-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/active_runtime_plan.lua'))
local s = h:read('*a')
h:close()
local fixture = assert(loadstring(assert(s:match('^(.-)\ntest%(')) .. '\nreturn fixture', '@rebind-plan-fixture'))()

local function live(target)
    local c, a, get = fixture(target)
    local b, current, token, handled = get(a, 0, a.currentRotation)
    assert(handled and b and current(), 'initial actual saved-copy plan was not managed')
    return c, a, get, b, current, token
end

local function load(c, a, path)
    local f = assert(loadfile(path))
    setfenv(f, c.e)
    f('rotationmaster', a)
end

local function functionSource()
    return {
        description = 'Unrelated utility',
        args = { { name = 'value', type = 'number', description = 'Input' } },
        returns = { { type = 'number', description = 'Output' } },
        code = 'return value + 1',
        bindings = {},
    }
end

test('supported profile rebind remaps key and readmits healthy active saved rotation', function()
    local c, a, get, b, current = live(true)
    local old = a.currentRotation
    assert(a:BindRotationProfile())
    assert(a.currentRotation and a.currentRotation ~= old and not current(), 'rebind did not remap/retire')
    local nextBody, nextCurrent, _, handled = get(a, 0, a.currentRotation)
    assert(handled and nextBody and nextCurrent(), 'healthy rebound active selection remained fallback')
    assert(nextBody.name == b.name and a:GetActiveRuntimePlanDiagnostic().currentRoute == 'managed')
end)

test('condition-consumer availability refresh does not borrow the selected runtime asset', function()
    local _, a, get = live(true)
    a:RefreshConditionConsumers()
    local b, current, _, handled = get(a, 0, a.currentRotation)
    assert(handled and b and current(), 'availability-only refresh permanently borrowed the runtime asset')
end)

test('actual unrelated utility Apply and removal preserve prepared admission', function()
    local c, a, get = live(true)

    for _, path in ipairs({ 'UI/settings_draft.lua', 'Core/custom_authoring.lua', 'Core/functions.lua' }) do
        load(c, a, path)
    end

    assert(a:InstallCustomFunction('UNRELATED_PLAN_HELPER', functionSource()))
    local b, current, _, handled = get(a, 0, a.currentRotation)
    assert(handled and b and current(), 'utility Apply forced persistent fallback')
    local source = a.db.global.custom_functions.UNRELATED_PLAN_HELPER
    assert(a:RemoveCustomFunction('UNRELATED_PLAN_HELPER', source))
    local nextBody, nextCurrent, _, nextHandled = get(a, 0, a.currentRotation)
    assert(nextHandled and nextBody and nextCurrent(), 'utility removal forced persistent fallback')
end)

test('explicit public runtime borrow still retires private admission and preserves mutable asset', function()
    local c, a, get, body, current = live(true)
    local pass = assert(a:AcquireRotationRuntimePass(0))
    local public = assert(pass:Get(a.currentRotation))
    assert(public ~= body and not current())
    local changed = 0

    for _, row in ipairs(public.rotation) do
        if row.action == 403 then
            row.action = 8042
            changed = changed + 1
        end
    end

    assert(changed > 0)
    c.tick()
    assert(a.currentSpell == 8042, 'public runtime mutation stopped affecting actual advice')
    local _, _, _, handled = get(a, 0, a.currentRotation)
    assert(not handled, 'explicit public borrow was silently cleared')

    assert(
        assert(a:AcquireRotationRuntimePass(0)):Get(a.currentRotation) == public,
        'public mutable runtime asset was replaced'
    )
end)

test('owned rebind never calls the public getter merely to rediscover its reference', function()
    local _, a, get, _, current = live(true)
    local calls = 0

    a.GetRuntimeRotation = function()
        calls = calls + 1
        error('owned rebind exposed public data')
    end

    assert(a:BindRotationProfile())
    assert(calls == 0 and not current())
    local b, nextCurrent, _, handled = get(a, 0, a.currentRotation)
    assert(handled and b and nextCurrent())
end)

test('legacy selection without owned active state retains its actual public getter', function()
    local _, a, get = live(true)
    local key = a.currentRotation
    local pending = a:BeginActiveRotationTransition()
    assert(a:RetireActiveRotationTransition(pending))
    a.currentRotation = key
    local original = a.GetRuntimeRotation
    local calls = 0

    a.GetRuntimeRotation = function(self, ...)
        calls = calls + 1
        return original(self, ...)
    end

    assert(a:BindRotationProfile())
    assert(calls == 1 and a.currentRotation, 'legacy getter or selection was lost')
    local _, _, _, handled = get(a, 0, a.currentRotation)
    assert(not handled, 'real canonical exposure was cleared')
end)

test('mismatched profile spec and ID cannot reuse an old active reference', function()
    for _, kind in ipairs({ 'profile', 'spec', 'id' }) do
        local _, a = live(true)
        local prepare

        a:BindActiveRotationPublication(function(_, _, value)
            prepare = value
        end)

        if kind == 'profile' then
            local old = a.db.profile
            a.db.profile = {}
            assert(a.db.profile ~= old)
        elseif kind == 'spec' then
            a.currentSpec = 1
        else
            a.currentRotation = 'different-key'
        end

        local calls = 0

        a.GetRuntimeRotation = function()
            calls = calls + 1
            return nil
        end

        local _, reference = prepare('Default')

        assert(
            calls == 1 and reference == nil,
            kind .. ' reused stale active reference calls=' .. tostring(calls) .. ' reference=' .. tostring(reference)
        )
    end
end)

test('legacy getter reentry cannot publish the superseded rebind preparation', function()
    local _, a = live(true)
    local key = a.currentRotation
    local pending = a:BeginActiveRotationTransition()
    assert(a:RetireActiveRotationTransition(pending))
    a.currentRotation = key
    local prepare

    a:BindActiveRotationPublication(function(_, _, value)
        prepare = value
    end)

    local newest

    a.GetRuntimeRotation = function()
        newest = a:BeginActiveRotationTransition()
        return { name = 'Stale', rotation = {}, cooldowns = {} }
    end

    local ticket, reference = prepare('Default')

    assert(
        ticket == nil and reference == nil and newest and a:IsActiveRotationTransitionCurrent(newest),
        'stale outer operation survived'
    )
end)

test('nested rebind from a real context provider leaves the newer coordinator and plan current', function()
    local c, a, get, _, current = live(true)
    local original = c.e.UnitLevel
    local entered, inner, key, coordinator

    c.e.UnitLevel = function(...)
        if not entered then
            entered = true
            inner = a:BindRotationProfile()
            key = a.currentRotation
            coordinator = a:GetScopedRotationCoordinator()
        end

        return original(...)
    end

    a:BindRotationProfile()

    assert(
        entered
            and inner
            and a.currentRotation == key
            and a:GetScopedRotationCoordinator() == coordinator
            and not current()
    )

    local b, nextCurrent, _, handled = get(a, 0, a.currentRotation)
    assert(handled and b and nextCurrent(), 'newer nested rebind did not admit')
end)

test('canonical exposure remains ineligible across a supported rebind', function()
    local c, a, get = live(true)
    local body = assert(a:GetEditableRotation(0, a.currentRotation))
    body.description = 'Supported canonical edit'
    local changed = 0

    for _, row in ipairs(body.rotation) do
        if row.action == 403 then
            row.action = 8042
            changed = changed + 1
        end
    end

    assert(changed > 0)
    assert(a:BindRotationProfile())
    c.tick()
    assert(a.currentSpell == 8042, 'canonical edit did not affect rebound advice')
    local _, _, _, handled = get(a, 0, a.currentRotation)
    assert(not handled, 'rebind erased canonical exposure')
end)

test('availability refresh cannot clear a preexisting real public borrow', function()
    local _, a, get = live(true)
    assert(assert(a:AcquireRotationRuntimePass(0)):Get(a.currentRotation))
    a:RefreshConditionConsumers()
    local _, _, _, handled = get(a, 0, a.currentRotation)
    assert(not handled, 'availability refresh erased public borrow')
end)

test('actual unrelated condition disable and enable Apply preserve admission', function()
    local c, a, get = live(true)

    for _, path in ipairs({
        'UI/settings_draft.lua',
        'Core/custom_authoring.lua',
        'Core/custom_condition_services.lua',
        'Core/custom_condition_data.lua',
        'Core/category_data.lua',
        'Core/functions.lua',
    }) do
        load(c, a, path)
    end

    local source = {
        description = 'Unrelated condition',
        icon = 'Interface\\Icons\\INV_Misc_QuestionMark',
        fields = {},
        valid = 'return true',
        evaluate = 'return true',
        print = 'return "Unrelated"',
        widget = '',
        help = '',
        on_register = '',
        on_unregister = '',
        bindings = {},
        disabled = true,
    }

    assert(a:InstallCustomCondition('UNRELATED_PLAN_CONDITION', source, nil))
    local b, current, _, handled = get(a, 0, a.currentRotation)
    assert(handled and b and current(), 'condition disable Apply forced fallback')
    local old = a.db.global.custom_conditions.UNRELATED_PLAN_CONDITION
    local enabled = a:CopySettingsData(old)
    enabled.disabled = nil

    assert(a:InstallCustomCondition(
        'UNRELATED_PLAN_CONDITION',
        enabled,
        a.conditionDefinitions.UNRELATED_PLAN_CONDITION,
        old
    ))

    local nextBody, nextCurrent, _, nextHandled = get(a, 0, a.currentRotation)
    assert(nextHandled and nextBody and nextCurrent(), 'condition enable Apply forced fallback')
end)

local function quietRefresh(a, events)
    a.UpdateAutoSwitch = function()
        events[#events + 1] = 'update'
    end

    a.SwitchRotation = function()
        events[#events + 1] = 'switch'
    end

    a.DisableRotation = function()
        events[#events + 1] = 'disable'
    end
end

test('public Acquire replacement false result retains exact eager call and disable order', function()
    local _, a = live(true)
    local events = {}
    quietRefresh(a, events)

    a.AcquireRotationRuntimePass = function()
        events[#events + 1] = 'acquire'

        return {
            Get = function()
                events[#events + 1] = 'get'
                return false
            end,
        }
    end

    a:RefreshConditionConsumers()
    assert(table.concat(events, ',') == 'update,acquire,get,disable,switch', table.concat(events, ','))
end)

test('public Acquire errors propagate once without replaying availability work', function()
    local _, a = live(true)
    local events = {}
    quietRefresh(a, events)
    local marker = {}

    a.AcquireRotationRuntimePass = function()
        events[#events + 1] = 'acquire'
        error(marker, 0)
    end

    local ok, why = pcall(a.RefreshConditionConsumers, a)
    assert(not ok and why == marker and table.concat(events, ',') == 'update,acquire')
end)

test('uncertain coordinator getter executes the original lookup sequence once', function()
    local _, a = live(true)
    local events = {}
    quietRefresh(a, events)
    local coordinator = a.GetScopedRotationCoordinator
    local meta = getmetatable(a)
    local copied = {}

    for k, v in pairs(meta or {}) do
        copied[k] = v
    end

    local priorIndex = copied.__index
    a.GetScopedRotationCoordinator = nil

    copied.__index = function(t, k)
        if k == 'GetScopedRotationCoordinator' then
            events[#events + 1] = 'lookup'

            return function(self)
                events[#events + 1] = 'coordinator'
                return coordinator(self)
            end
        end

        if type(priorIndex) == 'function' then
            return priorIndex(t, k)
        elseif type(priorIndex) == 'table' then
            return priorIndex[k]
        end
    end

    setmetatable(a, copied)

    a.AcquireRotationRuntimePass = function()
        events[#events + 1] = 'acquire'

        return {
            Get = function()
                events[#events + 1] = 'get'
                return {}
            end,
        }
    end

    a:RefreshConditionConsumers()

    assert(table.concat(events, ',') == 'update,lookup,lookup,coordinator,acquire,get,switch', table.concat(
        events,
        ','
    ))
end)

test('nil public pass retains original runtime-getter fallback and false availability', function()
    local _, a = live(true)
    local events = {}
    quietRefresh(a, events)

    a:GetScopedRotationCoordinator().RuntimePass = function()
        events[#events + 1] = 'pass'
        return nil
    end

    a.GetRuntimeRotation = function()
        events[#events + 1] = 'runtime'
        return false
    end

    a:RefreshConditionConsumers()
    assert(table.concat(events, ',') == 'update,pass,runtime,disable,switch', table.concat(events, ','))
end)

finish()
