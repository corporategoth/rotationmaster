-- QA only: exact lifecycle successors to complete6e preimages; unknown bytes pass unchanged.
local rows = {
    ["main.lua"] = {
        before = [========[local addon_name, addon = ...
-- Capture the compatibility override once. Managed rotations use the prepared
-- executor; unsupported/custom sources retain the eager compatibility path.
local preparedRuntimeEnabled = addon.preparedRuntimeEnabled ~= false
local publicationRawget,publicationType,publicationMetatable=rawget,type,getmetatable
addon.BindRotationExecutionGeneration=nil
-- BEGIN ANALYTICS ADVICE HANDOFF
local adviceCapture
if addon.BindAnalyticsAdviceCapture then
 addon:BindAnalyticsAdviceCapture(function(sink)adviceCapture=sink end)
end
-- END ANALYTICS ADVICE HANDOFF
-- BEGIN SWITCH UNIT HANDOFF
local switchConditionEvaluator
local consumeSwitch=addon.ConsumeSwitchConditionEvaluator
if type(consumeSwitch)=='function'then
    switchConditionEvaluator=consumeSwitch(addon)
    addon.ConsumeSwitchConditionEvaluator=nil
end
local function switchConditionMatches(value,current)
    if switchConditionEvaluator then return switchConditionEvaluator(addon,value,current)end
    return addon:evaluateCondition(value)
end
-- END SWITCH UNIT HANDOFF
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local advanceActiveSpec=addon.AdvanceActiveRotationSpecialization
local retireActive=addon.RetireActiveRotationTransition
local commitActive=addon.CommitActiveRotationTransition
local cleanupActive=addon.GetActiveRotationCleanupSelection
local prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local invalidateChoiceDependencies=addon.InvalidateRotationDependencies
local consumeChoices=addon.ConsumeRotationChoiceSelection
if type(consumeChoices)=='function' then
    prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh=consumeChoices(addon)
    addon.ConsumeRotationChoiceSelection=nil
end
-- BEGIN EQUIPMENT EVENT LIFETIME
local equipmentSubscription
local equipmentCoordinator=addon.GetScopedRotationCoordinator
-- END EQUIPMENT EVENT LIFETIME
local function activeChangeCurrent(self,token)
    return type(activeCurrent)=='function' and activeCurrent(self,token)
end
local function activeCall(self,token,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=self[name]
    if not activeChangeCurrent(self,token) then return false end
    method(self,...)
    return activeChangeCurrent(self,token)
end
local function activeValue(self,token,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=self[name]
    if not activeChangeCurrent(self,token) then return false end
    local value=method(self,...)
    return activeChangeCurrent(self,token),value
end
local function activeObjectCall(self,token,object,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=object[name]
    if not activeChangeCurrent(self,token) then return false end
    method(object,...)
    return activeChangeCurrent(self,token)
end
local function activeObjectValue(self,token,object,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=object[name]
    if not activeChangeCurrent(self,token) then return false end
    local value=method(object,...)
    return activeChangeCurrent(self,token),value
end
local function activeBroker(self,token,broker,text)
    if not activeChangeCurrent(self,token) then return false end
    broker.text=text
    return activeChangeCurrent(self,token)
end
-- SavedVariables identity must match the TOC, independent of folder casing.
addon.savedVariableName = "RotationMasterDB"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

_G[addon_name] = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local getCached
local acquireActiveRuntimePlan,registerActiveRuntimeConsumers
local mainEnvironment=getfenv(1)
local consumeActiveRuntimePlan=addon.ConsumeActiveRuntimePlan
if type(consumeActiveRuntimePlan)=='function' then
    acquireActiveRuntimePlan,registerActiveRuntimeConsumers=consumeActiveRuntimePlan(addon)
    addon.ConsumeActiveRuntimePlan=nil
end
local prepareConditionRuntime,retireConditionRuntime,lastConditionSession
local consumeConditionRuntime=addon.ConsumeConditionRuntime
if type(consumeConditionRuntime)=='function' then
    prepareConditionRuntime,retireConditionRuntime=consumeConditionRuntime(addon)
    addon.ConsumeConditionRuntime=nil
end
local acquireEvaluationPass,invalidateEvaluationContext,acquireMainSelectionPass,getMainCleanupBody
local bindEvaluationContext=addon.BindRuntimeEvaluationContext
if type(bindEvaluationContext)=='function' then
    bindEvaluationContext(addon,function(acquire,invalidate,selection,cleanup) acquireEvaluationPass,invalidateEvaluationContext,acquireMainSelectionPass,getMainCleanupBody=acquire,invalidate,selection,cleanup end)
    addon.BindRuntimeEvaluationContext=nil
end
local sequenceRawMethod,sequenceRun,sequenceStatus,ownedSequence
local bindSequence=addon.BindRotationSequenceReader
if type(bindSequence)=="function" then
    bindSequence(addon,function(rawMethod,run,status,source) sequenceRawMethod,sequenceRun,sequenceStatus,ownedSequence=rawMethod,run,status,source end)
    addon.BindRotationSequenceReader=nil
end
local function evaluateSequence(owner,body,evaluate,visit,guard)
    local before=sequenceRawMethod and sequenceRawMethod(owner)
    local method
    if guard then method=before else method=owner.EvaluateRotationSequence end
    if sequenceRun then return sequenceRun(owner,before,method,body,evaluate,visit,guard) end
    if guard then return {status='unavailable',suppressAttack=true}end
    return method(owner,body,evaluate,visit)
end
-- One-time private handoff to the earlier-loaded optional CPU sampler.
local bindCPUStatus=addon.BindCPUExecutionIndexDiagnostic
if type(bindCPUStatus)=="function" then
    bindCPUStatus(addon,function()
        local status=sequenceStatus and sequenceStatus(addon) or {}
        status.main={reason=sequenceRawMethod and sequenceRun and sequenceStatus and "ready" or "unbound"}
        return status
    end)
    addon.BindCPUExecutionIndexDiagnostic=nil
end
local DBIcon = LibStub("LibDBIcon-1.0")
local function spellLink(spellid)
    return addon.Platform:GetSpellLink(spellid) or string.format(L["Unknown spell (%s)"],spellid)
end

local ThreatClassic = LibStub("ThreatClassic-1.0", true)
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    if not UnitThreatSituation and ThreatClassic then
        UnitThreatSituation = function(...) return ThreatClassic:UnitThreatSituation(...) end
    end

    local LibClassicDurations = LibStub("LibClassicDurations")
    LibClassicDurations:Register(addon_name)
elseif ThreatClassic then
    ThreatClassic:Disable()
end

local pairs, color, string = pairs, color, string
local floor = math.floor
local isin, starts_with, isint = addon.Functions.values.isin, addon.Functions.text.starts_with, addon.Functions.values.isint

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
addon.delayed_condition = {}
-- The engine borrows its own validated pass; legacy public getters retain
-- their historical mutable-body contract without becoming the polling path.
local function mainSelectionPass(owner,spec)
    if acquireMainSelectionPass then return acquireMainSelectionPass(owner,spec) end
    return owner:AcquireRotationRuntimePass(spec)
end
local function runtimeRows(owner,spec,candidates)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=mainSelectionPass(owner,spec);if not pass then return {},why end
        return pass:Candidates(candidates==true)
    end
    return owner:GetRuntimeRotations(spec,true,candidates)
end
local function runtimeOne(owner,spec,value)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=mainSelectionPass(owner,spec);if not pass then return nil,why end
        return pass:Get(value)
    end
    return owner:GetRuntimeRotation(spec,value)
end
local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(addon_name,
        { type = "data source", label = addon.pretty_name, icon = addon.logoTexture })

--
-- Initialization
--

BINDING_HEADER_ROTATIONMASTER = addon.pretty_name
BINDING_NAME_ROTATIONMASTER_TOGGLE = string.format(L["Toggle %s " .. color.CYAN .. "/rm toggle" .. color.RESET], addon.pretty_name)

local playerGUID = UnitGUID("player")

local defaults = {
    profile = {
        enable = true,
        poll = 0.15,
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
        rotation_view = "diagram",
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
            yoffs = 0
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
    }
}

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and
   LE_EXPANSION_LEVEL_CURRENT >= 2 then
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
    'ITEM_DATA_LOAD_RESULT'
}

-- These handlers maintain legacy combat observations. Reference-only clients
-- must neither subscribe to them nor process a queued/direct invocation.
local combat_events = {
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_COMBAT",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "COMBAT_LOG_EVENT_UNFILTERED",
}

local mainline_events = {
    'PLAYER_FOCUS_CHANGED',
    'VEHICLE_UPDATE',
    'UNIT_ENTERED_VEHICLE',
    'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED',
    'PLAYER_SPECIALIZATION_CHANGED',
}

local wrath_events = {
    'PLAYER_TALENT_UPDATE',
    -- 'ACTIVE_TALENT_GROUP_CHANGED', # Implied by the above
}

local tbc_events = {
    'PLAYER_FOCUS_CHANGED',
}

local classic_events = {

}

-- Chat, menu and cold restoration share the existing active transition path.
local function chooseManualRotation(self,id,change,remember)
    change=change or beginActive(self)
    if not activeChangeCurrent(self,change) then return nil end
    local body=id and runtimeOne(self,self.currentSpec,id)
    if not activeChangeCurrent(self,change) or id and not body then return nil end
    local ticket
    if remember and prepareChoiceSelection then
        local reference
        if id then
            local available=self.GetScopedRotationCoordinator
            if not activeChangeCurrent(self,change) then return nil end
            local checked,coordinator
            if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return nil end end
            if coordinator then checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,id);if not checked then return nil end end
        end
        if not id or reference then ticket=prepareChoiceSelection(self,reference) end
        if not activeChangeCurrent(self,change) then return nil end
    end
    if ticket and invalidateChoiceDependencies then
        invalidateChoiceDependencies(self,'selection',nil)
        if not activeChangeCurrent(self,change) then return nil end
    end
    self.rotationChoiceSuspended=nil
    if id==nil then
        if ticket then finishChoiceSelection(ticket) end
        self.manualRotation=false
        return self:SwitchRotation()
    end
    local selected=self.currentRotation
    if not activeChangeCurrent(self,change) then return nil end
    if selected~=id then
        if not retireActive(self,change) or not activeChangeCurrent(self,change) then return nil end
        if not activeCall(self,change,'RemoveAllCurrentGlows') then return nil end
        if not commitActive(self,change,self.currentSpec,id,body) or not activeChangeCurrent(self,change) then return nil end
        self.manualRotation=true
        self.skipAnnounce=true;self.avail_announced={};self.announced={}
        if not activeCall(self,change,'EnableRotationTimer') then return nil end
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeBroker(self,change,DataBroker,name) then return nil end
        if not activeObjectCall(self,change,AceEvent,'SendMessage','ROTATIONMASTER_ROTATION',id,name) then return nil end
    else self.manualRotation=true end
    if remember then
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name) then return nil end
        local checked,valid=activeValue(self,change,'rotationValidConditions',body,self.currentSpec)
        if not checked then return nil end
        if not valid and not activeCall(self,change,'warn',L["Active rotation is incomplete and may not work correctly!"]) then return nil end
        if ticket then finishChoiceSelection(ticket) end
    end
    return true,change
end

local function restoreManualChoice(self)
    if choiceNeedsRefresh and choiceNeedsRefresh(self) then
        local change=beginActive(self)
        if not activeChangeCurrent(self,change) then return true end
        local desired,changed=readDesiredChoice(self)
        if not activeChangeCurrent(self,change) then return true end
        if self.adviceErrorReport or self.initializationErrorReport then return true end
        if changed then
            local wasManual=self.manualRotation
            if not activeChangeCurrent(self,change) then return true end
            self.rotationChoiceSuspended=nil
            self.manualRotation=false
            if desired then
                local available=self.GetScopedRotationCoordinator
                if not activeChangeCurrent(self,change) then return true end
                local checked,coordinator,reference,key
                if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return true end end
                if coordinator then
                    checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,desired)
                    if not checked then return true end
                    if reference then checked,key=activeObjectValue(self,change,coordinator,'Key',reference);if not checked then return true end end
                end
                if not activeChangeCurrent(self,change) then return true end
                if reference and chooseManualRotation(self,key,change,false) then return true,change end
                if not activeChangeCurrent(self,change) then return true end
                self.rotationChoiceSuspended=true
            end
            if wasManual and self.currentRotation then
                local disable=self.DisableRotation
                if not activeChangeCurrent(self,change) then return true end
                local _,nextChange,stopped=disable(self)
                if stopped==false then return true end
                change=nextChange or change
                if not activeChangeCurrent(self,change) then return true end
            end
        end
        return false,change
    end
    return false
end

function addon:HandleCommand(str)
    local cmd, npos = AceConsole:GetArgs(str, 1, 1)
    if self.initializationErrorReport and cmd and cmd~="errors" and cmd~="help" then
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
        addon:print(L["                          Manual choices are remembered for this character, specialization and action context."])
        addon:print(L["/rm check               - Check the database integrity."])
        addon:print(L["/rm repair              - Fix any DB errors found in the data with internal validation."])
        addon:print(L["/rm errors              - View and copy Rotation Master errors."])
        addon:print(L['/rm editorinfo          - Copy native Lua input diagnostics.'])
        addon:print(L['/rm editorarrows        - Temporarily test native arrows in an open editor.'])
        addon:print(L['/rm cpu [start|report|cancel] - Capture and inspect CPU costs.'])

    elseif cmd == "config" then
        self:ShowConfig("Rotations")

    elseif cmd == "errors" then
        self:ShowErrors()

    elseif cmd == 'editorinfo' then
        self:ShowLuaEditorInputReport()

    elseif cmd == 'editorarrows' then
        self:ShowLuaEditorArrowProbe()

    elseif cmd == 'cpu' then
        self:RunCPUProfileAction(AceConsole:GetArgs(str,1,npos))

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
            addon:print(L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO], addon:GetRotationName(self.currentRotation))
        end

    elseif cmd == "set" then
        local change=beginActive(self)
        local name = string.sub(str, npos)
        if not activeChangeCurrent(self,change) then return end

        if name=="auto" then
            chooseManualRotation(self,nil,change,true)
        elseif name==self.currentRotation or name==DEFAULT then
            if not chooseManualRotation(self,name,change,true) and activeChangeCurrent(self,change) and name==DEFAULT then
                self:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.'])
            end
        else
            local matches={}
            for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]=id end end
            if not activeChangeCurrent(self,change) then return end
            if #matches>1 then self:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
            if #matches==1 then chooseManualRotation(self,matches[1],change,true);return end
            self:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."],name)
        end
    elseif cmd == "check" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, false)
    elseif cmd == "repair" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, true)
    else
        addon:warn(L["Invalid option " .. color.WHITE .. "%s" .. color.WARN], cmd)
    end
end

-- One optional-provider lifetime, independent of the rotation event owner.
-- Settings only publish saved preferences through SyncQuestieIntegration.
local questieService,questieEvents,questieEnabled
function addon:InitializeQuestieIntegration()
    if questieService then return end
    local factory=self.Integrations and self.Integrations.NewQuestie
    if type(factory)~='function' then return end
    questieService=factory()
    self:SyncQuestieIntegration()
end
function addon:SyncQuestieIntegration()
    if not questieService then return false end
    local enabled=self.db and self.db.profile and self.db.profile.questie_enabled==true or false
    if enabled==questieEnabled then return true end
    questieEnabled=enabled
    if enabled then
        if not questieEvents then
            questieEvents=CreateFrame('Frame')
            questieEvents:SetScript('OnEvent',function(_,event,name)
                if event=='ADDON_LOADED' and name=='Questie' and questieEnabled then questieService:Refresh() end
            end)
        end
        questieEvents:RegisterEvent('ADDON_LOADED')
    elseif questieEvents then questieEvents:UnregisterEvent('ADDON_LOADED') end
    questieService:SetEnabled(enabled)
    return true
end
function addon:GetQuestieIntegrationStatus()
    if questieService then return questieService:GetStatus() end
    return {state='unavailable',reason='adapter-unavailable',nativeAcceptance='unverified'}
end
function addon:RefreshQuestieIntegration()
    if questieService and questieEnabled then return questieService:Refresh() end
    return self:GetQuestieIntegrationStatus()
end

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
        defaults.profile.rotations=nil;defaults.profile.rotationLibrary=nil
    end
    self.db = LibStub("AceDB-3.0"):New(self.savedVariableName, defaults, true)
    -- BEGIN CACHE DIAGNOSTIC INITIALIZATION
    if type(self.InitializeCacheDiagnosticMode)=="function" then
        self:InitializeCacheDiagnosticMode(self.db.global)
    end
    -- END CACHE DIAGNOSTIC INITIALIZATION

    for ext_addon,conditions in pairs(self.delayed_condition) do
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
    self.rotationChoiceSuspended=nil

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
    self.damageHistory = {}
    self.lastMainSwing = nil
    self.lastOffSwing = nil

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

    self.evaluationProfile = addon:ProfiledCode()

    self.currentSpell = nil
    self.nextWindow = nil
    if self.InstallRotationProfileLifecycle then self:InstallRotationProfileLifecycle() end

    -- This is here because of order of loading.
    getCached = addon.Functions.cache.getCached

    self:InitializeQuestieIntegration()

    --self:SetupOptions()
end

function addon:OnInitialize()
    -- A failed initializer must not be followed by OnEnable or gameplay events
    -- using half-built state. Diagnostics stays independent of the database.
    self.initializationErrorReport=0
    local ok,reportId
    if self.Diagnostics then
        ok,reportId=self.Diagnostics:Call({module="startup",operation="initialization"},self.OnInitializeInternal,self)
    else self:OnInitializeInternal();ok=true end
    if ok then self.initializationErrorReport=nil;self.adviceErrorReport=nil
    else self.initializationErrorReport=reportId or 0;self.adviceErrorReport=reportId or 0 end
    return ok,reportId
end

function addon:GetRotationName(id)
    if id == DEFAULT then
        return DEFAULT
    else
        local body=runtimeOne(self,self.currentSpec,id)
        return body and body.name or nil
    end
end

local function minimapToggleRotation(_, _, _, checked)
    if checked then
        addon:enable()
    else
        addon:disable()
    end
end

local function minimapChangeRotation(_,arg1)
    chooseManualRotation(addon,arg1,nil,true)
end

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
    info.text, info.arg1, info.checked = DEFAULT, DEFAULT, (addon.manualRotation == true and addon.currentRotation == DEFAULT)
    UIDropDownMenu_AddButton(info)
    do
        for id, rot in pairs(runtimeRows(addon,addon.currentSpec)) do
            if id ~= DEFAULT then
                info.text, info.arg1, info.checked = rot.name, id, (addon.manualRotation == true and addon.currentRotation == id)
                if addon:IsDefaultRuntimeRotation(addon.currentSpec,id) then info.text="|cff5bc0eb"..rot.name.."|r ("..L["Built In · read-only"]..")" end
                UIDropDownMenu_AddButton(info)
            end
        end
    end
end

function DataBroker.OnClick(_, button)
    if addon.initializationErrorReport then addon:ShowErrors();return end
    if button == "RightButton" then
        local frame = CreateFrame("Frame", addon_name .. "LDBFrame")
        local dropdownFrame = CreateFrame("Frame", addon_name .. "LDBDropdownFrame", frame, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        local shell=addon.configWindow
        if shell and shell.frame:IsShown() then shell:Hide() else addon:ShowConfig("Rotations") end
    end
end

function DataBroker.OnTooltipShow(GameTooltip)
    GameTooltip:SetText(addon.pretty_name .. " " .. GetAddOnMetadata(addon_name, "Version"), 0, 1, 1)
    GameTooltip:AddLine(" ")
    if addon.currentRotation ~= nil then
        GameTooltip:AddLine(L["Current Rotation"], 0.55, 0.78, 0.33, 1)
        GameTooltip:AddLine(addon:GetRotationName(addon.currentRotation), 1, 1, 1)
    else
        GameTooltip:AddLine(L["Battle rotation disabled"], 1, 0, 0, 1)
    end
    if addon.rotationChoiceSuspended then
        GameTooltip:AddLine(L['Saved manual choice is unavailable in the current context.'],1,0.8,0.2,true)
    end
end

function addon:toggle()
    if self.currentRotation == nil then
        self:enable()
    else
        self:disable()
    end
end

-- These additional notifications vary by client; leave existing subscriptions
-- alone and require the native event catalogue to confirm each optional name.
local function registerOptionalEvent(owner,change,event)
    if not activeChangeCurrent(owner,change) then return false end
    local utils=C_EventUtils
    local validEvent=type(utils)=='table' and utils.IsEventValid
    if not activeChangeCurrent(owner,change) then return false end
    if type(validEvent)~='function' then return activeChangeCurrent(owner,change),false end
    local ok,valid=pcall(validEvent,event)
    if not activeChangeCurrent(owner,change) then return false end
    if ok and valid==true then local current=activeCall(owner,change,'RegisterEvent',event);return current,current end
    return true,false
end

function addon:enable()
    if self.initializationErrorReport then self:ShowErrors();return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT ENABLE LIFETIME
    equipmentSubscription=nil
    local equipmentProfile=self.db.profile
    local equipmentRegistered=false
    -- END EQUIPMENT ENABLE LIFETIME
    for _,v in pairs(events) do
        if not activeCall(self,change,'RegisterEvent',v) then return end
    end
    local client=self.Platform:GetClientInfo()
    if not activeChangeCurrent(self,change) then return end
    if client.combatDataPolicy=='probe' then
        for _,event in ipairs(combat_events) do if not activeCall(self,change,'RegisterEvent',event) then return end end
    end
    local family=client.family
    local extraEvents=family=="retail" or family=="forever"
    extraEvents=extraEvents and mainline_events or family=="progression" and wrath_events
        or family=="tbc" and tbc_events or family=="era" and classic_events or {}
    for _,event in ipairs(extraEvents) do if not activeCall(self,change,'RegisterEvent',event) then return end end

    if not registerOptionalEvent(self,change,'UNIT_EXITED_VEHICLE') then return end
    if family=='tbc' then
        if not registerOptionalEvent(self,change,'PLAYER_TALENT_UPDATE') then return end
        if not registerOptionalEvent(self,change,'ACTIVE_TALENT_GROUP_CHANGED') then return end
        -- BEGIN EQUIPMENT EVENT REGISTRATION
        local current,registered=registerOptionalEvent(self,change,'PLAYER_EQUIPMENT_CHANGED')
        if not current then return end
        equipmentRegistered=registered
        -- END EQUIPMENT EVENT REGISTRATION
    end

    if self.RefreshPreviewWindow then
        if not activeCall(self,change,'RefreshPreviewWindow') then return end
    end
    if not activeChangeCurrent(self,change) then return end
    local update=self.UpdateSkill
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=update(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT ENABLE COMMIT
    if not activeCall(self,change,'EnableRotation') then return end
    if equipmentRegistered and self.db.profile==equipmentProfile and activeChangeCurrent(self,change) then
        equipmentSubscription={}
    end
    -- END EQUIPMENT ENABLE COMMIT
end

function addon:disable()
    if self.initializationErrorReport then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT DISABLE LIFETIME
    equipmentSubscription=nil
    -- END EQUIPMENT DISABLE LIFETIME
    local disable=self.DisableRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange,stopped=disable(self);change=nextChange or change
    if stopped==false or not activeChangeCurrent(self,change) then return end
    local available=self.nextWindow
    if not activeChangeCurrent(self,change) then return end
    if available then
        local spells=self.db.profile.preview_spells
        local window=self.nextWindow
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,window,'Release') then return end
        self.nextWindow=nil
        self.db.profile.preview_spells=spells
    end
    self.spellHistory={}
    self.combatHistory={}
    if not activeCall(self,change,'UnregisterAllEvents') then return end
end

function addon:OnEnable()
    if self.initializationErrorReport then return end
    self:info(L["Starting up version %s"], GetAddOnMetadata(addon_name, "Version"))

    if self.db.profile.live_config_update and not self.conditionEvalTimer then
        self.conditionEvalTimer = self:ScheduleRepeatingTimer('UpdateCurrentCondition', self.db.profile.live_config_update)
    end

    if self.db.profile.enable then
        self:enable()
    end
end

function addon:rotationValidConditions(rot,spec)
    if type(rot)~='table' or not self.RotationData.GetRotationPriority(rot.priority) then return false end
    local tree=self.RotationData.IndexRotationSteps(rot,{allowMissingIds=true})
    if not tree then return false end
    local itemsets,global_itemsets=self.db.profile.itemsets,self.db.global.itemsets
    local itemfound=false
    for _,row in ipairs(tree.rows) do
        local step=row.step
        if not row.unreachable and not step.disabled then
            if step.type=="branch" then
                if (step.mode==nil or step.mode=="evaluate") and not self:validateCondition(step.conditions,spec) then return false end
            else
                if step.type==nil or not self:validateCondition(step.conditions,spec) then return false end
                if step.type~="none" and step.action==nil then return false end
                if step.type=="item" then
                    if type(step.action)=="string" then
                        local itemset=itemsets[step.action] or global_itemsets[step.action]
                        if not itemset or type(itemset.items)~="table" or #itemset.items==0 then return false end
                    elseif type(step.action)~="table" or #step.action==0 then return false end
                end
            end
            itemfound=true
        end
    end
    return itemfound
end

function addon:UpdateAutoSwitch()
    local rotations=runtimeRows(self,self.currentSpec,true)
    self.autoswitchRotation=self:GetOrderedAutoSwitchRotations(self.currentSpec,rotations)

    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figure out which of the autoswitch rotations best matches
function addon:SwitchRotation()
    local handled,restoredChange=restoreManualChoice(self)
    if handled then return nil,restoredChange end
    if self.db.profile.disable_autoswitch or self.manualRotation then
        if restoredChange and not activeChangeCurrent(self,restoredChange) then return end
        return nil,restoredChange
    end

    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    local newRotation
    local selectedSpec,selectedProfile,selectedRotation=self.currentSpec,self.db.profile,self.currentRotation
    local selectionPass,rotations
    if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
        selectionPass=mainSelectionPass(self,selectedSpec);if not selectionPass then return end
        local why;rotations,why=selectionPass:Candidates(false);if why then return end
    else rotations=runtimeRows(self,selectedSpec) end
    -- BEGIN SWITCH OWNER LEASE
    local function switchOwnerCurrent()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
            and self.currentRotation==selectedRotation and not self.db.profile.disable_autoswitch and not self.manualRotation
    end
    -- END SWITCH OWNER LEASE
    local function current()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile and self.currentRotation==selectedRotation
            and not self.db.profile.disable_autoswitch and not self.manualRotation and (not selectionPass or selectionPass:IsCurrent())
    end
    for _, v in ipairs(self.autoswitchRotation) do
        if not switchOwnerCurrent()then return end
        -- A packaged recommendation must not displace the user's saved fallback.
        if self:IsDefaultRuntimeRotation(self.currentSpec,v) and rotations[DEFAULT]
            and self:rotationValidConditions(rotations[DEFAULT],self.currentSpec) then
            newRotation=DEFAULT
            break
        end
        local matched=rotations[v] and switchConditionMatches(rotations[v].switch,switchOwnerCurrent)
        if not switchOwnerCurrent()then return end
        if matched then
            newRotation = v
            break
        end
    end
    if not newRotation and rotations[DEFAULT] ~= nil and
        self:rotationValidConditions(rotations[DEFAULT], self.currentSpec) then
        newRotation = DEFAULT
    end
    if not current() then return end

    if newRotation then
        if self.currentRotation ~= newRotation then
            local name=newRotation==DEFAULT and DEFAULT or rotations[newRotation].name
            if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
            selectedRotation=nil
            if not activeCall(self,change,'RemoveAllCurrentGlows') or not current() then return end
            if not commitActive(self,change,selectedSpec,newRotation,rotations[newRotation]) or not activeChangeCurrent(self,change) then return end
            selectedRotation=newRotation
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            if not activeCall(self,change,'EnableRotationTimer') or not current() then return end
            if not activeBroker(addon,change,DataBroker,name) then return end
            if not current() then return end
            if not activeCall(self,change,'info',L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO],name) then return end
            if not current() then return end
            if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,name) then return end
        end
        return nil,change
    end

    -- Could not find a rotation to switch to, even the default one.
    if self.currentRotation ~= nil then
        addon:warn(L["No rotation is active as there is none suitable to automatically switch to."])
        if not current() then return end
        self:DisableRotation()
    end
end

function addon:EnableRotation()
    if self.currentSpec==nil or self.currentRotation then return end
    local change=beginActive(self)
    if not activeCall(self,change,'Fetch') then return end
    if not activeCall(self,change,'UpdateAutoSwitch') then return end
    local method=self.SwitchRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=method(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    if self.currentRotation~=nil then
        local getName=self.GetRotationName
        if not activeChangeCurrent(self,change) then return end
        local name=getName(self,self.currentRotation)
        if not activeChangeCurrent(self,change) then return end
        if not activeBroker(self,change,DataBroker,name) then return end
        activeCall(self,change,'info',L["Battle rotation enabled"])
    end
end

function addon:DisableRotation()
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    -- BEGIN ANALYTICS DISABLE
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return nil,nil,false end
    end
    -- END ANALYTICS DISABLE
    local selected=self.currentRotation
    if not retireActive(self,change) or not activeChangeCurrent(self,change) then return nil,nil,false end
    if retireConditionRuntime then
        local previous=lastConditionSession
        retireConditionRuntime(self)
        if lastConditionSession==previous then lastConditionSession=nil end
        if not activeChangeCurrent(self,change) then return nil,nil,false end
    end
    if not selected then return nil,change,true end
    self.currentSpell = nil
    self.avail_announced = {}
    self.announced = {}
    if not activeCall(self,change,'DisableRotationTimer') then return nil,nil,false end
    if not activeCall(self,change,'RemoveAllCurrentGlows') then return nil,nil,false end
    if not activeCall(self,change,'DestroyAllGlows') then return nil,nil,false end
    local availableWindow=self.nextWindow
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if availableWindow then
        local window=self.nextWindow
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,window,'ReleaseChildren') then return nil,nil,false end
    end
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if not activeBroker(self,change,DataBroker,color.RED .. OFF) then return nil,nil,false end
    if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",nil) then return nil,nil,false end
    if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_SPELL_UPDATE",nil,nil) then return nil,nil,false end
    local weak=_G.WeakAuras
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if weak then
        local available=weak.ScanEvents
        if not activeChangeCurrent(self,change) then return nil,nil,false end
        if available then
            local scan=weak.ScanEvents
            if not activeChangeCurrent(self,change) then return nil,nil,false end
            scan("ROTATIONMASTER_SPELL_UPDATE",nil,nil)
        end
    end
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if not activeCall(self,change,'info',L["Battle rotation disabled"]) then return nil,nil,false end
    return nil,change,true
end

function addon:EnableRotationTimer()
    if self.adviceErrorReport then return end
    if self.currentRotation and not self.rotationTimer then
        self.rotationTimer = self:ScheduleRepeatingTimer('EvaluateNextAction', self.db.profile.poll)
    end
end

function addon:DisableRotationTimer()
    if self.rotationTimer then
        self:CancelTimer(self.rotationTimer)
        self.rotationTimer = nil
    end
end

function addon:ButtonFetch()
    if self.fetchTimer then
        self:CancelTimer(self.fetchTimer)
    end
    self.fetchTimer = self:ScheduleTimer(function()
        self.skipAnnounce = true
        self:Fetch()
    end, 0.25)
end

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

function addon:StopAdviceForError(reportId)
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN ANALYTICS ERROR
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return end
    end
    -- END ANALYTICS ERROR
    self.adviceErrorReport = reportId
    if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
    self.currentSpell = nil
    self.avail_announced = {}
    local timer = self.rotationTimer
    self.rotationTimer = nil
    local function cleanup(operation, callback, ...)
        if not activeChangeCurrent(self,change) then return false end
        local diagnostics=self.Diagnostics
        local method=diagnostics.Call
        if not activeChangeCurrent(self,change) then return false end
        method(diagnostics,{module="recommendations",operation=operation},callback,...)
        return activeChangeCurrent(self,change)
    end
    if timer and not cleanup("cancel-timer", self.CancelTimer, self, timer) then return end
    if self.nextWindow and not cleanup("hide-preview", self.nextWindow.Hide, self.nextWindow) then return end
    if not cleanup("clear-glows", self.RemoveAllCurrentGlows, self) then return end
    if not cleanup("destroy-glows", self.DestroyAllGlows, self) then return end
    if not cleanup("broker-disabled", function() activeBroker(self,change,DataBroker,color.RED .. OFF) end) then return end
    if not cleanup("rotation-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_ROTATION", nil) then return end
    if not cleanup("suggestion-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_SPELL_UPDATE", nil, nil) then return end
    if WeakAuras and WeakAuras.ScanEvents then
        cleanup("weak-aura-cleared", WeakAuras.ScanEvents, "ROTATIONMASTER_SPELL_UPDATE", nil, nil)
    end
end

function addon:EvaluateNextAction()
    if self.initializationErrorReport then return end
    if not self.Diagnostics then return self:EvaluateNextActionInternal() end
    if self.adviceErrorReport then return end
    local ok, reportId = self.Diagnostics:Call({module="recommendations", operation="timer",
        rotationId=self.currentRotation}, self.EvaluateNextActionInternal, self)
    if not ok then self:StopAdviceForError(reportId) end
end

function addon:EvaluateNextActionInternal()
    local selectedRotation,selectedSpec,selectedProfile=self.currentRotation,self.currentSpec,self.db.profile
    local runtimePass,rot,publicationGuard,planToken,conditionSession,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease
    local executionFailed=false
    local function dispatchCurrent(kind)
        if executionFailed then return false end
        if not dispatchLease then return true end
        if dispatchLease(kind)then return true end
        executionFailed=true
        return false
    end
    if preparedRuntimeEnabled and selectedRotation~=nil and acquireActiveRuntimePlan and prepareConditionRuntime then
        rot,publicationGuard,planToken,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease=acquireActiveRuntimePlan(self,selectedSpec,selectedRotation)
        if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile then return end
        if handled then
            if not publicationGuard then return end
            if dispatchLease then
                if not dispatchCurrent('resume')then return end
            elseif not publicationGuard()then return end
            if rot then
                conditionSession=prepareConditionRuntime(self,rot,planToken,notifiedLease or conditionLease or publicationGuard,publicationGuard,dispatchLease and dispatchCurrent)
                if executionFailed then return end
                -- Owned preparation certifies its producers and invocation.
                -- Rejected preparation can return before that boundary, so
                -- the ordinary fallback still needs the full source fence.
                if conditionSession and notifiedLease then
                    if not notifiedLease()then return end
                elseif not publicationGuard() then return end
                lastConditionSession=conditionSession
                -- Custom or unsupported trees retain the existing execution
                -- input and callback route; private plan data never escapes.
                if not conditionSession then
                    runtimePass,rot,publicationGuard,planToken,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease=nil,nil,nil,nil,false,nil,nil,nil,nil,nil
                end
            end
        end
    end
    if selectedRotation~=nil and not handled then
        if retireConditionRuntime then
            local previous=lastConditionSession
            if not retireConditionRuntime(self,previous or false) then return end
            if lastConditionSession==previous then lastConditionSession=nil end
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile then return end
        end
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            if acquireEvaluationPass then local reason;runtimePass,reason,publicationGuard=acquireEvaluationPass(self,selectedSpec)
            else runtimePass=self:AcquireRotationRuntimePass(selectedSpec) end
            if runtimePass then rot=runtimePass:Get(selectedRotation) end
        else rot=self:GetRuntimeRotation(selectedSpec,selectedRotation) end
    end
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
        return
    elseif not rot then
        self.manualRotation=false
        self:DisableRotation()
        return
    else
        self.evaluationProfile:start()
        if self.RefreshMacroButtons then self:RefreshMacroButtons() end

        local now = GetTime()
        local cache = {}
        if not self.inCombat then
            self.combatCache = cache
        end

        self.evaluationProfile:child("environment"):start()

        local unitsHandled, unitsGUID = {}, {}
        for unit, _ in pairs(addon.units) do
            unitsGUID[unit] = getCached(cache, UnitGUID, unit)
        end
        for guid, entity in pairs(self.unitsInRange) do
            if isin(addon.units, entity.unit) then
		        if unitsGUID[entity.unit] and unitsGUID[entity.unit] == guid then
                    unitsHandled[entity.unit] = true
                else
                    self.unitsInRange[guid] = nil
                end
            end

            addon:verbose("Updating Unit " .. guid .. " (" .. entity.name .. ")")
            UpdateUnitInfo(cache, entity)
        end
        for unit, guid in pairs(unitsGUID) do
            if not unitsHandled[unit] and not self.unitsInRange[guid] and
                not starts_with(unit, "mouseover") then
                self.unitsInRange[guid] = CreateUnitInfo(cache, unit)
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
        for _,history in pairs(self.combatHistory) do
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

        local actionReady=self:NewActionReadiness(now)
        -- Preparation can call public providers. Check the compiled graph's
        -- source authority once here, before any cached condition is reused.
        if conditionSession and not conditionSession:AfterOpaque() then
            self.evaluationProfile:stop()
            return
        end
        local function eval(cond)
            local firstMapped,firstItem
            local matches
            if cond.action~=nil and not cond.disabled then
                if conditionSession then matches=conditionSession:EvaluateBool(cond.conditions,{stepId=cond.id})
                else matches=addon:evaluateCondition(cond.conditions,{stepId=cond.id}) end
            end
            if matches then
                if not dispatchCurrent('step')then return nil,false end
                local spellids,itemids=addon:GetSpellIds(cond)
                for index,id in ipairs(spellids or {}) do
                    local itemId=itemids and itemids[index]
                    local mapped=addon:FindSpell({id},cond.type=="item" and {itemId} or nil)
                    if mapped then
                        if not firstMapped then firstMapped,firstItem=mapped,itemId end
                        local ready=actionReady(cond.type,id,itemId)
                        if ready then return mapped,true,itemId end
                    end
                end
            end
            return firstMapped,false,firstItem
        end

        self.evaluationProfile:child("rotation"):start()
        local preview,suppressAttack=0,false
        local weakAuras=_G.WeakAuras
        ---@type RMRecommendationPreview
        local previewWindow=self.nextWindow
        local nativePreview=previewWindow and type(previewWindow.AddRecommendation)=="function"
        local staged={}
        local delivering,deliveryFailed=false,false
        local function current()
            if deliveryFailed or executionFailed then return false end
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile
                or self.nextWindow~=previewWindow then return false end
            if delivering and deliveryLease then return deliveryLease()end
            if conditionSession and dispatchLease then return dispatchCurrent('resume')end
            if publicationGuard then return publicationGuard() end
            if not runtimePass then return true end
            return runtimePass:IsCurrent()
        end
        local function stage(callback) staged[#staged+1]=callback end
        if nativePreview then
            stage(function() previewWindow:ReleaseChildren();if current() then previewWindow:PauseLayout() end end)
        end
        local function recommend(spellid,cond,index,itemId)
            preview=preview+1
            local ordinal=preview
            stage(function()
                if ordinal==1 then
                    -- BEGIN ANALYTICS PRIMARY ADVICE
                    if adviceCapture then
                        adviceCapture("advice",previewWindow,current,cond.type,spellid)
                        if not current() then return end
                    end
                    -- END ANALYTICS PRIMARY ADVICE
                    self.currentSpell=spellid
                    if not addon:IsGlowing(spellid,itemId) then
                        if not current() then return end
                        if not self.db.profile.disable_buttons then addon:GlowNextSpell(spellid,itemId) end
                        if not current() then return end
                        if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",cond.type,spellid) end
                        if not current() then return end
                        AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,index,cond.id,cond.type,spellid)
                    end
                end
                if not current() then return end
                if nativePreview then previewWindow:AddRecommendation(spellid,itemId) end
            end)
        end
        local sequence=evaluateSequence(self,rot,function(condition,context)
            if conditionSession then return conditionSession:EvaluateResult(condition,context) end
            return addon:evaluateConditionResult(condition,context)
        end,function(cond,index)
            local spellid,enabled,itemId=eval(cond)
            if not dispatchCurrent('resume')then return false end
            if enabled then
                recommend(spellid,cond,index,itemId)
                if not nativePreview or preview>=self.db.profile.preview_spells then return false end
            end
            return true
        end,conditionSession and dispatchLease and dispatchCurrent or nil)
        if executionFailed then self.evaluationProfile:stop();return end
        suppressAttack=sequence.suppressAttack
        if preview==0 and not suppressAttack and self.Platform:IsMeleeAttackNeeded("target")==true and actionReady("spell",6603) then
            local attack=addon:FindSpell({6603})
            if attack then recommend(attack,{id="RM-IMPLICIT:ATTACK",type="spell"},sequence.fallbackOrdinal or #(rot.rotation or {})+1) end
        end
        if preview==0 then
            stage(function()
                -- BEGIN ANALYTICS EMPTY ADVICE
                if adviceCapture then adviceCapture("retire");if not current() then return end end
                -- END ANALYTICS EMPTY ADVICE
                self.currentSpell=nil
                if not self.db.profile.disable_buttons then addon:GlowClear() end
                if not current() then return end
                if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",nil,nil) end
                if not current() then return end
                AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,nil)
            end)
        end
        if nativePreview then
            stage(function() previewWindow:ResumeLayout();if current() then previewWindow:DoLayout() end end)
        end

        self.evaluationProfile:child("rotation"):stop()
        self.evaluationProfile:child("cooldowns"):start()
        if rot.cooldowns ~= nil then
            local observations={}
            if not dispatchCurrent('iterator')then self.evaluationProfile:stop();return end
            for id,cond in pairs(rot.cooldowns) do
                local spellid,enabled,itemId=eval(cond)
                if not dispatchCurrent('resume')then self.evaluationProfile:stop();return end
                observations[#observations+1]={id=id,condition=cond,spellid=spellid,enabled=enabled,itemId=itemId}
            end
            stage(function()
                local enabled_cooldowns = {}
                local enabled_items = {}
                local disabled_cooldowns = {}
                for _,observation in ipairs(observations) do
                    -- A missing observation with no prior announcement has no
                    -- publication side effect. Decide at delivery, after the
                    -- earlier publishers, and retain ordinary accessor dispatch.
                    local announced=publicationRawget(addon,'avail_announced')
                    local inactive=conditionSession and observation.spellid==nil
                        and publicationType(announced)=='table' and publicationMetatable(announced)==nil
                        and publicationRawget(announced,observation.condition.id)==nil
                    if not inactive then
                        if not current() then return end
                        local id,cond=observation.id,observation.condition
                        local spellid,enabled,itemId=observation.spellid,observation.enabled,observation.itemId
                        local previous=addon.avail_announced[cond.id]
                        if previous and (previous~=spellid or not enabled) and not enabled_cooldowns[previous] then
                            disabled_cooldowns[previous]=cond
                        end
                        if spellid then
                            if enabled then
                                addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)
                                if addon.avail_announced[cond.id] ~= spellid then
                                    if not addon.skipAnnounce then
                                        local link = spellLink(spellid)
                                        if delivering then
                                            local message=string.format(L["%s is now available!"],link)
                                            -- This rare receiver still gets a private node.
                                            -- Link/format/log callbacks precede its full fence.
                                            if publicationGuard and not publicationGuard()then deliveryFailed=true;return end
                                            addon:DispatchAnnouncement(cond,message)
                                        else
                                            addon:DispatchAnnouncement(cond, string.format(L["%s is now available!"], link))
                                        end
                                    end
                                    if not current() then return end
                                    addon.avail_announced[cond.id] = spellid;
                                    AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
                                    if not current() then return end
                                end
                                if not enabled_cooldowns[spellid] then
                                    enabled_cooldowns[spellid] = cond
                                    enabled_items[spellid] = itemId
                                    disabled_cooldowns[spellid] = nil
                                end
                            else
                                if addon.avail_announced[cond.id] then
                                    addon.avail_announced[cond.id] = nil;
                                    AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                                end
                                addon:verbose("Cooldown %d [%s] is disabled", id, cond.id)
                                if not enabled_cooldowns[spellid] then
                                    disabled_cooldowns[spellid] = cond
                                end
                            end
                        else
                            if addon.avail_announced[cond.id] then
                                addon.avail_announced[cond.id] = nil;
                                AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                            end
                        end
                    end
                end
                for spellid, cond in pairs(disabled_cooldowns) do
                    if not current() then return end
                    local style=cond
                    if conditionSession then style=presentationViews and presentationViews[cond];if not style then return end end
                    addon:GlowCooldown(spellid, false, style)
                end
                for spellid, cond in pairs(enabled_cooldowns) do
                    if not current() then return end
                    local style=cond
                    if conditionSession then style=presentationViews and presentationViews[cond];if not style then return end end
                    addon:GlowCooldown(spellid, true, style, enabled_items[spellid])
                end
            end)
        end
        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        stage(function() addon.skipAnnounce=false;addon.announced={} end)

        -- Every condition and readiness callback finishes before advice becomes
        -- externally visible. Recheck between publishers too: another addon's
        -- message/glow callback may retire this profile or selected record.
        -- One final execution-source proof before any staged output. Only the
        -- managed graph's scalar/detached deliveries may then use freshness.
        if conditionSession and deliveryLease then
            if not current()or not publicationGuard or not publicationGuard()or not current()then self.evaluationProfile:stop();return end
            delivering=true
        end
        for _,publish in ipairs(staged) do if not current() then break end;publish() end

        self.evaluationProfile:stop()
    end

    if GetTime() - self.lastCacheReport > 15 then
        addon.Functions.cache.ReportCacheStats(addon)
        addon:debug("%s", self.evaluationProfile:report(self.db.profile.detailed_profiling))
        self.evaluationProfile:reset()
        self.lastCacheReport = GetTime()
    end
end

function addon:UpdateCurrentCondition()
    -- Update the live config config .. just to be nice :)
    if self.currentConditionEval ~= nil then
        self.currentConditionEval()
        addon:debug(L["Notified configuration to update it's status."])
    end
end

function addon:GetSpellIds(rot)
    if rot.action then
        if rot.type == BOOKTYPE_SPELL or rot.type == BOOKTYPE_PET or rot.type == "any" then
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if rot.ranked then
                    return { rot.action }
                else
                    return self.SpellCatalog:GetAllSpellIds(rot.action) or {rot.action}
                end
            else
                return { rot.action }
            end
        elseif rot.type == "item" then
            local spellids,itemids={},{}
            local items=rot.action
            if type(items)=="string" then
                local itemset=self.db.profile.itemsets[items] or self.db.global.itemsets[items]
                items=type(itemset)=="table" and itemset.items or nil
            end
            if type(items)=="table" then
                for _,item in ipairs(items) do
                    local use=self.Platform:GetItemUseSpell(item)
                    local itemid=use and self.Platform:GetItemID(item)
                    -- A spell without its item identity cannot be checked for
                    -- ownership/cooldown. Retry unavailable metadata next poll.
                    if use and itemid then
                        spellids[#spellids+1]=use.spellID
                        itemids[#itemids+1]=itemid
                    end
                end
            end
            return spellids, itemids
        end
    end
    return {}
end
if registerActiveRuntimeConsumers then
    registerActiveRuntimeConsumers(addon,addon.GetSpellIds,ownedSequence,mainEnvironment)
end

function addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot)
    if spec == self.currentSpec and rotation == self.currentRotation then
        for _, spellid in pairs(addon:GetSpellIds(rot)) do
            addon:GlowCooldown(spellid, false)
        end
    end
end

function addon:RemoveAllCurrentGlows()
    local spec,id,change=cleanupActive(self)
    if not id then spec,id=self.currentSpec,self.currentRotation end
    local function current() return not change or activeChangeCurrent(self,change) end
    addon:debug(L["Removing all glows."])
    if not current() then return end
    local rotation
    if id then
        local get=self.GetRotationForCleanup
        if not current() then return end
        if getMainCleanupBody then rotation=getMainCleanupBody(self,spec,id,get)
        else rotation=get(self,spec,id) end
    end
    if not current() then return end
    if rotation and rotation.cooldowns then
        for _,rot in pairs(rotation.cooldowns) do
            if not current() then return end
            local getIDs=addon.GetSpellIds
            if not current() then return end
            local ids=getIDs(addon,rot)
            if not current() then return end
            for _,spellid in pairs(ids) do
                if not current() then return end
                local glow=addon.GlowCooldown
                if not current() then return end
                glow(addon,spellid,false)
                if not current() then return end
            end
        end
    end
    if current() then
        local clear=addon.GlowClear
        if current() then clear(addon) end
    end
end

function addon:UpdateSpecSpells()
    return self:RefreshSpellCatalog()
end

function addon:UpdateSkill()
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    if not activeCall(self,change,'verbose',"Skill update triggered") then return end
    if not activeChangeCurrent(self,change) then return end
    local selection=self.Platform:GetRotationSpecialization()
    local spec=selection and selection.key
    if not activeChangeCurrent(self,change) then return end
    if spec~=self.currentSpec then
        local disable=self.DisableRotation
        if not activeChangeCurrent(self,change) then return end
        local _,nextChange,stopped=disable(self)
        if stopped==false then return end
        change=nextChange or change
        if not activeChangeCurrent(self,change) then return end
        self.manualRotation=false
    end
    change=advanceActiveSpec(self,change,spec)
    if not activeChangeCurrent(self,change) then return end
    self.longtermCache={}
    if invalidateChoiceContext then invalidateChoiceContext(self) end
    if not selection then
        self.autoswitchRotation={}
        return nil,change
    end
    local availableTab=self.specTab
    if not activeChangeCurrent(self,change) then return end
    if availableTab then
        local tab=self.specTab
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,tab,'SelectTab',spec) then return end
    end
    if not activeChangeCurrent(self,change) then return end
    if not activeCall(self,change,'UpdateSpecSpells') then return end
    if not activeCall(self,change,'UpdateAutoSwitch') then return end
    local switch=self.SwitchRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=switch(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    if activeCall(self,change,'ButtonFetch') then return nil,change end
end

function addon:GetSpecTalentName(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].name == nil then
        return string.format(L["[Tier: %d, Column: %d]"], floor((idx - 1) / 3) + 1, ((idx - 1) % 3) + 1)
    end

    return self.specTalents[spec][idx].name
end

function addon:GetSpecTalentIcon(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].icon == nil then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    return self.specTalents[spec][idx].icon
end

function addon:UpdateBoundButton(id)
    if InCombatLockdown and InCombatLockdown() then return false end
    self.updatingBoundButtons=self.updatingBoundButtons or {};if self.updatingBoundButtons[id] then return false end
    self.updatingBoundButtons[id]=true
    local ok,changed=pcall(function()
        local bindings=self.db.char.bindings;local slots=bindings[id];if not slots then return false end
        local itemid=self:FindFirstItemOfItemSet({},id,true);local updated=false
        for index=#slots,1,-1 do local slot=slots[index];local kind,action=GetActionInfo(slot)
            if kind=='item' then
                if itemid and itemid~=action then self:debug('Updated slot %s to new item %d',slot,itemid);PickupItem(itemid);PlaceAction(slot);ClearCursor();updated=true end
            else table.remove(slots,index);updated=true end
        end
        if #slots==0 then bindings[id]=nil end
        if updated then self:ButtonFetch() end;return updated
    end)
    self.updatingBoundButtons[id]=nil;if not ok then error(changed,0) end;return changed
end

-- These notifications may change eligibility facts or their readability. Other
-- event handlers do not invalidate a snapshot of player/session eligibility.
local runtimeContextEvents={PLAYER_LEVEL_UP=true,UNIT_LEVEL=true,PLAYER_ENTERING_WORLD=true,PLAYER_LEAVING_WORLD=true,
    PLAYER_EQUIPMENT_CHANGED=true,
    PLAYER_SPECIALIZATION_CHANGED=true,PLAYER_TALENT_UPDATE=true,ACTIVE_TALENT_GROUP_CHANGED=true,
    CHARACTER_POINTS_CHANGED=true,SPELLS_CHANGED=true,PLAYER_CONTROL_GAINED=true,PLAYER_CONTROL_LOST=true,
    UPDATE_SHAPESHIFT_FORM=true,VEHICLE_UPDATE=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true,
    PLAYER_REGEN_ENABLED=true,PLAYER_REGEN_DISABLED=true}
local function wrapEvent(func)
    local failed = false
    return function(self, event, ...)
        if invalidateEvaluationContext and (event==nil or runtimeContextEvents[event]) then invalidateEvaluationContext() end
        if invalidateChoiceContext and (event==nil or runtimeContextEvents[event]) then invalidateChoiceContext(self) end
        if failed or self.initializationErrorReport then return end
        local function dispatch(...)
            self:debug("Event %s fired.", event)
            return func(self, event, ...)
        end
        if not self.Diagnostics then return dispatch(...) end
        local ok, reportId = self.Diagnostics:Call({module="events", operation="dispatch", event=event,
            rotationId=self.currentRotation}, dispatch, ...)
        if not ok then
            failed = true
            self:StopAdviceForError(reportId)
        end
    end
end

local function wrapCombatEvent(func)
    local dispatch=wrapEvent(func)
    return function(self,...)
        if self.initializationErrorReport or self.Platform:GetClientInfo().combatDataPolicy~='probe' then return end
        return dispatch(self,...)
    end
end

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PARTY_MEMBERS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PLAYER_FLAGS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.UPDATE_SHAPESHIFT_FORM = wrapEvent(function(self)
    local newForm = GetShapeshiftForm()
    if self.currentForm ~= newForm then
        self.currentForm = newForm
        -- self.skipAnnounce = true
        -- We need the delay because multiple shapeshift events come in at once
        -- and there is no way to know which will be the final one.
        if self.shapeshiftTimer == nil then
            self.shapeshiftTimer = self:ScheduleTimer(function ()
                self.shapeshiftTimer = nil
                self:SwitchRotation()
            end, 0.25)
            self:ButtonFetch()
        end
    end
end)
addon.UPDATE_STEALTH = wrapEvent(addon.SwitchRotation)

function addon:UnbindItemSet(id,expectedItems)
    if InCombatLockdown and InCombatLockdown() then return false end
    local slots=self.db.char.bindings[id] or {};self.db.char.bindings[id]=nil
    for _,slot in ipairs(slots) do
        local kind,item=GetActionInfo(slot)
        if kind=='item' and (expectedItems and self:FindItemInItems(expectedItems,item) or self:FindItemInItemSet(id,item)) and type(PickupAction)=='function' and type(ClearCursor)=='function' then PickupAction(slot);ClearCursor() end
    end
    if self.bindingItemSet==id then self.bindingItemSet=nil end
    if self.EndHighlightSlot then self:EndHighlightSlot() end
    self:ButtonFetch()
    if self.itemSetCallback then self.itemSetCallback(id) end
    return true
end
addon.ACTIONBAR_SLOT_CHANGED = wrapEvent(function(self, _, slot)
    local bindings=self.db.char.bindings;self:ButtonFetch()
    -- Slot zero means the client invalidated the whole bar. Reconcile every
    -- tracked slot, never create a binding to the sentinel itself.
    local cursor,item=GetCursorInfo();local pickup;local changed={}
    for id,slots in pairs(bindings) do
        for i=#slots,1,-1 do local old=slots[i]
            if slot==0 or old==slot then
                local kind,action=GetActionInfo(old)
                if kind~='item' or not self:FindItemInItemSet(id,action) then
                    if old==slot and cursor=='item' and self:FindItemInItemSet(id,item) then pickup=id end
                    table.remove(slots,i);changed[id]=true
                end
            end
        end
        if #slots==0 then bindings[id]=nil end
    end
    local pending=self.bindingItemSet;self.bindingItemSet=nil
    if pending and slot>0 then
        local kind,action=GetActionInfo(slot)
        if kind=='item' and self:FindItemInItemSet(pending,action) then
            local slots=bindings[pending] or {};bindings[pending]=slots;local found=false;for _,value in ipairs(slots) do if value==slot then found=true end end;if not found then slots[#slots+1]=slot end;changed[pending]=true
        end
    end
    if pickup then self.bindingItemSet=pickup end
    for id in pairs(changed) do if bindings[id] and self.FindFirstItemOfItemSet then self:UpdateBoundButton(id) end end
    if self.itemSetCallback then for id in pairs(changed) do self.itemSetCallback(id) end end
end)

addon.PET_BAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.PET_BAR_UPDATE = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_PAGE_CHANGED = wrapEvent(addon.ButtonFetch)
addon.UPDATE_MACROS = wrapEvent(addon.ButtonFetch)
addon.VEHICLE_UPDATE = wrapEvent(function(self)
    restoreManualChoice(self)
    self:ButtonFetch()
end)

addon.PLAYER_TARGET_CHANGED = wrapEvent(function(self)
    self:verbose("Player targeted something else.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self.lastMainSwing = nil
    self.lastOffSwing = nil

    self:EvaluateNextAction()
end)

addon.PLAYER_FOCUS_CHANGED = addon.PLAYER_TARGET_CHANGED

addon.UNIT_PET = wrapEvent(function(self, _, unit)
    -- UNIT_PET identifies the pet owner, not the changed pet unit.
    if unit == "player" then
        self:verbose("Player %s changed pet.", unit)
        self:UpdateSpecSpells()

        if not self.inCombat then
            self:SwitchRotation()
        end

        self:EvaluateNextAction()
    end
end)

addon.PLAYER_CONTROL_GAINED = wrapEvent(function(self)
    restoreManualChoice(self)
    self:verbose("Player regained control.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self:EnableRotationTimer()
    self:EvaluateNextAction()
end)

addon.PLAYER_CONTROL_LOST = wrapEvent(function(self)
    self:verbose("Player lost control.")
    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
end)

addon.PLAYER_TALENT_UPDATE = wrapEvent(addon.UpdateSkill)
addon.ACTIVE_TALENT_GROUP_CHANGED = wrapEvent(addon.UpdateSkill)
-- BEGIN EQUIPMENT EVENT DISPATCH
local equipmentEvent = wrapEvent(function(self,_,subscription,profile,change)
    if self~=addon or equipmentSubscription~=subscription or self.db.profile~=profile
        or not activeChangeCurrent(self,change) then return end
    local coordinator
    if self.GetScopedRotationCoordinator~=equipmentCoordinator or not activeChangeCurrent(self,change) then return end
    if equipmentCoordinator then coordinator=equipmentCoordinator(self) end
    local function current()
        if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription
            or self.db.profile~=profile or self.GetScopedRotationCoordinator~=equipmentCoordinator then return false end
        if equipmentCoordinator and equipmentCoordinator(self)~=coordinator then return false end
        return self.db.profile==profile and self.GetScopedRotationCoordinator==equipmentCoordinator
            and activeChangeCurrent(self,change) and equipmentSubscription==subscription
    end
    if not current() or self.enabledState~=true or not current() then return end
    local switch=self.SwitchRotation
    if not current() or type(switch)~='function' then return end
    local _,nextChange=switch(self);change=nextChange or change
    if not current() or self.currentRotation==nil then return end
    local evaluate=self.EvaluateNextAction
    if current() and type(evaluate)=='function' then evaluate(self) end
end)
addon.PLAYER_EQUIPMENT_CHANGED=function(self,event)
    local subscription=equipmentSubscription
    if not rawequal(self,addon) or not subscription or self.enabledState~=true then return end
    local profile=self.db.profile
    if equipmentSubscription~=subscription or type(profile)~='table' then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription or self.db.profile~=profile then return end
    return equipmentEvent(self,event,subscription,profile,change)
end
-- END EQUIPMENT EVENT DISPATCH
addon.SPELLS_CHANGED = wrapEvent(addon.UpdateSkill)
local function invalidatePlayerLevel(self)
    if type(self.longtermCache)~='table' then return end
    self.longtermCache.conditionPlayerLevel=nil
    -- Saved raw condition sources may still use the native cache identity.
    local native=type(UnitLevel)=='function' and self.longtermCache[UnitLevel]
    if type(native)=='table' then native.player=nil end
end

addon.PLAYER_LEVEL_UP = wrapEvent(function(self)
    invalidatePlayerLevel(self)
    -- Level facts can still be old while the event is being dispatched.
    self:ScheduleTimer(function()
        invalidatePlayerLevel(self)
        self:UpdateAutoSwitch()
        self:SwitchRotation()
        if self.currentRotation then self:EvaluateNextAction() end
    end,0.01)
end)
addon.CHARACTER_POINTS_CHANGED = wrapEvent(addon.UpdateSkill)
addon.PLAYER_SPECIALIZATION_CHANGED = wrapEvent(addon.UpdateSkill)

addon.ZONE_CHANGED = wrapEvent(function(self)
    addon:verbose("Player switched zones.")
    if not self.inCombat then
        self:SwitchRotation()
    end
end)

addon.ZONE_CHANGED_INDOORS = addon.ZONE_CHANGED
addon.GROUP_ROSTER_UPDATE = addon.ZONE_CHANGED

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

addon.PLAYER_REGEN_DISABLED = wrapEvent(function(self)
    self:verbose("Player is in combat.")
    self.inCombat = true
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.combatCache = {}
    self.combatStart = GetTime()
end)

addon.PLAYER_REGEN_ENABLED = wrapEvent(function(self)
    self:verbose("Player is out of combat.")
    self.inCombat = false
    self.lastMainSwing = nil
    self.lastOffSwing = nil
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

addon.UNIT_ENTERED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player on a vehicle.")
        self.PLAYER_CONTROL_LOST(self, event)
    end
end)

addon.UNIT_EXITED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player off a vehicle.")
        self.PLAYER_CONTROL_GAINED(self, event)
    end
end)

-- Nameplate removal can arrive after its token stops resolving. Retire by the
-- stored token; preserve only a positively identified canonical replacement.
local nameplateEvent
local function nameplateCurrent(self,snapshot,ticket)
    return self.unitsInRange==snapshot and nameplateEvent==ticket
end
local function nameplateReadable(self,snapshot,ticket,value)
    local readable=self.Platform:CanReadValue(value)
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    return not not readable
end
local function nameplateGUID(self,snapshot,ticket,unit)
    local ok,guid=pcall(UnitGUID,unit)
    if not nameplateCurrent(self,snapshot,ticket) or not ok then return nil end
    if not nameplateReadable(self,snapshot,ticket,guid) then return nil end
    if canaccessvalue and type(canaccessvalue)~="function" then return nil end
    if canaccessvalue and not canaccessvalue(guid) then return nil end
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    if type(guid)=="string" and guid~="" then return guid end
end
local function nameplateChanges(self,snapshot,ticket,unit,keep)
    -- Provider calls can reenter these handlers and mutate public maps. Finish
    -- copying their keys before calling any provider or readability function.
    local entries,changes={},{}
    for guid,entry in pairs(snapshot) do entries[#entries+1]={guid=guid,entry=entry} end
    for _,change in ipairs(entries) do
        local entry=change.entry
        if type(entry)=="table" and getmetatable(entry)==nil then
            local stored=rawget(entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return nil end
            if readable and type(stored)=="string" and stored==unit then
                readable=nameplateReadable(self,snapshot,ticket,change.guid)
                if readable==nil then return nil end
                if readable and type(change.guid)=="string" and change.guid~=keep then changes[#changes+1]=change end
            end
        end
    end
    if #changes==0 then return changes end
    local units,aliases={},{}
    for alias in pairs(addon.units) do units[#units+1]=alias end
    for _,alias in ipairs(units) do
        local readable=nameplateReadable(self,snapshot,ticket,alias)
        if readable==nil then return nil end
        if readable and type(alias)=="string" and alias~=unit then
            local guid=nameplateGUID(self,snapshot,ticket,alias)
            if not nameplateCurrent(self,snapshot,ticket) then return nil end
            if guid and not aliases[guid] then aliases[guid]=alias end
        end
    end
    for _,change in ipairs(changes) do change.alias=aliases[change.guid] end
    return changes
end
local function nameplateStoredMatches(entry,stored)
    return rawget(entry,"unit")==stored
end
local function applyNameplateChanges(self,snapshot,ticket,unit,changes)
    for _,change in ipairs(changes) do
        if rawget(snapshot,change.guid)==change.entry then
            local stored=rawget(change.entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return false end
            if readable and type(stored)=="string" and stored==unit then
                -- A readability callback may directly replace the field. Never
                -- compare a newly restricted value outside a protected read.
                local ok,unchanged=pcall(nameplateStoredMatches,change.entry,stored)
                if ok and unchanged and rawget(snapshot,change.guid)==change.entry then
                    if change.alias then rawset(change.entry,"unit",change.alias)
                    else rawset(snapshot,change.guid,nil) end
                end
            end
        end
    end
    return true
end

addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local guid=nameplateGUID(self,snapshot,ticket,unit);if not guid then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit,guid);if not changes then return end
    local previous=rawget(snapshot,guid)
    if previous~=nil and (type(previous)~="table" or getmetatable(previous)~=nil) then return end
    local previousUnit=previous and rawget(previous,"unit")
    if previous and (not nameplateReadable(self,snapshot,ticket,previousUnit) or type(previousUnit)~="string") then return end
    local entry=previous or CreateUnitInfo({},unit)
    if not nameplateCurrent(self,snapshot,ticket) then return end
    if not applyNameplateChanges(self,snapshot,ticket,unit,changes) then return end
    local current=rawget(snapshot,guid)
    if type(current)~=type(previous) or not rawequal(current,previous) then return end
    if previous then
        local ok,unchanged=pcall(nameplateStoredMatches,previous,previousUnit)
        if not ok or not unchanged then return end
    end
    rawset(entry,"unit",unit);rawset(snapshot,guid,entry)
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit);if not changes then return end
    if not nameplateCurrent(self,snapshot,ticket) then return end
    applyNameplateChanges(self,snapshot,ticket,unit,changes)
end)

addon.BAG_UPDATE = wrapEvent(function(self)
    local bindings = self.db.char.bindings

    for id, _ in pairs(bindings) do
        self:UpdateBoundButton(id)
    end

    self:UpdateBagContents()
end)

addon.UNIT_COMBAT = wrapCombatEvent(function(self, _, unit, action, severity, value, type)
    if self.combatHistory[unit] == nil then
        self.combatHistory[unit] = {}
    end

    table.insert(self.combatHistory[unit], 1, {
        time = GetTime(),
        action = action,
        severity = severity,
        value = value,
        type = type,
    })
end)

local currentSpells = {}
local lastCastTarget = {} -- work around UNIT_SPELLCAST_SENT not always triggering
local currentChannel

local function spellcast(self, event, unit, castguid, spellid)
    -- even though we check it later, this skips rows entirely.
    if unit == 'player' or unit == "pet" then
        -- BEGIN ANNOUNCEMENT CONDITION OWNER
        local profile=self.db.profile
        local announcements=profile.announces
        for index, value in ipairs(announcements) do
        -- END ANNOUNCEMENT CONDITION OWNER
            if value.type~='macro' and (value.outputs~=nil or value.value or value.announce == "audible" or value.announce == "gesture") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
                (event == "UNIT_SPELLCAST_" .. value.event or event == "UNIT_SPELLCAST_CHANNEL_" .. value.event) then
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
                    local registry=self.conditionRegistryVersion
                    local seriesRecipient=currentSpells[castguid]
                    local seriesLifecycle=value.outputs~=nil and self.IsEnabled or nil
                    local function seriesEnabled()
                        if value.outputs==nil then return true end
                        if self.IsEnabled~=seriesLifecycle then return false end
                        if seriesLifecycle~=nil then
                            if type(seriesLifecycle)~='function' then return false end
                            local ok,enabled=pcall(seriesLifecycle,self)
                            if not ok or enabled~=true then return false end
                        end
                        local state=rawget(self,'enabledState')
                        return self.IsEnabled==seriesLifecycle and rawget(self,'enabledState')==state and (state==nil or state==true)
                    end
                    local ent,current=self:PrepareAnnouncementDelivery(value,function()
                        return seriesEnabled() and self.db.profile==profile and profile.announces==announcements
                            and announcements[index]==value and not value.disabled
                            and self.conditionRegistryVersion==registry
                            and (value.outputs==nil or currentSpells[castguid]==seriesRecipient)
                    end)
                    if ent and current() and (ent.outputs==nil or self:IsValidAnnouncement(value) and current()) then
                    -- END ANNOUNCEMENT CONDITION LEASE
                    local spellids, itemids = self:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
                            if ent.outputs~=nil then
                                if not current() then return end
                                -- Reserve the parent once before any card callback.
                                if self.announced[ent.id]==nil then self.announced[ent.id]={castguid}
                                else table.insert(self.announced[ent.id],castguid) end
                                self:DispatchAnnouncementSeries(ent,seriesRecipient,current,nil,function(card,live)
                                    local text=card.value or ''
                                    local link,itemLink
                                    if text:find('{{target}}',1,true) and not seriesRecipient then return nil end
                                    if text:find('{{spell}}',1,true) then
                                        if ent.type~=BOOKTYPE_SPELL and ent.type~=BOOKTYPE_PET then return nil end
                                        link=spellLink(sid)
                                        if type(link)~='string' or not live() then return nil end
                                    end
                                    if text:find('{{item}}',1,true) then
                                        if ent.type~='item' then return nil end
                                        local info=self.Platform:GetItemDisplayInfo(itemids[idx])
                                        itemLink=info and info.link
                                        if type(itemLink)~='string' or not live() then return nil end
                                    end
                                    return text:gsub('{{target}}',function()return seriesRecipient end)
                                        :gsub('{{spell}}',function()return link end):gsub('{{item}}',function()return itemLink end)
                                        :gsub('{{event}}',function()return self.events[ent.event]end)
                                end)
                            else
                            -- BEGIN ANNOUNCEMENT CONDITION MATCH
                            if self:AnnouncementConditionMatches(ent,currentSpells[castguid],current) then
                            -- END ANNOUNCEMENT CONDITION MATCH
                            local text = ent.value or ""
                            if ent.announce~='audible' and ent.announce~='gesture' then
                            if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                                local link = spellLink(sid)
                                text = text:gsub("{{spell}}", link)
                            elseif ent.type == "item" then
                                local info = self.Platform:GetItemDisplayInfo(itemids[idx])
                                local link = info and info.link
                                if type(link)=="string" then text = text:gsub("{{item}}", function() return link end) end
                            end
                            text = text:gsub("{{event}}", self.events[ent.event])
                            if currentSpells[castguid] or lastCastTarget[spellid] then
                                text = text:gsub("{{target}}", currentSpells[castguid] or lastCastTarget[spellid])
                            end
                            end
                            if not current() then return end -- ANNOUNCEMENT CONDITION BEFORE OUTPUT
                            -- Reserve before any output callback can reenter this cast.
                            if self.announced[ent.id] == nil then
                                self.announced[ent.id] = { castguid }
                            else
                                table.insert(self.announced[ent.id], castguid)
                            end
                            if ent.announce=='gesture' then self:DispatchAnnouncement(ent,nil,currentSpells[castguid],current)
                            else self:DispatchAnnouncement(ent,text,nil,current) end
                            end -- ANNOUNCEMENT CONDITION OUTPUT
                            end -- ANNOUNCEMENT SERIES OR LEGACY
                            break
                        end
                    end
                    end -- ANNOUNCEMENT CONDITION LEASE
                end
            end
        end
    end
end

addon.UNIT_SPELLCAST_START = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_STOP = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        currentSpells[castguid] = nil
        self.lastMainSwing = nil
        self.lastOffSwing = nil
    end
end)
addon.UNIT_SPELLCAST_SUCCEEDED = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        if currentChannel then
            currentChannel = castguid
        end
    end
    if unit == 'player' or unit == 'pet' then
        table.insert(self.spellHistory, 1, {
            spell = spellid, --[[ this was causing spellid to be nil in spellHistory, breaking the spell history conditions. ]]
            time = GetTime()
        })
    end
end)
addon.UNIT_SPELLCAST_INTERRUPTED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_FAILED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_DELAYED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_CHANNEL_START = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        currentChannel = true
    end
end)
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

addon.UNIT_SPELLCAST_SENT = wrapCombatEvent(function(_, _, unit, target, castguid, spellid)
    if (unit == 'player') then
        currentSpells[castguid] = target
        lastCastTarget[spellid] = target
    end
end)

local function handle_combat_log(_, event, _, sourceGUID, _, _, _, destGUID, _, _, _, ...)
    local spellid, spellname, envType
    local offs = 1
    if event:sub(1, 5) == "SPELL" or event:sub(1, 5) == "RANGE" then
        spellid, spellname = ...
        offs = 4
    elseif event:sub(1, 5) == "ENVIRONMENTAL" then
        envType = ...
        offs = 2
    elseif event == "SWING_MISSED" and sourceGUID == playerGUID then
        local offhand = select(2, ...)
        if offhand then
            addon.lastOffSwing = GetTime()
        else
            addon.lastMainSwing = GetTime()
        end
    end

    if event:sub(-5) == "_HEAL" then
        local amount = select(offs, ...)
        if not addon.damageHistory[destGUID] then
            addon.damageHistory[destGUID] = {
                damage = {},
                heals = {},
            }
        end
        table.insert(addon.damageHistory[destGUID].heals, 1, {
            time = GetTime(),
            value = tonumber(amount),
        })
    elseif event:sub(-7) == "_DAMAGE" then
        if event:sub(1, 5) == "SWING" and sourceGUID == playerGUID then
            local offhand = select(10, ...)
            if offhand then
                addon.lastOffSwing = GetTime()
            else
                addon.lastMainSwing = GetTime()
            end
        end

        local amount = select(offs, ...)
        if not addon.damageHistory[destGUID] then
            addon.damageHistory[destGUID] = {
                damage = {},
                heals = {},
            }
        end
        table.insert(addon.damageHistory[destGUID].damage, 1, {
            time = GetTime(),
            value = tonumber(amount),
        })
    end
end
addon.COMBAT_LOG_EVENT_UNFILTERED = wrapCombatEvent(function() handle_combat_log(CombatLogGetCurrentEventInfo()) end)

addon.SPELL_DATA_LOAD_RESULT = wrapEvent(function(_, _, spellId, success)
    if success then
        addon.SpellCatalog:UpdateSpell(spellId)
    end
end)

addon.ITEM_DATA_LOAD_RESULT = wrapEvent(function(_, _, itemId, success)
    if success then
        addon:UpdateReferenceItem(itemId)
    end
end)
-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'main',addon.EvaluateNextActionInternal,function() return UpdateUnitInfo end) end
end
-- END CPU RUNTIME WORK HANDOFF
]========],
        after = [========[local addon_name, addon = ...
-- Capture the compatibility override once. Managed rotations use the prepared
-- executor; unsupported/custom sources retain the eager compatibility path.
local preparedRuntimeEnabled = addon.preparedRuntimeEnabled ~= false
local publicationRawget,publicationType,publicationMetatable=rawget,type,getmetatable
addon.BindRotationExecutionGeneration=nil
-- BEGIN ANALYTICS ADVICE HANDOFF
local adviceCapture
if addon.BindAnalyticsAdviceCapture then
 addon:BindAnalyticsAdviceCapture(function(sink)adviceCapture=sink end)
end
-- END ANALYTICS ADVICE HANDOFF
-- BEGIN SWITCH UNIT HANDOFF
local switchConditionEvaluator
local consumeSwitch=addon.ConsumeSwitchConditionEvaluator
if type(consumeSwitch)=='function'then
    switchConditionEvaluator=consumeSwitch(addon)
    addon.ConsumeSwitchConditionEvaluator=nil
end
local function switchConditionMatches(value,current)
    if switchConditionEvaluator then return switchConditionEvaluator(addon,value,current)end
    return addon:evaluateCondition(value)
end
-- END SWITCH UNIT HANDOFF
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local advanceActiveSpec=addon.AdvanceActiveRotationSpecialization
local retireActive=addon.RetireActiveRotationTransition
local commitActive=addon.CommitActiveRotationTransition
local cleanupActive=addon.GetActiveRotationCleanupSelection
local prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local invalidateChoiceDependencies=addon.InvalidateRotationDependencies
local consumeChoices=addon.ConsumeRotationChoiceSelection
if type(consumeChoices)=='function' then
    prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh=consumeChoices(addon)
    addon.ConsumeRotationChoiceSelection=nil
end
-- BEGIN EQUIPMENT EVENT LIFETIME
local equipmentSubscription
local equipmentCoordinator=addon.GetScopedRotationCoordinator
-- END EQUIPMENT EVENT LIFETIME
local function activeChangeCurrent(self,token)
    return type(activeCurrent)=='function' and activeCurrent(self,token)
end
local function activeCall(self,token,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=self[name]
    if not activeChangeCurrent(self,token) then return false end
    method(self,...)
    return activeChangeCurrent(self,token)
end
local function activeValue(self,token,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=self[name]
    if not activeChangeCurrent(self,token) then return false end
    local value=method(self,...)
    return activeChangeCurrent(self,token),value
end
local function activeObjectCall(self,token,object,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=object[name]
    if not activeChangeCurrent(self,token) then return false end
    method(object,...)
    return activeChangeCurrent(self,token)
end
local function activeObjectValue(self,token,object,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=object[name]
    if not activeChangeCurrent(self,token) then return false end
    local value=method(object,...)
    return activeChangeCurrent(self,token),value
end
local function activeBroker(self,token,broker,text)
    if not activeChangeCurrent(self,token) then return false end
    broker.text=text
    return activeChangeCurrent(self,token)
end
-- SavedVariables identity must match the TOC, independent of folder casing.
addon.savedVariableName = "RotationMasterDB"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

_G[addon_name] = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local getCached
local acquireActiveRuntimePlan,registerActiveRuntimeConsumers
local mainEnvironment=getfenv(1)
local runtimeDecisionSink
local bindRuntimeDecisions=addon.BindCPURuntimeDecisionCounts
addon.BindCPURuntimeDecisionCounts=nil
if type(bindRuntimeDecisions)=='function'then
    bindRuntimeDecisions(addon,function(sink)runtimeDecisionSink=sink end)
end
local consumeActiveRuntimePlan=addon.ConsumeActiveRuntimePlan
if type(consumeActiveRuntimePlan)=='function' then
    acquireActiveRuntimePlan,registerActiveRuntimeConsumers=consumeActiveRuntimePlan(addon)
    addon.ConsumeActiveRuntimePlan=nil
end
local prepareConditionRuntime,retireConditionRuntime,lastConditionSession
local consumeConditionRuntime=addon.ConsumeConditionRuntime
if type(consumeConditionRuntime)=='function' then
    prepareConditionRuntime,retireConditionRuntime=consumeConditionRuntime(addon)
    addon.ConsumeConditionRuntime=nil
end
local acquireEvaluationPass,invalidateEvaluationContext,acquireMainSelectionPass,getMainCleanupBody
local bindEvaluationContext=addon.BindRuntimeEvaluationContext
if type(bindEvaluationContext)=='function' then
    bindEvaluationContext(addon,function(acquire,invalidate,selection,cleanup) acquireEvaluationPass,invalidateEvaluationContext,acquireMainSelectionPass,getMainCleanupBody=acquire,invalidate,selection,cleanup end)
    addon.BindRuntimeEvaluationContext=nil
end
local sequenceRawMethod,sequenceRun,sequenceStatus,ownedSequence
local bindSequence=addon.BindRotationSequenceReader
if type(bindSequence)=="function" then
    bindSequence(addon,function(rawMethod,run,status,source) sequenceRawMethod,sequenceRun,sequenceStatus,ownedSequence=rawMethod,run,status,source end)
    addon.BindRotationSequenceReader=nil
end
local function evaluateSequence(owner,body,evaluate,visit,guard)
    local before=sequenceRawMethod and sequenceRawMethod(owner)
    local method
    if guard then method=before else method=owner.EvaluateRotationSequence end
    if sequenceRun then return sequenceRun(owner,before,method,body,evaluate,visit,guard) end
    if guard then return {status='unavailable',suppressAttack=true}end
    return method(owner,body,evaluate,visit)
end
-- One-time private handoff to the earlier-loaded optional CPU sampler.
local bindCPUStatus=addon.BindCPUExecutionIndexDiagnostic
if type(bindCPUStatus)=="function" then
    bindCPUStatus(addon,function()
        local status=sequenceStatus and sequenceStatus(addon) or {}
        status.main={reason=sequenceRawMethod and sequenceRun and sequenceStatus and "ready" or "unbound"}
        return status
    end)
    addon.BindCPUExecutionIndexDiagnostic=nil
end
local DBIcon = LibStub("LibDBIcon-1.0")
local function spellLink(spellid)
    return addon.Platform:GetSpellLink(spellid) or string.format(L["Unknown spell (%s)"],spellid)
end

local ThreatClassic = LibStub("ThreatClassic-1.0", true)
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    if not UnitThreatSituation and ThreatClassic then
        UnitThreatSituation = function(...) return ThreatClassic:UnitThreatSituation(...) end
    end

    local LibClassicDurations = LibStub("LibClassicDurations")
    LibClassicDurations:Register(addon_name)
elseif ThreatClassic then
    ThreatClassic:Disable()
end

local pairs, color, string = pairs, color, string
local floor = math.floor
local isin, starts_with, isint = addon.Functions.values.isin, addon.Functions.text.starts_with, addon.Functions.values.isint

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
addon.delayed_condition = {}
-- The engine borrows its own validated pass; legacy public getters retain
-- their historical mutable-body contract without becoming the polling path.
local function mainSelectionPass(owner,spec)
    if acquireMainSelectionPass then return acquireMainSelectionPass(owner,spec) end
    return owner:AcquireRotationRuntimePass(spec)
end
local function runtimeRows(owner,spec,candidates)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=mainSelectionPass(owner,spec);if not pass then return {},why end
        return pass:Candidates(candidates==true)
    end
    return owner:GetRuntimeRotations(spec,true,candidates)
end
local function runtimeOne(owner,spec,value)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=mainSelectionPass(owner,spec);if not pass then return nil,why end
        return pass:Get(value)
    end
    return owner:GetRuntimeRotation(spec,value)
end
local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(addon_name,
        { type = "data source", label = addon.pretty_name, icon = addon.logoTexture })

--
-- Initialization
--

BINDING_HEADER_ROTATIONMASTER = addon.pretty_name
BINDING_NAME_ROTATIONMASTER_TOGGLE = string.format(L["Toggle %s " .. color.CYAN .. "/rm toggle" .. color.RESET], addon.pretty_name)

local playerGUID = UnitGUID("player")

local defaults = {
    profile = {
        enable = true,
        poll = 0.15,
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
        rotation_view = "diagram",
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
            yoffs = 0
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
    }
}

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and
   LE_EXPANSION_LEVEL_CURRENT >= 2 then
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
    'ITEM_DATA_LOAD_RESULT'
}

-- These handlers maintain legacy combat observations. Reference-only clients
-- must neither subscribe to them nor process a queued/direct invocation.
local combat_events = {
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_COMBAT",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "COMBAT_LOG_EVENT_UNFILTERED",
}

local mainline_events = {
    'PLAYER_FOCUS_CHANGED',
    'VEHICLE_UPDATE',
    'UNIT_ENTERED_VEHICLE',
    'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED',
    'PLAYER_SPECIALIZATION_CHANGED',
}

local wrath_events = {
    'PLAYER_TALENT_UPDATE',
    -- 'ACTIVE_TALENT_GROUP_CHANGED', # Implied by the above
}

local tbc_events = {
    'PLAYER_FOCUS_CHANGED',
}

local classic_events = {

}

-- Chat, menu and cold restoration share the existing active transition path.
local function chooseManualRotation(self,id,change,remember)
    change=change or beginActive(self)
    if not activeChangeCurrent(self,change) then return nil end
    local body=id and runtimeOne(self,self.currentSpec,id)
    if not activeChangeCurrent(self,change) or id and not body then return nil end
    local ticket
    if remember and prepareChoiceSelection then
        local reference
        if id then
            local available=self.GetScopedRotationCoordinator
            if not activeChangeCurrent(self,change) then return nil end
            local checked,coordinator
            if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return nil end end
            if coordinator then checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,id);if not checked then return nil end end
        end
        if not id or reference then ticket=prepareChoiceSelection(self,reference) end
        if not activeChangeCurrent(self,change) then return nil end
    end
    if ticket and invalidateChoiceDependencies then
        invalidateChoiceDependencies(self,'selection',nil)
        if not activeChangeCurrent(self,change) then return nil end
    end
    self.rotationChoiceSuspended=nil
    if id==nil then
        if ticket then finishChoiceSelection(ticket) end
        self.manualRotation=false
        return self:SwitchRotation()
    end
    local selected=self.currentRotation
    if not activeChangeCurrent(self,change) then return nil end
    if selected~=id then
        if not retireActive(self,change) or not activeChangeCurrent(self,change) then return nil end
        if not activeCall(self,change,'RemoveAllCurrentGlows') then return nil end
        if not commitActive(self,change,self.currentSpec,id,body) or not activeChangeCurrent(self,change) then return nil end
        self.manualRotation=true
        self.skipAnnounce=true;self.avail_announced={};self.announced={}
        if not activeCall(self,change,'EnableRotationTimer') then return nil end
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeBroker(self,change,DataBroker,name) then return nil end
        if not activeObjectCall(self,change,AceEvent,'SendMessage','ROTATIONMASTER_ROTATION',id,name) then return nil end
    else self.manualRotation=true end
    if remember then
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name) then return nil end
        local checked,valid=activeValue(self,change,'rotationValidConditions',body,self.currentSpec)
        if not checked then return nil end
        if not valid and not activeCall(self,change,'warn',L["Active rotation is incomplete and may not work correctly!"]) then return nil end
        if ticket then finishChoiceSelection(ticket) end
    end
    return true,change
end

local function restoreManualChoice(self)
    if choiceNeedsRefresh and choiceNeedsRefresh(self) then
        local change=beginActive(self)
        if not activeChangeCurrent(self,change) then return true end
        local desired,changed=readDesiredChoice(self)
        if not activeChangeCurrent(self,change) then return true end
        if self.adviceErrorReport or self.initializationErrorReport then return true end
        if changed then
            local wasManual=self.manualRotation
            if not activeChangeCurrent(self,change) then return true end
            self.rotationChoiceSuspended=nil
            self.manualRotation=false
            if desired then
                local available=self.GetScopedRotationCoordinator
                if not activeChangeCurrent(self,change) then return true end
                local checked,coordinator,reference,key
                if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return true end end
                if coordinator then
                    checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,desired)
                    if not checked then return true end
                    if reference then checked,key=activeObjectValue(self,change,coordinator,'Key',reference);if not checked then return true end end
                end
                if not activeChangeCurrent(self,change) then return true end
                if reference and chooseManualRotation(self,key,change,false) then return true,change end
                if not activeChangeCurrent(self,change) then return true end
                self.rotationChoiceSuspended=true
            end
            if wasManual and self.currentRotation then
                local disable=self.DisableRotation
                if not activeChangeCurrent(self,change) then return true end
                local _,nextChange,stopped=disable(self)
                if stopped==false then return true end
                change=nextChange or change
                if not activeChangeCurrent(self,change) then return true end
            end
        end
        return false,change
    end
    return false
end

function addon:HandleCommand(str)
    local cmd, npos = AceConsole:GetArgs(str, 1, 1)
    if self.initializationErrorReport and cmd and cmd~="errors" and cmd~="help" then
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
        addon:print(L["                          Manual choices are remembered for this character, specialization and action context."])
        addon:print(L["/rm check               - Check the database integrity."])
        addon:print(L["/rm repair              - Fix any DB errors found in the data with internal validation."])
        addon:print(L["/rm errors              - View and copy Rotation Master errors."])
        addon:print(L['/rm editorinfo          - Copy native Lua input diagnostics.'])
        addon:print(L['/rm editorarrows        - Temporarily test native arrows in an open editor.'])
        addon:print(L['/rm cpu [start|report|cancel] - Capture and inspect CPU costs.'])

    elseif cmd == "config" then
        self:ShowConfig("Rotations")

    elseif cmd == "errors" then
        self:ShowErrors()

    elseif cmd == 'editorinfo' then
        self:ShowLuaEditorInputReport()

    elseif cmd == 'editorarrows' then
        self:ShowLuaEditorArrowProbe()

    elseif cmd == 'cpu' then
        self:RunCPUProfileAction(AceConsole:GetArgs(str,1,npos))

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
            addon:print(L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO], addon:GetRotationName(self.currentRotation))
        end

    elseif cmd == "set" then
        local change=beginActive(self)
        local name = string.sub(str, npos)
        if not activeChangeCurrent(self,change) then return end

        if name=="auto" then
            chooseManualRotation(self,nil,change,true)
        elseif name==self.currentRotation or name==DEFAULT then
            if not chooseManualRotation(self,name,change,true) and activeChangeCurrent(self,change) and name==DEFAULT then
                self:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.'])
            end
        else
            local matches={}
            for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]=id end end
            if not activeChangeCurrent(self,change) then return end
            if #matches>1 then self:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
            if #matches==1 then chooseManualRotation(self,matches[1],change,true);return end
            self:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."],name)
        end
    elseif cmd == "check" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, false)
    elseif cmd == "repair" then
        addon:print(L["Validating database integrity"])
        self:validate(defaults, true)
    else
        addon:warn(L["Invalid option " .. color.WHITE .. "%s" .. color.WARN], cmd)
    end
end

-- One optional-provider lifetime, independent of the rotation event owner.
-- Settings only publish saved preferences through SyncQuestieIntegration.
local questieService,questieEvents,questieEnabled
function addon:InitializeQuestieIntegration()
    if questieService then return end
    local factory=self.Integrations and self.Integrations.NewQuestie
    if type(factory)~='function' then return end
    questieService=factory()
    self:SyncQuestieIntegration()
end
function addon:SyncQuestieIntegration()
    if not questieService then return false end
    local enabled=self.db and self.db.profile and self.db.profile.questie_enabled==true or false
    if enabled==questieEnabled then return true end
    questieEnabled=enabled
    if enabled then
        if not questieEvents then
            questieEvents=CreateFrame('Frame')
            questieEvents:SetScript('OnEvent',function(_,event,name)
                if event=='ADDON_LOADED' and name=='Questie' and questieEnabled then questieService:Refresh() end
            end)
        end
        questieEvents:RegisterEvent('ADDON_LOADED')
    elseif questieEvents then questieEvents:UnregisterEvent('ADDON_LOADED') end
    questieService:SetEnabled(enabled)
    return true
end
function addon:GetQuestieIntegrationStatus()
    if questieService then return questieService:GetStatus() end
    return {state='unavailable',reason='adapter-unavailable',nativeAcceptance='unverified'}
end
function addon:RefreshQuestieIntegration()
    if questieService and questieEnabled then return questieService:Refresh() end
    return self:GetQuestieIntegrationStatus()
end

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
        defaults.profile.rotations=nil;defaults.profile.rotationLibrary=nil
    end
    self.db = LibStub("AceDB-3.0"):New(self.savedVariableName, defaults, true)
    -- BEGIN CACHE DIAGNOSTIC INITIALIZATION
    if type(self.InitializeCacheDiagnosticMode)=="function" then
        self:InitializeCacheDiagnosticMode(self.db.global)
    end
    -- END CACHE DIAGNOSTIC INITIALIZATION

    for ext_addon,conditions in pairs(self.delayed_condition) do
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
    self.rotationChoiceSuspended=nil

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
    self.damageHistory = {}
    self.lastMainSwing = nil
    self.lastOffSwing = nil

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

    self.evaluationProfile = addon:ProfiledCode()

    self.currentSpell = nil
    self.nextWindow = nil
    if self.InstallRotationProfileLifecycle then self:InstallRotationProfileLifecycle() end

    -- This is here because of order of loading.
    getCached = addon.Functions.cache.getCached

    self:InitializeQuestieIntegration()

    --self:SetupOptions()
end

function addon:OnInitialize()
    -- A failed initializer must not be followed by OnEnable or gameplay events
    -- using half-built state. Diagnostics stays independent of the database.
    self.initializationErrorReport=0
    local ok,reportId
    if self.Diagnostics then
        ok,reportId=self.Diagnostics:Call({module="startup",operation="initialization"},self.OnInitializeInternal,self)
    else self:OnInitializeInternal();ok=true end
    if ok then self.initializationErrorReport=nil;self.adviceErrorReport=nil
    else self.initializationErrorReport=reportId or 0;self.adviceErrorReport=reportId or 0 end
    return ok,reportId
end

function addon:GetRotationName(id)
    if id == DEFAULT then
        return DEFAULT
    else
        local body=runtimeOne(self,self.currentSpec,id)
        return body and body.name or nil
    end
end

local function minimapToggleRotation(_, _, _, checked)
    if checked then
        addon:enable()
    else
        addon:disable()
    end
end

local function minimapChangeRotation(_,arg1)
    chooseManualRotation(addon,arg1,nil,true)
end

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
    info.text, info.arg1, info.checked = DEFAULT, DEFAULT, (addon.manualRotation == true and addon.currentRotation == DEFAULT)
    UIDropDownMenu_AddButton(info)
    do
        for id, rot in pairs(runtimeRows(addon,addon.currentSpec)) do
            if id ~= DEFAULT then
                info.text, info.arg1, info.checked = rot.name, id, (addon.manualRotation == true and addon.currentRotation == id)
                if addon:IsDefaultRuntimeRotation(addon.currentSpec,id) then info.text="|cff5bc0eb"..rot.name.."|r ("..L["Built In · read-only"]..")" end
                UIDropDownMenu_AddButton(info)
            end
        end
    end
end

function DataBroker.OnClick(_, button)
    if addon.initializationErrorReport then addon:ShowErrors();return end
    if button == "RightButton" then
        local frame = CreateFrame("Frame", addon_name .. "LDBFrame")
        local dropdownFrame = CreateFrame("Frame", addon_name .. "LDBDropdownFrame", frame, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        local shell=addon.configWindow
        if shell and shell.frame:IsShown() then shell:Hide() else addon:ShowConfig("Rotations") end
    end
end

function DataBroker.OnTooltipShow(GameTooltip)
    GameTooltip:SetText(addon.pretty_name .. " " .. GetAddOnMetadata(addon_name, "Version"), 0, 1, 1)
    GameTooltip:AddLine(" ")
    if addon.currentRotation ~= nil then
        GameTooltip:AddLine(L["Current Rotation"], 0.55, 0.78, 0.33, 1)
        GameTooltip:AddLine(addon:GetRotationName(addon.currentRotation), 1, 1, 1)
    else
        GameTooltip:AddLine(L["Battle rotation disabled"], 1, 0, 0, 1)
    end
    if addon.rotationChoiceSuspended then
        GameTooltip:AddLine(L['Saved manual choice is unavailable in the current context.'],1,0.8,0.2,true)
    end
end

function addon:toggle()
    if self.currentRotation == nil then
        self:enable()
    else
        self:disable()
    end
end

-- These additional notifications vary by client; leave existing subscriptions
-- alone and require the native event catalogue to confirm each optional name.
local function registerOptionalEvent(owner,change,event)
    if not activeChangeCurrent(owner,change) then return false end
    local utils=C_EventUtils
    local validEvent=type(utils)=='table' and utils.IsEventValid
    if not activeChangeCurrent(owner,change) then return false end
    if type(validEvent)~='function' then return activeChangeCurrent(owner,change),false end
    local ok,valid=pcall(validEvent,event)
    if not activeChangeCurrent(owner,change) then return false end
    if ok and valid==true then local current=activeCall(owner,change,'RegisterEvent',event);return current,current end
    return true,false
end

local reconcileNameplateResume

function addon:enable()
    if self.initializationErrorReport then self:ShowErrors();return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT ENABLE LIFETIME
    equipmentSubscription=nil
    local equipmentProfile=self.db.profile
    local equipmentRegistered=false
    -- END EQUIPMENT ENABLE LIFETIME
    for _,v in pairs(events) do
        if not activeCall(self,change,'RegisterEvent',v) then return end
    end
    local client=self.Platform:GetClientInfo()
    if not activeChangeCurrent(self,change) then return end
    if client.combatDataPolicy=='probe' then
        for _,event in ipairs(combat_events) do if not activeCall(self,change,'RegisterEvent',event) then return end end
    end
    local family=client.family
    local extraEvents=family=="retail" or family=="forever"
    extraEvents=extraEvents and mainline_events or family=="progression" and wrath_events
        or family=="tbc" and tbc_events or family=="era" and classic_events or {}
    for _,event in ipairs(extraEvents) do if not activeCall(self,change,'RegisterEvent',event) then return end end

    if not registerOptionalEvent(self,change,'UNIT_EXITED_VEHICLE') then return end
    if family=='tbc' then
        if not registerOptionalEvent(self,change,'PLAYER_TALENT_UPDATE') then return end
        if not registerOptionalEvent(self,change,'ACTIVE_TALENT_GROUP_CHANGED') then return end
        -- BEGIN EQUIPMENT EVENT REGISTRATION
        local current,registered=registerOptionalEvent(self,change,'PLAYER_EQUIPMENT_CHANGED')
        if not current then return end
        equipmentRegistered=registered
        -- END EQUIPMENT EVENT REGISTRATION
    end

    if client.combatDataPolicy=='probe' then
        reconcileNameplateResume(self,change)
        if not activeChangeCurrent(self,change) then return end
    end

    if self.RefreshPreviewWindow then
        if not activeCall(self,change,'RefreshPreviewWindow') then return end
    end
    if not activeChangeCurrent(self,change) then return end
    local update=self.UpdateSkill
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=update(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT ENABLE COMMIT
    if not activeCall(self,change,'EnableRotation') then return end
    if equipmentRegistered and self.db.profile==equipmentProfile and activeChangeCurrent(self,change) then
        equipmentSubscription={}
    end
    -- END EQUIPMENT ENABLE COMMIT
end

function addon:disable()
    if self.initializationErrorReport then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN EQUIPMENT DISABLE LIFETIME
    equipmentSubscription=nil
    -- END EQUIPMENT DISABLE LIFETIME
    local disable=self.DisableRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange,stopped=disable(self);change=nextChange or change
    if stopped==false or not activeChangeCurrent(self,change) then return end
    local available=self.nextWindow
    if not activeChangeCurrent(self,change) then return end
    if available then
        local spells=self.db.profile.preview_spells
        local window=self.nextWindow
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,window,'Release') then return end
        self.nextWindow=nil
        self.db.profile.preview_spells=spells
    end
    self.spellHistory={}
    self.combatHistory={}
    if not activeCall(self,change,'UnregisterAllEvents') then return end
end

function addon:OnEnable()
    if self.initializationErrorReport then return end
    self:info(L["Starting up version %s"], GetAddOnMetadata(addon_name, "Version"))

    if self.db.profile.live_config_update and not self.conditionEvalTimer then
        self.conditionEvalTimer = self:ScheduleRepeatingTimer('UpdateCurrentCondition', self.db.profile.live_config_update)
    end

    if self.db.profile.enable then
        self:enable()
    end
end

function addon:rotationValidConditions(rot,spec)
    if type(rot)~='table' or not self.RotationData.GetRotationPriority(rot.priority) then return false end
    local tree=self.RotationData.IndexRotationSteps(rot,{allowMissingIds=true})
    if not tree then return false end
    local itemsets,global_itemsets=self.db.profile.itemsets,self.db.global.itemsets
    local itemfound=false
    for _,row in ipairs(tree.rows) do
        local step=row.step
        if not row.unreachable and not step.disabled then
            if step.type=="branch" then
                if (step.mode==nil or step.mode=="evaluate") and not self:validateCondition(step.conditions,spec) then return false end
            else
                if step.type==nil or not self:validateCondition(step.conditions,spec) then return false end
                if step.type~="none" and step.action==nil then return false end
                if step.type=="item" then
                    if type(step.action)=="string" then
                        local itemset=itemsets[step.action] or global_itemsets[step.action]
                        if not itemset or type(itemset.items)~="table" or #itemset.items==0 then return false end
                    elseif type(step.action)~="table" or #step.action==0 then return false end
                end
            end
            itemfound=true
        end
    end
    return itemfound
end

function addon:UpdateAutoSwitch()
    local rotations=runtimeRows(self,self.currentSpec,true)
    self.autoswitchRotation=self:GetOrderedAutoSwitchRotations(self.currentSpec,rotations)

    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figure out which of the autoswitch rotations best matches
function addon:SwitchRotation()
    local handled,restoredChange=restoreManualChoice(self)
    if handled then return nil,restoredChange end
    if self.db.profile.disable_autoswitch or self.manualRotation then
        if restoredChange and not activeChangeCurrent(self,restoredChange) then return end
        return nil,restoredChange
    end

    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    local newRotation
    local selectedSpec,selectedProfile,selectedRotation=self.currentSpec,self.db.profile,self.currentRotation
    local selectionPass,rotations
    if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
        selectionPass=mainSelectionPass(self,selectedSpec);if not selectionPass then return end
        local why;rotations,why=selectionPass:Candidates(false);if why then return end
    else rotations=runtimeRows(self,selectedSpec) end
    -- BEGIN SWITCH OWNER LEASE
    local function switchOwnerCurrent()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
            and self.currentRotation==selectedRotation and not self.db.profile.disable_autoswitch and not self.manualRotation
    end
    -- END SWITCH OWNER LEASE
    local function current()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile and self.currentRotation==selectedRotation
            and not self.db.profile.disable_autoswitch and not self.manualRotation and (not selectionPass or selectionPass:IsCurrent())
    end
    for _, v in ipairs(self.autoswitchRotation) do
        if not switchOwnerCurrent()then return end
        -- A packaged recommendation must not displace the user's saved fallback.
        if self:IsDefaultRuntimeRotation(self.currentSpec,v) and rotations[DEFAULT]
            and self:rotationValidConditions(rotations[DEFAULT],self.currentSpec) then
            newRotation=DEFAULT
            break
        end
        local matched=rotations[v] and switchConditionMatches(rotations[v].switch,switchOwnerCurrent)
        if not switchOwnerCurrent()then return end
        if matched then
            newRotation = v
            break
        end
    end
    if not newRotation and rotations[DEFAULT] ~= nil and
        self:rotationValidConditions(rotations[DEFAULT], self.currentSpec) then
        newRotation = DEFAULT
    end
    if not current() then return end

    if newRotation then
        if self.currentRotation ~= newRotation then
            local name=newRotation==DEFAULT and DEFAULT or rotations[newRotation].name
            if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
            selectedRotation=nil
            if not activeCall(self,change,'RemoveAllCurrentGlows') or not current() then return end
            if not commitActive(self,change,selectedSpec,newRotation,rotations[newRotation]) or not activeChangeCurrent(self,change) then return end
            selectedRotation=newRotation
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            if not activeCall(self,change,'EnableRotationTimer') or not current() then return end
            if not activeBroker(addon,change,DataBroker,name) then return end
            if not current() then return end
            if not activeCall(self,change,'info',L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO],name) then return end
            if not current() then return end
            if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,name) then return end
        end
        return nil,change
    end

    -- Could not find a rotation to switch to, even the default one.
    if self.currentRotation ~= nil then
        addon:warn(L["No rotation is active as there is none suitable to automatically switch to."])
        if not current() then return end
        self:DisableRotation()
    end
end

function addon:EnableRotation()
    if self.currentSpec==nil or self.currentRotation then return end
    local change=beginActive(self)
    if not activeCall(self,change,'Fetch') then return end
    if not activeCall(self,change,'UpdateAutoSwitch') then return end
    local method=self.SwitchRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=method(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    if self.currentRotation~=nil then
        local getName=self.GetRotationName
        if not activeChangeCurrent(self,change) then return end
        local name=getName(self,self.currentRotation)
        if not activeChangeCurrent(self,change) then return end
        if not activeBroker(self,change,DataBroker,name) then return end
        activeCall(self,change,'info',L["Battle rotation enabled"])
    end
end

function addon:DisableRotation()
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    -- BEGIN ANALYTICS DISABLE
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return nil,nil,false end
    end
    -- END ANALYTICS DISABLE
    local selected=self.currentRotation
    if not retireActive(self,change) or not activeChangeCurrent(self,change) then return nil,nil,false end
    if retireConditionRuntime then
        local previous=lastConditionSession
        retireConditionRuntime(self)
        if lastConditionSession==previous then lastConditionSession=nil end
        if not activeChangeCurrent(self,change) then return nil,nil,false end
    end
    if not selected then return nil,change,true end
    self.currentSpell = nil
    self.avail_announced = {}
    self.announced = {}
    if not activeCall(self,change,'DisableRotationTimer') then return nil,nil,false end
    if not activeCall(self,change,'RemoveAllCurrentGlows') then return nil,nil,false end
    if not activeCall(self,change,'DestroyAllGlows') then return nil,nil,false end
    local availableWindow=self.nextWindow
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if availableWindow then
        local window=self.nextWindow
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,window,'ReleaseChildren') then return nil,nil,false end
    end
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if not activeBroker(self,change,DataBroker,color.RED .. OFF) then return nil,nil,false end
    if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",nil) then return nil,nil,false end
    if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_SPELL_UPDATE",nil,nil) then return nil,nil,false end
    local weak=_G.WeakAuras
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if weak then
        local available=weak.ScanEvents
        if not activeChangeCurrent(self,change) then return nil,nil,false end
        if available then
            local scan=weak.ScanEvents
            if not activeChangeCurrent(self,change) then return nil,nil,false end
            scan("ROTATIONMASTER_SPELL_UPDATE",nil,nil)
        end
    end
    if not activeChangeCurrent(self,change) then return nil,nil,false end
    if not activeCall(self,change,'info',L["Battle rotation disabled"]) then return nil,nil,false end
    return nil,change,true
end

function addon:EnableRotationTimer()
    if self.adviceErrorReport then return end
    if self.currentRotation and not self.rotationTimer then
        self.rotationTimer = self:ScheduleRepeatingTimer('EvaluateNextAction', self.db.profile.poll)
    end
end

function addon:DisableRotationTimer()
    if self.rotationTimer then
        self:CancelTimer(self.rotationTimer)
        self.rotationTimer = nil
    end
end

function addon:ButtonFetch()
    if self.fetchTimer then
        self:CancelTimer(self.fetchTimer)
    end
    self.fetchTimer = self:ScheduleTimer(function()
        self.skipAnnounce = true
        self:Fetch()
    end, 0.25)
end

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

function addon:StopAdviceForError(reportId)
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    -- BEGIN ANALYTICS ERROR
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return end
    end
    -- END ANALYTICS ERROR
    self.adviceErrorReport = reportId
    if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
    self.currentSpell = nil
    self.avail_announced = {}
    local timer = self.rotationTimer
    self.rotationTimer = nil
    local function cleanup(operation, callback, ...)
        if not activeChangeCurrent(self,change) then return false end
        local diagnostics=self.Diagnostics
        local method=diagnostics.Call
        if not activeChangeCurrent(self,change) then return false end
        method(diagnostics,{module="recommendations",operation=operation},callback,...)
        return activeChangeCurrent(self,change)
    end
    if timer and not cleanup("cancel-timer", self.CancelTimer, self, timer) then return end
    if self.nextWindow and not cleanup("hide-preview", self.nextWindow.Hide, self.nextWindow) then return end
    if not cleanup("clear-glows", self.RemoveAllCurrentGlows, self) then return end
    if not cleanup("destroy-glows", self.DestroyAllGlows, self) then return end
    if not cleanup("broker-disabled", function() activeBroker(self,change,DataBroker,color.RED .. OFF) end) then return end
    if not cleanup("rotation-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_ROTATION", nil) then return end
    if not cleanup("suggestion-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_SPELL_UPDATE", nil, nil) then return end
    if WeakAuras and WeakAuras.ScanEvents then
        cleanup("weak-aura-cleared", WeakAuras.ScanEvents, "ROTATIONMASTER_SPELL_UPDATE", nil, nil)
    end
end

function addon:EvaluateNextAction()
    if self.initializationErrorReport then return end
    if not self.Diagnostics then return self:EvaluateNextActionInternal() end
    if self.adviceErrorReport then return end
    local ok, reportId = self.Diagnostics:Call({module="recommendations", operation="timer",
        rotationId=self.currentRotation}, self.EvaluateNextActionInternal, self)
    if not ok then self:StopAdviceForError(reportId) end
end

function addon:EvaluateNextActionInternal()
    local decisionSink=runtimeDecisionSink
    local selectedRotation,selectedSpec,selectedProfile=self.currentRotation,self.currentSpec,self.db.profile
    local runtimePass,rot,publicationGuard,planToken,conditionSession,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease
    local executionFailed=false
    local function dispatchCurrent(kind)
        if executionFailed then return false end
        if not dispatchLease then return true end
        if dispatchLease(kind)then return true end
        executionFailed=true
        return false
    end
    if preparedRuntimeEnabled and selectedRotation~=nil and acquireActiveRuntimePlan and prepareConditionRuntime then
        rot,publicationGuard,planToken,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease=acquireActiveRuntimePlan(self,selectedSpec,selectedRotation)
        if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile then return end
        if handled then
            if not publicationGuard then return end
            if dispatchLease then
                if not dispatchCurrent('resume')then return end
            elseif not publicationGuard()then return end
            if rot then
                conditionSession=prepareConditionRuntime(self,rot,planToken,notifiedLease or conditionLease or publicationGuard,publicationGuard,dispatchLease and dispatchCurrent)
                if executionFailed then return end
                -- Owned preparation certifies its producers and invocation.
                -- Rejected preparation can return before that boundary, so
                -- the ordinary fallback still needs the full source fence.
                if conditionSession and notifiedLease then
                    if not notifiedLease()then return end
                elseif not publicationGuard() then return end
                lastConditionSession=conditionSession
                -- Custom or unsupported trees retain the existing execution
                -- input and callback route; private plan data never escapes.
                if not conditionSession then
                    runtimePass,rot,publicationGuard,planToken,handled,presentationViews,conditionLease,notifiedLease,deliveryLease,dispatchLease=nil,nil,nil,nil,false,nil,nil,nil,nil,nil
                end
            end
        end
    end
    if selectedRotation~=nil and not handled then
        if retireConditionRuntime then
            local previous=lastConditionSession
            if not retireConditionRuntime(self,previous or false) then return end
            if lastConditionSession==previous then lastConditionSession=nil end
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile then return end
        end
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            if acquireEvaluationPass then local reason;runtimePass,reason,publicationGuard=acquireEvaluationPass(self,selectedSpec)
            else runtimePass=self:AcquireRotationRuntimePass(selectedSpec) end
            if runtimePass then rot=runtimePass:Get(selectedRotation) end
        else rot=self:GetRuntimeRotation(selectedSpec,selectedRotation) end
    end
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
        return
    elseif not rot then
        self.manualRotation=false
        self:DisableRotation()
        return
    else
        self.evaluationProfile:start()
        if self.RefreshMacroButtons then self:RefreshMacroButtons() end

        local now = GetTime()
        local cache = {}
        if not self.inCombat then
            self.combatCache = cache
        end

        self.evaluationProfile:child("environment"):start()

        local unitsHandled, unitsGUID = {}, {}
        for unit, _ in pairs(addon.units) do
            unitsGUID[unit] = getCached(cache, UnitGUID, unit)
        end
        for guid, entity in pairs(self.unitsInRange) do
            if isin(addon.units, entity.unit) then
		        if unitsGUID[entity.unit] and unitsGUID[entity.unit] == guid then
                    unitsHandled[entity.unit] = true
                else
                    self.unitsInRange[guid] = nil
                end
            end

            addon:verbose("Updating Unit " .. guid .. " (" .. entity.name .. ")")
            UpdateUnitInfo(cache, entity)
        end
        for unit, guid in pairs(unitsGUID) do
            if not unitsHandled[unit] and not self.unitsInRange[guid] and
                not starts_with(unit, "mouseover") then
                self.unitsInRange[guid] = CreateUnitInfo(cache, unit)
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
        for _,history in pairs(self.combatHistory) do
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

        local actionReady=self:NewActionReadiness(now)
        -- Preparation can call public providers. Check the compiled graph's
        -- source authority once here, before any cached condition is reused.
        if conditionSession and not conditionSession:AfterOpaque() then
            self.evaluationProfile:stop()
            return
        end
        local function eval(cond,decisionRow)
            if decisionSink then decisionSink(decisionRow,'attempt')end
            local firstMapped,firstItem
            local matches
            local action=cond.action
            if action~=nil and not cond.disabled then
                if conditionSession then matches=conditionSession:EvaluateBool(cond.conditions,{stepId=cond.id})
                else matches=addon:evaluateCondition(cond.conditions,{stepId=cond.id}) end
                if decisionSink then decisionSink(decisionRow,matches and 'matched' or 'notmatched')end
            elseif decisionSink then decisionSink(decisionRow,action==nil and 'noaction' or 'disabled')end
            if matches then
                if not dispatchCurrent('step')then return nil,false end
                local spellids,itemids=addon:GetSpellIds(cond)
                for index,id in ipairs(spellids or {}) do
                    local itemId=itemids and itemids[index]
                    local mapped=addon:FindSpell({id},cond.type=="item" and {itemId} or nil)
                    if decisionSink then decisionSink(decisionRow,mapped and 'mapped' or 'unmapped')end
                    if mapped then
                        if not firstMapped then firstMapped,firstItem=mapped,itemId end
                        local ready=actionReady(cond.type,id,itemId)
                        if decisionSink then decisionSink(decisionRow,ready and 'ready' or 'notready')end
                        if ready then return mapped,true,itemId end
                    end
                end
            end
            return firstMapped,false,firstItem
        end

        self.evaluationProfile:child("rotation"):start()
        local preview,suppressAttack=0,false
        local weakAuras=_G.WeakAuras
        ---@type RMRecommendationPreview
        local previewWindow=self.nextWindow
        local nativePreview=previewWindow and type(previewWindow.AddRecommendation)=="function"
        local staged={}
        local delivering,deliveryFailed=false,false
        local function current()
            if deliveryFailed or executionFailed then return false end
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile
                or self.nextWindow~=previewWindow then return false end
            if delivering and deliveryLease then return deliveryLease()end
            if conditionSession and dispatchLease then return dispatchCurrent('resume')end
            if publicationGuard then return publicationGuard() end
            if not runtimePass then return true end
            return runtimePass:IsCurrent()
        end
        local function stage(callback) staged[#staged+1]=callback end
        if nativePreview then
            stage(function() previewWindow:ReleaseChildren();if current() then previewWindow:PauseLayout() end end)
        end
        local function recommend(spellid,cond,index,itemId)
            preview=preview+1
            local ordinal=preview
            stage(function()
                if ordinal==1 then
                    -- BEGIN ANALYTICS PRIMARY ADVICE
                    if adviceCapture then
                        adviceCapture("advice",previewWindow,current,cond.type,spellid)
                        if not current() then return end
                    end
                    -- END ANALYTICS PRIMARY ADVICE
                    self.currentSpell=spellid
                    if not addon:IsGlowing(spellid,itemId) then
                        if not current() then return end
                        if not self.db.profile.disable_buttons then addon:GlowNextSpell(spellid,itemId) end
                        if not current() then return end
                        if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",cond.type,spellid) end
                        if not current() then return end
                        AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,index,cond.id,cond.type,spellid)
                    end
                end
                if not current() then return end
                if nativePreview then previewWindow:AddRecommendation(spellid,itemId) end
            end)
        end
        local sequence=evaluateSequence(self,rot,function(condition,context)
            if conditionSession then return conditionSession:EvaluateResult(condition,context) end
            return addon:evaluateConditionResult(condition,context)
        end,function(cond,index)
            local spellid,enabled,itemId=eval(cond,'rotation')
            if not dispatchCurrent('resume')then return false end
            if enabled then
                recommend(spellid,cond,index,itemId)
                if not nativePreview or preview>=self.db.profile.preview_spells then return false end
            end
            return true
        end,conditionSession and dispatchLease and dispatchCurrent or nil)
        if executionFailed then self.evaluationProfile:stop();return end
        suppressAttack=sequence.suppressAttack
        if preview==0 and not suppressAttack and self.Platform:IsMeleeAttackNeeded("target")==true and actionReady("spell",6603) then
            local attack=addon:FindSpell({6603})
            if attack then recommend(attack,{id="RM-IMPLICIT:ATTACK",type="spell"},sequence.fallbackOrdinal or #(rot.rotation or {})+1) end
        end
        if preview==0 then
            stage(function()
                -- BEGIN ANALYTICS EMPTY ADVICE
                if adviceCapture then adviceCapture("retire");if not current() then return end end
                -- END ANALYTICS EMPTY ADVICE
                self.currentSpell=nil
                if not self.db.profile.disable_buttons then addon:GlowClear() end
                if not current() then return end
                if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",nil,nil) end
                if not current() then return end
                AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,nil)
            end)
        end
        if nativePreview then
            stage(function() previewWindow:ResumeLayout();if current() then previewWindow:DoLayout() end end)
        end

        self.evaluationProfile:child("rotation"):stop()
        self.evaluationProfile:child("cooldowns"):start()
        if rot.cooldowns ~= nil then
            local observations={}
            if not dispatchCurrent('iterator')then self.evaluationProfile:stop();return end
            for id,cond in pairs(rot.cooldowns) do
                local spellid,enabled,itemId=eval(cond,'cooldowns')
                if not dispatchCurrent('resume')then self.evaluationProfile:stop();return end
                observations[#observations+1]={id=id,condition=cond,spellid=spellid,enabled=enabled,itemId=itemId}
            end
            stage(function()
                local enabled_cooldowns = {}
                local enabled_items = {}
                local disabled_cooldowns = {}
                for _,observation in ipairs(observations) do
                    -- A missing observation with no prior announcement has no
                    -- publication side effect. Decide at delivery, after the
                    -- earlier publishers, and retain ordinary accessor dispatch.
                    local announced=publicationRawget(addon,'avail_announced')
                    local inactive=conditionSession and observation.spellid==nil
                        and publicationType(announced)=='table' and publicationMetatable(announced)==nil
                        and publicationRawget(announced,observation.condition.id)==nil
                    if not inactive then
                        if not current() then return end
                        local id,cond=observation.id,observation.condition
                        local spellid,enabled,itemId=observation.spellid,observation.enabled,observation.itemId
                        local previous=addon.avail_announced[cond.id]
                        if previous and (previous~=spellid or not enabled) and not enabled_cooldowns[previous] then
                            disabled_cooldowns[previous]=cond
                        end
                        if spellid then
                            if enabled then
                                addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)
                                if addon.avail_announced[cond.id] ~= spellid then
                                    if not addon.skipAnnounce then
                                        local link = spellLink(spellid)
                                        if delivering then
                                            local message=string.format(L["%s is now available!"],link)
                                            -- This rare receiver still gets a private node.
                                            -- Link/format/log callbacks precede its full fence.
                                            if publicationGuard and not publicationGuard()then deliveryFailed=true;return end
                                            addon:DispatchAnnouncement(cond,message)
                                        else
                                            addon:DispatchAnnouncement(cond, string.format(L["%s is now available!"], link))
                                        end
                                    end
                                    if not current() then return end
                                    addon.avail_announced[cond.id] = spellid;
                                    AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
                                    if not current() then return end
                                end
                                if not enabled_cooldowns[spellid] then
                                    enabled_cooldowns[spellid] = cond
                                    enabled_items[spellid] = itemId
                                    disabled_cooldowns[spellid] = nil
                                end
                            else
                                if addon.avail_announced[cond.id] then
                                    addon.avail_announced[cond.id] = nil;
                                    AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                                end
                                addon:verbose("Cooldown %d [%s] is disabled", id, cond.id)
                                if not enabled_cooldowns[spellid] then
                                    disabled_cooldowns[spellid] = cond
                                end
                            end
                        else
                            if addon.avail_announced[cond.id] then
                                addon.avail_announced[cond.id] = nil;
                                AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                            end
                        end
                    end
                end
                for spellid, cond in pairs(disabled_cooldowns) do
                    if not current() then return end
                    local style=cond
                    if conditionSession then style=presentationViews and presentationViews[cond];if not style then return end end
                    addon:GlowCooldown(spellid, false, style)
                end
                for spellid, cond in pairs(enabled_cooldowns) do
                    if not current() then return end
                    local style=cond
                    if conditionSession then style=presentationViews and presentationViews[cond];if not style then return end end
                    addon:GlowCooldown(spellid, true, style, enabled_items[spellid])
                end
            end)
        end
        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        stage(function() addon.skipAnnounce=false;addon.announced={} end)

        -- Every condition and readiness callback finishes before advice becomes
        -- externally visible. Recheck between publishers too: another addon's
        -- message/glow callback may retire this profile or selected record.
        -- One final execution-source proof before any staged output. Only the
        -- managed graph's scalar/detached deliveries may then use freshness.
        if conditionSession and deliveryLease then
            if not current()or not publicationGuard or not publicationGuard()or not current()then self.evaluationProfile:stop();return end
            delivering=true
        end
        for _,publish in ipairs(staged) do if not current() then break end;publish() end

        self.evaluationProfile:stop()
    end

    if GetTime() - self.lastCacheReport > 15 then
        addon.Functions.cache.ReportCacheStats(addon)
        addon:debug("%s", self.evaluationProfile:report(self.db.profile.detailed_profiling))
        self.evaluationProfile:reset()
        self.lastCacheReport = GetTime()
    end
end

function addon:UpdateCurrentCondition()
    -- Update the live config config .. just to be nice :)
    if self.currentConditionEval ~= nil then
        self.currentConditionEval()
        addon:debug(L["Notified configuration to update it's status."])
    end
end

function addon:GetSpellIds(rot)
    if rot.action then
        if rot.type == BOOKTYPE_SPELL or rot.type == BOOKTYPE_PET or rot.type == "any" then
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if rot.ranked then
                    return { rot.action }
                else
                    return self.SpellCatalog:GetAllSpellIds(rot.action) or {rot.action}
                end
            else
                return { rot.action }
            end
        elseif rot.type == "item" then
            local spellids,itemids={},{}
            local items=rot.action
            if type(items)=="string" then
                local itemset=self.db.profile.itemsets[items] or self.db.global.itemsets[items]
                items=type(itemset)=="table" and itemset.items or nil
            end
            if type(items)=="table" then
                for _,item in ipairs(items) do
                    local use=self.Platform:GetItemUseSpell(item)
                    local itemid=use and self.Platform:GetItemID(item)
                    -- A spell without its item identity cannot be checked for
                    -- ownership/cooldown. Retry unavailable metadata next poll.
                    if use and itemid then
                        spellids[#spellids+1]=use.spellID
                        itemids[#itemids+1]=itemid
                    end
                end
            end
            return spellids, itemids
        end
    end
    return {}
end
if registerActiveRuntimeConsumers then
    registerActiveRuntimeConsumers(addon,addon.GetSpellIds,ownedSequence,mainEnvironment)
end

function addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot)
    if spec == self.currentSpec and rotation == self.currentRotation then
        for _, spellid in pairs(addon:GetSpellIds(rot)) do
            addon:GlowCooldown(spellid, false)
        end
    end
end

function addon:RemoveAllCurrentGlows()
    local spec,id,change=cleanupActive(self)
    if not id then spec,id=self.currentSpec,self.currentRotation end
    local function current() return not change or activeChangeCurrent(self,change) end
    addon:debug(L["Removing all glows."])
    if not current() then return end
    local rotation
    if id then
        local get=self.GetRotationForCleanup
        if not current() then return end
        if getMainCleanupBody then rotation=getMainCleanupBody(self,spec,id,get)
        else rotation=get(self,spec,id) end
    end
    if not current() then return end
    if rotation and rotation.cooldowns then
        for _,rot in pairs(rotation.cooldowns) do
            if not current() then return end
            local getIDs=addon.GetSpellIds
            if not current() then return end
            local ids=getIDs(addon,rot)
            if not current() then return end
            for _,spellid in pairs(ids) do
                if not current() then return end
                local glow=addon.GlowCooldown
                if not current() then return end
                glow(addon,spellid,false)
                if not current() then return end
            end
        end
    end
    if current() then
        local clear=addon.GlowClear
        if current() then clear(addon) end
    end
end

function addon:UpdateSpecSpells()
    return self:RefreshSpellCatalog()
end

function addon:UpdateSkill()
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
    if not activeCall(self,change,'verbose',"Skill update triggered") then return end
    if not activeChangeCurrent(self,change) then return end
    local selection=self.Platform:GetRotationSpecialization()
    local spec=selection and selection.key
    if not activeChangeCurrent(self,change) then return end
    if spec~=self.currentSpec then
        local disable=self.DisableRotation
        if not activeChangeCurrent(self,change) then return end
        local _,nextChange,stopped=disable(self)
        if stopped==false then return end
        change=nextChange or change
        if not activeChangeCurrent(self,change) then return end
        self.manualRotation=false
    end
    change=advanceActiveSpec(self,change,spec)
    if not activeChangeCurrent(self,change) then return end
    self.longtermCache={}
    if invalidateChoiceContext then invalidateChoiceContext(self) end
    if not selection then
        self.autoswitchRotation={}
        return nil,change
    end
    local availableTab=self.specTab
    if not activeChangeCurrent(self,change) then return end
    if availableTab then
        local tab=self.specTab
        if not activeChangeCurrent(self,change) or not activeObjectCall(self,change,tab,'SelectTab',spec) then return end
    end
    if not activeChangeCurrent(self,change) then return end
    if not activeCall(self,change,'UpdateSpecSpells') then return end
    if not activeCall(self,change,'UpdateAutoSwitch') then return end
    local switch=self.SwitchRotation
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=switch(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    if activeCall(self,change,'ButtonFetch') then return nil,change end
end

function addon:GetSpecTalentName(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].name == nil then
        return string.format(L["[Tier: %d, Column: %d]"], floor((idx - 1) / 3) + 1, ((idx - 1) % 3) + 1)
    end

    return self.specTalents[spec][idx].name
end

function addon:GetSpecTalentIcon(spec, idx)
    if idx == nil or idx < 1 or idx > 21 then
        return nil
    end

    if self.specTalents[spec] == nil or self.specTalents[spec][idx] == nil or self.specTalents[spec][idx].icon == nil then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    return self.specTalents[spec][idx].icon
end

function addon:UpdateBoundButton(id)
    if InCombatLockdown and InCombatLockdown() then return false end
    self.updatingBoundButtons=self.updatingBoundButtons or {};if self.updatingBoundButtons[id] then return false end
    self.updatingBoundButtons[id]=true
    local ok,changed=pcall(function()
        local bindings=self.db.char.bindings;local slots=bindings[id];if not slots then return false end
        local itemid=self:FindFirstItemOfItemSet({},id,true);local updated=false
        for index=#slots,1,-1 do local slot=slots[index];local kind,action=GetActionInfo(slot)
            if kind=='item' then
                if itemid and itemid~=action then self:debug('Updated slot %s to new item %d',slot,itemid);PickupItem(itemid);PlaceAction(slot);ClearCursor();updated=true end
            else table.remove(slots,index);updated=true end
        end
        if #slots==0 then bindings[id]=nil end
        if updated then self:ButtonFetch() end;return updated
    end)
    self.updatingBoundButtons[id]=nil;if not ok then error(changed,0) end;return changed
end

-- These notifications may change eligibility facts or their readability. Other
-- event handlers do not invalidate a snapshot of player/session eligibility.
local runtimeContextEvents={PLAYER_LEVEL_UP=true,UNIT_LEVEL=true,PLAYER_ENTERING_WORLD=true,PLAYER_LEAVING_WORLD=true,
    PLAYER_EQUIPMENT_CHANGED=true,
    PLAYER_SPECIALIZATION_CHANGED=true,PLAYER_TALENT_UPDATE=true,ACTIVE_TALENT_GROUP_CHANGED=true,
    CHARACTER_POINTS_CHANGED=true,SPELLS_CHANGED=true,PLAYER_CONTROL_GAINED=true,PLAYER_CONTROL_LOST=true,
    UPDATE_SHAPESHIFT_FORM=true,VEHICLE_UPDATE=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true,
    PLAYER_REGEN_ENABLED=true,PLAYER_REGEN_DISABLED=true}
local function wrapEvent(func)
    local failed = false
    return function(self, event, ...)
        if invalidateEvaluationContext and (event==nil or runtimeContextEvents[event]) then invalidateEvaluationContext() end
        if invalidateChoiceContext and (event==nil or runtimeContextEvents[event]) then invalidateChoiceContext(self) end
        if failed or self.initializationErrorReport then return end
        local function dispatch(...)
            self:debug("Event %s fired.", event)
            return func(self, event, ...)
        end
        if not self.Diagnostics then return dispatch(...) end
        local ok, reportId = self.Diagnostics:Call({module="events", operation="dispatch", event=event,
            rotationId=self.currentRotation}, dispatch, ...)
        if not ok then
            failed = true
            self:StopAdviceForError(reportId)
        end
    end
end

local function wrapCombatEvent(func)
    local dispatch=wrapEvent(func)
    return function(self,...)
        if self.initializationErrorReport or self.Platform:GetClientInfo().combatDataPolicy~='probe' then return end
        return dispatch(self,...)
    end
end

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PARTY_MEMBERS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.PLAYER_FLAGS_CHANGED = wrapEvent(addon.SwitchRotation)
addon.UPDATE_SHAPESHIFT_FORM = wrapEvent(function(self)
    local newForm = GetShapeshiftForm()
    if self.currentForm ~= newForm then
        self.currentForm = newForm
        -- self.skipAnnounce = true
        -- We need the delay because multiple shapeshift events come in at once
        -- and there is no way to know which will be the final one.
        if self.shapeshiftTimer == nil then
            self.shapeshiftTimer = self:ScheduleTimer(function ()
                self.shapeshiftTimer = nil
                self:SwitchRotation()
            end, 0.25)
            self:ButtonFetch()
        end
    end
end)
addon.UPDATE_STEALTH = wrapEvent(addon.SwitchRotation)

function addon:UnbindItemSet(id,expectedItems)
    if InCombatLockdown and InCombatLockdown() then return false end
    local slots=self.db.char.bindings[id] or {};self.db.char.bindings[id]=nil
    for _,slot in ipairs(slots) do
        local kind,item=GetActionInfo(slot)
        if kind=='item' and (expectedItems and self:FindItemInItems(expectedItems,item) or self:FindItemInItemSet(id,item)) and type(PickupAction)=='function' and type(ClearCursor)=='function' then PickupAction(slot);ClearCursor() end
    end
    if self.bindingItemSet==id then self.bindingItemSet=nil end
    if self.EndHighlightSlot then self:EndHighlightSlot() end
    self:ButtonFetch()
    if self.itemSetCallback then self.itemSetCallback(id) end
    return true
end
addon.ACTIONBAR_SLOT_CHANGED = wrapEvent(function(self, _, slot)
    local bindings=self.db.char.bindings;self:ButtonFetch()
    -- Slot zero means the client invalidated the whole bar. Reconcile every
    -- tracked slot, never create a binding to the sentinel itself.
    local cursor,item=GetCursorInfo();local pickup;local changed={}
    for id,slots in pairs(bindings) do
        for i=#slots,1,-1 do local old=slots[i]
            if slot==0 or old==slot then
                local kind,action=GetActionInfo(old)
                if kind~='item' or not self:FindItemInItemSet(id,action) then
                    if old==slot and cursor=='item' and self:FindItemInItemSet(id,item) then pickup=id end
                    table.remove(slots,i);changed[id]=true
                end
            end
        end
        if #slots==0 then bindings[id]=nil end
    end
    local pending=self.bindingItemSet;self.bindingItemSet=nil
    if pending and slot>0 then
        local kind,action=GetActionInfo(slot)
        if kind=='item' and self:FindItemInItemSet(pending,action) then
            local slots=bindings[pending] or {};bindings[pending]=slots;local found=false;for _,value in ipairs(slots) do if value==slot then found=true end end;if not found then slots[#slots+1]=slot end;changed[pending]=true
        end
    end
    if pickup then self.bindingItemSet=pickup end
    for id in pairs(changed) do if bindings[id] and self.FindFirstItemOfItemSet then self:UpdateBoundButton(id) end end
    if self.itemSetCallback then for id in pairs(changed) do self.itemSetCallback(id) end end
end)

addon.PET_BAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_HIDEGRID = wrapEvent(addon.ButtonFetch)
addon.PET_BAR_UPDATE = wrapEvent(addon.ButtonFetch)
addon.ACTIONBAR_PAGE_CHANGED = wrapEvent(addon.ButtonFetch)
addon.UPDATE_MACROS = wrapEvent(addon.ButtonFetch)
addon.VEHICLE_UPDATE = wrapEvent(function(self)
    restoreManualChoice(self)
    self:ButtonFetch()
end)

addon.PLAYER_TARGET_CHANGED = wrapEvent(function(self)
    self:verbose("Player targeted something else.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self.lastMainSwing = nil
    self.lastOffSwing = nil

    self:EvaluateNextAction()
end)

addon.PLAYER_FOCUS_CHANGED = addon.PLAYER_TARGET_CHANGED

addon.UNIT_PET = wrapEvent(function(self, _, unit)
    -- UNIT_PET identifies the pet owner, not the changed pet unit.
    if unit == "player" then
        self:verbose("Player %s changed pet.", unit)
        self:UpdateSpecSpells()

        if not self.inCombat then
            self:SwitchRotation()
        end

        self:EvaluateNextAction()
    end
end)

addon.PLAYER_CONTROL_GAINED = wrapEvent(function(self)
    restoreManualChoice(self)
    self:verbose("Player regained control.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self:EnableRotationTimer()
    self:EvaluateNextAction()
end)

addon.PLAYER_CONTROL_LOST = wrapEvent(function(self)
    self:verbose("Player lost control.")
    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
end)

addon.PLAYER_TALENT_UPDATE = wrapEvent(addon.UpdateSkill)
addon.ACTIVE_TALENT_GROUP_CHANGED = wrapEvent(addon.UpdateSkill)
-- BEGIN EQUIPMENT EVENT DISPATCH
local equipmentEvent = wrapEvent(function(self,_,subscription,profile,change)
    if self~=addon or equipmentSubscription~=subscription or self.db.profile~=profile
        or not activeChangeCurrent(self,change) then return end
    local coordinator
    if self.GetScopedRotationCoordinator~=equipmentCoordinator or not activeChangeCurrent(self,change) then return end
    if equipmentCoordinator then coordinator=equipmentCoordinator(self) end
    local function current()
        if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription
            or self.db.profile~=profile or self.GetScopedRotationCoordinator~=equipmentCoordinator then return false end
        if equipmentCoordinator and equipmentCoordinator(self)~=coordinator then return false end
        return self.db.profile==profile and self.GetScopedRotationCoordinator==equipmentCoordinator
            and activeChangeCurrent(self,change) and equipmentSubscription==subscription
    end
    if not current() or self.enabledState~=true or not current() then return end
    local switch=self.SwitchRotation
    if not current() or type(switch)~='function' then return end
    local _,nextChange=switch(self);change=nextChange or change
    if not current() or self.currentRotation==nil then return end
    local evaluate=self.EvaluateNextAction
    if current() and type(evaluate)=='function' then evaluate(self) end
end)
addon.PLAYER_EQUIPMENT_CHANGED=function(self,event)
    local subscription=equipmentSubscription
    if not rawequal(self,addon) or not subscription or self.enabledState~=true then return end
    local profile=self.db.profile
    if equipmentSubscription~=subscription or type(profile)~='table' then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription or self.db.profile~=profile then return end
    return equipmentEvent(self,event,subscription,profile,change)
end
-- END EQUIPMENT EVENT DISPATCH
addon.SPELLS_CHANGED = wrapEvent(addon.UpdateSkill)
local function invalidatePlayerLevel(self)
    if type(self.longtermCache)~='table' then return end
    self.longtermCache.conditionPlayerLevel=nil
    -- Saved raw condition sources may still use the native cache identity.
    local native=type(UnitLevel)=='function' and self.longtermCache[UnitLevel]
    if type(native)=='table' then native.player=nil end
end

addon.PLAYER_LEVEL_UP = wrapEvent(function(self)
    invalidatePlayerLevel(self)
    -- Level facts can still be old while the event is being dispatched.
    self:ScheduleTimer(function()
        invalidatePlayerLevel(self)
        self:UpdateAutoSwitch()
        self:SwitchRotation()
        if self.currentRotation then self:EvaluateNextAction() end
    end,0.01)
end)
addon.CHARACTER_POINTS_CHANGED = wrapEvent(addon.UpdateSkill)
addon.PLAYER_SPECIALIZATION_CHANGED = wrapEvent(addon.UpdateSkill)

addon.ZONE_CHANGED = wrapEvent(function(self)
    addon:verbose("Player switched zones.")
    if not self.inCombat then
        self:SwitchRotation()
    end
end)

addon.ZONE_CHANGED_INDOORS = addon.ZONE_CHANGED
addon.GROUP_ROSTER_UPDATE = addon.ZONE_CHANGED

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

addon.PLAYER_REGEN_DISABLED = wrapEvent(function(self)
    self:verbose("Player is in combat.")
    self.inCombat = true
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.combatCache = {}
    self.combatStart = GetTime()
end)

addon.PLAYER_REGEN_ENABLED = wrapEvent(function(self)
    self:verbose("Player is out of combat.")
    self.inCombat = false
    self.lastMainSwing = nil
    self.lastOffSwing = nil
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

addon.UNIT_ENTERED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player on a vehicle.")
        self.PLAYER_CONTROL_LOST(self, event)
    end
end)

addon.UNIT_EXITED_VEHICLE = wrapEvent(function(self, event, unit)
    if unit == "player" then
        self:verbose("Player off a vehicle.")
        self.PLAYER_CONTROL_GAINED(self, event)
    end
end)

-- Nameplate removal can arrive after its token stops resolving. Retire by the
-- stored token; preserve only a positively identified canonical replacement.
local nameplateEvent
local function nameplateCurrent(self,snapshot,ticket)
    return self.unitsInRange==snapshot and nameplateEvent==ticket
end
local function nameplateReadable(self,snapshot,ticket,value)
    local readable=self.Platform:CanReadValue(value)
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    return not not readable
end
local function nameplateGUID(self,snapshot,ticket,unit)
    local ok,guid=pcall(UnitGUID,unit)
    if not nameplateCurrent(self,snapshot,ticket) or not ok then return nil end
    if not nameplateReadable(self,snapshot,ticket,guid) then return nil end
    if canaccessvalue and type(canaccessvalue)~="function" then return nil end
    if canaccessvalue and not canaccessvalue(guid) then return nil end
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    if type(guid)=="string" and guid~="" then return guid end
end
local function nameplateChanges(self,snapshot,ticket,unit,keep)
    -- Provider calls can reenter these handlers and mutate public maps. Finish
    -- copying their keys before calling any provider or readability function.
    local entries,changes={},{}
    for guid,entry in pairs(snapshot) do entries[#entries+1]={guid=guid,entry=entry} end
    for _,change in ipairs(entries) do
        local entry=change.entry
        if type(entry)=="table" and getmetatable(entry)==nil then
            local stored=rawget(entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return nil end
            if readable and type(stored)=="string" and stored==unit then
                readable=nameplateReadable(self,snapshot,ticket,change.guid)
                if readable==nil then return nil end
                if readable and type(change.guid)=="string" and change.guid~=keep then changes[#changes+1]=change end
            end
        end
    end
    if #changes==0 then return changes end
    local units,aliases={},{}
    for alias in pairs(addon.units) do units[#units+1]=alias end
    for _,alias in ipairs(units) do
        local readable=nameplateReadable(self,snapshot,ticket,alias)
        if readable==nil then return nil end
        if readable and type(alias)=="string" and alias~=unit then
            local guid=nameplateGUID(self,snapshot,ticket,alias)
            if not nameplateCurrent(self,snapshot,ticket) then return nil end
            if guid and not aliases[guid] then aliases[guid]=alias end
        end
    end
    for _,change in ipairs(changes) do change.alias=aliases[change.guid] end
    return changes
end
local function nameplateStoredMatches(entry,stored)
    return rawget(entry,"unit")==stored
end
local function applyNameplateChanges(self,snapshot,ticket,unit,changes)
    for _,change in ipairs(changes) do
        if rawget(snapshot,change.guid)==change.entry then
            local stored=rawget(change.entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return false end
            if readable and type(stored)=="string" and stored==unit then
                -- A readability callback may directly replace the field. Never
                -- compare a newly restricted value outside a protected read.
                local ok,unchanged=pcall(nameplateStoredMatches,change.entry,stored)
                if ok and unchanged and rawget(snapshot,change.guid)==change.entry then
                    if change.alias then rawset(change.entry,"unit",change.alias)
                    else rawset(snapshot,change.guid,nil) end
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
local kind,meta,read,write,same,nextEntry,items,protected,raise,match=
    type,getmetatable,rawget,rawset,rawequal,next,ipairs,pcall,error,string.match
reconcileNameplateResume=function(self,change)
    local snapshot=self.unitsInRange
    if kind(snapshot)~="table" or meta(snapshot)~=nil then return end
    local ticket={};nameplateEvent=ticket
    local db,profile=self.db,self.db.profile
    local function current()
        return nameplateCurrent(self,snapshot,ticket) and self.db==db and db.profile==profile
            and kind(activeCurrent)=="function" and activeCurrent(self,change)
    end
    -- Native/frame/readability failures leave the complete old map intact.
    -- All writes below occur after the last callback and exact slot checks.
    protected(function()
        local function requireCurrent() if not current() then raise("stale nameplate resume",0) end end
        local function readable(value)
            requireCurrent()
            if not self.Platform:CanReadValue(value) then raise("unreadable nameplate resume",0) end
            requireCurrent()
            if canaccessvalue then
                if kind(canaccessvalue)~="function" or not canaccessvalue(value) then raise("restricted nameplate resume",0) end
                requireCurrent()
            end
            return value
        end
        local function observe(fn,...)
            requireCurrent()
            if kind(fn)~="function" then raise("missing nameplate resume provider",0) end
            local value=fn(...)
            requireCurrent()
            return readable(value)
        end
        local old,proposed,retargets,observations,frames={},{},{},{},{}
        for guid,entry in nextEntry,snapshot do
            old[#old+1]={guid=guid,entry=entry,meta=kind(entry)=="table" and meta(entry) or nil,unit=kind(entry)=="table" and meta(entry)==nil and read(entry,"unit") or nil}
            proposed[guid]=entry
        end
        local aliases={}
        local units={}
        for unit in nextEntry,addon.units do units[#units+1]=unit end
        local function guidFor(unit)
            local guid=observe(UnitGUID,unit)
            if guid~=nil and (kind(guid)~="string" or guid=="") then raise("unknown nameplate GUID",0) end
            observations[#observations+1]={unit=unit,guid=guid}
            return guid
        end
        for _,unit in items(units) do
            readable(unit)
            if kind(unit)~="string" then raise("unknown canonical unit",0) end
            local guid=guidFor(unit)
            if guid and not aliases[guid] then aliases[guid]=unit end
        end
        local api=C_NamePlate
        if kind(api)~="table" then return end
        local listed=observe(api.GetNamePlates)
        if kind(listed)~="table" or meta(listed)~=nil then return end
        local members={}
        for _,frame in nextEntry,listed do members[#members+1]=frame end
        for _,frame in items(members) do
            readable(frame)
            if observe(frame.IsForbidden,frame)~=false then return end
            local unit=observe(frame.GetUnit,frame)
            if kind(unit)~="string" or not match(unit,"^nameplate%d+$") then return end
            local guid=guidFor(unit)
            if not guid then return end
            frames[#frames+1]={frame=frame,unit=unit,guid=guid}
        end
        for _,item in items(old) do
            local unit=readable(item.unit)
            if kind(unit)=="string" and match(unit,"^nameplate%d+$") then
                readable(item.guid)
                local guid=guidFor(unit)
                local obsolete=guid~=nil and guid~=item.guid
                if guid==nil then
                    local exists=observe(UnitExists,unit)
                    if kind(exists)~="boolean" then return end
                    observations[#observations].exists=exists
                    obsolete=exists==false
                end
                if obsolete then
                    if aliases[item.guid] then retargets[item.entry]=aliases[item.guid]
                    else proposed[item.guid]=nil end
                end
            end
        end
        for _,item in items(frames) do
            local entry=proposed[item.guid]
            if entry~=nil and (kind(entry)~="table" or meta(entry)~=nil) then return end
            if not entry then
                entry=CreateUnitInfo({},item.unit)
                requireCurrent()
            end
            proposed[item.guid]=entry
            retargets[entry]=item.unit
        end
        for _,item in items(observations) do
            if observe(UnitGUID,item.unit)~=item.guid then return end
            if item.exists~=nil and observe(UnitExists,item.unit)~=item.exists then return end
        end
        for _,item in items(old) do
            readable(item.guid);readable(item.unit)
        end
        -- Readability/GUID callbacks above can also recycle pooled frames.
        -- Check their current binding last, then commit without more providers.
        for _,item in items(frames) do
            if observe(item.frame.IsForbidden,item.frame)~=false or observe(item.frame.GetUnit,item.frame)~=item.unit then return end
        end
        requireCurrent()
        if meta(snapshot)~=nil then return end
        local count=0
        for _ in nextEntry,snapshot do count=count+1 end
        if count~=#old then return end
        for _,item in items(old) do
            if not same(read(snapshot,item.guid),item.entry) then return end
            if kind(item.entry)=="table" then
                if meta(item.entry)~=item.meta then return end
                if item.meta==nil and read(item.entry,"unit")~=item.unit then return end
            end
        end
        requireCurrent()
        for entry,unit in nextEntry,retargets do write(entry,"unit",unit) end
        for _,item in items(old) do if proposed[item.guid]==nil then write(snapshot,item.guid,nil) end end
        for guid,entry in nextEntry,proposed do write(snapshot,guid,entry) end
    end)
end

end

addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local guid=nameplateGUID(self,snapshot,ticket,unit);if not guid then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit,guid);if not changes then return end
    local previous=rawget(snapshot,guid)
    if previous~=nil and (type(previous)~="table" or getmetatable(previous)~=nil) then return end
    local previousUnit=previous and rawget(previous,"unit")
    if previous and (not nameplateReadable(self,snapshot,ticket,previousUnit) or type(previousUnit)~="string") then return end
    local entry=previous or CreateUnitInfo({},unit)
    if not nameplateCurrent(self,snapshot,ticket) then return end
    if not applyNameplateChanges(self,snapshot,ticket,unit,changes) then return end
    local current=rawget(snapshot,guid)
    if type(current)~=type(previous) or not rawequal(current,previous) then return end
    if previous then
        local ok,unchanged=pcall(nameplateStoredMatches,previous,previousUnit)
        if not ok or not unchanged then return end
    end
    rawset(entry,"unit",unit);rawset(snapshot,guid,entry)
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit);if not changes then return end
    if not nameplateCurrent(self,snapshot,ticket) then return end
    applyNameplateChanges(self,snapshot,ticket,unit,changes)
end)

addon.BAG_UPDATE = wrapEvent(function(self)
    local bindings = self.db.char.bindings

    for id, _ in pairs(bindings) do
        self:UpdateBoundButton(id)
    end

    self:UpdateBagContents()
end)

addon.UNIT_COMBAT = wrapCombatEvent(function(self, _, unit, action, severity, value, type)
    if self.combatHistory[unit] == nil then
        self.combatHistory[unit] = {}
    end

    table.insert(self.combatHistory[unit], 1, {
        time = GetTime(),
        action = action,
        severity = severity,
        value = value,
        type = type,
    })
end)

local currentSpells = {}
local lastCastTarget = {} -- work around UNIT_SPELLCAST_SENT not always triggering
local currentChannel

local function spellcast(self, event, unit, castguid, spellid)
    -- even though we check it later, this skips rows entirely.
    if unit == 'player' or unit == "pet" then
        -- BEGIN ANNOUNCEMENT CONDITION OWNER
        local profile=self.db.profile
        local announcements=profile.announces
        for index, value in ipairs(announcements) do
        -- END ANNOUNCEMENT CONDITION OWNER
            if value.type~='macro' and (value.outputs~=nil or value.value or value.announce == "audible" or value.announce == "gesture") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
                (event == "UNIT_SPELLCAST_" .. value.event or event == "UNIT_SPELLCAST_CHANNEL_" .. value.event) then
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
                    local registry=self.conditionRegistryVersion
                    local seriesRecipient=currentSpells[castguid]
                    local seriesLifecycle=value.outputs~=nil and self.IsEnabled or nil
                    local function seriesEnabled()
                        if value.outputs==nil then return true end
                        if self.IsEnabled~=seriesLifecycle then return false end
                        if seriesLifecycle~=nil then
                            if type(seriesLifecycle)~='function' then return false end
                            local ok,enabled=pcall(seriesLifecycle,self)
                            if not ok or enabled~=true then return false end
                        end
                        local state=rawget(self,'enabledState')
                        return self.IsEnabled==seriesLifecycle and rawget(self,'enabledState')==state and (state==nil or state==true)
                    end
                    local ent,current=self:PrepareAnnouncementDelivery(value,function()
                        return seriesEnabled() and self.db.profile==profile and profile.announces==announcements
                            and announcements[index]==value and not value.disabled
                            and self.conditionRegistryVersion==registry
                            and (value.outputs==nil or currentSpells[castguid]==seriesRecipient)
                    end)
                    if ent and current() and (ent.outputs==nil or self:IsValidAnnouncement(value) and current()) then
                    -- END ANNOUNCEMENT CONDITION LEASE
                    local spellids, itemids = self:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
                            if ent.outputs~=nil then
                                if not current() then return end
                                -- Reserve the parent once before any card callback.
                                if self.announced[ent.id]==nil then self.announced[ent.id]={castguid}
                                else table.insert(self.announced[ent.id],castguid) end
                                self:DispatchAnnouncementSeries(ent,seriesRecipient,current,nil,function(card,live)
                                    local text=card.value or ''
                                    local link,itemLink
                                    if text:find('{{target}}',1,true) and not seriesRecipient then return nil end
                                    if text:find('{{spell}}',1,true) then
                                        if ent.type~=BOOKTYPE_SPELL and ent.type~=BOOKTYPE_PET then return nil end
                                        link=spellLink(sid)
                                        if type(link)~='string' or not live() then return nil end
                                    end
                                    if text:find('{{item}}',1,true) then
                                        if ent.type~='item' then return nil end
                                        local info=self.Platform:GetItemDisplayInfo(itemids[idx])
                                        itemLink=info and info.link
                                        if type(itemLink)~='string' or not live() then return nil end
                                    end
                                    return text:gsub('{{target}}',function()return seriesRecipient end)
                                        :gsub('{{spell}}',function()return link end):gsub('{{item}}',function()return itemLink end)
                                        :gsub('{{event}}',function()return self.events[ent.event]end)
                                end)
                            else
                            -- BEGIN ANNOUNCEMENT CONDITION MATCH
                            if self:AnnouncementConditionMatches(ent,currentSpells[castguid],current) then
                            -- END ANNOUNCEMENT CONDITION MATCH
                            local text = ent.value or ""
                            if ent.announce~='audible' and ent.announce~='gesture' then
                            if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                                local link = spellLink(sid)
                                text = text:gsub("{{spell}}", link)
                            elseif ent.type == "item" then
                                local info = self.Platform:GetItemDisplayInfo(itemids[idx])
                                local link = info and info.link
                                if type(link)=="string" then text = text:gsub("{{item}}", function() return link end) end
                            end
                            text = text:gsub("{{event}}", self.events[ent.event])
                            if currentSpells[castguid] or lastCastTarget[spellid] then
                                text = text:gsub("{{target}}", currentSpells[castguid] or lastCastTarget[spellid])
                            end
                            end
                            if not current() then return end -- ANNOUNCEMENT CONDITION BEFORE OUTPUT
                            -- Reserve before any output callback can reenter this cast.
                            if self.announced[ent.id] == nil then
                                self.announced[ent.id] = { castguid }
                            else
                                table.insert(self.announced[ent.id], castguid)
                            end
                            if ent.announce=='gesture' then self:DispatchAnnouncement(ent,nil,currentSpells[castguid],current)
                            else self:DispatchAnnouncement(ent,text,nil,current) end
                            end -- ANNOUNCEMENT CONDITION OUTPUT
                            end -- ANNOUNCEMENT SERIES OR LEGACY
                            break
                        end
                    end
                    end -- ANNOUNCEMENT CONDITION LEASE
                end
            end
        end
    end
end

addon.UNIT_SPELLCAST_START = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_STOP = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        currentSpells[castguid] = nil
        self.lastMainSwing = nil
        self.lastOffSwing = nil
    end
end)
addon.UNIT_SPELLCAST_SUCCEEDED = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        if currentChannel then
            currentChannel = castguid
        end
    end
    if unit == 'player' or unit == 'pet' then
        table.insert(self.spellHistory, 1, {
            spell = spellid, --[[ this was causing spellid to be nil in spellHistory, breaking the spell history conditions. ]]
            time = GetTime()
        })
    end
end)
addon.UNIT_SPELLCAST_INTERRUPTED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_FAILED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_DELAYED = wrapCombatEvent(spellcast)
addon.UNIT_SPELLCAST_CHANNEL_START = wrapCombatEvent(function(self, event, unit, castguid, spellid)
    spellcast(self, event, unit, castguid, spellid)
    if unit == 'player' then
        currentChannel = true
    end
end)
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

addon.UNIT_SPELLCAST_SENT = wrapCombatEvent(function(_, _, unit, target, castguid, spellid)
    if (unit == 'player') then
        currentSpells[castguid] = target
        lastCastTarget[spellid] = target
    end
end)

local function handle_combat_log(_, event, _, sourceGUID, _, _, _, destGUID, _, _, _, ...)
    local spellid, spellname, envType
    local offs = 1
    if event:sub(1, 5) == "SPELL" or event:sub(1, 5) == "RANGE" then
        spellid, spellname = ...
        offs = 4
    elseif event:sub(1, 5) == "ENVIRONMENTAL" then
        envType = ...
        offs = 2
    elseif event == "SWING_MISSED" and sourceGUID == playerGUID then
        local offhand = select(2, ...)
        if offhand then
            addon.lastOffSwing = GetTime()
        else
            addon.lastMainSwing = GetTime()
        end
    end

    if event:sub(-5) == "_HEAL" then
        local amount = select(offs, ...)
        if not addon.damageHistory[destGUID] then
            addon.damageHistory[destGUID] = {
                damage = {},
                heals = {},
            }
        end
        table.insert(addon.damageHistory[destGUID].heals, 1, {
            time = GetTime(),
            value = tonumber(amount),
        })
    elseif event:sub(-7) == "_DAMAGE" then
        if event:sub(1, 5) == "SWING" and sourceGUID == playerGUID then
            local offhand = select(10, ...)
            if offhand then
                addon.lastOffSwing = GetTime()
            else
                addon.lastMainSwing = GetTime()
            end
        end

        local amount = select(offs, ...)
        if not addon.damageHistory[destGUID] then
            addon.damageHistory[destGUID] = {
                damage = {},
                heals = {},
            }
        end
        table.insert(addon.damageHistory[destGUID].damage, 1, {
            time = GetTime(),
            value = tonumber(amount),
        })
    end
end
addon.COMBAT_LOG_EVENT_UNFILTERED = wrapCombatEvent(function() handle_combat_log(CombatLogGetCurrentEventInfo()) end)

addon.SPELL_DATA_LOAD_RESULT = wrapEvent(function(_, _, spellId, success)
    if success then
        addon.SpellCatalog:UpdateSpell(spellId)
    end
end)

addon.ITEM_DATA_LOAD_RESULT = wrapEvent(function(_, _, itemId, success)
    if success then
        addon:UpdateReferenceItem(itemId)
    end
end)
-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'main',addon.EvaluateNextActionInternal,function() return UpdateUnitInfo end) end
end
-- END CPU RUNTIME WORK HANDOFF
]========],
    },
    ["buttons.lua"] = {
        before = [========[-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end
addon.ConsumeClientPolicyReader=nil
-- The active-plan receiver is consumed before any library callback. Only the
-- literal cooldown publisher below may qualify its private presentation route.
---@type fun(...): any
local publishActivePresentation=addon.BindActiveRuntimePresentationSource
addon.BindActiveRuntimePresentationSource=nil
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local CustomGlow = LibStub("LibCustomGlow-1.0")

local procSupport,procProbe
local function methods(value,names)
    for _,name in ipairs(names) do if type(value[name])~='function' then return false end end
    return true
end
local function probeProcGlow(atlas)
    for _,name in ipairs({'UI-HUD-ActionBar-Proc-Start-Flipbook','UI-HUD-ActionBar-Proc-Loop-Flipbook'}) do
        if type(atlas(name))~='table' then return false end
    end
    if not procProbe then procProbe=CreateFrame('Frame',nil,UIParent);procProbe:Hide();procProbe:SetSize(40,40) end
    local texture=procProbe:CreateTexture(nil,'ARTWORK');if type(texture.SetAtlas)~='function' then return false end
    texture:SetAtlas('UI-HUD-ActionBar-Proc-Start-Flipbook');texture:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
    procProbe.ProcLoop=texture
    local group=procProbe:CreateAnimationGroup()
    if not methods(group,{'Stop','Play','IsPlaying','SetLooping','SetToFinalAlpha','SetScript'}) then return false end
    group:SetLooping('REPEAT');group:SetToFinalAlpha(true)
    local alpha=group:CreateAnimation('Alpha')
    if not methods(alpha,{'SetChildKey','SetDuration','SetOrder','SetFromAlpha','SetToAlpha'}) then return false end
    alpha:SetChildKey('ProcLoop');alpha:SetDuration(.001);alpha:SetOrder(0);alpha:SetFromAlpha(1);alpha:SetToAlpha(1)
    local flipbook=group:CreateAnimation('FlipBook')
    if not methods(flipbook,{'SetChildKey','SetDuration','SetOrder','SetFlipBookRows','SetFlipBookColumns','SetFlipBookFrames','SetFlipBookFrameWidth','SetFlipBookFrameHeight'}) then return false end
    flipbook:SetChildKey('ProcLoop');flipbook:SetDuration(1);flipbook:SetOrder(0)
    flipbook:SetFlipBookRows(6);flipbook:SetFlipBookColumns(5);flipbook:SetFlipBookFrames(30);flipbook:SetFlipBookFrameWidth(0);flipbook:SetFlipBookFrameHeight(0)
    group:Stop();return true
end
-- Method names alone do not establish animation/atlas support on Classic.
-- This hidden probe never plays, and stable capabilities need no warm allocation.
function addon:GetProcGlowSupport()
    local atlas=C_Texture and C_Texture.GetAtlasInfo or rawget(_G,'GetAtlasInfo')
    if procSupport and procSupport.atlas==atlas and procSupport.create==CreateFrame
        and procSupport.start==CustomGlow.ProcGlow_Start and procSupport.stop==CustomGlow.ProcGlow_Stop then return procSupport.available end
    procSupport={atlas=atlas,create=CreateFrame,start=CustomGlow.ProcGlow_Start,stop=CustomGlow.ProcGlow_Stop,available=false}
    if type(atlas)=='function' and type(CreateFrame)=='function' and type(procSupport.start)=='function' and type(procSupport.stop)=='function' then
        local ok,value=pcall(probeProcGlow,atlas);procSupport.available=ok and value==true
    end
    return procSupport.available
end

local function spellMetadataID(spell)
    local info=addon.Platform:GetSpellInfo(spell)
    return info and info.spellID
end
local function itemUseSpellID(item)
    local info=addon.Platform:GetItemUseSpell(item)
    return info and info.spellID
end

local Spells = {}
local ButtonItems = {}
local ButtonSpells = {}
local MacroButtons = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}

local HighlightOverlay = {
	type = "dazzle",
	texture = "Interface\\Cooldown\\star4",
	frequency = 0.1,
	sequence = {
		{ r = 1.00, g = 0.00, b = 0.00, a = 1 },
		{ r = 0.75, g = 0.25, b = 0.00, a = 1 },
		{ r = 0.50, g = 0.50, b = 0.00, a = 1 },
		{ r = 0.25, g = 0.75, b = 0.00, a = 1 },
		{ r = 0.00, g = 1.00, b = 0.00, a = 1 },
		{ r = 0.00, g = 0.75, b = 0.25, a = 1 },
		{ r = 0.00, g = 0.50, b = 0.50, a = 1 },
		{ r = 0.00, g = 0.25, b = 0.75, a = 1 },
		{ r = 0.00, g = 0.00, b = 1.00, a = 1 },
		{ r = 0.25, g = 0.00, b = 0.75, a = 1 },
		{ r = 0.50, g = 0.00, b = 0.50, a = 1 },
		{ r = 0.75, g = 0.00, b = 0.25, a = 1 },
	}
}
local Highlight = {}

addon.textured_types = { "texture", "dazzle", "animate", "pulse", "rotate", "custom" }

function addon:ApplyCustomGlow(effect, frame, id, color, xoffs, yoffs)
    local c
	if color ~= nil then
		c = { color.r, color.g, color.b, color.a }
	end
	if effect.type == "pixel" then
		CustomGlow.PixelGlow_Start(frame, c, effect.lines, effect.frequency, effect.length, effect.thickness, xoffs, yoffs, false, id)
	elseif effect.type == "autocast" then
		CustomGlow.AutoCastGlow_Start(frame, c, effect.particles, effect.frequency, effect.scale, xoffs, yoffs, id)
	elseif effect.type == "blizzard" then
		CustomGlow.ButtonGlow_Start(frame, c, effect.frequency)
	elseif effect.type == 'proc' then
        if self:GetProcGlowSupport() then
            local duration=effect.duration
            if type(duration)~='number' or duration~=duration or duration<.1 or duration>5 then duration=1 end
            local ok=pcall(CustomGlow.ProcGlow_Start,frame,{key=tostring(id or ''),color=c,duration=duration,startAnim=effect.startAnim==true,xOffset=xoffs or 0,yOffset=yoffs or 0})
            if ok then return end
            procSupport.available=false
        end
        -- Another frame may have retired shared support while this key was lit.
        if type(CustomGlow.ProcGlow_Stop)=='function' then pcall(CustomGlow.ProcGlow_Stop,frame,tostring(id or '')) end
        CustomGlow.PixelGlow_Start(frame,c,nil,nil,nil,nil,xoffs,yoffs,false,id)
	end
end

local function InvalidateOverlay(frame)
    frame.rmOverlayGeneration=(frame.rmOverlayGeneration or 0)+1
    frame.rmOverlayDirty=true
    frame.rmOverlayParent=nil
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs, angle)
    local generation=frame.rmOverlayGeneration
    -- Native size scripts can alter any earlier render channel. These frames
    -- keep the complete legacy write path; sample the script each tick so late
    -- registration is covered without an observer or new subscription.
    local sizeScript=frame:GetScript('OnSizeChanged')~=nil
    local parent=frame:GetParent()
    if frame.rmOverlayGeneration~=generation then return false end
    local dirty=frame.rmOverlayDirty~=false or sizeScript
    if dirty or frame.rmOverlayParent~=parent or frame.rmOverlayPoint~=setp
        or frame.rmOverlayX~=xoffs or frame.rmOverlayY~=yoffs then
        -- Native geometry setters may synchronously alter later geometry or
        -- paint channels. Keep the remainder of this invocation on the legacy
        -- write path; only stable geometry can skip unchanged paint channels.
        dirty=true
        frame:ClearAllPoints()
        if frame.rmOverlayGeneration~=generation then return false end
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
        frame:SetPoint("CENTER",parent,setp,xoffs,yoffs)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayParent,frame.rmOverlayPoint=parent,setp
        frame.rmOverlayX,frame.rmOverlayY=xoffs,yoffs
        -- Anchor setters can invoke native callbacks which reparent the frame.
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local sizeChanged=false
    local width=parent:GetWidth() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayWidth~=width then
        dirty=true
        frame:SetWidth(width)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    -- Size setters can dispatch native OnSizeChanged callbacks. Read later
    -- inputs only after those callbacks, just as the original renderer did.
    local height=parent:GetHeight() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayHeight~=height then
        dirty=true
        frame:SetHeight(height)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
    end
    if sizeChanged then
        -- A size callback can change either dimension again. Cache the final
        -- native dimensions so the next tick corrects any request disagreement.
        frame.rmOverlayWidth,frame.rmOverlayHeight=frame:GetWidth(),frame:GetHeight()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local r,g,b,a=color.r,color.g,color.b,color.a
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayR~=r or frame.rmOverlayG~=g or frame.rmOverlayB~=b or frame.rmOverlayA~=a then
        frame.texture:SetVertexColor(r,g,b,a)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayR,frame.rmOverlayG,frame.rmOverlayB,frame.rmOverlayA=r,g,b,a
    end
    if effect and (dirty or frame.rmOverlayTexture~=effect) then
        frame.texture:SetTexture(effect)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayTexture=effect
    end
    if angle and (dirty or frame.rmOverlayAngle~=angle) then
        frame.texture:SetRotation(angle)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayAngle=angle
    end
    -- Leave a final repaint pending after the script is removed.
    frame.rmOverlayDirty=sizeScript
    return true
end

local function StopOverlay(frame)
	InvalidateOverlay(frame)
	if frame.sequenceTimer then
		addon:CancelTimer(frame.sequenceTimer)
		frame.sequenceTimer = nil
	end
	frame.sequenceIdx = nil
end

function addon:HideGlow(frame, id, keepProc)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
    if not keepProc and type(CustomGlow.ProcGlow_Stop)=='function' then CustomGlow.ProcGlow_Stop(frame,tostring(id or '')) end
	if id ~= nil and frame.rmOverlays and frame.rmOverlays[id] then
		StopOverlay(frame.rmOverlays[id])
		frame.rmOverlays[id]:Hide()
	end
end

local function UpdateOverlay(frame, effect, color, mags, setp, xoffs, yoffs, angle)
	local type =  effect.type
    if type == "texture" then
        return UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, angle)
	elseif type == "rotate" and effect.steps and effect.steps > 0 then
		if frame.sequenceIdx then
			frame.sequenceIdx = frame.sequenceIdx >= effect.steps and 1 or (frame.sequenceIdx + 1)
		else
			frame.sequenceIdx = 1
		end
        if effect.reverse then
            if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (effect.steps - (frame.sequenceIdx - 1)))) then return false end
		else
			if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (frame.sequenceIdx - 1))) then return false end
        end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
					frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	elseif effect.sequence and #effect.sequence > 0 then
        local sequence = effect.sequence
        if frame.sequenceIdx then
            frame.sequenceIdx = frame.sequenceIdx >= #sequence and 1 or (frame.sequenceIdx + 1)
        else
            frame.sequenceIdx = 1
        end
        if type == "dazzle" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, sequence[frame.sequenceIdx], mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "animate" then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx], color, mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "pulse" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, color, sequence[frame.sequenceIdx], setp, xoffs, yoffs, angle) then return false end
		elseif type == "custom" and sequence[frame.sequenceIdx].texture and sequence[frame.sequenceIdx].color and sequence[frame.sequenceIdx].magnification then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx].texture, sequence[frame.sequenceIdx].color, sequence[frame.sequenceIdx].magnification, setp, xoffs, yoffs, math.rad(sequence[frame.sequenceIdx].angle or 0)) then return false end
		else
            StopOverlay(frame)
			return false
		end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
				frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	end
    return false
end

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
local function CreateOverlay(parent)
	local frame = tremove(FramePool)
	if not frame then
		frame = CreateFrame('Frame', addon_name .. '_Overlay_' .. addon.uuid(), parent)
	else
		frame:SetParent(parent)
	end
	InvalidateOverlay(frame)

	frame:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'HIGH')
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()+1) end

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)
	return frame
end

local function DestroyOverlay(frame, id)
	StopOverlay(frame)
	if frame:GetParent().rmOverlays ~= nil and frame:GetParent().rmOverlays[id] then
		frame:GetParent().rmOverlays[id] = nil
	end
	frame:ClearAllPoints()
	frame:Hide()
	frame:SetParent(UIParent)
	frame.width = nil
	frame.height = nil

	tinsert(FramePool, frame)
end

local function DestroyAllOverlay(parent)
	if parent.rmOverlays ~= nil then
		for id,frame in pairs(parent.rmOverlays) do
			DestroyOverlay(frame, id)
		end
		parent.rmOverlays = nil
	end
end

function addon:DestroyAllGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, spellid)
				DestroyAllOverlay(button)
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, "next")
				DestroyAllOverlay(button)
			end
		end
	end
end

function addon:UpdateButtonGlow()
	local LAB
	local LBG
	local origShow
	local noFunction = function() end

	if IsAddOnLoaded('ElvUI') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0-ElvUI')
		LBG = LibStub:GetLibrary('LibCustomGlow-1.0')
		origShow = LBG.ShowOverlayGlow
	elseif IsAddOnLoaded('Bartender4') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0')
	end

	if self.db.global.disableButtonGlow then
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow
		end
	end
end

function addon:Glow(button, id, effect, color, mags, setp, xoffs, yoffs, angle)
	if not effect then
		return
	end

    color=self:ResolveHighlightColor(color)

	local type = effect.type
	addon:HideGlow(button, id, type=='proc')
	if addon.Functions.collections.index(addon.textured_types, type) then
		if not button.rmOverlays then
			button.rmOverlays = {}
		end
		if not button.rmOverlays[id] then
			button.rmOverlays[id] = CreateOverlay(button, id)
		end

        if UpdateOverlay(button.rmOverlays[id], effect, color, mags, setp, xoffs, yoffs, angle) then
            button.rmOverlays[id]:Show()
        end
	else
		addon:ApplyCustomGlow(effect, button, id, color, xoffs, yoffs)
	end
end

local function AddButton(spellId, button, itemId)
    if not addon.Platform:CanReadValue(spellId) then return end
	if type(spellId)=="number" and spellId>0 and spellId<math.huge and spellId%1==0 then
		if Spells[spellId] == nil then
			Spells[spellId] = {}
		end
        if ButtonSpells[button]~=spellId then tinsert(Spells[spellId], button) end
        ButtonSpells[button]=spellId
        ButtonItems[button]=itemId
	end
end

local function ValidActionSlot(slot)
    return addon.Platform:CanReadValue(slot) and type(slot) == 'number' and slot > 0 and slot < math.huge and slot%1 == 0
end

local function GetActionSlot(button)
    local slot = button:GetAttribute('action')
    if ValidActionSlot(slot) then return slot end

    -- Anniversary uses the same button methods as Retail. Older clients and
    -- third-party bars may still expose the global helpers or only action.
    if button.GetPagedID then
        slot = button:GetPagedID()
    elseif ActionButton_GetPagedID then
        slot = ActionButton_GetPagedID(button)
    end
    if ValidActionSlot(slot) then return slot end

    if button.CalculateAction then
        slot = button:CalculateAction()
    elseif ActionButton_CalculateAction then
        slot = ActionButton_CalculateAction(button)
    end
    if ValidActionSlot(slot) then return slot end
    if ValidActionSlot(button.action) then return button.action end
end

local function ReadStandardAction(button)
    local kind=button:GetAttribute('type')
    if not addon.Platform:CanReadValue(kind) then return end
    if kind~='action' and kind~='macro' and kind~='item' and kind~='spell' then return end
    local action=button:GetAttribute(kind)
    if kind=='action' then
        local slot=GetActionSlot(button)
        if not slot or not HasAction(slot) then return end
        kind,action=GetActionInfo(slot)
    end
    if not addon.Platform:CanReadValue(kind) then return end
    if not addon.Platform:CanReadValue(action) then return kind end
    return kind,action
end

local function ResolveStandardAction(kind,action)
    if kind=='macro' then
        local observed=addon.Platform:GetMacroAction(action)
        if observed then return observed.spellID,observed.itemID end
    elseif kind=='item' then
        local item=addon.Platform:GetItemID(action)
        if item then return itemUseSpellID(item),item end
    elseif kind=='spell' then
        return spellMetadataID(action)
    end
end

local function AddStandardButton(button)
    if not button or ButtonSpells[button] then return end
    local ok,kind,action=pcall(ReadStandardAction,button)
    if not ok then return end
    -- Retain macros whose current observation is unavailable so a later pass
    -- can recover without waiting for a bar-edit event.
    if kind=='macro' then MacroButtons[button]=true end
    local spell,item=ResolveStandardAction(kind,action)
    AddButton(spell,button,item)
end

-- Macro conditionals and cast sequences can change their exposed action
-- without moving a slot or editing the macro. Observe known macro buttons on
-- the existing recommendation cadence; never parse or execute macro bodies.
function addon:RefreshMacroButtons()
    if readClientPolicy(self.Platform)~='probe' then
        if next(Spells) then self:Fetch() end
        return
    end
    local observations,changes,affected={},{},{}
    for button in pairs(MacroButtons) do
        local ok,kind,action=pcall(ReadStandardAction,button)
        local spell,item
        if ok then
            local cacheable=kind=='macro' and (type(action)=='string' or
                type(action)=='number' and action>0 and action<math.huge and action%1==0)
            if cacheable then
                local observed=observations[action]
                if observed==nil then
                    observed=self.Platform:GetMacroAction(action) or false
                    observations[action]=observed
                end
                if observed then spell,item=observed.spellID,observed.itemID end
            else
                spell,item=ResolveStandardAction(kind,action)
            end
        end
        local previous=ButtonSpells[button]
        if previous~=spell or ButtonItems[button]~=item then
            changes[#changes+1]={button=button,spell=spell,item=item,previous=previous}
            if previous then affected[previous]=true end
            if spell then affected[spell]=true end
        end
    end
    -- Invalidate the affected identities before reindexing. Other buttons for
    -- those spells need their recommendation/cooldown glow reapplied as well.
    for spell in pairs(affected) do
        for _,button in ipairs(Spells[spell] or {}) do
            self:HideGlow(button,'next')
            self:HideGlow(button,spell)
        end
        SpellsGlowing[spell]=nil
        Flags[spell]=nil
    end
    for _,change in ipairs(changes) do
        local buttons=change.previous and Spells[change.previous]
        if buttons then
            for index=#buttons,1,-1 do
                if buttons[index]==change.button then table.remove(buttons,index) end
            end
            if #buttons==0 then Spells[change.previous]=nil end
        end
        ButtonSpells[change.button],ButtonItems[change.button]=nil,nil
        AddButton(change.spell,change.button,change.item)
    end
end

function FetchNeuron()
	for x = 1, 12 do
		for i = 1, 12 do
			local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchDiabolic()
	local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'};
	for _, bar in pairs(diabolicBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchBartender4()
    -- Non-pet buttons are done via. LibActionButton
	for i = 1, 10 do
		local button = _G['BT4PetButton' .. i];
		if button then
		    local spell = select(7, GetPetActionInfo(button.id))
			AddButton(spell, button);
		end
		button = _G['BT4StanceButton' .. i];
		if button then
			local spell = select(4, GetShapeshiftFormInfo(button:GetID()))
			AddButton(spell, button);
		end
	end
end

local function FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i]
		if button then
			AddStandardButton(button)
		end
	end
end

local function FetchFarmingBar()
	local i = 1
	while true do
		local button = _G['FarmingBar_Button' .. i]
		if not button then
			break
		end
		local hyperlink = button.obj:GetHyperlink()
		if hyperlink then
			local itemid = tonumber(hyperlink:match("item:(%d+)"))
			if itemid then
				local spellid = itemUseSpellID(itemid)
				if spellid then
					AddButton(spellid, button, itemid)
				end
			end
		end
		i = i + 1
	end
end

local function FetchAzeriteUI()
	for i = 1, 24 do
		local button = _G['AzeriteUIActionButton' .. i];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchSamyTotemTimers()
	for i = 1, 6 do
		local button = _G['SamyTotemTimers' .. i .. "CastTotemButton"];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchTotemTimers()
    for i=1,10 do
		local button = _G['XiTimers_Timer' .. i];
		if not button then
            break
        end
		local spellid = spellMetadataID(button:GetAttribute("*spell1"))
    	if not spellid then
			spellid = spellMetadataID(button:GetAttribute("spell1"))
		end
		if spellid then
			AddButton(spellid, button)
        end

    	for j=1,10 do
			button = _G['TT_ActionButton' .. i .. j];
			if not button then
				break
            end
			spellid = spellMetadataID(button:GetAttribute("*spell1"))
			if spellid then
				AddButton(spellid, button)
            end
		end
    end
end

local function FetchLUI()
	local luiBars = {
		'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
		'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
	}

	for _, bar in pairs(luiBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchSyncUI()
	local syncbars = {}

	syncbars[1] = SyncUI_ActionBar
	syncbars[2] = SyncUI_MultiBar
	syncbars[3] = SyncUI_SideBar.Bar1
	syncbars[4] = SyncUI_SideBar.Bar2
	syncbars[5] = SyncUI_SideBar.Bar3
	syncbars[6] = SyncUI_PetBar

	for _, bar in pairs(syncbars) do
		for i = 1, 12 do
			local button = bar['Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchLibActionButton()
	local LAB = {
		original = LibStub:GetLibrary('LibActionButton-1.0', true),
		elvui = LibStub:GetLibrary('LibActionButton-1.0-ElvUI', true),
	}

	for _, lib in pairs(LAB) do
		if lib and lib.GetAllButtons then
			for button in pairs(lib:GetAllButtons()) do
                AddStandardButton(button)
			end
		end
	end
end

local function FetchBlizzard()
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'}
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i]
			AddStandardButton(button)
		end
    end

	for i = 1, 10 do
		local button = _G['PetActionButton' .. i]
		AddStandardButton(button)
	end
end

local function FetchG15Buttons()
	local i = 2; -- it starts from 2
	while true do
		local button = _G['objG15_btn_' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

local function FetchButtonForge()
	local i = 1
	while true do
		local button = _G['ButtonForge' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

function addon:Fetch()
	self = addon
	if self.currentRotation then
		self:DisableRotationTimer()
	end
	self.Spell = nil

	self:GlowClear()
	self:DestroyAllGlows()

	Spells = {}
    ButtonItems = {}
    ButtonSpells = {}
    MacroButtons = {}
	Flags = {}
	SpellsGlowing = {}

    -- The reference/editor modes on restricted clients do not inspect combat
    -- actions. Clear outgoing mappings above before leaving the scanner.
    if addon.Platform:GetClientInfo().combatDataPolicy~="probe" then return end
	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('Bartender4') then
		FetchBartender4()
	end

	if IsAddOnLoaded('ButtonForge') then
		FetchButtonForge()
	end

	if IsAddOnLoaded('G15Buttons') then
		FetchG15Buttons()
	end

	if IsAddOnLoaded('SyncUI') then
		FetchSyncUI()
	end

	if IsAddOnLoaded('LUI') then
		FetchLUI()
	end

	if IsAddOnLoaded('Dominos') then
		FetchDominos()
	end

	if IsAddOnLoaded('DiabolicUI') then
		FetchDiabolic();
	end

	if IsAddOnLoaded('AzeriteUI') then
		FetchAzeriteUI();
    end

	if IsAddOnLoaded('Neuron') then
		FetchNeuron();
	end

	if IsAddOnLoaded('FarmingBar') then
		FetchFarmingBar();
	end

	if IsAddOnLoaded('TotemTimers') then
		FetchTotemTimers();
	end

	if IsAddOnLoaded('SamyTotemTimers') then
		FetchSamyTotemTimers();
	end

	if self.currentRotation then
		self:EnableRotationTimer()
		self:EvaluateNextAction()
	end
end

function addon:FindSpell(spellIds,itemIds)
    for index,id in ipairs(spellIds or {}) do
        if Spells[id] then
            if not itemIds then return id,index end
            local wanted=itemIds[index]
            if self.Platform:CanReadValue(wanted) and type(wanted)=="number" then
                for _,button in ipairs(Spells[id]) do
                    if ButtonItems[button]==wanted then return id,index end
                end
            end
        end
    end
end

function addon:IsGlowing(spellId,itemId)
    local current=SpellsGlowing[spellId]
    return current~=nil and current.itemId==itemId
end

local function GlowIndependent(spellId, id, effect, color, mags, setpoint, xoffs, yoffs, angle, itemId)
	if Spells[spellId] ~= nil and addon.db.global.effects[effect] then
		for _, button in pairs(Spells[spellId]) do
			if not itemId or ButtonItems[button]==itemId then
                addon:Glow(button, id, addon.db.global.effects[effect], color, mags, setpoint, xoffs, yoffs, angle)
            end
			addon:verbose(spellId .. " is now glowing")
		end
	end
end

local function ClearGlowIndependent(spellId, id)
	if Spells[spellId] ~= nil then
		for _, button in pairs(Spells[spellId]) do
			addon:HideGlow(button, id)
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowCooldown(spellId, condition, cooldown, itemId)
    if spellId == nil then
		return
    end

	local previous=Flags[spellId]
    if condition and cooldown and (not previous or previous.id~=cooldown.id or previous.itemId~=itemId) then
        if previous then ClearGlowIndependent(spellId,spellId) end
		Flags[spellId] = {id=cooldown.id,itemId=itemId}
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs,
				cooldown.angle or self.db.profile.angle, itemId)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = nil
		ClearGlowIndependent(spellId, spellId)
	end

	if WeakAuras then WeakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

if type(publishActivePresentation)=='function' then
    publishActivePresentation(addon,addon.GlowCooldown,getfenv(1))
end

function addon:GlowSpell(spellId,itemId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil and addon.db.global.effects[self.db.profile.effect] then
		for _, button in pairs(Spells[spellId]) do
            if not itemId or ButtonItems[button]==itemId then
			addon:Glow(button, 'next', addon.db.global.effects[self.db.profile.effect], self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs, self.db.profile.angle)
            end
		end

		SpellsGlowing[spellId] = {itemId=itemId}
		addon:verbose(spellId .. " is now glowing")
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellId]) do
				addon:HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = nil
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId,itemId)
	self:GlowClear()
	self:GlowSpell(spellId,itemId)
end

function addon:EndHighlightSlot()
	for _, button in pairs(Highlight) do
        self:HideGlow(button, "highlight")
    end
    Highlight = {}
end

function addon:HighlightSlots(slots)
	addon:EndHighlightSlot()
	for _, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = button:GetAttribute('type')
			if type == 'action' then
				local bslot = GetActionSlot(button)

				if bslot and addon.Functions.collections.index(slots, bslot) ~= nil then
                    self:Glow(button, "highlight", HighlightOverlay, {}, 1.0, "CENTER", 0, 0)
                	table.insert(Highlight, button)
				end
			end
		end
	end
end


-- BEGIN CPU ACTIVITY HANDOFF
-- Only the private RM button maps and their current logical slots are inspected.
-- Shared glow fields establish association, never exclusive caller ownership.
do
    local raw,nextKey,kind,equal,protect,text=rawget,next,type,rawequal,pcall,tostring
    local ownedGlow,ownedFetch=addon.Glow,addon.Fetch
    local starts={pixel=CustomGlow.PixelGlow_Start,autocast=CustomGlow.AutoCastGlow_Start,blizzard=CustomGlow.ButtonGlow_Start}
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'visual',function(api)
        if not equal(raw(addon,'Glow'),ownedGlow) or not equal(raw(addon,'Fetch'),ownedFetch) then return end
        for name,method in nextKey,starts do
            local key=name=='pixel' and 'PixelGlow_Start' or name=='autocast' and 'AutoCastGlow_Start' or 'ButtonGlow_Start'
            if not equal(raw(CustomGlow,key),method) then return end
        end
        local result={buttons=0,slots=0,logical=0,overlays=0,sequence=0,pixel=0,autocast=0,blizzard=0,proc=0,capped=false,callbacks={overlay=UpdateOverlay},ambiguous={}}
        if kind(api)~='table' or kind(raw(api,'GetParent'))~='function' or kind(raw(api,'IsVisible'))~='function' or kind(raw(api,'GetScript'))~='function' then result.unsupported=true;return result end
        local highlighted,seen={},{};local n=0
        for _,button in nextKey,Highlight do n=n+1;if n>128 then result.capped=true;break end;highlighted[button]=true end
        local function inspect(frame,button,name)
            result.slots=result.slots+1;if result.slots>512 then result.slots=512;result.capped=true;return end
            if kind(frame)~='table' or seen[frame] then return end
            local ok,parent=protect(api.GetParent,frame);if not ok or not equal(parent,button) then return end
            seen[frame]=true
            if name=='overlays' and raw(frame,'sequenceTimer')~=nil then result.sequence=result.sequence+1 end
            local visible,shown=protect(api.IsVisible,frame)
            if not visible then result.unsupported=true;return end
            if shown~=true then return end
            result[name]=result[name]+1
            if name=='overlays' or name=='proc' then return end
            local success,fn=protect(api.GetScript,frame,'OnUpdate')
            if not success or kind(fn)~='function' then return end
            if result.callbacks[name] and not equal(result.callbacks[name],fn) then result.callbacks[name]=nil;result.ambiguous[name]=true
            elseif not result.ambiguous[name] then result.callbacks[name]=fn end
        end
        for button,spell in nextKey,ButtonSpells do
            result.buttons=result.buttons+1;if result.buttons>128 then result.buttons=128;result.capped=true;break end
            if result.capped and result.slots>=512 then break end
            if kind(button)=='table' then
                local ids={}
                local glowing,flag=SpellsGlowing[spell],Flags[spell]
                if glowing and (glowing.itemId==nil or equal(glowing.itemId,ButtonItems[button])) then ids[#ids+1]='next' end
                if flag and (flag.itemId==nil or equal(flag.itemId,ButtonItems[button])) then ids[#ids+1]=spell end
                if highlighted[button] then ids[#ids+1]='highlight' end
                for _,id in nextKey,ids do
                    result.logical=result.logical+1
                    local overlays=raw(button,'rmOverlays');inspect(kind(overlays)=='table' and raw(overlays,id),button,'overlays')
                    local key=text(id)
                    inspect(raw(button,'_PixelGlow'..key),button,'pixel')
                    inspect(raw(button,'_AutoCastGlow'..key),button,'autocast')
                    inspect(raw(button,'_ProcGlow'..key),button,'proc')
                    if result.slots>=512 then result.capped=true;break end
                end
                if #ids>0 then inspect(raw(button,'_ButtonGlow'),button,'blizzard') end
            end
        end
        return result
    end) end
end
-- END CPU ACTIVITY HANDOFF
]========],
        after = [========[-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end
addon.ConsumeClientPolicyReader=nil
-- The active-plan receiver is consumed before any library callback. Only the
-- literal cooldown publisher below may qualify its private presentation route.
---@type fun(...): any
local publishActivePresentation=addon.BindActiveRuntimePresentationSource
addon.BindActiveRuntimePresentationSource=nil
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local CustomGlow = LibStub("LibCustomGlow-1.0")

local procSupport,procProbe
local function methods(value,names)
    for _,name in ipairs(names) do if type(value[name])~='function' then return false end end
    return true
end
local function probeProcGlow(atlas)
    for _,name in ipairs({'UI-HUD-ActionBar-Proc-Start-Flipbook','UI-HUD-ActionBar-Proc-Loop-Flipbook'}) do
        if type(atlas(name))~='table' then return false end
    end
    if not procProbe then procProbe=CreateFrame('Frame',nil,UIParent);procProbe:Hide();procProbe:SetSize(40,40) end
    local texture=procProbe:CreateTexture(nil,'ARTWORK');if type(texture.SetAtlas)~='function' then return false end
    texture:SetAtlas('UI-HUD-ActionBar-Proc-Start-Flipbook');texture:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
    procProbe.ProcLoop=texture
    local group=procProbe:CreateAnimationGroup()
    if not methods(group,{'Stop','Play','IsPlaying','SetLooping','SetToFinalAlpha','SetScript'}) then return false end
    group:SetLooping('REPEAT');group:SetToFinalAlpha(true)
    local alpha=group:CreateAnimation('Alpha')
    if not methods(alpha,{'SetChildKey','SetDuration','SetOrder','SetFromAlpha','SetToAlpha'}) then return false end
    alpha:SetChildKey('ProcLoop');alpha:SetDuration(.001);alpha:SetOrder(0);alpha:SetFromAlpha(1);alpha:SetToAlpha(1)
    local flipbook=group:CreateAnimation('FlipBook')
    if not methods(flipbook,{'SetChildKey','SetDuration','SetOrder','SetFlipBookRows','SetFlipBookColumns','SetFlipBookFrames','SetFlipBookFrameWidth','SetFlipBookFrameHeight'}) then return false end
    flipbook:SetChildKey('ProcLoop');flipbook:SetDuration(1);flipbook:SetOrder(0)
    flipbook:SetFlipBookRows(6);flipbook:SetFlipBookColumns(5);flipbook:SetFlipBookFrames(30);flipbook:SetFlipBookFrameWidth(0);flipbook:SetFlipBookFrameHeight(0)
    group:Stop();return true
end
-- Method names alone do not establish animation/atlas support on Classic.
-- This hidden probe never plays, and stable capabilities need no warm allocation.
function addon:GetProcGlowSupport()
    local atlas=C_Texture and C_Texture.GetAtlasInfo or rawget(_G,'GetAtlasInfo')
    if procSupport and procSupport.atlas==atlas and procSupport.create==CreateFrame
        and procSupport.start==CustomGlow.ProcGlow_Start and procSupport.stop==CustomGlow.ProcGlow_Stop then return procSupport.available end
    procSupport={atlas=atlas,create=CreateFrame,start=CustomGlow.ProcGlow_Start,stop=CustomGlow.ProcGlow_Stop,available=false}
    if type(atlas)=='function' and type(CreateFrame)=='function' and type(procSupport.start)=='function' and type(procSupport.stop)=='function' then
        local ok,value=pcall(probeProcGlow,atlas);procSupport.available=ok and value==true
    end
    return procSupport.available
end

local function spellMetadataID(spell)
    local info=addon.Platform:GetSpellInfo(spell)
    return info and info.spellID
end
local function itemUseSpellID(item)
    local info=addon.Platform:GetItemUseSpell(item)
    return info and info.spellID
end

local Spells = {}
local ButtonItems = {}
local ButtonSpells = {}
local MacroButtons = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}

local HighlightOverlay = {
	type = "dazzle",
	texture = "Interface\\Cooldown\\star4",
	frequency = 0.1,
	sequence = {
		{ r = 1.00, g = 0.00, b = 0.00, a = 1 },
		{ r = 0.75, g = 0.25, b = 0.00, a = 1 },
		{ r = 0.50, g = 0.50, b = 0.00, a = 1 },
		{ r = 0.25, g = 0.75, b = 0.00, a = 1 },
		{ r = 0.00, g = 1.00, b = 0.00, a = 1 },
		{ r = 0.00, g = 0.75, b = 0.25, a = 1 },
		{ r = 0.00, g = 0.50, b = 0.50, a = 1 },
		{ r = 0.00, g = 0.25, b = 0.75, a = 1 },
		{ r = 0.00, g = 0.00, b = 1.00, a = 1 },
		{ r = 0.25, g = 0.00, b = 0.75, a = 1 },
		{ r = 0.50, g = 0.00, b = 0.50, a = 1 },
		{ r = 0.75, g = 0.00, b = 0.25, a = 1 },
	}
}
local Highlight = {}

addon.textured_types = { "texture", "dazzle", "animate", "pulse", "rotate", "custom" }

function addon:ApplyCustomGlow(effect, frame, id, color, xoffs, yoffs)
    local c
	if color ~= nil then
		c = { color.r, color.g, color.b, color.a }
	end
	if effect.type == "pixel" then
		CustomGlow.PixelGlow_Start(frame, c, effect.lines, effect.frequency, effect.length, effect.thickness, xoffs, yoffs, false, id)
	elseif effect.type == "autocast" then
		CustomGlow.AutoCastGlow_Start(frame, c, effect.particles, effect.frequency, effect.scale, xoffs, yoffs, id)
	elseif effect.type == "blizzard" then
		CustomGlow.ButtonGlow_Start(frame, c, effect.frequency)
	elseif effect.type == 'proc' then
        if self:GetProcGlowSupport() then
            local duration=effect.duration
            if type(duration)~='number' or duration~=duration or duration<.1 or duration>5 then duration=1 end
            local ok=pcall(CustomGlow.ProcGlow_Start,frame,{key=tostring(id or ''),color=c,duration=duration,startAnim=effect.startAnim==true,xOffset=xoffs or 0,yOffset=yoffs or 0})
            if ok then return end
            procSupport.available=false
        end
        -- Another frame may have retired shared support while this key was lit.
        if type(CustomGlow.ProcGlow_Stop)=='function' then pcall(CustomGlow.ProcGlow_Stop,frame,tostring(id or '')) end
        CustomGlow.PixelGlow_Start(frame,c,nil,nil,nil,nil,xoffs,yoffs,false,id)
	end
end

local function InvalidateOverlay(frame)
    frame.rmOverlayGeneration=(frame.rmOverlayGeneration or 0)+1
    frame.rmOverlayDirty=true
    frame.rmOverlayParent=nil
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs, angle)
    local generation=frame.rmOverlayGeneration
    -- Native size scripts can alter any earlier render channel. These frames
    -- keep the complete legacy write path; sample the script each tick so late
    -- registration is covered without an observer or new subscription.
    local sizeScript=frame:GetScript('OnSizeChanged')~=nil
    local parent=frame:GetParent()
    if frame.rmOverlayGeneration~=generation then return false end
    local dirty=frame.rmOverlayDirty~=false or sizeScript
    if dirty or frame.rmOverlayParent~=parent or frame.rmOverlayPoint~=setp
        or frame.rmOverlayX~=xoffs or frame.rmOverlayY~=yoffs then
        -- Native geometry setters may synchronously alter later geometry or
        -- paint channels. Keep the remainder of this invocation on the legacy
        -- write path; only stable geometry can skip unchanged paint channels.
        dirty=true
        frame:ClearAllPoints()
        if frame.rmOverlayGeneration~=generation then return false end
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
        frame:SetPoint("CENTER",parent,setp,xoffs,yoffs)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayParent,frame.rmOverlayPoint=parent,setp
        frame.rmOverlayX,frame.rmOverlayY=xoffs,yoffs
        -- Anchor setters can invoke native callbacks which reparent the frame.
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local sizeChanged=false
    local width=parent:GetWidth() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayWidth~=width then
        dirty=true
        frame:SetWidth(width)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    -- Size setters can dispatch native OnSizeChanged callbacks. Read later
    -- inputs only after those callbacks, just as the original renderer did.
    local height=parent:GetHeight() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayHeight~=height then
        dirty=true
        frame:SetHeight(height)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
    end
    if sizeChanged then
        -- A size callback can change either dimension again. Cache the final
        -- native dimensions so the next tick corrects any request disagreement.
        frame.rmOverlayWidth,frame.rmOverlayHeight=frame:GetWidth(),frame:GetHeight()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local r,g,b,a=color.r,color.g,color.b,color.a
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayR~=r or frame.rmOverlayG~=g or frame.rmOverlayB~=b or frame.rmOverlayA~=a then
        frame.texture:SetVertexColor(r,g,b,a)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayR,frame.rmOverlayG,frame.rmOverlayB,frame.rmOverlayA=r,g,b,a
    end
    if effect and (dirty or frame.rmOverlayTexture~=effect) then
        frame.texture:SetTexture(effect)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayTexture=effect
    end
    if angle and (dirty or frame.rmOverlayAngle~=angle) then
        frame.texture:SetRotation(angle)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayAngle=angle
    end
    -- Leave a final repaint pending after the script is removed.
    frame.rmOverlayDirty=sizeScript
    return true
end

local UpdateOverlay
local function OverlayVisible(frame)
    -- Older external frame stand-ins have no visibility observation. Keep
    -- their legacy timer behavior; ordinary native Frames provide this API.
    if type(frame.IsVisible)=='function' then return frame:IsVisible() end
end

local function StopOverlay(frame)
    InvalidateOverlay(frame)
    local generation,timer=frame.rmOverlayGeneration,frame.sequenceTimer
    frame.rmOverlayAnimation=nil
    frame.sequenceTimer=nil
    frame.sequenceIdx=nil
    if timer then addon:CancelTimer(timer) end
    return frame.rmOverlayGeneration==generation
end

local function PauseOverlay(frame)
    local animation,generation=frame.rmOverlayAnimation,frame.rmOverlayGeneration
    if not animation or OverlayVisible(frame)~=false then return end
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation then return end
    InvalidateOverlay(frame)
    animation.generation=frame.rmOverlayGeneration
    animation.paused=true
    animation.ticket=nil
    local timer=frame.sequenceTimer
    frame.sequenceTimer=nil
    if timer then addon:CancelTimer(timer) end
end

local function StartOverlay(frame,animation)
    local generation=frame.rmOverlayGeneration
    if frame.rmOverlayAnimation~=animation or animation.generation~=generation then return false end
    if frame.sequenceTimer or animation.scheduling and animation.scheduling.generation==generation then return true end
    local visible=OverlayVisible(frame)
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation then return false end
    if visible==false then animation.paused=true;return true end
    animation.paused=false
    local ticket={generation=generation}
    animation.ticket,animation.scheduling=ticket,ticket
    local ok,timer=pcall(addon.ScheduleRepeatingTimer,addon,UpdateOverlay,animation.effect.frequency or .25,
        frame,animation.effect,animation.color,animation.mags,animation.setp,
        animation.xoffs,animation.yoffs,animation.angle,animation,ticket)
    if animation.scheduling==ticket then animation.scheduling=nil end
    if not ok then
        if animation.ticket==ticket then animation.ticket=nil end
        error(timer,0)
    end
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation
        or animation.ticket~=ticket or animation.paused then
        if timer then addon:CancelTimer(timer) end
        return false
    end
    frame.sequenceTimer=timer
    return true
end

local function ResumeOverlay(frame)
    local animation=frame.rmOverlayAnimation
    if animation and OverlayVisible(frame)==true then StartOverlay(frame,animation) end
end

function addon:HideGlow(frame, id, keepProc)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
    if not keepProc and type(CustomGlow.ProcGlow_Stop)=='function' then CustomGlow.ProcGlow_Stop(frame,tostring(id or '')) end
	if id ~= nil and frame.rmOverlays and frame.rmOverlays[id] then
        local overlay=frame.rmOverlays[id]
        if StopOverlay(overlay) and frame.rmOverlays and frame.rmOverlays[id]==overlay then overlay:Hide() end
	end
end

UpdateOverlay=function(frame, effect, color, mags, setp, xoffs, yoffs, angle, animation, ticket)
	if animation then
        if frame.rmOverlayAnimation~=animation or animation.generation~=frame.rmOverlayGeneration
            or animation.ticket~=ticket or animation.paused then return false end
    elseif effect.type~='texture' then
        animation={effect=effect,color=color,mags=mags,setp=setp,xoffs=xoffs,yoffs=yoffs,angle=angle,
            generation=frame.rmOverlayGeneration}
        frame.rmOverlayAnimation=animation
    end
	local type =  effect.type
    if type == "texture" then
        return UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, angle)
	elseif type == "rotate" and effect.steps and effect.steps > 0 then
		if frame.sequenceIdx then
			frame.sequenceIdx = frame.sequenceIdx >= effect.steps and 1 or (frame.sequenceIdx + 1)
		else
			frame.sequenceIdx = 1
		end
        if effect.reverse then
            if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (effect.steps - (frame.sequenceIdx - 1)))) then return false end
		else
			if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (frame.sequenceIdx - 1))) then return false end
        end
		return StartOverlay(frame,animation)
	elseif effect.sequence and #effect.sequence > 0 then
        local sequence = effect.sequence
        if frame.sequenceIdx then
            frame.sequenceIdx = frame.sequenceIdx >= #sequence and 1 or (frame.sequenceIdx + 1)
        else
            frame.sequenceIdx = 1
        end
        if type == "dazzle" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, sequence[frame.sequenceIdx], mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "animate" then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx], color, mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "pulse" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, color, sequence[frame.sequenceIdx], setp, xoffs, yoffs, angle) then return false end
		elseif type == "custom" and sequence[frame.sequenceIdx].texture and sequence[frame.sequenceIdx].color and sequence[frame.sequenceIdx].magnification then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx].texture, sequence[frame.sequenceIdx].color, sequence[frame.sequenceIdx].magnification, setp, xoffs, yoffs, math.rad(sequence[frame.sequenceIdx].angle or 0)) then return false end
		else
            StopOverlay(frame)
			return false
		end
		return StartOverlay(frame,animation)
	end
    return false
end

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
local function CreateOverlay(parent)
	local frame = tremove(FramePool)
	if not frame then
		frame = CreateFrame('Frame', addon_name .. '_Overlay_' .. addon.uuid(), parent)
	else
		frame:SetParent(parent)
	end
	InvalidateOverlay(frame)

	frame:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'HIGH')
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()+1) end

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)
    if not frame.rmOverlayLifecycle then
        frame.rmOverlayLifecycle=true
        frame:HookScript('OnHide',PauseOverlay)
        frame:HookScript('OnShow',ResumeOverlay)
    end
	return frame
end

local function DestroyOverlay(frame, id)
	if not StopOverlay(frame) then return end
	if frame:GetParent().rmOverlays ~= nil and frame:GetParent().rmOverlays[id] then
		frame:GetParent().rmOverlays[id] = nil
	end
	frame:ClearAllPoints()
	frame:Hide()
	frame:SetParent(UIParent)
	frame.width = nil
	frame.height = nil

	tinsert(FramePool, frame)
end

local function DestroyAllOverlay(parent)
	if parent.rmOverlays ~= nil then
		local overlays=parent.rmOverlays
		for id,frame in pairs(overlays) do
			DestroyOverlay(frame, id)
		end
		if parent.rmOverlays==overlays and next(overlays)==nil then parent.rmOverlays = nil end
	end
end

local function OverlaySuperseded(button,id,overlay,generation)
    if (button.rmOverlays and button.rmOverlays[id])~=overlay then return true end
    return overlay and overlay.rmOverlayGeneration~=generation
        and (overlay.rmOverlayGeneration~=generation+1 or overlay.rmOverlayAnimation~=nil)
end

function addon:DestroyAllGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				local overlay=button.rmOverlays and button.rmOverlays[spellid]
				local generation=overlay and overlay.rmOverlayGeneration
				self:HideGlow(button, spellid)
				if not OverlaySuperseded(button,spellid,overlay,generation) then DestroyAllOverlay(button) end
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				local overlay=button.rmOverlays and button.rmOverlays.next
				local generation=overlay and overlay.rmOverlayGeneration
				self:HideGlow(button, "next")
				if not OverlaySuperseded(button,'next',overlay,generation) then DestroyAllOverlay(button) end
			end
		end
	end
end

function addon:UpdateButtonGlow()
	local LAB
	local LBG
	local origShow
	local noFunction = function() end

	if IsAddOnLoaded('ElvUI') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0-ElvUI')
		LBG = LibStub:GetLibrary('LibCustomGlow-1.0')
		origShow = LBG.ShowOverlayGlow
	elseif IsAddOnLoaded('Bartender4') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0')
	end

	if self.db.global.disableButtonGlow then
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow
		end
	end
end

function addon:Glow(button, id, effect, color, mags, setp, xoffs, yoffs, angle)
	if not effect then
		return
	end

    local overlay=button.rmOverlays and button.rmOverlays[id]
    local generation=overlay and overlay.rmOverlayGeneration
    color=self:ResolveHighlightColor(color)
    if (button.rmOverlays and button.rmOverlays[id])~=overlay
        or overlay and overlay.rmOverlayGeneration~=generation then return end

	local type = effect.type
	addon:HideGlow(button, id, type=='proc')
    if OverlaySuperseded(button,id,overlay,generation) then return end
	if addon.Functions.collections.index(addon.textured_types, type) then
		if not button.rmOverlays then
			button.rmOverlays = {}
		end
		if not button.rmOverlays[id] then
			button.rmOverlays[id] = CreateOverlay(button, id)
		end

        if UpdateOverlay(button.rmOverlays[id], effect, color, mags, setp, xoffs, yoffs, angle) then
            button.rmOverlays[id]:Show()
        end
	else
		addon:ApplyCustomGlow(effect, button, id, color, xoffs, yoffs)
	end
end

local function AddButton(spellId, button, itemId)
    if not addon.Platform:CanReadValue(spellId) then return end
	if type(spellId)=="number" and spellId>0 and spellId<math.huge and spellId%1==0 then
		if Spells[spellId] == nil then
			Spells[spellId] = {}
		end
        if ButtonSpells[button]~=spellId then tinsert(Spells[spellId], button) end
        ButtonSpells[button]=spellId
        ButtonItems[button]=itemId
	end
end

local function ValidActionSlot(slot)
    return addon.Platform:CanReadValue(slot) and type(slot) == 'number' and slot > 0 and slot < math.huge and slot%1 == 0
end

local function GetActionSlot(button)
    local slot = button:GetAttribute('action')
    if ValidActionSlot(slot) then return slot end

    -- Anniversary uses the same button methods as Retail. Older clients and
    -- third-party bars may still expose the global helpers or only action.
    if button.GetPagedID then
        slot = button:GetPagedID()
    elseif ActionButton_GetPagedID then
        slot = ActionButton_GetPagedID(button)
    end
    if ValidActionSlot(slot) then return slot end

    if button.CalculateAction then
        slot = button:CalculateAction()
    elseif ActionButton_CalculateAction then
        slot = ActionButton_CalculateAction(button)
    end
    if ValidActionSlot(slot) then return slot end
    if ValidActionSlot(button.action) then return button.action end
end

local function ReadStandardAction(button)
    local kind=button:GetAttribute('type')
    if not addon.Platform:CanReadValue(kind) then return end
    if kind~='action' and kind~='macro' and kind~='item' and kind~='spell' then return end
    local action=button:GetAttribute(kind)
    if kind=='action' then
        local slot=GetActionSlot(button)
        if not slot or not HasAction(slot) then return end
        kind,action=GetActionInfo(slot)
    end
    if not addon.Platform:CanReadValue(kind) then return end
    if not addon.Platform:CanReadValue(action) then return kind end
    return kind,action
end

local function ResolveStandardAction(kind,action)
    if kind=='macro' then
        local observed=addon.Platform:GetMacroAction(action)
        if observed then return observed.spellID,observed.itemID end
    elseif kind=='item' then
        local item=addon.Platform:GetItemID(action)
        if item then return itemUseSpellID(item),item end
    elseif kind=='spell' then
        return spellMetadataID(action)
    end
end

local function AddStandardButton(button)
    if not button or ButtonSpells[button] then return end
    local ok,kind,action=pcall(ReadStandardAction,button)
    if not ok then return end
    -- Retain macros whose current observation is unavailable so a later pass
    -- can recover without waiting for a bar-edit event.
    if kind=='macro' then MacroButtons[button]=true end
    local spell,item=ResolveStandardAction(kind,action)
    AddButton(spell,button,item)
end

-- Macro conditionals and cast sequences can change their exposed action
-- without moving a slot or editing the macro. Observe known macro buttons on
-- the existing recommendation cadence; never parse or execute macro bodies.
function addon:RefreshMacroButtons()
    if readClientPolicy(self.Platform)~='probe' then
        if next(Spells) then self:Fetch() end
        return
    end
    local observations,changes,affected={},{},{}
    for button in pairs(MacroButtons) do
        local ok,kind,action=pcall(ReadStandardAction,button)
        local spell,item
        if ok then
            local cacheable=kind=='macro' and (type(action)=='string' or
                type(action)=='number' and action>0 and action<math.huge and action%1==0)
            if cacheable then
                local observed=observations[action]
                if observed==nil then
                    observed=self.Platform:GetMacroAction(action) or false
                    observations[action]=observed
                end
                if observed then spell,item=observed.spellID,observed.itemID end
            else
                spell,item=ResolveStandardAction(kind,action)
            end
        end
        local previous=ButtonSpells[button]
        if previous~=spell or ButtonItems[button]~=item then
            changes[#changes+1]={button=button,spell=spell,item=item,previous=previous}
            if previous then affected[previous]=true end
            if spell then affected[spell]=true end
        end
    end
    -- Invalidate the affected identities before reindexing. Other buttons for
    -- those spells need their recommendation/cooldown glow reapplied as well.
    for spell in pairs(affected) do
        for _,button in ipairs(Spells[spell] or {}) do
            self:HideGlow(button,'next')
            self:HideGlow(button,spell)
        end
        SpellsGlowing[spell]=nil
        Flags[spell]=nil
    end
    for _,change in ipairs(changes) do
        local buttons=change.previous and Spells[change.previous]
        if buttons then
            for index=#buttons,1,-1 do
                if buttons[index]==change.button then table.remove(buttons,index) end
            end
            if #buttons==0 then Spells[change.previous]=nil end
        end
        ButtonSpells[change.button],ButtonItems[change.button]=nil,nil
        AddButton(change.spell,change.button,change.item)
    end
end

function FetchNeuron()
	for x = 1, 12 do
		for i = 1, 12 do
			local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchDiabolic()
	local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'};
	for _, bar in pairs(diabolicBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchBartender4()
    -- Non-pet buttons are done via. LibActionButton
	for i = 1, 10 do
		local button = _G['BT4PetButton' .. i];
		if button then
		    local spell = select(7, GetPetActionInfo(button.id))
			AddButton(spell, button);
		end
		button = _G['BT4StanceButton' .. i];
		if button then
			local spell = select(4, GetShapeshiftFormInfo(button:GetID()))
			AddButton(spell, button);
		end
	end
end

local function FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i]
		if button then
			AddStandardButton(button)
		end
	end
end

local function FetchFarmingBar()
	local i = 1
	while true do
		local button = _G['FarmingBar_Button' .. i]
		if not button then
			break
		end
		local hyperlink = button.obj:GetHyperlink()
		if hyperlink then
			local itemid = tonumber(hyperlink:match("item:(%d+)"))
			if itemid then
				local spellid = itemUseSpellID(itemid)
				if spellid then
					AddButton(spellid, button, itemid)
				end
			end
		end
		i = i + 1
	end
end

local function FetchAzeriteUI()
	for i = 1, 24 do
		local button = _G['AzeriteUIActionButton' .. i];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchSamyTotemTimers()
	for i = 1, 6 do
		local button = _G['SamyTotemTimers' .. i .. "CastTotemButton"];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchTotemTimers()
    for i=1,10 do
		local button = _G['XiTimers_Timer' .. i];
		if not button then
            break
        end
		local spellid = spellMetadataID(button:GetAttribute("*spell1"))
    	if not spellid then
			spellid = spellMetadataID(button:GetAttribute("spell1"))
		end
		if spellid then
			AddButton(spellid, button)
        end

    	for j=1,10 do
			button = _G['TT_ActionButton' .. i .. j];
			if not button then
				break
            end
			spellid = spellMetadataID(button:GetAttribute("*spell1"))
			if spellid then
				AddButton(spellid, button)
            end
		end
    end
end

local function FetchLUI()
	local luiBars = {
		'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
		'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
	}

	for _, bar in pairs(luiBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchSyncUI()
	local syncbars = {}

	syncbars[1] = SyncUI_ActionBar
	syncbars[2] = SyncUI_MultiBar
	syncbars[3] = SyncUI_SideBar.Bar1
	syncbars[4] = SyncUI_SideBar.Bar2
	syncbars[5] = SyncUI_SideBar.Bar3
	syncbars[6] = SyncUI_PetBar

	for _, bar in pairs(syncbars) do
		for i = 1, 12 do
			local button = bar['Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchLibActionButton()
	local LAB = {
		original = LibStub:GetLibrary('LibActionButton-1.0', true),
		elvui = LibStub:GetLibrary('LibActionButton-1.0-ElvUI', true),
	}

	for _, lib in pairs(LAB) do
		if lib and lib.GetAllButtons then
			for button in pairs(lib:GetAllButtons()) do
                AddStandardButton(button)
			end
		end
	end
end

local function FetchBlizzard()
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'}
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i]
			AddStandardButton(button)
		end
    end

	for i = 1, 10 do
		local button = _G['PetActionButton' .. i]
		AddStandardButton(button)
	end
end

local function FetchG15Buttons()
	local i = 2; -- it starts from 2
	while true do
		local button = _G['objG15_btn_' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

local function FetchButtonForge()
	local i = 1
	while true do
		local button = _G['ButtonForge' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

function addon:Fetch()
	self = addon
	if self.currentRotation then
		self:DisableRotationTimer()
	end
	self.Spell = nil

	self:GlowClear()
	self:DestroyAllGlows()

	Spells = {}
    ButtonItems = {}
    ButtonSpells = {}
    MacroButtons = {}
	Flags = {}
	SpellsGlowing = {}

    -- The reference/editor modes on restricted clients do not inspect combat
    -- actions. Clear outgoing mappings above before leaving the scanner.
    if addon.Platform:GetClientInfo().combatDataPolicy~="probe" then return end
	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('Bartender4') then
		FetchBartender4()
	end

	if IsAddOnLoaded('ButtonForge') then
		FetchButtonForge()
	end

	if IsAddOnLoaded('G15Buttons') then
		FetchG15Buttons()
	end

	if IsAddOnLoaded('SyncUI') then
		FetchSyncUI()
	end

	if IsAddOnLoaded('LUI') then
		FetchLUI()
	end

	if IsAddOnLoaded('Dominos') then
		FetchDominos()
	end

	if IsAddOnLoaded('DiabolicUI') then
		FetchDiabolic();
	end

	if IsAddOnLoaded('AzeriteUI') then
		FetchAzeriteUI();
    end

	if IsAddOnLoaded('Neuron') then
		FetchNeuron();
	end

	if IsAddOnLoaded('FarmingBar') then
		FetchFarmingBar();
	end

	if IsAddOnLoaded('TotemTimers') then
		FetchTotemTimers();
	end

	if IsAddOnLoaded('SamyTotemTimers') then
		FetchSamyTotemTimers();
	end

	if self.currentRotation then
		self:EnableRotationTimer()
		self:EvaluateNextAction()
	end
end

function addon:FindSpell(spellIds,itemIds)
    for index,id in ipairs(spellIds or {}) do
        if Spells[id] then
            if not itemIds then return id,index end
            local wanted=itemIds[index]
            if self.Platform:CanReadValue(wanted) and type(wanted)=="number" then
                for _,button in ipairs(Spells[id]) do
                    if ButtonItems[button]==wanted then return id,index end
                end
            end
        end
    end
end

function addon:IsGlowing(spellId,itemId)
    local current=SpellsGlowing[spellId]
    return current~=nil and current.itemId==itemId
end

local function GlowIndependent(spellId, id, effect, color, mags, setpoint, xoffs, yoffs, angle, itemId)
	if Spells[spellId] ~= nil and addon.db.global.effects[effect] then
		for _, button in pairs(Spells[spellId]) do
			if not itemId or ButtonItems[button]==itemId then
                addon:Glow(button, id, addon.db.global.effects[effect], color, mags, setpoint, xoffs, yoffs, angle)
            end
			addon:verbose(spellId .. " is now glowing")
		end
	end
end

local function ClearGlowIndependent(spellId, id)
	if Spells[spellId] ~= nil then
		for _, button in pairs(Spells[spellId]) do
			addon:HideGlow(button, id)
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowCooldown(spellId, condition, cooldown, itemId)
    if spellId == nil then
		return
    end

	local previous=Flags[spellId]
    if condition and cooldown and (not previous or previous.id~=cooldown.id or previous.itemId~=itemId) then
        if previous then ClearGlowIndependent(spellId,spellId) end
		Flags[spellId] = {id=cooldown.id,itemId=itemId}
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs,
				cooldown.angle or self.db.profile.angle, itemId)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = nil
		ClearGlowIndependent(spellId, spellId)
	end

	if WeakAuras then WeakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

if type(publishActivePresentation)=='function' then
    publishActivePresentation(addon,addon.GlowCooldown,getfenv(1))
end

function addon:GlowSpell(spellId,itemId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil and addon.db.global.effects[self.db.profile.effect] then
		for _, button in pairs(Spells[spellId]) do
            if not itemId or ButtonItems[button]==itemId then
			addon:Glow(button, 'next', addon.db.global.effects[self.db.profile.effect], self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs, self.db.profile.angle)
            end
		end

		SpellsGlowing[spellId] = {itemId=itemId}
		addon:verbose(spellId .. " is now glowing")
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellId]) do
				addon:HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = nil
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId,itemId)
	self:GlowClear()
	self:GlowSpell(spellId,itemId)
end

function addon:EndHighlightSlot()
	for _, button in pairs(Highlight) do
        self:HideGlow(button, "highlight")
    end
    Highlight = {}
end

function addon:HighlightSlots(slots)
	addon:EndHighlightSlot()
	for _, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = button:GetAttribute('type')
			if type == 'action' then
				local bslot = GetActionSlot(button)

				if bslot and addon.Functions.collections.index(slots, bslot) ~= nil then
                    self:Glow(button, "highlight", HighlightOverlay, {}, 1.0, "CENTER", 0, 0)
                	table.insert(Highlight, button)
				end
			end
		end
	end
end


-- BEGIN CPU ACTIVITY HANDOFF
-- Only the private RM button maps and their current logical slots are inspected.
-- Shared glow fields establish association, never exclusive caller ownership.
do
    local raw,nextKey,kind,equal,protect,text=rawget,next,type,rawequal,pcall,tostring
    local ownedGlow,ownedFetch=addon.Glow,addon.Fetch
    local starts={pixel=CustomGlow.PixelGlow_Start,autocast=CustomGlow.AutoCastGlow_Start,blizzard=CustomGlow.ButtonGlow_Start}
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'visual',function(api)
        if not equal(raw(addon,'Glow'),ownedGlow) or not equal(raw(addon,'Fetch'),ownedFetch) then return end
        for name,method in nextKey,starts do
            local key=name=='pixel' and 'PixelGlow_Start' or name=='autocast' and 'AutoCastGlow_Start' or 'ButtonGlow_Start'
            if not equal(raw(CustomGlow,key),method) then return end
        end
        local result={buttons=0,slots=0,logical=0,overlays=0,sequence=0,pixel=0,autocast=0,blizzard=0,proc=0,capped=false,callbacks={overlay=UpdateOverlay},ambiguous={}}
        if kind(api)~='table' or kind(raw(api,'GetParent'))~='function' or kind(raw(api,'IsVisible'))~='function' or kind(raw(api,'GetScript'))~='function' then result.unsupported=true;return result end
        local highlighted,seen={},{};local n=0
        for _,button in nextKey,Highlight do n=n+1;if n>128 then result.capped=true;break end;highlighted[button]=true end
        local function inspect(frame,button,name)
            result.slots=result.slots+1;if result.slots>512 then result.slots=512;result.capped=true;return end
            if kind(frame)~='table' or seen[frame] then return end
            local ok,parent=protect(api.GetParent,frame);if not ok or not equal(parent,button) then return end
            seen[frame]=true
            if name=='overlays' and raw(frame,'sequenceTimer')~=nil then result.sequence=result.sequence+1 end
            local visible,shown=protect(api.IsVisible,frame)
            if not visible then result.unsupported=true;return end
            if shown~=true then return end
            result[name]=result[name]+1
            if name=='overlays' or name=='proc' then return end
            local success,fn=protect(api.GetScript,frame,'OnUpdate')
            if not success or kind(fn)~='function' then return end
            if result.callbacks[name] and not equal(result.callbacks[name],fn) then result.callbacks[name]=nil;result.ambiguous[name]=true
            elseif not result.ambiguous[name] then result.callbacks[name]=fn end
        end
        for button,spell in nextKey,ButtonSpells do
            result.buttons=result.buttons+1;if result.buttons>128 then result.buttons=128;result.capped=true;break end
            if result.capped and result.slots>=512 then break end
            if kind(button)=='table' then
                local ids={}
                local glowing,flag=SpellsGlowing[spell],Flags[spell]
                if glowing and (glowing.itemId==nil or equal(glowing.itemId,ButtonItems[button])) then ids[#ids+1]='next' end
                if flag and (flag.itemId==nil or equal(flag.itemId,ButtonItems[button])) then ids[#ids+1]=spell end
                if highlighted[button] then ids[#ids+1]='highlight' end
                for _,id in nextKey,ids do
                    result.logical=result.logical+1
                    local overlays=raw(button,'rmOverlays');inspect(kind(overlays)=='table' and raw(overlays,id),button,'overlays')
                    local key=text(id)
                    inspect(raw(button,'_PixelGlow'..key),button,'pixel')
                    inspect(raw(button,'_AutoCastGlow'..key),button,'autocast')
                    inspect(raw(button,'_ProcGlow'..key),button,'proc')
                    if result.slots>=512 then result.capped=true;break end
                end
                if #ids>0 then inspect(raw(button,'_ButtonGlow'),button,'blizzard') end
            end
        end
        return result
    end) end
end
-- END CPU ACTIVITY HANDOFF
]========],
    },
    ["Diagnostics/cpu.lua"] = {
        before = [========[local addon_name,addon=...
-- Opt-in cumulative snapshots. No functions are wrapped and shared counters are
-- never reset. Only this module's one completion timer exists during capture.
local active,lastReport
-- Fixed, source-free proof snapshots. The installer is retired by main;
-- this reader is private and is never invoked outside capture boundaries.
local proofType,proofRawget,proofPcall=type,rawget,pcall
-- BEGIN PRIVATE CACHE ANCHORS
local cacheSourceEqual=rawequal
local cacheSourceModules=proofRawget(addon,'builtinSourceModules')
local cacheSourceGetter=proofType(cacheSourceModules)=='table' and proofRawget(cacheSourceModules,'Functions/cache.lua') or nil
-- END PRIVATE CACHE ANCHORS
local executionIndexDiagnostic
function addon:BindCPUExecutionIndexDiagnostic(provider)
 if self~=addon or executionIndexDiagnostic or proofType(provider)~="function" then return end
 executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","parser-match-unavailable","parser-sub-unavailable","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
 if not executionIndexDiagnostic then return "probe-unavailable" end
 local ok,text=proofPcall(function()
  local status=executionIndexDiagnostic()
  if proofType(status)~="table" then return "probe-unavailable" end
  local parts={}
  for i=1,4 do
   local name=proofOwners[i];local row=proofRawget(status,name)
   local reason=proofType(row)=="table" and proofRawget(row,"reason") or nil
   reason=proofType(reason)=="string" and proofRawget(proofReasons,reason) and reason or "unavailable"
   local part=name.."="..reason
   if reason~="ready" and name~="main" then
    local flags=proofType(row)=="table" and proofRawget(row,"raw") or nil
    part=part.."["
    for keyIndex=1,7 do
     local key=proofRawKeys[keyIndex]
     if name~="sequence" or key=="type" or key=="ipairs" or key=="getfenv" then
      local flag=proofType(flags)=="table" and proofRawget(flags,key)
      part=part..key.."="..(flag==true and "1" or flag==false and "0" or "?").."," end
    end
    part=part.."]"
   end
   parts[i]=part
  end
  local function parserFlag(owner,key)
   local row=proofRawget(status,owner)
   local value=proofType(row)=="table" and proofRawget(row,key)
   return value==true and "1" or value==false and "0" or "?"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; parser-match="..parserFlag("index","parserMatch").."; parser-sub="..parserFlag("portable","parserSub")
 end)
 return ok and text or "probe-unavailable"
end
local function appendExecutionIndexProof(report,started,ended)
 local bytes=#report-1
 for i=1,#report do bytes=bytes+#report[i] end
 local first="Execution index proof start: "..(started or "probe-unavailable")
 local last="Execution index proof end: "..ended
 if bytes+1+#first+1+#last<16000 then
  report[#report+1]=first;report[#report+1]=last
 else
  local omitted="Execution index proof omitted to keep report bounded."
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
local runtimeNames={
 'EvaluateNextAction','EvaluateNextActionInternal','UpdateCurrentCondition','Fetch','UpdateBagContents',
 'GetRotationOwnerContext','GetRotationContext','GetRotationValidationStamp','GetRotationValidationOptions',
 'AcquireRotationRuntimePass','GetRuntimeRotations','GetRuntimeRotation','GetRotationCandidates',
 'EvaluateRotationSequence','rotationValidConditions','evaluateConditionResult','validateCondition',
 'NewActionReadiness','GetConditionUnitLevel','GetConditionPointResource','GetClassGroupCount','EvaluateItemCondition',
 'RefreshPreviewWindow','RemoveAllCurrentGlows','DestroyAllGlows','RefreshMacroButtons','UpdateButtonGlow','GlowNextSpell','GlowSpell','GlowCooldown','IsGlowing','FindSpell','GetSpellIds','RefreshSpellCatalog',
}
local platformNames={}
for name in ([[AuraRemaining CanReadValue GetAPISurface GetAnnouncementGroup GetAssistedAvailability GetAuraByIndex GetBagItemCounts GetBagSnapshot GetClientInfo GetGlobalCooldown GetGlyphItemInfo GetGlyphSocketSnapshot GetGridTalentInfo GetGroupMembership GetInstanceObservation GetItemCooldown GetItemCount GetItemDisplayInfo GetItemID GetItemInfoInstant GetItemMetadata GetItemRangeState GetItemUseSpell GetLossOfControlCount GetLossOfControlEvent GetMobInfo2Observation GetMacroAction GetNameplateMaxDistance GetPetObservation GetPlayerFlagObservation GetPlayerFormObservation GetPlayerMovementObservation GetPlayerOwnerClassObservation GetPrimaryTalentTree GetRangeCheckBounds GetRosterClassObservation GetRotationSpecialization GetRotationSpecializations GetRuneCooldownObservation GetRuneEvaluationTime GetRuneTypeObservation GetSpellBookSnapshot GetSpellCharges GetSpellCooldown GetSpellInfo GetSpellLink GetSpellRangeState GetTalentLayout GetTalentTreeCount GetTalentTreeInfo GetTotemInfo GetTotemSlotCount GetTreeTalentCount GetTreeTalentInfo GetUnitAttackabilityObservation GetUnitCastObservation GetUnitFlagObservation GetUnitHealthObservation GetUnitIdentityObservation GetUnitLevelObservation GetUnitMetadataObservation GetUnitPointIdentityObservation GetUnitPointPowerObservation GetUnitPowerObservation GetUnitThreatObservation GetZonePVPObservation IsAutoRepeatActive IsBeyondMeleeRange IsCurrentSpell IsItemEquipped IsItemLevelAllowed IsItemReady IsMeleeAttackNeeded IsSpellKnown IsSpellReady IsSpellUsable NewSpellRangeReader ReadAuraField SendAnnouncementChat]]):gmatch('%S+') do platformNames[#platformNames+1]=name end
local function readable(value)
 if type(issecretvalue)=='function' then local ok,secret=pcall(issecretvalue,value);if not ok or secret then return false end end
 if type(canaccessvalue)=='function' then local ok,allowed=pcall(canaccessvalue,value);if not ok or not allowed then return false end end
 return true
end
-- BEGIN COLD STORE STRING SHAPE
-- Current observations only: cached constructor identities/admission stay private.
local function storeStringShape()
 local ok,text=proofPcall(function()
  local meta=getmetatable('');if not readable(meta) then return 'unavailable' end
  local index;if proofType(meta)=='table' then index=proofRawget(meta,'__index') end
  if not readable(index) then return 'unavailable' end
  local find;if proofType(index)=='table' then find=proofRawget(index,'find') end
  if not readable(find) then return 'unavailable' end
  local repeated=getmetatable('');if not readable(repeated) then return 'unavailable' end
  local repeatedIndex;if proofType(repeated)=='table' then repeatedIndex=proofRawget(repeated,'__index') end
  if not readable(repeatedIndex) then return 'unavailable' end
  return 'meta='..proofType(meta)..'; index='..proofType(index)..'; raw-find='..proofType(find)
   ..'; repeat-meta='..(cacheSourceEqual(meta,repeated) and '1' or '0')
   ..'; repeat-index='..(cacheSourceEqual(index,repeatedIndex) and '1' or '0')
 end)
 return ok and text or 'unavailable'
end
local function appendStoreStringShape(report,started,ended)
 local lines={'Store string shape start: '..(started or 'unavailable'),'Store string shape end: '..ended,
  'Necessary shape only: table/table/function and stable reads; does not prove private-store use or cached factory identities/admission.'}
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Store string shape omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END COLD STORE STRING SHAPE
local function finite(value) return readable(value) and type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
local function counter(value,integer) return finite(value) and value>=0 and (not integer or value%1==0) end
local function field(owner,key) if type(owner)=='table' then return rawget(owner,key) end end
local function addonCPUAPI(name,legacy)
 local candidate=field(C_AddOns,name)
 if type(candidate)=='function' then return candidate end
 if type(legacy)=='function' then return legacy end
end
local function totalAPI() return addonCPUAPI('GetAddOnCPUUsage',GetAddOnCPUUsage) end
local function updateAPI() return addonCPUAPI('UpdateAddOnCPUUsage',UpdateAddOnCPUUsage) end
local function cvarAPI() return type(GetCVar)=='function' and GetCVar or type(C_CVar)=='table' and type(C_CVar.GetCVar)=='function' and C_CVar.GetCVar or nil end
local function enabled(fn)
 if type(fn)~='function' then return false,'missing-script-profile-api' end
 local ok,value=pcall(fn,'scriptProfile');if not ok then return false,'script-profile-query-error' end
 if not readable(value) then return false,'restricted-script-profile' end
 if value=='0' then return false,'script-profile-disabled' end
 if value~='1' then return false,'invalid-script-profile-result' end
 return true
end
local function clockAPI() return type(GetTimePreciseSec)=='function' and GetTimePreciseSec or type(GetTime)=='function' and GetTime or nil end
local function clock(fn)
 if type(fn)~='function' then return nil,'missing-clock-api' end
 local ok,value=pcall(fn);if not ok then return nil,'clock-error' end
 if not counter(value) then return nil,'invalid-clock' end
 return value
end
local function total(run)
 local ok=pcall(run.update);if not ok then return nil,'addon-cpu-update-error' end
 local good,value=pcall(run.total,addon_name);if not good then return nil,'addon-cpu-query-error' end
 if not counter(value) then return nil,'invalid-addon-cpu-counter' end
 return value
end
local function snapshot(run,fn)
 local ok,exclusive,calls=pcall(run.query,fn,false)
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 local good,inclusive,inclusiveCalls=pcall(run.query,fn,true)
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function visibility(owner)
 local frame=field(owner,'frame') or owner
 local method=type(frame)=='table' and frame.IsShown
 if type(method)~='function' then return nil end
 local ok,shown=pcall(method,frame);if ok and readable(shown) and type(shown)=='boolean' then return shown end
end
local function context(owner)
 local config=visibility(field(owner,'configWindow'));local dialog=visibility(field(owner,'nativeCustomConditionDialog'))
 if dialog==true then config=true end
 local combat='unavailable';if type(InCombatLockdown)=='function' then local ok,value=pcall(InCombatLockdown);if ok and readable(value) and type(value)=='boolean' then combat=tostring(value) end end
 local profile=field(field(owner,'db'),'profile')
 local function interval(key) local value=field(profile,key);if finite(value) or readable(value) and type(value)=='boolean' then return tostring(value) end;return 'unavailable' end
 local result='config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
 -- BEGIN CACHE MODE CONTEXT
 local mode=field(owner,'GetCacheDiagnosticMode')
 if type(mode)=='function' then
  local ok,loaded,requested,pending=pcall(mode,owner)
  local function known(value) return readable(value) and type(value)=='string' and (value=='cached' or value=='direct') end
  if ok and known(loaded) and known(requested) and readable(pending) and type(pending)=='boolean' then
   result=result..' observation-cache='..loaded..' requested='..requested..' reload='..tostring(pending)
  else result=result..' observation-cache=unavailable' end
 end
 return result
 -- END CACHE MODE CONTEXT
end
-- BEGIN STANDALONE PREVIEW CONTEXT
-- Canonical-slot observation only; this does not authenticate foreign frames.
local previewNumbers={[0]='0','1','2','3','4','5'}
local function standalonePreviewContext(owner)
 local ok,text=pcall(function()
  local selected,canonical=field(owner,'nextWindow'),field(owner,'nativePreviewWindow')
  if not readable(selected) then return 'selected=unavailable' end
  if selected==nil then return 'selected=none' end
  local marker=field(selected,'nativePreview')
  if not readable(canonical) or not readable(marker) then return 'selected=unavailable' end
  if type(selected)~='table' or not rawequal(selected,canonical) or marker~=true then return 'selected=custom' end
  local db=field(owner,'db');local profile=field(db,'profile');local frame=field(selected,'frame')
  local activeValue,count,slots,windowProfile=field(selected,'active'),field(selected,'count'),field(selected,'slots'),field(selected,'profile')
  local setting,generation=field(profile,'preview_spells'),field(selected,'generation')
  local capture=active
  local function current()
   return active==capture and rawequal(field(owner,'nextWindow'),selected) and rawequal(field(owner,'nativePreviewWindow'),canonical)
    and rawequal(field(owner,'db'),db) and rawequal(field(db,'profile'),profile) and rawequal(field(selected,'frame'),frame)
    and rawequal(field(selected,'nativePreview'),marker) and rawequal(field(selected,'active'),activeValue)
    and rawequal(field(selected,'count'),count) and rawequal(field(selected,'slots'),slots)
    and rawequal(field(selected,'profile'),windowProfile) and rawequal(field(profile,'preview_spells'),setting)
    and rawequal(field(selected,'generation'),generation)
  end
  local function number(value)
   if readable(value) and type(value)=='number' and value==value and value>=0 and value<=5 and value%1==0 then return previewNumbers[value] end
   return '?'
  end
  local function boolean(value)
   if readable(value) and type(value)=='boolean' then return value and '1' or '0' end
   return '?'
  end
  local shown='?'
  if readable(frame) and type(frame)=='table' then
   local valid,value=pcall(function()
    local method=frame.IsShown
    if readable(method) and type(method)=='function' and current() then return method(frame) end
   end)
   if valid then shown=boolean(value) end
  end
  local sameProfile='?'
  if readable(profile) and readable(windowProfile) and type(profile)=='table' and type(windowProfile)=='table' then
   sameProfile=rawequal(profile,windowProfile) and 'current' or 'different'
  end
  local result='selected=canonical shown='..shown..' active='..boolean(activeValue)..' setting='..number(setting)
   ..' slots='..number(slots)..' recommendations='..number(count)..' profile='..sameProfile
  -- A getter or visibility method may retire/rebind this surface mid-snapshot.
  if not current() then return 'selected=unavailable' end
  return result
 end)
 return ok and text or 'selected=unavailable'
end
local function appendStandalonePreviewContext(report,started,ended)
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local first='Standalone preview start: '..(started or 'selected=unavailable')
 local last='Standalone preview end: '..ended
 if bytes+1+#first+1+#last<16000 then report[#report+1]=first;report[#report+1]=last
 else
  local omitted='Standalone preview context omitted to keep report bounded.'
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
-- END STANDALONE PREVIEW CONTEXT
local function reference(owner,...)
 local keys={...}
 return function() local value=owner;for _,key in ipairs(keys) do value=field(value,key) end;return value end
end
local function definitionsOf(owner) return field(owner,'conditionDefinitions') or field(owner,'definitions') end
local function conditionReference(owner,key,callback)
 return function() return field(field(definitionsOf(owner),key),callback) end
end
local function selectFunctions(owner)
 local rows,seen,validationRows={},{},{};local truncated=false
 local function add(container,key,label,resolve)
  local fn=field(container,key);if type(fn)~='function' then return end
  resolve=resolve or reference(container,key)
  local previous=seen[fn]
  if previous then previous.refs[#previous.refs+1]=resolve;return previous end
  if #rows>=MAX_FUNCTIONS then truncated=true;return end
  local row={fn=fn,label=label,refs={resolve}};seen[fn]=row;rows[#rows+1]=row;return row
 end
 for _,name in ipairs(runtimeNames) do add(owner,name,'Runtime.'..name) end
 for _,name in ipairs(platformNames) do add(field(owner,'Platform'),name,'Platform.'..name,reference(owner,'Platform',name)) end
 for _,entry in ipairs({{'RotationData','IndexRotationSteps'},{'RotationData','CheckPortable'},{'SpellCatalog','GetAllSpellIds'},{'SpellCatalog','GetSpellId'}}) do
  local row=add(field(owner,entry[1]),entry[2],entry[1]..'.'..entry[2],reference(owner,entry[1],entry[2]))
  if entry[2]=='IndexRotationSteps' then validationRows.IndexRotationSteps=row end
 end
 for _,name in ipairs({'ValidateEnvelope','ValidateBody'}) do validationRows[name]=add(field(owner,'RotationData'),name,'RotationData.'..name,reference(owner,'RotationData',name)) end
 local functions=field(owner,'Functions');local cache=field(functions,'cache');add(cache,'getCached','Functions.cache.getCached',reference(owner,'Functions','cache','getCached'));add(cache,'getRetryCached','Functions.cache.getRetryCached',reference(owner,'Functions','cache','getRetryCached'))
 local definitions=definitionsOf(owner);local catalog=field(field(owner,'BuiltinSourceCatalog'),'conditions');local keys={};local scanned=0
 if type(definitions)=='table' then for key in pairs(definitions) do
  scanned=scanned+1;if scanned>MAX_SCAN then truncated=true;break end
  if readable(key) and type(key)=='string' then keys[#keys+1]=key end
 end end
 table.sort(keys,function(a,b)
  local aBuiltin=type(field(catalog,a))=='table';local bBuiltin=type(field(catalog,b))=='table'
  if aBuiltin~=bBuiltin then return aBuiltin end;return a<b
 end)
 local custom=0
 for _,key in ipairs(keys) do
  local definition=field(definitions,key);local label
  if type(field(catalog,key))=='table' and #key<=64 and key:match('^[A-Z][A-Z_0-9]*$') then label='Condition.'..key
  else custom=custom+1;label='Condition.custom'..custom end
  add(definition,'evaluate',label..'.evaluate',conditionReference(owner,key,'evaluate'));add(definition,'valid',label..'.valid',conditionReference(owner,key,'valid'))
 end
 return rows,truncated,validationRows
end
-- BEGIN PRIVATE CACHE SAMPLES
local function cacheFunction(owner,alias)
 if proofType(cacheSourceModules)~='table' or proofType(cacheSourceGetter)~='function' then return nil,'source-reader-unavailable' end
 if not cacheSourceEqual(owner,addon) or not cacheSourceEqual(proofRawget(owner,'builtinSourceModules'),cacheSourceModules)
  or not cacheSourceEqual(proofRawget(cacheSourceModules,'Functions/cache.lua'),cacheSourceGetter) then return nil,'source-reader-changed' end
 local ok,fn=proofPcall(cacheSourceGetter,alias)
 if not ok then return nil,'source-reader-error' end
 if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 return fn
end
local function privateCacheSelection(owner,rows)
 local result={views={},samples={}};local seen={}
 for _,row in ipairs(rows) do seen[row.fn]=row end
 for _,alias in ipairs({'getCachedInternal','packResults'}) do
  local fn,reason=cacheFunction(owner,alias)
  local view={alias=alias,label='Functions.cache.'..alias,reason=reason};result.views[#result.views+1]=view
  if fn then
   local sample=seen[fn]
   if not sample then
    if #rows+#result.samples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;result.samples[#result.samples+1]=sample end
   end
   view.sample=sample
  end
 end
 return result
end
-- BEGIN PRIVATE VALIDATION SCOPES
local validationEqual,validationSelect=rawequal,select
local validationSpecs={
 {name='references',anchor='GetRotationValidationStamp',slots={'observe','sameEntries','sameItemsets','proofGlobals'}},
 {name='library',anchor='InitializeRotationLibrary',slots={'ensure','eligible'}},
 {name='scope',anchor='BindRotationProfile',slots={'same'}},
}
local validationGroups,validationClosed,validationCount,validationCapture={},false,0,nil
local validationInstaller
local function validationRetire()
 validationClosed=true
 if validationEqual(proofRawget(addon,'BindCPUValidationScopeDiagnostic'),validationInstaller) then addon.BindCPUValidationScopeDiagnostic=nil end
end
validationInstaller=function(self,name,anchor,reader)
 if validationClosed or not validationEqual(self,addon) or proofType(name)~='string'
  or proofType(anchor)~='function' or proofType(reader)~='function' or validationGroups[name] then return false end
 local found
 for _,spec in ipairs(validationSpecs) do if name==spec.name then found=true;break end end
 if not found then return false end
 validationGroups[name]={anchor=anchor,reader=reader};validationCount=validationCount+1
 if validationCount==3 then validationRetire() end
 return true
end
addon.BindCPUValidationScopeDiagnostic=validationInstaller
local function validationClear(run)
 local state=run.validationScopes
 if state then state.phase='retired' end
 run.validationScopes=nil
 if validationCapture==run then validationCapture=nil end
end
local function validationEnding(run,status)
 if status~='complete' then validationClear(run)
 elseif run.validationScopes then run.validationScopes.phase='end' end
end
local function validationTuple(...) return {n=validationSelect('#',...),...} end
local function validationSnapshot(run,fn,current)
 if not current() then return nil,'capture-retired' end
 local ok,exclusive,calls=proofPcall(run.query,fn,false)
 if not current() then return nil,'capture-retired' end
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 local good,inclusive,inclusiveCalls=proofPcall(run.query,fn,true)
 if not current() then return nil,'capture-retired' end
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function validationFunctions(run,spec,group,current)
 if not current() then return nil,'capture-retired' end
 if not validationEqual(run.owner,addon) then return nil,'owner-changed' end
 if not group then return nil,'unbound' end
 local anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 local values=validationTuple(proofPcall(group.reader))
 if not current() then return nil,'capture-retired' end
 if not values[1] then return nil,'provider-unavailable' end
 if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
 for i=1,#spec.slots do
  local fn=values[i+1]
  if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 end
 anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 return values
end
local function validationStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},groups={}}
 run.validationScopes=state;validationCapture=run
 state.current=function()
  return validationCapture==run and run.validationScopes==state
   and (state.phase=='start' and active==run or state.phase=='end' and active==nil)
 end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,row in ipairs(run.privateCache.samples) do remember(row) end
 for _,row in ipairs(run.activity and run.activity.samples or {}) do remember(row) end
 for _,spec in ipairs(validationSpecs) do
  local group=validationGroups[spec.name];local funcs,reason=validationFunctions(run,spec,group,state.current)
  local source={spec=spec,group=group};state.groups[#state.groups+1]=source
  for i,name in ipairs(spec.slots) do
   local view={label='Validation.'..spec.name..'.'..name,group=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn
    local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else
      sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current)
     end
    end
    view.sample=sample
   end
  end
 end
end
local function appendValidationScopes(report,run,sampleEnd)
 local state=run.validationScopes
 local lines={'Private validation scopes (native counters; shared functions overlap):'};local available=0
 if state then
  for _,source in ipairs(state.groups) do source.functions,source.reason=validationFunctions(run,source.spec,source.group,state.current) end
 end
 local index=0
 for _,spec in ipairs(validationSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem
  if view then problem=view.reason else problem='baseline-unavailable' end
  local sample,current
  if view and not problem then
   local source=view.group;problem=source.reason
   if not problem and not validationEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
   sample=view.sample;problem=problem or sample.reason
   if not problem then current,problem=sampleEnd(run,sample,state.current) end
   if not problem then
    for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Validation.'..spec.name..'.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed validation views: aliases=7; available=%d; unavailable=%d (excluded from rankings above).',available,7-available)
 lines[#lines+1]='Shared helper counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private validation scopes omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE VALIDATION SCOPES
-- BEGIN RUNTIME WORK VIEWS
-- Fixed pointers only. Readers are source-local literal returns, not helpers.
local workGroups,workClosed,workCount,workCapture={},false,0,nil
local workEqual=rawequal
local workSpecs={
 {name='store',namespace='RotationData',anchor='NewRotationStore',slots={'Store.plain','Store.fields','Store.validAddress'}},
 {name='main',anchor='EvaluateNextActionInternal',slots={'Main.UpdateUnitInfo'}},
 {name='diagnostics',namespace='Diagnostics',member='Call',slots={'Diagnostics.Call'}},
 {name='profile',namespace='evaluationProfile',member='child',slots={'EvaluationProfile.child'}},
}
local workInstaller
local function workRetire()
 workClosed=true
 if workEqual(proofRawget(addon,'BindCPURuntimeWorkDiagnostic'),workInstaller) then addon.BindCPURuntimeWorkDiagnostic=nil end
end
workInstaller=function(self,name,anchor,reader)
 if workClosed or not workEqual(self,addon) or (name~='store' and name~='main')
  or proofType(anchor)~='function' or proofType(reader)~='function' or workGroups[name] then return false end
 local namespace=addon;if name=='store' then namespace=proofRawget(addon,'RotationData') end
 workGroups[name]={anchor=anchor,reader=reader,namespace=namespace}
 workCount=workCount+1;if workCount==2 then workRetire() end
 return true
end
addon.BindCPURuntimeWorkDiagnostic=workInstaller
local function workClear(run)
 local state=run.runtimeWork;if state then state.phase='retired' end
 run.runtimeWork=nil;if workCapture==run then workCapture=nil end
end
local function workEnding(run,status)
 if status~='complete' then workClear(run) elseif run.runtimeWork then run.runtimeWork.phase='end' end
end
local function workNamespace(spec)
 if spec.namespace then return proofRawget(addon,spec.namespace) end
 return addon
end
local function workFunctions(run,source,current)
 if not current() then return nil,'capture-retired' end
 if not workEqual(run.owner,addon) then return nil,'owner-changed' end
 local spec,group=source.spec,source.group
 if spec.anchor and not group then return nil,'unbound' end
 local namespace=workNamespace(spec)
 if not readable(namespace) or not workEqual(namespace,source.namespace) or proofType(namespace)~='table' then return nil,'owner-changed' end
 local values
 if spec.anchor then
  local anchor=proofRawget(namespace,spec.anchor)
  if not readable(anchor) or not workEqual(anchor,group.anchor) then return nil,'owner-changed' end
  if not current() then return nil,'capture-retired' end
  values=validationTuple(proofPcall(group.reader))
  if not current() then return nil,'capture-retired' end
  if not values[1] then return nil,'provider-unavailable' end
  if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
  if not workEqual(proofRawget(addon,spec.namespace or spec.anchor),spec.namespace and namespace or group.anchor)
   or not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 else values={true,proofRawget(namespace,spec.member)} end
 for i=1,#spec.slots do if not readable(values[i+1]) or proofType(values[i+1])~='function' then return nil,'invalid-source-function' end end
 if not current() then return nil,'capture-retired' end
 if not workEqual(workNamespace(spec),namespace) then return nil,'owner-changed' end
 if spec.anchor then
  if not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 elseif not workEqual(proofRawget(namespace,spec.member),values[2]) then return nil,'function-replaced' end
 return values
end
local function workStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},sources={}};run.runtimeWork=state;workCapture=run
 state.current=function() return workCapture==run and run.runtimeWork==state
  and (state.phase=='start' and active==run or state.phase=='end' and active==nil) end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,group in ipairs({run.privateCache,run.activity or {},run.validationScopes or {}}) do for _,row in ipairs(group.samples or {}) do remember(row) end end
 for _,spec in ipairs(workSpecs) do
  local group=workGroups[spec.name]
  local namespace=workNamespace(spec);if group then namespace=group.namespace end
  local source={spec=spec,group=group,namespace=namespace}
  state.sources[#state.sources+1]=source
  local funcs,reason=workFunctions(run,source,state.current)
  for i,name in ipairs(spec.slots) do
   local view={label='Work.'..name,source=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn;local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current) end
    end
    view.sample=sample
   end
  end
 end
end
local function appendWorkViews(report,run,sampleEnd)
 local state=run.runtimeWork
 local lines={'Runtime work views (native counters; shared functions overlap):'};local available=0;local index=0
 if state then for _,source in ipairs(state.sources) do source.functions,source.reason=workFunctions(run,source,state.current) end end
 for _,spec in ipairs(workSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem=view and view.reason or 'baseline-unavailable'
  local sample,current
  if view then
   problem=view.reason
   if not problem then
    local source=view.source;problem=source.reason
    if not problem and not workEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
    sample=view.sample;problem=problem or sample.reason
    if not problem then current,problem=sampleEnd(run,sample,state.current) end
    if not problem then for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Work.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed runtime work views: aliases=6; available=%d; unavailable=%d (excluded from rankings above).',available,6-available)
 lines[#lines+1]='Shared function counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Runtime work views omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END RUNTIME WORK VIEWS
local function finishSample(run,row,guard)
 if not row.sampled then
  row.sampled=true
  if guard then row.current,row.currentReason=validationSnapshot(run,row.fn,guard)
  else row.current,row.currentReason=snapshot(run,row.fn) end
 end
 return row.current,row.currentReason
end
local function appendPrivateCache(report,run)
 local lines={'Private cache helpers (native counters; shared functions overlap):'}
 local available=0
 for _,view in ipairs(run.privateCache.views) do
  local sample,problem=view.sample,view.reason
  if not problem then
   local fn;fn,problem=cacheFunction(run.owner,view.alias)
   if not problem and not cacheSourceEqual(fn,sample.fn) then problem='function-replaced' end
   problem=problem or sample.reason
  end
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and view.label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',view.label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Private helper views: aliases=2; available=%d; unavailable=%d (excluded from rankings above).',available,2-available)
 lines[#lines+1]='Shared helper counters include all callers, including archived copies; inclusive costs overlap.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private cache helpers omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE CACHE SAMPLES
-- BEGIN CPU ACTIVITY DIAGNOSTICS
local activityProviders,activityFrame,activityAPI={},nil,nil
local activityEqual,activityCreate=rawequal,CreateFrame
function addon:BindCPUActivityDiagnostic(name,reader)
 if self~=addon or (name~='spell' and name~='item' and name~='visual') or proofType(reader)~='function' or activityProviders[name] then return false end
 activityProviders[name]=reader
 if activityProviders.spell and activityProviders.item and activityProviders.visual then addon.BindCPUActivityDiagnostic=nil end
 return true
end
local function activityRead()
 local result={}
 for _,name in ipairs({'spell','item','visual'}) do
  local reader=activityProviders[name]
  if reader then local ok,value=proofPcall(reader,activityAPI);if ok and proofType(value)=='table' then result[name]=value end end
 end
 return result
end
local function activityEvent(run,event,_,success)
 if not readable(success) or proofType(success)~='boolean' then run.activity.events.unknown=run.activity.events.unknown+1;return end
 if success then
  if event=='SPELL_DATA_LOAD_RESULT' then run.activity.events.spell=run.activity.events.spell+1
  elseif event=='ITEM_DATA_LOAD_RESULT' then run.activity.events.item=run.activity.events.item+1 end
 end
end
local function activityStop(run)
 local state=run.activity;if not state then return end
 if state.lease then state.lease.run=nil;state.lease=nil end
 local frame,api=state.frame,state.api;state.frame=nil;state.api=nil
 if frame and api then
  local ok,current=proofPcall(api.GetScript,frame,'OnEvent')
  local released=false
  if ok and activityEqual(current,state.handler) then
   local events=proofPcall(api.UnregisterAllEvents,frame);local handler=proofPcall(api.SetScript,frame,'OnEvent',nil);released=events and handler
  end
  if not released then
   state.events.available=false
   if activityEqual(activityFrame,frame) then activityFrame=nil;activityAPI=nil end
  end
 end
 state.handler=nil
end
local function activityStart(run)
 addon.BindCPUActivityDiagnostic=nil
 run.activity={events={spell=0,item=0,unknown=0,available=false},views={},samples={}}
 local state=run.activity
 if not activityFrame and proofType(activityCreate)=='function' then
  local ok,frame=proofPcall(activityCreate,'Frame')
  if ok and frame then
   local api={};local valid=true
   for _,name in ipairs({'GetScript','SetScript','RegisterEvent','UnregisterAllEvents','Hide','GetParent','IsVisible'}) do
    local method=frame[name];if proofType(method)~='function' then valid=false end;api[name]=method
   end
   if valid then activityFrame,activityAPI=frame,api;proofPcall(api.Hide,frame) end
  end
 end
 if activityFrame then
  state.frame=activityFrame;state.api=activityAPI
  local lease={run=run};state.lease=lease
  state.handler=function(_,event,...)
   local current=lease.run;if not current or active~=current then return end
   if not proofPcall(activityEvent,current,event,...) then current.activity.events.unknown=current.activity.events.unknown+1 end
  end
  local ok=proofPcall(function()
   activityAPI.SetScript(activityFrame,'OnEvent',state.handler)
   activityAPI.RegisterEvent(activityFrame,'SPELL_DATA_LOAD_RESULT');activityAPI.RegisterEvent(activityFrame,'ITEM_DATA_LOAD_RESULT')
  end)
  if ok then state.events.available=true else activityStop(run) end
 end
 state.started=activityRead()
 local seen,totalSamples={},#run.rows+#run.privateCache.samples
 for _,row in ipairs(run.rows) do seen[row.fn]=row end
 for _,row in ipairs(run.privateCache.samples) do seen[row.fn]=row end
 local visual=state.started.visual
 for _,name in ipairs({'overlay','pixel','autocast','blizzard'}) do
  local view={name=name};state.views[#state.views+1]=view
  local callbacks=field(visual,'callbacks');local ambiguous=field(visual,'ambiguous')
  local fn=field(callbacks,name)
  if field(ambiguous,name)==true then view.reason='ambiguous-callback'
  elseif proofType(fn)~='function' or not readable(fn) then view.reason='no-start-callback'
  else
   local sample=seen[fn]
   if not sample then
    if totalSamples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;totalSamples=totalSamples+1;state.samples[#state.samples+1]=sample;sample.before,sample.reason=snapshot(run,fn) end
   end
   view.sample=sample
  end
 end
end
local function appendActivity(report,run)
 local state=run.activity;if not state then return end
 local lines={'Retained catalogs and animation activity (capture only):'}
 local function retained(root,key)
  local object=field(root,key);local n=field(object,'n');local capped=field(object,'capped')
  if not counter(n,true) or n>4096 or proofType(capped)~='boolean' then return 'unavailable' end
  return (capped and '>=' or '')..tostring(n),not capped and n or nil
 end
 for _,entry in ipairs({{'spell','spellIDs','spell IDs'},{'spell','spellNames','spell name groups'},{'item','itemRecords','item records'},{'item','itemIndex','item index'},{'item','itemBlocked','blocked items'}}) do
  local start,before=retained(field(state.started,entry[1]),entry[2]);local ending,after=retained(field(state.ended,entry[1]),entry[2])
  lines[#lines+1]=entry[3]..': start='..start..'; end='..ending..'; change='..(before~=nil and after~=nil and tostring(after-before) or 'unavailable')
 end
 local events=state.events
 lines[#lines+1]=events.available and string.format('metadata successes: spell=%s; item=%s; unknown=%s',tostring(events.spell),tostring(events.item),tostring(events.unknown)) or 'metadata successes: unavailable'
 local function visual(label,value)
  if proofType(value)~='table' then return label..' visuals: unavailable' end
  local parts={label..' visuals:'}
  for _,key in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(value,key);parts[#parts+1]=key..'='..(counter(n,true) and n<=4096 and tostring(n) or 'unavailable')
  end
  parts[#parts+1]='capped='..(field(value,'capped')==true and 'true' or 'false')
  if field(value,'unsupported')==true then parts[#parts+1]='native-observation=unavailable' end
  return table.concat(parts,' ')
 end
 lines[#lines+1]=visual('start',field(state.started,'visual'));lines[#lines+1]=visual('end',field(state.ended,'visual'))
 local labels={overlay='RM.UpdateOverlay',pixel='SharedGlow.Pixel.OnUpdate',autocast='SharedGlow.AutoCast.OnUpdate',blizzard='SharedGlow.Blizzard.OnUpdate'}
 local available=0
 for _,view in ipairs(state.views) do
  local sample,problem=view.sample,view.reason
  if not field(state.ended,'visual') then problem=problem or 'source-reader-changed' end
  problem=problem or sample and sample.reason
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and labels[view.name]..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',labels[view.name],exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Animation views: aliases=4; available=%d; unavailable=%d (excluded from rankings above).',available,4-available)
 lines[#lines+1]='Catalog counts are keys, not bytes; global metadata arrivals may originate outside RM. Capped counts are lower bounds; sequence counts timer handles regardless of visibility, not measured executions.'
 lines[#lines+1]='Shared glow frames are associated with RM-active slots; shared callback counters include all callers. Start callbacks only; end-only callbacks lack a baseline. Proc uses native animations.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Retained activity omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END CPU ACTIVITY DIAGNOSTICS
local function finish(run,status,reason)
 if active~=run then return end
 -- BEGIN PRIVATE VALIDATION END TOKEN
 validationEnding(run,status)
 -- END PRIVATE VALIDATION END TOKEN
 -- BEGIN RUNTIME WORK END TOKEN
 workEnding(run,status)
 -- END RUNTIME WORK END TOKEN
 active=nil;run.timer=nil
 -- BEGIN CPU ACTIVITY STOP
 activityStop(run)
 -- END CPU ACTIVITY STOP
 local text
 if status=='complete' then
  local now,why=clock(run.clock);local elapsed=now and now-run.started
  if not elapsed or not finite(elapsed) or elapsed<=0 then status,reason='invalid',why or 'clock-reset' end
  if status=='complete' then
   local allowed,problem=enabled(run.cvar)
   if clockAPI()~=run.clock or cvarAPI()~=run.cvar or GetFunctionCPUUsage~=run.query or totalAPI()~=run.total or updateAPI()~=run.update then status,reason='invalid','profiling-api-changed'
   elseif not allowed then status,reason='invalid',problem end
  end
  local used,rate
  if status=='complete' then local value,problem=total(run);if value==nil or value<run.initialTotal then status,reason='invalid',problem or 'addon-cpu-counter-reset' else used=value-run.initialTotal;if not finite(used) then status,reason='invalid','invalid-addon-cpu-delta' end end end
  if status=='complete' then rate=used/elapsed;if not finite(rate) then status,reason='invalid','invalid-cpu-rate' end end
  if status=='complete' then
   -- BEGIN CPU ACTIVITY END
   if run.activity then run.activity.ended=activityRead() end
   -- END CPU ACTIVITY END
   local ranked,unavailable={},{}
   for _,row in ipairs(run.rows) do
    local problem=row.reason
    for _,ref in ipairs(row.refs) do if ref()~=row.fn then problem='function-replaced';break end end
    local current;if not problem then current,problem=finishSample(run,row) end
    if not problem then
     for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<row.before[key] then problem='function-cpu-counter-reset';break end end
    end
    if not problem then
     local result={label=row.label,exclusive=current.exclusive-row.before.exclusive,inclusive=current.inclusive-row.before.inclusive,calls=current.calls-row.before.calls}
     if not finite(result.exclusive) or not finite(result.inclusive) or not counter(result.calls,true) then problem='invalid-function-cpu-delta' else ranked[#ranked+1]=result;row.deltaCalls=result.calls end
    end
    if problem then unavailable[#unavailable+1]={label=row.label,reason=problem} end
   end
   table.sort(ranked,function(a,b) if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;return a.label<b.label end)
   local report={'Rotation Master CPU profile: complete',string.format('duration=%.3f s; addon CPU=%.3f ms; addon rate=%.3f ms/s',elapsed,used,rate),
    'start '..run.context,'end '..context(run.owner),'States describe capture boundaries only; activity may change within the interval.',
    'Native cumulative counters include collection and profiling overhead. Inclusive rows overlap and are not additive.',
    'Rows are selected coverage, not complete CPU accounting; addon and function snapshot boundaries differ slightly.',
    string.format('selected=%d; available=%d; unavailable=%d; top=%d%s',#run.rows,#ranked,#unavailable,math.min(TOP,#ranked),run.truncated and '; selection truncated' or '')}
   local function validationCount(name)
    local row=run.validationRows[name]
    return row and row.deltaCalls~=nil and tostring(row.deltaCalls) or 'unavailable'
   end
   report[#report+1]='Structural validation calls: ValidateEnvelope='..validationCount('ValidateEnvelope')..'; ValidateBody='..validationCount('ValidateBody')..' (native counters; shared functions overlap).'
   report[#report+1]='Execution indexing calls: IndexRotationSteps='..validationCount('IndexRotationSteps')..' (native counter).'
   for index=1,math.min(TOP,#ranked) do local row=ranked[index];local mean=row.calls>0 and row.exclusive/row.calls or nil
    report[#report+1]=string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s | mean=%s ms',row.label,row.exclusive,row.inclusive,tostring(row.calls),mean and string.format('%.3f',mean) or 'unavailable')
   end
   for index=1,math.min(10,#unavailable) do local row=unavailable[index];report[#report+1]=row.label..' | unavailable: '..row.reason end
   if #unavailable>10 then report[#report+1]='Additional unavailable rows omitted.' end
   -- BEGIN INCLUSIVE CPU SCOPES
   -- Existing lines are complete before this second view of the same rows.
   local reportBytes=#report-1
   for _,line in ipairs(report) do reportBytes=reportBytes+#line end
   local title='Inclusive scopes (top 10; includes descendants; overlapping, not additive):'
   local omitted='Additional inclusive scopes omitted to keep report bounded.'
   if reportBytes+1+#title+1+#omitted<16000 then
    report[#report+1]=title;reportBytes=reportBytes+1+#title
    table.sort(ranked,function(a,b) if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;return a.label<b.label end)
    for index=1,math.min(10,#ranked) do local row=ranked[index]
     local line=string.format('%s | inclusive=%.3f ms | exclusive=%.3f ms | calls=%s',row.label,row.inclusive,row.exclusive,tostring(row.calls))
     if reportBytes+1+#line+1+#omitted>=16000 then report[#report+1]=omitted;break end
     report[#report+1]=line;reportBytes=reportBytes+1+#line
    end
   end
   -- END INCLUSIVE CPU SCOPES
   -- BEGIN EXECUTION INDEX DIAGNOSTICS
   appendExecutionIndexProof(report,run.executionIndexProof,executionIndexProof())
   -- END EXECUTION INDEX DIAGNOSTICS
   -- BEGIN PRIVATE CACHE APPENDIX
   appendPrivateCache(report,run)
   -- END PRIVATE CACHE APPENDIX
   -- BEGIN CPU ACTIVITY APPENDIX
   appendActivity(report,run)
   -- END CPU ACTIVITY APPENDIX
   -- BEGIN STANDALONE PREVIEW APPENDIX
   appendStandalonePreviewContext(report,run.previewContext,standalonePreviewContext(run.owner))
   -- END STANDALONE PREVIEW APPENDIX
   -- BEGIN PRIVATE VALIDATION APPENDIX
   local validationState=run.validationScopes
   local validationEntered=validationState and validationState.current()
   appendValidationScopes(report,run,finishSample)
   if validationEntered and not validationState.current() then validationClear(run);return end
   -- END PRIVATE VALIDATION APPENDIX
   -- BEGIN RUNTIME WORK APPENDIX
   local workState=run.runtimeWork
   local workEntered=workState and workState.current()
   appendWorkViews(report,run,finishSample)
   if workEntered and not workState.current() then workClear(run);return end
   -- END RUNTIME WORK APPENDIX
   -- BEGIN COLD STORE STRING END
   local shapeEntered=workState and workState.current()
   appendStoreStringShape(report,run.storeStringShape,storeStringShape())
   if shapeEntered and not workState.current() then workClear(run);return end
   -- END COLD STORE STRING END
   text=table.concat(report,'\n')
  end
 end
 text=text or 'Rotation Master CPU profile: '..status..(reason and ' ('..reason..')' or '')
 -- BEGIN PRIVATE VALIDATION CLEANUP
 validationClear(run)
 -- END PRIVATE VALIDATION CLEANUP
 -- BEGIN RUNTIME WORK CLEANUP
 workClear(run)
 -- END RUNTIME WORK CLEANUP
 lastReport=text
 local callback=field(run.owner,'OnCPUProfileFinished');if type(callback)=='function' then pcall(callback,run.owner,text,status) end
end
function addon:StartCPUProfile(duration)
 -- BEGIN NATIVE RUNTIME EXCLUSION
 if type(self.IsCPURuntimeCaptureRunning)=='function' and self:IsCPURuntimeCaptureRunning() then return false,'native-runtime-capture-running' end
 -- END NATIVE RUNTIME EXCLUSION
 -- BEGIN PRIVATE VALIDATION RETIRE
 validationRetire()
 -- END PRIVATE VALIDATION RETIRE
 -- BEGIN RUNTIME WORK RETIRE
 workRetire()
 -- END RUNTIME WORK RETIRE
 if active then return false,'already-running' end
 if duration==nil then duration=10 end
 if not finite(duration) or duration<1 or duration>60 then return false,'invalid-duration' end
 local cvar=cvarAPI();local allowed,reason=enabled(cvar);if not allowed then return false,reason end
 if type(GetFunctionCPUUsage)~='function' then return false,'missing-function-cpu-api' end
 if not totalAPI() or not updateAPI() then return false,'missing-addon-cpu-api' end
 if type(self.ScheduleTimer)~='function' or type(self.CancelTimer)~='function' then return false,'missing-timer-api' end
 local run={owner=self,query=GetFunctionCPUUsage,total=totalAPI(),update=updateAPI(),clock=clockAPI(),cvar=cvar,duration=duration,cancel=self.CancelTimer}
 run.started,reason=clock(run.clock);if run.started==nil then return false,reason end
 run.initialTotal,reason=total(run);if run.initialTotal==nil then return false,reason end
 run.rows,run.truncated,run.validationRows=selectFunctions(self);run.context=context(self)
 local available=0
 for _,row in ipairs(run.rows) do row.before,row.reason=snapshot(run,row.fn);if row.before then available=available+1 end end
 if available==0 then return false,'function-cpu-unavailable' end
 -- BEGIN PRIVATE CACHE START
 run.privateCache=privateCacheSelection(self,run.rows)
 for _,sample in ipairs(run.privateCache.samples) do sample.before,sample.reason=snapshot(run,sample.fn) end
 -- END PRIVATE CACHE START
 active=run
 -- BEGIN CPU ACTIVITY START
 local activityOK=proofPcall(activityStart,run)
 if not activityOK then activityStop(run);run.activity=nil end
 -- END CPU ACTIVITY START
 -- BEGIN PRIVATE VALIDATION START
 local validationEntered=active==run
 validationStart(run)
 if validationEntered and active~=run then validationClear(run);return true end
 -- END PRIVATE VALIDATION START
 -- BEGIN RUNTIME WORK START
 local workEntered=active==run
 workStart(run)
 if workEntered and active~=run then workClear(run);return true end
 -- END RUNTIME WORK START
 local ok,timer=pcall(self.ScheduleTimer,self,function() finish(run,'complete') end,duration)
 -- BEGIN PRIVATE VALIDATION TIMER FAILURE
 if not ok or not timer then validationClear(run) end
 -- END PRIVATE VALIDATION TIMER FAILURE
 -- BEGIN RUNTIME WORK TIMER FAILURE
 if not ok or not timer then workClear(run) end
 -- END RUNTIME WORK TIMER FAILURE
 if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end
 run.timer=timer;if active==run then run.executionIndexProof=executionIndexProof() end;lastReport=nil
 -- BEGIN STANDALONE PREVIEW START
 if active==run then run.previewContext=standalonePreviewContext(self) end
 -- END STANDALONE PREVIEW START
 -- BEGIN COLD STORE STRING START
 if active==run then
  run.storeStringShape=storeStringShape()
  if active~=run then return true end
 end
 -- END COLD STORE STRING START
 return true
end
function addon:CancelCPUProfile()
 local run=active;if not run then return false,'not-running' end
 if run.timer then pcall(run.cancel,run.owner,run.timer) end
 finish(run,'cancelled');return true
end
function addon:IsCPUProfileRunning() return active~=nil end
function addon:GetCPUProfileReport()
 if active then return string.format('Rotation Master CPU profile: running (requested %.3f s)',active.duration) end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
-- AceAddon invokes this before AceTimer retires the addon's embedded timers.
-- The ordinary rotation enable/disable toggle remains independent of capture.
function addon:OnDisable()
 -- BEGIN NATIVE RUNTIME DISABLE
 if type(self.CancelCPURuntimeCapture)=='function' then self:CancelCPURuntimeCapture() end
 -- END NATIVE RUNTIME DISABLE
 self:CancelCPUProfile()
 if type(self.ClearCastCaptureForDisable)=='function' then self:ClearCastCaptureForDisable() end
end
]========],
        after = [========[local addon_name,addon=...
-- Opt-in cumulative snapshots. No functions are wrapped and shared counters are
-- never reset. Only this module's one completion timer exists during capture.
local active,lastReport
-- Fixed, source-free proof snapshots. The installer is retired by main;
-- this reader is private and is never invoked outside capture boundaries.
local proofType,proofRawget,proofPcall=type,rawget,pcall
-- BEGIN PRIVATE CACHE ANCHORS
local cacheSourceEqual=rawequal
local cacheSourceModules=proofRawget(addon,'builtinSourceModules')
local cacheSourceGetter=proofType(cacheSourceModules)=='table' and proofRawget(cacheSourceModules,'Functions/cache.lua') or nil
-- END PRIVATE CACHE ANCHORS
local executionIndexDiagnostic
function addon:BindCPUExecutionIndexDiagnostic(provider)
 if self~=addon or executionIndexDiagnostic or proofType(provider)~="function" then return end
 executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","parser-match-unavailable","parser-sub-unavailable","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
 if not executionIndexDiagnostic then return "probe-unavailable" end
 local ok,text=proofPcall(function()
  local status=executionIndexDiagnostic()
  if proofType(status)~="table" then return "probe-unavailable" end
  local parts={}
  for i=1,4 do
   local name=proofOwners[i];local row=proofRawget(status,name)
   local reason=proofType(row)=="table" and proofRawget(row,"reason") or nil
   reason=proofType(reason)=="string" and proofRawget(proofReasons,reason) and reason or "unavailable"
   local part=name.."="..reason
   if reason~="ready" and name~="main" then
    local flags=proofType(row)=="table" and proofRawget(row,"raw") or nil
    part=part.."["
    for keyIndex=1,7 do
     local key=proofRawKeys[keyIndex]
     if name~="sequence" or key=="type" or key=="ipairs" or key=="getfenv" then
      local flag=proofType(flags)=="table" and proofRawget(flags,key)
      part=part..key.."="..(flag==true and "1" or flag==false and "0" or "?").."," end
    end
    part=part.."]"
   end
   parts[i]=part
  end
  local function parserFlag(owner,key)
   local row=proofRawget(status,owner)
   local value=proofType(row)=="table" and proofRawget(row,key)
   return value==true and "1" or value==false and "0" or "?"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; parser-match="..parserFlag("index","parserMatch").."; parser-sub="..parserFlag("portable","parserSub")
 end)
 return ok and text or "probe-unavailable"
end
local function appendExecutionIndexProof(report,started,ended)
 local bytes=#report-1
 for i=1,#report do bytes=bytes+#report[i] end
 local first="Execution index proof start: "..(started or "probe-unavailable")
 local last="Execution index proof end: "..ended
 if bytes+1+#first+1+#last<16000 then
  report[#report+1]=first;report[#report+1]=last
 else
  local omitted="Execution index proof omitted to keep report bounded."
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
local runtimeNames={
 'EvaluateNextAction','EvaluateNextActionInternal','UpdateCurrentCondition','Fetch','UpdateBagContents',
 'GetRotationOwnerContext','GetRotationContext','GetRotationValidationStamp','GetRotationValidationOptions',
 'AcquireRotationRuntimePass','GetRuntimeRotations','GetRuntimeRotation','GetRotationCandidates',
 'EvaluateRotationSequence','rotationValidConditions','evaluateConditionResult','validateCondition',
 'NewActionReadiness','GetConditionUnitLevel','GetConditionPointResource','GetClassGroupCount','EvaluateItemCondition',
 'RefreshPreviewWindow','RemoveAllCurrentGlows','DestroyAllGlows','RefreshMacroButtons','UpdateButtonGlow','GlowNextSpell','GlowSpell','GlowCooldown','IsGlowing','FindSpell','GetSpellIds','RefreshSpellCatalog',
}
local platformNames={}
for name in ([[AuraRemaining CanReadValue GetAPISurface GetAnnouncementGroup GetAssistedAvailability GetAuraByIndex GetBagItemCounts GetBagSnapshot GetClientInfo GetGlobalCooldown GetGlyphItemInfo GetGlyphSocketSnapshot GetGridTalentInfo GetGroupMembership GetInstanceObservation GetItemCooldown GetItemCount GetItemDisplayInfo GetItemID GetItemInfoInstant GetItemMetadata GetItemRangeState GetItemUseSpell GetLossOfControlCount GetLossOfControlEvent GetMobInfo2Observation GetMacroAction GetNameplateMaxDistance GetPetObservation GetPlayerFlagObservation GetPlayerFormObservation GetPlayerMovementObservation GetPlayerOwnerClassObservation GetPrimaryTalentTree GetRangeCheckBounds GetRosterClassObservation GetRotationSpecialization GetRotationSpecializations GetRuneCooldownObservation GetRuneEvaluationTime GetRuneTypeObservation GetSpellBookSnapshot GetSpellCharges GetSpellCooldown GetSpellInfo GetSpellLink GetSpellRangeState GetTalentLayout GetTalentTreeCount GetTalentTreeInfo GetTotemInfo GetTotemSlotCount GetTreeTalentCount GetTreeTalentInfo GetUnitAttackabilityObservation GetUnitCastObservation GetUnitFlagObservation GetUnitHealthObservation GetUnitIdentityObservation GetUnitLevelObservation GetUnitMetadataObservation GetUnitPointIdentityObservation GetUnitPointPowerObservation GetUnitPowerObservation GetUnitThreatObservation GetZonePVPObservation IsAutoRepeatActive IsBeyondMeleeRange IsCurrentSpell IsItemEquipped IsItemLevelAllowed IsItemReady IsMeleeAttackNeeded IsSpellKnown IsSpellReady IsSpellUsable NewSpellRangeReader ReadAuraField SendAnnouncementChat]]):gmatch('%S+') do platformNames[#platformNames+1]=name end
local function readable(value)
 if type(issecretvalue)=='function' then local ok,secret=pcall(issecretvalue,value);if not ok or secret then return false end end
 if type(canaccessvalue)=='function' then local ok,allowed=pcall(canaccessvalue,value);if not ok or not allowed then return false end end
 return true
end
-- BEGIN COLD STORE STRING SHAPE
-- Current observations only: cached constructor identities/admission stay private.
local function storeStringShape()
 local ok,text=proofPcall(function()
  local meta=getmetatable('');if not readable(meta) then return 'unavailable' end
  local index;if proofType(meta)=='table' then index=proofRawget(meta,'__index') end
  if not readable(index) then return 'unavailable' end
  local find;if proofType(index)=='table' then find=proofRawget(index,'find') end
  if not readable(find) then return 'unavailable' end
  local repeated=getmetatable('');if not readable(repeated) then return 'unavailable' end
  local repeatedIndex;if proofType(repeated)=='table' then repeatedIndex=proofRawget(repeated,'__index') end
  if not readable(repeatedIndex) then return 'unavailable' end
  return 'meta='..proofType(meta)..'; index='..proofType(index)..'; raw-find='..proofType(find)
   ..'; repeat-meta='..(cacheSourceEqual(meta,repeated) and '1' or '0')
   ..'; repeat-index='..(cacheSourceEqual(index,repeatedIndex) and '1' or '0')
 end)
 return ok and text or 'unavailable'
end
local function appendStoreStringShape(report,started,ended)
 local lines={'Store string shape start: '..(started or 'unavailable'),'Store string shape end: '..ended,
  'Necessary shape only: table/table/function and stable reads; does not prove private-store use or cached factory identities/admission.'}
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Store string shape omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END COLD STORE STRING SHAPE
local function finite(value) return readable(value) and type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
local function counter(value,integer) return finite(value) and value>=0 and (not integer or value%1==0) end
local function field(owner,key) if type(owner)=='table' then return rawget(owner,key) end end
local function addonCPUAPI(name,legacy)
 local candidate=field(C_AddOns,name)
 if type(candidate)=='function' then return candidate end
 if type(legacy)=='function' then return legacy end
end
local function totalAPI() return addonCPUAPI('GetAddOnCPUUsage',GetAddOnCPUUsage) end
local function updateAPI() return addonCPUAPI('UpdateAddOnCPUUsage',UpdateAddOnCPUUsage) end
local function cvarAPI() return type(GetCVar)=='function' and GetCVar or type(C_CVar)=='table' and type(C_CVar.GetCVar)=='function' and C_CVar.GetCVar or nil end
local function enabled(fn)
 if type(fn)~='function' then return false,'missing-script-profile-api' end
 local ok,value=pcall(fn,'scriptProfile');if not ok then return false,'script-profile-query-error' end
 if not readable(value) then return false,'restricted-script-profile' end
 if value=='0' then return false,'script-profile-disabled' end
 if value~='1' then return false,'invalid-script-profile-result' end
 return true
end
local function clockAPI() return type(GetTimePreciseSec)=='function' and GetTimePreciseSec or type(GetTime)=='function' and GetTime or nil end
local function clock(fn)
 if type(fn)~='function' then return nil,'missing-clock-api' end
 local ok,value=pcall(fn);if not ok then return nil,'clock-error' end
 if not counter(value) then return nil,'invalid-clock' end
 return value
end
local function total(run)
 local ok=pcall(run.update);if not ok then return nil,'addon-cpu-update-error' end
 local good,value=pcall(run.total,addon_name);if not good then return nil,'addon-cpu-query-error' end
 if not counter(value) then return nil,'invalid-addon-cpu-counter' end
 return value
end
local function snapshot(run,fn)
 local ok,exclusive,calls=pcall(run.query,fn,false)
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 local good,inclusive,inclusiveCalls=pcall(run.query,fn,true)
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function visibility(owner)
 local frame=field(owner,'frame') or owner
 local method=type(frame)=='table' and frame.IsShown
 if type(method)~='function' then return nil end
 local ok,shown=pcall(method,frame);if ok and readable(shown) and type(shown)=='boolean' then return shown end
end
local function context(owner)
 local config=visibility(field(owner,'configWindow'));local dialog=visibility(field(owner,'nativeCustomConditionDialog'))
 if dialog==true then config=true end
 local combat='unavailable';if type(InCombatLockdown)=='function' then local ok,value=pcall(InCombatLockdown);if ok and readable(value) and type(value)=='boolean' then combat=tostring(value) end end
 local profile=field(field(owner,'db'),'profile')
 local function interval(key) local value=field(profile,key);if finite(value) or readable(value) and type(value)=='boolean' then return tostring(value) end;return 'unavailable' end
 local result='config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
 -- BEGIN CACHE MODE CONTEXT
 local mode=field(owner,'GetCacheDiagnosticMode')
 if type(mode)=='function' then
  local ok,loaded,requested,pending=pcall(mode,owner)
  local function known(value) return readable(value) and type(value)=='string' and (value=='cached' or value=='direct') end
  if ok and known(loaded) and known(requested) and readable(pending) and type(pending)=='boolean' then
   result=result..' observation-cache='..loaded..' requested='..requested..' reload='..tostring(pending)
  else result=result..' observation-cache=unavailable' end
 end
 return result
 -- END CACHE MODE CONTEXT
end
-- BEGIN STANDALONE PREVIEW CONTEXT
-- Canonical-slot observation only; this does not authenticate foreign frames.
local previewNumbers={[0]='0','1','2','3','4','5'}
local function standalonePreviewContext(owner)
 local ok,text=pcall(function()
  local selected,canonical=field(owner,'nextWindow'),field(owner,'nativePreviewWindow')
  if not readable(selected) then return 'selected=unavailable' end
  if selected==nil then return 'selected=none' end
  local marker=field(selected,'nativePreview')
  if not readable(canonical) or not readable(marker) then return 'selected=unavailable' end
  if type(selected)~='table' or not rawequal(selected,canonical) or marker~=true then return 'selected=custom' end
  local db=field(owner,'db');local profile=field(db,'profile');local frame=field(selected,'frame')
  local activeValue,count,slots,windowProfile=field(selected,'active'),field(selected,'count'),field(selected,'slots'),field(selected,'profile')
  local setting,generation=field(profile,'preview_spells'),field(selected,'generation')
  local capture=active
  local function current()
   return active==capture and rawequal(field(owner,'nextWindow'),selected) and rawequal(field(owner,'nativePreviewWindow'),canonical)
    and rawequal(field(owner,'db'),db) and rawequal(field(db,'profile'),profile) and rawequal(field(selected,'frame'),frame)
    and rawequal(field(selected,'nativePreview'),marker) and rawequal(field(selected,'active'),activeValue)
    and rawequal(field(selected,'count'),count) and rawequal(field(selected,'slots'),slots)
    and rawequal(field(selected,'profile'),windowProfile) and rawequal(field(profile,'preview_spells'),setting)
    and rawequal(field(selected,'generation'),generation)
  end
  local function number(value)
   if readable(value) and type(value)=='number' and value==value and value>=0 and value<=5 and value%1==0 then return previewNumbers[value] end
   return '?'
  end
  local function boolean(value)
   if readable(value) and type(value)=='boolean' then return value and '1' or '0' end
   return '?'
  end
  local shown='?'
  if readable(frame) and type(frame)=='table' then
   local valid,value=pcall(function()
    local method=frame.IsShown
    if readable(method) and type(method)=='function' and current() then return method(frame) end
   end)
   if valid then shown=boolean(value) end
  end
  local sameProfile='?'
  if readable(profile) and readable(windowProfile) and type(profile)=='table' and type(windowProfile)=='table' then
   sameProfile=rawequal(profile,windowProfile) and 'current' or 'different'
  end
  local result='selected=canonical shown='..shown..' active='..boolean(activeValue)..' setting='..number(setting)
   ..' slots='..number(slots)..' recommendations='..number(count)..' profile='..sameProfile
  -- A getter or visibility method may retire/rebind this surface mid-snapshot.
  if not current() then return 'selected=unavailable' end
  return result
 end)
 return ok and text or 'selected=unavailable'
end
local function appendStandalonePreviewContext(report,started,ended)
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local first='Standalone preview start: '..(started or 'selected=unavailable')
 local last='Standalone preview end: '..ended
 if bytes+1+#first+1+#last<16000 then report[#report+1]=first;report[#report+1]=last
 else
  local omitted='Standalone preview context omitted to keep report bounded.'
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
-- END STANDALONE PREVIEW CONTEXT
local function reference(owner,...)
 local keys={...}
 return function() local value=owner;for _,key in ipairs(keys) do value=field(value,key) end;return value end
end
local function definitionsOf(owner) return field(owner,'conditionDefinitions') or field(owner,'definitions') end
local function conditionReference(owner,key,callback)
 return function() return field(field(definitionsOf(owner),key),callback) end
end
local function selectFunctions(owner)
 local rows,seen,validationRows={},{},{};local truncated=false
 local function add(container,key,label,resolve)
  local fn=field(container,key);if type(fn)~='function' then return end
  resolve=resolve or reference(container,key)
  local previous=seen[fn]
  if previous then previous.refs[#previous.refs+1]=resolve;return previous end
  if #rows>=MAX_FUNCTIONS then truncated=true;return end
  local row={fn=fn,label=label,refs={resolve}};seen[fn]=row;rows[#rows+1]=row;return row
 end
 for _,name in ipairs(runtimeNames) do add(owner,name,'Runtime.'..name) end
 for _,name in ipairs(platformNames) do add(field(owner,'Platform'),name,'Platform.'..name,reference(owner,'Platform',name)) end
 for _,entry in ipairs({{'RotationData','IndexRotationSteps'},{'RotationData','CheckPortable'},{'SpellCatalog','GetAllSpellIds'},{'SpellCatalog','GetSpellId'}}) do
  local row=add(field(owner,entry[1]),entry[2],entry[1]..'.'..entry[2],reference(owner,entry[1],entry[2]))
  if entry[2]=='IndexRotationSteps' then validationRows.IndexRotationSteps=row end
 end
 for _,name in ipairs({'ValidateEnvelope','ValidateBody'}) do validationRows[name]=add(field(owner,'RotationData'),name,'RotationData.'..name,reference(owner,'RotationData',name)) end
 local functions=field(owner,'Functions');local cache=field(functions,'cache');add(cache,'getCached','Functions.cache.getCached',reference(owner,'Functions','cache','getCached'));add(cache,'getRetryCached','Functions.cache.getRetryCached',reference(owner,'Functions','cache','getRetryCached'))
 local definitions=definitionsOf(owner);local catalog=field(field(owner,'BuiltinSourceCatalog'),'conditions');local keys={};local scanned=0
 if type(definitions)=='table' then for key in pairs(definitions) do
  scanned=scanned+1;if scanned>MAX_SCAN then truncated=true;break end
  if readable(key) and type(key)=='string' then keys[#keys+1]=key end
 end end
 table.sort(keys,function(a,b)
  local aBuiltin=type(field(catalog,a))=='table';local bBuiltin=type(field(catalog,b))=='table'
  if aBuiltin~=bBuiltin then return aBuiltin end;return a<b
 end)
 local custom=0
 for _,key in ipairs(keys) do
  local definition=field(definitions,key);local label
  if type(field(catalog,key))=='table' and #key<=64 and key:match('^[A-Z][A-Z_0-9]*$') then label='Condition.'..key
  else custom=custom+1;label='Condition.custom'..custom end
  add(definition,'evaluate',label..'.evaluate',conditionReference(owner,key,'evaluate'));add(definition,'valid',label..'.valid',conditionReference(owner,key,'valid'))
 end
 return rows,truncated,validationRows
end
-- BEGIN PRIVATE CACHE SAMPLES
local function cacheFunction(owner,alias)
 if proofType(cacheSourceModules)~='table' or proofType(cacheSourceGetter)~='function' then return nil,'source-reader-unavailable' end
 if not cacheSourceEqual(owner,addon) or not cacheSourceEqual(proofRawget(owner,'builtinSourceModules'),cacheSourceModules)
  or not cacheSourceEqual(proofRawget(cacheSourceModules,'Functions/cache.lua'),cacheSourceGetter) then return nil,'source-reader-changed' end
 local ok,fn=proofPcall(cacheSourceGetter,alias)
 if not ok then return nil,'source-reader-error' end
 if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 return fn
end
local function privateCacheSelection(owner,rows)
 local result={views={},samples={}};local seen={}
 for _,row in ipairs(rows) do seen[row.fn]=row end
 for _,alias in ipairs({'getCachedInternal','packResults'}) do
  local fn,reason=cacheFunction(owner,alias)
  local view={alias=alias,label='Functions.cache.'..alias,reason=reason};result.views[#result.views+1]=view
  if fn then
   local sample=seen[fn]
   if not sample then
    if #rows+#result.samples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;result.samples[#result.samples+1]=sample end
   end
   view.sample=sample
  end
 end
 return result
end
-- BEGIN PRIVATE VALIDATION SCOPES
local validationEqual,validationSelect=rawequal,select
local validationSpecs={
 {name='references',anchor='GetRotationValidationStamp',slots={'observe','sameEntries','sameItemsets','proofGlobals'}},
 {name='library',anchor='InitializeRotationLibrary',slots={'ensure','eligible'}},
 {name='scope',anchor='BindRotationProfile',slots={'same'}},
}
local validationGroups,validationClosed,validationCount,validationCapture={},false,0,nil
local validationInstaller
local function validationRetire()
 validationClosed=true
 if validationEqual(proofRawget(addon,'BindCPUValidationScopeDiagnostic'),validationInstaller) then addon.BindCPUValidationScopeDiagnostic=nil end
end
validationInstaller=function(self,name,anchor,reader)
 if validationClosed or not validationEqual(self,addon) or proofType(name)~='string'
  or proofType(anchor)~='function' or proofType(reader)~='function' or validationGroups[name] then return false end
 local found
 for _,spec in ipairs(validationSpecs) do if name==spec.name then found=true;break end end
 if not found then return false end
 validationGroups[name]={anchor=anchor,reader=reader};validationCount=validationCount+1
 if validationCount==3 then validationRetire() end
 return true
end
addon.BindCPUValidationScopeDiagnostic=validationInstaller
local function validationClear(run)
 local state=run.validationScopes
 if state then state.phase='retired' end
 run.validationScopes=nil
 if validationCapture==run then validationCapture=nil end
end
local function validationEnding(run,status)
 if status~='complete' then validationClear(run)
 elseif run.validationScopes then run.validationScopes.phase='end' end
end
local function validationTuple(...) return {n=validationSelect('#',...),...} end
local function validationSnapshot(run,fn,current)
 if not current() then return nil,'capture-retired' end
 local ok,exclusive,calls=proofPcall(run.query,fn,false)
 if not current() then return nil,'capture-retired' end
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 local good,inclusive,inclusiveCalls=proofPcall(run.query,fn,true)
 if not current() then return nil,'capture-retired' end
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function validationFunctions(run,spec,group,current)
 if not current() then return nil,'capture-retired' end
 if not validationEqual(run.owner,addon) then return nil,'owner-changed' end
 if not group then return nil,'unbound' end
 local anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 local values=validationTuple(proofPcall(group.reader))
 if not current() then return nil,'capture-retired' end
 if not values[1] then return nil,'provider-unavailable' end
 if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
 for i=1,#spec.slots do
  local fn=values[i+1]
  if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 end
 anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 return values
end
local function validationStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},groups={}}
 run.validationScopes=state;validationCapture=run
 state.current=function()
  return validationCapture==run and run.validationScopes==state
   and (state.phase=='start' and active==run or state.phase=='end' and active==nil)
 end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,row in ipairs(run.privateCache.samples) do remember(row) end
 for _,row in ipairs(run.activity and run.activity.samples or {}) do remember(row) end
 for _,spec in ipairs(validationSpecs) do
  local group=validationGroups[spec.name];local funcs,reason=validationFunctions(run,spec,group,state.current)
  local source={spec=spec,group=group};state.groups[#state.groups+1]=source
  for i,name in ipairs(spec.slots) do
   local view={label='Validation.'..spec.name..'.'..name,group=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn
    local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else
      sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current)
     end
    end
    view.sample=sample
   end
  end
 end
end
local function appendValidationScopes(report,run,sampleEnd)
 local state=run.validationScopes
 local lines={'Private validation scopes (native counters; shared functions overlap):'};local available=0
 if state then
  for _,source in ipairs(state.groups) do source.functions,source.reason=validationFunctions(run,source.spec,source.group,state.current) end
 end
 local index=0
 for _,spec in ipairs(validationSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem
  if view then problem=view.reason else problem='baseline-unavailable' end
  local sample,current
  if view and not problem then
   local source=view.group;problem=source.reason
   if not problem and not validationEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
   sample=view.sample;problem=problem or sample.reason
   if not problem then current,problem=sampleEnd(run,sample,state.current) end
   if not problem then
    for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Validation.'..spec.name..'.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed validation views: aliases=7; available=%d; unavailable=%d (excluded from rankings above).',available,7-available)
 lines[#lines+1]='Shared helper counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private validation scopes omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE VALIDATION SCOPES
-- BEGIN RUNTIME WORK VIEWS
-- Fixed pointers only. Readers are source-local literal returns, not helpers.
local workGroups,workClosed,workCount,workCapture={},false,0,nil
local workEqual=rawequal
local workSpecs={
 {name='store',namespace='RotationData',anchor='NewRotationStore',slots={'Store.plain','Store.fields','Store.validAddress'}},
 {name='main',anchor='EvaluateNextActionInternal',slots={'Main.UpdateUnitInfo'}},
 {name='diagnostics',namespace='Diagnostics',member='Call',slots={'Diagnostics.Call'}},
 {name='profile',namespace='evaluationProfile',member='child',slots={'EvaluationProfile.child'}},
}
local workInstaller
local function workRetire()
 workClosed=true
 if workEqual(proofRawget(addon,'BindCPURuntimeWorkDiagnostic'),workInstaller) then addon.BindCPURuntimeWorkDiagnostic=nil end
end
workInstaller=function(self,name,anchor,reader)
 if workClosed or not workEqual(self,addon) or (name~='store' and name~='main')
  or proofType(anchor)~='function' or proofType(reader)~='function' or workGroups[name] then return false end
 local namespace=addon;if name=='store' then namespace=proofRawget(addon,'RotationData') end
 workGroups[name]={anchor=anchor,reader=reader,namespace=namespace}
 workCount=workCount+1;if workCount==2 then workRetire() end
 return true
end
addon.BindCPURuntimeWorkDiagnostic=workInstaller
local function workClear(run)
 local state=run.runtimeWork;if state then state.phase='retired' end
 run.runtimeWork=nil;if workCapture==run then workCapture=nil end
end
local function workEnding(run,status)
 if status~='complete' then workClear(run) elseif run.runtimeWork then run.runtimeWork.phase='end' end
end
local function workNamespace(spec)
 if spec.namespace then return proofRawget(addon,spec.namespace) end
 return addon
end
local function workFunctions(run,source,current)
 if not current() then return nil,'capture-retired' end
 if not workEqual(run.owner,addon) then return nil,'owner-changed' end
 local spec,group=source.spec,source.group
 if spec.anchor and not group then return nil,'unbound' end
 local namespace=workNamespace(spec)
 if not readable(namespace) or not workEqual(namespace,source.namespace) or proofType(namespace)~='table' then return nil,'owner-changed' end
 local values
 if spec.anchor then
  local anchor=proofRawget(namespace,spec.anchor)
  if not readable(anchor) or not workEqual(anchor,group.anchor) then return nil,'owner-changed' end
  if not current() then return nil,'capture-retired' end
  values=validationTuple(proofPcall(group.reader))
  if not current() then return nil,'capture-retired' end
  if not values[1] then return nil,'provider-unavailable' end
  if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
  if not workEqual(proofRawget(addon,spec.namespace or spec.anchor),spec.namespace and namespace or group.anchor)
   or not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 else values={true,proofRawget(namespace,spec.member)} end
 for i=1,#spec.slots do if not readable(values[i+1]) or proofType(values[i+1])~='function' then return nil,'invalid-source-function' end end
 if not current() then return nil,'capture-retired' end
 if not workEqual(workNamespace(spec),namespace) then return nil,'owner-changed' end
 if spec.anchor then
  if not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 elseif not workEqual(proofRawget(namespace,spec.member),values[2]) then return nil,'function-replaced' end
 return values
end
local function workStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},sources={}};run.runtimeWork=state;workCapture=run
 state.current=function() return workCapture==run and run.runtimeWork==state
  and (state.phase=='start' and active==run or state.phase=='end' and active==nil) end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,group in ipairs({run.privateCache,run.activity or {},run.validationScopes or {}}) do for _,row in ipairs(group.samples or {}) do remember(row) end end
 for _,spec in ipairs(workSpecs) do
  local group=workGroups[spec.name]
  local namespace=workNamespace(spec);if group then namespace=group.namespace end
  local source={spec=spec,group=group,namespace=namespace}
  state.sources[#state.sources+1]=source
  local funcs,reason=workFunctions(run,source,state.current)
  for i,name in ipairs(spec.slots) do
   local view={label='Work.'..name,source=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn;local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current) end
    end
    view.sample=sample
   end
  end
 end
end
local function appendWorkViews(report,run,sampleEnd)
 local state=run.runtimeWork
 local lines={'Runtime work views (native counters; shared functions overlap):'};local available=0;local index=0
 if state then for _,source in ipairs(state.sources) do source.functions,source.reason=workFunctions(run,source,state.current) end end
 for _,spec in ipairs(workSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem=view and view.reason or 'baseline-unavailable'
  local sample,current
  if view then
   problem=view.reason
   if not problem then
    local source=view.source;problem=source.reason
    if not problem and not workEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
    sample=view.sample;problem=problem or sample.reason
    if not problem then current,problem=sampleEnd(run,sample,state.current) end
    if not problem then for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Work.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed runtime work views: aliases=6; available=%d; unavailable=%d (excluded from rankings above).',available,6-available)
 lines[#lines+1]='Shared function counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Runtime work views omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END RUNTIME WORK VIEWS
local function finishSample(run,row,guard)
 if not row.sampled then
  row.sampled=true
  if guard then row.current,row.currentReason=validationSnapshot(run,row.fn,guard)
  else row.current,row.currentReason=snapshot(run,row.fn) end
 end
 return row.current,row.currentReason
end
local function appendPrivateCache(report,run)
 local lines={'Private cache helpers (native counters; shared functions overlap):'}
 local available=0
 for _,view in ipairs(run.privateCache.views) do
  local sample,problem=view.sample,view.reason
  if not problem then
   local fn;fn,problem=cacheFunction(run.owner,view.alias)
   if not problem and not cacheSourceEqual(fn,sample.fn) then problem='function-replaced' end
   problem=problem or sample.reason
  end
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and view.label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',view.label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Private helper views: aliases=2; available=%d; unavailable=%d (excluded from rankings above).',available,2-available)
 lines[#lines+1]='Shared helper counters include all callers, including archived copies; inclusive costs overlap.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private cache helpers omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE CACHE SAMPLES
-- BEGIN CPU ACTIVITY DIAGNOSTICS
local activityProviders,activityFrame,activityAPI={},nil,nil
local activityEqual,activityCreate=rawequal,CreateFrame
function addon:BindCPUActivityDiagnostic(name,reader)
 if self~=addon or (name~='spell' and name~='item' and name~='visual') or proofType(reader)~='function' or activityProviders[name] then return false end
 activityProviders[name]=reader
 if activityProviders.spell and activityProviders.item and activityProviders.visual then addon.BindCPUActivityDiagnostic=nil end
 return true
end
local function activityRead()
 local result={}
 for _,name in ipairs({'spell','item','visual'}) do
  local reader=activityProviders[name]
  if reader then local ok,value=proofPcall(reader,activityAPI);if ok and proofType(value)=='table' then result[name]=value end end
 end
 return result
end
local function activityEvent(run,event,_,success)
 if not readable(success) or proofType(success)~='boolean' then run.activity.events.unknown=run.activity.events.unknown+1;return end
 if success then
  if event=='SPELL_DATA_LOAD_RESULT' then run.activity.events.spell=run.activity.events.spell+1
  elseif event=='ITEM_DATA_LOAD_RESULT' then run.activity.events.item=run.activity.events.item+1 end
 end
end
local function activityStop(run)
 local state=run.activity;if not state then return end
 if state.lease then state.lease.run=nil;state.lease=nil end
 local frame,api=state.frame,state.api;state.frame=nil;state.api=nil
 if frame and api then
  local ok,current=proofPcall(api.GetScript,frame,'OnEvent')
  local released=false
  if ok and activityEqual(current,state.handler) then
   local events=proofPcall(api.UnregisterAllEvents,frame);local handler=proofPcall(api.SetScript,frame,'OnEvent',nil);released=events and handler
  end
  if not released then
   state.events.available=false
   if activityEqual(activityFrame,frame) then activityFrame=nil;activityAPI=nil end
  end
 end
 state.handler=nil
end
local function activityEnsureAPI()
 if not activityFrame and proofType(activityCreate)=='function' then
  local ok,frame=proofPcall(activityCreate,'Frame')
  if ok and frame then
   local api={};local valid=true
   for _,name in ipairs({'GetScript','SetScript','RegisterEvent','UnregisterAllEvents','Hide','GetParent','IsVisible'}) do
    local method=frame[name];if proofType(method)~='function' then valid=false end;api[name]=method
   end
   if valid then activityFrame,activityAPI=frame,api;proofPcall(api.Hide,frame) end
  end
 end
end
local function activityStart(run)
 addon.BindCPUActivityDiagnostic=nil
 run.activity={events={spell=0,item=0,unknown=0,available=false},views={},samples={}}
 local state=run.activity
 activityEnsureAPI()
 if activityFrame then
  state.frame=activityFrame;state.api=activityAPI
  local lease={run=run};state.lease=lease
  state.handler=function(_,event,...)
   local current=lease.run;if not current or active~=current then return end
   if not proofPcall(activityEvent,current,event,...) then current.activity.events.unknown=current.activity.events.unknown+1 end
  end
  local ok=proofPcall(function()
   activityAPI.SetScript(activityFrame,'OnEvent',state.handler)
   activityAPI.RegisterEvent(activityFrame,'SPELL_DATA_LOAD_RESULT');activityAPI.RegisterEvent(activityFrame,'ITEM_DATA_LOAD_RESULT')
  end)
  if ok then state.events.available=true else activityStop(run) end
 end
 state.started=activityRead()
 local seen,totalSamples={},#run.rows+#run.privateCache.samples
 for _,row in ipairs(run.rows) do seen[row.fn]=row end
 for _,row in ipairs(run.privateCache.samples) do seen[row.fn]=row end
 local visual=state.started.visual
 for _,name in ipairs({'overlay','pixel','autocast','blizzard'}) do
  local view={name=name};state.views[#state.views+1]=view
  local callbacks=field(visual,'callbacks');local ambiguous=field(visual,'ambiguous')
  local fn=field(callbacks,name)
  if field(ambiguous,name)==true then view.reason='ambiguous-callback'
  elseif proofType(fn)~='function' or not readable(fn) then view.reason='no-start-callback'
  else
   local sample=seen[fn]
   if not sample then
    if totalSamples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;totalSamples=totalSamples+1;state.samples[#state.samples+1]=sample;sample.before,sample.reason=snapshot(run,fn) end
   end
   view.sample=sample
  end
 end
end
local memoryActivityPrepared=false
-- Bounded detached cardinality for explicit lifetime diagnostics. Never return
-- private maps, native frames, callbacks or the activity reader functions.
function addon:GetRetainedMemoryDiagnostic()
 if self~=addon then return end
 if not memoryActivityPrepared then memoryActivityPrepared=true;activityEnsureAPI()end
 local observed=activityRead();local result={}
 for _,spec in ipairs({{'spell','spellIDs'},{'spell','spellNames'},{'item','itemRecords'},{'item','itemIndex'},{'item','itemBlocked'}}) do
  local value=field(field(observed,spec[1]),spec[2]);local n=field(value,'n');local capped=field(value,'capped')
  if counter(n,true)and n<=4096 and readable(capped)and proofType(capped)=='boolean'then result[spec[2]]=n;result[spec[2]..'Capped']=capped end
 end
 local visual=field(observed,'visual')
 if field(visual,'unsupported')~=true then
  for _,name in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(visual,name)
   if counter(n,true)and n<=4096 then result[name]=n;result[name..'Capped']=field(visual,'capped')==true end
  end
 end
 return result
end
local function appendActivity(report,run)
 local state=run.activity;if not state then return end
 local lines={'Retained catalogs and animation activity (capture only):'}
 local function retained(root,key)
  local object=field(root,key);local n=field(object,'n');local capped=field(object,'capped')
  if not counter(n,true) or n>4096 or proofType(capped)~='boolean' then return 'unavailable' end
  return (capped and '>=' or '')..tostring(n),not capped and n or nil
 end
 for _,entry in ipairs({{'spell','spellIDs','spell IDs'},{'spell','spellNames','spell name groups'},{'item','itemRecords','item records'},{'item','itemIndex','item index'},{'item','itemBlocked','blocked items'}}) do
  local start,before=retained(field(state.started,entry[1]),entry[2]);local ending,after=retained(field(state.ended,entry[1]),entry[2])
  lines[#lines+1]=entry[3]..': start='..start..'; end='..ending..'; change='..(before~=nil and after~=nil and tostring(after-before) or 'unavailable')
 end
 local events=state.events
 lines[#lines+1]=events.available and string.format('metadata successes: spell=%s; item=%s; unknown=%s',tostring(events.spell),tostring(events.item),tostring(events.unknown)) or 'metadata successes: unavailable'
 local function visual(label,value)
  if proofType(value)~='table' then return label..' visuals: unavailable' end
  local parts={label..' visuals:'}
  for _,key in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(value,key);parts[#parts+1]=key..'='..(counter(n,true) and n<=4096 and tostring(n) or 'unavailable')
  end
  parts[#parts+1]='capped='..(field(value,'capped')==true and 'true' or 'false')
  if field(value,'unsupported')==true then parts[#parts+1]='native-observation=unavailable' end
  return table.concat(parts,' ')
 end
 lines[#lines+1]=visual('start',field(state.started,'visual'));lines[#lines+1]=visual('end',field(state.ended,'visual'))
 local labels={overlay='RM.UpdateOverlay',pixel='SharedGlow.Pixel.OnUpdate',autocast='SharedGlow.AutoCast.OnUpdate',blizzard='SharedGlow.Blizzard.OnUpdate'}
 local available=0
 for _,view in ipairs(state.views) do
  local sample,problem=view.sample,view.reason
  if not field(state.ended,'visual') then problem=problem or 'source-reader-changed' end
  problem=problem or sample and sample.reason
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and labels[view.name]..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',labels[view.name],exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Animation views: aliases=4; available=%d; unavailable=%d (excluded from rankings above).',available,4-available)
 lines[#lines+1]='Catalog counts are keys, not bytes; global metadata arrivals may originate outside RM. Capped counts are lower bounds; sequence counts timer handles regardless of visibility, not measured executions.'
 lines[#lines+1]='Shared glow frames are associated with RM-active slots; shared callback counters include all callers. Start callbacks only; end-only callbacks lack a baseline. Proc uses native animations.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Retained activity omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END CPU ACTIVITY DIAGNOSTICS
local function finish(run,status,reason)
 if active~=run then return end
 -- BEGIN PRIVATE VALIDATION END TOKEN
 validationEnding(run,status)
 -- END PRIVATE VALIDATION END TOKEN
 -- BEGIN RUNTIME WORK END TOKEN
 workEnding(run,status)
 -- END RUNTIME WORK END TOKEN
 active=nil;run.timer=nil
 -- BEGIN CPU ACTIVITY STOP
 activityStop(run)
 -- END CPU ACTIVITY STOP
 local text
 if status=='complete' then
  local now,why=clock(run.clock);local elapsed=now and now-run.started
  if not elapsed or not finite(elapsed) or elapsed<=0 then status,reason='invalid',why or 'clock-reset' end
  if status=='complete' then
   local allowed,problem=enabled(run.cvar)
   if clockAPI()~=run.clock or cvarAPI()~=run.cvar or GetFunctionCPUUsage~=run.query or totalAPI()~=run.total or updateAPI()~=run.update then status,reason='invalid','profiling-api-changed'
   elseif not allowed then status,reason='invalid',problem end
  end
  local used,rate
  if status=='complete' then local value,problem=total(run);if value==nil or value<run.initialTotal then status,reason='invalid',problem or 'addon-cpu-counter-reset' else used=value-run.initialTotal;if not finite(used) then status,reason='invalid','invalid-addon-cpu-delta' end end end
  if status=='complete' then rate=used/elapsed;if not finite(rate) then status,reason='invalid','invalid-cpu-rate' end end
  if status=='complete' then
   -- BEGIN CPU ACTIVITY END
   if run.activity then run.activity.ended=activityRead() end
   -- END CPU ACTIVITY END
   local ranked,unavailable={},{}
   for _,row in ipairs(run.rows) do
    local problem=row.reason
    for _,ref in ipairs(row.refs) do if ref()~=row.fn then problem='function-replaced';break end end
    local current;if not problem then current,problem=finishSample(run,row) end
    if not problem then
     for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<row.before[key] then problem='function-cpu-counter-reset';break end end
    end
    if not problem then
     local result={label=row.label,exclusive=current.exclusive-row.before.exclusive,inclusive=current.inclusive-row.before.inclusive,calls=current.calls-row.before.calls}
     if not finite(result.exclusive) or not finite(result.inclusive) or not counter(result.calls,true) then problem='invalid-function-cpu-delta' else ranked[#ranked+1]=result;row.deltaCalls=result.calls end
    end
    if problem then unavailable[#unavailable+1]={label=row.label,reason=problem} end
   end
   table.sort(ranked,function(a,b) if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;return a.label<b.label end)
   local report={'Rotation Master CPU profile: complete',string.format('duration=%.3f s; addon CPU=%.3f ms; addon rate=%.3f ms/s',elapsed,used,rate),
    'start '..run.context,'end '..context(run.owner),'States describe capture boundaries only; activity may change within the interval.',
    'Native cumulative counters include collection and profiling overhead. Inclusive rows overlap and are not additive.',
    'Rows are selected coverage, not complete CPU accounting; addon and function snapshot boundaries differ slightly.',
    string.format('selected=%d; available=%d; unavailable=%d; top=%d%s',#run.rows,#ranked,#unavailable,math.min(TOP,#ranked),run.truncated and '; selection truncated' or '')}
   local function validationCount(name)
    local row=run.validationRows[name]
    return row and row.deltaCalls~=nil and tostring(row.deltaCalls) or 'unavailable'
   end
   report[#report+1]='Structural validation calls: ValidateEnvelope='..validationCount('ValidateEnvelope')..'; ValidateBody='..validationCount('ValidateBody')..' (native counters; shared functions overlap).'
   report[#report+1]='Execution indexing calls: IndexRotationSteps='..validationCount('IndexRotationSteps')..' (native counter).'
   for index=1,math.min(TOP,#ranked) do local row=ranked[index];local mean=row.calls>0 and row.exclusive/row.calls or nil
    report[#report+1]=string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s | mean=%s ms',row.label,row.exclusive,row.inclusive,tostring(row.calls),mean and string.format('%.3f',mean) or 'unavailable')
   end
   for index=1,math.min(10,#unavailable) do local row=unavailable[index];report[#report+1]=row.label..' | unavailable: '..row.reason end
   if #unavailable>10 then report[#report+1]='Additional unavailable rows omitted.' end
   -- BEGIN INCLUSIVE CPU SCOPES
   -- Existing lines are complete before this second view of the same rows.
   local reportBytes=#report-1
   for _,line in ipairs(report) do reportBytes=reportBytes+#line end
   local title='Inclusive scopes (top 10; includes descendants; overlapping, not additive):'
   local omitted='Additional inclusive scopes omitted to keep report bounded.'
   if reportBytes+1+#title+1+#omitted<16000 then
    report[#report+1]=title;reportBytes=reportBytes+1+#title
    table.sort(ranked,function(a,b) if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;return a.label<b.label end)
    for index=1,math.min(10,#ranked) do local row=ranked[index]
     local line=string.format('%s | inclusive=%.3f ms | exclusive=%.3f ms | calls=%s',row.label,row.inclusive,row.exclusive,tostring(row.calls))
     if reportBytes+1+#line+1+#omitted>=16000 then report[#report+1]=omitted;break end
     report[#report+1]=line;reportBytes=reportBytes+1+#line
    end
   end
   -- END INCLUSIVE CPU SCOPES
   -- BEGIN EXECUTION INDEX DIAGNOSTICS
   appendExecutionIndexProof(report,run.executionIndexProof,executionIndexProof())
   -- END EXECUTION INDEX DIAGNOSTICS
   -- BEGIN PRIVATE CACHE APPENDIX
   appendPrivateCache(report,run)
   -- END PRIVATE CACHE APPENDIX
   -- BEGIN CPU ACTIVITY APPENDIX
   appendActivity(report,run)
   -- END CPU ACTIVITY APPENDIX
   -- BEGIN STANDALONE PREVIEW APPENDIX
   appendStandalonePreviewContext(report,run.previewContext,standalonePreviewContext(run.owner))
   -- END STANDALONE PREVIEW APPENDIX
   -- BEGIN PRIVATE VALIDATION APPENDIX
   local validationState=run.validationScopes
   local validationEntered=validationState and validationState.current()
   appendValidationScopes(report,run,finishSample)
   if validationEntered and not validationState.current() then validationClear(run);return end
   -- END PRIVATE VALIDATION APPENDIX
   -- BEGIN RUNTIME WORK APPENDIX
   local workState=run.runtimeWork
   local workEntered=workState and workState.current()
   appendWorkViews(report,run,finishSample)
   if workEntered and not workState.current() then workClear(run);return end
   -- END RUNTIME WORK APPENDIX
   -- BEGIN COLD STORE STRING END
   local shapeEntered=workState and workState.current()
   appendStoreStringShape(report,run.storeStringShape,storeStringShape())
   if shapeEntered and not workState.current() then workClear(run);return end
   -- END COLD STORE STRING END
   text=table.concat(report,'\n')
  end
 end
 text=text or 'Rotation Master CPU profile: '..status..(reason and ' ('..reason..')' or '')
 -- BEGIN PRIVATE VALIDATION CLEANUP
 validationClear(run)
 -- END PRIVATE VALIDATION CLEANUP
 -- BEGIN RUNTIME WORK CLEANUP
 workClear(run)
 -- END RUNTIME WORK CLEANUP
 lastReport=text
 local callback=field(run.owner,'OnCPUProfileFinished');if type(callback)=='function' then pcall(callback,run.owner,text,status) end
end
function addon:StartCPUProfile(duration)
 -- BEGIN NATIVE RUNTIME EXCLUSION
 if type(self.IsCPURuntimeCaptureRunning)=='function' and self:IsCPURuntimeCaptureRunning() then return false,'native-runtime-capture-running' end
 -- END NATIVE RUNTIME EXCLUSION
 -- BEGIN PRIVATE VALIDATION RETIRE
 validationRetire()
 -- END PRIVATE VALIDATION RETIRE
 -- BEGIN RUNTIME WORK RETIRE
 workRetire()
 -- END RUNTIME WORK RETIRE
 if active then return false,'already-running' end
 if duration==nil then duration=10 end
 if not finite(duration) or duration<1 or duration>60 then return false,'invalid-duration' end
 local cvar=cvarAPI();local allowed,reason=enabled(cvar);if not allowed then return false,reason end
 if type(GetFunctionCPUUsage)~='function' then return false,'missing-function-cpu-api' end
 if not totalAPI() or not updateAPI() then return false,'missing-addon-cpu-api' end
 if type(self.ScheduleTimer)~='function' or type(self.CancelTimer)~='function' then return false,'missing-timer-api' end
 local run={owner=self,query=GetFunctionCPUUsage,total=totalAPI(),update=updateAPI(),clock=clockAPI(),cvar=cvar,duration=duration,cancel=self.CancelTimer}
 run.started,reason=clock(run.clock);if run.started==nil then return false,reason end
 run.initialTotal,reason=total(run);if run.initialTotal==nil then return false,reason end
 run.rows,run.truncated,run.validationRows=selectFunctions(self);run.context=context(self)
 local available=0
 for _,row in ipairs(run.rows) do row.before,row.reason=snapshot(run,row.fn);if row.before then available=available+1 end end
 if available==0 then return false,'function-cpu-unavailable' end
 -- BEGIN PRIVATE CACHE START
 run.privateCache=privateCacheSelection(self,run.rows)
 for _,sample in ipairs(run.privateCache.samples) do sample.before,sample.reason=snapshot(run,sample.fn) end
 -- END PRIVATE CACHE START
 active=run
 -- BEGIN CPU ACTIVITY START
 local activityOK=proofPcall(activityStart,run)
 if not activityOK then activityStop(run);run.activity=nil end
 -- END CPU ACTIVITY START
 -- BEGIN PRIVATE VALIDATION START
 local validationEntered=active==run
 validationStart(run)
 if validationEntered and active~=run then validationClear(run);return true end
 -- END PRIVATE VALIDATION START
 -- BEGIN RUNTIME WORK START
 local workEntered=active==run
 workStart(run)
 if workEntered and active~=run then workClear(run);return true end
 -- END RUNTIME WORK START
 local ok,timer=pcall(self.ScheduleTimer,self,function() finish(run,'complete') end,duration)
 -- BEGIN PRIVATE VALIDATION TIMER FAILURE
 if not ok or not timer then validationClear(run) end
 -- END PRIVATE VALIDATION TIMER FAILURE
 -- BEGIN RUNTIME WORK TIMER FAILURE
 if not ok or not timer then workClear(run) end
 -- END RUNTIME WORK TIMER FAILURE
 if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end
 run.timer=timer;if active==run then run.executionIndexProof=executionIndexProof() end;lastReport=nil
 -- BEGIN STANDALONE PREVIEW START
 if active==run then run.previewContext=standalonePreviewContext(self) end
 -- END STANDALONE PREVIEW START
 -- BEGIN COLD STORE STRING START
 if active==run then
  run.storeStringShape=storeStringShape()
  if active~=run then return true end
 end
 -- END COLD STORE STRING START
 return true
end
function addon:CancelCPUProfile()
 local run=active;if not run then return false,'not-running' end
 if run.timer then pcall(run.cancel,run.owner,run.timer) end
 finish(run,'cancelled');return true
end
function addon:IsCPUProfileRunning() return active~=nil end
function addon:GetCPUProfileReport()
 if active then return string.format('Rotation Master CPU profile: running (requested %.3f s)',active.duration) end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
-- AceAddon invokes this before AceTimer retires the addon's embedded timers.
-- The ordinary rotation enable/disable toggle remains independent of capture.
function addon:OnDisable()
 -- BEGIN NATIVE RUNTIME DISABLE
 if type(self.CancelCPURuntimeCapture)=='function' then self:CancelCPURuntimeCapture() end
 -- END NATIVE RUNTIME DISABLE
 self:CancelCPUProfile()
 if type(self.IsMemoryCaptureRunning)=='function' and self:IsMemoryCaptureRunning()
  and type(self.StopMemoryCapture)=='function' then self:StopMemoryCapture() end
 if type(self.ClearCastCaptureForDisable)=='function' then self:ClearCastCaptureForDisable() end
end
]========],
    },
    ["Core/rotation_sequence.lua"] = {
        before = [========[local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
end
local function execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function permitted(receiver)
        if managed(receiver) then return true end
        result.status="unavailable";result.suppressAttack=true;return false
    end
    local function check(step,row)
        local observation
        if managed then
            if not permitted('pathcopy') then return "unavailable" end
            local conditions,stepId=step.conditions,step.id
            local path=data.CopyData(row.path)
            observation=evaluate(conditions,{stepId=stepId,stepPath=path})
            if not permitted('resume') then return "unavailable" end
        else
            observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        end
        if kind(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        if managed and not permitted('iterator') then return false end
        for _,step in each(list) do
            local row=rows[step]
            if step.type=="branch" then
                local mode=step.mode or "evaluate"
                local status=mode=="true" and "match" or mode=="false" and "no-match" or check(step,row)
                if status=="unavailable" then result.status="unavailable";result.suppressAttack=true;return false end
                if not walk(status=="match" and step.onTrue or step.onFalse) then return false end
            elseif not step.disabled then
                if step.type=="none" then
                    local status=check(step,row)
                    if status~="no-match" then
                        result.status=status=="unavailable" and "unavailable" or "stopped"
                        result.suppressAttack=status=="unavailable" or step.suppress_attack==true
                        return false
                    end
                elseif not managed then
                    if visit(step,row.ordinal,data.CopyData(row.path))==false then
                        result.status="selected";return false
                    end
                else
                    if not permitted('pathcopy') then return false end
                    local position=row.ordinal
                    local path=data.CopyData(row.path)
                    local keepGoing=visit(step,position,path)
                    if keepGoing==false then result.status="selected";return false end
                end
            end
        end
        return true
    end
    walk(body.rotation or {})
    return result
end
-- The caller owns observation policy and action availability. This executor
-- owns ordered control flow, and deliberately leaves optional upkeep alone.
function addon:EvaluateRotationSequence(body,evaluate,visit)
    local index,why=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not index then return unavailable(why) end
    if type(evaluate)~="function" or type(visit)~="function" then
        return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
    end
    local rows,ordinal={},0
    for _,row in ipairs(index.rows) do
        if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
    end
    local function kind(value) return type(value) end
    local function each(list) return ipairs(list) end
    return execute(body,evaluate,visit,rows,ordinal,kind,each)
end

-- Only main receives this reader. Public sequence calls always index afresh.
local sequenceType,sequenceRawget,sequenceEqual=type,rawget,rawequal
local sequenceIpairs=ipairs
---@type fun(f: number|function): table
local sequenceGetfenv=getfenv
local sequenceEnvironment=sequenceType(sequenceGetfenv)=="function" and sequenceGetfenv(1) or nil
local ownedSequence=addon.EvaluateRotationSequence
local readIndex,retireIndex,indexStatus
local bindIndex=addon.BindRotationExecutionIndexReader
if sequenceType(bindIndex)=="function" then
    ---@cast bindIndex function
    bindIndex(addon,function(read,retire,status) readIndex,retireIndex,indexStatus=read,retire,status end)
    addon.BindRotationExecutionIndexReader=nil
end
-- Source-owned status carries no body, cache, method, or profile references.
local function sequenceStatus(owner)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local ownerTable=sequenceType(owner)=="table"
    local db=ownerTable and sequenceRawget(owner,"db") or nil
    local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
    local environment=sequenceType(sequenceEnvironment)=="table"
    local capability=sequenceType(sequenceGetfenv)=="function"
    check("owner",sequenceEqual(owner,addon))
    check("method",ownerTable and sequenceEqual(sequenceRawget(owner,"EvaluateRotationSequence"),ownedSequence))
    check("namespace",ownerTable and sequenceEqual(sequenceRawget(owner,"RotationData"),data))
    check("db",sequenceType(db)=="table");check("profile",sequenceType(profile)=="table")
    check("index-reader",sequenceType(readIndex)=="function")
    check("capability",capability);check("env",environment)
    check("public-env",capability and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment))
    local keys={"type","ipairs","getfenv"};local pointers={sequenceType,sequenceIpairs,sequenceGetfenv}
    for i=1,3 do
        local key=keys[i];local ok=environment and sequenceEqual(sequenceRawget(sequenceEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
    end
    local status=indexStatus and indexStatus(data) or {portable={reason="unbound"},index={reason="unbound"}}
    status.sequence=result;return status
end
function addon:BindRotationSequenceReader(bind)
    if self~=addon or sequenceType(bind)~="function" then return end
    local function rawMethod(owner)
        return sequenceType(owner)=="table" and sequenceRawget(owner,"EvaluateRotationSequence") or nil
    end
    -- Only the admitted managed caller owns immutable execution bodies. Keep
    -- one private map; ordinary mutable callers retain the live index reader.
    local managedEntry
    local function run(owner,before,method,body,evaluate,visit,managed)
        if managed and not managed('sequence') then return unavailable({code="retired-managed-sequence"}) end
        local db=sequenceType(owner)=="table" and sequenceRawget(owner,"db") or nil
        local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
        if not (sequenceEqual(owner,addon) and sequenceEqual(before,ownedSequence) and sequenceEqual(method,ownedSequence)
            and sequenceEqual(sequenceRawget(owner,"RotationData"),data) and sequenceType(profile)=="table"
            and readIndex and sequenceType(sequenceEnvironment)=="table"
            and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"type"),sequenceType)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"ipairs"),sequenceIpairs)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"getfenv"),sequenceGetfenv)) then
            if retireIndex then retireIndex() end
            if managed then return unavailable({code="unowned-managed-sequence"}) end
            return method(owner,body,evaluate,visit)
        end
        local cached=managed and managedEntry
        local rows,ordinal
        if cached and sequenceEqual(cached.body,body) and sequenceEqual(cached.db,db)
            and sequenceEqual(cached.profile,profile) then
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal=cached.rows,cached.ordinal
        else
            local eligible,index,why=readIndex(body,profile,data,db)
            if managed and not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
            if not eligible then
                if managed then return unavailable({code="unowned-managed-index"}) end
                return method(owner,body,evaluate,visit)
            end
            if not index then return unavailable(why) end
            -- Preserve the ordinary reader's callback validation before any
            -- row-map iteration, including its original error ordering.
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal={},0
            for _,row in sequenceIpairs(index.rows) do
                if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
            end
            if managed then
                -- A failed older invocation must not erase or replace a map
                -- published by a nested, newer managed continuation.
                if not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
                managedEntry={body=body,db=db,profile=profile,rows=rows,ordinal=ordinal}
            end
        end
        local function kind(value) return sequenceEnvironment.type(value) end
        local function each(list) return sequenceEnvironment.ipairs(list) end
        return execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    end
    bind(rawMethod,run,sequenceStatus,ownedSequence)
end
]========],
        after = [========[local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
end
-- Managed rows own dense scalar paths produced by the private execution index.
-- Give each receiver a fresh plain array without revalidating portable data.
local function managedPath(path)
    local result={}
    for i=1,#path do result[i]=path[i] end
    return result
end
local function execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function permitted(receiver)
        if managed(receiver) then return true end
        result.status="unavailable";result.suppressAttack=true;return false
    end
    local function check(step,row)
        local observation
        if managed then
            if not permitted('pathcopy') then return "unavailable" end
            local conditions,stepId=step.conditions,step.id
            local path=managedPath(row.path)
            observation=evaluate(conditions,{stepId=stepId,stepPath=path})
            if not permitted('resume') then return "unavailable" end
        else
            observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        end
        if kind(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        if managed and not permitted('iterator') then return false end
        for _,step in each(list) do
            local row=rows[step]
            if step.type=="branch" then
                local mode=step.mode or "evaluate"
                local status=mode=="true" and "match" or mode=="false" and "no-match" or check(step,row)
                if status=="unavailable" then result.status="unavailable";result.suppressAttack=true;return false end
                if not walk(status=="match" and step.onTrue or step.onFalse) then return false end
            elseif not step.disabled then
                if step.type=="none" then
                    local status=check(step,row)
                    if status~="no-match" then
                        result.status=status=="unavailable" and "unavailable" or "stopped"
                        result.suppressAttack=status=="unavailable" or step.suppress_attack==true
                        return false
                    end
                elseif not managed then
                    if visit(step,row.ordinal,data.CopyData(row.path))==false then
                        result.status="selected";return false
                    end
                else
                    if not permitted('pathcopy') then return false end
                    local position=row.ordinal
                    local path=managedPath(row.path)
                    local keepGoing=visit(step,position,path)
                    if keepGoing==false then result.status="selected";return false end
                end
            end
        end
        return true
    end
    walk(body.rotation or {})
    return result
end
-- The caller owns observation policy and action availability. This executor
-- owns ordered control flow, and deliberately leaves optional upkeep alone.
function addon:EvaluateRotationSequence(body,evaluate,visit)
    local index,why=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not index then return unavailable(why) end
    if type(evaluate)~="function" or type(visit)~="function" then
        return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
    end
    local rows,ordinal={},0
    for _,row in ipairs(index.rows) do
        if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
    end
    local function kind(value) return type(value) end
    local function each(list) return ipairs(list) end
    return execute(body,evaluate,visit,rows,ordinal,kind,each)
end

-- Only main receives this reader. Public sequence calls always index afresh.
local sequenceType,sequenceRawget,sequenceEqual=type,rawget,rawequal
local sequenceIpairs=ipairs
---@type fun(f: number|function): table
local sequenceGetfenv=getfenv
local sequenceEnvironment=sequenceType(sequenceGetfenv)=="function" and sequenceGetfenv(1) or nil
local ownedSequence=addon.EvaluateRotationSequence
local readIndex,retireIndex,indexStatus
local bindIndex=addon.BindRotationExecutionIndexReader
if sequenceType(bindIndex)=="function" then
    ---@cast bindIndex function
    bindIndex(addon,function(read,retire,status) readIndex,retireIndex,indexStatus=read,retire,status end)
    addon.BindRotationExecutionIndexReader=nil
end
-- Source-owned status carries no body, cache, method, or profile references.
local function sequenceStatus(owner)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local ownerTable=sequenceType(owner)=="table"
    local db=ownerTable and sequenceRawget(owner,"db") or nil
    local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
    local environment=sequenceType(sequenceEnvironment)=="table"
    local capability=sequenceType(sequenceGetfenv)=="function"
    check("owner",sequenceEqual(owner,addon))
    check("method",ownerTable and sequenceEqual(sequenceRawget(owner,"EvaluateRotationSequence"),ownedSequence))
    check("namespace",ownerTable and sequenceEqual(sequenceRawget(owner,"RotationData"),data))
    check("db",sequenceType(db)=="table");check("profile",sequenceType(profile)=="table")
    check("index-reader",sequenceType(readIndex)=="function")
    check("capability",capability);check("env",environment)
    check("public-env",capability and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment))
    local keys={"type","ipairs","getfenv"};local pointers={sequenceType,sequenceIpairs,sequenceGetfenv}
    for i=1,3 do
        local key=keys[i];local ok=environment and sequenceEqual(sequenceRawget(sequenceEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
    end
    local status=indexStatus and indexStatus(data) or {portable={reason="unbound"},index={reason="unbound"}}
    status.sequence=result;return status
end
function addon:BindRotationSequenceReader(bind)
    if self~=addon or sequenceType(bind)~="function" then return end
    local function rawMethod(owner)
        return sequenceType(owner)=="table" and sequenceRawget(owner,"EvaluateRotationSequence") or nil
    end
    -- Only the admitted managed caller owns immutable execution bodies. Keep
    -- one private map; ordinary mutable callers retain the live index reader.
    local managedEntry
    local function run(owner,before,method,body,evaluate,visit,managed)
        if managed and not managed('sequence') then return unavailable({code="retired-managed-sequence"}) end
        local db=sequenceType(owner)=="table" and sequenceRawget(owner,"db") or nil
        local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
        if not (sequenceEqual(owner,addon) and sequenceEqual(before,ownedSequence) and sequenceEqual(method,ownedSequence)
            and sequenceEqual(sequenceRawget(owner,"RotationData"),data) and sequenceType(profile)=="table"
            and readIndex and sequenceType(sequenceEnvironment)=="table"
            and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"type"),sequenceType)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"ipairs"),sequenceIpairs)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"getfenv"),sequenceGetfenv)) then
            if retireIndex then retireIndex() end
            if managed then return unavailable({code="unowned-managed-sequence"}) end
            return method(owner,body,evaluate,visit)
        end
        local cached=managed and managedEntry
        local rows,ordinal
        if cached and sequenceEqual(cached.body,body) and sequenceEqual(cached.db,db)
            and sequenceEqual(cached.profile,profile) then
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal=cached.rows,cached.ordinal
        else
            local eligible,index,why=readIndex(body,profile,data,db)
            if managed and not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
            if not eligible then
                if managed then return unavailable({code="unowned-managed-index"}) end
                return method(owner,body,evaluate,visit)
            end
            if not index then return unavailable(why) end
            -- Preserve the ordinary reader's callback validation before any
            -- row-map iteration, including its original error ordering.
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal={},0
            for _,row in sequenceIpairs(index.rows) do
                if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
            end
            if managed then
                -- A failed older invocation must not erase or replace a map
                -- published by a nested, newer managed continuation.
                if not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
                managedEntry={body=body,db=db,profile=profile,rows=rows,ordinal=ordinal}
            end
        end
        local function kind(value) return sequenceEnvironment.type(value) end
        local function each(list) return sequenceEnvironment.ipairs(list) end
        return execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    end
    bind(rawMethod,run,sequenceStatus,ownedSequence)
end
]========],
    },
}

return function(text, path)
    local row = rows[path]

    if row and text == row.after then
        return row.before
    end

    return text
end
