-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Completed scalar delivery follows managed notifications; private execution stays fully proved.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/acquisition_proof_consolidation.lua'):match('^(.-)\ntest%('))

local acquired, find, calls = assert(loadstring(
    prefix .. '\nreturn acquired,find,calls',
    '@publication-freshness-fixture'
))()

local function prepared(target)
    local c, a, get = acquired(target)
    local b, f, t, h, v, l, n, p = get(a, 0, a.currentRotation)
    assert(h and b and f() and type(p) == 'function' and p(), 'missing separate publication freshness lease')
    return c, a, get, b, f, p
end

test('delivery uses the managed generation without Scope Store or active snapshot walks', function()
    for _, target in ipairs({ false, true }) do
        local _, _, _, _, full, delivery = prepared(target)
        local store = assert(find(full, 'guard'))
        local active = assert(find(full, 'readActiveRuntime'))

        assert(
            calls(store, function()
                for i = 1, 7 do
                    assert(delivery())
                end
            end) == 0,
            'delivery repeated full Store source certificate'
        )

        assert(
            calls(active, function()
                for i = 1, 7 do
                    assert(delivery())
                end
            end) == 0,
            'delivery repeated active snapshot instead of managed operation generation'
        )

        local authority = assert(find(full, 'runtimeAuthority'))

        assert(
            calls(authority, function()
                for i = 1, 7 do
                    assert(delivery())
                end
            end) == 0,
            'delivery traversed dependency roots'
        )
    end
end)

test('unused producer environment replacement permits scalar delivery but refuses next execution', function()
    for _, name in ipairs({ 'GetSpellIds', 'CopyData', 'IsRotationClassToken', 'GetRotationValidationOptions' }) do
        local _, a, get, _, full, delivery = prepared(true)
        local fn = a[name] or a.RotationData[name]
        assert(type(fn) == 'function', name)
        local env = getfenv(fn)
        setfenv(fn, setmetatable({}, { __index = env }))
        assert(not full(), 'full source admission weakened for ' .. name)
        assert(delivery(), 'unused ' .. name .. ' environment cancelled scalar delivery')
        local b, f, _, handled = get(a, 0, a.currentRotation)
        assert(not handled or b == nil or not f(), 'changed producer reused private execution')
    end
end)

test('raw owner selection still aborts immediately without a managed notification', function()
    for _, kind in ipairs({ 'db', 'profile', 'spec', 'key' }) do
        local _, a, _, _, _, delivery = prepared(true)

        if kind == 'db' then
            a.db = {}
        elseif kind == 'profile' then
            a.db.profile = {}
        elseif kind == 'spec' then
            a.currentSpec = 1
        else
            a.currentRotation = 'other'
        end

        assert(not delivery(), kind .. ' mutation survived publication')
    end
end)

test('unnotified table replacement does not promise immediate completed-result cancellation', function()
    for _, kind in ipairs({
        'global',
        'store',
        'body',
        'origin',
        'store-meta',
        'body-meta',
        'condition-root',
        'effects-root',
    }) do
        local _, a, _, _, full, delivery = prepared(true)
        local store = a.db.profile.rotationStore
        local selected

        for _, bySpec in pairs(store.classes) do
            for _, rows in pairs(bySpec) do
                for _, record in pairs(rows) do
                    if record.body and record.body.name == 'Copy of Shaman: early leveling' then
                        selected = record
                    end
                end
            end
        end

        assert(selected, 'selected saved record missing')

        if kind == 'global' then
            a.db.global = {}
        elseif kind == 'store' then
            a.db.profile.rotationStore = {}
        elseif kind == 'body' then
            selected.body = {}
        elseif kind == 'origin' then
            selected.origin = {}
        elseif kind == 'store-meta' then
            setmetatable(store, {})
        elseif kind == 'body-meta' then
            setmetatable(selected.body, {})
        elseif kind == 'condition-root' then
            a.conditionDefinitions = {}
        else
            a.db.global.effects = {}
        end

        assert(delivery(), kind .. ' raw edit added a new synchronous publication contract')
        assert(not full(), kind .. ' raw edit escaped unchanged full execution admission')
    end
end)

test('the next full acquisition observes a raw selected body replacement before private reuse', function()
    local _, a, get, body, full, delivery = prepared(true)
    local previousToken = assert(find(full, 'selected')).token
    local ref = assert(a:GetScopedRotationCoordinator():Resolve(0, a.currentRotation))
    local address = ref.address
    local rows = a.db.profile.rotationStore.classes[address.owner][address.spec]
    local record = rows[address.id]
    record.body = a.RotationData.CopyData(record.body)
    assert(delivery() and not full(), 'phase-specific root freshness contract was lost')
    local nextBody, nextFull, nextToken, handled = get(a, 0, a.currentRotation)

    assert(
        not handled or nextBody == nil or nextToken ~= previousToken,
        'next acquisition reused the stale admitted private graph'
    )

    if handled and nextBody then
        assert(nextFull(), 'replacement acquisition was not fully proved')
    end
end)

test('managed dependency notification and newer acquisitions retire only the older delivery', function()
    local _, a, _, _, _, delivery = prepared(false)
    a:InvalidateRotationDependencies('effect', 'changed')
    assert(not delivery())
    local _, a, get, _, _, delivery = prepared(true)
    local _, full, _, h, _, _, _, later = get(a, 0, a.currentRotation)
    assert(h and full() and later() and not delivery() and later(), 'nested request lifetime was lost')
end)

test('supported edit delete exposure key borrow and rebind abort completed delivery', function()
    for _, kind in ipairs({ 'edit', 'delete', 'expose', 'borrow', 'rebind' }) do
        local _, a, _, _, _, delivery = prepared(true)
        local coordinator = a:GetScopedRotationCoordinator()
        local key = a.currentRotation

        if kind == 'edit' then
            local record, token = assert(a:GetRotationRecordSnapshot(0, key))
            record.body.description = 'Managed delivery edit'
            local ref = assert(coordinator:Resolve(0, key))
            assert(a:CommitRotationDraft(ref, token, record, 'class'))
        elseif kind == 'delete' then
            local _, token = a:GetRotationRecordSnapshot(0, key)
            assert(a:DeleteRotationRecord(assert(coordinator:Resolve(0, key)), token))
        elseif kind == 'expose' then
            assert(coordinator:GetEditableRotation(0, key))
        elseif kind == 'borrow' then
            local pass = assert(coordinator:RuntimePass(0))
            assert(pass:Get(key))
        else
            assert(a:BindRotationProfile())
        end

        assert(not delivery(), kind .. ' supported publication missed generation')
    end
end)

test('actual detached-style receiver replacement or environment change cancels delivery', function()
    for _, kind in ipairs({ 'pointer', 'environment' }) do
        local _, a, _, _, _, delivery = prepared(true)

        if kind == 'pointer' then
            a.GlowCooldown = function()
                error('unknown receiver invoked')
            end
        else
            setfenv(a.GlowCooldown, setmetatable({}, { __index = getfenv(a.GlowCooldown) }))
        end

        assert(not delivery(), kind .. ' Glow receiver admitted')
    end
end)

-- The actual main fixture supplies an explicit eighth private capability.
local mainPrefix = assert(read('tests/active_runtime_main.lua'):match('^(.-)\ntest%('))
local needle = 'return body,state.fullLease,state.token,true,state.views,state.cheapLease,state.notifiedLease'
local at = assert(mainPrefix:find(needle, 1, true))
mainPrefix = mainPrefix:sub(1, at - 1) .. needle .. ',state.deliveryLease' .. mainPrefix:sub(at + #needle)
local fullNeedle = 'state.fullLease=function()state.fullChecks=(state.fullChecks or 0)+1;return state.current end'
local fullAt = assert(mainPrefix:find(fullNeedle, 1, true))

mainPrefix = mainPrefix:sub(1, fullAt - 1)
    .. fullNeedle:gsub('return state.current end', 'return state.current and state.fullCurrent~=false end')
    .. mainPrefix:sub(fullAt + #fullNeedle)

local make = assert(loadstring(mainPrefix .. '\nreturn fixture', '@publication-main-fixture'))()

local function protocol()
    local c, s = make()
    s.mode = 'plan'
    s.body.rotation = {}
    s.body.cooldowns = {}

    s.deliveryLease = function()
        s.deliveryChecks = (s.deliveryChecks or 0) + 1
        return s.current
    end

    return c, s
end

test('main makes one final full proof before scalar deliveries and then uses freshness only', function()
    local c, s = protocol()
    local beforeFull, afterFull

    c.e.WeakAuras = {
        ScanEvents = function()
            beforeFull = s.fullChecks
        end,
    }

    local send = c.e.LibStub('AceEvent-3.0').SendMessage

    c.e.LibStub('AceEvent-3.0').SendMessage = function(...)
        afterFull = s.fullChecks
        return send(...)
    end

    c.tick()
    assert(beforeFull and afterFull == beforeFull, 'scalar publisher repeated full admission')
    assert((s.deliveryChecks or 0) > 0, 'main ignored publication freshness capability')
end)

test('failed final full proof suppresses even a valid lean publication lease', function()
    local c, s = protocol()

    s.onFence = function()
        s.current = false
        return true
    end

    local sent = 0

    c.e.WeakAuras = {
        ScanEvents = function()
            sent = sent + 1
        end,
    }

    c.tick()
    assert(sent == 0, 'failed final full fence published')
end)

test('rare private cooldown announcement proves full authority after link and formatting callouts', function()
    local c, s = protocol()
    local cond = { id = 'announce', type = 'spell', action = 403, announce = 'local' }
    s.body.cooldowns = { cond }
    s.views = { [cond] = { id = cond.id } }
    c.a.skipAnnounce = false
    c.a.announced = { kept = true }
    local links, dispatch, armed = 0, 0, false

    c.a.verbose = function(_, format)
        if format == 'Cooldown %d [%s] is enabled' then
            armed = true
        end
    end

    c.a.Platform.GetSpellLink = function()
        if armed then
            links = links + 1
            s.fullCurrent = false
            assert((s.deliveryChecks or 0) > 0, 'link call was before delivery')
        end

        return 'spell:403'
    end

    c.a.DispatchAnnouncement = function()
        dispatch = dispatch + 1
    end

    c.tick()
    assert(not c.a.adviceErrorReport and #c.a.Diagnostics:GetReports() == 0, 'private branch raised diagnostic error')
    assert(links == 1 and dispatch == 0, 'private dispatch crossed rejected post-format full fence')
    assert(c.a.announced.kept == true, 'rejected private fence resumed later scalar housekeeping')
end)

test('late actual Glow environment probe cannot bless a newer same-key operation', function()
    local loader, env = loadfile, getfenv
    local state = {}

    _G.loadfile = function(path)
        local chunk = assert(loader(path))

        if path ~= 'Core/active_runtime_plan.lua' then
            return chunk
        end

        return function(name, a)
            local inherited = env(1)
            local separate = setmetatable({}, { __index = inherited })

            separate.getfenv = function(fn)
                if fn == a.GlowCooldown and state.callback then
                    local callback = state.callback
                    state.callback = nil
                    callback()
                end

                return env(fn)
            end

            setfenv(chunk, separate)
            return chunk(name, a)
        end
    end

    local ok, c, a, get, body, full, delivery = pcall(prepared, true)
    _G.loadfile = loader
    assert(ok, c)

    state.callback = function()
        local op = assert(a:BeginActiveRotationTransition())
        assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation, body))
    end

    assert(not delivery(), 'late receiver probe refreshed old publication operation')
end)

finish()
