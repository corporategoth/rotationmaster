-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Actual DISTANCE execution. Use authored-copy only before root catalog integration.
-- Default/generated-current requires checked-in generated source to equal authored code.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local mode = arg[1] or 'generated-current'
assert(mode == 'authored-copy' or mode == 'generated-current', 'explicit source mode required')

local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local rangeMarker = '        -- pcall preserves both range bounds returned by the cached observation.'
local oldPrefix = '\n        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end\n'

local function evaluator()
    local text = read('Conditions/spatial.lua')
    local first = assert(text:find('addon:RegisterCondition("DISTANCE", {', 1, true))
    local last = assert(text:find('addon:RegisterCondition("DISTANCE_COUNT", {', first + 1, true))
    local section = text:sub(first, last - 1)
    local signature = '    evaluate = function(value, cache)'
    local _, start = assert(section:find(signature, 1, true))
    assert(not section:find(signature, start + 1, true))
    local ending = assert(section:find('    end,\n    print = function', start + 1, true))
    local body = section:sub(start + 1, ending + 3)

    assert(
        body:sub(1, 1) == '\n' and body:sub(-5) == '\n    ' and body:find(rangeMarker, 1, true),
        'exact evaluator boundaries lost'
    )

    return body
end

local authored = evaluator()

local function fixture(project)
    local f = F.new(project or 5)
    local a, e = f.addon, f.env
    local s = { exists = true, lower = 0, upper = 5, calls = {}, opaque = {} }

    local function record(name, ...)
        s.calls[#s.calls + 1] = { name, ... }
    end

    e.UnitExists = function(...)
        assert(select('#', ...) == 1)
        record('exists', ...)

        if s.throw then
            error('native presence failure')
        end

        return s.exists, s.opaque
    end

    e.canaccessvalue = function(v) return not rawequal(v, s.opaque) end
    e.geterrorhandler = function() return function() end end
    local checker = f.libraries['LibRangeCheck-3.0']

    checker.GetRange = function(self, unit)
        assert(self == checker)
        record('range', unit)

        if s.rangeThrow then
            error('range failure')
        end

        return s.lower, s.upper
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Platform/range.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/spatial.lua',
        'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    local catalog = assert(a:GetBuiltinConditionSource('DISTANCE'))
    local current = a:CopySettingsData(catalog)

    if mode == 'generated-current' then
        assert(current.evaluate == authored, 'generated DISTANCE catalog does not equal actual authored evaluator')
    else
        current.evaluate = authored
    end

    a:RegisterCondition('CURRENT_COPY', assert(a:CompileCustomCondition('CURRENT_COPY', current)))
    local archive = a:CopySettingsData(catalog)
    local marker = assert(archive.evaluate:find(rangeMarker, 1, true))
    archive.evaluate = oldPrefix .. archive.evaluate:sub(marker)
    assert(a:FunctionSourceHash(archive) == '397d9b2b', 'complete historical DISTANCE export changed')
    a:RegisterCondition('RAW_ARCHIVE', assert(a:CompileCustomCondition('RAW_ARCHIVE', archive)))
    return f, a, s, catalog, current, archive
end

local function node(tag, unit)
    return { type = tag or 'DISTANCE', unit = unit or 'target', value = 10 }
end

local function calls(s, name)
    local n = 0

    for _, r in ipairs(s.calls) do
        if r[1] == name then
            n = n + 1
        end
    end

    return n
end

local function known(a, v, match)
    assert(a:validateCondition(v, 0))
    assert(a:evaluateConditionResult(v).status == (match and 'match' or 'no-match'))
    assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == (match and 'no-match' or 'match'))
end

local function unknown(a, v, reason)
    assert(a:validateCondition(v, 0), 'invalid fixture')

    for _, n in ipairs({
        v,
        { type = 'NOT', value = v },
        { type = 'AND', value = { v } },
        { type = 'OR', value = { { type = 'NOT', value = v } } },
    }) do
        local result = a:evaluateConditionResult(n)

        assert(
            result.status == 'unavailable' and result.reason ~= 'invalid-condition-fields',
            'required presence became actionable'
        )

        if reason then
            assert(result.reason == reason, tostring(result.reason))
        end
    end

    local selected

    local r = a:EvaluateRotationSequence({
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = v,
                onTrue = { { id = 'yes', type = 'spell', action = 403 } },
                onFalse = { { id = 'no', type = 'spell', action = 403 } },
            },
        },
    }, function(n) return a:evaluateConditionResult(n) end, function(n)
        selected = n.id
    end)

    assert(
        r.status == 'unavailable' and r.suppressAttack and not selected,
        'unknown selected a branch or allowed Attack'
    )

    assert(#a.Diagnostics:GetReports() == 0, 'transient native failure became diagnostic quarantine')
end

local tags = { 'DISTANCE', 'CURRENT_COPY' }

test('unavailable native presence never authorizes NOT groups either branch or range reads', function()
    for _, tag in ipairs(tags) do
        local f, a, s = fixture()
        s.exists = nil
        unknown(a, node(tag), 'unit-data-unavailable')

        for _, bad in ipairs({ 0, 1, 'false', {}, math.huge, 0 / 0 }) do
            s.exists = bad
            unknown(a, node(tag), 'invalid-api-result')
        end

        s.exists = s.opaque
        unknown(a, node(tag), 'restricted-value')
        f.env.UnitExists = nil
        unknown(a, node(tag), 'missing-api')
        assert(calls(s, 'range') == 0)
    end
end)

test('failed native presence is transient unavailable and a fresh evaluation recovers', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        s.throw = true
        unknown(a, node(tag), 'api-error')
        assert(calls(s, 'range') == 0)
        s.throw = false
        known(a, node(tag), true)
        assert(calls(s, 'range') > 0 and #a.Diagnostics:GetReports() == 0)
    end
end)

test('readable false lazily skips range while denied false stays unavailable', function()
    for _, tag in ipairs(tags) do
        local f, a, s = fixture()
        s.exists = false
        known(a, node(tag), false)
        assert(calls(s, 'range') == 0)
        f.env.canaccessvalue = function(v) return v ~= false end
        unknown(a, node(tag), 'restricted-value')
        assert(calls(s, 'range') == 0)
    end
end)

test('missing nil nil and malformed public observer overrides retain unavailable reasons', function()
    for _, tag in ipairs(tags) do
        for _, kind in ipairs({ 'missing', 'nil-nil', 'explicit', 'number', 'string' }) do
            local _, a, s = fixture()

            if kind == 'missing' then
                a.Platform.GetUnitPresenceObservation = nil
            elseif kind == 'nil-nil' then
                a.Platform.GetUnitPresenceObservation = function() return nil end
            elseif kind == 'explicit' then
                a.Platform.GetUnitPresenceObservation = function() return nil, 'override-unknown' end
            elseif kind == 'number' then
                a.Platform.GetUnitPresenceObservation = function() return 1 end
            else
                a.Platform.GetUnitPresenceObservation = function() return 'false' end
            end

            unknown(
                a,
                node(tag),
                kind == 'explicit' and 'override-unknown'
                    or (kind == 'number' or kind == 'string') and 'invalid-api-result'
                    or 'unit-data-unavailable'
            )

            assert(#s.calls == 0)
        end
    end
end)

test('ordinary upper bound semantics exact arity and provider receiver remain unchanged', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        known(a, node(tag), true)
        assert(s.calls[1][1] == 'exists' and s.calls[1][2] == 'target')
        s.lower, s.upper = 5, 15
        known(a, node(tag), false)
        s.lower = nil
        s.upper = 10
        known(a, node(tag), true)

        for _, r in ipairs(s.calls) do
            assert(r[2] == 'target' and r[3] == nil)
        end
    end
end)

test('existing malformed missing and failed range observations remain unavailable after known presence', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        s.upper = nil
        unknown(a, node(tag), 'range-unavailable')
        s.upper = s.opaque
        unknown(a, node(tag), 'restricted-value')
        s.upper = -1
        unknown(a, node(tag), 'invalid-range-result')
        s.upper = 5
        s.lower = 6
        unknown(a, node(tag), 'invalid-range-result')
        s.lower = 0
        s.rangeThrow = true
        unknown(a, node(tag), 'range-provider-error')
    end
end)

test('canonical observer cache shares current copies and public helper with fresh pass retries', function()
    local _, a, s = fixture()
    local cache = {}
    s.exists = nil

    for _, tag in ipairs(tags) do
        local v, r = a.conditionDefinitions[tag].evaluate(node(tag), cache)
        assert(v == nil and r == 'unit-data-unavailable')
    end

    local read = a.Functions.cache.getCached
    local method = a.Platform.GetUnitPresenceObservation
    local v, r = read(cache, method, a.Platform, 'target')
    assert(v == nil and r == 'unit-data-unavailable' and calls(s, 'exists') == 1)
    s.exists = true
    assert(a.conditionDefinitions.DISTANCE.evaluate(node(), cache) == nil and calls(s, 'exists') == 1)
    cache = {}

    for _, tag in ipairs(tags) do
        assert(a.conditionDefinitions[tag].evaluate(node(tag), cache) == true)
    end

    assert(calls(s, 'exists') == 2 and calls(s, 'range') == 1)
    s.exists = false
    cache = {}

    for _, tag in ipairs(tags) do
        assert(a.conditionDefinitions[tag].evaluate(node(tag), cache) == false)
    end

    assert(calls(s, 'exists') == 3 and calls(s, 'range') == 1)
end)

test('live observer receiver unit and method identities partition cached observations', function()
    local f, a, s = fixture()
    local fn = a.conditionDefinitions.DISTANCE.evaluate
    local cache = {}
    assert(fn(node(), cache))
    local before = calls(s, 'exists')
    assert(fn(node(nil, 'focus'), cache) and calls(s, 'exists') == before + 1)
    local p = {}

    for k, v in pairs(a.Platform) do
        p[k] = v
    end

    a.Platform = p
    s.exists = false
    assert(fn(node(), cache) == false)
    local seen = 0

    p.GetUnitPresenceObservation = function(self, unit, ...)
        assert(self == p and unit == 'target' and select('#', ...) == 0)
        seen = seen + 1
        return nil, 'replacement-unknown'
    end

    local v, r = fn(node(), cache)
    assert(v == nil and r == 'replacement-unknown' and seen == 1)
    assert(fn(node(), cache) == nil and seen == 1)

    p.GetUnitPresenceObservation = function(self, unit)
        assert(self == p and unit == 'target')
        return true
    end

    assert(fn(node(), cache) == true)
end)

test('identified families retain presence policy without new combat gating', function()
    for _, project in ipairs({ 1, 18, 2, 5, 11, 14, 19 }) do
        local _, a = fixture(project)
        known(a, node(), true)
        known(a, node('CURRENT_COPY'), true)
    end

    local _, a, s = fixture(999)
    unknown(a, node(), 'unsupported-client')
    assert(#s.calls == 0)
end)

test('raw historical callback bytes and known behavior remain independently compilable', function()
    local _, a, s, catalog, current, archive = fixture()
    local preserved = a:CopySettingsData(archive)
    s.exists = nil
    known(a, node('RAW_ARCHIVE'), false)
    s.exists = true
    known(a, node('RAW_ARCHIVE'), true)
    assert(a:SettingsDataEqual(archive, preserved))
    assert(current.evaluate == authored)

    if mode == 'generated-current' then
        assert(catalog.evaluate == authored)
    else
        assert(
            catalog.evaluate == archive.evaluate,
            'authored-copy mode requires explicitly archived checked-in catalog'
        )
    end

    for name, hash in pairs({
        rcf = 'a7ab75e4',
        protectedRead = 'cc49d134',
        color = '158ebd8f',
        helpers = '9485f785',
    }) do
        local id = 'builtin:Conditions/spatial.lua:' .. name

        assert(
            a:FunctionSourceHash(a.builtinFunctions[id].source) == hash and a:ResolveFunctionBinding(id)
                == a.builtinSourceModules['Conditions/spatial.lua'](name)
        )
    end
end)

test('real public presence helper clone retains exact native and readability contract', function()
    local f, a, s = fixture()
    local id = 'builtin:Platform/unit_presence.lua:Platform_GetUnitPresenceObservation'
    local record = assert(a.builtinFunctions[id])
    assert(a:ResolveFunctionBinding(id) == a.Platform.GetUnitPresenceObservation)
    assert(a:InstallCustomFunction('PRESENCE_HELPER_COPY', a:CopySettingsData(record.source)))
    local helper = assert(a:ResolveFunctionBinding('PRESENCE_HELPER_COPY'))
    assert(helper(a.Platform, 'target') == true)
    s.exists = false
    assert(helper(a.Platform, 'target') == false)
    s.exists = s.opaque
    local v, r = helper(a.Platform, 'target')
    assert(v == nil and r == 'restricted-value')
end)

print(
    'Source mode: '
        .. mode
        .. (mode == 'authored-copy'
            and ' (actual authored evaluator over detached archived metadata; catalog untouched)'
            or ' (checked-in generated catalog must equal actual authored evaluator)')
)

finish()
