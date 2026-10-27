-- Runtime driver of the addon: the /rm slash commands, the minimap menu, event registration, the repeating poll that
-- picks the next action, automatic rotation switching, the two evaluation engines (standard and lean; see
-- docs/dev/architecture.md, "Evaluation") and the combat and cast event handlers. It sequences work only: rotation
-- data, selection, conditions and sequences are owned by Core/, glow drawing by buttons.lua; it must not draw windows.
-- Loaded from RotationMaster.toc after profiler.lua, Core/condition_runtime.lua, Core/rotation_selection.lua and
-- Core/active_runtime_plan.lua, whose one-time binder functions it consumes (and then deletes) at load; init.lua loads
-- later. On restricted clients (Retail, Forever) game values are read only through platform:CanReadValue and the
-- combat log is not subscribed (docs/restricted-clients.md).
local addon_name, addon = ...

-- ============================================================================
-- Load-time handoffs from earlier modules
-- ============================================================================

-- Capture the compatibility override once. Managed rotations use the prepared
-- executor; unsupported/custom sources retain the eager compatibility path.
local preparedRuntimeEnabled = addon.preparedRuntimeEnabled ~= false
-- The evaluation profiler's hooks come from profiler.lua once; the public name is removed afterwards.
local initializeEvaluationProfiler, reportEvaluationProfiler
local consumeProfilerPolicy = addon.ConsumeLegacyEvaluationProfilerPolicy

if type(consumeProfilerPolicy) == 'function' then
    initializeEvaluationProfiler, reportEvaluationProfiler = consumeProfilerPolicy(addon)
    addon.ConsumeLegacyEvaluationProfilerPolicy = nil
end

local publicationRawget, publicationType, publicationMetatable = rawget, type, getmetatable
-- The execution generation is the one number every rotation, condition,
-- function, itemset and effect writer advances (Core/dependency_revisions).
local readExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration = addon.BindRotationExecutionGeneration

if type(bindExecutionGeneration) == 'function' then
    bindExecutionGeneration(addon, function(read) readExecutionGeneration = read end)
end

addon.BindRotationExecutionGeneration = nil
-- BEGIN ANALYTICS ADVICE HANDOFF
local adviceCapture

if addon.BindAnalyticsAdviceCapture then
    addon:BindAnalyticsAdviceCapture(function(sink) adviceCapture = sink end)
end

-- END ANALYTICS ADVICE HANDOFF
-- BEGIN SWITCH UNIT HANDOFF
local switchConditionEvaluator
local consumeSwitch = addon.ConsumeSwitchConditionEvaluator

if type(consumeSwitch) == 'function' then
    switchConditionEvaluator = consumeSwitch(addon)
    addon.ConsumeSwitchConditionEvaluator = nil
end

-- Whether a rotation's switch condition lets automatic selection pick it. `current` is the caller's lease check, passed
-- through to the evaluator so a change during evaluation aborts it. Returns true for no/empty condition.
local function switchConditionMatches(value, current)
    -- No switch condition (none, an empty one, or a tree with nothing in it)
    -- matches; a broken one (an unknown condition) is not "none" and falls
    -- through to evaluation, which refuses it.
    if value == nil then return true end

    if
        type(value) == 'table'
        and addon.usefulCondition
        and not addon:usefulCondition(value)
        and addon:validateCondition(value)
    then
        return true
    end

    if switchConditionEvaluator then return switchConditionEvaluator(addon, value, current) end
    return addon:evaluateCondition(value)
end

-- END SWITCH UNIT HANDOFF
-- The active-rotation transition API of Core/rotation_active.lua. Every change of the active rotation begins a
-- transition and proves its token after each call that could run other code (see the activeCall helpers below).
local activeCurrent = addon.IsActiveRotationTransitionCurrent
local beginActive = addon.BeginActiveRotationTransition
local advanceActiveSpec = addon.AdvanceActiveRotationSpecialization
local retireActive = addon.RetireActiveRotationTransition
local commitActive = addon.CommitActiveRotationTransition
local cleanupActive = addon.GetActiveRotationCleanupSelection
local prepareChoiceSelection, finishChoiceSelection, readDesiredChoice, choiceNeedsRefresh
local invalidateChoiceContext = addon.InvalidateRotationChoiceContext
local invalidateChoiceDependencies = addon.InvalidateRotationDependencies
local consumeChoices = addon.ConsumeRotationChoiceSelection

if type(consumeChoices) == 'function' then
    prepareChoiceSelection, finishChoiceSelection, readDesiredChoice, choiceNeedsRefresh = consumeChoices(addon)
    addon.ConsumeRotationChoiceSelection = nil
end

-- BEGIN EQUIPMENT EVENT LIFETIME
local equipmentSubscription
local equipmentCoordinator = addon.GetScopedRotationCoordinator

-- END EQUIPMENT EVENT LIFETIME
-- ============================================================================
-- Transition guards
-- ============================================================================

-- Automatic rotation selection is on while its re-check interval is above
-- zero. The retired Disable Auto-Switching flag is still honoured until the
-- profile is migrated (see StartAutoSwitchTimer).
local function autoSwitchEnabled(profile)
    return not profile.disable_autoswitch and (tonumber(profile.autoswitch_poll) or 1) > 0
end

-- True while `token` is still the current active-rotation transition. False when the owner is missing or a newer
-- change superseded this one; callers stop at once in that case.
local function activeChangeCurrent(self, token)
    return type(activeCurrent) == 'function' and activeCurrent(self, token)
end

-- Calls self[name](self, ...) for the transition `token`, proving the token before and after the method lookup. Returns
-- whether the transition is still current afterwards, so callers write `if not activeCall(...) then return end`.
local function activeCall(self, token, name, ...)
    if not activeChangeCurrent(self, token) then return false end
    local method = self[name]
    if not activeChangeCurrent(self, token) then return false end
    method(self, ...)
    return activeChangeCurrent(self, token)
end

-- Like activeCall but also returns the method's first result: `current, value`. The value is only meaningful when
-- `current` is true.
local function activeValue(self, token, name, ...)
    if not activeChangeCurrent(self, token) then return false end
    local method = self[name]
    if not activeChangeCurrent(self, token) then return false end
    local value = method(self, ...)
    return activeChangeCurrent(self, token), value
end

-- activeCall for a method of another object (AceEvent, the preview window, a coordinator): object[name](object, ...).
local function activeObjectCall(self, token, object, name, ...)
    if not activeChangeCurrent(self, token) then return false end
    local method = object[name]
    if not activeChangeCurrent(self, token) then return false end
    method(object, ...)
    return activeChangeCurrent(self, token)
end

-- activeValue for a method of another object; returns `current, value`.
local function activeObjectValue(self, token, object, name, ...)
    if not activeChangeCurrent(self, token) then return false end
    local method = object[name]
    if not activeChangeCurrent(self, token) then return false end
    local value = method(object, ...)
    return activeChangeCurrent(self, token), value
end

-- Sets the data broker's text for the transition `token`; returns whether the transition is still current.
local function activeBroker(self, token, broker, text)
    if not activeChangeCurrent(self, token) then return false end
    broker.text = text
    return activeChangeCurrent(self, token)
end

-- ============================================================================
-- Addon object, libraries and selection helpers
-- ============================================================================

-- SavedVariables identity must match the TOC, independent of folder casing.
addon.savedVariableName = "RotationMasterDB"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

_G[addon_name] = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local getCached
local acquireActiveRuntimePlan, registerActiveRuntimeConsumers
local mainEnvironment = getfenv(1)
local runtimeDecisionSink
local bindRuntimeDecisions = addon.BindCPURuntimeDecisionCounts
addon.BindCPURuntimeDecisionCounts = nil

if type(bindRuntimeDecisions) == 'function' then
    bindRuntimeDecisions(addon, function(sink) runtimeDecisionSink = sink end)
end

local consumeActiveRuntimePlan = addon.ConsumeActiveRuntimePlan

if type(consumeActiveRuntimePlan) == 'function' then
    acquireActiveRuntimePlan, registerActiveRuntimeConsumers = consumeActiveRuntimePlan(addon)
    addon.ConsumeActiveRuntimePlan = nil
end

local prepareConditionRuntime, retireConditionRuntime, lastConditionSession
local consumeConditionRuntime = addon.ConsumeConditionRuntime

if type(consumeConditionRuntime) == 'function' then
    prepareConditionRuntime, retireConditionRuntime = consumeConditionRuntime(addon)
    addon.ConsumeConditionRuntime = nil
end

local acquireEvaluationPass, invalidateEvaluationContext, acquireMainSelectionPass, getMainCleanupBody
local bindEvaluationContext = addon.BindRuntimeEvaluationContext

if type(bindEvaluationContext) == 'function' then
    bindEvaluationContext(addon, function(acquire, invalidate, selection, cleanup)
        acquireEvaluationPass, invalidateEvaluationContext, acquireMainSelectionPass, getMainCleanupBody =
            acquire, invalidate, selection, cleanup
    end)

    addon.BindRuntimeEvaluationContext = nil
end

local sequenceRawMethod, sequenceRun, sequenceStatus, ownedSequence
local bindSequence = addon.BindRotationSequenceReader

if type(bindSequence) == "function" then
    bindSequence(addon, function(rawMethod, run, status, source)
        sequenceRawMethod, sequenceRun, sequenceStatus, ownedSequence = rawMethod, run, status, source
    end)

    addon.BindRotationSequenceReader = nil
end

-- Walks a rotation body through the sequence executor (Core/rotation_sequence.lua). With `guard` it uses the method
-- captured at load instead of trusting owner.EvaluateRotationSequence; when no executor is bound it then reports an
-- unavailable result that suppresses the implicit attack. Returns the executor's result table.
local function evaluateSequence(owner, body, evaluate, visit, guard)
    local before = sequenceRawMethod and sequenceRawMethod(owner)
    local method

    if guard then
        method = before
    else
        method = owner.EvaluateRotationSequence
    end

    if sequenceRun then return sequenceRun(owner, before, method, body, evaluate, visit, guard) end
    if guard then return { status = 'unavailable', suppressAttack = true } end
    return method(owner, body, evaluate, visit)
end

-- One-time private handoff to the earlier-loaded optional CPU sampler.
local bindCPUStatus = addon.BindCPUExecutionIndexDiagnostic

if type(bindCPUStatus) == "function" then
    bindCPUStatus(addon, function()
        local status = sequenceStatus and sequenceStatus(addon) or {}
        status.main = { reason = sequenceRawMethod and sequenceRun and sequenceStatus and "ready" or "unbound" }
        return status
    end)

    addon.BindCPUExecutionIndexDiagnostic = nil
end

local DBIcon = LibStub("LibDBIcon-1.0")

-- Chat link for a spell id, or a localized "Unknown spell" text when the client has no data for it.
local function spellLink(spellid)
    return addon.Platform:GetSpellLink(spellid) or string.format(L["Unknown spell (%s)"], spellid)
end

local ThreatClassic = LibStub("ThreatClassic-1.0", true)

if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    if not UnitThreatSituation and ThreatClassic then
        UnitThreatSituation = function(...) return ThreatClassic:UnitThreatSituation(...) end
    end

    -- The library captured UnitAura and CombatLogGetCurrentEventInfo when it
    -- loaded. With loadDeprecationFallbacks off Era provides neither, the
    -- library cannot work, and registering would run its combat-log handler
    -- into a nil call on every event; Platform/auras.lua then reads C_UnitAuras.
    if type(UnitAura) == "function" and type(CombatLogGetCurrentEventInfo) == "function" then
        local LibClassicDurations = LibStub("LibClassicDurations")
        LibClassicDurations:Register(addon_name)
    end
elseif ThreatClassic then
    ThreatClassic:Disable()
end

local pairs, color, string = pairs, color, string
local floor = math.floor

local isin, starts_with, isint =
    addon.Functions.values.isin, addon.Functions.text.starts_with, addon.Functions.values.isint

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
addon.delayed_condition = {}

-- The engine borrows its own validated pass; legacy public getters retain
-- their historical mutable-body contract without becoming the polling path.
local function mainSelectionPass(owner, spec)
    if acquireMainSelectionPass then return acquireMainSelectionPass(owner, spec) end
    return owner:AcquireRotationRuntimePass(spec)
end

-- The selectable rotations (id -> body) for `spec`. Returns the table, or an empty table and a reason when the scoped
-- selection pass cannot be acquired; `candidates` is forwarded to the pass.
local function runtimeRows(owner, spec, candidates)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass, why = mainSelectionPass(owner, spec)
        if not pass then return {}, why end
        return pass:Candidates(candidates == true)
    end

    return owner:GetRuntimeRotations(spec, true, candidates)
end

-- The runtime body of one rotation `value` for `spec`; returns it, or nil and a reason.
local function runtimeOne(owner, spec, value)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass, why = mainSelectionPass(owner, spec)
        if not pass then return nil, why end
        return pass:Get(value)
    end

    return owner:GetRuntimeRotation(spec, value)
end

local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(addon_name, {
    type = "data source",
    label = addon.pretty_name,
    icon = addon.logoTexture,
})

-- ============================================================================
-- Initialization: saved-variable defaults and event lists
-- ============================================================================

BINDING_HEADER_ROTATIONMASTER = addon.pretty_name
BINDING_NAME_ROTATIONMASTER_TOGGLE = string.format(L["Toggle %s |cFF00FFFF/rm toggle|r"], addon.pretty_name)

local playerGUID = UnitGUID("player")

-- AceDB defaults for the three saved scopes: profile (per profile), char (per character) and global (account-wide).
-- init.lua augments it (addon:augmentDefaults) and validate.lua checks saved data against it.
local defaults = {
    profile = {
        enable = true,
        poll = 0.15,
        idle_poll = 1.0,
        autoswitch_poll = 1.0,
        ignore_mana = false,
        ignore_range = false,
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = 'CENTER',
        xoffs = 0,
        yoffs = 0,
        loglevel = 2,
        detailed_profiling = false,
        disable_autoswitch = false,
        live_config_update = 2,
        spell_history = 60,
        combat_history = 10,
        damage_history = 30,
        disable_buttons = false,
        assisted_highlight = "rm",
        tooltips = true,
        tooltip_itemsets = true,
        tooltip_rotations = true,
        tooltip_conditions = false,
        tooltip_limit = 3,
        rotation_view = "diagram",
        transfer_format = "rm",
        lua_editor = "auto",
        lua_line_numbers = true,
        questie_enabled = false,
        rotationTagColors = {},
        preview_spells = 0,
        preview_vertical = false,
        preview_locked = false,
        preview_opacity = 1,
        preview_icon_size = 64,
        preview_window = {
            point = "CENTER",
            relpoint = "CENTER",
            xoffs = 0,
            yoffs = 0,
        },
        rotations = {},
        rotationLibrary = {},
        itemsets = {},
        announces = {},
        minimap = {
            hide = false,
        },
        condition_groups = {},
        switch_conditions = {},
        other_conditions_order = {},
        disabled_conditions = {},
    },
    char = {
        bindings = {},
    },
    global = {
        uiScale = 1,
        itemsets = {},
        effects = {},
        custom_conditions = {},
        custom_functions = {},
        function_import_origins = {},
        condition_test_values = {},
    },
}

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2 then
    defaults.char.specs = {}
    defaults.char.specs[1] = PRIMARY
    defaults.char.specs[2] = SECONDARY
end

local events = {
    -- Conditions that indicate a major combat event that should trigger an immediate
    -- evaluation of the rotation conditions (or will disable your rotation entirely).
    'PLAYER_TARGET_CHANGED',
    'PLAYER_REGEN_DISABLED',
    'PLAYER_REGEN_ENABLED',
    'UNIT_PET',
    'PLAYER_CONTROL_GAINED',
    'PLAYER_CONTROL_LOST',
    "UPDATE_STEALTH",
    -- Conditions that affect whether the rotation should be switched.
    'ZONE_CHANGED',
    'ZONE_CHANGED_INDOORS',
    'GROUP_ROSTER_UPDATE',
    'CHARACTER_POINTS_CHANGED',
    "PLAYER_FLAGS_CHANGED",
    "UPDATE_SHAPESHIFT_FORM",
    -- Conditions that affect affect the contents of highlighted buttons.
    'ACTIONBAR_SLOT_CHANGED',
    'PET_BAR_UPDATE',
    'PLAYER_ENTERING_WORLD',
    'ACTIONBAR_HIDEGRID',
    'PET_BAR_HIDEGRID',
    'ACTIONBAR_PAGE_CHANGED',
    'UPDATE_MACROS',
    'SPELLS_CHANGED',
    'PLAYER_LEVEL_UP',
    -- Reference metadata and inventory stay available without combat advice.
    'BAG_UPDATE',
    'SPELL_DATA_LOAD_RESULT',
    'ITEM_DATA_LOAD_RESULT',
}

-- These handlers maintain legacy combat observations. Reference-only clients
-- must neither subscribe to them nor process a queued/direct invocation.
local combat_events = {
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_COMBAT", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "COMBAT_LOG_EVENT_UNFILTERED"
}

-- Extra events for Retail and Forever: focus, vehicle and talent or specialization changes.
local mainline_events = {
    'PLAYER_FOCUS_CHANGED',
    'VEHICLE_UPDATE',
    'UNIT_ENTERED_VEHICLE',
    'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED',
    'PLAYER_SPECIALIZATION_CHANGED',
}

-- Bar replacements (possession, vehicle, override bar) and pet battles. Each
-- name is registered only where the client's event catalogue confirms it.
local actionContextEvents = {
    'UNIT_ENTERED_VEHICLE',
    'UPDATE_VEHICLE_ACTIONBAR',
    'UPDATE_OVERRIDE_ACTIONBAR',
    'UPDATE_POSSESS_BAR',
    'UPDATE_BONUS_ACTIONBAR',
    'PET_BATTLE_OPENING_START',
    'PET_BATTLE_CLOSE',
}

-- Extra events for the progression client family.
local wrath_events = {
    'PLAYER_TALENT_UPDATE',
    -- 'ACTIVE_TALENT_GROUP_CHANGED', # Implied by the above
}

-- Extra events for the TBC client family.
local tbc_events = {
    'PLAYER_FOCUS_CHANGED',
}

-- The Era family needs no extra events.
local classic_events = {}

-- ============================================================================
-- Manual rotation choice
-- ============================================================================

-- Chat, menu and cold restoration share the existing active transition path.
-- `id` is the rotation to select (nil returns to automatic selection and gives SwitchRotation's results), `change` an
-- open transition token (one is begun when omitted) and `remember` saves the choice for this character,
-- specialization and action context. Returns true and the token once the manual rotation is applied; nil when the
-- rotation is refused or the transition was superseded.
local function chooseManualRotation(self, id, change, remember)
    change = change or beginActive(self)
    if not activeChangeCurrent(self, change) then return nil end
    local body = id and runtimeOne(self, self.currentSpec, id)
    if not activeChangeCurrent(self, change) or id and not body then return nil end
    local ticket

    if remember and prepareChoiceSelection then
        local reference

        if id then
            local available = self.GetScopedRotationCoordinator
            if not activeChangeCurrent(self, change) then return nil end
            local checked, coordinator

            if available then
                checked, coordinator = activeValue(self, change, 'GetScopedRotationCoordinator')
                if not checked then return nil end
            end

            if coordinator then
                checked, reference = activeObjectValue(self, change, coordinator, 'Resolve', self.currentSpec, id)
                if not checked then return nil end
            end
        end

        if not id or reference then ticket = prepareChoiceSelection(self, reference) end
        if not activeChangeCurrent(self, change) then return nil end
    end

    if ticket and invalidateChoiceDependencies then
        invalidateChoiceDependencies(self, 'selection', nil)
        if not activeChangeCurrent(self, change) then return nil end
    end

    self.rotationChoiceSuspended = nil

    if id == nil then
        if ticket then finishChoiceSelection(ticket) end
        self.manualRotation = false
        return self:SwitchRotation()
    end

    local selected = self.currentRotation
    if not activeChangeCurrent(self, change) then return nil end

    if selected ~= id then
        if not retireActive(self, change) or not activeChangeCurrent(self, change) then return nil end
        if not activeCall(self, change, 'RemoveAllCurrentGlows') then return nil end

        if not commitActive(self, change, self.currentSpec, id, body) or not activeChangeCurrent(self, change) then
            return nil
        end

        self.manualRotation = true
        self.skipAnnounce = true
        self.avail_announced = {}
        self.announced = {}
        if not activeCall(self, change, 'EnableRotationTimer') then return nil end
        local named, name = activeValue(self, change, 'GetRotationName', id)
        if not named or not activeBroker(self, change, DataBroker, name) then return nil end

        if not activeObjectCall(self, change, AceEvent, 'SendMessage', 'ROTATIONMASTER_ROTATION', id, name) then
            return nil
        end
    else
        self.manualRotation = true
    end

    if remember then
        local named, name = activeValue(
            self,
            change,
            self.GetRotationLabel and 'GetRotationLabel' or 'GetRotationName',
            id
        )

        if
            not named
            or not activeCall(
                self,
                change,
                'info',
                L["Active rotation manually switched to |cFFFFFFFF%s|cFF7BC653"],
                name
            )
        then
            return nil
        end

        local checked, valid = activeValue(self, change, 'rotationValidConditions', body, self.currentSpec)
        if not checked then return nil end

        if
            not valid
            and not activeCall(self, change, 'warn', L["Active rotation is incomplete and may not work correctly!"])
        then
            return nil
        end

        if ticket then finishChoiceSelection(ticket) end
    end

    return true, change
end

-- Re-applies the saved manual choice when it changed (spec, action context or profile switch). Returns handled and the
-- open transition token: true means this call took over selection (or stopped on an error report) and automatic
-- switching must not run; false lets it continue.
local function restoreManualChoice(self)
    if choiceNeedsRefresh and choiceNeedsRefresh(self) then
        local change = beginActive(self)
        if not activeChangeCurrent(self, change) then return true end
        local desired, changed = readDesiredChoice(self)
        if not activeChangeCurrent(self, change) then return true end
        if self.adviceErrorReport or self.initializationErrorReport then return true end

        if changed then
            local wasManual = self.manualRotation
            if not activeChangeCurrent(self, change) then return true end
            self.rotationChoiceSuspended = nil
            self.manualRotation = false

            if desired then
                local available = self.GetScopedRotationCoordinator
                if not activeChangeCurrent(self, change) then return true end
                local checked, coordinator, reference, key

                if available then
                    checked, coordinator = activeValue(self, change, 'GetScopedRotationCoordinator')
                    if not checked then return true end
                end

                if coordinator then
                    checked, reference = activeObjectValue(
                        self,
                        change,
                        coordinator,
                        'Resolve',
                        self.currentSpec,
                        desired
                    )

                    if not checked then return true end

                    if reference then
                        checked, key = activeObjectValue(self, change, coordinator, 'Key', reference)
                        if not checked then return true end
                    end
                end

                if not activeChangeCurrent(self, change) then return true end
                if reference and chooseManualRotation(self, key, change, false) then return true, change end
                if not activeChangeCurrent(self, change) then return true end
                self.rotationChoiceSuspended = true
            end

            if wasManual and self.currentRotation then
                local disable = self.DisableRotation
                if not activeChangeCurrent(self, change) then return true end
                local _, nextChange, stopped = disable(self)
                if stopped == false then return true end
                change = nextChange or change
                if not activeChangeCurrent(self, change) then return true end
            end
        end

        return false, change
    end

    return false
end

-- ============================================================================
-- Slash commands
-- ============================================================================

-- Dispatcher for /rm and /rotationmaster; `str` is the raw argument text. While initialization has failed only
-- `errors` and `help` run and every other command opens the error report. `set` accepts an identifier first, then an
-- exact rotation name, and explains why a named rotation cannot be selected.
function addon:HandleCommand(str)
    local cmd, npos = AceConsole:GetArgs(str, 1, 1)

    if self.initializationErrorReport and cmd and cmd ~= "errors" and cmd ~= "help" then
        self:ShowErrors()
        return
    end

    if not cmd or cmd == "help" then
        addon:print(L["/rm help                - This text."])
        addon:print(L["/rm config              - Open the config dialog."])
        addon:print(L["/rm disable             - Disable battle rotation."])
        addon:print(L["/rm enable              - Enable battle rotation."])
        addon:print(L["/rm toggle              - Toggle between enabled and disabled."])
        addon:print(L["/rm current             - Print out the name of the current rotation."])
        addon:print(L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."])

        addon:print(
            L["                          Manual choices are remembered for this character, specialization and action context."]
        )

        addon:print(L["/rm why                 - Explain why each rotation can or cannot be selected."])
        addon:print(L["/rm debug glow [seconds] - Explain why a recommendation does or does not light a button."])
        addon:print(L['/rm debug editor        - Copy native Lua input diagnostics.'])
        addon:print(L['/rm debug talents [views] - Report why the Retail and Forever talent lists are short or empty.'])

        addon:print(
            L['/rm debug timeline [seconds] - Report what the Retail and Forever encounter timeline offers to addons.']
        )

        addon:print(L["/rm check               - Check the database integrity."])
        addon:print(L["/rm repair              - Fix any DB errors found in the data with internal validation."])
        addon:print(L["/rm errors              - View and copy Rotation Master errors."])
        addon:print(L['/rm perf cpu|runtime|memory [seconds|stop|report] - Capture performance observations.'])
        addon:print(L['/rm perf probe - Check native profiler access.'])
        addon:print(L['/rm perf engine [lean|standard] - Show or choose the rotation evaluation engine.'])
    elseif cmd == "config" then
        self:ShowConfig("Rotations")
    elseif cmd == "errors" then
        self:ShowErrors()
    elseif cmd == "why" then
        self:ShowRotationEligibilityReport()
    elseif cmd == "list" and self.ShowRotationIdentifierReport then
        self:ShowRotationIdentifierReport()
    elseif cmd == "debug" and self.HandleDebugCommand then
        self:HandleDebugCommand(string.sub(str, npos))
    elseif cmd == 'perf' then
        self:HandlePerformanceCommand(string.sub(str, npos))
    elseif cmd == "disable" then
        addon:disable()
    elseif cmd == "enable" then
        addon:enable()
    elseif cmd == "toggle" then
        if self.currentRotation == nil then
            addon:enable()
        else
            addon:disable()
        end
    elseif cmd == "current" then
        if self.currentRotation == nil then
            addon:print(L["No rotation is currently active."])
        else
            addon:print(L["The current rotation is |cFFFFFFFF%s|cFF7BC653"], addon:GetRotationName(
                self.currentRotation
            ))
        end
    elseif cmd == "set" then
        local change = beginActive(self)
        local name = string.sub(str, npos)
        if not activeChangeCurrent(self, change) then return end

        if name == "auto" then
            chooseManualRotation(self, nil, change, true)
        elseif name == self.currentRotation or name == DEFAULT then
            if
                not chooseManualRotation(self, name, change, true)
                and activeChangeCurrent(self, change)
                and name == DEFAULT
            then
                self:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.'])
                self:WarnRotationRefusal(DEFAULT)
            end
        else
            local rows = runtimeRows(self, self.currentSpec)
            if not activeChangeCurrent(self, change) then return end

            -- An identifier first (case-insensitive, among selectable rotations),
            -- then the exact name, as before.
            if self.ResolveRotationIdentifier then
                local key, _, _, ambiguous = self:ResolveRotationIdentifier(self.currentSpec, name, rows)
                if not activeChangeCurrent(self, change) then return end

                if key then
                    if not chooseManualRotation(self, key, change, true) and activeChangeCurrent(self, change) then
                        self:WarnRotationRefusal(key)
                    end

                    return
                end

                if ambiguous then
                    self:warn(
                        L['More than one rotation uses the identifier %s. Give one of them another identifier in Rotations.'],
                        name
                    )

                    return
                end

                -- An identifier of a rotation that cannot be selected now says why.
                local named, entry = self:ResolveRotationIdentifier(self.currentSpec, name, nil)
                if not activeChangeCurrent(self, change) then return end

                if named and entry then
                    self:warn(L["Rotation %s cannot be selected."], string.format(
                        '%s [%s]',
                        entry.name,
                        entry.identifier
                    ))

                    self:WarnRotationRefusal(named)
                    return
                end
            end

            local matches = {}

            for id, rot in pairs(rows) do
                if rot.name == name then matches[#matches + 1] = id end
            end

            if not activeChangeCurrent(self, change) then return end

            if #matches > 1 then
                self:warn(
                    L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],
                    name
                )

                return
            end

            if #matches == 1 then
                if not chooseManualRotation(self, matches[1], change, true) and activeChangeCurrent(self, change) then
                    self:WarnRotationRefusal(matches[1])
                end

                return
            end

            -- Candidates hold only selectable rotations; say why a named one is not.
            local headers = self.ListRotationHeaders and self:ListRotationHeaders(self.currentSpec)
            if not activeChangeCurrent(self, change) then return end

            for _, row in ipairs(type(headers) == 'table' and headers or {}) do
                if row.name == name and not row.fallback then
                    self:warn(L["Rotation %s cannot be selected."], name)
                    self:WarnRotationRefusal(row.key)
                    return
                end
            end

            self:warn(L["Could not find rotation named |cFFFFFFFF%s|cFFB212B7 for your current specialization."], name)

            if self.ResolveRotationIdentifier then
                local selectable = self:ListSelectableIdentifiers(self.currentSpec, rows)

                if selectable and #selectable > 0 then
                    self:print(
                        L['Identifiers you can use now: %s (or auto). /rm list shows every rotation.'],
                        table.concat(selectable, ', ')
                    )
                end
            end
        end
    elseif cmd == "check" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, false)
    elseif cmd == "repair" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, true)
    else
        addon:warn(L["Invalid option |cFFFFFFFF%s|cFFB212B7"], cmd)
    end
end

-- ============================================================================
-- Questie integration
-- ============================================================================

-- One optional-provider lifetime, independent of the rotation event owner.
-- Settings only publish saved preferences through SyncQuestieIntegration.
local questieService, questieEvents, questieEnabled

-- Builds the Questie adapter once, if the integrations module offers one, and applies the saved preference to it.
function addon:InitializeQuestieIntegration()
    if questieService then return end
    local factory = self.Integrations and self.Integrations.NewQuestie
    if type(factory) ~= 'function' then return end
    questieService = factory()
    self:SyncQuestieIntegration()
end

-- Applies profile.questie_enabled to the adapter. While enabled it listens for ADDON_LOADED so a Questie that loads
-- later is refreshed. Returns false when there is no adapter, true otherwise; does nothing if the setting is unchanged.
function addon:SyncQuestieIntegration()
    if not questieService then return false end
    local enabled = self.db and self.db.profile and self.db.profile.questie_enabled == true or false
    if enabled == questieEnabled then return true end
    questieEnabled = enabled

    if enabled then
        if not questieEvents then
            questieEvents = CreateFrame('Frame')

            questieEvents:SetScript('OnEvent', function(_, event, name)
                if event == 'ADDON_LOADED' and name == 'Questie' and questieEnabled then questieService:Refresh() end
            end)
        end

        questieEvents:RegisterEvent('ADDON_LOADED')
    elseif questieEvents then
        questieEvents:UnregisterEvent('ADDON_LOADED')
    end

    questieService:SetEnabled(enabled)
    return true
end

-- The adapter's status record, or an "unavailable" record when no adapter was created.
function addon:GetQuestieIntegrationStatus()
    if questieService then return questieService:GetStatus() end
    return { state = 'unavailable', reason = 'adapter-unavailable', nativeAcceptance = 'unverified' }
end

-- Asks the adapter to rescan while the integration is enabled; otherwise returns the current status unchanged.
function addon:RefreshQuestieIntegration()
    if questieService and questieEnabled then return questieService:Refresh() end
    return self:GetQuestieIntegrationStatus()
end

-- ============================================================================
-- Initialization, enable and disable
-- ============================================================================

-- The body of OnInitialize: registers the chat commands, opens the database, registers custom conditions and the
-- Built In module, and sets every runtime field to its empty state. It runs under Diagnostics:Call so an error leaves
-- the addon inert (see OnInitialize) instead of half built.
function addon:OnInitializeInternal()
    AceConsole:RegisterChatCommand("rm", function(str)
        addon:HandleCommand(str)
    end)

    AceConsole:RegisterChatCommand("rotationmaster", function(str)
        addon:HandleCommand(str)
    end)

    self:augmentDefaults(defaults)

    if self.InitializeScopedRotationStorage then
        -- Even false/malformed legacy roots are evidence. AceDB table defaults
        -- would replace false before migration can inventory it.
        defaults.profile.rotations = nil
        defaults.profile.rotationLibrary = nil
    end

    self.db = LibStub("AceDB-3.0"):New(self.savedVariableName, defaults, true)

    -- BEGIN CACHE DIAGNOSTIC INITIALIZATION
    if type(self.InitializeCacheDiagnosticMode) == "function" then
        self:InitializeCacheDiagnosticMode(self.db.global)
    end

    -- END CACHE DIAGNOSTIC INITIALIZATION

    for ext_addon, conditions in pairs(self.delayed_condition) do
        if IsAddOnLoaded(ext_addon) then
            for name, condition in pairs(conditions) do
                self:RegisterCondition(name, condition)
            end
        end
    end

    if self.RefreshRotationProfileStorage then self:RefreshRotationProfileStorage() end
    self:init()
    self:validate(defaults)

    if type(self.db.profile.minimap) == "boolean" then
        self.db.profile.minimap = nil
    end

    DBIcon:Register(addon.name, DataBroker, self.db.profile.minimap)
    DataBroker.text = color.RED .. OFF

    self.funcDeserialize = {}
    if self.InitializeFunctionRegistry then self:InitializeFunctionRegistry() end

    for key, condition in pairs(self.db.global.custom_conditions) do
        addon:register_custom_condition(key, condition)
    end

    -- This character's Built In packs register before the catalog is built.
    if self.LoadBuiltInModule then self:LoadBuiltInModule() end
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end

    -- These values are cached for the entire time you are in combat.  Their values
    -- are unlikely to change during combat (and if they do, they will have minimal effect)
    self.combatCache = {}

    -- These values are cached until the cache is reset (spec change, etc).  Their values
    -- will not change without a respec (or sometimes never).
    self.longtermCache = {}

    self.currentSpec = nil
    self.currentForm = nil

    -- This is a list of rotations that are available (ie. they are complete).  So we don't
    -- have to call validate in a time of battle.
    self.autoswitchRotation = {}

    self.currentRotation = nil
    self.manualRotation = false
    self.rotationChoiceSuspended = nil

    self.inCombat = false

    self.rotationTimer = nil
    self.fetchTimer = nil
    self.shapeshiftTimer = nil

    -- This is a cache of spec based spell names -> IDs.  Updated when we switch specs.
    self.specSpells = {}
    self.specSpellsReverse = {}
    self.bagContents = {}

    self.specTalents = {}

    self.unitsInRange = {}
    -- Restricted clients make an NPC's GUID secret, so they keep the nameplate
    -- unit tokens instead (Core/threat_count_conditions.lua); nil elsewhere.
    local platform = self.Platform

    self.nameplateUnits = platform
        and platform.GetCombatDataPolicy
        and platform:GetCombatDataPolicy() == 'restricted'
        and {}
        or nil

    self.damageHistory = {}
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.lastRangedShot = nil

    self.spellHistory = {}
    self.combatHistory = {}

    self.avail_announced = {}
    self.announced = {}
    self.skipAnnounce = true

    self.currentConditionEval = nil
    self.conditionEvalTimer = nil
    self.lastCacheReport = GetTime()

    self.itemSetButtons = {}
    self.itemSetCallback = nil
    self.bindingItemSet = nil

    if initializeEvaluationProfiler then
        initializeEvaluationProfiler(self)
    else
        self.evaluationProfile = addon:ProfiledCode()
    end

    self.currentSpell = nil
    self.nextWindow = nil
    if self.InstallRotationProfileLifecycle then self:InstallRotationProfileLifecycle() end

    -- This is here because of order of loading.
    getCached = addon.Functions.cache.getCached

    self:InitializeQuestieIntegration()
    if self.InitializeEncounterIntegration then self:InitializeEncounterIntegration() end

    --self:SetupOptions()
end

-- AceAddon entry point. Runs OnInitializeInternal under the error recorder when Diagnostics is loaded and stores the
-- failure report so OnEnable and the gameplay events stay off. Returns ok and the report id.
function addon:OnInitialize()
    -- A failed initializer must not be followed by OnEnable or gameplay events
    -- using half-built state. Diagnostics stays independent of the database.
    self.initializationErrorReport = 0
    local ok, reportId

    if self.Diagnostics then
        ok, reportId = self.Diagnostics:Call({
            module = "startup",
            operation = "initialization",
        }, self.OnInitializeInternal, self)
    else
        self:OnInitializeInternal()
        ok = true
    end

    if ok then
        self.initializationErrorReport = nil
        self.adviceErrorReport = nil
    else
        self.initializationErrorReport = reportId or 0
        self.adviceErrorReport = reportId or 0
    end

    return ok, reportId
end

-- One warning line naming why `value` cannot be selected for this character.
function addon:WarnRotationRefusal(value)
    local why = self.ExplainRotationRefusal and self:ExplainRotationRefusal(self.currentSpec, value)
    if why then self:warn(L['Reason: %s. Type /rm why to check every rotation.'], why) end
end

-- The name of rotation `id` in the current specialization (DEFAULT for the fallback), or nil when it is not selectable.
function addon:GetRotationName(id)
    if id == DEFAULT then
        return DEFAULT
    else
        local body = runtimeOne(self, self.currentSpec, id)
        return body and body.name or nil
    end
end

-- ============================================================================
-- Minimap menu and data broker
-- ============================================================================

-- Menu callback for the "Battle rotation enabled" checkbox; `checked` is the new state.
local function minimapToggleRotation(_, _, _, checked)
    if checked then
        addon:enable()
    else
        addon:disable()
    end
end

-- Menu callback for a rotation entry: `arg1` is the rotation id, or nil for Automatic Switching. The choice is
-- remembered.
local function minimapChangeRotation(_, arg1)
    chooseManualRotation(addon, arg1, nil, true)
end

-- Initializer of the minimap right-click dropdown: the enable checkbox, Automatic Switching, the fallback and every
-- selectable rotation (Built Ins in blue), then a note about Built Ins that apply but are switched off.
function minimapInitialize()
    local info = UIDropDownMenu_CreateInfo()
    info.text = addon.pretty_name
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.text, info.checked = L["Battle rotation enabled"], addon.db.profile.enable
    info.func = minimapToggleRotation
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.text = " "
    info.notClickable = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)
    info.isTitle = true
    info.text = L["Current Rotation"]
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.func = minimapChangeRotation
    info.text, info.arg1, info.checked = L["Automatic Switching"], nil, (addon.manualRotation == false)
    UIDropDownMenu_AddButton(info)

    info.text, info.arg1, info.checked =
        DEFAULT, DEFAULT, (addon.manualRotation == true and addon.currentRotation == DEFAULT)

    UIDropDownMenu_AddButton(info)

    do
        for id, rot in pairs(runtimeRows(addon, addon.currentSpec)) do
            if id ~= DEFAULT then
                local identifier = addon.GetRotationIdentifier and addon:GetRotationIdentifier(addon.currentSpec, id)
                local label = identifier and string.format('%s [%s]', tostring(rot.name), identifier) or rot.name

                info.text, info.arg1, info.checked =
                    label, id, (addon.manualRotation == true and addon.currentRotation == id)

                -- Built Ins are told apart by colour; the tooltip says so.
                info.tooltipTitle, info.tooltipText, info.tooltipOnButton = nil, nil, nil

                if addon:IsDefaultRuntimeRotation(addon.currentSpec, id) then
                    info.text = "|cff5bc0eb" .. tostring(label) .. "|r"

                    info.tooltipTitle, info.tooltipText, info.tooltipOnButton =
                        rot.name, L["Built In · read-only"], true
                end

                UIDropDownMenu_AddButton(info)
            end
        end
    end

    -- A Built In that would apply now but is switched off is not offered;
    -- say so, so a forgotten toggle is not mistaken for a missing rotation.
    local hidden = addon.GetDisabledApplicableBuiltins and addon:GetDisabledApplicableBuiltins(addon.currentSpec)

    if hidden and #hidden > 0 then
        local names = {}

        for _, row in ipairs(hidden) do
            names[#names + 1] = row.name
        end

        info = UIDropDownMenu_CreateInfo()
        info.notCheckable = true

        info.text = "|cff808080"
            .. string.format(L["%d Built In disabled: %s"], #hidden, table.concat(names, ", "))
            .. "|r"

        info.tooltipTitle = L["Disabled Built In rotations"]
        info.tooltipText = L["Open Rotations, select the Built In and turn it back on to make it selectable."]
        info.tooltipOnButton = true
        info.func = function() addon:ShowConfig("Rotations") end
        UIDropDownMenu_AddButton(info)
    end
end

-- Broker click: right opens the rotation menu, left toggles the configuration window. After a failed initialization any
-- click opens the error report instead.
function DataBroker.OnClick(_, button)
    if addon.initializationErrorReport then
        addon:ShowErrors()
        return
    end

    if button == "RightButton" then
        local frame = CreateFrame("Frame", addon_name .. "LDBFrame")
        local dropdownFrame = CreateFrame("Frame", addon_name .. "LDBDropdownFrame", frame, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        local shell = addon.configWindow

        if shell and shell.frame:IsShown() then
            shell:Hide()
        else
            addon:ShowConfig("Rotations")
        end
    end
end

-- Fills the broker tooltip with the addon version, the active rotation (or "disabled") and a notice when a saved manual
-- choice cannot apply in the current context.
function DataBroker.OnTooltipShow(GameTooltip)
    GameTooltip:SetText(addon.pretty_name .. " " .. GetAddOnMetadata(addon_name, "Version"), 0, 1, 1)
    GameTooltip:AddLine(" ")

    if addon.currentRotation ~= nil then
        GameTooltip:AddLine(L["Current Rotation"], 0.55, 0.78, 0.33, 1)

        GameTooltip:AddLine(
            addon.GetRotationLabel and addon:GetRotationLabel(addon.currentRotation) or addon:GetRotationName(
                addon.currentRotation
            ),
            1,
            1,
            1
        )
    else
        GameTooltip:AddLine(L["Battle rotation disabled"], 1, 0, 0, 1)
    end

    if addon.rotationChoiceSuspended then
        GameTooltip:AddLine(L['Saved manual choice is unavailable in the current context.'], 1, 0.8, 0.2, true)
    end
end

-- Flips between enabled and disabled; the target of the key binding declared in Bindings.xml.
function addon:toggle()
    if self.currentRotation == nil then
        self:enable()
    else
        self:disable()
    end
end

-- ============================================================================
-- Event registration
-- ============================================================================

-- These additional notifications vary by client; leave existing subscriptions
-- alone and require the native event catalogue to confirm each optional name.
-- Returns whether the transition is still current and whether the event was registered.
local function registerOptionalEvent(owner, change, event)
    if not activeChangeCurrent(owner, change) then return false end
    local utils = C_EventUtils
    local validEvent = type(utils) == 'table' and utils.IsEventValid
    if not activeChangeCurrent(owner, change) then return false end
    if type(validEvent) ~= 'function' then return activeChangeCurrent(owner, change), false end
    local ok, valid = pcall(validEvent, event)
    if not activeChangeCurrent(owner, change) then return false end

    if ok and valid == true then
        local current = activeCall(owner, change, 'RegisterEvent', event)
        return current, current
    end

    return true, false
end

-- RM only acts on the player's and pet's own casts. A per-unit subscription
-- keeps every other caster nearby from reaching a handler at all. Clients
-- without RegisterUnitEvent keep the ordinary subscription.
local castEvents = {
    UNIT_SPELLCAST_SENT = true,
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
}

-- Restricted clients record only the player's and pet's successful casts
-- (spell history); announcements stay on the probe policy.
local restrictedCastEvents = { UNIT_SPELLCAST_SUCCEEDED = true }

-- Combat observations that still reach addons on restricted clients (the combat log itself does not).
local restrictedCombatEvents = {
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_COMBAT",
    "UNIT_SPELLCAST_SUCCEEDED",
}

-- Private frame carrying the per-unit cast subscriptions; created on first use and forwards to the addon's handlers.
local castFrame

-- Subscribes the cast events in `wanted` (default: all of castEvents) for the player and pet only. Returns false when
-- the client cannot filter by unit; the caller then registers those events the ordinary way.
local function registerCastEvents(self, wanted)
    if not castFrame then
        if type(CreateFrame) ~= 'function' then return false end
        castFrame = CreateFrame('Frame')

        castFrame:SetScript('OnEvent', function(_, event, ...)
            local handler = self[event]
            if handler then handler(self, event, ...) end
        end)
    end

    if not castFrame.RegisterUnitEvent then return false end

    for event in pairs(wanted or castEvents) do
        pcall(castFrame.RegisterUnitEvent, castFrame, event, 'player', 'pet')
    end

    return true
end

-- Nameplates already shown when a restricted client enables. Events keep the
-- set current afterwards; UnitExists carries no secret annotation.
local function seedNameplateUnits(self)
    local units = self.nameplateUnits
    if type(units) ~= 'table' then return end

    for unit in pairs(units) do
        units[unit] = nil
    end

    if type(UnitExists) ~= 'function' then return end

    for index = 1, 40 do
        local unit = 'nameplate' .. index
        local ok, exists = pcall(UnitExists, unit)
        if ok and self.Platform:CanReadValue(exists) and exists == true then units[unit] = true end
    end
end

-- Forward declaration; assigned with the nameplate tracking further down and called by enable() on probe-policy
-- clients.
local reconcileNameplateResume

-- Starts the addon: subscribes the events this client family needs (the combat log only where the policy allows it,
-- a reduced set on restricted clients), refreshes the preview window, selects a rotation and starts the auto-switch
-- timer. Each step re-proves the transition token, so a concurrent enable or disable wins cleanly.
function addon:enable()
    if self.initializationErrorReport then
        self:ShowErrors()
        return
    end

    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return end
    -- BEGIN EQUIPMENT ENABLE LIFETIME
    equipmentSubscription = nil
    local equipmentProfile = self.db.profile
    local equipmentRegistered = false

    -- END EQUIPMENT ENABLE LIFETIME
    for _, v in pairs(events) do
        if not activeCall(self, change, 'RegisterEvent', v) then return end
    end

    local client = self.Platform:GetClientInfo()
    if not activeChangeCurrent(self, change) then return end

    if client.combatDataPolicy == 'probe' then
        local unitCasts = registerCastEvents(self)

        for _, event in ipairs(combat_events) do
            if not (unitCasts and castEvents[event]) and not activeCall(self, change, 'RegisterEvent', event) then
                return
            end
        end
    elseif client.combatDataPolicy == 'restricted' then
        -- The combat log is SecureOnly there; these events still reach addons.
        local unitCasts = registerCastEvents(self, restrictedCastEvents)

        for _, event in ipairs(restrictedCombatEvents) do
            if not (unitCasts and castEvents[event]) and not activeCall(self, change, 'RegisterEvent', event) then
                return
            end
        end

        if self.nameplateUnits == nil then self.nameplateUnits = {} end
        seedNameplateUnits(self)
    end

    local family = client.family
    local extraEvents = family == "retail" or family == "forever"

    extraEvents = extraEvents and mainline_events
        or family == "progression" and wrath_events
        or family == "tbc" and tbc_events
        or family == "era" and classic_events
        or {}

    for _, event in ipairs(extraEvents) do
        if not activeCall(self, change, 'RegisterEvent', event) then return end
    end

    if not registerOptionalEvent(self, change, 'UNIT_EXITED_VEHICLE') then return end

    -- BEGIN ACTION CONTEXT REGISTRATION
    for _, event in ipairs(actionContextEvents) do
        if not registerOptionalEvent(self, change, event) then return end
    end

    if self.RefreshActionContext then self:RefreshActionContext() end

    -- END ACTION CONTEXT REGISTRATION
    if family == 'tbc' then
        if not registerOptionalEvent(self, change, 'PLAYER_TALENT_UPDATE') then return end
        if not registerOptionalEvent(self, change, 'ACTIVE_TALENT_GROUP_CHANGED') then return end
        -- BEGIN EQUIPMENT EVENT REGISTRATION
        local current, registered = registerOptionalEvent(self, change, 'PLAYER_EQUIPMENT_CHANGED')
        if not current then return end
        equipmentRegistered = registered
        -- END EQUIPMENT EVENT REGISTRATION
    end

    if client.combatDataPolicy == 'probe' then
        reconcileNameplateResume(self, change)
        if not activeChangeCurrent(self, change) then return end
    end

    if self.RefreshPreviewWindow then
        if not activeCall(self, change, 'RefreshPreviewWindow') then return end
    end

    if not activeChangeCurrent(self, change) then return end
    local update = self.UpdateSkill
    if not activeChangeCurrent(self, change) then return end
    local _, nextChange = update(self)
    change = nextChange or change
    if not activeChangeCurrent(self, change) then return end
    -- BEGIN EQUIPMENT ENABLE COMMIT
    if not activeCall(self, change, 'EnableRotation') then return end

    if equipmentRegistered and self.db.profile == equipmentProfile and activeChangeCurrent(self, change) then
        equipmentSubscription = {}
    end

    -- END EQUIPMENT ENABLE COMMIT
    if activeChangeCurrent(self, change) then self:StartAutoSwitchTimer() end
end

-- Stops the addon: cancels the auto-switch timer, retires the active rotation, releases the preview window, clears the
-- spell and combat histories and the nameplate set, and unregisters every event.
function addon:disable()
    if self.initializationErrorReport then return end
    self:StopAutoSwitchTimer()
    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return end
    -- BEGIN EQUIPMENT DISABLE LIFETIME
    equipmentSubscription = nil
    -- END EQUIPMENT DISABLE LIFETIME
    local disable = self.DisableRotation
    if not activeChangeCurrent(self, change) then return end
    local _, nextChange, stopped = disable(self)
    change = nextChange or change
    if stopped == false or not activeChangeCurrent(self, change) then return end
    local available = self.nextWindow
    if not activeChangeCurrent(self, change) then return end

    if available then
        local spells = self.db.profile.preview_spells
        local window = self.nextWindow

        if not activeChangeCurrent(self, change) or not activeObjectCall(self, change, window, 'Release') then
            return
        end

        self.nextWindow = nil
        self.db.profile.preview_spells = spells
    end

    self.spellHistory = {}
    self.combatHistory = {}
    local plates = self.nameplateUnits

    if type(plates) == 'table' then
        for unit in pairs(plates) do
            plates[unit] = nil
        end
    end

    if castFrame and castFrame.UnregisterAllEvents then castFrame:UnregisterAllEvents() end
    if not activeCall(self, change, 'UnregisterAllEvents') then return end
end

-- AceAddon entry point: enables the rotation when the profile says so; does nothing after a failed initialization.
function addon:OnEnable()
    if self.initializationErrorReport then return end
    self:info(L["Starting up version %s"], GetAddOnMetadata(addon_name, "Version"))

    -- Live Status Update Frequency drives the rotation editor's live dots,
    -- which run their own timer only while the editor is open (see
    -- UI/rotation_editor.lua). Nothing is scheduled here, so a closed editor
    -- costs nothing.

    if self.db.profile.enable then
        self:enable()
    end
end

-- ============================================================================
-- Automatic rotation switching
-- ============================================================================

-- Whether rotation body `rot` is complete for `spec`: every reachable, enabled step has valid conditions and an action
-- (or is a Stop or Assisted step), item steps name a non-empty item set, and at least one usable step exists.
function addon:rotationValidConditions(rot, spec)
    if type(rot) ~= 'table' or not self.RotationData.GetRotationPriority(rot.priority) then return false end
    local tree = self.RotationData.IndexRotationSteps(rot, { allowMissingIds = true })
    if not tree then return false end
    local itemsets, global_itemsets = self.db.profile.itemsets, self.db.global.itemsets
    local itemfound = false

    for _, row in ipairs(tree.rows) do
        local step = row.step

        if not row.unreachable and not step.disabled then
            if step.type == "branch" then
                if
                    (step.mode == nil or step.mode == "evaluate") and not self:validateCondition(step.conditions, spec)
                then
                    return false
                end
            else
                if step.type == nil or not self:validateCondition(step.conditions, spec) then return false end

                if
                    step.type ~= "stop"
                    and step.action == nil
                    and not (step.type == "assisted" and row.section == "rotation")
                then
                    return false
                end

                if step.type == "item" then
                    if type(step.action) == "string" then
                        local itemset = itemsets[step.action] or global_itemsets[step.action]
                        if not itemset or type(itemset.items) ~= "table" or #itemset.items == 0 then return false end
                    elseif type(step.action) ~= "table" or #step.action == 0 then
                        return false
                    end
                end
            end

            itemfound = true
        end
    end

    return itemfound
end

-- Rebuilds self.autoswitchRotation, the ordered list of rotation ids automatic selection tries for the current
-- specialization, so selection does not have to validate rotations during combat.
function addon:UpdateAutoSwitch()
    local rotations = runtimeRows(self, self.currentSpec, true)
    self.autoswitchRotation = self:GetOrderedAutoSwitchRotations(self.currentSpec, rotations)

    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figures out which of the autoswitch rotations best matches. A remembered manual choice is restored first; nothing
-- happens when automatic switching is off or a manual rotation is active. Otherwise the first matching rotation (else
-- the fallback) is committed, and with none the rotation is disabled. Every step re-proves its transition token.
-- Returns nil and the token when settled, nothing when superseded.
function addon:SwitchRotation()
    local handled, restoredChange = restoreManualChoice(self)
    if handled then return nil, restoredChange end

    if not autoSwitchEnabled(self.db.profile) or self.manualRotation then
        if restoredChange and not activeChangeCurrent(self, restoredChange) then return end
        return nil, restoredChange
    end

    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return end
    local newRotation
    local selectedSpec, selectedProfile, selectedRotation = self.currentSpec, self.db.profile, self.currentRotation
    local selectionPass, rotations

    if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
        selectionPass = mainSelectionPass(self, selectedSpec)
        if not selectionPass then return end
        local why
        rotations, why = selectionPass:Candidates(false)
        if why then return end
    else
        rotations = runtimeRows(self, selectedSpec)
    end

    -- BEGIN SWITCH OWNER LEASE
    -- Lease passed to switch-condition evaluation: true while the transition, specialization, profile, rotation and
    -- automatic mode are all unchanged.
    local function switchOwnerCurrent()
        return activeChangeCurrent(self, change)
            and self.currentSpec == selectedSpec
            and self.db.profile == selectedProfile
            and self.currentRotation == selectedRotation
            and autoSwitchEnabled(self.db.profile)
            and not self.manualRotation
    end

    -- END SWITCH OWNER LEASE
    -- The same proof plus the scoped selection pass still being valid; checked before each state change below.
    local function current()
        return activeChangeCurrent(self, change)
            and self.currentSpec == selectedSpec
            and self.db.profile == selectedProfile
            and self.currentRotation == selectedRotation
            and autoSwitchEnabled(self.db.profile)
            and not self.manualRotation
            and (not selectionPass or selectionPass:IsCurrent())
    end

    -- Enabled rotations, yours and Built Ins alike, are tried by priority
    -- (GetOrderedAutoSwitchRotations: higher first, then name); the first
    -- whose switch condition matches wins. The fallback (Default) is the last
    -- resort when none matches. A Built In you do not want picked is disabled,
    -- or ranked, in its Built In view.
    for _, v in ipairs(self.autoswitchRotation) do
        if not switchOwnerCurrent() then return end
        local matched = rotations[v] and switchConditionMatches(rotations[v].switch, switchOwnerCurrent)
        if not switchOwnerCurrent() then return end

        if matched then
            newRotation = v
            break
        end
    end

    if not newRotation and rotations[DEFAULT] ~= nil and self:rotationValidConditions(
        rotations[DEFAULT],
        self.currentSpec
    ) then
        newRotation = DEFAULT
    end

    if not current() then return end

    if newRotation then
        if self.currentRotation ~= newRotation then
            local name = newRotation == DEFAULT and DEFAULT or rotations[newRotation].name
            if not retireActive(self, change) or not activeChangeCurrent(self, change) then return end
            selectedRotation = nil
            if not activeCall(self, change, 'RemoveAllCurrentGlows') or not current() then return end

            if
                not commitActive(self, change, selectedSpec, newRotation, rotations[newRotation])
                or not activeChangeCurrent(self, change)
            then
                return
            end

            selectedRotation = newRotation
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            if not activeCall(self, change, 'EnableRotationTimer') or not current() then return end
            if not activeBroker(addon, change, DataBroker, name) then return end
            if not current() then return end
            local label = name

            -- The name is already known; only the identifier is added (no second pass).
            if self.FormatRotationLabel then
                local labelled, value = activeValue(
                    self,
                    change,
                    'FormatRotationLabel',
                    name,
                    newRotation,
                    selectedSpec
                )

                if not labelled then return end
                label = value or name
            end

            if not current() then return end

            if not activeCall(
                self,
                change,
                'info',
                L["Active rotation automatically switched to |cFFFFFFFF%s|cFF7BC653"],
                label
            ) then
                return
            end

            if not current() then return end

            if not activeObjectCall(
                self,
                change,
                AceEvent,
                'SendMessage',
                "ROTATIONMASTER_ROTATION",
                self.currentRotation,
                name
            ) then
                return
            end
        end

        return nil, change
    end

    -- Could not find a rotation to switch to, even the default one.
    if self.currentRotation ~= nil then
        local explain

        if self.GetActionContext and self:GetActionContext() ~= 'player' then
            addon:info(L["Advice is suspended: no rotation applies while you are using another action bar."])
        else
            addon:warn(L["No rotation is active as there is none suitable to automatically switch to."])
            explain = true
        end

        if not current() then return end
        self:DisableRotation()
        if explain then addon:WarnRotationRefusal(DEFAULT) end
    end
end

-- Auto mode re-checks selection every autoswitch_poll seconds, in and out of
-- combat, so volatile switch conditions (enemy count, threat, movement,
-- health...) take effect. The check below is read-only and follows the same
-- order as SwitchRotation; only a different answer goes through
-- SwitchRotation, whose transition retires current work.
local function autoSwitchCandidate(self)
    local spec, rotations = self.currentSpec, nil

    if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
        local pass = mainSelectionPass(self, spec)
        if not pass then return nil, false end
        local why
        rotations, why = pass:Candidates(false)
        if why then return nil, false end
    else
        rotations = runtimeRows(self, spec)
    end

    for _, v in ipairs(self.autoswitchRotation) do
        if rotations[v] and switchConditionMatches(rotations[v].switch) then return v, true end
    end

    if rotations[DEFAULT] ~= nil and self:rotationValidConditions(rotations[DEFAULT], spec) then
        return DEFAULT, true
    end

    return nil, true
end

-- Whether a switch condition matches now (true/false; nil when it cannot be
-- evaluated). Commands and menus only; polling uses the paths above.
function addon:SwitchConditionMatchesNow(condition)
    if condition == nil then return true end
    if type(condition) ~= 'table' then return nil end
    local ok, matched = pcall(switchConditionMatches, condition)
    if not ok then return nil end
    return matched and true or false
end

-- /rm why: the rotation automatic switching would choose now (nil when none),
-- by the same order and checks as the re-check above. Command only.
function addon:PreviewAutoSwitch()
    if not self.autoswitchRotation then return nil end
    return (autoSwitchCandidate(self))
end

-- One periodic or event-driven re-check. Settles an action-bar context change first, then calls SwitchRotation only
-- when the read-only candidate differs from the current rotation. Skipped after an error, when disabled, and in manual
-- mode.
function addon:AutoSwitchTick()
    local profile = self.db.profile
    if self.initializationErrorReport or self.adviceErrorReport or not profile.enable then return end
    -- A client without one of the bar notifications still settles here, once
    -- per re-check (never per poll); a change runs the full transition.
    if self.ApplyActionContext and self:ApplyActionContext() then return end
    if not autoSwitchEnabled(profile) or self.manualRotation then return end
    local candidate, known = autoSwitchCandidate(self)
    if known and candidate == self.currentRotation then return end
    self:SwitchRotation()
end

-- Diagnostics context for the auto-switch timer, reused (and updated in place) on every tick.
local autoSwitchContext = { module = "events", operation = "autoswitch" }

-- Timer callback: runs AutoSwitchTick under the error recorder and stops the timer after the first failure.
function addon:AutoSwitchTimer()
    if not self.Diagnostics then return self:AutoSwitchTick() end
    autoSwitchContext.rotationId = self.currentRotation
    local ok = self.Diagnostics:Call(autoSwitchContext, self.AutoSwitchTick, self)
    -- A failing check is recorded once rather than every second.
    if not ok then self:StopAutoSwitchTimer() end
end

-- Cancels the repeating auto-switch timer if one is scheduled.
function addon:StopAutoSwitchTimer()
    if self.autoSwitchTimer and self.CancelTimer then
        self:CancelTimer(self.autoSwitchTimer)
        self.autoSwitchTimer = nil
    end
end

-- Event-driven check (target, focus, pet): Auto mode checks read-only first,
-- so an unchanged selection keeps the current evaluation plan; manual mode
-- keeps SwitchRotation's remembered-choice handling.
function addon:CheckAutoSwitch()
    local profile = self.db and self.db.profile
    if not profile or not autoSwitchEnabled(profile) or self.manualRotation then return self:SwitchRotation() end
    return self:AutoSwitchTick()
end

-- (Re)starts the auto-switch timer from profile.autoswitch_poll (seconds; zero or less leaves it off) and migrates the
-- retired disable flag to an interval of zero.
function addon:StartAutoSwitchTimer()
    self:StopAutoSwitchTimer()
    local profile = self.db and self.db.profile
    if not profile or type(self.ScheduleRepeatingTimer) ~= 'function' then return end

    -- Migrate the retired Disable Auto-Switching flag to interval 0.
    if profile.disable_autoswitch then
        profile.autoswitch_poll = 0
        profile.disable_autoswitch = nil
    end

    local interval = tonumber(profile.autoswitch_poll)

    if interval and interval > 0 then
        self.autoSwitchTimer = self:ScheduleRepeatingTimer('AutoSwitchTimer', interval)
    end
end

-- ============================================================================
-- Rotation activation and the poll timer
-- ============================================================================

-- Activates a rotation for the current specialization: rescans the buttons, rebuilds the autoswitch list, runs
-- SwitchRotation and shows the chosen name on the broker. Does nothing without a spec or when one is already active.
function addon:EnableRotation()
    if self.currentSpec == nil or self.currentRotation then return end
    local change = beginActive(self)
    if not activeCall(self, change, 'Fetch') then return end
    if not activeCall(self, change, 'UpdateAutoSwitch') then return end
    local method = self.SwitchRotation
    if not activeChangeCurrent(self, change) then return end
    local _, nextChange = method(self)
    change = nextChange or change
    if not activeChangeCurrent(self, change) then return end

    if self.currentRotation ~= nil then
        local getName = self.GetRotationName
        if not activeChangeCurrent(self, change) then return end
        local name = getName(self, self.currentRotation)
        if not activeChangeCurrent(self, change) then return end
        if not activeBroker(self, change, DataBroker, name) then return end
        activeCall(self, change, 'info', L["Battle rotation enabled"])
    end
end

-- Retires the active rotation: ends the poll timer, clears glows, the preview window, the broker text and the
-- WeakAuras signal. Returns nil, token, true when done (or nothing was active) and nil, nil, false when the transition
-- was superseded or a step refused.
function addon:DisableRotation()
    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return nil, nil, false end

    -- BEGIN ANALYTICS DISABLE
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self, change) then return nil, nil, false end
    end

    -- END ANALYTICS DISABLE
    local selected = self.currentRotation
    if not retireActive(self, change) or not activeChangeCurrent(self, change) then return nil, nil, false end

    if retireConditionRuntime then
        local previous = lastConditionSession
        retireConditionRuntime(self)
        if lastConditionSession == previous then lastConditionSession = nil end
        if not activeChangeCurrent(self, change) then return nil, nil, false end
    end

    if not selected then return nil, change, true end
    self.currentSpell = nil
    self.avail_announced = {}
    self.announced = {}
    if not activeCall(self, change, 'DisableRotationTimer') then return nil, nil, false end
    if not activeCall(self, change, 'RemoveAllCurrentGlows') then return nil, nil, false end
    if not activeCall(self, change, 'DestroyAllGlows') then return nil, nil, false end
    local availableWindow = self.nextWindow
    if not activeChangeCurrent(self, change) then return nil, nil, false end

    if availableWindow then
        local window = self.nextWindow

        if not activeChangeCurrent(self, change) or not activeObjectCall(self, change, window, 'ReleaseChildren') then
            return nil, nil, false
        end
    end

    if not activeChangeCurrent(self, change) then return nil, nil, false end
    if not activeBroker(self, change, DataBroker, color.RED .. OFF) then return nil, nil, false end

    if not activeObjectCall(self, change, AceEvent, 'SendMessage', "ROTATIONMASTER_ROTATION", nil) then
        return nil, nil, false
    end

    if not activeObjectCall(self, change, AceEvent, 'SendMessage', "ROTATIONMASTER_SPELL_UPDATE", nil, nil) then
        return nil, nil, false
    end

    local weak = _G.WeakAuras
    if not activeChangeCurrent(self, change) then return nil, nil, false end

    if weak then
        local available = weak.ScanEvents
        if not activeChangeCurrent(self, change) then return nil, nil, false end

        if available then
            local scan = weak.ScanEvents
            if not activeChangeCurrent(self, change) then return nil, nil, false end
            scan("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
        end
    end

    if not activeChangeCurrent(self, change) then return nil, nil, false end
    if not activeCall(self, change, 'info', L["Battle rotation disabled"]) then return nil, nil, false end
    return nil, change, true
end

-- Idle gate. Out of combat with no target and no focus, the units a rotation
-- can read (player, pet, party, mouseover) only change on the notifications
-- below, with two exceptions: time (aura/cooldown remaining) and position. So
-- a timer tick re-evaluates only after one of these notifications, or once
-- every idle_poll seconds as a floor for time, position and custom code. In
-- combat, with any target or focus (whose target-of-target has no events of
-- its own), or with the configuration window open, every tick evaluates as
-- before. idle_poll = 0 turns the gate off. Direct EvaluateNextAction calls
-- (events, buttons) are never gated.
-- Unit-scoped notifications that mark the gate dirty (registered per unit group where the client allows it).
local idleUnitEvents = {
    'UNIT_AURA', 'UNIT_HEALTH', 'UNIT_MAXHEALTH', 'UNIT_POWER_UPDATE', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER',
    'UNIT_INVENTORY_CHANGED', 'UNIT_FLAGS', 'UNIT_FACTION', 'UNIT_LEVEL', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP', 'UNIT_TARGET'
}

-- Unit pairs that share a frame: RegisterUnitEvent takes at most two units per call.
local idleUnitGroups = { { 'player', 'pet' }, { 'target', 'focus' }, { 'party1', 'party2' }, { 'party3', 'party4' } }

-- Non-unit notifications that mark the gate dirty.
local idleEvents = {
    'SPELL_UPDATE_COOLDOWN', 'SPELL_UPDATE_USABLE', 'SPELL_UPDATE_CHARGES', 'ACTIONBAR_UPDATE_COOLDOWN',
    'ACTIONBAR_UPDATE_USABLE', 'ACTIONBAR_UPDATE_STATE', 'BAG_UPDATE', 'BAG_UPDATE_COOLDOWN', 'PLAYER_STARTED_MOVING',
    'PLAYER_STOPPED_MOVING', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'PLAYER_REGEN_DISABLED',
    'PLAYER_REGEN_ENABLED', 'PLAYER_ENTERING_WORLD', 'PLAYER_TOTEM_UPDATE', 'PLAYER_EQUIPMENT_CHANGED',
    'PLAYER_MOUNT_DISPLAY_CHANGED', 'PLAYER_UPDATE_RESTING', 'PLAYER_ALIVE', 'PLAYER_DEAD', 'PLAYER_UNGHOST',
    'PLAYER_CONTROL_LOST', 'PLAYER_CONTROL_GAINED', 'PLAYER_LEVEL_UP', 'UPDATE_SHAPESHIFT_FORM', 'UPDATE_STEALTH',
    'SPELLS_CHANGED', 'UNIT_PET', 'PET_BAR_UPDATE', 'UNIT_ENTERED_VEHICLE', 'UNIT_EXITED_VEHICLE',
    'UPDATE_MOUSEOVER_UNIT', 'GROUP_ROSTER_UPDATE', 'ZONE_CHANGED', 'ZONE_CHANGED_INDOORS', 'ZONE_CHANGED_NEW_AREA',
    'RUNE_POWER_UPDATE', 'UNIT_COMBO_POINTS', 'UPDATE_SHAPESHIFT_COOLDOWN', 'ENCOUNTER_START', 'ENCOUNTER_END',
    'SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 'SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 'ECLIPSE_DIRECTION_CHANGE'
}

-- Gate state, also read by Diagnostics/cpu_runtime.lua: `dirty` forces the next tick to evaluate, `nextEval` is the
-- idle floor, `evaluated` and `skipped` count ticks.
local idleGate = { dirty = true, nextEval = 0, evaluated = 0, skipped = 0 }
addon.idleGate = idleGate

-- Registers `event` on `frame`, for the given units when any are passed and the frame supports unit events.
local function register(frame, event, ...)
    -- Event names vary by client; an unknown name must not stop the rest.
    if select('#', ...) > 0 and frame.RegisterUnitEvent then
        pcall(frame.RegisterUnitEvent, frame, event, ...)
    else
        pcall(frame.RegisterEvent, frame, event)
    end
end

-- Registers every gate event and marks the gate dirty; does nothing if already registered.
-- Frames cannot be destroyed, so they are created once and only their
-- registrations follow the rotation timer.
local function startIdleGate()
    idleGate.dirty = true
    if idleGate.registered or type(CreateFrame) ~= 'function' then return end
    local frames = idleGate.frames

    if not frames then
        -- Any registered event marks the gate dirty, so the next tick evaluates.
        local function dirty()
            idleGate.dirty = true
        end

        frames = { CreateFrame('Frame') }

        if frames[1].RegisterUnitEvent then
            for i = 1, #idleUnitGroups do
                frames[i + 1] = CreateFrame('Frame')
            end
        end

        for _, frame in ipairs(frames) do
            frame:SetScript('OnEvent', dirty)
        end

        idleGate.frames = frames
    end

    local shared = frames[1]

    for _, event in ipairs(idleEvents) do
        register(shared, event)
    end

    if #frames > 1 then
        for i, units in ipairs(idleUnitGroups) do
            for _, event in ipairs(idleUnitEvents) do
                register(frames[i + 1], event, units[1], units[2])
            end
        end
    else
        for _, event in ipairs(idleUnitEvents) do
            register(shared, event)
        end
    end

    idleGate.registered = true
end

-- Unregisters every gate event and marks the gate dirty so the next start evaluates at once.
local function stopIdleGate()
    for _, frame in ipairs(idleGate.frames or {}) do
        if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
    end

    idleGate.registered = false
    idleGate.dirty = true
end

-- The poll timer's callback. Out of combat it skips the tick while the idle gate is clean, the floor has not passed,
-- the rotation is unchanged, the configuration window is closed and there is no target or focus; otherwise it runs
-- EvaluateNextAction.
function addon:EvaluateNextActionTimer()
    local interval = self.db.profile.idle_poll

    if interval and interval > 0 and not self.inCombat then
        local now = GetTime()
        local shell = self.configWindow

        if
            not idleGate.dirty
            and now < idleGate.nextEval
            and self.currentRotation == idleGate.rotation
            and not (shell and shell.frame and shell.frame:IsShown())
            and not UnitExists('target')
            and not UnitExists('focus')
        then
            idleGate.skipped = idleGate.skipped + 1
            return
        end

        idleGate.nextEval = now + interval
    end

    idleGate.dirty = false
    idleGate.rotation = self.currentRotation
    idleGate.evaluated = idleGate.evaluated + 1
    return self:EvaluateNextAction()
end

-- Starts the poll (profile.poll seconds) and the idle gate for the active rotation. Does nothing without a rotation,
-- when already running, or after an advice error.
function addon:EnableRotationTimer()
    if self.adviceErrorReport then return end

    if self.currentRotation and not self.rotationTimer then
        startIdleGate()
        self.rotationTimer = self:ScheduleRepeatingTimer('EvaluateNextActionTimer', self.db.profile.poll)
    end
end

-- Cancels the poll timer and stops the idle gate.
function addon:DisableRotationTimer()
    if self.rotationTimer then
        self:CancelTimer(self.rotationTimer)
        self.rotationTimer = nil
    end

    stopIdleGate()
end

-- Debounced action-bar rescan: re-arms a 0.25 second timer that runs Fetch with announcements silenced for that pass.
function addon:ButtonFetch()
    if self.fetchTimer then
        self:CancelTimer(self.fetchTimer)
    end

    -- The bars changed and the index is older than they are until the rescan
    -- below runs (Fetch clears this): the editor judges nothing meanwhile.
    self.fetchPending = true

    self.fetchTimer = self:ScheduleTimer(function()
        self.skipAnnounce = true
        self:Fetch()
    end, 0.25)
end

-- ============================================================================
-- Per-poll preparation
-- ============================================================================

-- Builds the record kept in self.unitsInRange for `unit`: name, attackable, enemy and, for enemies, threat. Reads go
-- through the per-poll API cache `cache`.
local function CreateUnitInfo(cache, unit)
    local info = {
        unit = unit,
        name = getCached(cache, UnitName, unit),
        attackable = getCached(cache, UnitCanAttack, "player", unit),
        enemy = getCached(cache, UnitIsEnemy, "player", unit),
    }

    if info.enemy then
        info.threat = getCached(cache, UnitThreatSituation, "player", unit)
    end

    return info
end

-- Refreshes a unitsInRange record in place; leaves it untouched when the unit no longer exists.
local function UpdateUnitInfo(cache, record)
    if not getCached(cache, UnitExists, record.unit) then
        return
    end

    record.attackable = getCached(cache, UnitCanAttack, "player", record.unit)
    record.enemy = getCached(cache, UnitIsEnemy, "player", record.unit)

    if record.enemy then
        record.threat = getCached(cache, UnitThreatSituation, "player", record.unit)
    else
        record.threat = nil
    end
end

-- Shared start of every evaluation: profile markers, macro buttons, unit
-- environment and history trimming. Returns the poll time and its API cache.
local environmentHandled, environmentGUID = {}, {}

-- Runs at the start of every poll, standard or lean. It also drops spell, combat and damage history older than the
-- profile's windows. The GUID-keyed unit pass is skipped on restricted clients, where an NPC's GUID is secret.
local function prepareEvaluation(self)
    self.evaluationProfile:start()
    if self.RefreshMacroButtons then self:RefreshMacroButtons() end

    local now = GetTime()
    local cache = {}

    if not self.inCombat then
        self.combatCache = cache
    end

    self.evaluationProfile:child("environment"):start()

    -- The GUID-keyed unit environment never runs on restricted clients: an
    -- NPC's GUID is secret there and cannot be compared or used as a key.
    if self.nameplateUnits == nil then
        -- Reused every poll; only read within this function.
        local unitsHandled, unitsGUID = environmentHandled, environmentGUID

        for k in pairs(unitsHandled) do
            unitsHandled[k] = nil
        end

        for k in pairs(unitsGUID) do
            unitsGUID[k] = nil
        end

        local verbose = (tonumber(self.db.profile.loglevel) or 2) >= 4
        local groupKinds = addon.groupUnitKinds or {}

        for unit, _ in pairs(addon.units) do
            -- Group unit types are resolved from the roster, not unit tokens.
            if not groupKinds[unit] then unitsGUID[unit] = getCached(cache, UnitGUID, unit) end
        end

        for guid, entity in pairs(self.unitsInRange) do
            if isin(addon.units, entity.unit) then
                if unitsGUID[entity.unit] and unitsGUID[entity.unit] == guid then
                    unitsHandled[entity.unit] = true
                else
                    self.unitsInRange[guid] = nil
                end
            end

            if verbose then addon:verbose("Updating Unit " .. guid .. " (" .. entity.name .. ")") end
            UpdateUnitInfo(cache, entity)
        end

        for unit, guid in pairs(unitsGUID) do
            if not unitsHandled[unit] and not self.unitsInRange[guid] and not starts_with(unit, "mouseover") then
                self.unitsInRange[guid] = CreateUnitInfo(cache, unit)
            end
        end
    end

    local threshold_time = now - self.db.profile.spell_history

    while #self.spellHistory ~= 0 do
        if self.spellHistory[#self.spellHistory].time < threshold_time then
            table.remove(self.spellHistory, #self.spellHistory)
        else
            break
        end
    end

    threshold_time = now - self.db.profile.combat_history

    for _, history in pairs(self.combatHistory) do
        while #history ~= 0 do
            if history[#history].time < threshold_time then
                table.remove(history, #history)
            else
                break
            end
        end
    end

    self.evaluationProfile:child("environment"):stop()

    threshold_time = now - self.db.profile.damage_history

    for guid, entry in pairs(self.damageHistory) do
        while #entry.heals ~= 0 do
            if entry.heals[#entry.heals].time < threshold_time then
                table.remove(entry.heals, #entry.heals)
            else
                break
            end
        end

        while #entry.damage ~= 0 do
            if entry.damage[#entry.damage].time < threshold_time then
                table.remove(entry.damage, #entry.damage)
            else
                break
            end
        end

        if #entry.heals == 0 and #entry.damage == 0 then
            self.damageHistory[guid] = nil
        end
    end

    return now, cache
end

-- Called after an error in the poll: records `reportId` in adviceErrorReport (advice stays off while it is set) and
-- retires the rotation, timer, preview, glows, broker text and event signals. Each step runs under Diagnostics, so one
-- failing step cannot stop the rest.
function addon:StopAdviceForError(reportId)
    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return end

    -- BEGIN ANALYTICS ERROR
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self, change) then return end
    end

    -- END ANALYTICS ERROR
    self.adviceErrorReport = reportId
    if not retireActive(self, change) or not activeChangeCurrent(self, change) then return end
    self.currentSpell = nil
    self.avail_announced = {}
    local timer = self.rotationTimer
    self.rotationTimer = nil

    -- Runs one cleanup step under Diagnostics:Call; returns whether the transition is still current afterwards.
    local function cleanup(operation, callback, ...)
        if not activeChangeCurrent(self, change) then return false end
        local diagnostics = self.Diagnostics
        local method = diagnostics.Call
        if not activeChangeCurrent(self, change) then return false end
        method(diagnostics, { module = "recommendations", operation = operation }, callback, ...)
        return activeChangeCurrent(self, change)
    end

    if timer and not cleanup("cancel-timer", self.CancelTimer, self, timer) then return end
    if self.nextWindow and not cleanup("hide-preview", self.nextWindow.Hide, self.nextWindow) then return end
    if not cleanup("clear-glows", self.RemoveAllCurrentGlows, self) then return end
    if not cleanup("destroy-glows", self.DestroyAllGlows, self) then return end

    if not cleanup("broker-disabled", function() activeBroker(self, change, DataBroker, color.RED .. OFF) end) then
        return
    end

    if not cleanup("rotation-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_ROTATION", nil) then return end

    if not cleanup("suggestion-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_SPELL_UPDATE", nil, nil) then
        return
    end

    if WeakAuras and WeakAuras.ScanEvents then
        cleanup("weak-aura-cleared", WeakAuras.ScanEvents, "ROTATIONMASTER_SPELL_UPDATE", nil, nil)
    end
end

-- Diagnostics context for a poll, reused (and updated in place) on every tick.
local evaluationContext = { module = "recommendations", operation = "timer" }

-- ============================================================================
-- Evaluation entry point
-- ============================================================================

-- Runs one poll under the error recorder; the first error stops advice (StopAdviceForError). Skipped after a failed
-- initialization or while an advice error is recorded.
function addon:EvaluateNextAction()
    if self.initializationErrorReport then return end
    if not self.Diagnostics then return self:EvaluateNextActionInternal() end
    if self.adviceErrorReport then return end
    evaluationContext.rotationId = self.currentRotation
    local ok, reportId = self.Diagnostics:Call(evaluationContext, self.EvaluateNextActionInternal, self)
    if not ok then self:StopAdviceForError(reportId) end
end

-- ============================================================================
-- Lean evaluation engine
-- ============================================================================

-- BEGIN LEAN EVALUATION
-- Steady-state polling. The standard path below acquires and proves the
-- active body (ownership, eligibility, scope, conditions) and, when a poll
-- completes, records it here. Later polls reuse that body while nothing it
-- depends on has changed: spec, rotation, profile, preview window, the
-- execution generation (advanced by every rotation, condition, function,
-- itemset and effect writer), the context epoch (events that change
-- eligibility: level, talents, spells, vehicle, control, form, combat...)
-- and a one minute age cap. Nothing is re-proved within a poll. Conditions,
-- readiness, range and cooldowns are still read fresh every poll, and
-- outputs still check the selection is current after each callout.
-- /rm perf engine standard turns this off.
-- Condition-plan compiler and evaluator from Core/conditions.lua, handed over once at load.
local compileConditionPlan, evaluateConditionPlan

if type(addon.ConsumeConditionPlans) == 'function' then
    compileConditionPlan, evaluateConditionPlan = addon:ConsumeConditionPlans()
end

-- Seconds a recorded plan is reused before the standard path must prove the body again.
local LEAN_MAX_AGE = 60
-- Plans built, polls served and why plans were dropped, for runtime reports.
local leanStats = { built = 0, polls = 0, key = 0, generation = 0, context = 0, age = 0 }
addon.leanStats = leanStats
-- Captured at load (Core/action_policy.lua loads first): an overridden
-- NewActionReadiness keeps being used as is.
local ownedActionReadiness = addon.NewActionReadiness
-- Advanced by events that change eligibility; a plan recorded under an older epoch is dropped.
local leanContextEpoch = 0
-- The recorded plan, or nil when none is valid.
local leanPlan
-- Stand-in step recorded when the implicit attack is recommended because no rotation step applied.
local implicitAttack = { id = "RM-IMPLICIT:ATTACK", type = "spell" }
-- Single-entry scratch lists reused for every FindSpell call, and a shared empty list, so a poll does not allocate.
local scratchSpell, scratchItem, noIds = {}, {}, {}

-- Whether the lean engine may run: its plan compiler and generation reader are bound and /rm perf engine has not
-- forced the standard engine.
local function leanEnabled(self)
    return compileConditionPlan and readExecutionGeneration and self.db.global.evaluator ~= 'standard'
end

-- Chooses 'lean' or 'standard' (saved in db.global.evaluator; lean is the default and is stored as nil) and drops the
-- recorded plan. Returns false for any other name.
function addon:SetEvaluationEngine(engine)
    if engine ~= 'lean' and engine ~= 'standard' then return false end
    self.db.global.evaluator = engine ~= 'lean' and engine or nil
    leanPlan = nil
    return true
end

-- The engine in use for /rm perf engine: 'standard', 'lean', or 'lean (building)' while no plan is recorded yet.
function addon:GetEvaluationEngine()
    if not leanEnabled(self) then return 'standard' end
    return leanPlan and 'lean' or 'lean (building)'
end

-- Compiles a step list into entries holding prepared condition plans, recursing into Branch arms. `ordinals` maps a
-- rotation step to its position among rotation steps, which reports and the implicit-attack ordinal use.
local function compileSteps(list, ordinals)
    local compiled = {}

    for index, step in ipairs(list) do
        local entry = { step = step, ordinal = ordinals[step] }

        if step.type == "branch" then
            entry.mode = step.mode or "evaluate"
            if entry.mode == "evaluate" then entry.conditions = compileConditionPlan(step.conditions) end
            entry.onTrue = compileSteps(step.onTrue, ordinals)
            entry.onFalse = compileSteps(step.onFalse, ordinals)
        else
            entry.conditions = compileConditionPlan(step.conditions)
        end

        compiled[index] = entry
    end

    return compiled
end

-- Records the plan after a poll completed on the standard path: the compiled rotation steps and cooldowns plus the
-- proofs (rotation key, spec, profile, preview window, execution generation, context epoch, age) that decide reuse.
-- Replaces any earlier plan; records nothing when the rotation cannot be indexed.
local function recordLeanPlan(self, rot, views, spec, key, profile, window, generation, epoch)
    local index = self.RotationData.IndexRotationSteps(rot, { allowMissingIds = true })
    if not index then return end
    local ordinals, count = {}, 0

    for _, row in ipairs(index.rows) do
        if row.section == "rotation" then
            ordinals[row.step] = row.ordinal
            count = count + 1
        end
    end

    local plan = {
        rot = rot,
        views = views,
        spec = spec,
        key = key,
        profile = profile,
        window = window,
        generation = generation,
        epoch = epoch,
        expires = GetTime() + LEAN_MAX_AGE,
        steps = compileSteps(rot.rotation or {}, ordinals),
        fallbackOrdinal = count + 1,
        cooldowns = {},
        recSpell = {},
        recCond = {},
        recIndex = {},
        recItem = {},
        obsSpell = {},
        obsEnabled = {},
        obsItem = {},
        enabledCooldowns = {},
        enabledItems = {},
        disabledCooldowns = {},
    }

    if rot.cooldowns ~= nil then
        for id, cond in pairs(rot.cooldowns) do
            plan.cooldowns[#plan.cooldowns + 1] = {
                id = id,
                step = cond,
                conditions = compileConditionPlan(cond.conditions),
            }
        end
    end

    -- True while the selection, profile, preview window and execution generation the plan was built under are
    -- unchanged.
    plan.current = function()
        return self.currentRotation == key
            and self.currentSpec == spec
            and self.db.profile == profile
            and self.nextWindow == window
            and readExecutionGeneration() == generation
    end

    leanPlan = plan
    leanStats.built = leanStats.built + 1
end

-- One action step: conditions, then the first mapped and ready spell.
-- Returns the mapped spell, whether it is ready (and so may be recommended) and the item id; nil and false when the
-- step has no usable action or its conditions do not match. `decisionRow` names the bucket for runtime counters.
local function leanAction(plan, entry, decisionRow)
    local decisionSink = plan.decisionSink
    local cond = entry.step
    if decisionSink then decisionSink(decisionRow, 'attempt') end
    local action = cond.action

    if action == nil or cond.disabled then
        -- Assisted steps carry no action: the spell is Blizzard's suggestion,
        -- read below each poll. An enabled step with an action never gets here.
        if action ~= nil or cond.disabled or cond.type ~= "assisted" then
            if decisionSink then decisionSink(decisionRow, action == nil and 'noaction' or 'disabled') end
            return nil, false
        end
    end

    local matches = evaluateConditionPlan(entry.conditions, plan.cache, plan.now, cond.id) == "match"
    if decisionSink then decisionSink(decisionRow, matches and 'matched' or 'notmatched') end
    if not matches then return nil, false end
    local firstMapped, firstItem
    -- Spell rank lists change with SPELLS_CHANGED (a context event) or spell
    -- data loads (the plan's age cap); items follow bags, so stay fresh.
    local spellids, itemids = entry.spellids, nil

    if not spellids then
        spellids, itemids = addon:GetSpellIds(cond)
        if cond.type ~= "item" and action ~= nil then entry.spellids = spellids end
    end

    for index, id in ipairs(spellids or noIds) do
        local itemId = itemids and itemids[index]
        scratchSpell[1] = id
        local mapped

        if cond.type == "item" then
            scratchItem[1] = itemId
            mapped = addon:FindSpell(scratchSpell, scratchItem)
            scratchItem[1] = nil
        else
            mapped = addon:FindSpell(scratchSpell)
        end

        if decisionSink then decisionSink(decisionRow, mapped and 'mapped' or 'unmapped') end

        if mapped then
            if not firstMapped then firstMapped, firstItem = mapped, itemId end
            local ready = plan.actionReady(cond.type, id, itemId)
            if decisionSink then decisionSink(decisionRow, ready and 'ready' or 'notready') end
            if ready then return mapped, true, itemId end
        end
    end

    return firstMapped, false, firstItem
end

-- Appends one recommendation (spell, step, ordinal, item) to the plan's parallel arrays, which are reused each poll.
local function leanRecommend(plan, spellid, cond, index, itemId)
    local n = plan.recommended + 1
    plan.recommended = n
    plan.recSpell[n], plan.recCond[n], plan.recIndex[n], plan.recItem[n] = spellid, cond, index, itemId
end

-- Same control flow as Core/rotation_sequence.lua execute(). Returns nil to
-- continue, or how the walk ended: "selected", "stopped" or "unavailable".
local function leanWalk(plan, list)
    for i = 1, #list do
        local entry = list[i]
        local step = entry.step

        if step.type == "branch" then
            local mode = entry.mode

            local status = mode == "true" and "match" or mode == "false" and "no-match" or evaluateConditionPlan(
                entry.conditions,
                plan.cache,
                plan.now,
                step.id
            )

            if status == "unavailable" then return "unavailable" end
            local ended = leanWalk(plan, status == "match" and entry.onTrue or entry.onFalse)
            if ended then return ended end
        elseif not step.disabled then
            if step.type == "stop" then
                local status = evaluateConditionPlan(entry.conditions, plan.cache, plan.now, step.id)

                if status ~= "no-match" then
                    plan.suppressAttack = status == "unavailable" or step.suppress_attack == true
                    return status == "unavailable" and "unavailable" or "stopped"
                end
            else
                local spellid, enabled, itemId = leanAction(plan, entry, 'rotation')

                if enabled then
                    leanRecommend(plan, spellid, step, entry.ordinal, itemId)

                    if not plan.nativePreview or plan.recommended >= plan.profile.preview_spells then
                        return "selected"
                    end
                end
            end
        end
    end
end

-- Publication order and checks match the standard path's staged publishers.
-- Publishes the plan's recommendations: the preview window, the primary glow and the WeakAuras signal. `plan.current()`
-- is re-proved after each callout and the function returns as soon as it fails.
local function leanPublish(self, plan)
    local current, profile, previewWindow = plan.current, plan.profile, plan.window
    local nativePreview = plan.nativePreview
    local weakAuras = _G.WeakAuras

    if nativePreview then
        previewWindow:ReleaseChildren()
        if current() then previewWindow:PauseLayout() end
        if not current() then return end
    end

    for n = 1, plan.recommended do
        local spellid, cond, index, itemId = plan.recSpell[n], plan.recCond[n], plan.recIndex[n], plan.recItem[n]

        if n == 1 then
            -- BEGIN ANALYTICS PRIMARY ADVICE
            if adviceCapture then
                adviceCapture("advice", previewWindow, current, cond.type, spellid)
                if not current() then return end
            end

            -- END ANALYTICS PRIMARY ADVICE
            self.currentSpell = spellid
            -- Blizzard's own highlight can own a "Blizzard's suggestion" step
            -- (Core/assisted_highlight.lua); RM then records the spell unglowed.
            local hidden = cond.type == "assisted" and addon.assistedGlowHidden == true

            if not addon:IsGlowing(spellid, itemId, hidden) then
                if not current() then return end
                if not profile.disable_buttons then addon:GlowNextSpell(spellid, itemId, hidden) end
                if not current() then return end

                if weakAuras and type(weakAuras.ScanEvents) == "function" then
                    weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", cond.type, spellid)
                end

                if not current() then return end

                AceEvent:SendMessage(
                    "ROTATIONMASTER_SPELL_UPDATE",
                    self.currentRotation,
                    index,
                    cond.id,
                    cond.type,
                    spellid
                )
            end
        end

        if not current() then return end
        if nativePreview then previewWindow:AddRecommendation(spellid, itemId) end
        if not current() then return end
    end

    if plan.recommended == 0 then
        -- BEGIN ANALYTICS EMPTY ADVICE
        if adviceCapture then
            adviceCapture("retire")
            if not current() then return end
        end

        -- END ANALYTICS EMPTY ADVICE
        self.currentSpell = nil
        if not profile.disable_buttons then addon:GlowClear() end
        if not current() then return end

        if weakAuras and type(weakAuras.ScanEvents) == "function" then
            weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
        end

        if not current() then return end
        AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE", self.currentRotation, nil)
        if not current() then return end
    end

    if nativePreview then
        previewWindow:ResumeLayout()
        if current() then previewWindow:DoLayout() end
        if not current() then return end
    end

    if plan.rot.cooldowns ~= nil then
        local views = plan.views

        local enabledCooldowns, enabledItems, disabledCooldowns =
            plan.enabledCooldowns, plan.enabledItems, plan.disabledCooldowns

        for k in pairs(enabledCooldowns) do
            enabledCooldowns[k] = nil
        end

        for k in pairs(enabledItems) do
            enabledItems[k] = nil
        end

        for k in pairs(disabledCooldowns) do
            disabledCooldowns[k] = nil
        end

        local cooldowns = plan.cooldowns

        for i = 1, #cooldowns do
            local id, cond = cooldowns[i].id, cooldowns[i].step
            local spellid, enabled, itemId = plan.obsSpell[i], plan.obsEnabled[i], plan.obsItem[i]
            local announced = addon.avail_announced

            -- A missing observation with no prior announcement has no output.
            if spellid ~= nil or type(announced) ~= 'table' or announced[cond.id] ~= nil then
                if not current() then return end
                local previous = addon.avail_announced[cond.id]

                if previous and (previous ~= spellid or not enabled) and not enabledCooldowns[previous] then
                    disabledCooldowns[previous] = cond
                end

                if spellid then
                    if enabled then
                        addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)

                        if addon.avail_announced[cond.id] ~= spellid then
                            if not addon.skipAnnounce then
                                addon:DispatchAnnouncement(cond, string.format(L["%s is now available!"], spellLink(
                                    spellid
                                )))
                            end

                            if not current() then return end
                            addon.avail_announced[cond.id] = spellid

                            AceEvent:SendMessage(
                                "ROTATIONMASTER_COOLDOWN_UPDATE",
                                self.currentRotation,
                                id,
                                cond.id,
                                cond.type,
                                spellid
                            )

                            if not current() then return end
                        end

                        if not enabledCooldowns[spellid] then
                            enabledCooldowns[spellid] = cond
                            enabledItems[spellid] = itemId
                            disabledCooldowns[spellid] = nil
                        end
                    else
                        if addon.avail_announced[cond.id] then
                            addon.avail_announced[cond.id] = nil

                            AceEvent:SendMessage(
                                "ROTATIONMASTER_COOLDOWN_UPDATE",
                                self.currentRotation,
                                id,
                                cond.id,
                                nil
                            )
                        end

                        addon:verbose("Cooldown %d [%s] is disabled", id, cond.id)

                        if not enabledCooldowns[spellid] then
                            disabledCooldowns[spellid] = cond
                        end
                    end
                elseif addon.avail_announced[cond.id] then
                    addon.avail_announced[cond.id] = nil
                    AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                end
            end
        end

        for spellid, cond in pairs(disabledCooldowns) do
            if not current() then return end
            local style = cond

            if views then
                style = views[cond]
                if not style then return end
            end

            addon:GlowCooldown(spellid, false, style)
        end

        for spellid, cond in pairs(enabledCooldowns) do
            if not current() then return end
            local style = cond

            if views then
                style = views[cond]
                if not style then return end
            end

            addon:GlowCooldown(spellid, true, style, enabledItems[spellid])
        end
    end

    if not current() then return end
    addon.skipAnnounce = false
    if type(addon.announced) ~= 'table' or next(addon.announced) ~= nil then addon.announced = {} end
end

-- Closes every poll, whichever engine ran it. At most every 15 seconds it writes the cache statistics and the
-- evaluation profiler report to the debug log and resets the profiler; otherwise it costs one GetTime() comparison.
local function reportEvaluation(self)
    if GetTime() - self.lastCacheReport > 15 then
        addon.Functions.cache.ReportCacheStats(addon)
        if self.RefreshEvaluationProfilerPolicy then self:RefreshEvaluationProfilerPolicy() end

        if not reportEvaluationProfiler or reportEvaluationProfiler(self) then
            addon:debug("%s", self.evaluationProfile:report(self.db.profile.detailed_profiling))
            self.evaluationProfile:reset()
        end

        self.lastCacheReport = GetTime()
    end
end

-- Runs one poll from the recorded plan. Returns true when the lean path handled the poll. Returns false when there is
-- no plan or it is stale (rotation, spec, profile or preview window moved, a writer advanced the execution generation,
-- a context event fired, or the age cap passed): the plan is dropped, the reason is counted in leanStats and the
-- caller runs the standard path, which records a new plan. Conditions, readiness and cooldowns are read fresh here.
local function evaluateLean(self)
    local plan = leanPlan
    if not plan then return false end
    local stale

    if
        plan.key ~= self.currentRotation
        or plan.spec ~= self.currentSpec
        or plan.profile ~= self.db.profile
        or plan.window ~= self.nextWindow
    then
        stale = 'key'
    elseif plan.generation ~= readExecutionGeneration() then
        stale = 'generation'
    elseif plan.epoch ~= leanContextEpoch then
        stale = 'context'
    elseif GetTime() >= plan.expires then
        stale = 'age'
    end

    if stale then
        leanStats[stale] = leanStats[stale] + 1
        leanPlan = nil
        return false
    end

    leanStats.polls = leanStats.polls + 1
    local now, cache = prepareEvaluation(self)
    plan.now, plan.cache = now, cache

    if self.NewActionReadiness == ownedActionReadiness and self.ResetActionReadiness then
        plan.actionReady = self:ResetActionReadiness(now)
    else
        plan.actionReady = self:NewActionReadiness(now)
    end

    plan.decisionSink = runtimeDecisionSink
    local previewWindow = plan.window
    plan.nativePreview = previewWindow and type(previewWindow.AddRecommendation) == "function"
    plan.recommended, plan.suppressAttack = 0, false

    self.evaluationProfile:child("rotation"):start()
    local ended = leanWalk(plan, plan.steps)

    if ended == "unavailable" then
        plan.suppressAttack = true
    elseif ended ~= "stopped" then
        plan.suppressAttack = false
    end

    if plan.recommended == 0 and not plan.suppressAttack then
        local attack = self:ResolveImplicitAttack(plan.actionReady)
        if attack then leanRecommend(plan, attack, implicitAttack, plan.fallbackOrdinal) end
    end

    self.evaluationProfile:child("rotation"):stop()

    self.evaluationProfile:child("cooldowns"):start()
    local cooldowns = plan.cooldowns

    for i = 1, #cooldowns do
        plan.obsSpell[i], plan.obsEnabled[i], plan.obsItem[i] = leanAction(plan, cooldowns[i], 'cooldowns')
    end

    self.evaluationProfile:child("cooldowns"):stop()

    leanPublish(self, plan)
    plan.cache = nil
    self.evaluationProfile:stop()
    reportEvaluation(self)
    return true
end

-- END LEAN EVALUATION

-- ============================================================================
-- Standard evaluation and spell resolution
-- ============================================================================

-- One poll of the standard engine. Tries the lean plan first; only when evaluateLean declines does the full path run:
-- resolve the active rotation body (prepared runtime plan, scoped pass or raw runtime rotation), evaluate the rotation
-- and cooldown steps through the sequence executor, stage every output (glows, messages, announcements) and publish
-- them in order, rechecking after each callout that the selection is still current. A completed poll whose inputs did
-- not move records a lean plan. Called every poll tick through addon:EvaluateNextAction, which adds the error boundary.
function addon:EvaluateNextActionInternal()
    local useLean = leanEnabled(self)
    if useLean and evaluateLean(self) then return end
    local leanGeneration, leanEpoch = useLean and readExecutionGeneration(), leanContextEpoch
    local decisionSink = runtimeDecisionSink
    local selectedRotation, selectedSpec, selectedProfile = self.currentRotation, self.currentSpec, self.db.profile
    local runtimePass, rot, publicationGuard, planToken, conditionSession, handled, presentationViews, conditionLease, notifiedLease, deliveryLease, dispatchLease
    local executionFailed = false

    -- Asks the dispatch lease, when the managed runtime issued one, whether the poll may continue at a named checkpoint
    -- ('resume', 'step', 'iterator'). The first refusal latches executionFailed, so every later check fails as well.
    local function dispatchCurrent(kind)
        if executionFailed then return false end
        if not dispatchLease then return true end
        if dispatchLease(kind) then return true end
        executionFailed = true
        return false
    end

    if preparedRuntimeEnabled and selectedRotation ~= nil and acquireActiveRuntimePlan and prepareConditionRuntime then
        rot, publicationGuard, planToken, handled, presentationViews, conditionLease, notifiedLease, deliveryLease, dispatchLease = acquireActiveRuntimePlan(
            self,
            selectedSpec,
            selectedRotation
        )

        if
            self.currentRotation ~= selectedRotation
            or self.currentSpec ~= selectedSpec
            or self.db.profile ~= selectedProfile
        then
            return
        end

        if handled then
            if not publicationGuard then return end

            if dispatchLease then
                if not dispatchCurrent('resume') then return end
            elseif not publicationGuard() then
                return
            end

            if rot then
                conditionSession = prepareConditionRuntime(
                    self,
                    rot,
                    planToken,
                    notifiedLease or conditionLease or publicationGuard,
                    publicationGuard,
                    dispatchLease and dispatchCurrent
                )

                if executionFailed then return end

                -- Owned preparation certifies its producers and invocation.
                -- Rejected preparation can return before that boundary, so
                -- the ordinary fallback still needs the full source fence.
                if conditionSession and notifiedLease then
                    if not notifiedLease() then return end
                elseif not publicationGuard() then
                    return
                end

                lastConditionSession = conditionSession

                -- Custom or unsupported trees retain the existing execution
                -- input and callback route; private plan data never escapes.
                if not conditionSession then
                    runtimePass, rot, publicationGuard, planToken, handled, presentationViews, conditionLease, notifiedLease, deliveryLease, dispatchLease =
                        nil, nil, nil, nil, false, nil, nil, nil, nil, nil
                end
            end
        end
    end

    if selectedRotation ~= nil and not handled then
        if retireConditionRuntime then
            local previous = lastConditionSession
            if not retireConditionRuntime(self, previous or false) then return end
            if lastConditionSession == previous then lastConditionSession = nil end

            if
                self.currentRotation ~= selectedRotation
                or self.currentSpec ~= selectedSpec
                or self.db.profile ~= selectedProfile
            then
                return
            end
        end

        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            if acquireEvaluationPass then
                local reason
                runtimePass, reason, publicationGuard = acquireEvaluationPass(self, selectedSpec)
            else
                runtimePass = self:AcquireRotationRuntimePass(selectedSpec)
            end

            if runtimePass then rot = runtimePass:Get(selectedRotation) end
            -- Acquiring a pass starts a new observation, which advances the
            -- generation itself; any later advance is a real writer.
            if useLean then leanGeneration = readExecutionGeneration() end
        else
            rot = self:GetRuntimeRotation(selectedSpec, selectedRotation)
        end
    end

    if self.currentRotation == nil then
        addon:DisableRotationTimer()
        return
    elseif not rot then
        self.manualRotation = false
        self:DisableRotation()
        return
    else
        local now, cache = prepareEvaluation(self)

        local actionReady = self:NewActionReadiness(now)

        -- Preparation can call public providers. Check the compiled graph's
        -- source authority once here, before any cached condition is reused.
        if conditionSession and not conditionSession:AfterOpaque() then
            self.evaluationProfile:stop()
            return
        end

        -- Evaluates one action step fresh: its conditions, then the first of its spell ids that maps to a button and is
        -- ready. Returns spellid, ready, itemId. If nothing is ready it still returns the first mapped spell with ready
        -- false, so a disabled cooldown can clear its glow. decisionRow ('rotation' or 'cooldowns') is the row reported
        -- to the runtime decision sink.
        local function eval(cond, decisionRow)
            if decisionSink then decisionSink(decisionRow, 'attempt') end
            local firstMapped, firstItem
            local matches
            local action = cond.action

            if (action ~= nil or cond.type == "assisted") and not cond.disabled then
                if conditionSession then
                    matches = conditionSession:EvaluateBool(cond.conditions, { stepId = cond.id })
                else
                    matches = addon:evaluateCondition(cond.conditions, { stepId = cond.id })
                end

                if decisionSink then decisionSink(decisionRow, matches and 'matched' or 'notmatched') end
            elseif decisionSink then
                decisionSink(decisionRow, action == nil and 'noaction' or 'disabled')
            end

            if matches then
                if not dispatchCurrent('step') then return nil, false end
                local spellids, itemids = addon:GetSpellIds(cond)

                for index, id in ipairs(spellids or {}) do
                    local itemId = itemids and itemids[index]
                    local mapped = addon:FindSpell({ id }, cond.type == "item" and { itemId } or nil)
                    if decisionSink then decisionSink(decisionRow, mapped and 'mapped' or 'unmapped') end

                    if mapped then
                        if not firstMapped then firstMapped, firstItem = mapped, itemId end
                        local ready = actionReady(cond.type, id, itemId)
                        if decisionSink then decisionSink(decisionRow, ready and 'ready' or 'notready') end
                        if ready then return mapped, true, itemId end
                    end
                end
            end

            return firstMapped, false, firstItem
        end

        self.evaluationProfile:child("rotation"):start()
        local preview, suppressAttack = 0, false
        local weakAuras = _G.WeakAuras
        ---@type RMRecommendationPreview
        local previewWindow = self.nextWindow
        local nativePreview = previewWindow and type(previewWindow.AddRecommendation) == "function"
        local staged = {}
        local delivering, deliveryFailed = false, false

        -- True while this poll may still publish: the selection, spec, profile and preview window are the ones the poll
        -- started with, no checkpoint has failed and the runtime pass or publication guard still holds. Staged outputs
        -- call it again after every callout that can reenter (glow, message and announcement handlers).
        local function current()
            if deliveryFailed or executionFailed then return false end

            if
                self.currentRotation ~= selectedRotation
                or self.currentSpec ~= selectedSpec
                or self.db.profile ~= selectedProfile
                or self.nextWindow ~= previewWindow
            then
                return false
            end

            if delivering and deliveryLease then return deliveryLease() end
            if conditionSession and dispatchLease then return dispatchCurrent('resume') end
            if publicationGuard then return publicationGuard() end
            if not runtimePass then return true end
            return runtimePass:IsCurrent()
        end

        -- Queues an output. Nothing becomes visible until every condition and readiness callback has finished.
        local function stage(callback)
            staged[#staged + 1] = callback
        end

        if nativePreview then
            stage(function()
                previewWindow:ReleaseChildren()
                if current() then previewWindow:PauseLayout() end
            end)
        end

        -- Counts one recommendation against the preview limit and stages its outputs. The first one becomes the current
        -- spell (glow, WeakAuras and ROTATIONMASTER_SPELL_UPDATE); every one goes to the preview window, if any.
        local function recommend(spellid, cond, index, itemId)
            preview = preview + 1
            local ordinal = preview

            stage(function()
                if ordinal == 1 then
                    -- BEGIN ANALYTICS PRIMARY ADVICE
                    if adviceCapture then
                        adviceCapture("advice", previewWindow, current, cond.type, spellid)
                        if not current() then return end
                    end

                    -- END ANALYTICS PRIMARY ADVICE
                    self.currentSpell = spellid
                    local hidden = cond.type == "assisted" and addon.assistedGlowHidden == true

                    if not addon:IsGlowing(spellid, itemId, hidden) then
                        if not current() then return end
                        if not self.db.profile.disable_buttons then addon:GlowNextSpell(spellid, itemId, hidden) end
                        if not current() then return end

                        if weakAuras and type(weakAuras.ScanEvents) == "function" then
                            weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", cond.type, spellid)
                        end

                        if not current() then return end

                        AceEvent:SendMessage(
                            "ROTATIONMASTER_SPELL_UPDATE",
                            self.currentRotation,
                            index,
                            cond.id,
                            cond.type,
                            spellid
                        )
                    end
                end

                if not current() then return end
                if nativePreview then previewWindow:AddRecommendation(spellid, itemId) end
            end)
        end

        local sequence = evaluateSequence(
            self,
            rot,
            function(condition, context)
                if conditionSession then return conditionSession:EvaluateResult(condition, context) end
                return addon:evaluateConditionResult(condition, context)
            end,
            function(cond, index)
                local spellid, enabled, itemId = eval(cond, 'rotation')
                if not dispatchCurrent('resume') then return false end

                if enabled then
                    recommend(spellid, cond, index, itemId)
                    if not nativePreview or preview >= self.db.profile.preview_spells then return false end
                end

                return true
            end,
            conditionSession and dispatchLease and dispatchCurrent or nil
        )

        if executionFailed then
            self.evaluationProfile:stop()
            return
        end

        suppressAttack = sequence.suppressAttack

        if preview == 0 and not suppressAttack then
            local attack = self:ResolveImplicitAttack(actionReady)

            if attack then
                recommend(
                    attack,
                    { id = "RM-IMPLICIT:ATTACK", type = "spell" },
                    sequence.fallbackOrdinal or #(rot.rotation or {}) + 1
                )
            end
        end

        if preview == 0 then
            stage(function()
                -- BEGIN ANALYTICS EMPTY ADVICE
                if adviceCapture then
                    adviceCapture("retire")
                    if not current() then return end
                end

                -- END ANALYTICS EMPTY ADVICE
                self.currentSpell = nil
                if not self.db.profile.disable_buttons then addon:GlowClear() end
                if not current() then return end

                if weakAuras and type(weakAuras.ScanEvents) == "function" then
                    weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
                end

                if not current() then return end
                AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE", self.currentRotation, nil)
            end)
        end

        if nativePreview then
            stage(function()
                previewWindow:ResumeLayout()
                if current() then previewWindow:DoLayout() end
            end)
        end

        self.evaluationProfile:child("rotation"):stop()
        self.evaluationProfile:child("cooldowns"):start()

        if rot.cooldowns ~= nil then
            local observations = {}

            if not dispatchCurrent('iterator') then
                self.evaluationProfile:stop()
                return
            end

            for id, cond in pairs(rot.cooldowns) do
                local spellid, enabled, itemId = eval(cond, 'cooldowns')

                if not dispatchCurrent('resume') then
                    self.evaluationProfile:stop()
                    return
                end

                observations[#observations + 1] = {
                    id = id,
                    condition = cond,
                    spellid = spellid,
                    enabled = enabled,
                    itemId = itemId,
                }
            end

            stage(function()
                local enabled_cooldowns = {}
                local enabled_items = {}
                local disabled_cooldowns = {}

                for _, observation in ipairs(observations) do
                    -- A missing observation with no prior announcement has no
                    -- publication side effect. Decide at delivery, after the
                    -- earlier publishers, and retain ordinary accessor dispatch.
                    local announced = publicationRawget(addon, 'avail_announced')

                    local inactive = conditionSession
                        and observation.spellid == nil
                        and publicationType(announced) == 'table'
                        and publicationMetatable(announced) == nil
                        and publicationRawget(announced, observation.condition.id) == nil

                    if not inactive then
                        if not current() then return end
                        local id, cond = observation.id, observation.condition
                        local spellid, enabled, itemId = observation.spellid, observation.enabled, observation.itemId
                        local previous = addon.avail_announced[cond.id]

                        if previous and (previous ~= spellid or not enabled) and not enabled_cooldowns[previous] then
                            disabled_cooldowns[previous] = cond
                        end

                        if spellid then
                            if enabled then
                                addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)

                                if addon.avail_announced[cond.id] ~= spellid then
                                    if not addon.skipAnnounce then
                                        local link = spellLink(spellid)

                                        if delivering then
                                            local message = string.format(L["%s is now available!"], link)

                                            -- This rare receiver still gets a private node.
                                            -- Link/format/log callbacks precede its full fence.
                                            if publicationGuard and not publicationGuard() then
                                                deliveryFailed = true
                                                return
                                            end

                                            addon:DispatchAnnouncement(cond, message)
                                        else
                                            addon:DispatchAnnouncement(cond, string.format(
                                                L["%s is now available!"],
                                                link
                                            ))
                                        end
                                    end

                                    if not current() then return end
                                    addon.avail_announced[cond.id] = spellid

                                    AceEvent:SendMessage(
                                        "ROTATIONMASTER_COOLDOWN_UPDATE",
                                        self.currentRotation,
                                        id,
                                        cond.id,
                                        cond.type,
                                        spellid
                                    )

                                    if not current() then return end
                                end

                                if not enabled_cooldowns[spellid] then
                                    enabled_cooldowns[spellid] = cond
                                    enabled_items[spellid] = itemId
                                    disabled_cooldowns[spellid] = nil
                                end
                            else
                                if addon.avail_announced[cond.id] then
                                    addon.avail_announced[cond.id] = nil

                                    AceEvent:SendMessage(
                                        "ROTATIONMASTER_COOLDOWN_UPDATE",
                                        self.currentRotation,
                                        id,
                                        cond.id,
                                        nil
                                    )
                                end

                                addon:verbose("Cooldown %d [%s] is disabled", id, cond.id)

                                if not enabled_cooldowns[spellid] then
                                    disabled_cooldowns[spellid] = cond
                                end
                            end
                        else
                            if addon.avail_announced[cond.id] then
                                addon.avail_announced[cond.id] = nil

                                AceEvent:SendMessage(
                                    "ROTATIONMASTER_COOLDOWN_UPDATE",
                                    self.currentRotation,
                                    id,
                                    cond.id,
                                    nil
                                )
                            end
                        end
                    end
                end

                for spellid, cond in pairs(disabled_cooldowns) do
                    if not current() then return end
                    local style = cond

                    if conditionSession then
                        style = presentationViews and presentationViews[cond]
                        if not style then return end
                    end

                    addon:GlowCooldown(spellid, false, style)
                end

                for spellid, cond in pairs(enabled_cooldowns) do
                    if not current() then return end
                    local style = cond

                    if conditionSession then
                        style = presentationViews and presentationViews[cond]
                        if not style then return end
                    end

                    addon:GlowCooldown(spellid, true, style, enabled_items[spellid])
                end
            end)
        end

        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        stage(function()
            addon.skipAnnounce = false
            addon.announced = {}
        end)

        -- Every condition and readiness callback finishes before advice becomes
        -- externally visible. Recheck between publishers too: another addon's
        -- message/glow callback may retire this profile or selected record.
        -- One final execution-source proof before any staged output. Only the
        -- managed graph's scalar/detached deliveries may then use freshness.
        if conditionSession and deliveryLease then
            if not current() or not publicationGuard or not publicationGuard() or not current() then
                self.evaluationProfile:stop()
                return
            end

            delivering = true
        end

        for _, publish in ipairs(staged) do
            if not current() then break end
            publish()
        end

        local completed = current()

        self.evaluationProfile:stop()

        -- A completed poll whose inputs did not move hands its body to the
        -- lean path; a poll that saw a change builds again next time. Only the
        -- managed and scoped routes have writers that advance the generation;
        -- the unscoped route reads raw profile tables and stays standard.
        if
            useLean
            and completed
            and (conditionSession or runtimePass)
            and readExecutionGeneration() == leanGeneration
            and leanContextEpoch == leanEpoch
        then
            recordLeanPlan(
                self,
                rot,
                conditionSession and presentationViews or nil,
                selectedSpec,
                selectedRotation,
                selectedProfile,
                previewWindow,
                leanGeneration,
                leanEpoch
            )
        end
    end

    reportEvaluation(self)
end

-- Calls the configuration window's live condition-status callback (self.currentConditionEval) when one is set; a no-op
-- otherwise.
function addon:UpdateCurrentCondition()
    -- Update the live config config .. just to be nice :)
    if self.currentConditionEval ~= nil then
        self.currentConditionEval()
        addon:debug(L["Notified configuration to update it's status."])
    end
end

-- Returns the spell ids a rotation or cooldown step can fire and, for item steps, a parallel list of item ids. Spell,
-- pet and "any" steps return the action alone on Retail and on ranked steps, otherwise every known rank from the spell
-- catalog. Item steps expand an item set (or a literal item list) to each item's use-spell; an item whose use-spell or
-- id is not loaded yet is left out and retried on the next poll. "assisted" steps return Blizzard's suggestion and its
-- override ids, read fresh on every call. Anything else returns an empty list.
function addon:GetSpellIds(rot)
    if rot.action then
        if rot.type == (BOOKTYPE_SPELL or "spell") or rot.type == (BOOKTYPE_PET or "pet") or rot.type == "any" then
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if rot.ranked then
                    return { rot.action }
                else
                    return self.SpellCatalog:GetAllSpellIds(rot.action) or { rot.action }
                end
            else
                return { rot.action }
            end
        elseif rot.type == "item" then
            local spellids, itemids = {}, {}
            local items = rot.action

            if type(items) == "string" then
                local itemset = self.db.profile.itemsets[items] or self.db.global.itemsets[items]
                items = type(itemset) == "table" and itemset.items or nil
            end

            if type(items) == "table" then
                for _, item in ipairs(items) do
                    local use = self.Platform:GetItemUseSpell(item)
                    local itemid = use and self.Platform:GetItemID(item)

                    -- A spell without its item identity cannot be checked for
                    -- ownership/cooldown. Retry unavailable metadata next poll.
                    if use and itemid then
                        spellids[#spellids + 1] = use.spellID
                        itemids[#itemids + 1] = itemid
                    end
                end
            end

            return spellids, itemids
        end
    elseif rot.type == "assisted" then
        -- Blizzard's Assisted Combat suggestion, resolved fresh on every call:
        -- the suggestion, then its base and override spell IDs, so whichever
        -- one sits on a button maps (Platform/assisted_combat.lua).
        local platform = self.Platform
        local suggestion = platform.GetAssistedSuggestion and platform:GetAssistedSuggestion()
        if suggestion then return platform:GetAssistedSpellCandidates(suggestion) end
    end

    return {}
end

-- Registers the spell-id lookup, the sequence executor and this file's environment with the active runtime plan
-- (Core/active_runtime_plan.lua), which uses them to prove the plan still runs the code it was built for.
if registerActiveRuntimeConsumers then
    registerActiveRuntimeConsumers(addon, addon.GetSpellIds, ownedSequence, mainEnvironment)
end

-- ============================================================================
-- Glow cleanup, spec updates and talent names
-- ============================================================================

-- Turns off the glow of every spell a cooldown step names, but only while spec and rotation are still the active
-- selection.
function addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot)
    if spec == self.currentSpec and rotation == self.currentRotation then
        for _, spellid in pairs(addon:GetSpellIds(rot)) do
            addon:GlowCooldown(spellid, false)
        end
    end
end

-- Clears the primary-suggestion glow and every cooldown glow of the rotation being torn down. That rotation comes from
-- the cleanup selection of the transition in progress and falls back to the current one. Each external call is
-- bracketed by current() because a glow or lookup callback can reenter and change the active transition.
function addon:RemoveAllCurrentGlows()
    local spec, id, change = cleanupActive(self)
    if not id then spec, id = self.currentSpec, self.currentRotation end

    -- True while the transition this cleanup belongs to is still the active one (always true when there is none).
    local function current()
        return not change or activeChangeCurrent(self, change)
    end

    addon:debug(L["Removing all glows."])
    if not current() then return end
    local rotation

    if id then
        local get = self.GetRotationForCleanup
        if not current() then return end

        if getMainCleanupBody then
            rotation = getMainCleanupBody(self, spec, id, get)
        else
            rotation = get(self, spec, id)
        end
    end

    if not current() then return end

    if rotation and rotation.cooldowns then
        for _, rot in pairs(rotation.cooldowns) do
            if not current() then return end
            local getIDs = addon.GetSpellIds
            if not current() then return end
            local ids = getIDs(addon, rot)
            if not current() then return end

            for _, spellid in pairs(ids) do
                if not current() then return end
                local glow = addon.GlowCooldown
                if not current() then return end
                glow(addon, spellid, false)
                if not current() then return end
            end
        end
    end

    if current() then
        local clear = addon.GlowClear
        if current() then clear(addon) end
    end
end

-- Rebuilds the spell catalog for the current specialization; the name the spec-change paths call.
function addon:UpdateSpecSpells()
    return self:RefreshSpellCatalog()
end

-- Re-reads the player's rotation specialization and brings everything that depends on it into line. When the spec
-- changed it stops the current rotation first, then clears the long-term cache, selects the spec tab, refreshes the
-- spell catalog and the auto-switch conditions, runs SwitchRotation and refetches the buttons. Every step is guarded by
-- the active-transition token, so a reentrant change abandons the rest. Returns nil and the token when it completed.
function addon:UpdateSkill()
    local change = beginActive(self)
    if not activeChangeCurrent(self, change) then return end
    if not activeCall(self, change, 'verbose', "Skill update triggered") then return end
    if not activeChangeCurrent(self, change) then return end
    local selection = self.Platform:GetRotationSpecialization()
    local spec = selection and selection.key
    if not activeChangeCurrent(self, change) then return end

    if spec ~= self.currentSpec then
        local disable = self.DisableRotation
        if not activeChangeCurrent(self, change) then return end
        local _, nextChange, stopped = disable(self)
        if stopped == false then return end
        change = nextChange or change
        if not activeChangeCurrent(self, change) then return end
        self.manualRotation = false
    end

    change = advanceActiveSpec(self, change, spec)
    if not activeChangeCurrent(self, change) then return end
    self.longtermCache = {}
    if invalidateChoiceContext then invalidateChoiceContext(self) end

    if not selection then
        self.autoswitchRotation = {}
        return nil, change
    end

    local availableTab = self.specTab
    if not activeChangeCurrent(self, change) then return end

    if availableTab then
        local tab = self.specTab

        if not activeChangeCurrent(self, change) or not activeObjectCall(self, change, tab, 'SelectTab', spec) then
            return
        end
    end

    if not activeChangeCurrent(self, change) then return end
    if not activeCall(self, change, 'UpdateSpecSpells') then return end
    if not activeCall(self, change, 'UpdateAutoSwitch') then return end
    local switch = self.SwitchRotation
    if not activeChangeCurrent(self, change) then return end
    local _, nextChange = switch(self)
    change = nextChange or change
    if not activeChangeCurrent(self, change) then return end
    if activeCall(self, change, 'ButtonFetch') then return nil, change end
end

-- Display name of talent slot idx (1 to 21) for a spec. Returns a "[Tier, Column]" placeholder while the name is not
-- known, and nil for an index outside 1 to 21.
function addon:GetSpecTalentName(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if
        self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].name == nil
    then
        return string.format(L["[Tier: %d, Column: %d]"], floor((idx - 1) / 3) + 1, ((idx - 1) % 3) + 1)
    end

    return self.specTalents[spec][idx].name
end

-- Icon path of talent slot idx (1 to 21) for a spec, the question-mark icon while it is not known, nil outside 1 to 21.
function addon:GetSpecTalentIcon(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if
        self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].icon == nil
    then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    return self.specTalents[spec][idx].icon
end

-- ============================================================================
-- Item-set button bindings
-- ============================================================================

-- Re-points the action-bar slots bound to item set `id` at the set's current first item and drops slots that no longer
-- hold an item. Returns true when anything changed and false when it did nothing. It refuses in combat (slots cannot
-- change then) and while the cursor holds something (it retries in half a second); one pass per set at a time.
function addon:UpdateBoundButton(id)
    if InCombatLockdown and InCombatLockdown() then return false end

    -- Refreshing a slot picks the item up; never replace what the cursor
    -- already holds (a swapped-out action). Retry once it is empty.
    if type(GetCursorInfo) == 'function' and GetCursorInfo() then
        self.deferredBoundButtons = self.deferredBoundButtons or {}
        self.deferredBoundButtons[id] = true

        if not self.deferredBoundTimer and C_Timer and C_Timer.After then
            self.deferredBoundTimer = true

            C_Timer.After(.5, function()
                self.deferredBoundTimer = nil
                local ids = self.deferredBoundButtons
                self.deferredBoundButtons = nil

                for deferred in pairs(ids or {}) do
                    self:UpdateBoundButton(deferred)
                end
            end)
        end

        return false
    end

    self.updatingBoundButtons = self.updatingBoundButtons or {}
    if self.updatingBoundButtons[id] then return false end
    self.updatingBoundButtons[id] = true

    -- pcall so a client error cannot leave updatingBoundButtons[id] set, which would block every later refresh.
    local ok, changed = pcall(function()
        local bindings = self.db.char.bindings
        local slots = bindings[id]
        if not slots then return false end
        local itemid = self:FindFirstItemOfItemSet({}, id, true)
        local updated = false

        for index = #slots, 1, -1 do
            local slot = slots[index]
            local kind, action = GetActionInfo(slot)

            if kind == 'item' then
                if itemid and itemid ~= action then
                    -- C_Item.PickupItem: Retail/Forever have no global, Classic only behind loadDeprecationFallbacks.
                    local pickup = type(C_Item) == 'table' and C_Item.PickupItem or PickupItem
                    self:debug('Updated slot %s to new item %d', slot, itemid)
                    pickup(itemid)
                    PlaceAction(slot)
                    ClearCursor()
                    updated = true
                end
            else
                table.remove(slots, index)
                updated = true
            end
        end

        if #slots == 0 then bindings[id] = nil end
        if updated then self:ButtonFetch() end
        return updated
    end)

    self.updatingBoundButtons[id] = nil
    if not ok then error(changed, 0) end
    return changed
end

-- ============================================================================
-- Event handlers
-- ============================================================================

-- Each addon.<EVENT> below is installed through wrapEvent or wrapCombatEvent and is registered by name in addon:enable
-- (AceEvent calls the method named like the event). Handlers that touch the action bars or the rotation selection do
-- so through the guarded helpers above, never directly.

-- These notifications may change eligibility facts or their readability. Other
-- event handlers do not invalidate a snapshot of player/session eligibility.
local runtimeContextEvents = {
    PLAYER_LEVEL_UP = true,
    UNIT_LEVEL = true,
    PLAYER_ENTERING_WORLD = true,
    PLAYER_LEAVING_WORLD = true,
    PLAYER_EQUIPMENT_CHANGED = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    ACTIVE_TALENT_GROUP_CHANGED = true,
    CHARACTER_POINTS_CHANGED = true,
    SPELLS_CHANGED = true,
    PLAYER_CONTROL_GAINED = true,
    PLAYER_CONTROL_LOST = true,
    UPDATE_SHAPESHIFT_FORM = true,
    VEHICLE_UPDATE = true,
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
    PLAYER_REGEN_ENABLED = true,
    PLAYER_REGEN_DISABLED = true,
}

-- Wraps an event handler and returns the function to install as addon.<EVENT>. Before the handler runs, an event in
-- runtimeContextEvents (or a direct call with no event name) invalidates the evaluation and choice contexts and bumps
-- leanContextEpoch, which makes the lean engine rebuild its plan. The handler then runs inside the Diagnostics error
-- boundary; the first failure disables that handler for the session and stops advice (StopAdviceForError).
local function wrapEvent(func)
    local failed = false
    local context = { module = "events", operation = "dispatch" }

    return function(self, event, ...)
        if invalidateEvaluationContext and (event == nil or runtimeContextEvents[event]) then
            invalidateEvaluationContext()
        end

        if invalidateChoiceContext and (event == nil or runtimeContextEvents[event]) then
            invalidateChoiceContext(self)
        end

        if event == nil or runtimeContextEvents[event] then
            leanContextEpoch = leanContextEpoch + 1

            -- UnitLevel can trail PLAYER_LEVEL_UP; rebuild once more after it settles.
            if event == 'PLAYER_LEVEL_UP' and C_Timer and C_Timer.After then
                C_Timer.After(2, function() leanContextEpoch = leanContextEpoch + 1 end)
            end
        end

        if failed or self.initializationErrorReport then return end
        self:debug("Event %s fired.", event)
        if not self.Diagnostics then return func(self, event, ...) end
        -- Reused per handler: read only if this dispatch records an error.
        context.event, context.rotationId = event, self.currentRotation
        local ok, reportId = self.Diagnostics:Call(context, func, self, event, ...)

        if not ok then
            failed = true
            self:StopAdviceForError(reportId)
        end
    end
end

-- The client project, and so its combat data policy, is fixed for the
-- session; these handlers run for every combat log line in range. A handler
-- with a restricted variant runs it on Retail and Forever, where any payload
-- field may be secret and is checked before it is compared or used as a key.
local combatDataPolicy

-- Like wrapEvent, for handlers that read combat data. `func` runs where the client exposes the data (combatDataPolicy
-- 'probe'); `restricted`, when given, runs instead on Retail and Forever and must check every payload field with
-- Platform:CanReadValue. A handler without a restricted variant does nothing there.
local function wrapCombatEvent(func, restricted)
    local dispatch = wrapEvent(func)
    local restrictedDispatch = restricted and wrapEvent(restricted)

    return function(self, ...)
        if self.initializationErrorReport then return end
        combatDataPolicy = combatDataPolicy or self.Platform:GetClientInfo().combatDataPolicy
        if combatDataPolicy == 'probe' then return dispatch(self, ...) end
        if restrictedDispatch and combatDataPolicy == 'restricted' then return restrictedDispatch(self, ...) end
    end
end

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PARTY_MEMBERS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PLAYER_FLAGS_CHANGED = wrapEvent(addon.SwitchRotation)

-- A stance or form change: records the new form, refetches the buttons and, after a short debounce, re-selects the
-- rotation.
addon.UPDATE_SHAPESHIFT_FORM = wrapEvent(function(self)
    local newForm = GetShapeshiftForm()

    if self.currentForm ~= newForm then
        self.currentForm = newForm

        -- self.skipAnnounce = true
        -- We need the delay because multiple shapeshift events come in at once
        -- and there is no way to know which will be the final one.
        if self.shapeshiftTimer == nil then
            self.shapeshiftTimer = self:ScheduleTimer(function()
                self.shapeshiftTimer = nil
                self:SwitchRotation()
            end, 0.25)

            self:ButtonFetch()
        end
    end
end)

-- Re-checks rotation selection when the stealth state changes.
addon.UPDATE_STEALTH = wrapEvent(addon.SwitchRotation)

-- Forgets the action-bar slots bound to item set `id`: removes the binding, picks the set's items off those slots once
-- the cursor is empty (`expectedItems` names the items to match when the set was just edited), then refetches the
-- buttons and notifies itemSetCallback. Returns false in combat, where slots cannot change, and true otherwise.
function addon:UnbindItemSet(id, expectedItems)
    if InCombatLockdown and InCombatLockdown() then return false end
    local slots = self.db.char.bindings[id] or {}
    self.db.char.bindings[id] = nil

    -- Clearing a slot picks its item up; never swap with or discard what the
    -- cursor already holds. Clear the slots once the cursor is empty.
    -- Picks each matching item off its slot. Retries every half second while the cursor is full and gives up if combat
    -- starts.
    local function clearSlots()
        if type(GetCursorInfo) == 'function' and GetCursorInfo() then
            if C_Timer and C_Timer.After then C_Timer.After(.5, clearSlots) end
            return
        end

        if InCombatLockdown and InCombatLockdown() then return end

        for _, slot in ipairs(slots) do
            local kind, item = GetActionInfo(slot)

            if
                kind == 'item'
                and (expectedItems and self:FindItemInItems(expectedItems, item) or self:FindItemInItemSet(id, item))
                and type(PickupAction) == 'function'
                and type(ClearCursor) == 'function'
            then
                PickupAction(slot)
                ClearCursor()
            end
        end
    end

    clearSlots()
    if self.bindingItemSet == id then self.bindingItemSet = nil end
    if self.EndHighlightSlot then self:EndHighlightSlot() end
    self:ButtonFetch()
    if self.itemSetCallback then self.itemSetCallback(id) end
    return true
end

-- Keeps item-set bindings in step with the bars. A slot that no longer holds one of its set's items is unbound (slot 0
-- means the whole bar changed, so every tracked slot is checked); picking a set item off its slot arms bindingItemSet
-- so dropping it on another slot rebinds it; a pending bind request adopts the slot just filled. Notifies
-- itemSetCallback for every set that changed.
addon.ACTIONBAR_SLOT_CHANGED = wrapEvent(function(self, _, slot)
    local bindings = self.db.char.bindings
    self:ButtonFetch()
    -- Slot zero means the client invalidated the whole bar. Reconcile every
    -- tracked slot, never create a binding to the sentinel itself.
    local cursor, item = GetCursorInfo()
    local pickup
    local changed = {}

    for id, slots in pairs(bindings) do
        for i = #slots, 1, -1 do
            local old = slots[i]

            if slot == 0 or old == slot then
                local kind, action = GetActionInfo(old)

                if kind ~= 'item' or not self:FindItemInItemSet(id, action) then
                    if old == slot and cursor == 'item' and self:FindItemInItemSet(id, item) then pickup = id end
                    table.remove(slots, i)
                    changed[id] = true
                end
            end
        end

        if #slots == 0 then bindings[id] = nil end
    end

    local pending = self.bindingItemSet
    self.bindingItemSet = nil

    if pending and slot > 0 then
        local kind, action = GetActionInfo(slot)

        if kind == 'item' and self:FindItemInItemSet(pending, action) then
            local slots = bindings[pending] or {}
            bindings[pending] = slots
            local found = false

            for _, value in ipairs(slots) do
                if value == slot then found = true end
            end

            if not found then slots[#slots + 1] = slot end
            changed[pending] = true
        end
    end

    if pickup then
        self.bindingItemSet = pickup
        if self.WatchItemSetBind then self:WatchItemSetBind() end
    end

    for id in pairs(changed) do
        if bindings[id] and self.FindFirstItemOfItemSet then self:UpdateBoundButton(id) end
    end

    if self.itemSetCallback then
        for id in pairs(changed) do
            self.itemSetCallback(id)
        end
    end
end)

-- The bar layout or macros changed: rediscover the action-bar buttons.
addon.PET_BAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.PET_BAR_UPDATE = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_PAGE_CHANGED = wrapEvent(addon.ButtonFetch)
addon.UPDATE_MACROS = wrapEvent(addon.ButtonFetch)

-- Vehicle state changed: restore a suspended manual rotation choice, re-read the action context and refetch buttons.
addon.VEHICLE_UPDATE = wrapEvent(function(self)
    restoreManualChoice(self)
    self:ApplyActionContext()
    self:ButtonFetch()
end)

-- Target changed: re-check automatic switching, forget the swing timers and evaluate at once instead of waiting for
-- the next poll tick.
addon.PLAYER_TARGET_CHANGED = wrapEvent(function(self)
    self:verbose("Player targeted something else.")
    -- Switch conditions often read the target; this applies in combat too.
    -- Auto mode checks read-only first, so an unchanged selection keeps the
    -- current evaluation plan.
    self:CheckAutoSwitch()

    self.lastMainSwing = nil
    self.lastOffSwing = nil

    self:EvaluateNextAction()
end)

-- Focus changes use the target handler. This assignment replaces the SwitchRotation-only one near the top of the file.
addon.PLAYER_FOCUS_CHANGED = addon.PLAYER_TARGET_CHANGED

-- The player's pet changed: refresh the spell catalog (pet spells), re-check automatic switching and evaluate.
addon.UNIT_PET = wrapEvent(function(self, _, unit)
    -- UNIT_PET identifies the pet owner, not the changed pet unit.
    if unit == "player" then
        self:verbose("Player %s changed pet.", unit)
        self:UpdateSpecSpells()

        -- Pet switch conditions apply in combat too.
        self:CheckAutoSwitch()

        self:EvaluateNextAction()
    end
end)

-- Control returned (after a fear, charm or similar): restart the poll timer and evaluate straight away.
addon.PLAYER_CONTROL_GAINED = wrapEvent(function(self)
    restoreManualChoice(self)
    self:verbose("Player regained control.")

    if not self.inCombat then
        self:SwitchRotation()
    end

    self:EnableRotationTimer()
    self:EvaluateNextAction()
end)

-- Control was lost: stop polling and clear every glow, unless the player is only driving a vehicle or possessed unit.
addon.PLAYER_CONTROL_LOST = wrapEvent(function(self)
    self:verbose("Player lost control.")

    -- Controlling a vehicle or a possessed unit is not losing control: the
    -- action context transition owns advice for that bar.
    if self.currentRotation and self.ReadActionContext then
        local ok, context = pcall(self.ReadActionContext, self)
        if ok and context ~= 'player' then return self:ApplyActionContext() end
    end

    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
end)

-- Talent changes (and the talent group switch) re-read the specialization through UpdateSkill.
addon.PLAYER_TALENT_UPDATE = wrapEvent(addon.UpdateSkill)
addon.ACTIVE_TALENT_GROUP_CHANGED = wrapEvent(addon.UpdateSkill)

-- Equipment changes are subscribed only on TBC (see addon:enable). The dispatch below re-runs rotation selection and
-- one evaluation, but only while the subscription made at enable time, the profile and the active transition are still
-- the ones the event started with.
-- BEGIN EQUIPMENT EVENT DISPATCH
-- The wrapped handler body: every step re-proves the subscription, profile and transition before it acts.
local equipmentEvent = wrapEvent(function(self, _, subscription, profile, change)
    if
        self ~= addon
        or equipmentSubscription ~= subscription
        or self.db.profile ~= profile
        or not activeChangeCurrent(self, change)
    then
        return
    end

    local coordinator

    if self.GetScopedRotationCoordinator ~= equipmentCoordinator or not activeChangeCurrent(self, change) then
        return
    end

    if equipmentCoordinator then coordinator = equipmentCoordinator(self) end

    -- True while the subscription, profile, scope coordinator and transition are all unchanged since the event began.
    local function current()
        if
            not activeChangeCurrent(self, change)
            or equipmentSubscription ~= subscription
            or self.db.profile ~= profile
            or self.GetScopedRotationCoordinator ~= equipmentCoordinator
        then
            return false
        end

        if equipmentCoordinator and equipmentCoordinator(self) ~= coordinator then return false end

        return self.db.profile == profile
            and self.GetScopedRotationCoordinator == equipmentCoordinator
            and activeChangeCurrent(self, change)
            and equipmentSubscription == subscription
    end

    if not current() or self.enabledState ~= true or not current() then return end
    local switch = self.SwitchRotation
    if not current() or type(switch) ~= 'function' then return end
    local _, nextChange = switch(self)
    change = nextChange or change
    if not current() or self.currentRotation == nil then return end
    local evaluate = self.EvaluateNextAction
    if current() and type(evaluate) == 'function' then evaluate(self) end
end)

-- The registered entry point. It ignores the event unless the addon is enabled with a live subscription, opens a
-- transition token, and only then hands over to equipmentEvent.
addon.PLAYER_EQUIPMENT_CHANGED = function(self, event)
    local subscription = equipmentSubscription
    if not rawequal(self, addon) or not subscription or self.enabledState ~= true then return end
    local profile = self.db.profile
    if equipmentSubscription ~= subscription or type(profile) ~= 'table' then return end
    local change = beginActive(self)

    if not activeChangeCurrent(self, change) or equipmentSubscription ~= subscription or self.db.profile ~= profile then
        return
    end

    return equipmentEvent(self, event, subscription, profile, change)
end

-- END EQUIPMENT EVENT DISPATCH
-- A changed spell list refreshes the spell catalog through UpdateSkill.
addon.SPELLS_CHANGED = wrapEvent(addon.UpdateSkill)

-- Drops the cached player level (the condition cache entry and the native UnitLevel cache) so the next read asks the
-- client again.
local function invalidatePlayerLevel(self)
    if type(self.longtermCache) ~= 'table' then return end
    self.longtermCache.conditionPlayerLevel = nil
    -- Saved raw condition sources may still use the native cache identity.
    local native = type(UnitLevel) == 'function' and self.longtermCache[UnitLevel]
    if type(native) == 'table' then native.player = nil end
end

-- Level-up: drops the cached level now and again 10 ms later, then re-runs the auto-switch conditions, rotation
-- selection and an evaluation.
addon.PLAYER_LEVEL_UP = wrapEvent(function(self)
    invalidatePlayerLevel(self)

    -- Level facts can still be old while the event is being dispatched.
    self:ScheduleTimer(function()
        invalidatePlayerLevel(self)
        self:UpdateAutoSwitch()
        self:SwitchRotation()
        if self.currentRotation then self:EvaluateNextAction() end
    end, 0.01)
end)

-- Talent point and specialization changes also go through UpdateSkill.
addon.CHARACTER_POINTS_CHANGED = wrapEvent(addon.UpdateSkill)
addon.PLAYER_SPECIALIZATION_CHANGED = wrapEvent(addon.UpdateSkill)

-- A zone or group change can change which rotation applies: re-select, but not in combat. ZONE_CHANGED_INDOORS and
-- GROUP_ROSTER_UPDATE share this handler.
addon.ZONE_CHANGED = wrapEvent(function(self)
    addon:verbose("Player switched zones.")

    if not self.inCombat then
        self:SwitchRotation()
    end
end)

addon.ZONE_CHANGED_INDOORS = addon.ZONE_CHANGED
addon.GROUP_ROSTER_UPDATE = addon.ZONE_CHANGED

-- Login or any loading screen: rebuilds the options, glow settings, specialization state and bag contents, and
-- refreshes every item-set binding and button.
addon.PLAYER_ENTERING_WORLD = wrapEvent(function(self)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets
    local bindings = self.db.char.bindings

    self:verbose("Player entered world.")
    self:SetupOptions()
    self:UpdateButtonGlow()
    self:UpdateSkill()
    self:UpdateBagContents()

    for id, _ in pairs(bindings) do
        self:UpdateBoundButton(id)
    end

    for id, _ in pairs(itemsets) do
        self:UpdateItemSetButtons(id)
    end

    for id, _ in pairs(global_itemsets) do
        self:UpdateItemSetButtons(id)
    end
end)

-- Combat started: sets inCombat, clears the swing timers and starts a fresh combat cache.
addon.PLAYER_REGEN_DISABLED = wrapEvent(function(self)
    self:verbose("Player is in combat.")
    self.inCombat = true
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.combatCache = {}
    self.combatStart = GetTime()
end)

-- Combat ended: clears the combat state, re-selects the rotation and refreshes the item-set slots, which the client
-- would not let us change during combat.
addon.PLAYER_REGEN_ENABLED = wrapEvent(function(self)
    self:verbose("Player is out of combat.")
    self.inCombat = false
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.lastRangedShot = nil
    self.combatCache = {}
    self.combatStart = nil

    self:SwitchRotation()

    -- Item Slots can't be updated while in combat.
    for id, _ in pairs(self.db.char.bindings) do
        self:UpdateBoundButton(id)
    end

    for id, _ in pairs(self.db.profile.itemsets) do
        self:UpdateItemSetButtons(id)
    end

    for id, _ in pairs(self.db.global.itemsets) do
        self:UpdateItemSetButtons(id)
    end
end)

-- A vehicle replaces the player's bar: the action context transition picks a
-- vehicle rotation or suspends advice, and restores the player's on exit.
addon.UNIT_ENTERED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player on a vehicle.")
        self:ApplyActionContext()
        self:ButtonFetch()
    end
end)

-- Leaving a vehicle also restores a suspended manual rotation choice and resumes polling.
addon.UNIT_EXITED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player off a vehicle.")
        restoreManualChoice(self)
        self:ApplyActionContext()
        self:ButtonFetch()
        self:EnableRotationTimer()
        self:EvaluateNextAction()
    end
end)

-- ============================================================================
-- Action bar context
-- ============================================================================

-- BEGIN ACTION CONTEXT
-- The bar the player acts through: player, vehicle, possession, override or
-- petbattle. Observed only on the notifications above (and once per
-- auto-switch re-check as a floor for clients lacking one), never per poll.
-- A change advances the context epoch, dirties the idle gate, refetches
-- buttons and re-selects: an applicable rotation for the new bar, or
-- suspended advice; leaving restores the player's rotation (a manual choice
-- included, even with automatic switching off).
local actionContext
local actionSuspended

-- Returns the last observed action context, 'player' when none has been read yet.
function addon:GetActionContext()
    return actionContext or 'player'
end

-- Reads the context through ReadActionContext (a failure or a non-string result counts as 'player'), stores it and
-- returns it plus whether it differs from the previous observation. The first observation is never a change.
function addon:RefreshActionContext()
    local read = self.ReadActionContext
    local ok, value = true, 'player'
    if type(read) == 'function' then ok, value = pcall(read, self) end
    if not ok or type(value) ~= 'string' then value = 'player' end
    local changed = actionContext ~= nil and value ~= actionContext
    actionContext = value
    return value, changed
end

-- Re-reads the action context and, when it changed, reacts to it: bumps the context epoch, dirties the idle gate,
-- invalidates the evaluation caches, refetches the buttons and re-selects a rotation. A rotation that cannot be
-- resolved for the new bar is stopped (remembered in actionSuspended when leaving the player bar), and returning to
-- the player bar brings back a suspended manual choice. Returns true when the context changed.
function addon:ApplyActionContext()
    local previous = actionContext or 'player'
    local value, changed = self:RefreshActionContext()
    if not changed then return false end
    leanContextEpoch = leanContextEpoch + 1
    idleGate.dirty = true
    if invalidateEvaluationContext then invalidateEvaluationContext() end
    if invalidateChoiceContext then invalidateChoiceContext(self) end
    self:verbose("Action context changed from %s to %s.", previous, value)
    self:ButtonFetch()
    local spec, profile = self.currentSpec, self.db.profile

    if self.currentRotation ~= nil and spec ~= nil and not runtimeOne(self, spec, self.currentRotation) then
        if previous == 'player' then
            actionSuspended = {
                spec = spec,
                profile = profile,
                rotation = self.currentRotation,
                manual = self.manualRotation == true,
            }
        end

        self.manualRotation = false
        self:DisableRotation()
    end

    local suspended = actionSuspended

    if value == 'player' then
        actionSuspended = nil

        if
            suspended
            and suspended.manual
            and self.currentRotation == nil
            and suspended.spec == self.currentSpec
            and suspended.profile == self.db.profile
            and runtimeOne(self, suspended.spec, suspended.rotation)
        then
            chooseManualRotation(self, suspended.rotation, nil, false)
        end
    end

    self:SwitchRotation()

    if self.currentRotation == nil and value ~= 'player' and actionSuspended then
        self:info(L["Advice is suspended: no rotation applies while you are using another action bar."])
    end

    return true
end

-- Bar-swap notifications: apply the new action context, or just refetch the buttons when the context is unchanged.
local function actionBarChanged(self)
    if not self:ApplyActionContext() then self:ButtonFetch() end
end

-- Bar swaps go through actionBarChanged; the start and end of a pet battle change the context directly.
addon.UPDATE_VEHICLE_ACTIONBAR = wrapEvent(actionBarChanged)
addon.UPDATE_OVERRIDE_ACTIONBAR = wrapEvent(actionBarChanged)
addon.UPDATE_POSSESS_BAR = wrapEvent(actionBarChanged)
addon.UPDATE_BONUS_ACTIONBAR = wrapEvent(actionBarChanged)
-- A pet battle starting or ending re-reads the action context.
addon.PET_BATTLE_OPENING_START = wrapEvent(function(self) self:ApplyActionContext() end)
addon.PET_BATTLE_CLOSE = wrapEvent(function(self) self:ApplyActionContext() end)
-- END ACTION CONTEXT

-- ============================================================================
-- Nameplate unit tracking
-- ============================================================================

-- Nameplate removal can arrive after its token stops resolving. Retire by the
-- stored token; preserve only a positively identified canonical replacement.
local nameplateEvent

-- True while `snapshot` is still the unit map and `ticket` the newest nameplate event. Every provider call below
-- rechecks it, because a callback can reenter these handlers and replace either.
local function nameplateCurrent(self, snapshot, ticket)
    return self.unitsInRange == snapshot and nameplateEvent == ticket
end

-- Returns whether `value` may be read on this client (Platform:CanReadValue), or nil when the snapshot or ticket went
-- stale during the call; nil means the caller must abandon the event.
local function nameplateReadable(self, snapshot, ticket, value)
    local readable = self.Platform:CanReadValue(value)
    if not nameplateCurrent(self, snapshot, ticket) then return nil end
    return not not readable
end

-- Returns the GUID of a nameplate unit, or nil when the event went stale or the GUID is missing, secret or empty.
local function nameplateGUID(self, snapshot, ticket, unit)
    local ok, guid = pcall(UnitGUID, unit)
    if not nameplateCurrent(self, snapshot, ticket) or not ok then return nil end
    if not nameplateReadable(self, snapshot, ticket, guid) then return nil end
    if canaccessvalue and type(canaccessvalue) ~= "function" then return nil end
    if canaccessvalue and not canaccessvalue(guid) then return nil end
    if not nameplateCurrent(self, snapshot, ticket) then return nil end
    if type(guid) == "string" and guid ~= "" then return guid end
end

-- Lists the map entries that still name `unit` under a GUID other than `keep`, each with the canonical unit alias that
-- now carries that GUID (change.alias, nil when there is none). Returns the list, empty when nothing needs to move, or
-- nil when the event went stale or a value was unreadable.
local function nameplateChanges(self, snapshot, ticket, unit, keep)
    -- Provider calls can reenter these handlers and mutate public maps. Finish
    -- copying their keys before calling any provider or readability function.
    local entries, changes = {}, {}

    for guid, entry in pairs(snapshot) do
        entries[#entries + 1] = { guid = guid, entry = entry }
    end

    for _, change in ipairs(entries) do
        local entry = change.entry

        if type(entry) == "table" and getmetatable(entry) == nil then
            local stored = rawget(entry, "unit")
            local readable = nameplateReadable(self, snapshot, ticket, stored)
            if readable == nil then return nil end

            if readable and type(stored) == "string" and stored == unit then
                readable = nameplateReadable(self, snapshot, ticket, change.guid)
                if readable == nil then return nil end

                if readable and type(change.guid) == "string" and change.guid ~= keep then
                    changes[#changes + 1] = change
                end
            end
        end
    end

    if #changes == 0 then return changes end
    local units, aliases = {}, {}

    for alias in pairs(addon.units) do
        if not (addon.groupUnitKinds and addon.groupUnitKinds[alias]) then units[#units + 1] = alias end
    end

    for _, alias in ipairs(units) do
        local readable = nameplateReadable(self, snapshot, ticket, alias)
        if readable == nil then return nil end

        if readable and type(alias) == "string" and alias ~= unit then
            local guid = nameplateGUID(self, snapshot, ticket, alias)
            if not nameplateCurrent(self, snapshot, ticket) then return nil end
            if guid and not aliases[guid] then aliases[guid] = alias end
        end
    end

    for _, change in ipairs(changes) do
        change.alias = aliases[change.guid]
    end

    return changes
end

-- Raw read of an entry's unit field. Always called under pcall so a value that became restricted cannot raise outside
-- a protected call.
local function nameplateStoredMatches(entry, stored)
    return rawget(entry, "unit") == stored
end

-- Applies the changes from nameplateChanges: an entry still stored under `unit` is retargeted to its canonical alias,
-- or removed from the map when it has none. Each entry is rechecked just before it is written. Returns false when the
-- event went stale.
local function applyNameplateChanges(self, snapshot, ticket, unit, changes)
    for _, change in ipairs(changes) do
        if rawget(snapshot, change.guid) == change.entry then
            local stored = rawget(change.entry, "unit")
            local readable = nameplateReadable(self, snapshot, ticket, stored)
            if readable == nil then return false end

            if readable and type(stored) == "string" and stored == unit then
                -- A readability callback may directly replace the field. Never
                -- compare a newly restricted value outside a protected read.
                local ok, unchanged = pcall(nameplateStoredMatches, change.entry, stored)

                if ok and unchanged and rawget(snapshot, change.guid) == change.entry then
                    if change.alias then
                        rawset(change.entry, "unit", change.alias)
                    else
                        rawset(snapshot, change.guid, nil)
                    end
                end
            end
        end
    end

    return true
end

-- A disabled addon misses removal events. Reconcile only at subscription
-- renewal: enumeration adds positive observations; it never proves absence.
-- Negative evidence is confined to ordinary native nameplate tokens, with a
-- readable current GUID change or readable GUID nil AND UnitExists false.
do
    local kind, meta, read, write, same, nextEntry, items, protected, raise, match =
        type, getmetatable, rawget, rawset, rawequal, next, ipairs, pcall, error, string.match

    -- Called from addon:enable on probe clients with the enable transition's token. Compares the unit map with a fresh
    -- enumeration of the canonical units and the visible nameplate frames, all inside one protected call, and writes
    -- the differences only at the very end and only if the map is unchanged since it was copied. Any failure, stale
    -- token or unreadable value leaves the old map exactly as it was.
    reconcileNameplateResume = function(self, change)
        local snapshot = self.unitsInRange
        if kind(snapshot) ~= "table" or meta(snapshot) ~= nil then return end
        local ticket = {}
        nameplateEvent = ticket
        local db, profile = self.db, self.db.profile

        -- True while this resume is still the newest nameplate event and the enable transition is current.
        local function current()
            return nameplateCurrent(self, snapshot, ticket)
                and self.db == db
                and db.profile == profile
                and kind(activeCurrent) == "function"
                and activeCurrent(self, change)
        end

        -- Native/frame/readability failures leave the complete old map intact.
        -- All writes below occur after the last callback and exact slot checks.
        protected(function()
            -- Aborts the protected block, leaving the old map intact, as soon as the resume goes stale.
            local function requireCurrent()
                if not current() then raise("stale nameplate resume", 0) end
            end

            -- Returns value after proving it is readable and not restricted; raises otherwise.
            local function readable(value)
                requireCurrent()
                if not self.Platform:CanReadValue(value) then raise("unreadable nameplate resume", 0) end
                requireCurrent()

                if canaccessvalue then
                    if kind(canaccessvalue) ~= "function" or not canaccessvalue(value) then
                        raise("restricted nameplate resume", 0)
                    end

                    requireCurrent()
                end

                return value
            end

            -- Calls a client provider, requiring the resume to stay current around the call, and returns its result
            -- only if it is readable.
            local function observe(fn, ...)
                requireCurrent()
                if kind(fn) ~= "function" then raise("missing nameplate resume provider", 0) end
                local value = fn(...)
                requireCurrent()
                return readable(value)
            end

            local old, proposed, retargets, observations, frames = {}, {}, {}, {}, {}

            for guid, entry in nextEntry, snapshot do
                old[#old + 1] = {
                    guid = guid,
                    entry = entry,
                    meta = kind(entry) == "table" and meta(entry) or nil,
                    unit = kind(entry) == "table" and meta(entry) == nil and read(entry, "unit") or nil,
                }

                proposed[guid] = entry
            end

            local aliases = {}
            local units = {}

            for unit in nextEntry, addon.units do
                if not (addon.groupUnitKinds and addon.groupUnitKinds[unit]) then units[#units + 1] = unit end
            end

            -- GUID of a unit token, or nil when the unit does not exist. Each reading is recorded in `observations` so
            -- it can be verified again just before the commit.
            local function guidFor(unit)
                local guid = observe(UnitGUID, unit)
                if guid ~= nil and (kind(guid) ~= "string" or guid == "") then raise("unknown nameplate GUID", 0) end
                observations[#observations + 1] = { unit = unit, guid = guid }
                return guid
            end

            for _, unit in items(units) do
                readable(unit)
                if kind(unit) ~= "string" then raise("unknown canonical unit", 0) end
                local guid = guidFor(unit)
                if guid and not aliases[guid] then aliases[guid] = unit end
            end

            local api = C_NamePlate
            if kind(api) ~= "table" then return end
            local listed = observe(api.GetNamePlates)
            if kind(listed) ~= "table" or meta(listed) ~= nil then return end
            local members = {}

            for _, frame in nextEntry, listed do
                members[#members + 1] = frame
            end

            for _, frame in items(members) do
                readable(frame)
                if observe(frame.IsForbidden, frame) ~= false then return end
                local unit = observe(frame.GetUnit, frame)
                if kind(unit) ~= "string" or not match(unit, "^nameplate%d+$") then return end
                local guid = guidFor(unit)
                if not guid then return end
                frames[#frames + 1] = { frame = frame, unit = unit, guid = guid }
            end

            for _, item in items(old) do
                local unit = readable(item.unit)

                if kind(unit) == "string" and match(unit, "^nameplate%d+$") then
                    readable(item.guid)
                    local guid = guidFor(unit)
                    local obsolete = guid ~= nil and guid ~= item.guid

                    if guid == nil then
                        local exists = observe(UnitExists, unit)
                        if kind(exists) ~= "boolean" then return end
                        observations[#observations].exists = exists
                        obsolete = exists == false
                    end

                    if obsolete then
                        if aliases[item.guid] then
                            retargets[item.entry] = aliases[item.guid]
                        else
                            proposed[item.guid] = nil
                        end
                    end
                end
            end

            for _, item in items(frames) do
                local entry = proposed[item.guid]
                if entry ~= nil and (kind(entry) ~= "table" or meta(entry) ~= nil) then return end

                if not entry then
                    entry = CreateUnitInfo({}, item.unit)
                    requireCurrent()
                end

                proposed[item.guid] = entry
                retargets[entry] = item.unit
            end

            for _, item in items(observations) do
                if observe(UnitGUID, item.unit) ~= item.guid then return end
                if item.exists ~= nil and observe(UnitExists, item.unit) ~= item.exists then return end
            end

            for _, item in items(old) do
                readable(item.guid)
                readable(item.unit)
            end

            -- Readability/GUID callbacks above can also recycle pooled frames.
            -- Check their current binding last, then commit without more providers.
            for _, item in items(frames) do
                if
                    observe(item.frame.IsForbidden, item.frame) ~= false
                    or observe(item.frame.GetUnit, item.frame) ~= item.unit
                then
                    return
                end
            end

            requireCurrent()
            if meta(snapshot) ~= nil then return end
            local count = 0

            for _ in nextEntry, snapshot do
                count = count + 1
            end

            if count ~= #old then return end

            for _, item in items(old) do
                if not same(read(snapshot, item.guid), item.entry) then return end

                if kind(item.entry) == "table" then
                    if meta(item.entry) ~= item.meta then return end
                    if item.meta == nil and read(item.entry, "unit") ~= item.unit then return end
                end
            end

            requireCurrent()

            for entry, unit in nextEntry, retargets do
                write(entry, "unit", unit)
            end

            for _, item in items(old) do
                if proposed[item.guid] == nil then write(snapshot, item.guid, nil) end
            end

            for guid, entry in nextEntry, proposed do
                write(snapshot, guid, entry)
            end
        end)
    end
end

-- Restricted clients: the token alone (its GUID is secret for an NPC). Adds or removes the token in the
-- self.nameplateUnits set and ignores a token that is unreadable or not a non-empty string.
local function restrictedNameplateUnit(self, unit, shown)
    local units = self.nameplateUnits

    if type(units) ~= "table" or not self.Platform:CanReadValue(unit) or type(unit) ~= "string" or unit == "" then
        return
    end

    if shown then
        units[unit] = true
    else
        units[unit] = nil
    end
end

-- A nameplate appeared: maps its GUID to a unit entry that names the nameplate token, first moving any entry that named
-- the same token under an older GUID. Every provider call is followed by a staleness check, and nothing is written
-- unless the map is exactly as it was read. The second function is the restricted-client variant.
addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local ticket = {}
    nameplateEvent = ticket
    local snapshot = self.unitsInRange
    if type(snapshot) ~= "table" or getmetatable(snapshot) ~= nil then return end
    if not nameplateReadable(self, snapshot, ticket, unit) or type(unit) ~= "string" or unit == "" then return end
    local guid = nameplateGUID(self, snapshot, ticket, unit)
    if not guid then return end
    local changes = nameplateChanges(self, snapshot, ticket, unit, guid)
    if not changes then return end
    local previous = rawget(snapshot, guid)
    if previous ~= nil and (type(previous) ~= "table" or getmetatable(previous) ~= nil) then return end
    local previousUnit = previous and rawget(previous, "unit")

    if previous and (not nameplateReadable(self, snapshot, ticket, previousUnit) or type(previousUnit) ~= "string") then
        return
    end

    local entry = previous or CreateUnitInfo({}, unit)
    if not nameplateCurrent(self, snapshot, ticket) then return end
    if not applyNameplateChanges(self, snapshot, ticket, unit, changes) then return end
    local current = rawget(snapshot, guid)
    if type(current) ~= type(previous) or not rawequal(current, previous) then return end

    if previous then
        local ok, unchanged = pcall(nameplateStoredMatches, previous, previousUnit)
        if not ok or not unchanged then return end
    end

    rawset(entry, "unit", unit)
    rawset(snapshot, guid, entry)
end, function(self, _, unit) restrictedNameplateUnit(self, unit, true) end)

-- A nameplate went away: retires the entries that still name its token, retargeting each to its canonical unit alias
-- when one carries the same GUID. Removal can arrive after the token stops resolving, so it works from the stored
-- token only. The second function is the restricted-client variant.
addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local ticket = {}
    nameplateEvent = ticket
    local snapshot = self.unitsInRange
    if type(snapshot) ~= "table" or getmetatable(snapshot) ~= nil then return end
    if not nameplateReadable(self, snapshot, ticket, unit) or type(unit) ~= "string" or unit == "" then return end
    local changes = nameplateChanges(self, snapshot, ticket, unit)
    if not changes then return end
    if not nameplateCurrent(self, snapshot, ticket) then return end
    applyNameplateChanges(self, snapshot, ticket, unit, changes)
end, function(self, _, unit) restrictedNameplateUnit(self, unit, false) end)

-- Bag contents changed: refresh the buttons bound to item sets and the cached bag contents.
addon.BAG_UPDATE = wrapEvent(function(self)
    local bindings = self.db.char.bindings

    for id, _ in pairs(bindings) do
        self:UpdateBoundButton(id)
    end

    self:UpdateBagContents()
end)

-- ============================================================================
-- Combat history, casts and announcements
-- ============================================================================

-- Damage/heal and UNIT_COMBAT histories are read only by their conditions.
-- A reader stamps WantHistory each time it evaluates; events record while a
-- reader ran in the last minute (an active rotation evaluates at least every
-- idle_poll seconds), so nobody pays for histories no rotation uses.
local historyWanted = { damage = 0, combat = 0 }
addon.historyWanted = historyWanted

-- Called by a history condition each time it evaluates: keeps `kind` ('damage' or 'combat') recording for another
-- minute. Runs on the poll path, so it only stores a number.
function addon:WantHistory(kind)
    historyWanted[kind] = GetTime() + 60
end

-- The restricted variant's recorder (the probe handler keeps its own copy). Puts `entry` at the front of the unit's
-- combat history after dropping entries older than the profile's combat_history seconds.
local function recordCombatAction(self, unit, entry)
    if self.combatHistory[unit] == nil then
        self.combatHistory[unit] = {}
    end

    -- Evaluation trims too, but it does not run without an active rotation.
    local history = self.combatHistory[unit]
    local profile = self.db and self.db.profile
    local threshold = entry.time - (profile and profile.combat_history or 10)

    while #history > 0 and history[#history].time < threshold do
        history[#history] = nil
    end

    table.insert(history, 1, entry)
end

-- Records each UNIT_COMBAT hit or heal per unit into combatHistory, but only while a history condition has asked for it
-- in the last minute (historyWanted.combat). The second function is the restricted-client variant.
addon.UNIT_COMBAT = wrapCombatEvent(function(self, _, unit, action, severity, value, type)
    local now = GetTime()
    local wanted = self.historyWanted
    if wanted and now > wanted.combat then return end

    if self.combatHistory[unit] == nil then
        self.combatHistory[unit] = {}
    end

    -- Evaluation trims too, but it does not run without an active rotation.
    local history = self.combatHistory[unit]
    local profile = self.db and self.db.profile
    local threshold = now - (profile and profile.combat_history or 10)

    while #history > 0 and history[#history].time < threshold do
        history[#history] = nil
    end

    table.insert(history, 1, {
        time = now,
        action = action,
        severity = severity,
        value = value,
        type = type,
    })
end, function(self, _, unit, action, severity, value, kind)
    -- UNIT_COMBAT carries no secret annotation (Blizzard_APIDocumentationGenerated,
    -- live 12.1.5 and forever 1.60.1), but every field is still checked. An
    -- action that cannot be read is recorded as unknown (action false), so a
    -- history reader at that position is unavailable rather than wrong.
    local platform = self.Platform
    if not platform:CanReadValue(unit) or type(unit) ~= "string" or unit == "" then return end
    local now = GetTime()
    local wanted = self.historyWanted
    if wanted and now > wanted.combat then return end
    local entry = { time = now, action = false }

    if
        platform:CanReadValue(action)
        and type(action) == "string"
        and platform:CanReadValue(severity)
        and (severity == nil or type(severity) == "string")
    then
        entry.action, entry.severity = action, severity
    end

    if platform:CanReadValue(value) then entry.value = value end
    if platform:CanReadValue(kind) then entry.type = kind end
    recordCombatAction(self, unit, entry)
end)

-- Cast targets by cast GUID (from UNIT_SPELLCAST_SENT), the last target by spell id, and the player's channel marker.
local currentSpells = {}
local lastCastTarget = {}  -- work around UNIT_SPELLCAST_SENT not always triggering
local currentChannel

-- Shared handler of the UNIT_SPELLCAST_* events: runs the announcement rules for the player's and pet's casts. A rule
-- fires when its event matches this one, its spell or item list contains the cast spell and its conditions pass, and at
-- most once per cast GUID (self.announced). {{spell}}, {{item}}, {{event}} and {{target}} in its text are filled in
-- from the cast. Series rules (rules with outputs) deliver their cards through DispatchAnnouncementSeries instead.
local function spellcast(self, event, unit, castguid, spellid)
    -- even though we check it later, this skips rows entirely.
    if unit == 'player' or unit == "pet" then
        -- BEGIN ANNOUNCEMENT CONDITION OWNER
        local profile = self.db.profile
        local announcements = profile.announces

        for index, value in ipairs(announcements) do
            -- END ANNOUNCEMENT CONDITION OWNER
            if
                value.type ~= 'macro'
                and (value.outputs ~= nil or value.value or value.announce == "audible" or value.announce == "gesture")
                and (not value.disabled)
                and (value.type == (BOOKTYPE_PET or "pet") and unit == "pet" or unit == "player")
                and type(value.event) == "string"
                and (event == "UNIT_SPELLCAST_" .. value.event or event == "UNIT_SPELLCAST_CHANNEL_" .. value.event)
            then
                local skip = false

                if self.announced[value.id] then
                    for _, val in ipairs(self.announced[value.id]) do
                        if val == castguid then
                            skip = true
                        end
                    end
                end

                if not skip then
                    -- BEGIN ANNOUNCEMENT CONDITION LEASE
                    local registry = self.conditionRegistryVersion
                    local seriesRecipient = currentSpells[castguid]
                    local seriesLifecycle = value.outputs ~= nil and self.IsEnabled or nil

                    -- For series rules only (other rules are always enabled here): true while the addon is still
                    -- enabled and IsEnabled is the method captured when the rule started.
                    local function seriesEnabled()
                        if value.outputs == nil then return true end
                        if self.IsEnabled ~= seriesLifecycle then return false end

                        if seriesLifecycle ~= nil then
                            if type(seriesLifecycle) ~= 'function' then return false end
                            local ok, enabled = pcall(seriesLifecycle, self)
                            if not ok or enabled ~= true then return false end
                        end

                        local state = rawget(self, 'enabledState')

                        return self.IsEnabled == seriesLifecycle
                            and rawget(self, 'enabledState') == state
                            and (state == nil or state == true)
                    end

                    local ent, current = self:PrepareAnnouncementDelivery(value, function()
                        return seriesEnabled()
                            and self.db.profile == profile
                            and profile.announces == announcements
                            and announcements[index] == value
                            and not value.disabled
                            and self.conditionRegistryVersion == registry
                            and (value.outputs == nil or currentSpells[castguid] == seriesRecipient)
                    end)

                    if ent and current() and (ent.outputs == nil or self:IsValidAnnouncement(value) and current()) then
                        -- END ANNOUNCEMENT CONDITION LEASE
                        local spellids, itemids = self:GetSpellIds(ent)

                        for idx, sid in ipairs(spellids) do
                            if spellid == sid then
                                if ent.outputs ~= nil then
                                    if not current() then return end

                                    -- Reserve the parent once before any card callback.
                                    if self.announced[ent.id] == nil then
                                        self.announced[ent.id] = { castguid }
                                    else
                                        table.insert(self.announced[ent.id], castguid)
                                    end

                                    self:DispatchAnnouncementSeries(ent, seriesRecipient, current, nil, function(
                                        card,
                                        live
                                    )
                                        local text = card.value or ''
                                        local link, itemLink
                                        if text:find('{{target}}', 1, true) and not seriesRecipient then return nil end

                                        if text:find('{{spell}}', 1, true) then
                                            if
                                                ent.type ~= (BOOKTYPE_SPELL or "spell")
                                                and ent.type ~= (BOOKTYPE_PET or "pet")
                                            then
                                                return nil
                                            end

                                            link = spellLink(sid)
                                            if type(link) ~= 'string' or not live() then return nil end
                                        end

                                        if text:find('{{item}}', 1, true) then
                                            if ent.type ~= 'item' then return nil end
                                            local info = self.Platform:GetItemDisplayInfo(itemids[idx])
                                            itemLink = info and info.link
                                            if type(itemLink) ~= 'string' or not live() then return nil end
                                        end

                                        return text:gsub('{{target}}', function() return seriesRecipient end):gsub(
                                            '{{spell}}',
                                            function() return link end
                                        ):gsub('{{item}}', function() return itemLink end):gsub('{{event}}', function()
                                            return self.events[ent.event]
                                        end)
                                    end)
                                else
                                    -- BEGIN ANNOUNCEMENT CONDITION MATCH
                                    if self:AnnouncementConditionMatches(ent, currentSpells[castguid], current) then
                                        -- END ANNOUNCEMENT CONDITION MATCH
                                        local text = ent.value or ""

                                        if ent.announce ~= 'audible' and ent.announce ~= 'gesture' then
                                            if
                                                ent.type == (BOOKTYPE_SPELL or "spell")
                                                or ent.type == (BOOKTYPE_PET or "pet")
                                            then
                                                local link = spellLink(sid)
                                                text = text:gsub("{{spell}}", link)
                                            elseif ent.type == "item" then
                                                local info = self.Platform:GetItemDisplayInfo(itemids[idx])
                                                local link = info and info.link

                                                if type(link) == "string" then
                                                    text = text:gsub("{{item}}", function() return link end)
                                                end
                                            end

                                            text = text:gsub("{{event}}", self.events[ent.event])

                                            if currentSpells[castguid] or lastCastTarget[spellid] then
                                                text = text:gsub(
                                                    "{{target}}",
                                                    currentSpells[castguid] or lastCastTarget[spellid]
                                                )
                                            end
                                        end

                                        if not current() then return end  -- ANNOUNCEMENT CONDITION BEFORE OUTPUT

                                        -- Reserve before any output callback can reenter this cast.
                                        if self.announced[ent.id] == nil then
                                            self.announced[ent.id] = { castguid }
                                        else
                                            table.insert(self.announced[ent.id], castguid)
                                        end

                                        if ent.announce == 'gesture' then
                                            self:DispatchAnnouncement(ent, nil, currentSpells[castguid], current)
                                        else
                                            self:DispatchAnnouncement(ent, text, nil, current)
                                        end
                                    end  -- ANNOUNCEMENT CONDITION OUTPUT
                                end  -- ANNOUNCEMENT SERIES OR LEGACY

                                break
                            end
                        end
                    end  -- ANNOUNCEMENT CONDITION LEASE
                end
            end
        end
    end
end

-- Cast start only drives announcements.
addon.UNIT_SPELLCAST_START = wrapCombatEvent(spellcast)

-- Cast stopped: runs announcements, then forgets the player's cast target and resets the swing timers.
addon.UNIT_SPELLCAST_STOP = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)

    if unit == 'player' then
        currentSpells[castguid] = nil
        self.lastMainSwing = nil
        self.lastOffSwing = nil
    end
end)

-- The restricted variant's recorder (the probe handler keeps its own copy). Puts the spell (false when it was
-- unreadable) at the front of spellHistory after dropping entries older than the profile's spell_history seconds.
local function recordSpellCast(self, spellid)
    local now = GetTime()
    local history = self.spellHistory

    table.insert(history, 1, {
        spell = spellid,  --[[ this was causing spellid to be nil in spellHistory, breaking the spell history conditions. ]]
        time = now,
    })

    -- Evaluation trims too, but it does not run without an active rotation.
    local threshold = now - (self.db.profile.spell_history or 60)

    while #history > 1 and history[#history].time < threshold do
        history[#history] = nil
    end
end

-- A cast completed: runs announcements and records the spell in spellHistory for the player and pet. The second
-- function is the restricted-client variant, which records only (see recordSpellCast).
addon.UNIT_SPELLCAST_SUCCEEDED = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)

    if unit == 'player' then
        if currentChannel then
            currentChannel = castguid
        end
    end

    if unit == 'player' or unit == 'pet' then
        local now = GetTime()
        local history = self.spellHistory

        table.insert(history, 1, {
            spell = spellid,  --[[ this was causing spellid to be nil in spellHistory, breaking the spell history conditions. ]]
            time = now,
        })

        -- Evaluation trims too, but it does not run without an active rotation.
        local threshold = now - (self.db.profile.spell_history or 60)

        while #history > 1 and history[#history].time < threshold do
            history[#history] = nil
        end
    end
end, function(self, _, unit, _, spellid)
    -- The player's and pet's casts are readable unless Blizzard flags the
    -- spell always secret (SecretWhenUnitSpellCastRestricted). A secret spell
    -- is still a cast: it is recorded as unknown (spell false), so a history
    -- reader at that position is unavailable rather than wrong.
    local platform = self.Platform
    if not platform:CanReadValue(unit) or (unit ~= 'player' and unit ~= 'pet') then return end
    if not platform:CanReadValue(spellid) or type(spellid) ~= 'number' then spellid = false end
    recordSpellCast(self, spellid)
end)

-- These cast outcomes only drive announcements.
addon.UNIT_SPELLCAST_INTERRUPTED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_FAILED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_DELAYED = wrapCombatEvent(spellcast)

-- A channel began: runs announcements and marks the player as channeling.
addon.UNIT_SPELLCAST_CHANNEL_START = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)

    if unit == 'player' then
        currentChannel = true
    end
end)

-- A channel ended: runs announcements, forgets the channel's cast target and resets the swing timers.
addon.UNIT_SPELLCAST_CHANNEL_STOP = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)

    if unit == 'player' then
        if currentChannel ~= nil then
            currentSpells[currentChannel] = nil
        end

        currentChannel = nil
        self.lastMainSwing = nil
        self.lastOffSwing = nil
    end
end)

-- Remembers whom the player's cast was aimed at, by cast GUID and by spell, for the {{target}} announcement text.
addon.UNIT_SPELLCAST_SENT = wrapCombatEvent(function(_, _, unit, target, castguid, spellid)
    if (unit == 'player') then
        currentSpells[castguid] = target
        lastCastTarget[spellid] = target
    end
end)

-- ============================================================================
-- Combat log and data-load events
-- ============================================================================

-- This runs for every combat log line in range. Only the player's own swings
-- and, while a damage history reader exists, damage and heal amounts matter;
-- everything else returns before any string work.
local function handle_combat_log(_, event, _, sourceGUID, _, _, _, destGUID, _, _, _, ...)
    if sourceGUID == playerGUID then
        if event == "SWING_DAMAGE" then
            if select(10, ...) then
                addon.lastOffSwing = GetTime()
            else
                addon.lastMainSwing = GetTime()
            end
        elseif event == "SWING_MISSED" then
            if select(2, ...) then
                addon.lastOffSwing = GetTime()
            else
                addon.lastMainSwing = GetTime()
            end
        elseif event == "RANGE_DAMAGE" or event == "RANGE_MISSED" then
            -- Auto Shot and wand shots, the ranged spells that repeat on their
            -- own (RANGED_SWING_REMAIN). Throw and other single ranged casts
            -- do not start the timer.
            local spellId = ...

            if spellId == 75 or addon.Platform:IsAutoRepeatActive(spellId) == true then
                addon.lastRangedShot = GetTime()
            end
        end
    end

    local wanted = addon.historyWanted
    if wanted and GetTime() > wanted.damage then return end

    local kind = event:sub(-5) == "_HEAL" and "heals" or event:sub(-7) == "_DAMAGE" and "damage"
    if not kind then return end
    local prefix = event:match("^[^_]+")
    local offs = (prefix == "SPELL" or prefix == "RANGE") and 4 or prefix == "ENVIRONMENTAL" and 2 or 1
    local entry = addon.damageHistory[destGUID]

    if not entry then
        entry = { damage = {}, heals = {} }
        addon.damageHistory[destGUID] = entry
    end

    table.insert(entry[kind], 1, {
        time = GetTime(),
        value = tonumber((select(offs, ...))),
    })
end

-- Classic reads the payload from C_CombatLog; its CombatLogGetCurrentEventInfo
-- exists only while loadDeprecationFallbacks is on. Retail and Forever never
-- dispatch this handler (their payload is secure-only).
addon.COMBAT_LOG_EVENT_UNFILTERED = wrapCombatEvent(function()
    local read = type(C_CombatLog) == 'table' and C_CombatLog.GetCurrentEventInfo or nil
    if type(read) ~= 'function' then read = CombatLogGetCurrentEventInfo end
    handle_combat_log(read())
end)

-- Spell data finished loading: refresh that spell's catalog entry.
addon.SPELL_DATA_LOAD_RESULT = wrapEvent(function(_, _, spellId, success)
    if success then
        addon.SpellCatalog:UpdateSpell(spellId)
    end
end)

-- Item data finished loading: refresh the cached reference item.
addon.ITEM_DATA_LOAD_RESULT = wrapEvent(function(_, _, itemId, success)
    if success then
        addon:UpdateReferenceItem(itemId)
    end
end)

-- ============================================================================
-- Diagnostics handoff
-- ============================================================================

-- Gives the optional CPU sampler (Diagnostics/cpu.lua) the poll function to attribute work to, and a reader for
-- UpdateUnitInfo.
-- BEGIN CPU RUNTIME WORK HANDOFF
do
    local bind = addon.BindCPURuntimeWorkDiagnostic

    if type(bind) == 'function' then
        bind(addon, 'main', addon.EvaluateNextActionInternal, function() return UpdateUnitInfo end)
    end
end
-- END CPU RUNTIME WORK HANDOFF
