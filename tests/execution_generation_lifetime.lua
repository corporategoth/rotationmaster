-- Actual prepared planner and Store notification protocol; no timing claims.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local prefix = assert(read('tests/active_runtime_plan.lua'):match('^(.-)\ntest%('))
local fixture, change = assert(loadstring(prefix .. '\nreturn fixture,change', '@generation-fixture'))()

local function acquire()
    local c, a, get = fixture(true)
    local b, full, t, h, views, boundary, current = get(a, 0, a.currentRotation)
    assert(h and b and full() and type(current) == 'function' and current(), 'notification continuation missing')
    return c, a, get, b, full, t, boundary, current
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

local function observed(run)
    local calls = {}
    local old, mask, count = debug.gethook()
    local enabled = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(event)
        if event == 'call' then
            local fn = debug.getinfo(2, 'f').func
            calls[fn] = (calls[fn] or 0) + 1
        end
    end, 'c')

    local ok, why = pcall(run)
    debug.sethook(old, mask, count)

    if enabled then
        jit.on()
    end

    assert(ok, why)
    return calls
end

test('notification continuation performs no source Store dependency or active-identity proof', function()
    local _, _, _, _, full, _, boundary, current = acquire()
    local guard = assert(find(full, 'guard'))
    local active = assert(find(full, 'readActiveRuntime'))
    local consumers = assert(find(full, 'consumers'))

    local calls = observed(function()
        for i = 1, 20 do
            assert(current())
        end
    end)

    for _, fn in ipairs({ guard, active, consumers, boundary, rawget, getfenv, pairs }) do
        assert(not calls[fn], 'notification check repeated a source proof')
    end

    assert(calls[current] == 20, 'continuation control did not run')
end)

test('managed mutations retire the execution stamp before old work resumes', function()
    for _, kind in ipairs({ 'body', 'dependency', 'rebind', 'context', 'expose', 'borrow', 'begin', 'disable' }) do
        local _, a, _, _, full, _, _, current = acquire()

        if kind == 'body' then
            change(a, function(b)
                b.description = 'Managed successor'
            end)
        elseif kind == 'dependency' then
            a:InvalidateRotationDependencies('condition', 'LEVEL')
        elseif kind == 'rebind' then
            assert(a:BindRotationProfile())
        elseif kind == 'context' then
            a:PLAYER_REGEN_DISABLED()
        elseif kind == 'expose' then
            assert(a:GetEditableRotation(0, a.currentRotation))
        elseif kind == 'borrow' then
            assert(a:AcquireRotationRuntimePass(0):Get(a.currentRotation))
        elseif kind == 'begin' then
            assert(a:BeginActiveRotationTransition())
        else
            a:DisableRotation()
        end

        assert(not current(), kind .. ' missed notification')
        assert(not full(), kind .. ' retained publication')
    end
end)

test('a later poll retires the old execution ticket while preserving stable content plan', function()
    local _, a, get, b, full, t, _, current = acquire()
    local nextBody, nextFull, nextToken, h, _, _, nextCurrent = get(a, 0, a.currentRotation)
    assert(h and nextBody == b and nextToken == t and nextCurrent() and nextFull() and not current() and not full())
end)

test('transition begin invalidates before profile property callbacks can reenter', function()
    local _, a, _, _, _, _, _, current = acquire()
    local profile = a.db.profile
    local witnessed

    a.db = setmetatable({}, {
        __index = function(_, key)
            if key == 'profile' then
                witnessed = current()
                return profile
            end
        end,
    })

    assert(current(), 'unnotified replacement should not scan properties')
    assert(a:BeginActiveRotationTransition())
    assert(witnessed == false, 'begin notified after a reentrant property read')
end)

test('public borrow of an unrelated asset leaves selected execution current', function()
    local _, a, get = fixture(true)
    local other = assert(a:CloneDefaultRotation(0, 'rm.tbc.shaman.starter', 'Other saved copy', { scope = 'class' }))
    local b, full, _, h, _, _, current = get(a, 0, a.currentRotation)
    assert(h and b and current() and full())
    assert(a:AcquireRotationRuntimePass(0):Get(other))
    assert(current() and full(), 'unrelated public borrow retired selected authority')
end)

test('old Store notifications cannot advance a replacement binding execution generation', function()
    local _, a, _, _, full, _, _, current = acquire()
    local reader = assert(find(full, 'reader'))
    local clock = assert(find(current, 'readExecutionGeneration'))
    local staleNotify = assert(find(full, 'executionWatch')).notify
    assert(a:BindRotationProfile())
    local generation = clock()
    reader:Retire()
    staleNotify()
    assert(clock() == generation, 'stale Store notification reached the replacement binding')
end)

test('unnotified raw changes stay the responsibility of the full callback boundary', function()
    for _, name in ipairs({ 'GetSpellIds', 'rotationStore', 'conditionDefinitions' }) do
        local _, a, _, _, full, _, _, current = acquire()

        if name == 'GetSpellIds' then
            a.GetSpellIds = function()
                error('must not invoke replacement')
            end
        elseif name == 'rotationStore' then
            a.db.profile.rotationStore = {}
        else
            a.conditionDefinitions = {}
        end

        assert(current(), 'scalar clock performed hidden source reads')
        assert(not full(), name .. ' escaped callback fence')
    end
end)

local storePrefix = assert(read('tests/rotation_store_reader.lua'):match('^(.-)\ntest%('))

local model, state, address, ctx, record = assert(loadstring(
    storePrefix .. '\nreturn model,state,address,ctx,record',
    '@generation-store'
))()

local function store()
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
    local a = address('class')
    local ok, _, seal = reader:Read(a, ctx, function(r) return r.body.name end)
    assert(ok)
    local n = 0

    local full = maker(reader, seal, ctx, function()
        n = n + 1
    end)

    assert(full and full())
    return service, reader, s, a, function() return n end
end

test('selected Store writes and reader publications retire execution watches', function()
    for _, kind in ipairs({ 'replace', 'delete', 'move', 'refresh', 'retire', 'aba' }) do
        local service, reader, _, a, n = store()
        local snapshot, expected = service:Get(a, ctx)

        if kind == 'refresh' then
            assert(service:Refresh())
        elseif kind == 'retire' then
            reader:Retire()
        elseif kind == 'replace' then
            snapshot.body.name = 'Changed'
            assert(service:Commit(assert(service:PlanReplace(a, snapshot, ctx, expected)), ctx))
        elseif kind == 'move' then
            local dest = address('character', ctx.character)
            local _, token = service:Get(dest, ctx)
            assert(service:Commit(assert(service:PlanDelete(dest, ctx, token)), ctx))
            assert(service:Commit(assert(service:PlanMove(a, dest, ctx, expected)), ctx))
        else
            assert(service:Commit(assert(service:PlanDelete(a, ctx, expected)), ctx))

            if kind == 'aba' then
                assert(service:Commit(assert(service:PlanCreate(a, snapshot, ctx)), ctx))
            end
        end

        assert(n() == (kind == 'refresh' and 2 or 1), kind .. ' notifications=' .. n())
    end
end)

test('failed and unrelated Store writes do not notify the selected execution', function()
    local service, _, _, _, n = store()
    assert(not service:Commit({}, ctx))
    assert(n() == 0)
    local other = address('class', 'MAGE', 'unrelated', 'MAGE')
    local c = { class = 'MAGE', character = 'Mage - Realm' }
    assert(service:Commit(assert(service:PlanCreate(other, record('Other'), c)), c))
    assert(n() == 0)
end)

finish()
