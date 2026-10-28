-- main.lua's Questie wiring against the production startup fixture: the service is created once, the late-load event
-- owner exists only while the preference is on, and every profile change (replace, switch, copy, reset, import)
-- re-synchronizes the same service. Native frames and provider calls are recorded; tests/questie_integration.lua
-- covers the adapter itself and tests/integration_settings.lua the settings cards.
local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local prefix = assert(read('tests/startup.lua'):match('^(.-)\ntest%('))
local startup, initialize = assert(loadstring(prefix .. '\nreturn fixture,initialize', '@questie/startup'))()
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(enabled)
    local env, a, load = startup(true, true)
    local frames, trace = {}, {}

    env.CreateFrame = function(kind)
        assert(kind == 'Frame')
        local f = { events = {} }
        frames[#frames + 1] = f

        function f:RegisterEvent(event)
            self.events[event] = true
        end

        function f:UnregisterEvent(event)
            self.events[event] = nil
        end

        function f:SetScript(event, callback)
            assert(event == 'OnEvent')
            self.callback = callback
        end

        return f
    end

    local made = 0
    local on = false

    a.Integrations = {
        NewQuestie = function()
            made = made + 1
            local s = {}

            function s:SetEnabled(value)
                on = value
                trace[#trace + 1] = { 'enabled', value }
                return true
            end

            function s:Refresh()
                trace[#trace + 1] = { 'refresh' }
            end

            function s:GetStatus()
                return {
                    state = on and 'available' or 'disabled',
                    reason = 'ready',
                    version = '12.1.0',
                    versionStatus = 'source-tested',
                    family = 'tbc',
                    familyContract = 'declared-unverified',
                    nativeAcceptance = 'unverified',
                    coverage = 'recent-update-receipts-only',
                }
            end

            return s
        end,
    }

    a.augmentDefaults = function(_, defaults)
        defaults.profile.questie_enabled = enabled == true
    end

    load('main.lua')
    local augment = a.augmentDefaults
    -- initialize() supplies ordinary startup stubs; retain the preference seeder.
    local original = a.OnInitializeInternal

    a.OnInitializeInternal = function(self)
        self.augmentDefaults = augment
        return original(self)
    end

    initialize(a)
    return env, a, load, frames, trace, function() return made end
end

test('default-disabled startup creates one service and no frame or polling work', function()
    local _, a, _, frames, trace, made = fixture(false)
    assert(type(a.SyncQuestieIntegration) == 'function', 'missing integration lifecycle')
    assert(made() == 1 and #frames == 0 and #trace == 1 and trace[1][2] == false)
    a:SyncQuestieIntegration()
    assert(made() == 1 and #frames == 0 and #trace == 1)
    assert(a.db.profile.questie_enabled == false)
end)

test('saved enabled preference binds one independent late-load event owner', function()
    local _, a, _, frames, trace, made = fixture(true)
    assert(made() == 1 and #frames == 1 and frames[1].events.ADDON_LOADED)
    local before = #trace
    frames[1].callback(frames[1], 'ADDON_LOADED', 'OtherAddon')
    assert(#trace == before)
    frames[1].callback(frames[1], 'ADDON_LOADED', 'Questie')
    assert(trace[#trace][1] == 'refresh')
    a.UnregisterAllEvents = function() end
    a:UnregisterAllEvents()
    assert(frames[1].events.ADDON_LOADED)
    a:SyncQuestieIntegration()
    assert(made() == 1 and #frames == 1)
    a.db.profile.questie_enabled = false
    a:SyncQuestieIntegration()
    assert(not frames[1].events.ADDON_LOADED)
    before = #trace
    frames[1].callback(frames[1], 'ADDON_LOADED', 'Questie')
    assert(#trace == before)
    a.db.profile.questie_enabled = true
    a:SyncQuestieIntegration()
    assert(made() == 1 and #frames == 1 and frames[1].events.ADDON_LOADED)
end)

test('saved profile replacement and final imported overlay synchronize without service recreation', function()
    local _, a, load, frames, _, made = fixture(false)
    a.InitializeScopedRotationStorage = function() return true end
    load('Core/rotation_lifecycle.lua')
    a.db.profile = { questie_enabled = true }
    assert(a:RefreshRotationProfileStorage())
    assert(#frames == 1 and frames[1].events.ADDON_LOADED)
    a.db.profile = { questie_enabled = false }
    assert(a:RefreshRotationProfileStorage())
    assert(not frames[1].events.ADDON_LOADED)
    -- Imported overlay follows a reset callback; final refresh must see final data.
    a.db.profile.questie_enabled = true
    assert(a:RefreshRotationProfileStorage())
    assert(frames[1].events.ADDON_LOADED and made() == 1)
end)

test('actual AceDB profile switch copy and reset synchronize the same service', function()
    local source = assert(read('tests/rotation_scope_runtime.lua'):match('^(.-)\ntest%('))
    local runtime = assert(loadstring(source .. '\nreturn fixture', '@questie/profile-fixture'))()
    local env, a = runtime()
    local made = 0
    local enabled

    env.CreateFrame = function()
        return { SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
    end

    a.Integrations = {
        NewQuestie = function()
            made = made + 1

            return {
                SetEnabled = function(_, v)
                    enabled = v
                    return true
                end,
                GetStatus = function() return { state = 'disabled' } end,
            }
        end,
    }

    a:InitializeQuestieIntegration()
    assert(enabled == false and made == 1)
    a.DestroyAllGlows = function() end
    a.RefreshConfiguration = function() end
    a.EnableRotation = function() end
    a.db.profile.questie_enabled = true
    a:SyncQuestieIntegration()
    assert(enabled)
    a.db:SetProfile('Other')
    assert(not enabled and made == 1)
    a.db:CopyProfile('Default')
    assert(enabled and made == 1)
    a.db:ResetProfile()
    assert(not enabled and made == 1)
end)

test('Questie profile preference round-trips as a boolean and rejects malformed imports', function()
    local source = assert(read('tests/rotation_scope_runtime.lua'):match('^(.-)\ntest%('))
    local runtime = assert(loadstring(source .. '\nreturn fixture', '@questie/transfer-fixture'))()
    local _, a, _, _, _, _, load = runtime()
    load('UI/settings_draft.lua')
    load('Core/profile_data.lua')

    for _, value in ipairs({ false, true }) do
        local original = { questie_enabled = value }
        local restored = assert(a:ProfileFromPortable(a:ProfileToPortable(original)))

        assert(
            restored.questie_enabled == value and a:ValidateProfileTransfer(restored),
            'Questie profile boolean not portable'
        )
    end

    for _, value in ipairs({ 'true', 1, {} }) do
        assert(not a:ValidateProfileTransfer({ questie_enabled = value }))
    end
end)

test('actual corrected adapter loads late through production event wiring and retires profile receipts', function()
    local env, a, load = startup(true, true)
    local frame
    local loaded = false
    local probes = 0

    env.CreateFrame = function()
        frame = { events = {} }

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:UnregisterEvent(event)
            self.events[event] = nil
        end

        function frame:SetScript(_, fn)
            self.callback = fn
        end

        return frame
    end

    local metadata = env.C_AddOns.GetAddOnMetadata

    env.C_AddOns.GetAddOnMetadata = function(name, key)
        if name == 'Questie' then
            return '12.1.0'
        end

        return metadata(name, key)
    end

    env.C_AddOns.IsAddOnLoaded = function(name)
        if name == 'Questie' then
            probes = probes + 1
            return loaded
        end

        return false
    end

    a.Platform.CanReadValue = function() return true end
    a.Platform.GetClientInfo = function() return { family = 'tbc' } end
    load(arg[1] or 'Integrations/questie.lua')
    local service
    local factory = a.Integrations.NewQuestie

    a.Integrations.NewQuestie = function()
        service = factory()
        return service
    end

    load('main.lua')
    initialize(a)
    assert(probes == 0 and a:GetQuestieIntegrationStatus().state == 'disabled')
    a.db.profile.questie_enabled = true
    a:SyncQuestieIntegration()
    assert(a:GetQuestieIntegrationStatus().state == 'missing')
    local readyCalls, updateCalls, update = 0, 0

    local api = {
        isReady = true,
        Enums = {
            QuestUpdateTriggerReason = {
                QUEST_ACCEPTED = 1,
                QUEST_UPDATED = 2,
                QUEST_TURNED_IN = 3,
                QUEST_ABANDONED = 4,
            },
        },
    }

    api.RegisterOnReady = function(callback)
        readyCalls = readyCalls + 1
        callback()
    end

    api.RegisterForQuestUpdates = function(callback)
        updateCalls = updateCalls + 1
        update = callback
    end

    env.Questie = { API = api }
    loaded = true
    frame.callback(frame, 'ADDON_LOADED', 'Questie')
    assert(a:GetQuestieIntegrationStatus().state == 'available' and readyCalls == 1 and updateCalls == 1)
    update(42, nil, 1)
    assert(service:GetRecentUpdate(42).status == 'available')
    a.db.profile = { questie_enabled = false }
    a:SyncQuestieIntegration()
    assert(service:GetRecentUpdate(42).status == 'unavailable')
    local before = probes
    update(42, nil, 2)
    assert(probes == before)
    a.db.profile = { questie_enabled = true }
    a:SyncQuestieIntegration()
    assert(readyCalls == 1 and updateCalls == 1)
    assert(service:GetRecentUpdate(42).status == 'unavailable', 'old profile receipt survived re-enable')
end)

finish()
