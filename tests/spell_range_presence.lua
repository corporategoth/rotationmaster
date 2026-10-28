local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local restore, old, repaired = dofile('tests/fixtures/restore_spell_range_presence.lua')
local tags = { 'SPELL_RANGE', 'PETSPELL_RANGE', 'ANYSPELL_RANGE' }
local sourceHashes = { SPELL_RANGE = 'e3ae21ae', PETSPELL_RANGE = 'e4d8d562', ANYSPELL_RANGE = '7ff9d97f' }

local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local function fixture(modern, project)
    local f = F.new(project or 5, 1, 'SHAMAN')
    local a, e = f.addon, f.env
    local s = { exists = true, known = true, hasRange = true, range = true, canonical = 5020, calls = {} }

    local function hit(name, ...)
        s.calls[#s.calls + 1] = { name, ... }

        if s.throw == name then
            error('required ' .. name .. ' failure')
        end
    end

    e.BOOKTYPE_SPELL, e.BOOKTYPE_PET = 'spell', 'pet'
    e.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }

    e.UnitExists = function(...)
        assert(select('#', ...) == 1 and (...) == 'target')
        hit('exists', ...)
        return s.exists
    end

    local function info(id)
        hit('metadata', id)

        if id == 'Shoot' then
            id = s.canonical
        end

        if id == 5019 or id == 5020 then
            return { name = 'Shoot', spellID = id, iconID = 1, subtext = id == 5019 and 'Rank 1' or 'Rank 2' }
        end
    end

    local function link(id)
        return '|Hspell:' .. id .. '|h[Shoot]|h'
    end

    if modern then
        e.C_Spell = {
            GetSpellInfo = info,
            GetSpellLink = link,
            SpellHasRange = function(id)
                hit('shape', id)
                return s.hasRange
            end,
            IsSpellInRange = function(id, unit)
                assert(unit == 'target')
                hit('range', id, unit)
                return s.range
            end,
        }

        e.C_SpellBook = {
            IsSpellKnown = function(id, bank)
                assert(bank == 1)
                hit('known', id, bank)
                return s.known
            end,
        }
    else
        e.GetSpellInfo = function(id)
            local v = info(id)

            if v then
                return v.name, v.subtext, 1, 0, 0, 30, v.spellID
            end
        end

        e.GetSpellLink = link

        e.IsSpellKnown = function(id, pet)
            assert(pet == true)
            hit('known', id, pet)
            return s.known
        end

        e.FindSpellBookSlotBySpellID = function(id, pet)
            hit('slot', id, pet)
            return pet and 8 or 3
        end

        e.SpellHasRange = function(slot, bank)
            hit('shape', slot, bank)
            return s.hasRange
        end

        e.IsSpellInRange = function(slot, bank, unit)
            assert(unit == 'target')
            hit('range', slot, bank, unit)

            if s.range == nil then
                return
            end

            return s.range and 1 or 0
        end
    end

    if not a.Platform.GetUnitPresenceObservation then
        local file = io.open('Platform/unit_presence.lua')

        if file then
            file:close()
            f.load('Platform/unit_presence.lua')
        end
    end

    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/actions.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/spell.lua',
        'Conditions/petspell.lua', 'Conditions/anyspell.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua',
        'Core/custom_authoring.lua', 'Core/function_data.lua'
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

    s.calls = {}
    return f, a, s
end

local function node(tag, ranked)
    return { type = tag, spell = 5019, ranked = ranked ~= false }
end

local function counts(s, name)
    local n = 0

    for _, call in ipairs(s.calls) do
        if call[1] == name then
            n = n + 1
        end
    end

    return n
end

local function unknown(a, v)
    assert(a.conditionDefinitions[v.type].valid(0, v), 'invalid unavailable fixture')

    for _, n in ipairs({
        v,
        { type = 'NOT', value = v },
        { type = 'AND', value = { v } },
        { type = 'OR', value = { { type = 'NOT', value = v } } },
    }) do
        local r = a:evaluateConditionResult(n)

        assert(
            r.status == 'unavailable' and r.reason ~= 'invalid-condition-fields',
            'required existence became actionable'
        )
    end

    local selected

    local r = a:EvaluateRotationSequence({
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = v,
                onTrue = { { id = 'yes', type = 'spell', action = 5019 } },
                onFalse = { { id = 'no', type = 'spell', action = 5019 } },
            },
        },
    }, function(n) return a:evaluateConditionResult(n) end, function(n)
        selected = n.id
    end)

    assert(r.status == 'unavailable' and not selected)
end

local function known(a, v, match)
    assert(a.conditionDefinitions[v.type].valid(0, v))
    assert(a:evaluateConditionResult(v).status == (match and 'match' or 'no-match'))
    assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == (match and 'no-match' or 'match'))
end

test('unavailable native target existence cannot authorize NOT groups or either branch', function()
    for _, tag in ipairs(tags) do
        local f, a, s = fixture(true)
        s.exists = nil
        unknown(a, node(tag))

        for _, v in ipairs({ 0, 1, 'false', {} }) do
            s.exists = v
            unknown(a, node(tag))
        end

        s.exists = true
        s.throw = 'exists'
        unknown(a, node(tag))
        s.throw = nil
        f.env.UnitExists = nil
        unknown(a, node(tag))
        assert(counts(s, 'metadata') == 0 and counts(s, 'known') == 0 and counts(s, 'range') == 0)
    end
end)

test('readability-denied false is unknown while readable absent target is a lazy known no-match', function()
    for _, tag in ipairs(tags) do
        local f, a, s = fixture(true)
        s.exists = false
        known(a, node(tag), false)
        assert(counts(s, 'metadata') == 0 and counts(s, 'known') == 0 and counts(s, 'range') == 0)
        f.env.canaccessvalue = function(v) return v ~= false end
        unknown(a, node(tag))
        assert(counts(s, 'metadata') == 0)
    end
end)

test('normal range banks selected ranks and native ordering remain unchanged in both API shapes', function()
    for _, modern in ipairs({ false, true }) do
        for _, tag in ipairs(tags) do
            for _, ranked in ipairs({ false, true }) do
                local _, a, s = fixture(modern)
                known(a, node(tag, ranked), true)
                assert(s.calls[1][1] == 'exists')
                local wanted = tag == 'PETSPELL_RANGE' and 5020 or ranked and 5019 or 5020
                local range

                for _, call in ipairs(s.calls) do
                    if call[1] == 'range' then
                        range = call
                    end
                end

                assert(range)

                if modern then
                    assert(range[2] == wanted and range[3] == 'target')
                else
                    assert(range[3] == (tag == 'PETSPELL_RANGE' and 'pet' or 'spell') and range[4] == 'target')
                end

                if tag == 'PETSPELL_RANGE' then
                    assert(counts(s, 'known') > 0)
                else
                    assert(counts(s, 'known') == 0)
                end
            end
        end
    end
end)

test('nonapplicable and out-of-range controls remain false while pet knowledge preserves exact gating', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture(true)
        s.hasRange = false
        known(a, node(tag), false)
        assert(counts(s, 'range') == 0)
        s.hasRange = true
        s.range = false
        known(a, node(tag), false)
    end

    local _, a, s = fixture(true)
    s.known = false
    known(a, node('PETSPELL_RANGE'), false)
    assert(counts(s, 'shape') == 0 and counts(s, 'range') == 0)
    s.known = nil
    unknown(a, node('PETSPELL_RANGE'))
end)

test('public presence adds no Retail or Forever ban while unknown client refuses before native queries', function()
    for _, project in ipairs({ 1, 18, 2, 5, 11, 14, 19 }) do
        for _, tag in ipairs(tags) do
            local _, a = fixture(true, project)
            known(a, node(tag), true)
        end
    end

    for _, tag in ipairs(tags) do
        local _, a, s = fixture(true, 999)
        unknown(a, node(tag))
        assert(#s.calls == 0)
    end
end)

test('presence snapshots share full nil reasons across current callbacks and recover only on a fresh pass', function()
    local f, a, s = fixture(true)
    local cache = {}
    s.exists = nil

    for _, tag in ipairs(tags) do
        local v, r = a.conditionDefinitions[tag].evaluate(node(tag), cache)
        assert(v == nil and r == 'unit-data-unavailable')
    end

    assert(counts(s, 'exists') == 1)
    s.exists = true
    assert(a.conditionDefinitions.SPELL_RANGE.evaluate(node('SPELL_RANGE'), cache) == nil)
    assert(counts(s, 'exists') == 1)
    cache = {}

    for _, tag in ipairs(tags) do
        assert(a.conditionDefinitions[tag].evaluate(node(tag), cache) == true)
    end

    assert(counts(s, 'exists') == 2)
    s.exists = false
    cache = {}
    assert(a.conditionDefinitions.SPELL_RANGE.evaluate(node('SPELL_RANGE'), cache) == false)
    s.exists = true
    local absentCount = counts(s, 'exists')

    assert(
        a.conditionDefinitions.PETSPELL_RANGE.evaluate(node('PETSPELL_RANGE'), cache) == false
            and counts(s, 'exists') == absentCount
    )

    local before = counts(s, 'exists')
    a.conditionDefinitions.SPELL_RANGE.evaluate(node('SPELL_RANGE'))
    a.conditionDefinitions.SPELL_RANGE.evaluate(node('SPELL_RANGE'))
    assert(counts(s, 'exists') == before + 2)
end)

test('actual current observer method and receiver identity partition the canonical cache', function()
    local _, a, s = fixture(true)
    local fn = a.conditionDefinitions.SPELL_RANGE.evaluate
    local v = node('SPELL_RANGE')
    local cache = {}
    assert(fn(v, cache))
    local platform = a.Platform
    local replacement = {}

    for k, x in pairs(platform) do
        replacement[k] = x
    end

    a.Platform = replacement
    s.exists = false
    assert(fn(v, cache) == false)
    local calls = 0

    replacement.GetUnitPresenceObservation = function(self, unit, ...)
        assert(self == replacement and unit == 'target' and select('#', ...) == 0)
        calls = calls + 1
        return nil, 'override-unknown'
    end

    local got, reason = fn(v, cache)
    assert(got == nil and reason == 'override-unknown' and calls == 1)
    assert(fn(v, cache) == nil and calls == 1)

    replacement.GetUnitPresenceObservation = function(self, unit)
        assert(self == replacement and unit == 'target')
        return true
    end

    assert(fn(v, cache) == true)
end)

test('generic presence cache keys separate units and leave longterm storage unchanged', function()
    local f, a, s = fixture(true)
    local storage = a.longtermCache
    local before = a:CopySettingsData(storage)
    local calls = 0

    f.env.UnitExists = function(unit, ...)
        assert(select('#', ...) == 0)
        calls = calls + 1
        return unit == 'target'
    end

    local read = a.Functions.cache.getCached
    local method = a.Platform.GetUnitPresenceObservation
    local cache = {}

    assert(
        read(cache, method, a.Platform, 'target') == true
            and read(cache, method, a.Platform, 'focus') == false
            and calls == 2
    )

    assert(
        read(cache, method, a.Platform, 'target') == true
            and read(cache, method, a.Platform, 'focus') == false
            and calls == 2
    )

    assert(a.longtermCache == storage and a:SettingsDataEqual(storage, before))
end)

-- What was a byte-exact inverse of three modules is now only the part that matters to saved copies: the private helpers they bind
-- to keep their source identity and resolve to the shipped getters.
test('private helper source identities of the spell modules stay exact', function()
    local _, a = fixture(true)

    for path, map in pairs({
        ['Conditions/spell.lua'] = { color = '906341b8', helpers = '769a506e' },
        ['Conditions/petspell.lua'] = { color = 'fedaa3e7', helpers = '60920b9d' },
        ['Conditions/anyspell.lua'] = { color = 'f35f4765', helpers = '47f6d2db', SpellData = 'bd968be4' },
    }) do
        for name, hash in pairs(map) do
            local id = 'builtin:' .. path .. ':' .. name

            assert(
                a:FunctionSourceHash(a.builtinFunctions[id].source) == hash and a:ResolveFunctionBinding(id)
                    == a.builtinSourceModules[path](name)
            )
        end
    end
end)

test(
    'actual generated copies normalize presence and complete raw archives preserve their historical behavior',
    function()
        for _, tag in ipairs(tags) do
            local f, a, s = fixture(true)
            local source = assert(a:GetBuiltinConditionSource(tag))
            local before = a:CopySettingsData(source)
            a:RegisterCondition('COPY', assert(a:CompileCustomCondition('COPY', source)))
            s.exists = nil
            unknown(a, node('COPY'))
            local raw = a:CopySettingsData(source)
            raw.evaluate = old[tag]
            local stored = a:CopySettingsData(raw)
            a.db.global.custom_conditions = a.db.global.custom_conditions or {}
            a.db.global.custom_conditions.RAW = raw
            a:RegisterCondition('RAW', assert(a:CompileCustomCondition('RAW', raw)))
            known(a, node('RAW'), false)
            assert(a:SettingsDataEqual(raw, stored) and a:SettingsDataEqual(before, source))
            s.exists = true
            known(a, node('COPY'), true)
            known(a, node('RAW'), true)
            local cache = {}
            local count = counts(s, 'exists')
            assert(a.conditionDefinitions.COPY.evaluate(node('COPY'), cache))
            assert(a.conditionDefinitions[tag].evaluate(node(tag), cache))
            assert(counts(s, 'exists') == count + 1)
        end
    end
)

for _, copied in ipairs({ false, true }) do
    test(
        (copied and 'current compiled' or 'authored')
            .. ' callbacks retain unknown for missing and nil-nil presence overrides',
        function()
            for _, tag in ipairs(tags) do
                for _, mode in ipairs({ 'missing', 'nil-nil', 'explicit' }) do
                    local _, a, s = fixture(true)
                    local kind = tag

                    if copied then
                        kind = 'OVERRIDE_COPY'

                        a:RegisterCondition(kind, assert(a:CompileCustomCondition(kind, a:GetBuiltinConditionSource(
                            tag
                        ))))
                    end

                    if mode == 'missing' then
                        a.Platform.GetUnitPresenceObservation = nil
                    elseif mode == 'nil-nil' then
                        a.Platform.GetUnitPresenceObservation = function() return nil end
                    else
                        a.Platform.GetUnitPresenceObservation = function() return nil, 'provider-unknown' end
                    end

                    unknown(a, node(kind))
                    local v, reason = a.conditionDefinitions[kind].evaluate(node(kind), {})

                    assert(
                        v == nil and reason == (mode == 'explicit' and 'provider-unknown' or 'unit-data-unavailable')
                    )

                    assert(#s.calls == 0, 'unavailable presence queried unconsumed spell or range facts')
                end
            end
        end
    )
end

test('actual public helper clone and getter retain live presence readiness and public family policy', function()
    local f, a, s = fixture(true)
    local id = 'builtin:Platform/unit_presence.lua:Platform_GetUnitPresenceObservation'
    local row = assert(a.builtinFunctions[id], 'catalog pending public presence observer')

    assert(
        a:ResolveFunctionBinding(id) == a.Platform.GetUnitPresenceObservation
            and row.source.args[1].type == 'RMPlatform'
            and row.source.args[2].name == 'unit'
            and row.source.args[2].type == 'string'
    )

    assert(
        a.builtinSourceModules['Platform/unit_presence.lua']('Platform_GetUnitPresenceObservation')
            == a.Platform.GetUnitPresenceObservation
    )

    assert(a:InstallCustomFunction('COPY_PRESENCE', a:CopySettingsData(row.source)))
    local copy = assert(a:ResolveFunctionBinding('COPY_PRESENCE'))
    assert(copy(a.Platform, 'target') == true)
    s.exists = false
    assert(copy(a.Platform, 'target') == false)
    f.env.canaccessvalue = function(v) return v ~= false end
    local v, r = copy(a.Platform, 'target')
    assert(v == nil and r == 'restricted-value')
end)

finish()
