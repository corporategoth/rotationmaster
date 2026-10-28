-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Boss-mod adapter and conditions against mocked DBM/BigWigs providers that
-- follow the inspected public contracts (see Integrations/encounters.lua).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function loadAdapter(addon, env)
    local chunk = assert(loadfile('Integrations/encounters.lua'))
    setfenv(chunk, env or setmetatable({}, { __index = _G }))
    chunk('RotationMaster', addon)
    assert(type(addon.Integrations.NewEncounterTimers) == 'function', 'factory must be published')
end

-- DBM: colon calls, callbacks receive (event, ...), unregister by function.
local function dbmProvider()
    local p = { callbacks = {}, registers = 0, unregisters = 0 }
    p.api = {}

    function p.api:RegisterCallback(event, f)
        assert(
            self == p.api and type(event) == 'string' and type(f) == 'function',
            'DBM registration must be a colon call'
        )

        p.registers = p.registers + 1
        p.callbacks[event] = p.callbacks[event] or {}
        table.insert(p.callbacks[event], f)
    end

    function p.api:UnregisterCallback(event, f)
        assert(self == p.api and type(f) == 'function')
        p.unregisters = p.unregisters + 1
        local list = p.callbacks[event] or {}

        for i = #list, 1, -1 do
            if list[i] == f then
                table.remove(list, i)
            end
        end
    end

    function p:fire(event, ...)
        for _, f in ipairs(self.callbacks[event] or {}) do
            f(event, ...)
        end
    end

    function p:count()
        local n = 0

        for _, list in pairs(self.callbacks) do
            n = n + #list
        end

        return n
    end

    return p
end

-- BigWigs: dot call with an owner table that must not be BigWigsLoader.
local function bigwigsProvider()
    local p = { map = {}, registers = 0 }
    p.api = {}

    p.api.RegisterMessage = function(owner, event, f)
        assert(
            owner ~= p.api and type(owner) == 'table' and type(event) == 'string' and type(f) == 'function',
            'BigWigs registration needs a private owner'
        )

        p.registers = p.registers + 1
        p.map[event] = p.map[event] or {}
        p.map[event][owner] = f
    end

    p.api.UnregisterMessage = function(owner, event)
        assert(owner ~= p.api)

        if p.map[event] then
            p.map[event][owner] = nil
        end
    end

    function p:fire(event, ...)
        for _, f in pairs(self.map[event] or {}) do
            f(event, ...)
        end
    end

    function p:count()
        local n = 0

        for _, owners in pairs(self.map) do
            for _ in pairs(owners) do
                n = n + 1
            end
        end

        return n
    end

    return p
end

local function service(options)
    local state = {
        now = 100,
        family = 'tbc',
        loaded = { ['DBM-Core'] = true, BigWigs = true },
        resolves = 0,
        changes = {},
    }

    state.dbm = dbmProvider()
    state.bw = bigwigsProvider()
    local addon = {}
    loadAdapter(addon)

    local opts = {
        resolve = function(id)
            state.resolves = state.resolves + 1

            return {
                loaded = state.loaded[id],
                family = state.family,
                version = id == 'BigWigs' and 'v427.7' or '12.1.17',
                api = id == 'BigWigs' and state.bw.api or state.dbm.api,
            }
        end,
        now = function() return state.now end,
        onChange = function(status)
            state.changes[#state.changes + 1] = status
        end,
    }

    for k, v in pairs(options or {}) do
        opts[k] = v
    end

    return addon.Integrations.NewEncounterTimers(opts), state
end

test('a disabled adapter resolves nothing and every read is unavailable', function()
    local s, st = service()
    assert(st.resolves == 0 and s:GetStatus().state == 'disabled')
    local active, _, _, why = s:GetEncounter()
    assert(active == nil and why == 'integration-disabled')
    local remaining, reason = s:GetTimerRemaining(123)
    assert(remaining == nil and reason == 'integration-disabled')
    assert(#s:ListTimers() == 0 and st.dbm:count() == 0 and st.bw:count() == 0)
    assert(select(2, s:SetProvider('Recount')) == 'invalid-provider')
end)

test('DBM binds every documented callback and reports encounter, stage and liveness', function()
    local s, st = service()
    assert(s:SetProvider('DBM-Core'))
    local status = s:GetStatus()
    assert(status.state == 'available' and status.provider == 'DBM-Core' and status.version == '12.1.17')
    assert(st.dbm:count() == 9)
    assert(s:GetEncounter() == false)

    local mod = {
        id = 'Attumen',
        encounterId = 652,
        inCombat = true,
        localization = { general = { name = 'Attumen the Huntsman' } },
    }

    st.dbm:fire('DBM_Pull', mod, 0, false, 100)
    local active, id, stage, name = s:GetEncounter()
    assert(active == true and id == 652 and stage == 1 and name == 'Attumen the Huntsman')
    st.dbm:fire('DBM_SetStage', mod, 'Attumen', 2, 652, 1)
    assert(select(3, s:GetEncounter()) == 2)
    st.dbm:fire('DBM_SetStage', { inCombat = false }, 'Other', 3, 1)
    assert(select(3, s:GetEncounter()) == 2, 'a stale mod must not change the stage')
    mod.inCombat = false
    assert(s:GetEncounter() == false, 'combat end without a kill/wipe callback must end the encounter')
    -- A stage report mid-fight from an engaged mod adopts it.
    local late = { id = 'Moroes', inCombat = true, encounterId = 653 }
    st.dbm:fire('DBM_SetStage', late, 'Moroes', 1.5, 653, 1)
    active, id, stage = s:GetEncounter()
    assert(active and id == 653 and stage == 1.5)
    st.dbm:fire('DBM_Wipe', late)
    assert(s:GetEncounter() == false)
    st.dbm:fire('DBM_Pull', mod)
    mod.inCombat = true
    st.dbm:fire('DBM_Kill', mod)
    assert(s:GetEncounter() == false)
end)

test('DBM timers count down lazily, follow update pause resume stop, and ignore bars without a spell', function()
    local s, st = service()
    s:SetProvider('DBM-Core')
    st.dbm:fire('DBM_TimerBegin', 't1', 'Shadow Cleave', 20, 'icon', 'cd', 29832, 1, 'Attumen')
    st.dbm:fire('DBM_TimerBegin', 't2', 'Charge', 8, 'icon', 'cd', '29847', 1, 'Attumen')
    st.dbm:fire('DBM_TimerBegin', 'pull', 'Pull in', 10, 'icon', 'extratimer', nil, 0, nil)
    assert(s:GetTimerRemaining(29832) == 20 and s:GetTimerRemaining(29847) == 8 and s:GetTimerRemaining(1) == false)
    st.now = 105
    assert(s:GetTimerRemaining(29832) == 15)
    assert(s:GetTimerRemaining(29832, 107) == 13, 'the evaluation clock is used when supplied')
    st.dbm:fire('DBM_TimerUpdate', 't1', 2, 30)
    assert(s:GetTimerRemaining(29832) == 28)
    st.dbm:fire('DBM_TimerPause', 't1')
    st.now = 150
    assert(s:GetTimerRemaining(29832) == 28, 'a paused timer keeps its remaining time')
    st.dbm:fire('DBM_TimerResume', 't1')
    st.now = 160
    assert(s:GetTimerRemaining(29832) == 18)
    assert(s:GetTimerRemaining(29847) == false, 'an expired timer is dropped lazily')
    local rows = s:ListTimers()
    assert(#rows == 1 and rows[1].spellId == 29832 and rows[1].remaining == 18)
    st.dbm:fire('DBM_TimerStop', 't1')
    assert(s:GetTimerRemaining(29832) == false)

    for _, bad in ipairs({ 0, -1, 0 / 0, math.huge, 4000, '20' }) do
        st.dbm:fire('DBM_TimerBegin', 'bad', 'x', bad, 'i', 'cd', 5)
        assert(s:GetTimerRemaining(5) == false)
    end

    st.dbm:fire('DBM_TimerBegin', 'id', 'x', 10, 'i', 'cd', 5)
    st.dbm:fire('DBM_TimerBegin', 'id', 'x', 10, 'i', 'cd', 'ej123')
    assert(s:GetTimerRemaining(5) == false, 'restarting an id without a spell retires the old one')
end)

test('the timer cache is bounded and evicts the soonest timer', function()
    local s, st = service()
    s:SetProvider('DBM-Core')

    for i = 1, 70 do
        st.dbm:fire('DBM_TimerBegin', 't' .. i, 'x', i, 'i', 'cd', 1000 + i)
    end

    local n = 0

    for i = 1, 70 do
        if s:GetTimerRemaining(1000 + i) then
            n = n + 1
        end
    end

    assert(n == 64 and s:GetTimerRemaining(1001) == false and s:GetTimerRemaining(1070) == 70)
end)

test('BigWigs uses a private owner and module-scoped bars, stages and engage lifecycle', function()
    local s, st = service()
    assert(s:SetProvider('BigWigs'))
    assert(s:GetStatus().state == 'available' and st.bw:count() == 10 and st.dbm:count() == 0)
    local boss = { moduleName = 'Nightbane', displayName = 'Nightbane', engageId = 662, isEngaged = true }
    st.bw:fire('BigWigs_OnBossEngage', boss)
    local active, id, stage, name = s:GetEncounter()
    assert(active and id == 662 and stage == 1 and name == 'Nightbane')
    st.bw:fire('BigWigs_SetStage', boss, 2)
    assert(select(3, s:GetEncounter()) == 2)
    st.bw:fire('BigWigs_StartBar', boss, 36922, 'Bellowing Roar', 30, 'icon', true, 30)
    st.bw:fire('BigWigs_StartBar', boss, 'stages', 'Air phase', 40, 'icon')
    assert(s:GetTimerRemaining(36922) == 30)
    local other = { moduleName = 'Other' }
    st.bw:fire('BigWigs_StopBar', other, 'Bellowing Roar')
    assert(s:GetTimerRemaining(36922) == 30, 'another module cannot stop this bar')
    st.bw:fire('BigWigs_PauseBar', boss, 'Bellowing Roar')
    st.now = 140
    assert(s:GetTimerRemaining(36922) == 30)
    st.bw:fire('BigWigs_ResumeBar', boss, 'Bellowing Roar')
    st.now = 150
    assert(s:GetTimerRemaining(36922) == 20)
    st.bw:fire('BigWigs_StopBar', boss, 'Bellowing Roar')
    assert(s:GetTimerRemaining(36922) == false)
    st.bw:fire('BigWigs_StartBar', boss, 36922, 'Bellowing Roar', 30, 'icon')
    st.bw:fire('BigWigs_StopBars', boss)
    assert(s:GetTimerRemaining(36922) == false)
    st.bw:fire('BigWigs_StartBar', boss, 36922, 'Bellowing Roar', 30, 'icon')
    st.bw:fire('BigWigs_OnBossWin', boss)
    assert(s:GetEncounter() == false and s:GetTimerRemaining(36922) == false)
    st.bw:fire('BigWigs_OnBossEngage', boss)
    boss.isEngaged = nil
    assert(s:GetEncounter() == false, 'a disabled module is not an encounter')
end)

test('switching or disabling providers detaches every callback and clears observations', function()
    local s, st = service()
    s:SetProvider('DBM-Core')
    st.dbm:fire('DBM_Pull', { inCombat = true, encounterId = 1 })
    st.dbm:fire('DBM_TimerBegin', 't', 'x', 10, 'i', 'cd', 7)
    s:SetProvider('BigWigs')
    assert(st.dbm:count() == 0 and st.dbm.unregisters == 9 and st.bw:count() == 10)
    assert(s:GetEncounter() == false and s:GetTimerRemaining(7) == false)
    s:SetProvider(nil)
    assert(st.bw:count() == 0 and s:GetStatus().state == 'disabled')
    assert(select(4, s:GetEncounter()) == 'integration-disabled')
    s:SetProvider('DBM-Core')
    s:Dispose()
    assert(st.dbm:count() == 0 and select(2, s:SetProvider('DBM-Core')) == 'disposed')
end)

test('missing, unsupported and malformed providers stay unavailable with an honest status', function()
    local s, st = service()
    st.loaded['DBM-Core'] = false
    s:SetProvider('DBM-Core')
    assert(s:GetStatus().state == 'missing' and not s:IsBound())
    assert(select(4, s:GetEncounter()) == 'provider-missing')
    st.loaded['DBM-Core'] = true
    s:Refresh()
    assert(s:GetStatus().state == 'available' and s:IsBound() and st.dbm:count() == 9)
    s:Refresh()
    assert(st.dbm:count() == 9, 'a bound refresh must not register twice')

    for _, family in ipairs({ 'retail', 'forever', 'unknown' }) do
        local s2, st2 = service()
        st2.family = family
        s2:SetProvider('BigWigs')

        assert(
            s2:GetStatus().state == 'incompatible'
                and s2:GetStatus().reason == 'unsupported-client'
                and st2.bw:count() == 0
        )
    end

    local s3, st3 = service()
    st3.dbm.api.RegisterCallback = nil
    s3:SetProvider('DBM-Core')
    assert(s3:GetStatus().state == 'incompatible' and s3:GetStatus().reason == 'invalid-registration')

    local s4 = service({
        resolve = function()
            error('PRIVATE')
        end,
    })

    s4:SetProvider('DBM-Core')
    assert(s4:GetStatus().state == 'error' and s4:GetStatus().reason == 'resolver-error')
    local s5, st5 = service()

    st5.dbm.api.RegisterCallback = function()
        error('nope')
    end

    s5:SetProvider('DBM-Core')
    assert(s5:GetStatus().state == 'error' and s5:GetStatus().reason == 'registration-error')
end)

test('a failing or restricted callback faults the adapter instead of raising into the provider', function()
    local secret = {}
    local s, st = service({ readable = function(v) return not rawequal(v, secret) end })
    s:SetProvider('DBM-Core')
    st.dbm:fire('DBM_TimerBegin', 't', 'x', 10, 'i', 'cd', 7)
    assert(s:GetTimerRemaining(7) == 10)
    st.dbm:fire('DBM_TimerBegin', secret, 'x', 10, 'i', 'cd', 8)
    assert(s:GetStatus().state == 'error' and s:GetStatus().reason == 'restricted-value')
    assert(s:GetTimerRemaining(7) == nil, 'observations are cleared after a fault')
    st.dbm:fire('DBM_TimerBegin', 't', 'x', 10, 'i', 'cd', 7)
    assert(s:GetTimerRemaining(7) == nil, 'a faulted handler ignores later callbacks')
    local s2, st2 = service({ now = function() return 0 / 0 end })
    s2:SetProvider('BigWigs')
    st2.bw:fire('BigWigs_StartBar', {}, 1, 'x', 5)
    assert(s2:GetStatus().reason == 'callback-error' or s2:GetStatus().reason == 'invalid-clock')
    -- Re-selecting the same provider (a profile sync) re-attaches a faulted binding.
    s:SetProvider('DBM-Core')
    assert(s:GetStatus().state == 'available' and s:IsBound())
    st.dbm:fire('DBM_TimerBegin', 't', 'x', 10, 'i', 'cd', 7)
    assert(s:GetTimerRemaining(7) == 10)
end)

test('status changes are published once per transition and never leak provider objects', function()
    local s, st = service()
    s:SetProvider('DBM-Core')
    s:SetProvider('DBM-Core')
    assert(#st.changes == 1 and st.changes[1].state == 'available')

    for _, status in ipairs(st.changes) do
        for _, v in pairs(status) do
            assert(type(v) ~= 'table' and type(v) ~= 'function')
        end
    end

    local copy = s:GetStatus()
    copy.state = 'corrupt'
    assert(s:GetStatus().state == 'available')
end)

-- Lifecycle and conditions against the real registry.
local function addonFixture(profile)
    local f = F.new(5, 2, 'MAGE')
    local a, e = f.addon, f.env
    local frames = {}

    e.CreateFrame = function()
        local frame = { events = {} }

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:UnregisterEvent(event)
            self.events[event] = nil
        end

        function frame:SetScript(_, fn)
            self.script = fn
        end

        frames[#frames + 1] = frame
        return frame
    end

    local dbm = dbmProvider()
    e.DBM = dbm.api
    local loaded = { ['DBM-Core'] = true }

    e.C_AddOns = {
        IsAddOnLoaded = function(id) return loaded[id] == true end,
        GetAddOnMetadata = function() return '12.1.17' end,
    }

    e.GetTime = function() return f.now or 100 end

    for _, path in ipairs({
        'Diagnostics/errors.lua',
        'Platform/client.lua',
        'Platform/spells.lua',
        'Core/conditions.lua',
        'Integrations/encounters.lua',
        'Conditions/bossmod.lua',
    }) do
        f.load(path)
    end

    a.db = { profile = profile or {} }
    return f, a, dbm, frames, loaded
end

test('the saved selection drives the lifecycle; only a missing provider waits for ADDON_LOADED', function()
    local f, a, dbm, all, loaded = addonFixture({})
    local base = #all

    local frames = setmetatable({}, {
        __index = function(_, i) return all[base + i] end,
        __len = function() return #all - base end,
    })

    a:InitializeEncounterIntegration()
    assert(#all == base and dbm:count() == 0 and a:GetEncounterIntegrationStatus().state == 'disabled')
    a.db.profile.encounter_provider = 'DBM-Core'
    a:SyncEncounterIntegration()
    assert(dbm:count() == 9 and #all == base, 'a loaded provider binds without any frame')
    a.db.profile.encounter_provider = 'bogus'
    a:SyncEncounterIntegration()
    assert(dbm:count() == 0)
    loaded['DBM-Core'] = false
    a.db.profile.encounter_provider = 'DBM-Core'
    a:SyncEncounterIntegration()
    assert(#all == base + 1 and frames[1].events.ADDON_LOADED and a:GetEncounterIntegrationStatus().state == 'missing')
    loaded['DBM-Core'] = true
    frames[1].script(frames[1], 'ADDON_LOADED', 'SomethingElse')
    assert(dbm:count() == 0)
    frames[1].script(frames[1], 'ADDON_LOADED', 'DBM-Core')
    assert(dbm:count() == 9 and not frames[1].events.ADDON_LOADED)
    a.db.profile.encounter_provider = nil
    a:SyncEncounterIntegration()
    assert(dbm:count() == 0 and not frames[1].events.ADDON_LOADED)
end)

test('boss-mod conditions are unavailable without a provider and match the cached observations', function()
    local f, a, dbm = addonFixture({})
    local enc = { type = 'BOSSMOD_ENCOUNTER' }
    local stage = { type = 'BOSSMOD_STAGE', operator = 'GREATERTHANOREQUALS', value = 2 }
    local timer = { type = 'BOSSMOD_TIMER', spell = 29832, operator = 'LESSTHAN', value = 5 }

    for _, v in ipairs({ enc, stage, timer }) do
        assert(a:validateCondition(v, 0), v.type .. ' should validate')
        local r = a:evaluateConditionResult({ type = 'NOT', value = v })
        assert(r.status == 'unavailable', v.type .. ' must stay unavailable under NOT')
    end

    a:InitializeEncounterIntegration()

    for _, v in ipairs({ enc, stage, timer }) do
        assert(a:evaluateConditionResult(v).status == 'unavailable')
    end

    a.db.profile.encounter_provider = 'DBM-Core'
    a:SyncEncounterIntegration()

    for _, v in ipairs({ enc, stage, timer }) do
        assert(a:evaluateConditionResult(v).status == 'no-match', v.type)
    end

    local mod = { inCombat = true, encounterId = 652 }
    dbm:fire('DBM_Pull', mod)

    assert(
        a:evaluateCondition(enc)
            and a:evaluateCondition({ type = 'BOSSMOD_ENCOUNTER', encounter = 652 })
            and not a:evaluateCondition({ type = 'BOSSMOD_ENCOUNTER', encounter = 653 })
    )

    assert(not a:evaluateCondition(stage))
    dbm:fire('DBM_SetStage', mod, 'x', 2, 652)
    assert(a:evaluateCondition(stage))
    dbm:fire('DBM_TimerBegin', 't', 'Shadow Cleave', 12, 'i', 'cd', 29832)
    assert(not a:evaluateCondition(timer))
    f.now = 108
    assert(a:evaluateCondition(timer))
    f.now = 113
    assert(a:evaluateConditionResult(timer).status == 'no-match', 'an expired timer is not "less than 5 seconds"')

    for _, bad in ipairs({
        { type = 'BOSSMOD_ENCOUNTER', encounter = 0 },
        { type = 'BOSSMOD_ENCOUNTER', encounter = 1.5 },
        { type = 'BOSSMOD_STAGE', operator = 'LESSTHAN' },
        { type = 'BOSSMOD_STAGE', operator = 'bogus', value = 1 },
        { type = 'BOSSMOD_TIMER', operator = 'LESSTHAN', value = 5 },
        { type = 'BOSSMOD_TIMER', spell = -1, operator = 'LESSTHAN', value = 5 },
        { type = 'BOSSMOD_TIMER', spell = 5, operator = 'LESSTHAN', value = -1 },
    }) do
        assert(not a:validateCondition(bad, 0), 'accepted invalid ' .. bad.type)
    end

    for _, tag in ipairs({ 'BOSSMOD_ENCOUNTER', 'BOSSMOD_STAGE', 'BOSSMOD_TIMER' }) do
        local d = a.conditionDefinitions[tag]
        assert(type(d.print(0, { operator = 'LESSTHAN', value = 1, spell = 29832, encounter = 652 })) == 'string')
    end
end)

test('the timer note checks the encounter reader before calling it', function()
    local _, a = addonFixture({})
    local timerNote = assert(a.builtinSourceModules['Conditions/bossmod.lua']('timerNote'), 'timerNote getter missing')
    -- A timer list with no encounter reader (a partial adapter) is unavailable, not an error.
    a.ListBossModTimers = function() return {} end
    a.GetBossModEncounter = nil
    local ok, text = pcall(timerNote)
    assert(ok, 'timerNote raised: ' .. tostring(text))
    assert(text == 'Boss mod data unavailable: adapter-unavailable', text)
    a.GetBossModEncounter = function() return nil, nil, nil, 'bossmod-disabled' end
    assert(timerNote() == 'Boss mod data unavailable: bossmod-disabled')
    a.GetBossModEncounter = function() return false end
    assert(timerNote() == 'No boss-mod timers are running.')
end)

test('existing profiles are seeded once; removals stay saved', function()
    local f, a = addonFixture({})

    local db = {
        profile = {
            switch_conditions = { 'AND' },
            condition_groups = {
                { id = 'b3d7df2c-f257-4a2d-961e-66e49336d109', conditions = { 'COMBAT' } },
                { id = 'other', conditions = {} },
            },
        },
    }

    a:InitializeBossModConditions(nil, db)
    local p = db.profile

    assert(
        p.bossModConditionsSeeded
            and #p.switch_conditions == 3
            and #p.condition_groups[1].conditions == 4
            and #p.condition_groups[2].conditions == 0
    )

    p.switch_conditions = { 'AND' }
    a:InitializeBossModConditions(nil, db)
    assert(#p.switch_conditions == 1)
    local malformed = { profile = {} }
    a:InitializeBossModConditions(nil, malformed)
    assert(malformed.profile.bossModConditionsSeeded)
end)

finish()
