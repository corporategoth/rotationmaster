-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/active_runtime_plan.lua'):match('^(.-)\ntest%('))
local fixture, change = assert(loadstring(prefix .. '\nreturn fixture,change', '@continuation-fixture'))()
local storePrefix = assert(read('tests/rotation_store_reader.lua'):match('^(.-)\ntest%('))

local model, state, address, ctx, record = assert(loadstring(
    storePrefix .. '\nreturn model,state,address,ctx,record',
    '@continuation-store'
))()

local function store(scope)
    local data = model()
    local s = state()
    local reader

    local service, why, maker = data.NewRotationStore({
        state = s,
        fallbackID = 'Default',
        bindInternalReader = function(r)
            reader = r
        end,
    })

    assert(service, why)
    local a = address(scope, scope == 'character' and ctx.character or nil)
    local ok, _, seal = reader:Read(a, ctx, function(r) return r.body.name end)
    assert(ok)
    local full, cheap = maker(reader, seal, ctx)
    assert(type(full) == 'function' and type(cheap) == 'function', 'missing separate Store continuation')
    assert(full() == true and cheap() == true)
    return service, reader, s, a, full, cheap, data
end

local function acquired(target)
    local c, a, get = fixture(target)
    local b, full, t, h, views, cheap = get(a, 0, a.currentRotation)
    assert(h and b and full() and type(cheap) == 'function' and cheap(), 'missing live sixth condition lease')
    return c, a, get, b, full, t, cheap, views
end

local function watched(run)
    local counts = {}
    local old, mask, step = debug.gethook()
    local enabled = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(event)
        if event == 'call' then
            local info = debug.getinfo(2, 'fS')
            local key = (info.source or '') .. ':' .. info.linedefined
            counts[key] = (counts[key] or 0) + 1
        end
    end, 'c')

    local ok, err = pcall(run)
    debug.sethook(old, mask, step)

    if enabled then
        jit.on()
    end

    assert(ok, err)
    return counts
end

local function key(fn)
    local i = debug.getinfo(fn, 'S')
    return i.source .. ':' .. i.linedefined
end

local function find(value, name, seen)
    if type(value) ~= 'function' and type(value) ~= 'table' then
        return
    end

    seen = seen or {}

    if seen[value] then
        return
    end

    seen[value] = true

    if type(value) == 'function' then
        for i = 1, 100 do
            local n, v = debug.getupvalue(value, i)

            if not n then
                break
            end

            if n == name then
                return v
            end
        end

        for i = 1, 100 do
            local n, v = debug.getupvalue(value, i)

            if not n then
                break
            end

            local got = find(v, name, seen)

            if got then
                return got
            end
        end
    else
        for _, v in pairs(value) do
            local got = find(v, name, seen)

            if got then
                return got
            end
        end
    end
end

test('sixth continuation is distinct and retires old poll without rebuilding plan', function()
    for _, target in ipairs({ false, true }) do
        local _, a, get, b, full, t, cheap = acquired(target)
        assert(cheap ~= full)

        for i = 1, 3 do
            local nextBody, nextFull, nextToken, h, _, nextCheap = get(a, 0, a.currentRotation)
            assert(h and nextBody == b and nextToken == t and nextFull() and nextCheap() and not cheap() and not full())
            cheap, full = nextCheap, nextFull
        end
    end
end)

test('cheap repeated checks perform one active read and zero full Store shape proofs', function()
    local _, _, _, _, full, _, cheap = acquired(true)
    local fullStore = assert(find(full, 'guard'))
    local active = assert(find(full, 'readActiveRuntime'))

    local counts = watched(function()
        for i = 1, 7 do
            assert(cheap())
        end
    end)

    assert((counts[key(fullStore)] or 0) == 0, 'condition path called full Store guard')
    assert(counts[key(active)] == 7, 'expected exactly one active identity per condition continuation')

    local withFull = watched(function()
        assert(full())
    end)

    assert((withFull[key(fullStore)] or 0) > 0, 'full publication route lost its Store proof')
end)

test('Store continuation never calls fields plain class validation or pairs', function()
    local _, _, _, _, full, cheap = store()

    local counts = watched(function()
        for i = 1, 7 do
            assert(cheap())
        end
    end)

    for _, name in ipairs({ 'fields', 'plain', 'validAddress', 'privateContext' }) do
        local fn = assert(find(full, name), name)
        assert((counts[key(fn)] or 0) == 0, 'cheap called ' .. name)
    end

    local n = 0
    local old = pairs

    _G.pairs = function(...)
        n = n + 1
        return old(...)
    end

    local ok = cheap()
    _G.pairs = old
    assert(ok and n == 0)
end)

test('selected raw root bucket row and every component replacement retire Store continuation', function()
    for _, scope in ipairs({ 'class', 'character' }) do
        for _, kind in ipairs({
            'classes', 'characters', 'legacy', 'bucket', 'specs', 'rows', 'record', 'body', 'origin', 'imported',
            'comparison', 'version'
        }) do
            local _, _, s, a, _, cheap = store(scope)
            local root = scope == 'class' and s.classes or s.characters
            local bucket = root[a.owner]
            local map = scope == 'class' and bucket or bucket.specs
            local rows = map[a.spec]
            local r = rows[a.id]

            if kind == 'classes' or kind == 'characters' or kind == 'legacy' then
                s[kind] = {}
            elseif kind == 'bucket' then
                root[a.owner] = {}
            elseif kind == 'specs' then
                if scope == 'character' then
                    bucket.specs = {}
                else
                    map[a.spec] = {}
                end
            elseif kind == 'rows' then
                map[a.spec] = {}
            elseif kind == 'record' then
                rows[a.id] = { body = r.body }
            elseif kind == 'version' then
                s.version = 2
            else
                r[kind] = {}
            end

            assert(not cheap(), scope .. ' ' .. kind .. ' survived')
        end
    end
end)

test('managed replace delete move refresh retire and same-ID recreate invalidate Store continuation', function()
    for _, kind in ipairs({ 'replace', 'delete', 'move', 'refresh', 'retire', 'aba' }) do
        local service, reader, _, a, _, cheap = store()
        local snapshot, expected = service:Get(a, ctx)

        if kind == 'refresh' then
            assert(service:Refresh())
        elseif kind == 'retire' then
            reader:Retire()
        elseif kind == 'replace' then
            snapshot.body.name = 'Changed'
            assert(service:Commit(assert(service:PlanReplace(a, snapshot, ctx, expected)), ctx))
        elseif kind == 'move' then
            local destination = address('character', ctx.character)
            local _, target = service:Get(destination, ctx)
            assert(service:Commit(assert(service:PlanDelete(destination, ctx, target)), ctx))
            assert(service:Commit(assert(service:PlanMove(a, destination, ctx, expected)), ctx))
        else
            assert(service:Commit(assert(service:PlanDelete(a, ctx, expected)), ctx))

            if kind == 'aba' then
                assert(service:Commit(assert(service:PlanCreate(a, snapshot, ctx)), ctx))
            end
        end

        assert(not cheap(), kind .. ' survived')
    end
end)

test('failed Store operation and unrelated managed write do not retire selected continuation', function()
    local service, _, _, a, full, cheap = store()
    assert(not service:Commit({}, ctx))
    assert(full() and cheap())
    local other = address('class', 'MAGE', 'unrelated', 'MAGE')
    local c = { class = 'MAGE', character = 'Mage - Realm' }
    assert(service:Commit(assert(service:PlanCreate(other, record('Other'), c)), c))
    assert(full() and cheap())
end)

test('full guard still rejects malformed header after cheap scalar continuation', function()
    local _, _, s, _, full, cheap = store()
    s.unexpected = true
    assert(cheap() == true and full() == false, 'full shape proof was removed or moved into cheap lease')
end)

test('managed publication and dependencies retire full and cheap authority', function()
    for _, kind in ipairs({
        'body', 'dependency', 'registry', 'definitions', 'shared', 'personal', 'effects', 'library', 'profile', 'db'
    }) do
        local _, a, _, _, full, _, cheap = acquired(true)

        if kind == 'body' then
            change(a, function(b)
                b.description = 'Managed successor'
            end)
        elseif kind == 'dependency' then
            a:InvalidateRotationDependencies('effect', 'changed')
        elseif kind == 'registry' then
            a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
        elseif kind == 'definitions' then
            a.conditionDefinitions = {}
        elseif kind == 'shared' then
            a.db.global.itemsets = {}
        elseif kind == 'personal' then
            a.db.profile.itemsets = {}
        elseif kind == 'effects' then
            a.db.global.effects = {}
        elseif kind == 'library' then
            a.db.profile.rotationLibrary = {}
        elseif kind == 'profile' then
            a.db.profile = a.RotationData.CopyData(a.db.profile)
        else
            a.db = { profile = a.db.profile, global = a.db.global }
        end

        assert(not cheap(), kind .. ' retained cheap authority')
        assert(not full(), kind .. ' retained full authority')
    end
end)

test('selection operation spec context rebind exposure and public borrow retire cheap lease', function()
    for _, kind in ipairs({ 'operation', 'spec', 'key', 'rebind', 'context', 'expose', 'borrow' }) do
        local c, a, _, _, full, _, cheap = acquired(true)

        if kind == 'operation' then
            a:BeginActiveRotationTransition()
        elseif kind == 'spec' then
            a.currentSpec = 1
        elseif kind == 'key' then
            a.currentRotation = 'foreign'
        elseif kind == 'rebind' then
            assert(a:BindRotationProfile())
        elseif kind == 'context' then
            a:PLAYER_REGEN_DISABLED()
        elseif kind == 'expose' then
            assert(a:GetEditableRotation(0, a.currentRotation))
        else
            assert(assert(a:AcquireRotationRuntimePass(0)):Get(a.currentRotation))
        end

        assert(not cheap(), kind .. ' survived')
        assert(not full(), kind .. ' full survived')
    end
end)

test('replacement Store owner root and fallback identity retire cheap continuation', function()
    for _, kind in ipairs({ 'rotationStore', 'rotationFallbackID' }) do
        local _, a, _, _, _, _, cheap = acquired(true)

        if kind == 'rotationStore' then
            a.db.profile.rotationStore = a.RotationData.CopyData(a.db.profile.rotationStore)
        else
            a.db.profile.rotationFallbackID = 'Replacement fallback'
        end

        assert(not cheap(), kind .. ' owner root survived')
    end
end)

test('private step sequence announcement and publication consumer overrides retire before handoff', function()
    for _, name in ipairs({ 'GetSpellIds', 'EvaluateRotationSequence', 'DispatchAnnouncement', 'GlowCooldown' }) do
        local _, a, _, _, _, _, cheap = acquired(true)
        local calls = 0

        a[name] = function()
            calls = calls + 1
            error('private input escaped')
        end

        assert(not cheap() and calls == 0, name .. ' override dispatched')
    end

    for _, name in ipairs({ 'CopyData', 'CheckPortable', 'IndexRotationSteps' }) do
        local _, a, _, _, _, _, cheap = acquired(true)
        local calls = 0

        a.RotationData[name] = function()
            calls = calls + 1
            error('private input escaped')
        end

        assert(not cheap() and calls == 0, name .. ' override dispatched')
    end
end)

test('consumer function environment changes retire cheap lease without invoking replacement', function()
    local _, a, _, _, _, _, cheap = acquired(true)
    local fn = a.GetSpellIds
    setfenv(fn, setmetatable({}, { __index = getfenv(fn) }))
    assert(not cheap())
end)

test('foreign requests do not revoke current cheap lease but a later owned poll does', function()
    local _, a, get, _, full, _, cheap = acquired(true)
    local _, _, _, h = get({}, 0, a.currentRotation)
    assert(not h and cheap() and full())
    local _, stale, _, handled = get(a, 1, a.currentRotation)
    assert(handled and not stale() and cheap())
    assert(get(a, 0, a.currentRotation))
    assert(not cheap() and not full())
end)

finish()
