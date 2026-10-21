local addon_name, addon = ...
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
local acquireEvaluationPass,invalidateEvaluationContext
local bindEvaluationContext=addon.BindRuntimeEvaluationContext
if type(bindEvaluationContext)=='function' then
    bindEvaluationContext(addon,function(acquire,invalidate) acquireEvaluationPass,invalidateEvaluationContext=acquire,invalidate end)
    addon.BindRuntimeEvaluationContext=nil
end
local sequenceRawMethod,sequenceRun,sequenceStatus
local bindSequence=addon.BindRotationSequenceReader
if type(bindSequence)=="function" then
    bindSequence(addon,function(rawMethod,run,status) sequenceRawMethod,sequenceRun,sequenceStatus=rawMethod,run,status end)
    addon.BindRotationSequenceReader=nil
end
local function evaluateSequence(owner,body,evaluate,visit)
    local before=sequenceRawMethod and sequenceRawMethod(owner)
    local method=owner.EvaluateRotationSequence
    if sequenceRun then return sequenceRun(owner,before,method,body,evaluate,visit) end
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
local function runtimeRows(owner,spec,candidates)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=owner:AcquireRotationRuntimePass(spec);if not pass then return {},why end
        return pass:Candidates(candidates==true)
    end
    return owner:GetRuntimeRotations(spec,true,candidates)
end
local function runtimeOne(owner,spec,value)
    if owner.GetScopedRotationCoordinator and owner:GetScopedRotationCoordinator() then
        local pass,why=owner:AcquireRotationRuntimePass(spec);if not pass then return nil,why end
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
        selectionPass=self:AcquireRotationRuntimePass(selectedSpec);if not selectionPass then return end
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
    local runtimePass,rot,publicationGuard
    if selectedRotation~=nil then
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
        local function eval(cond)
            local firstMapped,firstItem
            if cond.action~=nil and not cond.disabled and addon:evaluateCondition(cond.conditions,{stepId=cond.id}) then
                local spellids,itemids=addon:GetSpellIds(cond)
                for index,id in ipairs(spellids or {}) do
                    local itemId=itemids and itemids[index]
                    local mapped=addon:FindSpell({id},cond.type=="item" and {itemId} or nil)
                    if mapped then
                        if not firstMapped then firstMapped,firstItem=mapped,itemId end
                        if actionReady(cond.type,id,itemId) then return mapped,true,itemId end
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
        local function current()
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile
                or self.nextWindow~=previewWindow then return false end
            if not runtimePass then return true end
            if publicationGuard then return publicationGuard() end
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
            return addon:evaluateConditionResult(condition,context)
        end,function(cond,index)
            local spellid,enabled,itemId=eval(cond)
            if enabled then
                recommend(spellid,cond,index,itemId)
                if not nativePreview or preview>=self.db.profile.preview_spells then return false end
            end
            return true
        end)
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
            for id,cond in pairs(rot.cooldowns) do
                local spellid,enabled,itemId=eval(cond)
                observations[#observations+1]={id=id,condition=cond,spellid=spellid,enabled=enabled,itemId=itemId}
            end
            stage(function()
                local enabled_cooldowns = {}
                local enabled_items = {}
                local disabled_cooldowns = {}
                for _,observation in ipairs(observations) do
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
                                    addon:DispatchAnnouncement(cond, string.format(L["%s is now available!"], link))
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
                for spellid, cond in pairs(disabled_cooldowns) do
                    if not current() then return end
                    addon:GlowCooldown(spellid, false, cond)
                end
                for spellid, cond in pairs(enabled_cooldowns) do
                    if not current() then return end
                    addon:GlowCooldown(spellid, true, cond, enabled_items[spellid])
                end
            end)
        end
        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        stage(function() addon.skipAnnounce=false;addon.announced={} end)

        -- Every condition and readiness callback finishes before advice becomes
        -- externally visible. Recheck between publishers too: another addon's
        -- message/glow callback may retire this profile or selected record.
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
        rotation=get(self,spec,id)
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
            if value.type~='macro' and (value.value or value.announce == "audible" or value.announce == "gesture") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
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
                    local ent,current=self:PrepareAnnouncementDelivery(value,function()
                        return self.db.profile==profile and profile.announces==announcements
                            and announcements[index]==value and not value.disabled
                            and self.conditionRegistryVersion==registry
                    end)
                    if ent and current() then
                    -- END ANNOUNCEMENT CONDITION LEASE
                    local spellids, itemids = self:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
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
