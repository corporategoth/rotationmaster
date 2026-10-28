-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local rawMake = dofile('tests/fixtures/rotation_execution.lua')

local function make(options)
    local c = rawMake(options)
    c.e.GetBuildInfo = function() return '2.5.5', '12345' end
    return c
end

local function up(fn, key, seen)
    seen = seen or {}

    if seen[fn] then
        return
    end

    seen[fn] = true

    for i = 1, 120 do
        local k, v = debug.getupvalue(fn, i)

        if not k then
            break
        end

        if k == key then
            return v
        end
    end

    for i = 1, 120 do
        local k, v = debug.getupvalue(fn, i)

        if not k then
            break
        end

        if type(v) == 'function' then
            local r = up(v, key, seen)

            if r ~= nil then
                return r
            end
        end
    end
end

local function currentPass()
    for level = 2, 30 do
        if not debug.getinfo(level) then
            break
        end

        for i = 1, 100 do
            local name, value = debug.getlocal(level, i)

            if not name then
                break
            end

            if name == 'runtimePass' and type(value) == 'table' then
                return value
            end
        end
    end
end

test('actual managed poll reuses guard eligibility and every later invocation reads again', function()
    for _, target in ipairs({ false, true }) do
        local c = make({ target = target, buttons = true })
        c.reset()
        c.tick()
        local n = c.snapshot()
        assert((n.UnitLevel or 0) <= 4, 'repeated eligibility level reads: ' .. tostring(n.UnitLevel))
        assert((n.UnitLevel or 0) >= 1, 'entry must remain fresh')
        c.reset()
        c.tick()
        assert((c.snapshot().UnitLevel or 0) >= 1, 'cross-poll fact retention')
    end
end)

test('positive managed route has a private guard while unknown build falls back', function()
    local c = make({ target = true })
    local a = c.a
    a.IsGlowing = function() return false end
    local guarded = false

    a.GlowNextSpell = function()
        local p = assert(currentPass())
        guarded = type(up(p.IsCurrent, 'contextGuard')) == 'function'
    end

    c.tick()
    assert(guarded, 'positive source-owned fastpath not exercised')
    local acquire = assert(up(a.EvaluateNextActionInternal, 'acquireEvaluationPass'))
    local nativeLevel = c.e.UnitLevel

    for _, level in ipairs({ -1, 0, math.huge, 0 / 0 }) do
        c.e.UnitLevel = function() return level end
        local p = assert(acquire(a, 0))
        assert(not up(p.IsCurrent, 'contextGuard'), 'unknown native level authorized snapshot')
    end

    c.e.UnitLevel = nativeLevel
    c.e.GetBuildInfo = function() return 'unknown' end
    c.reset()
    c.tick()
    assert((c.snapshot().UnitLevel or 0) > 4, 'unknown build authorized snapshot')
end)

test('nested evaluation starts fresh and retires its outer private pass', function()
    local c = make({ target = true })
    local a = c.a
    a.IsGlowing = function() return false end
    local outer, done

    a.GlowNextSpell = function()
        if not done then
            done = true
            outer = assert(currentPass())
            a:EvaluateNextAction()
        end
    end

    c.tick()
    assert(outer)
    local ok, why = outer:IsCurrent()
    assert(not ok and why == 'rotation-context-changed', 'outer evaluation survived newer evaluation')
end)

test('public RuntimePass retains fresh context observation', function()
    local c = make({})
    local p = assert(c.a:AcquireRotationRuntimePass(0))
    c.e.UnitLevel = function() return 12 end
    local ok, why = p:IsCurrent()
    assert(not ok and why == 'rotation-context-changed')
end)

test('public context replacement retains repeated fresh calls', function()
    local c = make({})
    local a = c.a
    local original = a.GetRotationContext
    local calls = 0

    a.GetRotationContext = function(self, spec)
        calls = calls + 1
        return original(self, spec)
    end

    c.tick()
    assert(calls > 4, 'override unexpectedly cached')
end)

test('level event retires captured pass before debug callback with old native level', function()
    local c = make({ target = true })
    local a = c.a
    local retired = false
    local fired = false
    a.ScheduleTimer = function() return {} end
    a.IsGlowing = function() return false end
    local original = a.GlowNextSpell

    a.GlowNextSpell = function(...)
        local p = currentPass()
        assert(p)

        if not fired then
            fired = true

            a.debug = function(self, format, event)
                if event == 'PLAYER_LEVEL_UP' then
                    local ok, why = p:IsCurrent()
                    retired = not ok and why == 'rotation-context-changed'
                end
            end

            a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP', 12)
        end

        return original(...)
    end

    c.tick()
    assert(fired and retired, 'snapshot survived synchronous event until handler callout')
end)

test('uncovered vehicle state stays fresh across publication callbacks', function()
    local c = make({ target = true })
    local a = c.a
    local vehicle = false
    local captured
    c.e.UnitHasVehicleUI = function() return vehicle end
    a.IsGlowing = function() return false end
    local old = a.GlowNextSpell

    a.GlowNextSpell = function(...)
        captured = currentPass()
        vehicle = true
        return old(...)
    end

    c.tick()
    assert(captured)
    local ok, why = captured:IsCurrent()
    assert(not ok and why == 'rotation-context-changed')
end)

test('native function replacement cannot preserve an obsolete snapshot', function()
    local c = make({ target = true })
    local a = c.a
    local captured
    a.IsGlowing = function() return false end
    local old = a.GlowNextSpell

    a.GlowNextSpell = function(...)
        captured = currentPass()
        c.e.UnitLevel = function() return 20 end
        return old(...)
    end

    c.tick()
    assert(captured)
    local ok, why = captured:IsCurrent()
    assert(not ok and why == 'rotation-context-changed')
end)

test('mutable private Context provider keeps fallback calls', function()
    local c = make({})
    local a = c.a
    local reader = assert(up(a:GetScopedRotationCoordinator().RuntimePass, 'libraryReader'))
    local old = reader.Context
    local calls = 0

    reader.Context = function(...)
        calls = calls + 1
        return old(...)
    end

    c.tick()
    assert(calls > 4)
end)

test('retired coordinator remains collectible after profile rebind', function()
    local c = make({})
    local a = c.a
    local weak = setmetatable({ a:GetScopedRotationCoordinator() }, { __mode = 'v' })
    assert(a:BindRotationProfile())

    -- LuaJIT traces retain constants in both baseline and candidate. Isolate Lua
    -- object ownership without changing whether compilation is enabled.
    if jit then
        jit.flush()
    end

    collectgarbage('collect')
    collectgarbage('collect')
    assert(weak[1] == nil, 'private method authority retained retired coordinator')
end)

finish()
