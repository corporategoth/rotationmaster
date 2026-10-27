-- Optional boss-mod consumer: DBM (DBM-Core) or BigWigs, one selected at a time.
-- Everything here is event-fed. RM never polls a boss mod: the provider's own
-- callbacks fill a small cache, and conditions read that cache lazily.
--
-- Verified contracts (read-only source inspection, 2026-10-23):
--  DBM-Core 12.1.17 (TBC Anniversary install, DBM-Core.lua "Callbacks"):
--   DBM:RegisterCallback(event,f) / DBM:UnregisterCallback(event,f); f(event,...)
--   DBM_Pull(mod,delay,synced,startHp)   modules/CombatDetection.lua, after mod.inCombat=true
--   DBM_Kill(mod) / DBM_Wipe(mod)        only for mods with statistics; mod.inCombat=false on every end
--   DBM_SetStage(mod,modId,stage,encounterId,stageTotal)  modules/objects/BossMod.lua
--   DBM_TimerBegin(id,msg,timer,icon,simpType,spellId,colorId,modId,keep,...)
--   DBM_TimerStop(id[,guid]) DBM_TimerUpdate(id,elapsed,total) DBM_TimerPause(id) DBM_TimerResume(id)
--  BigWigs master 5592509 (github.com/BigWigsMods/BigWigs Loader.lua, Core/BossPrototype.lua):
--   BigWigsLoader.RegisterMessage(owner,event,f) / .UnregisterMessage(owner,event); f(event,...)
--   BigWigs_OnBossEngage(module) _OnBossWin(module) _OnBossWipe(module) _OnBossDisable(module)
--   BigWigs_SetStage(module,stage) BigWigs_StartBar(module,key,text,time,icon,isApprox,maxTime)
--   BigWigs_StopBar(module,text) _PauseBar(module,text) _ResumeBar(module,text) _StopBars(module)
--   module.isEngaged (true while engaged, nil after Disable), module.engageId, module.displayName
-- A timer is a provider prediction, not game state. Missing providers leave
-- every boss-mod condition unavailable rather than false.
local _, addon = ...
addon.Integrations = addon.Integrations or {}

local type, pairs, ipairs, pcall, rawget, tonumber, tostring, next =
    type, pairs, ipairs, pcall, rawget, tonumber, tostring, next

local providers = { ['DBM-Core'] = true, BigWigs = true }
-- Restricted clients may hand addons secret combat values; the adapter is
-- declared only where boss-mod payloads are ordinary readable values.
local supported = { era = true, tbc = true, progression = true }

local dbmEvents = {
    'DBM_Pull', 'DBM_Kill', 'DBM_Wipe', 'DBM_SetStage', 'DBM_TimerBegin', 'DBM_TimerStop', 'DBM_TimerUpdate',
    'DBM_TimerPause', 'DBM_TimerResume'
}

local bigwigsEvents = {
    'BigWigs_OnBossEngage', 'BigWigs_OnBossWin', 'BigWigs_OnBossWipe', 'BigWigs_OnBossDisable', 'BigWigs_SetStage',
    'BigWigs_StartBar', 'BigWigs_StopBar', 'BigWigs_PauseBar', 'BigWigs_ResumeBar', 'BigWigs_StopBars'
}

local MAX_TIMERS, MAX_DURATION = 64, 3600

local function finite(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local function spellID(v)
    if type(v) == 'string' and #v <= 12 then v = tonumber(v) end
    if finite(v) and v > 0 and v % 1 == 0 and v < 2 ^ 31 then return v end
end

local function positiveInteger(v)
    return finite(v) and v > 0 and v % 1 == 0 and v < 2 ^ 31 and v or nil
end

local function label(v)
    if type(v) ~= 'string' then return nil end
    return (v:sub(1, 96):gsub('[%c|]', '?'))
end

local function copy(source)
    local r = {}

    for k, v in pairs(source) do
        r[k] = v
    end

    return r
end

function addon.Integrations.NewEncounterTimers(options)
    options = options or {}
    local resolve, now, readable, onChange = options.resolve, options.now, options.readable, options.onChange
    local service = {}
    local provider, binding, generation, disposed = nil, nil, 0, false
    local encounter, timers, timerCount = nil, {}, 0
    local owner = {}  -- BigWigs message owner; never BigWigsLoader itself.

    local status = {
        state = 'disabled',
        reason = 'disabled',
        provider = nil,
        version = nil,
        family = 'unknown',
        nativeAcceptance = 'unverified',
    }

    local function canRead(v)
        if readable then return readable(v) == true end
        local platform = addon.Platform
        return not platform or platform:CanReadValue(v) == true
    end

    local function clock()
        local value

        if now then
            value = now()
        else
            value = GetTime()
        end

        if finite(value) then return value end
    end

    local function clear()
        encounter = nil
        timers = {}
        timerCount = 0
    end

    local function publish(state, reason, extra)
        local fresh = {
            state = state,
            reason = reason,
            provider = provider,
            family = status.family,
            nativeAcceptance = 'unverified',
            version = extra and extra.version or (state ~= 'disabled' and status.version or nil),
        }

        if extra and extra.family then fresh.family = extra.family end
        local changed = false

        for k, v in pairs(fresh) do
            if status[k] ~= v then changed = true end
        end

        for k, v in pairs(status) do
            if fresh[k] ~= v then changed = true end
        end

        status = fresh
        if changed and onChange then pcall(onChange, copy(status)) end
    end

    local function defaultResolve(id)
        local info = {}
        local platform = addon.Platform
        local client = platform and platform.GetClientInfo and platform:GetClientInfo()
        info.family = type(client) == 'table' and rawget(client, 'family') or 'unknown'
        local native = C_AddOns
        local loadedFn = type(native) == 'table' and native.IsAddOnLoaded or IsAddOnLoaded
        local versionFn = type(native) == 'table' and native.GetAddOnMetadata or GetAddOnMetadata
        if type(loadedFn) == 'function' then info.loaded = loadedFn(id) end
        if type(versionFn) == 'function' then info.version = versionFn(id, 'Version') end
        if info.loaded then info.api = rawget(_G, id == 'BigWigs' and 'BigWigsLoader' or 'DBM') end
        return info
    end

    -- Detach is idempotent and tolerates a provider that has since changed.
    local function detach()
        local b = binding
        binding = nil
        generation = generation + 1
        if not b then return end

        if b.kind == 'DBM-Core' then
            for _, event in ipairs(dbmEvents) do
                pcall(b.unregister, b.api, event, b.handler)
            end
        else
            for _, event in ipairs(bigwigsEvents) do
                pcall(b.unregister, owner, event)
            end
        end
    end

    local function fault(reason)
        -- Stay registered (detaching inside the provider's own dispatch loop can
        -- skip a sibling callback); the generation check silences this handler.
        if binding then binding.faulted = true end
        clear()
        publish('error', reason)
    end

    local function removeTimer(key)
        if timers[key] then
            timers[key] = nil
            timerCount = timerCount - 1
        end
    end

    local function startTimer(key, spell, duration, source, at)
        if timers[key] == nil then
            if timerCount >= MAX_TIMERS then
                local victim, soonest

                for k, t in pairs(timers) do
                    local ends = t.paused and (at + t.paused) or t.expiresAt
                    if not soonest or ends < soonest then victim, soonest = k, ends end
                end

                removeTimer(victim)
            end

            timerCount = timerCount + 1
        end

        timers[key] = { spellId = spell, expiresAt = at + duration, source = source }
    end

    local function engage(kind, handle, encounterId, name, key)
        encounter = {
            provider = kind,
            handle = handle,
            encounterId = positiveInteger(encounterId),
            name = label(name),
            key = label(key),
            stage = nil,
        }
    end

    local function same(handle)
        return encounter and rawequal(encounter.handle, handle)
    end

    local function dbmName(mod)
        local ok, value = pcall(function() return mod.localization.general.name end)
        return ok and value or nil
    end

    local dbm = {}

    function dbm.DBM_Pull(_, mod)
        if type(mod) ~= 'table' then return end
        engage('DBM-Core', mod, rawget(mod, 'encounterId'), dbmName(mod), rawget(mod, 'id'))
    end

    function dbm.DBM_Kill(_, mod)
        if same(mod) then encounter = nil end
    end

    dbm.DBM_Wipe = dbm.DBM_Kill

    function dbm.DBM_SetStage(_, mod, _, stage, encounterId)
        if type(mod) ~= 'table' or not finite(stage) then return end

        if not same(mod) then
            if rawget(mod, 'inCombat') ~= true then return end
            engage('DBM-Core', mod, encounterId or rawget(mod, 'encounterId'), dbmName(mod), rawget(mod, 'id'))
        end

        encounter.stage = stage
    end

    function dbm.DBM_TimerBegin(at, id, _, duration, _, _, spell)
        if type(id) ~= 'string' or #id > 512 then return end
        spell = spellID(spell)

        if not spell or not finite(duration) or duration <= 0 or duration > MAX_DURATION then
            removeTimer(id)
            return
        end

        startTimer(id, spell, duration, nil, at)
    end

    function dbm.DBM_TimerStop(_, id)
        if type(id) == 'string' then removeTimer(id) end
    end

    function dbm.DBM_TimerUpdate(at, id, elapsed, total)
        local t = type(id) == 'string' and timers[id]
        if not t then return end

        if not finite(elapsed) or not finite(total) then
            removeTimer(id)
            return
        end

        local remaining = total - elapsed

        if remaining <= 0 or remaining > MAX_DURATION then
            removeTimer(id)
        elseif t.paused then
            t.paused = remaining
        else
            t.expiresAt = at + remaining
        end
    end

    function dbm.DBM_TimerPause(at, id)
        local t = type(id) == 'string' and timers[id]

        if t and not t.paused then
            t.paused = t.expiresAt - at
            if t.paused <= 0 then removeTimer(id) end
        end
    end

    function dbm.DBM_TimerResume(at, id)
        local t = type(id) == 'string' and timers[id]

        if t and t.paused then
            t.expiresAt = at + t.paused
            t.paused = nil
        end
    end

    local bigwigs = {}

    function bigwigs.BigWigs_OnBossEngage(_, module)
        if type(module) ~= 'table' then return end
        local ok, name = pcall(function() return module.displayName or module.moduleName end)
        engage('BigWigs', module, rawget(module, 'engageId'), ok and name or nil, rawget(module, 'moduleName'))
    end

    local function bossEnd(_, module)
        if same(module) then encounter = nil end

        for k, t in pairs(timers) do
            if rawequal(t.source, module) then removeTimer(k) end
        end
    end

    bigwigs.BigWigs_OnBossWin = bossEnd
    bigwigs.BigWigs_OnBossWipe = bossEnd
    bigwigs.BigWigs_OnBossDisable = bossEnd

    function bigwigs.BigWigs_StopBars(_, module)
        for k, t in pairs(timers) do
            if rawequal(t.source, module) then removeTimer(k) end
        end
    end

    function bigwigs.BigWigs_SetStage(_, module, stage)
        if type(module) ~= 'table' or not finite(stage) then return end

        if not same(module) then
            if rawget(module, 'isEngaged') ~= true then return end
            bigwigs.BigWigs_OnBossEngage(nil, module)
        end

        encounter.stage = stage
    end

    -- Bars are named per module by their display text; the key (an option
    -- key, normally the ability's spell ID) is the only stable identity.
    function bigwigs.BigWigs_StartBar(at, module, key, text, duration)
        if type(text) ~= 'string' or #text > 512 then return end
        local spell = spellID(key)
        local existing = timers[text]

        if not spell or not finite(duration) or duration <= 0 or duration > MAX_DURATION then
            if existing and rawequal(existing.source, module) then removeTimer(text) end
            return
        end

        startTimer(text, spell, duration, module, at)
    end

    function bigwigs.BigWigs_StopBar(_, module, text)
        local t = type(text) == 'string' and timers[text]
        if t and rawequal(t.source, module) then removeTimer(text) end
    end

    function bigwigs.BigWigs_PauseBar(at, module, text)
        local t = type(text) == 'string' and timers[text]

        if t and rawequal(t.source, module) and not t.paused then
            t.paused = t.expiresAt - at
            if t.paused <= 0 then removeTimer(text) end
        end
    end

    function bigwigs.BigWigs_ResumeBar(at, module, text)
        local t = type(text) == 'string' and timers[text]

        if t and rawequal(t.source, module) and t.paused then
            t.expiresAt = at + t.paused
            t.paused = nil
        end
    end

    local function makeHandler(kind, routes, g)
        return function(event, ...)
            local b = binding
            if disposed or not b or b.faulted or generation ~= g then return end
            local route = routes[event]
            if not route then return end

            local ok, err = pcall(function(...)
                -- Only the leading payload fields are consumed (DBM spellId is 6th).
                local n = select('#', ...)
                if n > 7 then n = 7 end

                for i = 1, n do
                    if not canRead((select(i, ...))) then error('restricted', 0) end
                end

                local at = clock()
                if not at then error('invalid-clock', 0) end
                route(at, ...)
            end, ...)

            if not ok and generation == g then fault(err == 'restricted' and 'restricted-value' or 'callback-error') end
        end
    end

    local function attach()
        local info

        if resolve then
            local ok, value = pcall(resolve, provider)
            info = ok and value or nil

            if not ok then
                publish('error', 'resolver-error')
                return
            end
        else
            local ok, value = pcall(defaultResolve, provider)
            info = ok and value or nil

            if not ok then
                publish('error', 'resolver-error')
                return
            end
        end

        if type(info) ~= 'table' then
            publish('error', 'resolver-error')
            return
        end

        local family = type(info.family) == 'string' and info.family or 'unknown'
        local version = label(info.version)
        local meta = { family = family, version = version }

        if info.loaded ~= true then
            publish('missing', 'provider-missing', meta)
            return
        end

        if not supported[family] then
            publish('incompatible', 'unsupported-client', meta)
            return
        end

        local api = info.api

        if type(api) ~= 'table' then
            publish('incompatible', 'provider-api-missing', meta)
            return
        end

        local register, unregister

        local ok = pcall(function()
            if provider == 'DBM-Core' then
                register, unregister = api.RegisterCallback, api.UnregisterCallback
            else
                register, unregister = api.RegisterMessage, api.UnregisterMessage
            end
        end)

        if not ok or type(register) ~= 'function' or type(unregister) ~= 'function' then
            publish('incompatible', 'invalid-registration', meta)
            return
        end

        generation = generation + 1
        local g = generation
        local kind = provider
        local handler = makeHandler(kind, kind == 'DBM-Core' and dbm or bigwigs, g)
        binding = { kind = kind, api = api, handler = handler, register = register, unregister = unregister }
        local events = kind == 'DBM-Core' and dbmEvents or bigwigsEvents

        for _, event in ipairs(events) do
            local registered

            if kind == 'DBM-Core' then
                registered = pcall(register, api, event, handler)
            else
                registered = pcall(register, owner, event, handler)
            end

            if not registered then
                detach()
                clear()
                publish('error', 'registration-error', meta)
                return
            end
        end

        publish('available', 'ready', meta)
    end

    function service:SetProvider(id)
        if disposed then return false, 'disposed' end
        if id ~= nil and not providers[id] then return false, 'invalid-provider' end
        if id == provider and (id == nil or binding and not binding.faulted) then return true end
        detach()
        clear()
        provider = id

        if id == nil then
            publish('disabled', 'disabled')
            return true
        end

        attach()
        return true
    end

    -- Retry a selected provider that was not yet loaded (ADDON_LOADED).
    function service:Refresh()
        if disposed or provider == nil then return self:GetStatus() end
        if binding and not binding.faulted then return self:GetStatus() end
        detach()
        clear()
        attach()
        return self:GetStatus()
    end

    function service:IsBound()
        return binding ~= nil and not binding.faulted
    end

    function service:GetStatus()
        return copy(status)
    end

    local function current()
        if disposed then return nil, 'disposed' end
        if provider == nil then return nil, 'integration-disabled' end
        if not binding or binding.faulted or status.state ~= 'available' then return nil, status.reason end
        return true
    end

    -- Multiple returns keep the polling read allocation-free:
    -- active (true/false or nil when unavailable), encounterId, stage, name/reason.
    function service:GetEncounter()
        local ok, why = current()
        if not ok then return nil, nil, nil, why end
        local e = encounter
        if not e then return false end
        local alive = rawget(e.handle, e.provider == 'DBM-Core' and 'inCombat' or 'isEngaged') == true

        if not alive then
            encounter = nil
            return false
        end

        return true, e.encounterId, e.stage or 1, e.name
    end

    function service:GetTimerRemaining(spell, at)
        local ok, why = current()
        if not ok then return nil, why end
        at = finite(at) and at or clock()
        if not at then return nil, 'invalid-clock' end
        local best

        for key, t in pairs(timers) do
            local remaining = t.paused or (t.expiresAt - at)

            if remaining <= 0 then
                removeTimer(key)
            elseif t.spellId == spell and (not best or remaining < best) then
                best = remaining
            end
        end

        return best or false
    end

    -- Authoring aid only: bounded, detached rows sorted by time remaining.
    function service:ListTimers(limit)
        local rows = {}
        if not current() then return rows end
        local at = clock()
        if not at then return rows end

        for key, t in pairs(timers) do
            local remaining = t.paused or (t.expiresAt - at)

            if remaining <= 0 then
                removeTimer(key)
            else
                rows[#rows + 1] = { spellId = t.spellId, remaining = remaining, paused = t.paused ~= nil }
            end
        end

        table.sort(rows, function(a, b)
            if a.remaining ~= b.remaining then return a.remaining < b.remaining end
            return a.spellId < b.spellId
        end)

        for i = #rows, (limit or 8) + 1, -1 do
            rows[i] = nil
        end

        return rows
    end

    function service:Dispose()
        if disposed then return end
        detach()
        clear()
        provider = nil
        publish('disabled', 'disposed')
        disposed = true
    end

    return service
end

-- One lifetime per session. Settings only publish the saved selection.
local service, events, selected

local function profileProvider(self)
    local profile = self.db and self.db.profile
    local value = profile and profile.encounter_provider
    if type(value) == 'string' and providers[value] then return value end
end

function addon:InitializeEncounterIntegration()
    if service then return end
    local factory = self.Integrations and self.Integrations.NewEncounterTimers
    if type(factory) ~= 'function' then return end
    service = factory()
    self:SyncEncounterIntegration()
end

local function watchLoads(self, on)
    if on then
        if not events then
            if type(CreateFrame) ~= 'function' then return end
            events = CreateFrame('Frame')

            events:SetScript('OnEvent', function(_, event, name)
                if event ~= 'ADDON_LOADED' or not service or not selected or name ~= selected then return end
                service:Refresh()
                if service:IsBound() then events:UnregisterEvent('ADDON_LOADED') end
            end)
        end

        events:RegisterEvent('ADDON_LOADED')
    elseif events then
        events:UnregisterEvent('ADDON_LOADED')
    end
end

function addon:SyncEncounterIntegration()
    if not service then return false end
    local wanted = profileProvider(self)
    if wanted == selected and (wanted == nil or service:IsBound()) then return true end
    selected = wanted
    service:SetProvider(wanted)
    -- Only a selected, not-yet-loaded provider listens for its own load.
    watchLoads(self, wanted ~= nil and service:GetStatus().state == 'missing')
    return true
end

function addon:GetEncounterIntegrationStatus()
    if service then return service:GetStatus() end
    return { state = 'unavailable', reason = 'adapter-unavailable', nativeAcceptance = 'unverified' }
end

function addon:GetBossModEncounter()
    if not service then return nil, nil, nil, 'adapter-unavailable' end
    return service:GetEncounter()
end

function addon:GetBossModTimerRemaining(spell, at)
    if not service then return nil, 'adapter-unavailable' end
    return service:GetTimerRemaining(spell, at)
end

function addon:ListBossModTimers(limit)
    if not service then return {} end
    return service:ListTimers(limit)
end
