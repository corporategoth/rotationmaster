-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/rotation_execution.lua')

local function fixture(options)
    options = options or {}
    local c = make({ target = true, combat = options.combat == true })
    local a, e = c.a, c.e
    c.load('Platform/items.lua')
    c.load('Core/item_conditions.lua')
    a.RemoveAllCurrentGlows = function() end
    a.DestroyAllGlows = function() end
    local equipped = false
    local calls = { evaluations = 0, switches = 0 }
    e.C_Item = e.C_Item or {}

    e.C_Item.IsEquippedItem = function(id)
        assert(id == 12345)
        return equipped
    end

    local old = a.currentRotation
    local base = assert(a:GetEditableRotation(0, old))
    base.priority = 500
    base.switch = { type = 'SPELL_KNOWN', spell = 403 }
    local gear = assert(a:CloneDefaultRotation(0, 'rm.tbc.shaman.starter', 'Equipment refresh', { scope = 'class' }))
    local body = assert(a:GetEditableRotation(0, gear))
    body.priority = 1000
    body.switch = { type = 'EQUIPPED', item = { 12345 } }
    a.manualRotation = false
    a.db.profile.disable_autoswitch = false
    a:UpdateAutoSwitch()
    a:SwitchRotation()
    old = a.currentRotation
    local originalEvaluate = a.EvaluateNextAction
    local originalSwitch = a.SwitchRotation
    local originalEnable = a.EnableRotation

    a.EvaluateNextAction = function(self, ...)
        calls.evaluations = calls.evaluations + 1
        return originalEvaluate(self, ...)
    end

    a.SwitchRotation = function(self, ...)
        calls.switches = calls.switches + 1
        return originalSwitch(self, ...)
    end

    e.securecallfunction = function(fn, ...) return fn(...) end
    dofile('tests/fixtures/native_ui.lua')(e)
    local create = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = create(...)
        frame.events = {}

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:UnregisterEvent(event)
            self.events[event] = nil
        end

        return frame
    end

    c.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
    c.load('Libs/AceEvent-3.0/AceEvent-3.0.lua')
    local ace = e.LibStub('AceEvent-3.0')
    ace:Embed(a)
    local frame = ace.frame

    if options.family then
        local get = a.Platform.GetClientInfo

        a.Platform.GetClientInfo = function(self)
            local info = get(self)
            info.family = options.family
            return info
        end
    end

    if options.capability == 'missing' then
        e.C_EventUtils = nil
    else
        e.C_EventUtils = {
            IsEventValid = function(event)
                if event == 'PLAYER_EQUIPMENT_CHANGED' then
                    if options.onValid then
                        options.onValid(a)
                    end

                    if options.capability == 'throws' then
                        error('unavailable')
                    elseif options.capability == 'false' then
                        return false
                    elseif options.capability == 'malformed' then
                        return {}
                    end
                end

                return true
            end,
        }
    end

    a.UpdateSkill = function() end
    a.EnableRotation = function() end
    a.RefreshPreviewWindow = nil

    local function fire(...)
        if frame.events.PLAYER_EQUIPMENT_CHANGED then
            frame:GetScript('OnEvent')(frame, 'PLAYER_EQUIPMENT_CHANGED', ...)
        end
    end

    return {
        a = a,
        e = e,
        c = c,
        frame = frame,
        fire = fire,
        calls = calls,
        old = old,
        gear = gear,
        gearName = body.name,
        originalEnable = originalEnable,
        equipped = function(v)
            equipped = v
        end,
    }
end

local function enabled(options)
    local f = fixture(options)
    f.a:enable()
    return f
end

local function lifecycle(f)
    f.c.load('Platform/unit_level.lua')
    f.c.load('Core/level_conditions.lua')
    f.a.EnableRotation = f.originalEnable
    f.a.Fetch = function() end
    f.a.RefreshConfiguration = function() end
    f.a:InstallRotationProfileLifecycle()
end

local function addProfileGear(f)
    local key = assert(f.a:CloneDefaultRotation(0, 'rm.tbc.shaman.starter', f.gearName, { scope = 'class' }))
    local body = assert(f.a:GetEditableRotation(0, key))
    body.priority = 1000
    body.switch = { type = 'EQUIPPED', item = { 12345 } }
    f.a:UpdateAutoSwitch()
    f.a:SwitchRotation()
end

test('real equipment event refreshes existing equipment-conditioned selection after three stale polls', function()
    local f = enabled()
    assert(f.frame.events.PLAYER_EQUIPMENT_CHANGED, 'missing equipment subscription')
    f.equipped(true)

    for i = 1, 3 do
        f.c.tick()
    end

    assert(f.a.currentRotation == f.old, 'baseline poll unexpectedly reselected')
    f.fire(13, true)
    assert(f.a:GetRuntimeRotation(0, f.a.currentRotation).name == f.gearName)
    local gear = f.a.currentRotation
    f.equipped(false)

    for i = 1, 3 do
        f.c.tick()
    end

    assert(f.a.currentRotation == gear)
    f.fire(13, false)
    assert(f.a.currentRotation == f.old)
    assert(f.calls.evaluations >= 8, 'event did not immediately evaluate owned action')
end)

test('manual and autoswitch-disabled selections remain locked while the current owner refreshes', function()
    for _, key in ipairs({ 'manual', 'disabled' }) do
        local f = enabled()
        local a = f.a

        if key == 'manual' then
            f.e.LibStub('AceConsole-3.0').GetArgs = function(_, s)
                return s:match('^(%S+)'), (s:find(' ', 1, true) or #s) + 1
            end

            a:HandleCommand('set ' .. f.old)

            assert(
                a.manualRotation and a.db.profile.rotationChoicePreferences,
                'actual manual choice was not remembered'
            )
        else
            a.db.profile.disable_autoswitch = true
        end

        f.equipped(true)
        local n = f.calls.evaluations
        f.fire(13, true)
        assert(a.currentRotation == f.old, key)
        assert(f.calls.evaluations == n + 1, key .. ' current manual advice not refreshed')

        if key == 'manual' then
            a:HandleCommand('set auto')

            assert(
                not a.manualRotation and not a.db.profile.rotationChoicePreferences,
                'actual Auto command retained desired choice'
            )

            assert(
                a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName,
                'Auto did not immediately select equipped rotation'
            )

            f.equipped(false)
            n = f.calls.evaluations
            f.fire(13, false)

            assert(
                a.currentRotation == f.old and not a.manualRotation and f.calls.evaluations == n + 1,
                'Auto did not keep following equipment facts'
            )
        end
    end
end)

test('combat equipment notification remains advice-only and unavailable gear chooses existing fallback', function()
    local f = enabled({ combat = true })
    f.equipped(true)
    f.fire(16, true)
    assert(f.a:GetRuntimeRotation(0, f.a.currentRotation).name == f.gearName)
    f.e.C_Item.IsEquippedItem = function() return nil end
    f.fire(16, false)
    assert(f.a.currentRotation == f.old and not f.a.adviceErrorReport)
end)

test('missing unsupported throwing and malformed optional capability never subscribes', function()
    for _, kind in ipairs({ 'missing', 'false', 'throws', 'malformed' }) do
        local f = enabled({ capability = kind })
        assert(not f.frame.events.PLAYER_EQUIPMENT_CHANGED, kind)
        assert(f.frame.events.SPELLS_CHANGED and not f.a.adviceErrorReport)
    end

    for _, family in ipairs({ 'era', 'retail', 'forever', 'progression', 'unknown' }) do
        local f = enabled({ family = family })
        assert(not f.frame.events.PLAYER_EQUIPMENT_CHANGED, family)
    end
end)

test('disable unregisters and reenable restores exactly the new subscription', function()
    local f = enabled()
    assert(f.frame.events.PLAYER_EQUIPMENT_CHANGED)
    f.a:disable()
    assert(not f.frame.events.PLAYER_EQUIPMENT_CHANGED)
    local n = f.calls.evaluations
    f.a:PLAYER_EQUIPMENT_CHANGED('PLAYER_EQUIPMENT_CHANGED', 13, true)
    assert(f.calls.evaluations == n, 'direct retired dispatch revived advice')
    f.a:enable()
    assert(f.frame.events.PLAYER_EQUIPMENT_CHANGED)
    f.equipped(true)
    f.fire(13, true)
    assert(f.a:GetRuntimeRotation(0, f.a.currentRotation).name == f.gearName)
end)

test('capability callback retirement prevents equipment registration and old enable continuation', function()
    local f = fixture({
        onValid = function(a)
            a:disable()
        end,
    })

    f.a:enable()
    assert(not f.frame.events.PLAYER_EQUIPMENT_CHANGED)
    assert(not f.a.currentRotation)
end)

test('selection callbacks changing profile spec or active transition cannot trigger stale evaluation', function()
    for _, kind in ipairs({ 'profile', 'spec', 'transition', 'disable-reenable' }) do
        local f = enabled()

        f.a.SwitchRotation = function(a)
            if kind == 'profile' then
                a.db.profile = {}
            elseif kind == 'spec' then
                a.currentSpec = 1
            elseif kind == 'transition' then
                a:BeginActiveRotationTransition()
            else
                a:disable()
                a:enable()
            end
        end

        local n = f.calls.evaluations
        f.fire(13, true)
        assert(f.calls.evaluations == n, kind .. ' stale evaluation')
    end
end)

test('selection method lookup retirement cannot invoke the returned callback', function()
    local f = enabled()
    local called = false
    f.a.SwitchRotation = nil
    local old = getmetatable(f.a)

    setmetatable(f.a, {
        __index = function(_, key)
            if key == 'SwitchRotation' then
                f.a:disable()

                return function()
                    called = true
                end
            end

            return old and old.__index and old.__index[key]
        end,
    })

    f.fire(13, true)
    assert(not called, 'retired lookup invoked selected function')
end)

test('current coordinator replacement during selection cannot continue evaluation', function()
    local f = enabled()

    f.a.SwitchRotation = function(a)
        a.GetScopedRotationCoordinator = function() return {} end
    end

    local n = f.calls.evaluations
    f.fire(13, true)
    assert(f.calls.evaluations == n, 'replaced coordinator still evaluated')
end)

test('equipment notification invalidates the existing publication context before selection callback', function()
    local f = enabled()
    local acquire

    for i = 1, 30 do
        local name, value = debug.getupvalue(f.a.EvaluateNextActionInternal, i)

        if not name then
            break
        end

        if name == 'acquireEvaluationPass' then
            acquire = value
        end
    end

    assert(acquire)
    local pass, why, guard = acquire(f.a, f.a.currentSpec)
    assert(pass, why)
    assert(type(guard) == 'function' and guard())
    local reached, stillCurrent, retirementReason = false, nil, nil

    f.a.SwitchRotation = function()
        reached = true
        stillCurrent, retirementReason = guard()
    end

    f.fire(13, true)
    assert(reached, 'equipment handler not dispatched')

    assert(
        not stillCurrent and retirementReason == 'rotation-context-changed',
        'equipment event left old publication context current'
    )

    assert(not f.a.adviceErrorReport)
end)

test('empty eligible order retires current selection without evaluating a missing owner', function()
    local f = enabled()
    f.a.autoswitchRotation = {}
    local n = f.calls.evaluations
    f.fire(13, false)
    assert(f.a.currentRotation == nil and f.calls.evaluations == n and not f.a.adviceErrorReport)
end)

test('framework-disabled and foreign direct calls cannot refresh owned selection', function()
    local f = enabled()
    f.a.enabledState = false
    local n = f.calls.evaluations
    f.a:PLAYER_EQUIPMENT_CHANGED('PLAYER_EQUIPMENT_CHANGED', 13, true)
    assert(f.calls.evaluations == n)

    local foreign = {
        db = f.a.db,
        currentSpec = f.a.currentSpec,
        currentRotation = f.a.currentRotation,
        debug = function() end,
    }

    f.a.PLAYER_EQUIPMENT_CHANGED(foreign, 'PLAYER_EQUIPMENT_CHANGED', 13, true)
    assert(f.calls.evaluations == n)
end)

test('actual profile coordinator rebind during selection retires the outer evaluation', function()
    local f = enabled()
    local before = f.a:GetScopedRotationCoordinator()

    f.a.SwitchRotation = function(a)
        assert(a:BindRotationProfile())
        assert(a:GetScopedRotationCoordinator() ~= before)
    end

    local n = f.calls.evaluations
    f.fire(13, true)
    assert(f.calls.evaluations == n and not f.a.adviceErrorReport)
end)

test('evaluate method lookup cannot call a function returned after disable retirement', function()
    local f = enabled()
    local called = false
    f.a.EvaluateNextAction = nil

    setmetatable(f.a, {
        __index = function(_, key)
            if key == 'EvaluateNextAction' then
                f.a:disable()

                return function()
                    called = true
                end
            end
        end,
    })

    f.fire(13, true)
    assert(not called and not f.a.adviceErrorReport)
end)

test('capability lookup retirement prevents calling its returned validator', function()
    local f = fixture()
    local called = false

    f.e.C_EventUtils = setmetatable({}, {
        __index = function(_, key)
            assert(key == 'IsEventValid')
            f.a:disable()

            return function()
                called = true
                return true
            end
        end,
    })

    f.a:enable()
    assert(not called and not f.frame.events.PLAYER_EQUIPMENT_CHANGED)
end)

test('foreign equipment calls cannot retire an owned publication context', function()
    local f = enabled()
    local acquire

    for i = 1, 30 do
        local name, value = debug.getupvalue(f.a.EvaluateNextActionInternal, i)

        if not name then
            break
        end

        if name == 'acquireEvaluationPass' then
            acquire = value
        end
    end

    local pass, why, guard = acquire(f.a, f.a.currentSpec)
    assert(pass, why)
    assert(guard())

    local foreign = {
        db = f.a.db,
        currentSpec = f.a.currentSpec,
        currentRotation = f.a.currentRotation,
        debug = function() end,
    }

    f.a.PLAYER_EQUIPMENT_CHANGED(foreign, 'PLAYER_EQUIPMENT_CHANGED', 13, true)
    assert(guard(), 'foreign call retired current publication context')
end)

test('fresh bound profile retains enable-owned equipment subscription', function()
    local f = enabled()
    local a = f.a
    local old = a.db.profile
    local newer = {}

    for k, v in pairs(old) do
        newer[k] = v
    end

    setmetatable(newer, getmetatable(old))
    a.db.profile = newer
    assert(a:BindRotationProfile())
    a.manualRotation = false
    a.autoswitchRotation = {}
    a:UpdateAutoSwitch()
    a:SwitchRotation()
    assert(a.currentRotation and f.frame.events.PLAYER_EQUIPMENT_CHANGED)
    f.equipped(true)
    local n = f.calls.switches
    f.fire(13, true)
    assert(f.calls.switches == n + 1, 'new profile event rejected')
    assert(a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName)
end)

test('actual AceDB profile switch copy and reset keep fresh equipment dispatch active', function()
    local f = enabled()
    local a = f.a
    lifecycle(f)

    for _, operation in ipairs({ 'switch', 'copy', 'reset' }) do
        if operation == 'switch' then
            a.db:SetProfile('Equipment Other')
        elseif operation == 'copy' then
            a.db:CopyProfile('Default')
        else
            a.db:ResetProfile()
        end

        assert(a.currentRotation and f.frame.events.PLAYER_EQUIPMENT_CHANGED, operation .. ' active profile lost')
        addProfileGear(f)
        f.equipped(true)
        local n = f.calls.switches
        f.fire(13, true)
        assert(f.calls.switches == n + 1, operation .. ' did not dispatch')

        assert(
            a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName,
            operation .. ' did not choose equipped clone'
        )

        f.equipped(false)
        f.fire(13, false)
        assert(a:GetRuntimeRotation(0, a.currentRotation).name ~= f.gearName, operation .. ' did not choose fallback')
    end
end)

test('actual AceDB profile callback during selection retires outer advice but fresh next event works', function()
    local f = enabled()
    local a = f.a
    lifecycle(f)
    local switch = a.SwitchRotation
    local replaced = false

    a.SwitchRotation = function(self, ...)
        if not replaced then
            replaced = true
            self.db:SetProfile('Equipment Reentrant')
            return
        end

        return switch(self, ...)
    end

    local n = f.calls.evaluations
    f.fire(13, true)
    assert(replaced and a.currentRotation and f.calls.evaluations == n, 'old profile evaluated after callback')
    addProfileGear(f)
    f.equipped(true)
    f.fire(13, true)

    assert(
        a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName and f.calls.evaluations == n + 1,
        'fresh profile dispatch stayed retired'
    )
end)

test('wrapped debug profile publication retires old event before selection and permits fresh event', function()
    local f = enabled()
    local a = f.a
    lifecycle(f)
    local changed = false

    a.debug = function(self)
        if changed then
            return
        end

        changed = true
        self.debug = function() end
        self.db:SetProfile('Equipment Debug Profile')
    end

    local n = f.calls.evaluations
    f.fire(13, true)
    assert(changed and a.currentRotation and f.calls.evaluations == n, 'wrapped old event evaluated new profile')
    addProfileGear(f)
    f.equipped(true)
    f.fire(13, true)
    assert(a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName and f.calls.evaluations == n + 1)
end)

test('wrapped debug disable and reenable retires captured event before new selection', function()
    local f = enabled()
    local a = f.a
    local changed = false

    a.debug = function(self)
        if changed then
            return
        end

        changed = true
        self.debug = function() end
        self:disable()
        self:enable()
    end

    local n = f.calls.evaluations
    local switches = f.calls.switches
    f.fire(13, true)

    assert(
        changed and f.calls.evaluations == n and f.calls.switches == switches,
        'old wrapper revived under new enable'
    )

    f.equipped(true)
    f.fire(13, true)
    assert(a:GetRuntimeRotation(0, a.currentRotation).name == f.gearName and f.calls.evaluations == n + 1)
end)

finish()
