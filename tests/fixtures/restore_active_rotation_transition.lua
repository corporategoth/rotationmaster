-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact full-module inverse for the active transition unit.
-- Baseline: 9af1ad9 plus the frozen combined revision overlay.
local rows = {
    ['main.lua'] = {
        old = [====[local addon_name, addon = ...
-- SavedVariables identity must match the TOC, independent of folder casing.
addon.savedVariableName = "RotationMasterDB"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

_G[addon_name] = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local getCached
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
        addon:print(L["                          This is reset upon switching specializations."])
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
        local name = string.sub(str, npos)

        if name == "auto" then
            self.manualRotation = false
            self:SwitchRotation()
        elseif name == self.currentRotation then
            self.manualRotation = true
            addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO], name)
        elseif name == DEFAULT then
            if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() and not runtimeOne(self,self.currentSpec,DEFAULT) then
                addon:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.']);return
            end
            self:RemoveAllCurrentGlows()
            self.manualRotation = true
            self.currentRotation = DEFAULT
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            self:EnableRotationTimer()
            DataBroker.text = self:GetRotationName(DEFAULT)
            AceEvent:SendMessage("ROTATIONMASTER_ROTATION", self.currentRotation, self:GetRotationName(self.currentRotation))
            addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO], name)
        else
            do
                local matches={}
                for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]={id=id,body=rot} end end
                if #matches>1 then addon:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
                for _,entry in ipairs(matches) do
                    local id,rot=entry.id,entry.body
                    if rot.name == name then
                        self:RemoveAllCurrentGlows()
                        self.manualRotation = true
                        self.currentRotation = id
                        self.skipAnnounce = true
                        self.avail_announced = {}
                        self.announced = {}
                        self:EnableRotationTimer()
                        DataBroker.text = self:GetRotationName(id)
                        AceEvent:SendMessage("ROTATIONMASTER_ROTATION", self.currentRotation, self:GetRotationName(self.currentRotation))
                        addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO], name)
                        if (not self:rotationValidConditions(rot, self.currentSpec)) then
                            addon:warn(L["Active rotation is incomplete and may not work correctly!"])
                        end
                        return
                    end
                end
            end
            addon:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."], name)
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

local function minimapChangeRotation(_, arg1, _, _)
    if arg1 == nil then
        addon.manualRotation = false
        addon:SwitchRotation()
    else
        addon.manualRotation = true
        if addon.currentSpec ~= arg1 then
            addon:RemoveAllCurrentGlows()
            addon.currentRotation = arg1
            addon.skipAnnounce = true
            addon.avail_announced = {}
            addon.announced = {}
            addon:EnableRotationTimer()
            DataBroker.text = addon:GetRotationName(arg1)
            AceEvent:SendMessage("ROTATIONMASTER_ROTATION", addon.currentRotation, addon:GetRotationName(addon.currentRotation))
        end
        addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],
                addon:GetRotationName(arg1))
    end
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
end

function addon:toggle()
    if self.currentRotation == nil then
        self:enable()
    else
        self:disable()
    end
end

function addon:enable()
    if self.initializationErrorReport then self:ShowErrors();return end
    for _, v in pairs(events) do
        self:RegisterEvent(v)
    end
    local client=self.Platform:GetClientInfo()
    if client.combatDataPolicy=='probe' then
        for _,event in ipairs(combat_events) do self:RegisterEvent(event) end
    end
    local family=client.family
    local extraEvents=family=="retail" or family=="forever"
    extraEvents=extraEvents and mainline_events or family=="progression" and wrath_events
        or family=="tbc" and tbc_events or family=="era" and classic_events or {}
    for _,event in ipairs(extraEvents) do self:RegisterEvent(event) end

    if self.RefreshPreviewWindow then self:RefreshPreviewWindow() end
    self:UpdateSkill()
    self:EnableRotation()
end

function addon:disable()
    if self.initializationErrorReport then return end
    self:DisableRotation()
    if self.nextWindow then
        local spells = self.db.profile.preview_spells
        self.nextWindow:Release()
        self.nextWindow = nil
        self.db.profile.preview_spells = spells
    end
    self.spellHistory = {}
    self.combatHistory = {}
    self:UnregisterAllEvents()

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
    if self.db.profile.disable_autoswitch or self.manualRotation then
        return
    end

    local newRotation
    local selectedSpec,selectedProfile,selectedRotation=self.currentSpec,self.db.profile,self.currentRotation
    local selectionPass,rotations
    if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
        selectionPass=self:AcquireRotationRuntimePass(selectedSpec);if not selectionPass then return end
        local why;rotations,why=selectionPass:Candidates(false);if why then return end
    else rotations=runtimeRows(self,selectedSpec) end
    local function current()
        return self.currentSpec==selectedSpec and self.db.profile==selectedProfile and self.currentRotation==selectedRotation
            and not self.db.profile.disable_autoswitch and not self.manualRotation and (not selectionPass or selectionPass:IsCurrent())
    end
    for _, v in ipairs(self.autoswitchRotation) do
        -- A packaged recommendation must not displace the user's saved fallback.
        if self:IsDefaultRuntimeRotation(self.currentSpec,v) and rotations[DEFAULT]
            and self:rotationValidConditions(rotations[DEFAULT],self.currentSpec) then
            newRotation=DEFAULT
            break
        end
        if rotations[v] and addon:evaluateCondition(rotations[v].switch) then
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
            self:RemoveAllCurrentGlows()
            if not current() then return end
            self.currentRotation = newRotation
            selectedRotation=newRotation
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            self:EnableRotationTimer()
            if not current() then return end
            DataBroker.text = name
            if not current() then return end
            addon:info(L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO],name)
            if not current() then return end
            AceEvent:SendMessage("ROTATIONMASTER_ROTATION",self.currentRotation,name)
        end
        return
    end

    -- Could not find a rotation to switch to, even the default one.
    if self.currentRotation ~= nil then
        addon:warn(L["No rotation is active as there is none suitable to automatically switch to."])
        if not current() then return end
        self:DisableRotation()
    end
end

function addon:EnableRotation()
    if self.currentSpec==nil then return end
    if self.currentRotation then
        return
    end

    self:Fetch()
    self:UpdateAutoSwitch()
    self:SwitchRotation()
    if self.currentRotation ~= nil then
        DataBroker.text = self:GetRotationName(self.currentRotation)
        addon:info(L["Battle rotation enabled"])
    end
end

function addon:DisableRotation()
    if not self.currentRotation then
        return
    end

    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
    self:DestroyAllGlows()
    self.currentRotation = nil
    self.currentSpell = nil
    self.avail_announced = {}
    self.announced = {}
    if self.nextWindow then self.nextWindow:ReleaseChildren() end
    DataBroker.text = color.RED .. OFF
    AceEvent:SendMessage("ROTATIONMASTER_ROTATION", nil)
    AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
    if WeakAuras and WeakAuras.ScanEvents then WeakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", nil, nil) end
    addon:info(L["Battle rotation disabled"])
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
    self.adviceErrorReport = reportId
    self.currentRotation = nil
    self.currentSpell = nil
    self.avail_announced = {}
    local timer = self.rotationTimer
    self.rotationTimer = nil
    local function cleanup(operation, callback, ...)
        self.Diagnostics:Call({module="recommendations", operation=operation}, callback, ...)
    end
    if timer then cleanup("cancel-timer", self.CancelTimer, self, timer) end
    if self.nextWindow then cleanup("hide-preview", self.nextWindow.Hide, self.nextWindow) end
    cleanup("clear-glows", self.RemoveAllCurrentGlows, self)
    cleanup("destroy-glows", self.DestroyAllGlows, self)
    cleanup("broker-disabled", function() DataBroker.text = color.RED .. OFF end)
    cleanup("rotation-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_ROTATION", nil)
    cleanup("suggestion-cleared", AceEvent.SendMessage, AceEvent, "ROTATIONMASTER_SPELL_UPDATE", nil, nil)
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
    local runtimePass,rot
    if selectedRotation~=nil then
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            runtimePass=self:AcquireRotationRuntimePass(selectedSpec)
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
            return self.currentRotation==selectedRotation and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
                and self.nextWindow==previewWindow and (not runtimePass or runtimePass:IsCurrent())
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
    addon:debug(L["Removing all glows."])
    local rotation=self.currentRotation and self:GetRotationForCleanup(self.currentSpec,self.currentRotation)
    if rotation and rotation.cooldowns then
        for _, rot in pairs(rotation.cooldowns) do
            for _, spellid in pairs(addon:GetSpellIds(rot)) do
                addon:GlowCooldown(spellid, false)
            end
        end
    end
    addon:GlowClear()
end

function addon:UpdateSpecSpells()
    return self:RefreshSpellCatalog()
end

function addon:UpdateSkill()
    self:verbose("Skill update triggered")
    local selection=self.Platform:GetRotationSpecialization()
    local spec=selection and selection.key
    if spec~=self.currentSpec then
        self:DisableRotation()
        self.manualRotation=false
    end
    self.currentSpec=spec
    self.longtermCache={}
    if not selection then
        self.autoswitchRotation={}
        return
    end
    if self.specTab then self.specTab:SelectTab(spec) end

    self:UpdateSpecSpells()
    self:UpdateAutoSwitch()
    self:SwitchRotation()
    self:ButtonFetch()


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

local function wrapEvent(func)
    local failed = false
    return function(self, event, ...)
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
addon.VEHICLE_UPDATE = wrapEvent(addon.ButtonFetch)

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

addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        self.unitsInRange[guid].unit = unit
    else
        self.unitsInRange[guid] = CreateUnitInfo({}, unit)
    end
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        local handled = false
        for u, _ in pairs(addon.units) do
            if UnitIsUnit(unit, u) then
                self.unitsInRange[guid].unit = u
                handled = true
                break
            end
        end
        if not handled then
            self.unitsInRange[guid] = nil
        end
    end
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
        for _, value in ipairs(self.db.profile.announces) do
            if (value.value or value.announce == "audible") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
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
                    local ent = self.Functions.collections.deepcopy(value)
                    if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                        ent.action = ent.spell
                    elseif ent.type == "item" then
                        ent.action = ent.item
                    end

                    local spellids, itemids = self:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
                            local text = ent.value or ""
                            if ent.announce~='audible' then
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
                            self:DispatchAnnouncement(ent, text)
                            if self.announced[value.id] == nil then
                                self.announced[value.id] = { castguid }
                            else
                                table.insert(self.announced[value.id], castguid)
                            end
                            break
                        end
                    end
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
]====],
        new = [====[local addon_name, addon = ...
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local advanceActiveSpec=addon.AdvanceActiveRotationSpecialization
local retireActive=addon.RetireActiveRotationTransition
local commitActive=addon.CommitActiveRotationTransition
local cleanupActive=addon.GetActiveRotationCleanupSelection
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
        addon:print(L["                          This is reset upon switching specializations."])
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

        if name == "auto" then
            self.manualRotation = false
            self:SwitchRotation()
        elseif name == self.currentRotation then
            self.manualRotation = true
            activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
        elseif name == DEFAULT then
            if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() and not runtimeOne(self,self.currentSpec,DEFAULT) then
                addon:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.']);return
            end
            if not activeChangeCurrent(self,change) then return end
            local body=runtimeOne(self,self.currentSpec,DEFAULT)
            if not activeChangeCurrent(self,change) or not body then return end
            if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
            if not activeCall(self,change,'RemoveAllCurrentGlows') then return end
            if not commitActive(self,change,self.currentSpec,DEFAULT,body) or not activeChangeCurrent(self,change) then return end
            self.manualRotation = true
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            if not activeCall(self,change,'EnableRotationTimer') then return end
            local named,displayName=activeValue(self,change,'GetRotationName',DEFAULT)
            if not named then return end
            if not activeBroker(self,change,DataBroker,displayName) then return end
            local namedCurrent,currentName=activeValue(self,change,'GetRotationName',self.currentRotation)
            if not namedCurrent then return end
            if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,currentName) then return end
            if not activeChangeCurrent(self,change) then return end
            activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
        else
            do
                local matches={}
                for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]={id=id,body=rot} end end
                if not activeChangeCurrent(self,change) then return end
                if #matches>1 then addon:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
                for _,entry in ipairs(matches) do
                    local id,rot=entry.id,entry.body
                    if rot.name == name then
                        if not activeChangeCurrent(self,change) then return end
                        if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
                        if not activeCall(self,change,'RemoveAllCurrentGlows') then return end
                        if not commitActive(self,change,self.currentSpec,id,rot) or not activeChangeCurrent(self,change) then return end
                        self.manualRotation = true
                        self.skipAnnounce = true
                        self.avail_announced = {}
                        self.announced = {}
                        if not activeCall(self,change,'EnableRotationTimer') then return end
                        local named,displayName=activeValue(self,change,'GetRotationName',id)
                        if not named then return end
                        if not activeBroker(self,change,DataBroker,displayName) then return end
                        local namedCurrent,currentName=activeValue(self,change,'GetRotationName',self.currentRotation)
                        if not namedCurrent then return end
                        if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,currentName) then return end
                        if not activeChangeCurrent(self,change) then return end
                        activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
                        if not activeChangeCurrent(self,change) then return end
                        local checked,valid=activeValue(self,change,'rotationValidConditions',rot,self.currentSpec)
                        if not checked then return end
                        if not valid then activeCall(self,change,'warn',L["Active rotation is incomplete and may not work correctly!"]) end
                        return
                    end
                end
            end
            addon:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."], name)
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

local function minimapChangeRotation(_, arg1, _, _)
    local change=beginActive(addon)
    if not activeChangeCurrent(addon,change) then return end
    if arg1 == nil then
        addon.manualRotation = false
        addon:SwitchRotation()
    else
        if addon.currentSpec ~= arg1 then
            local body=runtimeOne(addon,addon.currentSpec,arg1)
            if not activeChangeCurrent(addon,change) or not body then return end
            if not retireActive(addon,change) or not activeChangeCurrent(addon,change) then return end
            if not activeCall(addon,change,'RemoveAllCurrentGlows') then return end
            if not commitActive(addon,change,addon.currentSpec,arg1,body) or not activeChangeCurrent(addon,change) then return end
            addon.skipAnnounce = true
            addon.avail_announced = {}
            addon.announced = {}
            if not activeCall(addon,change,'EnableRotationTimer') then return end
            local named,name=activeValue(addon,change,'GetRotationName',arg1)
            if not named then return end
            if not activeBroker(addon,change,DataBroker,name) then return end
            local namedCurrent,currentName=activeValue(addon,change,'GetRotationName',addon.currentRotation)
            if not namedCurrent then return end
            if not activeObjectCall(addon,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",addon.currentRotation,currentName) then return end
            if not activeChangeCurrent(addon,change) then return end
        end
        addon.manualRotation = true
        local named,name=activeValue(addon,change,'GetRotationName',arg1)
        if not named then return end
        activeCall(addon,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
    end
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
end

function addon:toggle()
    if self.currentRotation == nil then
        self:enable()
    else
        self:disable()
    end
end

function addon:enable()
    if self.initializationErrorReport then self:ShowErrors();return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
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

    if self.RefreshPreviewWindow then
        if not activeCall(self,change,'RefreshPreviewWindow') then return end
    end
    if not activeChangeCurrent(self,change) then return end
    local update=self.UpdateSkill
    if not activeChangeCurrent(self,change) then return end
    local _,nextChange=update(self);change=nextChange or change
    if not activeChangeCurrent(self,change) then return end
    activeCall(self,change,'EnableRotation')
end

function addon:disable()
    if self.initializationErrorReport then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) then return end
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
    if self.db.profile.disable_autoswitch or self.manualRotation then
        return
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
    local function current()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile and self.currentRotation==selectedRotation
            and not self.db.profile.disable_autoswitch and not self.manualRotation and (not selectionPass or selectionPass:IsCurrent())
    end
    for _, v in ipairs(self.autoswitchRotation) do
        -- A packaged recommendation must not displace the user's saved fallback.
        if self:IsDefaultRuntimeRotation(self.currentSpec,v) and rotations[DEFAULT]
            and self:rotationValidConditions(rotations[DEFAULT],self.currentSpec) then
            newRotation=DEFAULT
            break
        end
        if rotations[v] and addon:evaluateCondition(rotations[v].switch) then
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
    local runtimePass,rot
    if selectedRotation~=nil then
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            runtimePass=self:AcquireRotationRuntimePass(selectedSpec)
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
            return self.currentRotation==selectedRotation and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
                and self.nextWindow==previewWindow and (not runtimePass or runtimePass:IsCurrent())
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

local function wrapEvent(func)
    local failed = false
    return function(self, event, ...)
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
addon.VEHICLE_UPDATE = wrapEvent(addon.ButtonFetch)

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

addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        self.unitsInRange[guid].unit = unit
    else
        self.unitsInRange[guid] = CreateUnitInfo({}, unit)
    end
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        local handled = false
        for u, _ in pairs(addon.units) do
            if UnitIsUnit(unit, u) then
                self.unitsInRange[guid].unit = u
                handled = true
                break
            end
        end
        if not handled then
            self.unitsInRange[guid] = nil
        end
    end
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
        for _, value in ipairs(self.db.profile.announces) do
            if (value.value or value.announce == "audible") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
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
                    local ent = self.Functions.collections.deepcopy(value)
                    if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                        ent.action = ent.spell
                    elseif ent.type == "item" then
                        ent.action = ent.item
                    end

                    local spellids, itemids = self:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
                            local text = ent.value or ""
                            if ent.announce~='audible' then
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
                            self:DispatchAnnouncement(ent, text)
                            if self.announced[value.id] == nil then
                                self.announced[value.id] = { castguid }
                            else
                                table.insert(self.announced[value.id], castguid)
                            end
                            break
                        end
                    end
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
]====],
    },
    ['Core/rotation_lifecycle.lua'] = {
        old = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
    if not ok and self.warn then self:warn(L['Rotation data requires recovery: %s'],why) end
    return ok,why
end

function addon:RotationProfileChanged()
    if (self.rotationProfileChangeDepth or 0)>0 then return self:RefreshRotationProfileStorage() end
    if self.DisableRotation then self:DisableRotation() end
    self.manualRotation=false;self.autoswitchRotation={};self.longtermCache={}
    self.configRotationSelection=nil
    local ok,why=self:RefreshRotationProfileStorage()
    if self.RefreshConfiguration then self:RefreshConfiguration() end
    if ok and self.db.profile.enable and self.EnableRotation then self:EnableRotation() end
    return ok,why
end

function addon:InstallRotationProfileLifecycle()
    local db=self.db
    local previous=self.rotationProfileLifecycleDB
    local previousOwner=self.rotationProfileLifecycleOwner
    if self.rotationProfileLifecycleInstalled and previous==db and previousOwner then return end
    -- Retire authority before removing callbacks. A callback already captured
    -- by a dispatch must not apply the old database's event to a new active DB.
    self.rotationProfileLifecycleDB=nil
    self.rotationProfileLifecycleOwner=nil
    if previous and previousOwner then
        for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
            previous.UnregisterCallback(previousOwner,event)
        end
    end
    -- The addon itself already owns the init reset seeder on this registry.
    -- Give lifecycle callbacks a distinct binding owner so both can coexist.
    local owner={}
    local function changed(...)
        if self.db~=db or self.rotationProfileLifecycleDB~=db or self.rotationProfileLifecycleOwner~=owner then return end
        return self:RotationProfileChanged(...)
    end
    for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
        db.RegisterCallback(owner,event,changed)
    end
    self.rotationProfileLifecycleDB=db
    self.rotationProfileLifecycleOwner=owner
    self.rotationProfileLifecycleInstalled=true
end
]====],
        new = [====[local addon_name,addon=...
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local retireActive=addon.RetireActiveRotationTransition
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
    if not ok and self.warn then self:warn(L['Rotation data requires recovery: %s'],why) end
    return ok,why
end

function addon:RotationProfileChanged()
    local change=beginActive(self)
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    if (self.rotationProfileChangeDepth or 0)>0 then
        if not retireActive(self,change) or not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
        local refresh=self.RefreshRotationProfileStorage
        if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
        return refresh(self)
    end
    local available=self.DisableRotation
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    if available then
        local disable=self.DisableRotation
        if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
        local _,nextChange,stopped=disable(self)
        if stopped==false then return nil,'rotation-transition-superseded' end
        change=nextChange or change
        if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    elseif not retireActive(self,change) or not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    self.manualRotation=false;self.autoswitchRotation={};self.longtermCache={}
    self.configRotationSelection=nil
    local refresh=self.RefreshRotationProfileStorage
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    local ok,why=refresh(self)
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    local configure=self.RefreshConfiguration
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    if configure then
        configure=self.RefreshConfiguration
        if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
        configure(self)
    end
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    if ok and self.db.profile.enable and self.EnableRotation then
        local enable=self.EnableRotation
        if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
        enable(self)
    end
    return ok,why
end

function addon:InstallRotationProfileLifecycle()
    local db=self.db
    local previous=self.rotationProfileLifecycleDB
    local previousOwner=self.rotationProfileLifecycleOwner
    if self.rotationProfileLifecycleInstalled and previous==db and previousOwner then return end
    -- Retire authority before removing callbacks. A callback already captured
    -- by a dispatch must not apply the old database's event to a new active DB.
    self.rotationProfileLifecycleDB=nil
    self.rotationProfileLifecycleOwner=nil
    if previous and previousOwner then
        for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
            previous.UnregisterCallback(previousOwner,event)
        end
    end
    -- The addon itself already owns the init reset seeder on this registry.
    -- Give lifecycle callbacks a distinct binding owner so both can coexist.
    local owner={}
    local function changed(...)
        if self.db~=db or self.rotationProfileLifecycleDB~=db or self.rotationProfileLifecycleOwner~=owner then return end
        return self:RotationProfileChanged(...)
    end
    for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
        db.RegisterCallback(owner,event,changed)
    end
    self.rotationProfileLifecycleDB=db
    self.rotationProfileLifecycleOwner=owner
    self.rotationProfileLifecycleInstalled=true
end
]====],
    },
    ['Core/rotation_library.lua'] = {
        old = [====[local addon_name, addon = ...
local data = addon.RotationData
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local definitions, definitionVersion = {}, 0
local active
local readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable
local bindValidation=addon.BindRotationValidationReader
if type(bindValidation)=='function' then
    bindValidation(addon,function(read,check,raw,identity,kind,meta)
        if type(read)=='function' and type(check)=='function' and type(raw)=='function'
            and type(identity)=='function' and type(kind)=='function' and type(meta)=='function' then
            readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable=read,check,raw,identity,kind,meta
        end
    end)
    addon.BindRotationValidationReader=nil
end
local function validationPlain(value)
    return validationType(value)=='table' and validationGetmetatable(value)==nil
end

local function contains(list, value)
    for _,entry in ipairs(list or {}) do if entry==value then return true end end
    return false
end
local function matchesClass(view,context)
    local scope=view.applicability
    return not scope or not scope.class or scope.class==context.class
end
local function eligible(view, context, candidates)
    if not view.enabled then return false,"disabled" end
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then return false,"invalid-or-unsupported" end
    if not matchesClass(view,context) then return false,"class-mismatch" end
    if candidates then return true end
    local scope=view.applicability
    if not scope or not contains(scope.families,context.family) then return false,"edition-mismatch" end
    if scope.specs and not contains(scope.specs,context.spec) then return false,"specialization-mismatch" end
    if scope.actionContext~=context.actionContext then return false,"action-context-mismatch" end
    for _,range in ipairs({{"minLevel","maxLevel","level"},{"minBuild","maxBuild","build"}}) do
        local value=context[range[3]]
        if scope[range[1]] or scope[range[2]] then
            if type(value)~="number" then return false,"missing-"..range[3] end
            if scope[range[1]] and value<scope[range[1]] or scope[range[2]] and value>scope[range[2]] then return false,range[3].."-mismatch" end
        end
    end
    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.rulesets or scope.intent or scope.roles then return false,"unsupported-context-selector" end
    if context.combatDataPolicy~="probe" then return false,"restricted-or-unsupported-client" end
    return true
end
local function plainTable(value)
    return type(value)=="table" and getmetatable(value)==nil
end

function addon:RegisterDefaultRotation(envelope)
    local copy,why=data.CopyData(envelope)
    if not copy then return false,why.code end
    if copy.format~="RotationMaster" or copy.schemaVersion~=1 or not data.ValidateEnvelope(copy).valid then return false,"invalid-envelope" end
    if not copy.applicability.class and copy.applicability.universal~=true then return false,"missing-class-scope" end
    if definitions[copy.id] then return false,"duplicate-default-id" end
    definitions[copy.id]=copy;definitionVersion=definitionVersion+1
    return true
end

function addon:InitializeRotationLibrary()
    local profile=self.db.profile
    local validation,referenceStamp=self:GetRotationValidationOptions()
    local state=profile.rotationLibrary
    if state==nil then state={};profile.rotationLibrary=state end
    if not plainTable(state) then active=nil;return false,"invalid-library-state" end
    for _,key in ipairs({"preferences","origins","comparisons","imports"}) do
        if state[key]~=nil and not plainTable(state[key]) then active=nil;return false,"invalid-library-state" end
    end
    state.preferences,state.origins,state.comparisons,state.imports=state.preferences or {},state.origins or {},state.comparisons or {},state.imports or {}
    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog,why=data.NewCatalog({state={preferences=state.preferences},
        validation=validation,newId=self.uuid})
    if not catalog then active=nil;return false,why end
    local views,bodies={},{}
    for id,envelope in pairs(definitions) do
        local ok,reason=catalog:RegisterBuiltin(envelope)
        if not ok then active=nil;return false,reason end
        views[id]=catalog:Get({kind="builtin",id=id})
        bodies[id]=data.CopyData(views[id].envelope.body)
        bodies[id].name=L[views[id].nameKey]
    end
    active={profile=profile,state=state,catalog=catalog,views=views,bodies=bodies,cloneScopes={},version=definitionVersion,referenceStamp=referenceStamp,generation={}}
    for spec,origins in pairs(state.origins) do
        if type(spec)=="number" and plainTable(origins) then
            active.cloneScopes[spec]={}
            for id in pairs(origins) do
                local view=self:GetSourcedRotationView(spec,id)
                if view then
                    view.validation=data.ValidateEnvelope(view.envelope,validation)
                    view.enabled=true
                end
                active.cloneScopes[spec][id]=view or false
            end
        end
    end
    return true
end
local ownedInitializeRotationLibrary=addon.InitializeRotationLibrary
local function ensure(self,needProof)
    local referenceStamp,method,db,profile,global,conditions,shared,personal,effects,version,state
    local plainStamps=false
    if needProof and readValidationStamp then
        local entryMethod=validationType(self)=='table' and validationRawget(self,'GetRotationValidationStamp') or nil
        method=self.GetRotationValidationStamp
        referenceStamp,db,profile,global,conditions,shared,personal,effects,version,state=readValidationStamp(self,method,entryMethod)
        plainStamps=db~=nil and validationPlain(referenceStamp) and active~=nil
            and validationPlain(active.referenceStamp) and validationPlain(active.generation)
    else referenceStamp=self:GetRotationValidationStamp() end
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then local ok,why=self:InitializeRotationLibrary();return ok,why end
        return self:InitializeRotationLibrary()
    end
    -- An initializer call never issues proof, even if it returns the same generation.
    if plainStamps and validationRawequal(validationRawget(self,'InitializeRotationLibrary'),ownedInitializeRotationLibrary)
        and checkValidationLayout(self,method,db,profile,global,conditions,shared,personal,effects,version,state) then
        return true,nil,referenceStamp,true
    end
    return true
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context=self.Platform:GetClientInfo()
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and self.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local ownedRotationContext=addon.GetRotationContext
local clientContextReader
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local function runtimeKey(id, custom)
    local key="RM-BUILTIN:"..id
    while custom[key]~=nil do key=":"..key end
    return key
end
-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind)~='function' then return nil,'invalid-library-reader-binder' end
    local owner=self;local reader={}
    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    function reader:Context(spec) return rotationContext(owner,spec) end
    local function generationMethod(self)
        local ok,why,checked,proof=ensure(owner,true);if not ok then return nil,why end
        return active.generation,nil,checked,proof
    end
    reader.Generation=generationMethod
    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method,reference,generation)
        return validationRawget~=nil and validationPlain(reader) and validationPlain(reference) and validationPlain(generation)
            and validationRawequal(validationRawget(reader,'Generation'),generationMethod)
            and (method==nil or validationRawequal(method,generationMethod))
    end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local view=active.views[id];if not view then return nil,'unknown-rotation' end
        local context=rotationContext(owner,spec);context.spec=spec
        if not matchesClass(view,context) then return nil,'class-mismatch' end
        local allowed,reason=eligible(view,context,candidates)
        return true,project(view,active.bodies[id],allowed,reason),active.generation
    end
    function reader:List(spec,project)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
        for id,view in pairs(active.views) do if matchesClass(view,context) then rows[#rows+1]=project(id,view,active.bodies[id]) end end
        return rows,active.generation
    end
    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration);return true
end

function addon:ListDefaultRotations(spec)
    local ok,why=ensure(self)
    if not ok then return {},why end
    local context=self:GetRotationContext(spec);context.spec=spec
    local custom=(self.db.profile.rotations or {})[spec] or {}
    local rows={}
    for id,view in pairs(active.views) do
        if matchesClass(view,context) then
            local row=data.CopyData(view)
            local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey=scoped and scoped:Key({kind='builtin',id=id}) or runtimeKey(id,custom)
            row.eligible,row.eligibilityReason=eligible(view,context)
            row.name=L[row.nameKey or id]
            row.description=L[row.descriptionKey or ""]
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function addon:GetDefaultRotation(id)
    if not ensure(self) then return nil end
    return active.catalog:Get({kind="builtin",id=id})
end
function addon:SetDefaultRotationEnabled(id,value)
    local ok,why=ensure(self);if not ok then return false,why end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
    return saved,reason
end
function addon:GetEditableRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:GetEditableRotation(spec,id) end
    local rotations=self.db.profile.rotations[spec]
    return rotations and rotations[id]
end
function addon:OwnsRotationCondition(spec,id,step,condition)
    local body=self:GetEditableRotation(spec,id)
    local tree=body and data.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return false end
    for _,row in ipairs(tree.rows) do if row.step==step and step.conditions==condition then return true end end
    return false
end
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then local pass,why=scoped:RuntimePass(spec);if not pass then return {},why end;local rows,reason=pass:Candidates(candidates==true);for key,body in pairs(rows) do local ref=scoped:Resolve(spec,key);if ref and ref.kind=='custom' then rows[key]=scoped:GetEditableRotation(spec,key) else rows[key]=data.CopyData(body) end end;return rows,reason end
    local rotations={}
    if spec==nil then return rotations end
    local ready=ensure(self)
    local context=self:GetRotationContext(spec);context.spec=spec
    -- Editing/export use the saved-data facade independently. Legacy bodies
    -- must obey the same client execution policy as packaged/scoped rotations.
    if context.combatDataPolicy~="probe" then return rotations end
    local origins=ready and active.state.origins[spec]
    local scopes=ready and active.cloneScopes[spec]
    for id,body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped=scopes and scopes[id]
        local imported,importError
        if self.GetImportedRotationView then imported,importError=self:GetImportedRotationView(spec,id) end
        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body=body
            scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
            scoped.applicability=scoped.envelope.applicability
        end
        if not origins or plainTable(origins) and origins[id]==nil
            or scoped and eligible(scoped,context,candidates) then
            if (not self.GetImportedRotationView or importError=="not-imported" or imported and eligible(imported,context,candidates))
                and not self:HasDisabledRotationDependency(body) then rotations[id]=body end
        end
    end
    if not ready then return rotations end
    for id,view in pairs(active.views) do
        if eligible(view,context,candidates) then
            local body=internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id,rotations)]=body
        end
    end
    return rotations
end
function addon:GetRuntimeRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local pass,why=scoped:RuntimePass(spec);if not pass then return nil,why end
        local body,bodyReason=pass:Get(id);if not body then return nil,bodyReason end
        local reference=scoped:Resolve(spec,id);if reference.kind=='custom' then return scoped:GetEditableRotation(spec,reference) end
        return data.CopyData(body)
    end
    return self:GetRuntimeRotations(spec,true)[id]
end
function addon:CloneDefaultRotation(spec,id,name,options)
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if coordinator then return coordinator:Copy(spec,{kind='builtin',id=id},name,options) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local rotations=self.db.profile.rotations[spec] or {}
    if rotations[generated]~=nil then return nil,"id-collision" end
    local view=temporary:Get({kind="custom",id=generated})
    local manifest=view.envelope;local body=manifest.body;manifest.body=nil
    if manifest.applicability.universal then
        manifest.applicability.universal=nil;manifest.applicability.class=context.class
    end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    origins=origins or {}
    if origins[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec]=rotations;rotations[generated]=body
    active.state.origins[spec]=origins;origins[generated]={manifest=manifest,lineage=view.lineage}
    local scoped=self:GetSourcedRotationView(spec,generated)
    scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
    scoped.enabled=true
    active.cloneScopes[spec]=active.cloneScopes[spec] or {};active.cloneScopes[spec][generated]=scoped
    return generated
end
function addon:GetSourcedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,false) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins==nil then return nil,"no-source-baseline" end
    if not plainTable(origins) then return nil,"invalid-origin-state" end
    if origins[id]==nil then return nil,"no-source-baseline" end
    local origin,problem=data.CopyData(origins[id])
    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id~=id then return nil,"invalid-origin-state" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local envelope=data.CopyData(origin.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-custom-body" end
    -- Catalog validates both current structure and retained historical lineage.
    local state={custom={[id]=envelope},lineage={[id]=origin.lineage}}
    local catalog,reason=data.NewCatalog({state=state})
    if not catalog then return nil,reason end
    local view=catalog:Get({kind="custom",id=id})
    if view.lineageError then return nil,"invalid-origin-state" end
    return view
end

function addon:IsDefaultRuntimeRotation(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return self:GetDefaultIdForRuntime(spec,key)~=nil end
    if not ensure(self) then return false end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return true end end
    return false
end

function addon:GetDefaultIdForRuntime(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then local ref=scoped:Resolve(spec,key);return ref and ref.kind=='builtin' and ref.id or nil end
    if not ensure(self) then return nil end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return id end end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec,true,true)
end
function addon:GetRotationForCleanup(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Cleanup(spec,key) end
    local custom=self:GetEditableRotation(spec,key)
    if custom then return custom end
    if not ensure(self) then return nil end
    local saved=self.db.profile.rotations[spec] or {}
    for id,body in pairs(active.bodies) do if runtimeKey(id,saved)==key then return body end end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:ComparisonIdentity(spec,id) end
    if not ensure(self) then return nil,"invalid-library-state" end
    local rows=active.state.comparisons[spec]
    if rows~=nil and not plainTable(rows) then return nil,"invalid-comparison-origin" end
    local identity
    if rows and rows[id]~=nil then
        local why
        identity,why=data.CopyData(rows[id])
        if why or not plainTable(identity) or (identity.kind~="custom" and identity.kind~="builtin")
            or type(identity.id)~="string" or not plainTable(identity.origins) then return nil,"invalid-comparison-origin" end
    end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if view then
        if identity and (identity.kind~=view.lineage.sourceKind or identity.id~=view.lineage.sourceId) then return nil,"invalid-comparison-origin" end
        identity=identity or {kind=view.lineage.sourceKind,id=view.lineage.sourceId,origins={}}
        for key,origin in pairs(view.lineage.stepOrigins) do identity.origins[key]=origin end
        return identity
    end
    if self.GetImportedRotationView then
        local imported,why=self:GetImportedRotationView(spec,id)
        if imported then return {kind="import",id=imported.sourceId,origins=imported.stepOrigins}
        elseif why~="not-imported" then return nil,why end
    end
    return identity or {kind="custom",id=id}
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec,id,name,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Copy(spec,id,name,options) end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            local revision,problem=data.GetRotationContentRevision(prepared.body);if not revision then return nil,problem end
            prepared.manifest.body=nil;prepared.body.revision=1
            if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    local revision,revisionError=data.GetRotationContentRevision(body);if not revision then return nil,revisionError end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local ok,why=ensure(self);if not ok then return nil,why end
    if library==nil then library=profile.rotationLibrary end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    local sourceView
    if origins and origins[id]~=nil then
        sourceView,why=self:GetSourcedRotationView(spec,id)
        if not sourceView then return nil,why end
    end
    local identity,identityError=self:GetRotationComparisonIdentity(spec,id)
    if not identity then return nil,identityError end
    local correspondence={kind=identity.kind,id=identity.id,origins={}}
    local comparisonRows=active.state.comparisons[spec]
    if comparisonRows~=nil and not plainTable(comparisonRows) then return nil,"invalid-comparison-origin" end
    local used={}
    for _,rotations in pairs(self.db.profile.rotations) do
        if type(rotations)=="table" then
            for key,rotation in pairs(rotations) do
                used[key]=true
                data.ReserveRotationIdentities(rotation,used)
            end
        end
    end
    local function reserve(value) if type(value)=="string" then used[value]=true end end
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope,used)
    end
    for _,envelope in pairs(definitions) do reserveEnvelope(envelope) end
    for _,rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local entry=data.CopyData(raw)
                local retained=type(entry)=="table" and entry.lineage
                if type(retained)=="table" then
                    reserve(retained.sourceId);reserve(retained.clonedFrom)
                    if type(retained.baseline)=="table" then reserveEnvelope(retained.baseline) end
                    if type(retained.stepOrigins)=="table" then for step,origin in pairs(retained.stepOrigins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    for _,rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local retained=data.CopyData(raw)
                if type(retained)=="table" then
                    reserve(retained.id)
                    if type(retained.origins)=="table" then for step,origin in pairs(retained.origins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    local function fresh()
        local generatedOk,value=pcall(self.uuid)
        if not generatedOk or type(value)~="string" or #value>128 or not value:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[value] or definitions[value] then return nil,"id-collision" end
        used[value]=true;return value
    end
    local generated,reason=fresh();if not generated then return nil,reason end
    local lineage=sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins=lineage and lineage.stepOrigins
    if lineage then lineage.clonedFrom=id;lineage.stepOrigins={} end
    local indexed,indexError=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not indexed then return nil,indexError.code end
    for _,row in ipairs(indexed.rows) do
        local entry=row.step
        local stepId,errorCode=fresh();if not stepId then return nil,errorCode end
        if lineage then lineage.stepOrigins[stepId]=previousOrigins[entry.id] end
        correspondence.origins[stepId]=identity.origins and identity.origins[entry.id] or entry.id
        entry.id=stepId
    end
    body.name=name;body.revision=1
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    self.db.profile.rotations[spec][generated]=body
    if metadata then origins[generated]=metadata end
    comparisonRows=comparisonRows or {};active.state.comparisons[spec]=comparisonRows
    comparisonRows[generated]=correspondence
    self:InitializeRotationLibrary()
    return generated
end

function addon:BuildRotationComparison(spec,id,target)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if not target then return nil,'missing-comparison-target' end
        local targetReference
        if type(target)=='table' and target.kind=='custom' and not target.address then targetReference,why=scoped:Resolve(spec,target.id)
        else targetReference,why=scoped:Resolve(spec,target) end
        if not targetReference then return nil,why end
        local function sameAddress(a,b)
            if a.kind~=b.kind then return false end;if a.kind=='builtin' then return a.id==b.id end
            for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end;return true
        end
        if sameAddress(reference,targetReference) then return nil,'self-comparison' end
        local current,currentReason=scoped:Snapshot(spec,reference);if not current then return nil,currentReason end
        local other,targetReason=scoped:Snapshot(spec,targetReference);if not other then return nil,targetReason end
        local view=scoped:SourceView(spec,reference,false)
        if view and targetReference.kind=='builtin' and view.lineage.sourceKind=='builtin' and view.lineage.sourceId==targetReference.id then
            local source=other.source;local result=data.CompareClone(view,source)
            result.views={{key='current',left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key='source',left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key='custom',left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges}}
            return result
        end
        local left,leftError=scoped:ComparisonIdentity(spec,targetReference);local right,rightError=scoped:ComparisonIdentity(spec,reference)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        local exact=left.kind=='builtin' or left.kind=='import' or left.kind=='custom' and left.sourceAddress and right.sourceAddress and sameAddress({kind='custom',address=left.sourceAddress},{kind='custom',address=right.sourceAddress})
        if exact and left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other.body,self:GetRotationTags(spec,targetReference))
        local rightValue=data.RotationComparisonValue(current.body,self:GetRotationTags(spec,reference))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key='current',left=leftValue,right=rightValue,leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    if target and target.kind=="custom" and target.id==id then return nil,"self-comparison" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if target and target.kind=="builtin" then
        local source=self:GetDefaultRotation(target.id)
        if not source then return nil,"unknown-rotation" end
        if view and view.lineage.sourceKind=="builtin" and view.lineage.sourceId==target.id then
            local result=data.CompareClone(view,source)
            result.views={
                {key="current",left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key="source",left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key="custom",left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges},
            }
            return result
        end
        local leftValue=data.RotationComparisonValue(source.envelope.body,source.envelope.tags)
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue)
        leftValue.nameKey=source.envelope.nameKey
        result.views={{key="current",left=leftValue,right=rightValue,diff=data.CopyData(result)}}
        return result
    elseif target and target.kind=="custom" then
        local other=self:GetEditableRotation(spec,target.id)
        if not other then return nil,"unknown-rotation" end
        local left,leftError=self:GetRotationComparisonIdentity(spec,target.id)
        local right,rightError=self:GetRotationComparisonIdentity(spec,id)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        if left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other,self:GetRotationTags(spec,target.id))
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key="current",left=leftValue,right=rightValue,
            leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    return nil,"missing-comparison-target"
end

function addon:DeleteCustomRotation(spec,id,expected)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent then
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            self.currentRotation=nil;self.manualRotation=false
        end
        return true
    end
    if id==(DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec,id) then return nil,'read-only-rotation' end
    local body=self:GetEditableRotation(spec,id)
    if type(body)~='table' then return nil,'unknown-rotation' end
    local ready,why=ensure(self);if not ready then return nil,why end
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec]~=nil and not plainTable(active.state[key][spec]) then return nil,'invalid-library-state' end
    end
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        self.currentRotation=nil;self.manualRotation=false
    end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
        new = [====[local addon_name, addon = ...
local data = addon.RotationData
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local retireActive=addon.RetireActiveRotationTransition
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local definitions, definitionVersion = {}, 0
local active
local readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable
local bindValidation=addon.BindRotationValidationReader
if type(bindValidation)=='function' then
    bindValidation(addon,function(read,check,raw,identity,kind,meta)
        if type(read)=='function' and type(check)=='function' and type(raw)=='function'
            and type(identity)=='function' and type(kind)=='function' and type(meta)=='function' then
            readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable=read,check,raw,identity,kind,meta
        end
    end)
    addon.BindRotationValidationReader=nil
end
local function validationPlain(value)
    return validationType(value)=='table' and validationGetmetatable(value)==nil
end

local function contains(list, value)
    for _,entry in ipairs(list or {}) do if entry==value then return true end end
    return false
end
local function matchesClass(view,context)
    local scope=view.applicability
    return not scope or not scope.class or scope.class==context.class
end
local function eligible(view, context, candidates)
    if not view.enabled then return false,"disabled" end
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then return false,"invalid-or-unsupported" end
    if not matchesClass(view,context) then return false,"class-mismatch" end
    if candidates then return true end
    local scope=view.applicability
    if not scope or not contains(scope.families,context.family) then return false,"edition-mismatch" end
    if scope.specs and not contains(scope.specs,context.spec) then return false,"specialization-mismatch" end
    if scope.actionContext~=context.actionContext then return false,"action-context-mismatch" end
    for _,range in ipairs({{"minLevel","maxLevel","level"},{"minBuild","maxBuild","build"}}) do
        local value=context[range[3]]
        if scope[range[1]] or scope[range[2]] then
            if type(value)~="number" then return false,"missing-"..range[3] end
            if scope[range[1]] and value<scope[range[1]] or scope[range[2]] and value>scope[range[2]] then return false,range[3].."-mismatch" end
        end
    end
    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.rulesets or scope.intent or scope.roles then return false,"unsupported-context-selector" end
    if context.combatDataPolicy~="probe" then return false,"restricted-or-unsupported-client" end
    return true
end
local function plainTable(value)
    return type(value)=="table" and getmetatable(value)==nil
end

function addon:RegisterDefaultRotation(envelope)
    local copy,why=data.CopyData(envelope)
    if not copy then return false,why.code end
    if copy.format~="RotationMaster" or copy.schemaVersion~=1 or not data.ValidateEnvelope(copy).valid then return false,"invalid-envelope" end
    if not copy.applicability.class and copy.applicability.universal~=true then return false,"missing-class-scope" end
    if definitions[copy.id] then return false,"duplicate-default-id" end
    definitions[copy.id]=copy;definitionVersion=definitionVersion+1
    return true
end

function addon:InitializeRotationLibrary()
    local profile=self.db.profile
    local validation,referenceStamp=self:GetRotationValidationOptions()
    local state=profile.rotationLibrary
    if state==nil then state={};profile.rotationLibrary=state end
    if not plainTable(state) then active=nil;return false,"invalid-library-state" end
    for _,key in ipairs({"preferences","origins","comparisons","imports"}) do
        if state[key]~=nil and not plainTable(state[key]) then active=nil;return false,"invalid-library-state" end
    end
    state.preferences,state.origins,state.comparisons,state.imports=state.preferences or {},state.origins or {},state.comparisons or {},state.imports or {}
    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog,why=data.NewCatalog({state={preferences=state.preferences},
        validation=validation,newId=self.uuid})
    if not catalog then active=nil;return false,why end
    local views,bodies={},{}
    for id,envelope in pairs(definitions) do
        local ok,reason=catalog:RegisterBuiltin(envelope)
        if not ok then active=nil;return false,reason end
        views[id]=catalog:Get({kind="builtin",id=id})
        bodies[id]=data.CopyData(views[id].envelope.body)
        bodies[id].name=L[views[id].nameKey]
    end
    active={profile=profile,state=state,catalog=catalog,views=views,bodies=bodies,cloneScopes={},version=definitionVersion,referenceStamp=referenceStamp,generation={}}
    for spec,origins in pairs(state.origins) do
        if type(spec)=="number" and plainTable(origins) then
            active.cloneScopes[spec]={}
            for id in pairs(origins) do
                local view=self:GetSourcedRotationView(spec,id)
                if view then
                    view.validation=data.ValidateEnvelope(view.envelope,validation)
                    view.enabled=true
                end
                active.cloneScopes[spec][id]=view or false
            end
        end
    end
    return true
end
local ownedInitializeRotationLibrary=addon.InitializeRotationLibrary
local function ensure(self,needProof)
    local referenceStamp,method,db,profile,global,conditions,shared,personal,effects,version,state
    local plainStamps=false
    if needProof and readValidationStamp then
        local entryMethod=validationType(self)=='table' and validationRawget(self,'GetRotationValidationStamp') or nil
        method=self.GetRotationValidationStamp
        referenceStamp,db,profile,global,conditions,shared,personal,effects,version,state=readValidationStamp(self,method,entryMethod)
        plainStamps=db~=nil and validationPlain(referenceStamp) and active~=nil
            and validationPlain(active.referenceStamp) and validationPlain(active.generation)
    else referenceStamp=self:GetRotationValidationStamp() end
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then local ok,why=self:InitializeRotationLibrary();return ok,why end
        return self:InitializeRotationLibrary()
    end
    -- An initializer call never issues proof, even if it returns the same generation.
    if plainStamps and validationRawequal(validationRawget(self,'InitializeRotationLibrary'),ownedInitializeRotationLibrary)
        and checkValidationLayout(self,method,db,profile,global,conditions,shared,personal,effects,version,state) then
        return true,nil,referenceStamp,true
    end
    return true
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context=self.Platform:GetClientInfo()
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and self.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local ownedRotationContext=addon.GetRotationContext
local clientContextReader
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local function runtimeKey(id, custom)
    local key="RM-BUILTIN:"..id
    while custom[key]~=nil do key=":"..key end
    return key
end
-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind)~='function' then return nil,'invalid-library-reader-binder' end
    local owner=self;local reader={}
    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    function reader:Context(spec) return rotationContext(owner,spec) end
    local function generationMethod(self)
        local ok,why,checked,proof=ensure(owner,true);if not ok then return nil,why end
        return active.generation,nil,checked,proof
    end
    reader.Generation=generationMethod
    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method,reference,generation)
        return validationRawget~=nil and validationPlain(reader) and validationPlain(reference) and validationPlain(generation)
            and validationRawequal(validationRawget(reader,'Generation'),generationMethod)
            and (method==nil or validationRawequal(method,generationMethod))
    end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local view=active.views[id];if not view then return nil,'unknown-rotation' end
        local context=rotationContext(owner,spec);context.spec=spec
        if not matchesClass(view,context) then return nil,'class-mismatch' end
        local allowed,reason=eligible(view,context,candidates)
        return true,project(view,active.bodies[id],allowed,reason),active.generation
    end
    function reader:List(spec,project)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
        for id,view in pairs(active.views) do if matchesClass(view,context) then rows[#rows+1]=project(id,view,active.bodies[id]) end end
        return rows,active.generation
    end
    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration);return true
end

function addon:ListDefaultRotations(spec)
    local ok,why=ensure(self)
    if not ok then return {},why end
    local context=self:GetRotationContext(spec);context.spec=spec
    local custom=(self.db.profile.rotations or {})[spec] or {}
    local rows={}
    for id,view in pairs(active.views) do
        if matchesClass(view,context) then
            local row=data.CopyData(view)
            local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey=scoped and scoped:Key({kind='builtin',id=id}) or runtimeKey(id,custom)
            row.eligible,row.eligibilityReason=eligible(view,context)
            row.name=L[row.nameKey or id]
            row.description=L[row.descriptionKey or ""]
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function addon:GetDefaultRotation(id)
    if not ensure(self) then return nil end
    return active.catalog:Get({kind="builtin",id=id})
end
function addon:SetDefaultRotationEnabled(id,value)
    local change=beginActive(self)
    local ok,why=ensure(self);if not ok then return false,why end
    local selected=self.currentRotation and self:GetDefaultIdForRuntime(self.currentSpec,self.currentRotation)==id
    if not activeCurrent(self,change) then return false,'rotation-transition-superseded' end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
    if saved and not value and selected and activeCurrent(self,change) then
        local disable=self.DisableRotation
        if not activeCurrent(self,change) then return saved,reason end
        if type(disable)=='function' then
            local _,nextChange,stopped=disable(self)
            if stopped~=false and activeCurrent(self,nextChange or change) then self.manualRotation=false end
        elseif retireActive(self,change) and activeCurrent(self,change) then self.manualRotation=false end
    end
    return saved,reason
end
function addon:GetEditableRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:GetEditableRotation(spec,id) end
    local rotations=self.db.profile.rotations[spec]
    return rotations and rotations[id]
end
function addon:OwnsRotationCondition(spec,id,step,condition)
    local body=self:GetEditableRotation(spec,id)
    local tree=body and data.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return false end
    for _,row in ipairs(tree.rows) do if row.step==step and step.conditions==condition then return true end end
    return false
end
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then local pass,why=scoped:RuntimePass(spec);if not pass then return {},why end;local rows,reason=pass:Candidates(candidates==true);for key,body in pairs(rows) do local ref=scoped:Resolve(spec,key);if ref and ref.kind=='custom' then rows[key]=scoped:GetEditableRotation(spec,key) else rows[key]=data.CopyData(body) end end;return rows,reason end
    local rotations={}
    if spec==nil then return rotations end
    local ready=ensure(self)
    local context=self:GetRotationContext(spec);context.spec=spec
    -- Editing/export use the saved-data facade independently. Legacy bodies
    -- must obey the same client execution policy as packaged/scoped rotations.
    if context.combatDataPolicy~="probe" then return rotations end
    local origins=ready and active.state.origins[spec]
    local scopes=ready and active.cloneScopes[spec]
    for id,body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped=scopes and scopes[id]
        local imported,importError
        if self.GetImportedRotationView then imported,importError=self:GetImportedRotationView(spec,id) end
        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body=body
            scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
            scoped.applicability=scoped.envelope.applicability
        end
        if not origins or plainTable(origins) and origins[id]==nil
            or scoped and eligible(scoped,context,candidates) then
            if (not self.GetImportedRotationView or importError=="not-imported" or imported and eligible(imported,context,candidates))
                and not self:HasDisabledRotationDependency(body) then rotations[id]=body end
        end
    end
    if not ready then return rotations end
    for id,view in pairs(active.views) do
        if eligible(view,context,candidates) then
            local body=internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id,rotations)]=body
        end
    end
    return rotations
end
function addon:GetRuntimeRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local pass,why=scoped:RuntimePass(spec);if not pass then return nil,why end
        local body,bodyReason=pass:Get(id);if not body then return nil,bodyReason end
        local reference=scoped:Resolve(spec,id);if reference.kind=='custom' then return scoped:GetEditableRotation(spec,reference) end
        return data.CopyData(body)
    end
    return self:GetRuntimeRotations(spec,true)[id]
end
function addon:CloneDefaultRotation(spec,id,name,options)
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if coordinator then return coordinator:Copy(spec,{kind='builtin',id=id},name,options) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local rotations=self.db.profile.rotations[spec] or {}
    if rotations[generated]~=nil then return nil,"id-collision" end
    local view=temporary:Get({kind="custom",id=generated})
    local manifest=view.envelope;local body=manifest.body;manifest.body=nil
    if manifest.applicability.universal then
        manifest.applicability.universal=nil;manifest.applicability.class=context.class
    end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    origins=origins or {}
    if origins[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec]=rotations;rotations[generated]=body
    active.state.origins[spec]=origins;origins[generated]={manifest=manifest,lineage=view.lineage}
    local scoped=self:GetSourcedRotationView(spec,generated)
    scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
    scoped.enabled=true
    active.cloneScopes[spec]=active.cloneScopes[spec] or {};active.cloneScopes[spec][generated]=scoped
    return generated
end
function addon:GetSourcedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,false) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins==nil then return nil,"no-source-baseline" end
    if not plainTable(origins) then return nil,"invalid-origin-state" end
    if origins[id]==nil then return nil,"no-source-baseline" end
    local origin,problem=data.CopyData(origins[id])
    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id~=id then return nil,"invalid-origin-state" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local envelope=data.CopyData(origin.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-custom-body" end
    -- Catalog validates both current structure and retained historical lineage.
    local state={custom={[id]=envelope},lineage={[id]=origin.lineage}}
    local catalog,reason=data.NewCatalog({state=state})
    if not catalog then return nil,reason end
    local view=catalog:Get({kind="custom",id=id})
    if view.lineageError then return nil,"invalid-origin-state" end
    return view
end

function addon:IsDefaultRuntimeRotation(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return self:GetDefaultIdForRuntime(spec,key)~=nil end
    if not ensure(self) then return false end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return true end end
    return false
end

function addon:GetDefaultIdForRuntime(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then local ref=scoped:Resolve(spec,key);return ref and ref.kind=='builtin' and ref.id or nil end
    if not ensure(self) then return nil end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return id end end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec,true,true)
end
function addon:GetRotationForCleanup(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Cleanup(spec,key) end
    local custom=self:GetEditableRotation(spec,key)
    if custom then return custom end
    if not ensure(self) then return nil end
    local saved=self.db.profile.rotations[spec] or {}
    for id,body in pairs(active.bodies) do if runtimeKey(id,saved)==key then return body end end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:ComparisonIdentity(spec,id) end
    if not ensure(self) then return nil,"invalid-library-state" end
    local rows=active.state.comparisons[spec]
    if rows~=nil and not plainTable(rows) then return nil,"invalid-comparison-origin" end
    local identity
    if rows and rows[id]~=nil then
        local why
        identity,why=data.CopyData(rows[id])
        if why or not plainTable(identity) or (identity.kind~="custom" and identity.kind~="builtin")
            or type(identity.id)~="string" or not plainTable(identity.origins) then return nil,"invalid-comparison-origin" end
    end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if view then
        if identity and (identity.kind~=view.lineage.sourceKind or identity.id~=view.lineage.sourceId) then return nil,"invalid-comparison-origin" end
        identity=identity or {kind=view.lineage.sourceKind,id=view.lineage.sourceId,origins={}}
        for key,origin in pairs(view.lineage.stepOrigins) do identity.origins[key]=origin end
        return identity
    end
    if self.GetImportedRotationView then
        local imported,why=self:GetImportedRotationView(spec,id)
        if imported then return {kind="import",id=imported.sourceId,origins=imported.stepOrigins}
        elseif why~="not-imported" then return nil,why end
    end
    return identity or {kind="custom",id=id}
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec,id,name,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Copy(spec,id,name,options) end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            local revision,problem=data.GetRotationContentRevision(prepared.body);if not revision then return nil,problem end
            prepared.manifest.body=nil;prepared.body.revision=1
            if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    local revision,revisionError=data.GetRotationContentRevision(body);if not revision then return nil,revisionError end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local ok,why=ensure(self);if not ok then return nil,why end
    if library==nil then library=profile.rotationLibrary end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    local sourceView
    if origins and origins[id]~=nil then
        sourceView,why=self:GetSourcedRotationView(spec,id)
        if not sourceView then return nil,why end
    end
    local identity,identityError=self:GetRotationComparisonIdentity(spec,id)
    if not identity then return nil,identityError end
    local correspondence={kind=identity.kind,id=identity.id,origins={}}
    local comparisonRows=active.state.comparisons[spec]
    if comparisonRows~=nil and not plainTable(comparisonRows) then return nil,"invalid-comparison-origin" end
    local used={}
    for _,rotations in pairs(self.db.profile.rotations) do
        if type(rotations)=="table" then
            for key,rotation in pairs(rotations) do
                used[key]=true
                data.ReserveRotationIdentities(rotation,used)
            end
        end
    end
    local function reserve(value) if type(value)=="string" then used[value]=true end end
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope,used)
    end
    for _,envelope in pairs(definitions) do reserveEnvelope(envelope) end
    for _,rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local entry=data.CopyData(raw)
                local retained=type(entry)=="table" and entry.lineage
                if type(retained)=="table" then
                    reserve(retained.sourceId);reserve(retained.clonedFrom)
                    if type(retained.baseline)=="table" then reserveEnvelope(retained.baseline) end
                    if type(retained.stepOrigins)=="table" then for step,origin in pairs(retained.stepOrigins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    for _,rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local retained=data.CopyData(raw)
                if type(retained)=="table" then
                    reserve(retained.id)
                    if type(retained.origins)=="table" then for step,origin in pairs(retained.origins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    local function fresh()
        local generatedOk,value=pcall(self.uuid)
        if not generatedOk or type(value)~="string" or #value>128 or not value:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[value] or definitions[value] then return nil,"id-collision" end
        used[value]=true;return value
    end
    local generated,reason=fresh();if not generated then return nil,reason end
    local lineage=sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins=lineage and lineage.stepOrigins
    if lineage then lineage.clonedFrom=id;lineage.stepOrigins={} end
    local indexed,indexError=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not indexed then return nil,indexError.code end
    for _,row in ipairs(indexed.rows) do
        local entry=row.step
        local stepId,errorCode=fresh();if not stepId then return nil,errorCode end
        if lineage then lineage.stepOrigins[stepId]=previousOrigins[entry.id] end
        correspondence.origins[stepId]=identity.origins and identity.origins[entry.id] or entry.id
        entry.id=stepId
    end
    body.name=name;body.revision=1
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    self.db.profile.rotations[spec][generated]=body
    if metadata then origins[generated]=metadata end
    comparisonRows=comparisonRows or {};active.state.comparisons[spec]=comparisonRows
    comparisonRows[generated]=correspondence
    self:InitializeRotationLibrary()
    return generated
end

function addon:BuildRotationComparison(spec,id,target)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if not target then return nil,'missing-comparison-target' end
        local targetReference
        if type(target)=='table' and target.kind=='custom' and not target.address then targetReference,why=scoped:Resolve(spec,target.id)
        else targetReference,why=scoped:Resolve(spec,target) end
        if not targetReference then return nil,why end
        local function sameAddress(a,b)
            if a.kind~=b.kind then return false end;if a.kind=='builtin' then return a.id==b.id end
            for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end;return true
        end
        if sameAddress(reference,targetReference) then return nil,'self-comparison' end
        local current,currentReason=scoped:Snapshot(spec,reference);if not current then return nil,currentReason end
        local other,targetReason=scoped:Snapshot(spec,targetReference);if not other then return nil,targetReason end
        local view=scoped:SourceView(spec,reference,false)
        if view and targetReference.kind=='builtin' and view.lineage.sourceKind=='builtin' and view.lineage.sourceId==targetReference.id then
            local source=other.source;local result=data.CompareClone(view,source)
            result.views={{key='current',left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key='source',left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key='custom',left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges}}
            return result
        end
        local left,leftError=scoped:ComparisonIdentity(spec,targetReference);local right,rightError=scoped:ComparisonIdentity(spec,reference)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        local exact=left.kind=='builtin' or left.kind=='import' or left.kind=='custom' and left.sourceAddress and right.sourceAddress and sameAddress({kind='custom',address=left.sourceAddress},{kind='custom',address=right.sourceAddress})
        if exact and left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other.body,self:GetRotationTags(spec,targetReference))
        local rightValue=data.RotationComparisonValue(current.body,self:GetRotationTags(spec,reference))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key='current',left=leftValue,right=rightValue,leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    if target and target.kind=="custom" and target.id==id then return nil,"self-comparison" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if target and target.kind=="builtin" then
        local source=self:GetDefaultRotation(target.id)
        if not source then return nil,"unknown-rotation" end
        if view and view.lineage.sourceKind=="builtin" and view.lineage.sourceId==target.id then
            local result=data.CompareClone(view,source)
            result.views={
                {key="current",left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key="source",left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key="custom",left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges},
            }
            return result
        end
        local leftValue=data.RotationComparisonValue(source.envelope.body,source.envelope.tags)
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue)
        leftValue.nameKey=source.envelope.nameKey
        result.views={{key="current",left=leftValue,right=rightValue,diff=data.CopyData(result)}}
        return result
    elseif target and target.kind=="custom" then
        local other=self:GetEditableRotation(spec,target.id)
        if not other then return nil,"unknown-rotation" end
        local left,leftError=self:GetRotationComparisonIdentity(spec,target.id)
        local right,rightError=self:GetRotationComparisonIdentity(spec,id)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        if left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other,self:GetRotationTags(spec,target.id))
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key="current",left=leftValue,right=rightValue,
            leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    return nil,"missing-comparison-target"
end

function addon:DeleteCustomRotation(spec,id,expected)
    local change=beginActive(self)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent and activeCurrent(self,change) then
            if retireActive(self,change) and activeCurrent(self,change) then
                self.manualRotation=false
                local available=self.RemoveAllCurrentGlows
                if available and activeCurrent(self,change) then
                    local remove=self.RemoveAllCurrentGlows
                    if activeCurrent(self,change) then remove(self) end
                end
            end
        end
        return true
    end
    if id==(DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec,id) then return nil,'read-only-rotation' end
    local body=self:GetEditableRotation(spec,id)
    if type(body)~='table' then return nil,'unknown-rotation' end
    local ready,why=ensure(self);if not ready then return nil,why end
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec]~=nil and not plainTable(active.state[key][spec]) then return nil,'invalid-library-state' end
    end
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) and activeCurrent(self,change) then
        if retireActive(self,change) and activeCurrent(self,change) then
            self.manualRotation=false
            local available=self.RemoveAllCurrentGlows
            if available and activeCurrent(self,change) then
                local remove=self.RemoveAllCurrentGlows
                if activeCurrent(self,change) then remove(self) end
            end
        end
    end
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
    },
    ['Core/rotation_scope.lua'] = {
        old = [====[local addon_name,addon=...
local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
function addon:BindRotationProfile()
    if current then current:Retire() end
    local owner=self;local profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else store,problem=data.NewRotationStore({state=state,fallbackID=profile.rotationFallbackID,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end}) end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope,revisionPolicy)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if revisionPolicy~=nil and revisionPolicy~='import' then return nil,'invalid-rotation-revision-policy' end
        if not plain(record) then return nil,'invalid-record' end
        if token and (not issued or not same(issued.reference,reference) or not same(issued.context,c)) then return nil,'stale-rotation-record' end
        local moved=a.scope~=destination.scope or a.owner~=destination.owner
        local previous
        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot,snapshotProblem=store:Get(a,c)
            if not snapshot then return nil,snapshotProblem end
            previous=snapshot.body
            if plain(previous) and plain(record.body) then
                if previous.rotation==nil and record.body.rotation~=nil then previous.rotation={} end
                if previous.cooldowns==nil and record.body.cooldowns~=nil then previous.cooldowns={} end
            end
        end
        local body,problem=data.PrepareRotationContentRevision(record.body,previous,
            token and 'edit' or revisionPolicy=='import' and 'import' or 'create',moved or revisionPolicy=='import')
        if not body then return nil,problem end
        local detached=copy(record);if not detached then return nil,'invalid-record' end
        record=detached;record.body=body
        local now,contextProblem=context()
        local current,currentProblem=ready();if not current then return nil,currentProblem end
        if not now then return nil,contextProblem end
        if not same(now,c) then return nil,'rotation-owner-changed' end
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if token then expected[token]=nil end
        local target={kind='custom',address=destination};local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        keyFor(target);return target
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil;return true
    end
    function coordinator:Cleanup(number,value)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then return assets[referenceKey(reference)].body end
        local pass=self:RuntimePass(number);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        local reference={kind='custom',address=copy(adoption.target)}
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference);return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason=self:Commit(reference,token,record,scope,'import');if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposed[record.body]=true;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local function eligibilityContext()
            local value=rotationContext(owner,number);local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        return pass
    end
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
        new = [====[local addon_name,addon=...
local data=addon.RotationData
local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local protect,raise=pcall,error
local preparedBinding,bindGeneration
local bindIdentity=rawequal
if type(addon.BindActiveRotationPublication)=='function' then
    addon:BindActiveRotationPublication(function(prepare,finish,rebind,complete)
        prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind=prepare,finish,rebind,complete
    end)
end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
local function rebindContext()
    if not prepareActiveRebind then return nil end
    local ticket,reference,token,spec,id=prepareActiveRebind(DEFAULT)
    if not token then return nil end
    return {ticket=ticket,reference=reference,token=token,spec=spec,id=id}
end
local function completeRebind(binding,coordinator,problem)
    if not binding or not binding.ticket or not activeCurrent(addon,binding.token) then return end
    local function read(object,name,...)
        if not activeCurrent(addon,binding.token) then return nil end
        local method=object[name]
        if not activeCurrent(addon,binding.token) then return nil end
        local value=method(object,...)
        if not activeCurrent(addon,binding.token) then return nil end
        return value
    end
    local function resolve()
        if problem then return nil end
        local key=binding.id
        if key~=DEFAULT then
            if not binding.reference then return nil end
            local reference=read(coordinator,'Resolve',binding.spec,binding.reference)
            if not reference then return nil end
            key=read(coordinator,'Key',reference)
        end
        if not key then return nil end
        local reference=read(coordinator,'Resolve',binding.spec,key)
        local pass=reference and read(coordinator,'RuntimePass',binding.spec)
        local body=pass and read(pass,'Get',key)
        return key,reference,body
    end
    local ok,key,reference,body=protect(resolve)
    if not activeCurrent(addon,binding.token) then return end
    local handle,token=finishActiveRebind(binding.ticket,ok and key or nil,ok and reference or nil,ok and body or nil)
    if not handle and token and activeCurrent(addon,token) then addon.manualRotation=false end
end
local function runPreparedBind(owner,binding,method)
    local previous=preparedBinding;preparedBinding=binding
    local ok,result,reason=protect(method,owner)
    if preparedBinding==binding then preparedBinding=previous end
    if not ok then raise(result,0) end
    return result,reason
end
function addon:BindActiveRotationProfileRebind(receiver)
    if self~=addon or type(receiver)~='function' then return nil end
    receiver(rebindContext,runPreparedBind)
    return true
end
function addon:BindRotationProfile()
    local bindToken={};bindGeneration=bindToken
    local binding,profile
    local function bindingCurrent()
        if bindGeneration~=bindToken or binding and not activeCurrent(self,binding.token) then return false end
        if profile then local db=self.db;if not bindIdentity(db and db.profile,profile) then return false end end
        return bindGeneration==bindToken
    end
    if self==addon then
        binding=preparedBinding or rebindContext()
        if binding then
            if binding.used or not bindingCurrent() then return nil,'rotation-transition-superseded' end
            binding.used=true
        end
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local previous=current
    if previous then
        local retire=previous.Retire
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        retire(previous)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    end
    local owner=self;profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else
        local construct=data.NewRotationStore
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local getOptions=self.GetRotationValidationOptions
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local validation=getOptions(self)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        store,problem=construct({state=state,fallbackID=profile.rotationFallbackID,validation=validation,bindInternalReader=function(value) reader=value end})
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope,revisionPolicy)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if revisionPolicy~=nil and revisionPolicy~='import' then return nil,'invalid-rotation-revision-policy' end
        if not plain(record) then return nil,'invalid-record' end
        if token and (not issued or not same(issued.reference,reference) or not same(issued.context,c)) then return nil,'stale-rotation-record' end
        local previousKey=byReference[referenceKey(reference)]
        local moved=a.scope~=destination.scope or a.owner~=destination.owner
        local previous
        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot,snapshotProblem=store:Get(a,c)
            if not snapshot then return nil,snapshotProblem end
            previous=snapshot.body
            if plain(previous) and plain(record.body) then
                if previous.rotation==nil and record.body.rotation~=nil then previous.rotation={} end
                if previous.cooldowns==nil and record.body.cooldowns~=nil then previous.cooldowns={} end
            end
        end
        local body,problem=data.PrepareRotationContentRevision(record.body,previous,
            token and 'edit' or revisionPolicy=='import' and 'import' or 'create',moved or revisionPolicy=='import')
        if not body then return nil,problem end
        local detached=copy(record);if not detached then return nil,'invalid-record' end
        record=detached;record.body=body
        local target={kind='custom',address=destination}
        local fallbackKey=destination.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(a.spec,previousKey,reference,target,body,nil,fallbackKey)
        local now,contextProblem=context()
        local current,currentProblem=ready();if not current then return nil,currentProblem end
        if not now then return nil,contextProblem end
        if not same(now,c) then return nil,'rotation-owner-changed' end
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if token then expected[token]=nil end
        local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        local nextKey=keyFor(target)
        local transition
        if finishActivePublication then local _,change=finishActivePublication(publication,nextKey);transition=change end
        return target,nil,transition
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil;return true
    end
    function coordinator:Cleanup(number,value)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then return assets[referenceKey(reference)].body end
        local pass=self:RuntimePass(number);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local reference={kind='custom',address=copy(adoption.target)}
        local rows=profile.rotationStore.legacy.rotations[adoption.target.spec]
        local body=rows and rows[adoption.target.id]
        local fallbackKey=adoption.target.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(adoption.target.spec,nil,reference,reference,body,nil,fallbackKey)
        local current,currentReason=ready();if not current then return nil,currentReason end
        local now,ownerReason=context();if not now or not same(now,c) then return nil,ownerReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference)
        if finishActivePublication then finishActivePublication(publication) end
        return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason,transition=self:Commit(reference,token,record,scope,'import');if not saved then return nil,commitReason end
        return id,nil,saved,transition
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposed[record.body]=true;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local function eligibilityContext()
            local value=rotationContext(owner,number);local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        return pass
    end
    completeRebind(binding,coordinator,problem)
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
    },
    ['Core/rotation_editor.lua'] = {
        old = [====[local _,addon=...
local data=addon.RotationData

local function equal(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    local function compare(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not compare(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return compare(left,right)
end
local function weight(value)
    if type(value)=='string' then return 32+#value end
    if type(value)~='table' then return 16 end
    local total=64;for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end;return total
end

function addon:NewRotationEditSession(spec,original,options)
    options=options or {}
    if type(options)~='table' or getmetatable(options)~=nil or
        options.targetValid~=nil and type(options.targetValid)~='function' or
        options.readOnly~=nil and type(options.readOnly)~='boolean' or
        options.newRecord~=nil and type(options.newRecord)~='boolean' or
        options.commit~=nil and type(options.commit)~='function' or
        options.ownership~=nil and options.ownership~='class' and options.ownership~='character' or
        options.setOwnershipAllowed~=nil and type(options.setOwnershipAllowed)~='boolean' then return nil,'invalid-rotation-editor-options' end
    local newId=options.newId or self.uuid
    local draft,why=data.NewRotationDraft(original,newId,options.reserved)
    if not draft then return nil,why end
    local baseline=data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline=data.CopyData(original)
    if dirtyBaseline.rotation==nil then dirtyBaseline.rotation={} end
    if dirtyBaseline.cooldowns==nil then dirtyBaseline.cooldowns={} end
    local ownership,originalOwnership=options.ownership,options.ownership
    local readOnly=options.readOnly==true
    local targetValid=options.targetValid
    local closed,busy=false,false
    local undo,redo,bytes={},{},0
    local function push(stack,value)
        local size=weight(value);stack[#stack+1]={value=value,bytes=size};bytes=bytes+size
    end
    local function pop(stack,at)
        local entry=table.remove(stack,at or #stack);if entry then bytes=bytes-entry.bytes end;return entry
    end
    local function trim()
        while #undo+#redo>100 or bytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function writable()
        if closed then return nil,'rotation-editor-closed' end
        if busy then return nil,'rotation-editor-busy' end
        if readOnly then return nil,'readonly-rotation' end
        return true
    end
    local function owner()
        if not targetValid then return true end
        local ok,valid=pcall(targetValid);return ok and valid==true
    end
    local function close() closed=true;undo={};redo={};bytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:Baseline() return data.CopyData(dirtyBaseline) end
    function session:Ownership() return ownership end
    function session:BaselineOwnership() return originalOwnership end
    function session:IsDirty() return ownership~=originalOwnership or not data.SameRotationContent(dirtyBaseline,draft:Snapshot()) end
    function session:HistoryState()
        return {canUndo=not closed and not busy and not readOnly and #undo>0,
            canRedo=not closed and not busy and not readOnly and #redo>0}
    end
    function session:Command(name,...)
        local ok,reason=writable();if not ok then return nil,reason end
        local before={body=draft:Snapshot(),ownership=ownership}
        local changed,result
        if name=='SetOwnership' then
            local scope=(...);if not options.setOwnershipAllowed or (scope~='class' and scope~='character') then return nil,'invalid-owner-scope' end
            changed=true;ownership=scope
        else changed,result=draft:Command(name,...) end
        if changed and (before.ownership~=ownership or not equal(before.body,draft:Snapshot())) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return changed,result
    end
    local function travel(source,destination)
        local ok,reason=writable();if not ok then return nil,reason end
        if #source==0 then return nil,'rotation-history-empty' end
        local previous={body=draft:Snapshot(),ownership=ownership}
        local frame=source[#source].value
        local restored,problem=draft:Restore(frame.body)
        if not restored then return nil,problem end
        ownership=frame.ownership
        pop(source);push(destination,previous);trim()
        return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel()
        if busy then return nil,'rotation-editor-busy' end
        close();return true
    end
    function session:Apply()
        local writableOk,reason=writable();if not writableOk then return nil,reason end
        busy=true
        local function finish(ok,problem,details) busy=false;return ok,problem,details end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        local snapshot=draft:Snapshot()
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions())
        if not validation.valid then return finish(nil,'invalid-rotation-data',validation) end
        if not validation.supported then return finish(nil,'unsupported-rotation-data',validation) end
        if not validation.resolved then return finish(nil,'unresolved-rotation-data',validation) end
        local candidate=data.CopyData(snapshot)
        local tree=data.IndexRotationSteps(candidate)
        local function validate()
            local valid=addon:validateCondition(candidate.switch or {},spec)
            for _,row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {},spec) then valid=false end
            end
            return valid
        end
        local ok,valid
        if addon.Diagnostics then ok,valid=addon.Diagnostics:Call({module='rotation-editor',operation='validate',customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return finish(nil,'rotation-validation-error') end
        if not equal(snapshot,candidate) then return finish(nil,'validation-mutated-rotation') end
        if not valid then return finish(nil,'invalid-condition-fields') end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        if options.commit then
            local success,committed,problem,details=pcall(options.commit,snapshot,ownership)
            if not success then return finish(nil,'rotation-commit-error') end
            if not committed then return finish(nil,problem,details) end
            close();return finish(true,nil,problem)
        end
        local previous
        if not options.newRecord then
            previous=data.CopyData(original)
            if not previous then return finish(nil,'invalid-rotation-data') end
            if previous.rotation==nil then previous.rotation={} end
            if previous.cooldowns==nil then previous.cooldowns={} end
        end
        local saved,problem=data.PrepareRotationContentRevision(snapshot,previous,options.newRecord and 'create' or 'edit',ownership~=originalOwnership)
        if not saved then return finish(nil,problem) end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(saved) do original[key]=value end
        close();return finish(true)
    end
    return session
end
]====],
        new = [====[local _,addon=...
local data=addon.RotationData
local prepareActivePublication,finishActivePublication
if type(addon.BindActiveRotationPublication)=='function' then
    addon:BindActiveRotationPublication(function(prepare,finish)
        prepareActivePublication,finishActivePublication=prepare,finish
    end)
end

local function equal(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    local function compare(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not compare(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return compare(left,right)
end
local function weight(value)
    if type(value)=='string' then return 32+#value end
    if type(value)~='table' then return 16 end
    local total=64;for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end;return total
end

function addon:NewRotationEditSession(spec,original,options)
    options=options or {}
    if type(options)~='table' or getmetatable(options)~=nil or
        options.targetValid~=nil and type(options.targetValid)~='function' or
        options.readOnly~=nil and type(options.readOnly)~='boolean' or
        options.newRecord~=nil and type(options.newRecord)~='boolean' or
        options.commit~=nil and type(options.commit)~='function' or
        options.ownership~=nil and options.ownership~='class' and options.ownership~='character' or
        options.setOwnershipAllowed~=nil and type(options.setOwnershipAllowed)~='boolean' then return nil,'invalid-rotation-editor-options' end
    local newId=options.newId or self.uuid
    local draft,why=data.NewRotationDraft(original,newId,options.reserved)
    if not draft then return nil,why end
    local baseline=data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline=data.CopyData(original)
    if dirtyBaseline.rotation==nil then dirtyBaseline.rotation={} end
    if dirtyBaseline.cooldowns==nil then dirtyBaseline.cooldowns={} end
    local ownership,originalOwnership=options.ownership,options.ownership
    local readOnly=options.readOnly==true
    local targetValid=options.targetValid
    local closed,busy=false,false
    local undo,redo,bytes={},{},0
    local function push(stack,value)
        local size=weight(value);stack[#stack+1]={value=value,bytes=size};bytes=bytes+size
    end
    local function pop(stack,at)
        local entry=table.remove(stack,at or #stack);if entry then bytes=bytes-entry.bytes end;return entry
    end
    local function trim()
        while #undo+#redo>100 or bytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function writable()
        if closed then return nil,'rotation-editor-closed' end
        if busy then return nil,'rotation-editor-busy' end
        if readOnly then return nil,'readonly-rotation' end
        return true
    end
    local function owner()
        if not targetValid then return true end
        local ok,valid=pcall(targetValid);return ok and valid==true
    end
    local function close() closed=true;undo={};redo={};bytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:Baseline() return data.CopyData(dirtyBaseline) end
    function session:Ownership() return ownership end
    function session:BaselineOwnership() return originalOwnership end
    function session:IsDirty() return ownership~=originalOwnership or not data.SameRotationContent(dirtyBaseline,draft:Snapshot()) end
    function session:HistoryState()
        return {canUndo=not closed and not busy and not readOnly and #undo>0,
            canRedo=not closed and not busy and not readOnly and #redo>0}
    end
    function session:Command(name,...)
        local ok,reason=writable();if not ok then return nil,reason end
        local before={body=draft:Snapshot(),ownership=ownership}
        local changed,result
        if name=='SetOwnership' then
            local scope=(...);if not options.setOwnershipAllowed or (scope~='class' and scope~='character') then return nil,'invalid-owner-scope' end
            changed=true;ownership=scope
        else changed,result=draft:Command(name,...) end
        if changed and (before.ownership~=ownership or not equal(before.body,draft:Snapshot())) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return changed,result
    end
    local function travel(source,destination)
        local ok,reason=writable();if not ok then return nil,reason end
        if #source==0 then return nil,'rotation-history-empty' end
        local previous={body=draft:Snapshot(),ownership=ownership}
        local frame=source[#source].value
        local restored,problem=draft:Restore(frame.body)
        if not restored then return nil,problem end
        ownership=frame.ownership
        pop(source);push(destination,previous);trim()
        return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel()
        if busy then return nil,'rotation-editor-busy' end
        close();return true
    end
    function session:Apply()
        local writableOk,reason=writable();if not writableOk then return nil,reason end
        busy=true
        local function finish(ok,problem,details) busy=false;return ok,problem,details end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        local snapshot=draft:Snapshot()
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions())
        if not validation.valid then return finish(nil,'invalid-rotation-data',validation) end
        if not validation.supported then return finish(nil,'unsupported-rotation-data',validation) end
        if not validation.resolved then return finish(nil,'unresolved-rotation-data',validation) end
        local candidate=data.CopyData(snapshot)
        local tree=data.IndexRotationSteps(candidate)
        local function validate()
            local valid=addon:validateCondition(candidate.switch or {},spec)
            for _,row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {},spec) then valid=false end
            end
            return valid
        end
        local ok,valid
        if addon.Diagnostics then ok,valid=addon.Diagnostics:Call({module='rotation-editor',operation='validate',customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return finish(nil,'rotation-validation-error') end
        if not equal(snapshot,candidate) then return finish(nil,'validation-mutated-rotation') end
        if not valid then return finish(nil,'invalid-condition-fields') end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        if options.commit then
            local success,committed,problem,details=pcall(options.commit,snapshot,ownership)
            if not success then return finish(nil,'rotation-commit-error') end
            if not committed then return finish(nil,problem,details) end
            close();return finish(true,nil,problem)
        end
        local previous
        if not options.newRecord then
            previous=data.CopyData(original)
            if not previous then return finish(nil,'invalid-rotation-data') end
            if previous.rotation==nil then previous.rotation={} end
            if previous.cooldowns==nil then previous.cooldowns={} end
        end
        local saved,problem=data.PrepareRotationContentRevision(snapshot,previous,options.newRecord and 'create' or 'edit',ownership~=originalOwnership)
        if not saved then return finish(nil,problem) end
        local publication=prepareActivePublication and prepareActivePublication(spec,nil,nil,nil,saved,original)
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(saved) do original[key]=value end
        if finishActivePublication then finishActivePublication(publication) end
        close();return finish(true)
    end
    return session
end
]====],
    },
    ['Core/imports.lua'] = {
        old = [====[local _,addon=...
local data=addon.RotationData
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
local function settings(self)
    local options=self:GetRotationValidationOptions();return options
end
function addon:GetImportValidationOptions() return settings(self) end
function addon:GetImportedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,true) end
    local state=self.db.profile.rotationLibrary
    if state==nil then return nil,"not-imported" end
    if not plain(state) then return nil,"invalid-import-state" end
    if state.imports==nil then return nil,"not-imported" end
    if not plain(state.imports) then return nil,"invalid-import-state" end
    local rows=state.imports[spec]
    if rows==nil then return nil,"not-imported" end
    if not plain(rows) then return nil,"invalid-import-state" end
    if rows[id]==nil then return nil,"not-imported" end
    local record,why=data.CopyData(rows[id])
    if why or not plain(record) or not plain(record.manifest) or record.manifest.id~=id
        or type(record.sourceId)~="string" or not plain(record.stepOrigins) then return nil,"invalid-import-state" end
    local body=self:GetEditableRotation(spec,id)
    local envelope=data.CopyData(record.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-import-state" end
    return {envelope=envelope,applicability=envelope.applicability,enabled=true,
        validation=data.ValidateEnvelope(envelope,settings(self)),sourceId=record.sourceId,
        sourceRevision=record.sourceRevision,stepOrigins=record.stepOrigins}
end
function addon:CreateImportedRotation(prepared,spec,name,replacement,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Import(prepared,spec,name,replacement,options) end
    if type(spec)~="number" or spec<0 or spec%1~=0 then return nil,"invalid-specialization" end
    if type(name)~="string" or #name==0 or #name>256 then return nil,"invalid-name" end
    local profile=self.db.profile
    local rotationsRoot=profile.rotations
    if rotationsRoot~=nil and not plain(rotationsRoot) then return nil,"invalid-rotation-storage" end
    if rotationsRoot and rotationsRoot[spec]~=nil and not plain(rotationsRoot[spec]) then return nil,"invalid-rotation-storage" end
    local body,problem=data.CopyData(prepared.body)
    if problem or not plain(body) then return nil,"invalid-import" end
    local manifest=prepared.manifest and data.CopyData(prepared.manifest)
    if prepared.manifest and not manifest then return nil,"invalid-import" end
    local result
    if manifest then
        local envelope=data.CopyData(manifest);envelope.body=body
        result=data.ValidateEnvelope(envelope,settings(self))
    else result=data.ValidateBody(body,settings(self)) end
    if not result.valid or not result.supported or not result.resolved then return nil,"import-not-ready" end
    local ok,why=self:InitializeRotationLibrary();if not ok then return nil,why end
    local state=self.db.profile.rotationLibrary
    for _,kind in ipairs({"origins","comparisons","imports"}) do if state[kind][spec]~=nil and not plain(state[kind][spec]) then return nil,"invalid-import-state" end end
    local used={}
    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    local function reserve(value)
        if type(value)=="string" then used[value]=true
        elseif type(value)=="table" then for key,child in pairs(value) do reserve(key);reserve(child) end end
    end
    for _,rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id,rotation in pairs(rotations) do
                used[id]=true
                local copy=data.CopyData(rotation);if copy then reserve(copy) end
            end
        end
    end
    for _,kind in ipairs({"origins","comparisons","imports"}) do
        for _,rows in pairs(state[kind]) do
            if plain(rows) then for id,record in pairs(rows) do
                used[id]=true;local copy=data.CopyData(record);if copy then reserve(copy) end
            end end
        end
    end
    for _,row in ipairs(self:ListDefaultRotations(spec)) do reserve(row.envelope) end
    reserve(body);reserve(manifest)
    local function fresh()
        local success,id=pcall(self.uuid)
        if not success or type(id)~="string" or #id>128 or not id:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[id] then return nil,"id-collision" end
        used[id]=true;return id
    end
    local id,errorCode;if replacement then id=replacement.id else id,errorCode=fresh() end;if not id then return nil,errorCode end
    local sourceId=prepared.sourceId or manifest and manifest.id
    local sourceRevision=prepared.sourceRevision or manifest and manifest.revision
    local origins={}
    local tree,treeError=data.IndexRotationSteps(body)
    if not tree then return nil,treeError.code end
    for _,row in ipairs(tree.rows) do
        local step=row.step
        local stepId,reason=fresh();if not stepId then return nil,reason end
        origins[stepId]=prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id=stepId
    end
    body.name=name
    local previous=replacement and self:GetEditableRotation(spec,id) or nil
    local revised,revisionError=data.PrepareRotationContentRevision(body,previous,replacement and 'edit' or 'import',replacement~=nil)
    if not revised then return nil,revisionError end
    body=revised
    if manifest then manifest.id=id;manifest.revision=1;manifest.nameKey=name end
    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then return nil,'rotation-changed-externally' end
    if self.db.profile~=profile or profile.rotations~=rotationsRoot or profile.rotationLibrary~=state then return nil,'rotation-changed-externally' end
    local rotations=rotationsRoot and rotationsRoot[spec] or {}
    if replacement and rotations[id]~=previous then return nil,'rotation-changed-externally' end
    if not replacement and rotations[id]~=nil then return nil,'id-collision' end
    self.db.profile.rotations=rotationsRoot or {}
    self.db.profile.rotations[spec]=rotations;rotations[id]=body
    if replacement then
        for _,kind in ipairs({'origins','comparisons','imports'}) do if type(state[kind][spec])=='table' then state[kind][spec][id]=nil end end
    end
    if manifest then
        local rows=state.imports[spec] or {};state.imports[spec]=rows
        rows[id]={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
    end
    return id
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:ApplyRotationImport(session,token,spec,name,target,expected,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local prepared,why=session:GetReady(token);if not prepared then return nil,why end
        if not target then return self:CreateImportedRotation(prepared,spec,name,nil,options) end
        local reference,referenceReason=scoped:Resolve(spec,target);if not reference then return nil,referenceReason end
        if reference.kind~='custom' then return nil,'read-only-rotation' end
        if type(expected)~='table' or expected.profile~=self.db.profile then return nil,'rotation-changed-externally' end
        local workspace=self.GetRotationWorkspace and self:GetRotationWorkspace(spec,reference);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end
        local record,token=scoped:Snapshot(spec,reference);if not record then return nil,token end
        if expected.recordToken then
            if not equal(expected.reference,reference) then return nil,'rotation-changed-externally' end;token=expected.recordToken
        else
            local original=self:GetEditableRotation(spec,reference)
            if expected.target~=original or not data.CheckPortable(original) or not equal(original,expected.body) then return nil,'rotation-changed-externally' end
        end
        local id,commitReason,saved=self:CreateImportedRotation(prepared,spec,record.body.name or name,{profile=self.db.profile,reference=reference,recordToken=token},options)
        if not id then return nil,commitReason end
        if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
        return id,nil,saved
    end
    local prepared,why=session:GetReady(token);if not prepared then return nil,why end
    if not target then return self:CreateImportedRotation(prepared,spec,name) end
    local profile=self.db.profile;local original=self:GetEditableRotation(spec,target)
    local function valid()
        return self.db.profile==profile and type(expected)=='table' and expected.profile==profile and expected.target==original and original~=nil and self:GetEditableRotation(spec,target)==original and equal(original,expected.body) and not self:GetDefaultIdForRuntime(spec,target)
    end
    if not valid() then return nil,'rotation-changed-externally' end
    if self.GetRotationWorkspace then local workspace=self:GetRotationWorkspace(spec,target);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end end
    local id,reason=self:CreateImportedRotation(prepared,spec,original.name or name,{id=target,valid=valid})
    if not id then return nil,reason end
    if self.currentSpec==spec and self.currentRotation==target then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() elseif self.GlowClear then self:GlowClear() end
        self.currentSpell=nil;self.avail_announced={};self.announced={};self.skipAnnounce=true
    end
    if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
    return id
end

function addon:GetRotationExportData(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local record,why=scoped:Snapshot(spec,id);if not record then return nil,why end
        local result
        if record.source then result=record.source.envelope
        elseif record.origin or record.imported then local retained=record.origin or record.imported;result=data.CopyData(retained.manifest);result.body=record.body
        else return record.body end
        if result.body.tags~=nil then result.tags=data.CopyData(result.body.tags) end;return result
    end
    local function currentTags(envelope)
        if type(envelope)=='table' and type(envelope.body)=='table' and envelope.body.tags~=nil then
            local copy,why=data.CopyData(envelope);if not copy then return nil,why end
            copy.tags=data.CopyData(copy.body.tags);return copy
        end
        return envelope
    end
    local defaultId=self:GetDefaultIdForRuntime(spec,id)
    if defaultId then return currentTags(self:GetDefaultRotation(defaultId).envelope) end
    local source,why=self:GetSourcedRotationView(spec,id)
    if source then return currentTags(source.envelope) end
    if why~="no-source-baseline" then return nil,why end
    local imported,reason=self:GetImportedRotationView(spec,id)
    if imported then return currentTags(imported.envelope) end
    if reason~="not-imported" then return nil,reason end
    return data.CopyData(self:GetEditableRotation(spec,id))
end
]====],
        new = [====[local _,addon=...
local data=addon.RotationData
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local prepareActivePublication,finishActivePublication
if type(addon.BindActiveRotationPublication)=='function' then
    addon:BindActiveRotationPublication(function(prepare,finish)
        prepareActivePublication,finishActivePublication=prepare,finish
    end)
end
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
local function settings(self)
    local options=self:GetRotationValidationOptions();return options
end
function addon:GetImportValidationOptions() return settings(self) end
function addon:GetImportedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,true) end
    local state=self.db.profile.rotationLibrary
    if state==nil then return nil,"not-imported" end
    if not plain(state) then return nil,"invalid-import-state" end
    if state.imports==nil then return nil,"not-imported" end
    if not plain(state.imports) then return nil,"invalid-import-state" end
    local rows=state.imports[spec]
    if rows==nil then return nil,"not-imported" end
    if not plain(rows) then return nil,"invalid-import-state" end
    if rows[id]==nil then return nil,"not-imported" end
    local record,why=data.CopyData(rows[id])
    if why or not plain(record) or not plain(record.manifest) or record.manifest.id~=id
        or type(record.sourceId)~="string" or not plain(record.stepOrigins) then return nil,"invalid-import-state" end
    local body=self:GetEditableRotation(spec,id)
    local envelope=data.CopyData(record.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-import-state" end
    return {envelope=envelope,applicability=envelope.applicability,enabled=true,
        validation=data.ValidateEnvelope(envelope,settings(self)),sourceId=record.sourceId,
        sourceRevision=record.sourceRevision,stepOrigins=record.stepOrigins}
end
function addon:CreateImportedRotation(prepared,spec,name,replacement,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Import(prepared,spec,name,replacement,options) end
    if type(spec)~="number" or spec<0 or spec%1~=0 then return nil,"invalid-specialization" end
    if type(name)~="string" or #name==0 or #name>256 then return nil,"invalid-name" end
    local profile=self.db.profile
    local rotationsRoot=profile.rotations
    if rotationsRoot~=nil and not plain(rotationsRoot) then return nil,"invalid-rotation-storage" end
    if rotationsRoot and rotationsRoot[spec]~=nil and not plain(rotationsRoot[spec]) then return nil,"invalid-rotation-storage" end
    local body,problem=data.CopyData(prepared.body)
    if problem or not plain(body) then return nil,"invalid-import" end
    local manifest=prepared.manifest and data.CopyData(prepared.manifest)
    if prepared.manifest and not manifest then return nil,"invalid-import" end
    local result
    if manifest then
        local envelope=data.CopyData(manifest);envelope.body=body
        result=data.ValidateEnvelope(envelope,settings(self))
    else result=data.ValidateBody(body,settings(self)) end
    if not result.valid or not result.supported or not result.resolved then return nil,"import-not-ready" end
    local ok,why=self:InitializeRotationLibrary();if not ok then return nil,why end
    local state=self.db.profile.rotationLibrary
    for _,kind in ipairs({"origins","comparisons","imports"}) do if state[kind][spec]~=nil and not plain(state[kind][spec]) then return nil,"invalid-import-state" end end
    local used={}
    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    local function reserve(value)
        if type(value)=="string" then used[value]=true
        elseif type(value)=="table" then for key,child in pairs(value) do reserve(key);reserve(child) end end
    end
    for _,rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id,rotation in pairs(rotations) do
                used[id]=true
                local copy=data.CopyData(rotation);if copy then reserve(copy) end
            end
        end
    end
    for _,kind in ipairs({"origins","comparisons","imports"}) do
        for _,rows in pairs(state[kind]) do
            if plain(rows) then for id,record in pairs(rows) do
                used[id]=true;local copy=data.CopyData(record);if copy then reserve(copy) end
            end end
        end
    end
    for _,row in ipairs(self:ListDefaultRotations(spec)) do reserve(row.envelope) end
    reserve(body);reserve(manifest)
    local function fresh()
        local success,id=pcall(self.uuid)
        if not success or type(id)~="string" or #id>128 or not id:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[id] then return nil,"id-collision" end
        used[id]=true;return id
    end
    local id,errorCode;if replacement then id=replacement.id else id,errorCode=fresh() end;if not id then return nil,errorCode end
    local sourceId=prepared.sourceId or manifest and manifest.id
    local sourceRevision=prepared.sourceRevision or manifest and manifest.revision
    local origins={}
    local tree,treeError=data.IndexRotationSteps(body)
    if not tree then return nil,treeError.code end
    for _,row in ipairs(tree.rows) do
        local step=row.step
        local stepId,reason=fresh();if not stepId then return nil,reason end
        origins[stepId]=prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id=stepId
    end
    body.name=name
    local previous=replacement and self:GetEditableRotation(spec,id) or nil
    local revised,revisionError=data.PrepareRotationContentRevision(body,previous,replacement and 'edit' or 'import',replacement~=nil)
    if not revised then return nil,revisionError end
    body=revised
    if manifest then manifest.id=id;manifest.revision=1;manifest.nameKey=name end
    local publication=prepareActivePublication and prepareActivePublication(spec,id,nil,nil,body)
    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then return nil,'rotation-changed-externally' end
    if self.db.profile~=profile or profile.rotations~=rotationsRoot or profile.rotationLibrary~=state then return nil,'rotation-changed-externally' end
    local rotations=rotationsRoot and rotationsRoot[spec] or {}
    if replacement and rotations[id]~=previous then return nil,'rotation-changed-externally' end
    if not replacement and rotations[id]~=nil then return nil,'id-collision' end
    self.db.profile.rotations=rotationsRoot or {}
    self.db.profile.rotations[spec]=rotations;rotations[id]=body
    if replacement then
        for _,kind in ipairs({'origins','comparisons','imports'}) do if type(state[kind][spec])=='table' then state[kind][spec][id]=nil end end
    end
    if manifest then
        local rows=state.imports[spec] or {};state.imports[spec]=rows
        rows[id]={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
    end
    local transition
    if finishActivePublication then local _,change=finishActivePublication(publication);transition=change end
    return id,nil,nil,transition
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:ApplyRotationImport(session,token,spec,name,target,expected,options)
    local change=beginActive(self)
    local function current() return activeCurrent(self,change) end
    local function optional(name,...)
        local available=self[name]
        if not current() then return false end
        if available then
            local method=self[name]
            if not current() then return false end
            method(self,...)
        end
        return current()
    end
    local function switch()
        local available=self.SwitchRotation
        if not current() then return false end
        if available then
            local method=self.SwitchRotation
            if not current() then return false end
            local _,nextChange=method(self);change=nextChange or change
        end
        return current()
    end
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local prepared,why=session:GetReady(token);if not prepared then return nil,why end
        if not target then return self:CreateImportedRotation(prepared,spec,name,nil,options) end
        local reference,referenceReason=scoped:Resolve(spec,target);if not reference then return nil,referenceReason end
        if reference.kind~='custom' then return nil,'read-only-rotation' end
        if type(expected)~='table' or expected.profile~=self.db.profile then return nil,'rotation-changed-externally' end
        local workspace=self.GetRotationWorkspace and self:GetRotationWorkspace(spec,reference);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end
        local record,token=scoped:Snapshot(spec,reference);if not record then return nil,token end
        if expected.recordToken then
            if not equal(expected.reference,reference) then return nil,'rotation-changed-externally' end;token=expected.recordToken
        else
            local original=self:GetEditableRotation(spec,reference)
            if expected.target~=original or not data.CheckPortable(original) or not equal(original,expected.body) then return nil,'rotation-changed-externally' end
        end
        local id,commitReason,saved,transition=self:CreateImportedRotation(prepared,spec,record.body.name or name,{profile=self.db.profile,reference=reference,recordToken=token},options)
        if not id then return nil,commitReason end
        change=transition or change
        if not current() then return id,nil,saved end
        if not optional('UpdateAutoSwitch') then return id,nil,saved end
        if not current() then return id,nil,saved end
        if not switch() then return id,nil,saved end
        if not current() then return id,nil,saved end
        optional('EvaluateNextAction')
        return id,nil,saved
    end
    local prepared,why=session:GetReady(token);if not prepared then return nil,why end
    if not target then return self:CreateImportedRotation(prepared,spec,name) end
    local profile=self.db.profile;local original=self:GetEditableRotation(spec,target)
    local function valid()
        return self.db.profile==profile and type(expected)=='table' and expected.profile==profile and expected.target==original and original~=nil and self:GetEditableRotation(spec,target)==original and equal(original,expected.body) and not self:GetDefaultIdForRuntime(spec,target)
    end
    if not valid() then return nil,'rotation-changed-externally' end
    if self.GetRotationWorkspace then local workspace=self:GetRotationWorkspace(spec,target);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end end
    local id,reason,_,transition=self:CreateImportedRotation(prepared,spec,original.name or name,{id=target,valid=valid})
    if not id then return nil,reason end
    change=transition or change
    if not current() then return id end
    if self.currentSpec==spec and self.currentRotation==target then
        local available=self.RemoveAllCurrentGlows
        if not current() then return id end
        if available then
            local remove=self.RemoveAllCurrentGlows
            if not current() then return id end
            remove(self)
        elseif not optional('GlowClear') then return id end
        if not current() then return id end
        self.currentSpell=nil;self.avail_announced={};self.announced={};self.skipAnnounce=true
    end
    if not optional('UpdateAutoSwitch') then return id end
    if not current() then return id end
    if not switch() then return id end
    if not current() then return id end
    optional('EvaluateNextAction')
    return id
end

function addon:GetRotationExportData(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local record,why=scoped:Snapshot(spec,id);if not record then return nil,why end
        local result
        if record.source then result=record.source.envelope
        elseif record.origin or record.imported then local retained=record.origin or record.imported;result=data.CopyData(retained.manifest);result.body=record.body
        else return record.body end
        if result.body.tags~=nil then result.tags=data.CopyData(result.body.tags) end;return result
    end
    local function currentTags(envelope)
        if type(envelope)=='table' and type(envelope.body)=='table' and envelope.body.tags~=nil then
            local copy,why=data.CopyData(envelope);if not copy then return nil,why end
            copy.tags=data.CopyData(copy.body.tags);return copy
        end
        return envelope
    end
    local defaultId=self:GetDefaultIdForRuntime(spec,id)
    if defaultId then return currentTags(self:GetDefaultRotation(defaultId).envelope) end
    local source,why=self:GetSourcedRotationView(spec,id)
    if source then return currentTags(source.envelope) end
    if why~="no-source-baseline" then return nil,why end
    local imported,reason=self:GetImportedRotationView(spec,id)
    if imported then return currentTags(imported.envelope) end
    if reason~="not-imported" then return nil,reason end
    return data.CopyData(self:GetEditableRotation(spec,id))
end
]====],
    },
    ['Core/rotation_migration.lua'] = {
        old = [====[local _,addon=...
local data=addon.RotationData
local migrations,adoptions=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function clone(v,seen)
    if type(v)~='table' then return v end;seen=seen or {};if seen[v] then return seen[v] end
    local result={};seen[v]=result;for k,child in pairs(v) do result[k]=clone(child,seen) end;return result
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function legacy(profile)
    local library=profile.rotationLibrary
    if library~=nil and not plain(library) then return nil,'invalid-library-state' end
    local result={}
    for _,kind in ipairs({'rotations','origins','imports','comparisons'}) do
        local value;if kind=='rotations' then value=profile.rotations elseif library then value=library[kind] end
        if value~=nil and not plain(value) then return nil,'invalid-legacy-state' end
        result[kind]=value==nil and {} or value
    end
    return result
end
local function retiredLibrary(library)
    if not library then return nil end
    local result={origins={},imports={},comparisons={}}
    for key,value in pairs(library) do if key~='origins' and key~='imports' and key~='comparisons' then
        local detached,why=data.CopyData(value);if why then return nil,why.code end;result[key]=detached
    end end
    return result
end
local function nonempty(map) if type(map)~='table' then return map~=nil end;for _,rows in pairs(map) do if type(rows)~='table' or next(rows)~=nil then return true end end;return false end
function addon:PlanRotationProfileMigration(profile,fallbackID)
    if type(profile)~='table' then return nil,'invalid-profile' end
    local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
    if profile.rotationStore~=nil then
        if not text(profile.rotationFallbackID) then return nil,'missing-fallback-configuration' end
        local valid,why=data.ValidateRotationStore(profile.rotationStore);if not valid then return nil,why end
        for _,map in pairs(old) do if nonempty(map) then return nil,'conflicting-legacy-rotation-roots' end end
        local public={unchanged=true};migrations[public]={profile=profile,store=profile.rotationStore,fallback=profile.rotationFallbackID};return public
    end
    if not text(fallbackID) then return nil,'missing-fallback-configuration' end
    local proposed,planReason=data.PlanRotationStoreMigration(old);if not proposed then return nil,planReason end
    local public={unchanged=false};migrations[public]={profile=profile,store=nil,fallback=fallbackID,proposed=proposed,
        rotations=profile.rotations,library=profile.rotationLibrary,baseline=proposed.legacy,previousFallback=profile.rotationFallbackID};return public
end
function addon:ApplyRotationProfileMigration(public)
    local plan=migrations[public];if not plan then return nil,'invalid-migration-plan' end
    local profile=plan.profile
    if plan.store then
        if profile.rotationStore~=plan.store or profile.rotationFallbackID~=plan.fallback then return nil,'stale-migration-plan' end
        local valid,why=data.ValidateRotationStore(plan.store);if not valid then return nil,why end
        local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
        for _,map in pairs(old) do if nonempty(map) then return nil,'conflicting-legacy-rotation-roots' end end
        migrations[public]=nil;return true
    end
    if profile.rotationStore~=nil or profile.rotations~=plan.rotations or profile.rotationLibrary~=plan.library or profile.rotationFallbackID~=plan.previousFallback then return nil,'stale-migration-plan' end
    local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
    local checked,checkReason=data.PlanRotationStoreMigration(old);if not checked then return nil,checkReason end
    if not same(checked.legacy,plan.baseline) then return nil,'stale-migration-plan' end
    local replacement,libraryReason=retiredLibrary(profile.rotationLibrary);if libraryReason then return nil,libraryReason end
    -- Archive all four roots before retiring their old active homes. Ownership
    -- remains unknown even when a retained manifest happens to declare a class.
    profile.rotationStore=plan.proposed;profile.rotationFallbackID=plan.fallback;profile.rotations={}
    if profile.rotationLibrary then profile.rotationLibrary=replacement end
    profile.version=3;migrations[public]=nil;return true
end
-- Explicit startup entry point; the caller activates it only when every UI and
-- runtime route is ready. Profiles migrate independently; char archives stay put.
function addon:InitializeScopedRotationStorage()
    local results={};local visited={}
    for name,profile in pairs(self.db.sv and self.db.sv.profiles or {}) do
        visited[profile]=true;local plan,why=self:PlanRotationProfileMigration(profile,profile.rotationFallbackID or DEFAULT)
        local ok;if plan then ok,why=self:ApplyRotationProfileMigration(plan) end;results[#results+1]={profile=name,ok=ok==true,reason=why}
    end
    if not visited[self.db.profile] then
        local p=self.db.profile;local plan,why=self:PlanRotationProfileMigration(p,p.rotationFallbackID or DEFAULT)
        local ok;if plan then ok,why=self:ApplyRotationProfileMigration(plan) end;results[#results+1]={profile=false,ok=ok==true,reason=why}
    end
    local ok,why=self:BindRotationProfile();return ok,why,results
end
local function currentCharacter(owner)
    local c,why=owner:GetRotationOwnerContext();if not c or not c.character then return nil,why or 'missing-owner-context' end
    local root=owner.db.sv and owner.db.sv.char;local char=root and root[c.character]
    return char,c,root
end
local function validSelection(selection)
    if not plain(selection) or (selection.kind~='profile' and selection.kind~='character') or type(selection.spec)~='number' or selection.spec<0 or selection.spec==math.huge or selection.spec%1~=0 or not text(selection.id) then return false end
    for key in pairs(selection) do if key~='kind' and key~='spec' and key~='id' then return false end end
    return true
end
-- Inspection is a detached recovery boundary, never an ownership decision or
-- an adoption. Orphan source components remain available without a body.
function addon:GetUnassignedRotationSnapshot(selection)
    if not validSelection(selection) then return nil,'invalid-legacy-selection' end
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,why=coordinator:CheckReady();if not ready then return nil,why end
    local context,contextReason=self:GetRotationOwnerContext();if not context then return nil,contextReason end
    if selection.kind=='profile' then
        local rows,reason=coordinator:Unassigned();if not rows then return nil,reason end
        for _,row in ipairs(rows) do if row.address.spec==selection.spec and row.address.id==selection.id then return row.record end end
    else
        local char,c=currentCharacter(self);if not char then return nil,type(c)=='string' and c or 'unknown-rotation' end
        if not plain(char) then return nil,'invalid-legacy-state' end
        local archive,reason=data.PlanRotationStoreMigration({rotations=char.rotations});if not archive then return nil,reason end
        local rows=archive.legacy.rotations and archive.legacy.rotations[selection.spec]
        local body=rows and rows[selection.id];if body~=nil then return {body=body} end
    end
    return nil,'unknown-rotation'
end
function addon:ListUnassignedRotations()
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,readinessReason=coordinator:CheckReady();if not ready then return nil,readinessReason end
    local rows,why=coordinator:Unassigned();if not rows then return nil,why end
    local result={}
    local function add(kind,number,id,record,validation)
        local body=record.body;result[#result+1]={selection={kind=kind,spec=number,id=id},kind=kind,spec=number,id=id,
            name=type(body)=='table' and type(body.name)=='string' and body.name or id,hasBody=body~=nil,validation=validation}
    end
    for _,row in ipairs(rows) do add('profile',row.address.spec,row.address.id,row.record,row.validation) end
    local char,c=currentCharacter(self)
    if char and char.rotations~=nil then
        local proposed,why=data.PlanRotationStoreMigration({rotations=char.rotations});if not proposed then return nil,why end
        for number,map in pairs(proposed.legacy.rotations) do for id,body in pairs(map) do add('character',number,id,{body=body},data.ValidateBody(body,self:GetRotationValidationOptions())) end end
    end
    table.sort(result,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end;if a.spec~=b.spec then return a.spec<b.spec end;return a.id<b.id end)
    return result
end
function addon:PlanRotationAdoption(selection,scope)
    if not validSelection(selection) then return nil,'invalid-legacy-selection' end
    scope=scope or 'class'
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,readinessReason=coordinator:CheckReady();if not ready then return nil,readinessReason end
    if selection.kind=='profile' then
        local plan,why=coordinator:PlanAdoption(selection,scope or 'class');if not plan then return nil,why end
        adoptions[plan]={coordinator=coordinator};return plan
    end
    local char,c,charRoot=currentCharacter(self);if not char then return nil,type(c)=='string' and c or 'unknown-rotation' end
    if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
    local archive,why=data.PlanRotationStoreMigration({rotations=char.rotations});if not archive then return nil,why end
    local rows=archive.legacy.rotations and archive.legacy.rotations[selection.spec];local body=rows and rows[selection.id];if not body then return nil,'unknown-rotation' end
    local original=self.db.profile.rotationStore;local valid,stateReason=data.ValidateRotationStore(original);if not valid then return nil,stateReason end
    local proposed=clone(original);local service,storeReason=data.NewRotationStore({state=proposed,fallbackID=self.db.profile.rotationFallbackID});if not service then return nil,storeReason end
    local address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
    local transaction,planReason=service:PlanCreate(address,{body=body},c);if not transaction then return nil,planReason end
    local committed,commitReason=service:Commit(transaction,c);if not committed then return nil,commitReason end
    rows[selection.id]=nil
    local public={reference={kind='custom',address=clone(address)},selection=clone(selection),scope=scope}
    adoptions[public]={coordinator=coordinator,profile=self.db.profile,fallback=self.db.profile.rotationFallbackID,context=c,char=char,charRoot=charRoot,original=original,baseline=clone(original),
        rotations=char.rotations,charBaseline=data.PlanRotationStoreMigration({rotations=char.rotations}),proposed=proposed,charReplacement=archive.legacy.rotations,reference=clone(public.reference)}
    return public
end
function addon:ApplyRotationAdoption(public)
    local plan=adoptions[public];if not plan or self:GetScopedRotationCoordinator()~=plan.coordinator then return nil,'invalid-adoption-plan' end
    local ready,readinessReason=plan.coordinator:CheckReady();if not ready then return nil,readinessReason end
    if not plan.profile then local ok,reference=plan.coordinator:ApplyAdoption(public);if ok then adoptions[public]=nil end;return ok,reference end
    local char,c,charRoot=currentCharacter(self)
    if self.db.profile~=plan.profile or not same(c,plan.context) or char~=plan.char or charRoot~=plan.charRoot or char.rotations~=plan.rotations or plan.profile.rotationStore~=plan.original or plan.profile.rotationFallbackID~=plan.fallback then return nil,'stale-adoption-plan' end
    local valid,why=data.ValidateRotationStore(plan.original);if not valid then return nil,why end
    local now,archiveReason=data.PlanRotationStoreMigration({rotations=char.rotations});if not now then return nil,archiveReason end
    if not same(plan.original,plan.baseline) or not same(now,plan.charBaseline) then return nil,'stale-adoption-plan' end
    plan.profile.rotationStore=plan.proposed;char.rotations=plan.charReplacement;adoptions[public]=nil
    local bound,bindReason=self:BindRotationProfile();if not bound then return nil,bindReason end
    return true,clone(plan.reference)
end
]====],
        new = [====[local _,addon=...
local data=addon.RotationData
local prepareRootRebind,runRootRebind
local activeCurrent=addon.IsActiveRotationTransitionCurrent
if type(addon.BindActiveRotationProfileRebind)=='function' then
    addon:BindActiveRotationProfileRebind(function(prepare,run)
        prepareRootRebind,runRootRebind=prepare,run
    end)
end
local migrations,adoptions=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function clone(v,seen)
    if type(v)~='table' then return v end;seen=seen or {};if seen[v] then return seen[v] end
    local result={};seen[v]=result;for k,child in pairs(v) do result[k]=clone(child,seen) end;return result
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function legacy(profile)
    local library=profile.rotationLibrary
    if library~=nil and not plain(library) then return nil,'invalid-library-state' end
    local result={}
    for _,kind in ipairs({'rotations','origins','imports','comparisons'}) do
        local value;if kind=='rotations' then value=profile.rotations elseif library then value=library[kind] end
        if value~=nil and not plain(value) then return nil,'invalid-legacy-state' end
        result[kind]=value==nil and {} or value
    end
    return result
end
local function retiredLibrary(library)
    if not library then return nil end
    local result={origins={},imports={},comparisons={}}
    for key,value in pairs(library) do if key~='origins' and key~='imports' and key~='comparisons' then
        local detached,why=data.CopyData(value);if why then return nil,why.code end;result[key]=detached
    end end
    return result
end
local function nonempty(map) if type(map)~='table' then return map~=nil end;for _,rows in pairs(map) do if type(rows)~='table' or next(rows)~=nil then return true end end;return false end
function addon:PlanRotationProfileMigration(profile,fallbackID)
    if type(profile)~='table' then return nil,'invalid-profile' end
    local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
    if profile.rotationStore~=nil then
        if not text(profile.rotationFallbackID) then return nil,'missing-fallback-configuration' end
        local valid,why=data.ValidateRotationStore(profile.rotationStore);if not valid then return nil,why end
        for _,map in pairs(old) do if nonempty(map) then return nil,'conflicting-legacy-rotation-roots' end end
        local public={unchanged=true};migrations[public]={profile=profile,store=profile.rotationStore,fallback=profile.rotationFallbackID};return public
    end
    if not text(fallbackID) then return nil,'missing-fallback-configuration' end
    local proposed,planReason=data.PlanRotationStoreMigration(old);if not proposed then return nil,planReason end
    local public={unchanged=false};migrations[public]={profile=profile,store=nil,fallback=fallbackID,proposed=proposed,
        rotations=profile.rotations,library=profile.rotationLibrary,baseline=proposed.legacy,previousFallback=profile.rotationFallbackID};return public
end
function addon:ApplyRotationProfileMigration(public)
    local plan=migrations[public];if not plan then return nil,'invalid-migration-plan' end
    local profile=plan.profile
    if plan.store then
        if profile.rotationStore~=plan.store or profile.rotationFallbackID~=plan.fallback then return nil,'stale-migration-plan' end
        local valid,why=data.ValidateRotationStore(plan.store);if not valid then return nil,why end
        local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
        for _,map in pairs(old) do if nonempty(map) then return nil,'conflicting-legacy-rotation-roots' end end
        migrations[public]=nil;return true
    end
    if profile.rotationStore~=nil or profile.rotations~=plan.rotations or profile.rotationLibrary~=plan.library or profile.rotationFallbackID~=plan.previousFallback then return nil,'stale-migration-plan' end
    local old,legacyReason=legacy(profile);if not old then return nil,legacyReason end
    local checked,checkReason=data.PlanRotationStoreMigration(old);if not checked then return nil,checkReason end
    if not same(checked.legacy,plan.baseline) then return nil,'stale-migration-plan' end
    local replacement,libraryReason=retiredLibrary(profile.rotationLibrary);if libraryReason then return nil,libraryReason end
    -- Archive all four roots before retiring their old active homes. Ownership
    -- remains unknown even when a retained manifest happens to declare a class.
    profile.rotationStore=plan.proposed;profile.rotationFallbackID=plan.fallback;profile.rotations={}
    if profile.rotationLibrary then profile.rotationLibrary=replacement end
    profile.version=3;migrations[public]=nil;return true
end
-- Explicit startup entry point; the caller activates it only when every UI and
-- runtime route is ready. Profiles migrate independently; char archives stay put.
function addon:InitializeScopedRotationStorage()
    local results={};local visited={}
    for name,profile in pairs(self.db.sv and self.db.sv.profiles or {}) do
        visited[profile]=true;local plan,why=self:PlanRotationProfileMigration(profile,profile.rotationFallbackID or DEFAULT)
        local ok;if plan then ok,why=self:ApplyRotationProfileMigration(plan) end;results[#results+1]={profile=name,ok=ok==true,reason=why}
    end
    if not visited[self.db.profile] then
        local p=self.db.profile;local plan,why=self:PlanRotationProfileMigration(p,p.rotationFallbackID or DEFAULT)
        local ok;if plan then ok,why=self:ApplyRotationProfileMigration(plan) end;results[#results+1]={profile=false,ok=ok==true,reason=why}
    end
    local ok,why=self:BindRotationProfile();return ok,why,results
end
local function currentCharacter(owner)
    local c,why=owner:GetRotationOwnerContext();if not c or not c.character then return nil,why or 'missing-owner-context' end
    local root=owner.db.sv and owner.db.sv.char;local char=root and root[c.character]
    return char,c,root
end
local function validSelection(selection)
    if not plain(selection) or (selection.kind~='profile' and selection.kind~='character') or type(selection.spec)~='number' or selection.spec<0 or selection.spec==math.huge or selection.spec%1~=0 or not text(selection.id) then return false end
    for key in pairs(selection) do if key~='kind' and key~='spec' and key~='id' then return false end end
    return true
end
-- Inspection is a detached recovery boundary, never an ownership decision or
-- an adoption. Orphan source components remain available without a body.
function addon:GetUnassignedRotationSnapshot(selection)
    if not validSelection(selection) then return nil,'invalid-legacy-selection' end
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,why=coordinator:CheckReady();if not ready then return nil,why end
    local context,contextReason=self:GetRotationOwnerContext();if not context then return nil,contextReason end
    if selection.kind=='profile' then
        local rows,reason=coordinator:Unassigned();if not rows then return nil,reason end
        for _,row in ipairs(rows) do if row.address.spec==selection.spec and row.address.id==selection.id then return row.record end end
    else
        local char,c=currentCharacter(self);if not char then return nil,type(c)=='string' and c or 'unknown-rotation' end
        if not plain(char) then return nil,'invalid-legacy-state' end
        local archive,reason=data.PlanRotationStoreMigration({rotations=char.rotations});if not archive then return nil,reason end
        local rows=archive.legacy.rotations and archive.legacy.rotations[selection.spec]
        local body=rows and rows[selection.id];if body~=nil then return {body=body} end
    end
    return nil,'unknown-rotation'
end
function addon:ListUnassignedRotations()
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,readinessReason=coordinator:CheckReady();if not ready then return nil,readinessReason end
    local rows,why=coordinator:Unassigned();if not rows then return nil,why end
    local result={}
    local function add(kind,number,id,record,validation)
        local body=record.body;result[#result+1]={selection={kind=kind,spec=number,id=id},kind=kind,spec=number,id=id,
            name=type(body)=='table' and type(body.name)=='string' and body.name or id,hasBody=body~=nil,validation=validation}
    end
    for _,row in ipairs(rows) do add('profile',row.address.spec,row.address.id,row.record,row.validation) end
    local char,c=currentCharacter(self)
    if char and char.rotations~=nil then
        local proposed,why=data.PlanRotationStoreMigration({rotations=char.rotations});if not proposed then return nil,why end
        for number,map in pairs(proposed.legacy.rotations) do for id,body in pairs(map) do add('character',number,id,{body=body},data.ValidateBody(body,self:GetRotationValidationOptions())) end end
    end
    table.sort(result,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end;if a.spec~=b.spec then return a.spec<b.spec end;return a.id<b.id end)
    return result
end
function addon:PlanRotationAdoption(selection,scope)
    if not validSelection(selection) then return nil,'invalid-legacy-selection' end
    scope=scope or 'class'
    local coordinator=self:GetScopedRotationCoordinator();if not coordinator then return nil,'rotation-profile-not-bound' end
    local ready,readinessReason=coordinator:CheckReady();if not ready then return nil,readinessReason end
    if selection.kind=='profile' then
        local plan,why=coordinator:PlanAdoption(selection,scope or 'class');if not plan then return nil,why end
        adoptions[plan]={coordinator=coordinator};return plan
    end
    local char,c,charRoot=currentCharacter(self);if not char then return nil,type(c)=='string' and c or 'unknown-rotation' end
    if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
    local archive,why=data.PlanRotationStoreMigration({rotations=char.rotations});if not archive then return nil,why end
    local rows=archive.legacy.rotations and archive.legacy.rotations[selection.spec];local body=rows and rows[selection.id];if not body then return nil,'unknown-rotation' end
    local original=self.db.profile.rotationStore;local valid,stateReason=data.ValidateRotationStore(original);if not valid then return nil,stateReason end
    local proposed=clone(original);local service,storeReason=data.NewRotationStore({state=proposed,fallbackID=self.db.profile.rotationFallbackID});if not service then return nil,storeReason end
    local address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
    local transaction,planReason=service:PlanCreate(address,{body=body},c);if not transaction then return nil,planReason end
    local committed,commitReason=service:Commit(transaction,c);if not committed then return nil,commitReason end
    rows[selection.id]=nil
    local public={reference={kind='custom',address=clone(address)},selection=clone(selection),scope=scope}
    adoptions[public]={coordinator=coordinator,profile=self.db.profile,fallback=self.db.profile.rotationFallbackID,context=c,char=char,charRoot=charRoot,original=original,baseline=clone(original),
        rotations=char.rotations,charBaseline=data.PlanRotationStoreMigration({rotations=char.rotations}),proposed=proposed,charReplacement=archive.legacy.rotations,reference=clone(public.reference)}
    return public
end
function addon:ApplyRotationAdoption(public)
    local plan=adoptions[public];if not plan or self:GetScopedRotationCoordinator()~=plan.coordinator then return nil,'invalid-adoption-plan' end
    local ready,readinessReason=plan.coordinator:CheckReady();if not ready then return nil,readinessReason end
    if not plan.profile then local ok,reference=plan.coordinator:ApplyAdoption(public);if ok then adoptions[public]=nil end;return ok,reference end
    local char,c,charRoot=currentCharacter(self)
    if self.db.profile~=plan.profile or not same(c,plan.context) or char~=plan.char or charRoot~=plan.charRoot or char.rotations~=plan.rotations or plan.profile.rotationStore~=plan.original or plan.profile.rotationFallbackID~=plan.fallback then return nil,'stale-adoption-plan' end
    local valid,why=data.ValidateRotationStore(plan.original);if not valid then return nil,why end
    local now,archiveReason=data.PlanRotationStoreMigration({rotations=char.rotations});if not now then return nil,archiveReason end
    if not same(plan.original,plan.baseline) or not same(now,plan.charBaseline) then return nil,'stale-adoption-plan' end
    local binding=prepareRootRebind and prepareRootRebind()
    local freshChar,freshContext,freshRoot=currentCharacter(self)
    if self.db.profile~=plan.profile or not same(freshContext,plan.context) or freshChar~=plan.char or freshRoot~=plan.charRoot
        or char.rotations~=plan.rotations or plan.profile.rotationStore~=plan.original or plan.profile.rotationFallbackID~=plan.fallback then return nil,'stale-adoption-plan' end
    local freshArchive,freshArchiveReason=data.PlanRotationStoreMigration({rotations=char.rotations})
    if not freshArchive then return nil,freshArchiveReason end
    if not same(plan.original,plan.baseline) or not same(freshArchive,plan.charBaseline) then return nil,'stale-adoption-plan' end
    if self.db.profile~=plan.profile or char.rotations~=plan.rotations or plan.profile.rotationStore~=plan.original
        or plan.profile.rotationFallbackID~=plan.fallback then return nil,'stale-adoption-plan' end
    plan.profile.rotationStore=plan.proposed;char.rotations=plan.charReplacement;adoptions[public]=nil
    if binding and not activeCurrent(self,binding.token) then return true,clone(plan.reference) end
    local bind=self.BindRotationProfile
    if binding and not activeCurrent(self,binding.token) then return true,clone(plan.reference) end
    local bound,bindReason
    if binding and runRootRebind then bound,bindReason=runRootRebind(self,binding,bind)
    else bound,bindReason=bind(self) end
    if binding and not activeCurrent(self,binding.token) then return true,clone(plan.reference) end
    if not bound then return nil,bindReason end
    return true,clone(plan.reference)
end
]====],
    },
    ['UI/rotation_editor.lua'] = {
        old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData
local function text(parent,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');label:SetJustifyH('LEFT');label:SetWordWrap(false);return label
end
function addon:CreateRotationEditor(parent,spec,id,onSelect)
    if parent.rmRotationEditor then return parent.rmRotationEditor:Open(spec,id,onSelect) end
    local workspace,why=self:GetRotationEditWorkspace(spec,id);if not workspace then return nil,why end
    local pane={frame=CreateFrame('Frame',nil,parent),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}
    pane.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',0,0)
    pane.name=self:CreateWorkbenchEditBox(pane.frame);pane.name:SetPoint('TOPLEFT',8,-4);pane.name:SetSize(320,24);pane.name:SetMaxLetters(256)
    pane.origin=text(pane.frame);pane.origin:SetText('');pane.origin:Hide()
    pane.nameLabel=text(pane.frame);pane.nameLabel:SetText(L['Name']);pane.nameLabel:SetPoint('TOPLEFT',8,-10)
    pane.descriptionLabel=text(pane.frame);pane.descriptionLabel:SetText(L['Description']);pane.descriptionLabel:SetPoint('TOPLEFT',8,-38)
    pane.description=CreateFrame('EditBox',nil,pane.frame);pane.description:SetFontObject('GameFontHighlightSmall');pane.description:SetAutoFocus(false);pane.description:SetMultiLine(true);pane.description:SetMaxLetters(4096);pane.description:SetPoint('TOPLEFT',86,-30);pane.description:SetSize(300,36)
    pane.info=addon:CreateWorkbenchLabeledIconButton(pane.frame,'info',L['Metadata'],92)
    pane.validationButton=addon:CreateWorkbenchLabeledIconButton(pane.frame,'warning',L['This rotation cannot run until its incomplete or unavailable data is resolved.'],400)
    pane.validationButton:GetFontString():SetTextColor(1,.35,.3);pane.validationButton:Hide()
    pane.status=text(pane.frame);pane.status:SetPoint('BOTTOMLEFT',8,12)
    function pane:Message(message) self.status:SetText(message or '') end
    function pane:UpdateHistory()
        local state=self.workspace.session:HistoryState()
        local pending=not self.workspace.readOnly and (self.nameDirty or self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty or self.scopeDirty or self:HasPendingFields())
        if state.canUndo or pending then self.undo:Enable() else self.undo:Disable() end
        if state.canRedo and not pending then self.redo:Enable() else self.redo:Disable() end
        if not self.workspace.readOnly and (self.workspace.pending or self:HasUnsavedChanges()) then self.apply:Enable() else self.apply:Disable() end
    end
    function pane:BuildScene()
        local snapshot=self.workspace:Snapshot()
        for stepId,state in pairs(self.view.cardStates or {}) do self.view.expanded[stepId]=state=='expanded' end
        for stepId,expanded in pairs(self.view.expanded) do if not expanded then self.view.detailsHeights[stepId]=nil else self.view.detailsHeights[stepId]=self.view.detailsHeights[stepId] or 180 end end
        self.view.viewportWidth=self.canvas and self.canvas.frame:GetWidth() or 720
        local scene,problem=addon:BuildRotationCanvas(snapshot,self.view)
        if not scene then self:Message(problem.code);return end
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions());self.validation=validation
        for _,model in ipairs(scene.cards) do
            local path='$.body'
            for _,part in ipairs(model.path) do path=path..(type(part)=='number' and '['..part..']' or '.'..part) end
            for _,diagnostic in ipairs(validation.diagnostics) do
                if diagnostic.path==path or diagnostic.path:sub(1,#path+1)==path..'.' or diagnostic.path:sub(1,#path+1)==path..'[' then
                    model.invalid=true;model.problem=diagnostic.code;break
                end
            end
            model.pendingProblem=self:PendingFieldProblem(model.id)
            if model.pendingProblem then model.invalid=true end
            model.displayName=self:FieldText(model.id,'name',model.step.name or '')
            model.expanded=not model.compact and self.view.expanded[model.id]==true
        end
        return scene
    end
    function pane:RefreshValidation()
        if not self.active then return end
        local scene=self:BuildScene();if not scene then return end
        local byId={};for _,model in ipairs(scene.cards) do byId[model.id]=model end
        for _,card in ipairs(self.canvas.cards) do
            local model=card.model and byId[card.model.id]
            if model and card.frame:IsShown() then card:SetValidation(model.invalid);card.model.pendingProblem=model.pendingProblem;if card.RefreshHighlightPreview then card.RefreshHighlightPreview() end end
        end
        self:LayoutGeometry();self.canvas.frame:UpdateWorkbenchScroll()
    end
    function pane:Command(name,...)
        if not self.active then return nil,'rotation-pane-released' end
        local ok,result=self.workspace:Command(name,...)
        if not ok then self:Message(result);return nil,result end
        self:Message('');self:Render();return ok,result
    end
    function pane:Render()
        if not self.active then return end
        self.viewMode:SetText(self.view.layout=='list' and L['List view'] or L['Diagram view'])
        local snapshot=self.workspace:Snapshot()
        if self.metadataWindow and self.metadataWindow.frame:IsShown() and not self.metadataDirty then self.metadataWindow:Sync() end
        if not self.descriptionDirty then self.description:SetText(type(snapshot.description)=='string' and snapshot.description or (self.workspace.readOnly and type(self.workspace.description)=='string' and self.workspace.description or '')) end
        if not self.nameDirty and self.name:GetText()~=(snapshot.name or (workspace.fallback and DEFAULT or '')) then self.name:SetText(addon:PlainWorkbenchName(type(snapshot.name)=='string' and snapshot.name or (workspace.fallback and DEFAULT or ''))) end
        self.origin:SetText('')
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(snapshot.switch or {},spec)))
        if workspace.fallback then self.switch:Disable() else self.switch:Enable() end
        self:BuildScene();self:LayoutGeometry();self.canvas:Render()
        for _,control in ipairs({self.compare,self.clone}) do if self.workspace.pending then control:Disable() else control:Enable() end end
        self.clone:SetText(self.workspace.readOnly and L['Clone to edit'] or L['Duplicate'])
        if self.workspace.readOnly or workspace.fallback or self.workspace.pending then self.delete:Disable() else self.delete:Enable() end
        self.enable:SetSelected(self.workspace.readOnly and self.workspace.source.enabled or not self.workspace.readOnly and not snapshot.disabled)
        self.enable:SetText(self.workspace.readOnly and (self.workspace.source.enabled and L['Enabled'] or L['Disabled']) or snapshot.disabled and L['Disabled'] or L['Enabled'])
    end
    function pane:RotationDisplayName() return addon:PlainWorkbenchName(self.nameDirty and self.name:GetText() or self.workspace:Snapshot().name or self.workspace.title) end
    function pane:EditCondition(target)
        if not self.active then return end
        local editorTarget,reason=self.workspace:ConditionEditorTarget(target);if not editorTarget then self:Message(reason);return end
        local title,contextLabel
        if type(target)=='table' and target.kind=='switch' then title=L['Switch condition'];contextLabel=L['Switch condition'] else
            local row=data.IndexRotationSteps(self.workspace:Snapshot()).byId[target]
            if row then
                contextLabel=row.section=='cooldowns' and L['Cooldown'] or L['Rotation']
                local step=row.step;local name=self:FieldText(target,'name',step.name or '')
                if name:find('%S') then title=name
                elseif step.type=='spell' or step.type=='pet' or step.type=='any' then title=addon:SpellLabel(step.action)
                elseif step.type=='none' then title=L['Stop']
                elseif step.type=='item' then title=L['Item']
                else title=L['Edit Condition'] end
                title=addon:PlainWorkbenchName(title)
            end
        end
        local saved=self.workspace.session:Baseline();local savedCondition
        if type(target)=='table' and target.kind=='switch' then savedCondition=saved.switch or {} else local tree=data.IndexRotationSteps(saved,{allowMissingIds=true});savedCondition=tree and tree.byId[target] and tree.byId[target].step.conditions or {} end
        addon:ShowConditionEditor(1,spec,editorTarget.condition,function(applied)
            if not applied then return end
            local ok,problem=editorTarget.commit(editorTarget.condition)
            if self.active then if ok then self:Render() else self:Message(problem) end end
        end,editorTarget.valid,{readOnly=editorTarget.readOnly,persistentOwner=true,savedValue=savedCondition,title=title,contextLabel=contextLabel,rotationName=self:RotationDisplayName()})
    end
    function pane:ShowCardHelp(model)
        local kind=model.step.type=='branch' and 'branch' or model.section=='cooldowns' and 'cooldown' or 'rotation'
        local heading=model.displayName and model.displayName~='' and model.displayName or model.step.type=='branch' and L['Branch'] or model.section=='cooldowns' and L['Cooldown'] or L['Rotation']
        if addon.ShowWorkbenchHelp then addon:ShowWorkbenchHelp(heading,addon:WorkbenchInteractionHelp(kind),self:RotationDisplayName()) end
    end
    function pane:BuildFields(card,model,alive)
        if addon.BuildRotationCardFields then addon:BuildRotationCardFields(self,card,model,alive) end
    end
    addon:InstallRotationFieldDrafts(pane)
    local function tool(label,width,callback,icon)
        local control=icon and addon:CreateWorkbenchLabeledIconButton(pane.frame,icon,label,width==24 and 68 or width) or addon:CreateWorkbenchButton(pane.frame,label,width)
        control.action=callback;pane.tools[#pane.tools+1]=control;return control
    end
    pane.undo=tool(L['Undo'],24,function() if not pane:FlushName() then return end;local flushed,reason=pane:FlushFieldEdits();if not flushed then pane:Message(reason);return end;local ok,problem=workspace.session:Undo();if ok then pane:Render() else pane:Message(problem) end end,'undo')
    pane.redo=tool(L['Redo'],24,function() local ok,problem=workspace.session:Redo();if ok then pane:Render() else pane:Message(problem) end end,'redo')
    pane.switchButton=addon:CreateWorkbenchButton(pane.frame,'',300);pane.switch=pane.switchButton
    pane.switchText=pane.switchButton:GetFontString();pane.switchText:ClearAllPoints();pane.switchText:SetPoint('TOPLEFT',6,-4);pane.switchText:SetWordWrap(true);pane.switchText:SetJustifyH('LEFT')
    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);pane.switchLabel:GetFontString():SetFontObject('GameFontNormal');pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)
    pane.switch.tooltip=L['Click condition text on any card to view or edit its conditions.']
    pane.compare=tool(L['Compare rotations'],126,function()
        pane:RequestLeave(function() if addon.ShowRotationComparison then addon:ShowRotationComparison(spec,id) end end)
    end,'compare')
    table.remove(pane.tools);pane.compare:Hide()
    pane.clone=tool(workspace.readOnly and L['Clone to edit'] or L['Duplicate'],110,function()
        local function duplicate()
            local generated,problem,reference
            local name=string.format(L['Copy of %s'],workspace:Snapshot().name or workspace.title)
            if workspace.readOnly then generated,problem,reference=addon:CloneDefaultRotation(spec,workspace.builtin,name)
            else generated,problem,reference=addon:DuplicateCustomRotation(spec,id,name) end
            if generated and onSelect then onSelect(spec,reference or generated) else pane:Message(problem) end
        end
        if pane.RequestLeave then pane:RequestLeave(duplicate) else duplicate() end
    end,'copy')
    table.remove(pane.tools);pane.clone:Hide()
    pane.enable=tool(workspace.readOnly and L['Enable Built In'] or L['Enabled'],116,function()
        if workspace.readOnly then
            local current=workspace.source.enabled;local ok,problem=addon:SetDefaultRotationEnabled(workspace.builtin,not current)
            if ok then workspace.source.enabled=not current;pane:RefreshAdvice();pane:Render() else pane:Message(problem) end
        else pane:Command('SetBodyField','disabled',not workspace:Snapshot().disabled) end
    end)
    local oldEnable=pane.enable;oldEnable:Hide();table.remove(pane.tools)
    pane.enable=addon:CreateWorkbenchPill(pane.frame,L['Enabled'],70);pane.enable.action=oldEnable.action
    pane.delete=tool(L['Delete'],24,function() if pane.ConfirmDelete then pane:ConfirmDelete() end end)
    pane.delete:SetText('');pane.delete.art:Hide();pane.delete.icon=pane.delete:CreateTexture(nil,'ARTWORK');pane.delete.icon:SetAllPoints(pane.delete);pane.delete.icon:SetTexture(addon:ControlTexture('trash'));pane.delete.icon:SetVertexColor(1,.3,.3,1);pane.delete.tooltip=L['Delete rotation']
    table.remove(pane.tools)
    pane.canvas=self:CreateRotationCanvas(pane.frame,pane)
    addon:InstallRotationView(pane)
    pane.hint=text(pane.frame);pane.hint:SetPoint('BOTTOMLEFT',8,12);pane.hint:SetText(L['Click condition text on any card to view or edit its conditions.'])
    pane.apply=self:CreateWorkbenchButton(pane.frame,L['Apply'],86);pane.apply:SetPoint('BOTTOMRIGHT',-100,8)
    pane.discard=self:CreateWorkbenchButton(pane.frame,L['Discard'],86);pane.discard:SetPoint('BOTTOMRIGHT',-8,8)
    function pane:RefreshAdvice(previous,previousId)
        if previous and addon.currentSpec==spec and (addon.currentRotation==(previousId or id) or addon.currentRotation==id or workspace.effectiveFallback and addon.currentRotation==DEFAULT) then
            -- Removed/changed actions must be cleared using their old identities.
            for _,step in ipairs(previous.cooldowns or {}) do
                if addon.GetSpellIds and addon.GlowCooldown then for _,spell in ipairs(addon:GetSpellIds(step)) do addon:GlowCooldown(spell,false) end end
            end
            if addon.GlowClear then addon:GlowClear() end
            addon.currentSpell=nil;addon.avail_announced={};addon.announced={};addon.skipAnnounce=true
        end
        if addon.UpdateAutoSwitch then addon:UpdateAutoSwitch() end
        if addon.SwitchRotation then addon:SwitchRotation() end
        if addon.EvaluateNextAction then addon:EvaluateNextAction() end
        if self.onSaved then self.onSaved() end
    end
    function pane:AfterDelete() self.deleted=true;if onSelect then onSelect(spec,DEFAULT) else self:Release() end end
    function pane:Apply()
        if not self.active then return nil,'rotation-pane-released' end
        local fieldsOk,fieldsError=self:FlushFieldEdits();if not fieldsOk then self:Message(fieldsError);return nil,fieldsError end
        local flushed,flushError=self:FlushName();if not flushed then return nil,flushError end
        local previous=workspace.original and data.CopyData(workspace.original)
        local previousId=id;local ok,problem=workspace:Apply()
        if ok then
            if workspace.id~=id then
                if addon.currentSpec==spec and addon.currentRotation==previousId then addon.currentRotation=workspace.id end
                self:Open(spec,workspace.id,onSelect)
            end
            self:Message('');self:RefreshAdvice(previous,previousId);self:Render()
        else self:Message(problem) end
        return ok,problem
    end
    function pane:EffectiveTags(snapshot)
        snapshot=snapshot or self.workspace:Snapshot();local manifest=self.workspace.source and self.workspace.source.envelope
        if not manifest then for _,kind in ipairs({'origins','imports'}) do local record=self.workspace.reserved and self.workspace.reserved[kind];if type(record)=='table' and type(record.manifest)=='table' then manifest=record.manifest;break end end end
        return data.GetRotationTags({body=snapshot,tags=manifest and manifest.tags}) or {}
    end
    function pane:EffectiveScope() return self.scopeDirty and self.scopeDraft or self.workspace.scope end
    function pane:BaselineScope() return self.workspace.session.BaselineOwnership and self.workspace.session:BaselineOwnership() end
    function pane:FlushName()
        if self.deleted or workspace.readOnly then return true end
        if self.nameDirty and not workspace.fallback then local ok,problem=workspace:Command('SetBodyField','name',self.name:GetText());if not ok then self:Message(problem);return nil,problem end;self.nameDirty=false end
        if self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty then
            local snapshot=workspace:Snapshot();local tags=snapshot.tags;local priority=snapshot.priority
            if self.priorityDirty then
                local text=self.priority:GetText();local parsed=data.GetRotationPriority(text:match('^%s*$') and nil or tonumber(text))
                if parsed==nil or not text:match('^%s*$') and tonumber(text)==nil then self.priority:SetTextColor(1,.35,.35);self:Message(L['Switch priority must be a whole number between -100000 and 100000.']);return nil,'invalid-priority' end
                if snapshot.priority~=nil or parsed~=0 then priority=parsed end
            end
            if self.tagsDirty then
                local parsed=data.ParseRotationTags(self.tags:GetText());if not parsed then self.tags:SetTextColor(1,.35,.35);self:Message(L['Invalid tags. Use up to 64 tags of 64 characters, separated by commas.']);return nil,'invalid-tags' end
                if snapshot.tags~=nil and not data.NormalizeRotationTags(snapshot.tags) or data.FormatRotationTags(parsed)~=data.FormatRotationTags(self:EffectiveTags(snapshot)) then tags=parsed end
            end
            local metadata=self.metadataDirty and self.metadataDraft or snapshot.metadata;if snapshot.metadata==nil and type(metadata)=='table' and next(metadata)==nil then metadata=nil end
            local details={description=self.descriptionDirty and self.description:GetText() or snapshot.description,metadata=metadata,tags=tags,priority=priority}
            local ok,problem=workspace:Command('SetDetails',details);if not ok then self:Message(problem);return nil,problem end
            self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self:Message('')
        end
        if self.scopeDirty then local ok,problem=workspace:Command('SetOwnership',self.scopeDraft);if not ok then self:Message(problem);return nil,problem end;self.scopeDirty=false end
        return true
    end
    function pane:HasUnsavedChanges() return not self.deleted and not self.workspace.readOnly and (self.workspace:IsDirty() or self.nameDirty==true or self.descriptionDirty==true or self.metadataDirty==true or self.tagsDirty==true or self.priorityDirty==true or self.scopeDirty==true or self:HasPendingFields()) end
    function pane:LayoutGeometry()
        if not self.ready then return end
        local width,height=self.frame:GetWidth(),self.frame:GetHeight();local x,y=8,34
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',86,-4);self.name:SetWidth(math.max(100,width-94-self.info:GetWidth()-8))
        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-4)
        for _,control in ipairs(self.tools) do
                if x+control:GetWidth()>width-112 then x=8;y=y+24 end
            control:ClearAllPoints();control:SetPoint('TOPLEFT',self.frame,'TOPLEFT',x,-y);x=x+control:GetWidth()+4
        end
        self.delete:ClearAllPoints();self.delete:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-34)
        self.enable:ClearAllPoints();self.enable:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-36,-35)
        local available=self.validation and self.validation.valid and self.validation.supported and self.validation.resolved and not self:HasInvalidPendingFields()
        self.validationButton:ClearAllPoints();self.validationButton:SetPoint('TOPLEFT',8,-y-26);self.validationButton:SetWidth(math.max(100,width-16))
        if available then self.validationButton:Hide() else self.validationButton:Show() end
        local switchTop=y+30+(available and 0 or 24)
        self.switchLabel:ClearAllPoints();self.switchLabel:SetPoint('TOPLEFT',8,-switchTop)
        self.switch:ClearAllPoints();self.switch:SetPoint('TOPLEFT',8,-switchTop-22)
        self.switchText:SetWidth(math.max(100,width-28))
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(self.workspace:Snapshot().switch or {},spec)))
        local switchHeight=math.max(20,self.switchText:GetStringHeight());self.switchText:SetHeight(math.min(72,switchHeight))
        self.switch:SetSize(math.max(100,width-16),math.min(72,switchHeight)+8)
        self.switch:Show()
        local top=self:LayoutViewControls(switchTop+22+math.min(72,switchHeight)+18,width)
        self.canvas.frame:ClearAllPoints();self.canvas.frame:SetPoint('TOPLEFT',8,-top)
        self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48));self.canvas:LayoutScrollBar();self.status:SetWidth(math.max(1,width-330));self.hint:SetWidth(math.max(1,width-330));if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end
    end
    function pane:Layout() self:LayoutGeometry();self:Render() end
    function pane:SetWidth(value) self.frame:SetWidth(value) end
    function pane:SetHeight(value) self.frame:SetHeight(value) end
    function pane:Release()
        if self.active then self:FlushName() end
        if self.leavePrompt then self.leavePrompt.frame:Hide() end
        if self.deletePrompt then self.deletePrompt.frame:Hide() end
        if self.metadataWindow then self.metadataWindow:Close(true) end
        self.active=false;self.generation=(self.generation or 0)+1;self.canvas:Release();self.name:ClearFocus();self.description:ClearFocus();self.frame:Hide()
    end
    function pane:Open(nextSpec,nextId,nextSelect)
        local selected,problem=addon:GetRotationEditWorkspace(nextSpec,nextId);if not selected then return nil,problem end
        if self.active then self:Release() end
        workspace=selected;spec=nextSpec;id=selected.id;onSelect=nextSelect;self.workspace=workspace
        workspace.uiView=workspace.uiView or {collapsed={},expanded={},detailsHeights={}};self.view=workspace.uiView
        local preferred=addon.db.profile.rotation_view=='list' and 'list' or 'diagram'
        if self.view.defaultLayout~=preferred then self.view.layout=preferred;self.view.defaultLayout=preferred end
        self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self.metadataDraft=nil;self.deleted=false;self.active=true;self.generation=(self.generation or 0)+1
        local token=self.generation
        local function alive() return self.active and self.generation==token end
        for _,control in ipairs(self.tools) do
            addon:SetUIScript(control,'OnClick',function() if alive() then control.action() end end)
        end
        addon:SetUIScript(self.compare,'OnClick',function() if alive() then self.compare.action() end end)
        addon:SetUIScript(self.clone,'OnClick',function() if alive() then self.clone.action() end end)
        addon:SetUIScript(self.info,'OnClick',function() if alive() then self.metadataWindow:Open() end end)
        addon:SetUIScript(self.enable,'OnClick',function() if alive() then self.enable.action() end end)
        addon:SetUIScript(self.delete,'OnClick',function() if alive() then self.delete.action() end end)
        addon:SetUIScript(self.validationButton,'OnClick',function()
            if not alive() or not addon.ShowConditionText then return end
            local lines={L['This rotation cannot run until its incomplete or unavailable data is resolved.']}
            for _,problem in ipairs(self.validation and self.validation.diagnostics or {}) do lines[#lines+1]=problem.path..': '..problem.code end
            for stepId in pairs(self.view.pendingFields or {}) do local reason=self:PendingFieldProblem(stepId);if reason then lines[#lines+1]=stepId..': '..reason end end
            addon:ShowConditionText(table.concat(lines,'\n'),L['Rotation validation'])
        end)
        addon:SetUIScript(self.description,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly then self.descriptionDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.description,'OnEditFocusGained',workspace.readOnly and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.switchLabel,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        addon:SetUIScript(self.switch,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        self.view.section=self.view.section=='cooldowns' and 'cooldowns' or 'rotation'
        self.view.cardStates=self.view.cardStates or {};self.view.sectionsCollapsed={};self.view.hiddenChildren=self.view.hiddenChildren or {};self.view.switchCollapsed=nil
        self:BindViewControls(alive)
        addon:SetUIScript(self.name,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly and not workspace.fallback then self.nameDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.name,'OnEnterPressed',function(control) if alive() then control:ClearFocus();if self:FlushName() then self:Render() end end end)
        addon:SetUIScript(self.name,'OnEditFocusGained',(workspace.readOnly or workspace.fallback) and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.apply,'OnClick',function() if alive() then self:Apply() end end)
        addon:SetUIScript(self.discard,'OnClick',function()
            if not alive() then return end
            local ok,reason=workspace:Discard();if ok then self.metadataWindow:Close(true); self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self:ClearPendingFields();self:Render() else self:Message(reason) end
        end)
        if workspace.readOnly then self.apply:Disable();self.discard:Disable() else self.apply:Enable();self.discard:Enable() end
        for _,control in ipairs({self.compare,self.clone}) do if workspace.pending then control:Disable() else control:Enable() end end
        self.name:EnableMouse(not workspace.readOnly and not workspace.fallback);self.canvas.frame:Show();self.frame:Show();self:Message('')
        self.frame:SetSize(parent:GetWidth(),parent:GetHeight());self:Layout();return self
    end
    addon:SetUIScript(pane.frame,'OnSizeChanged',function() pane:Layout() end)
    addon:InstallRotationMetadata(pane)
    addon:InstallRotationUnsaved(pane);addon:InstallRotationChangeReview(pane)
    pane.ready=true;parent.rmRotationEditor=pane
    if addon.InstallRotationNavigation then addon:InstallRotationNavigation(pane) end
    return pane:Open(spec,id,onSelect)
end
]====],
        new = [====[local addon_name,addon=...
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData
local function text(parent,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');label:SetJustifyH('LEFT');label:SetWordWrap(false);return label
end
function addon:CreateRotationEditor(parent,spec,id,onSelect)
    if parent.rmRotationEditor then return parent.rmRotationEditor:Open(spec,id,onSelect) end
    local workspace,why=self:GetRotationEditWorkspace(spec,id);if not workspace then return nil,why end
    local pane={frame=CreateFrame('Frame',nil,parent),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}
    pane.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',0,0)
    pane.name=self:CreateWorkbenchEditBox(pane.frame);pane.name:SetPoint('TOPLEFT',8,-4);pane.name:SetSize(320,24);pane.name:SetMaxLetters(256)
    pane.origin=text(pane.frame);pane.origin:SetText('');pane.origin:Hide()
    pane.nameLabel=text(pane.frame);pane.nameLabel:SetText(L['Name']);pane.nameLabel:SetPoint('TOPLEFT',8,-10)
    pane.descriptionLabel=text(pane.frame);pane.descriptionLabel:SetText(L['Description']);pane.descriptionLabel:SetPoint('TOPLEFT',8,-38)
    pane.description=CreateFrame('EditBox',nil,pane.frame);pane.description:SetFontObject('GameFontHighlightSmall');pane.description:SetAutoFocus(false);pane.description:SetMultiLine(true);pane.description:SetMaxLetters(4096);pane.description:SetPoint('TOPLEFT',86,-30);pane.description:SetSize(300,36)
    pane.info=addon:CreateWorkbenchLabeledIconButton(pane.frame,'info',L['Metadata'],92)
    pane.validationButton=addon:CreateWorkbenchLabeledIconButton(pane.frame,'warning',L['This rotation cannot run until its incomplete or unavailable data is resolved.'],400)
    pane.validationButton:GetFontString():SetTextColor(1,.35,.3);pane.validationButton:Hide()
    pane.status=text(pane.frame);pane.status:SetPoint('BOTTOMLEFT',8,12)
    function pane:Message(message) self.status:SetText(message or '') end
    function pane:UpdateHistory()
        local state=self.workspace.session:HistoryState()
        local pending=not self.workspace.readOnly and (self.nameDirty or self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty or self.scopeDirty or self:HasPendingFields())
        if state.canUndo or pending then self.undo:Enable() else self.undo:Disable() end
        if state.canRedo and not pending then self.redo:Enable() else self.redo:Disable() end
        if not self.workspace.readOnly and (self.workspace.pending or self:HasUnsavedChanges()) then self.apply:Enable() else self.apply:Disable() end
    end
    function pane:BuildScene()
        local snapshot=self.workspace:Snapshot()
        for stepId,state in pairs(self.view.cardStates or {}) do self.view.expanded[stepId]=state=='expanded' end
        for stepId,expanded in pairs(self.view.expanded) do if not expanded then self.view.detailsHeights[stepId]=nil else self.view.detailsHeights[stepId]=self.view.detailsHeights[stepId] or 180 end end
        self.view.viewportWidth=self.canvas and self.canvas.frame:GetWidth() or 720
        local scene,problem=addon:BuildRotationCanvas(snapshot,self.view)
        if not scene then self:Message(problem.code);return end
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions());self.validation=validation
        for _,model in ipairs(scene.cards) do
            local path='$.body'
            for _,part in ipairs(model.path) do path=path..(type(part)=='number' and '['..part..']' or '.'..part) end
            for _,diagnostic in ipairs(validation.diagnostics) do
                if diagnostic.path==path or diagnostic.path:sub(1,#path+1)==path..'.' or diagnostic.path:sub(1,#path+1)==path..'[' then
                    model.invalid=true;model.problem=diagnostic.code;break
                end
            end
            model.pendingProblem=self:PendingFieldProblem(model.id)
            if model.pendingProblem then model.invalid=true end
            model.displayName=self:FieldText(model.id,'name',model.step.name or '')
            model.expanded=not model.compact and self.view.expanded[model.id]==true
        end
        return scene
    end
    function pane:RefreshValidation()
        if not self.active then return end
        local scene=self:BuildScene();if not scene then return end
        local byId={};for _,model in ipairs(scene.cards) do byId[model.id]=model end
        for _,card in ipairs(self.canvas.cards) do
            local model=card.model and byId[card.model.id]
            if model and card.frame:IsShown() then card:SetValidation(model.invalid);card.model.pendingProblem=model.pendingProblem;if card.RefreshHighlightPreview then card.RefreshHighlightPreview() end end
        end
        self:LayoutGeometry();self.canvas.frame:UpdateWorkbenchScroll()
    end
    function pane:Command(name,...)
        if not self.active then return nil,'rotation-pane-released' end
        local ok,result=self.workspace:Command(name,...)
        if not ok then self:Message(result);return nil,result end
        self:Message('');self:Render();return ok,result
    end
    function pane:Render()
        if not self.active then return end
        self.viewMode:SetText(self.view.layout=='list' and L['List view'] or L['Diagram view'])
        local snapshot=self.workspace:Snapshot()
        if self.metadataWindow and self.metadataWindow.frame:IsShown() and not self.metadataDirty then self.metadataWindow:Sync() end
        if not self.descriptionDirty then self.description:SetText(type(snapshot.description)=='string' and snapshot.description or (self.workspace.readOnly and type(self.workspace.description)=='string' and self.workspace.description or '')) end
        if not self.nameDirty and self.name:GetText()~=(snapshot.name or (workspace.fallback and DEFAULT or '')) then self.name:SetText(addon:PlainWorkbenchName(type(snapshot.name)=='string' and snapshot.name or (workspace.fallback and DEFAULT or ''))) end
        self.origin:SetText('')
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(snapshot.switch or {},spec)))
        if workspace.fallback then self.switch:Disable() else self.switch:Enable() end
        self:BuildScene();self:LayoutGeometry();self.canvas:Render()
        for _,control in ipairs({self.compare,self.clone}) do if self.workspace.pending then control:Disable() else control:Enable() end end
        self.clone:SetText(self.workspace.readOnly and L['Clone to edit'] or L['Duplicate'])
        if self.workspace.readOnly or workspace.fallback or self.workspace.pending then self.delete:Disable() else self.delete:Enable() end
        self.enable:SetSelected(self.workspace.readOnly and self.workspace.source.enabled or not self.workspace.readOnly and not snapshot.disabled)
        self.enable:SetText(self.workspace.readOnly and (self.workspace.source.enabled and L['Enabled'] or L['Disabled']) or snapshot.disabled and L['Disabled'] or L['Enabled'])
    end
    function pane:RotationDisplayName() return addon:PlainWorkbenchName(self.nameDirty and self.name:GetText() or self.workspace:Snapshot().name or self.workspace.title) end
    function pane:EditCondition(target)
        if not self.active then return end
        local editorTarget,reason=self.workspace:ConditionEditorTarget(target);if not editorTarget then self:Message(reason);return end
        local title,contextLabel
        if type(target)=='table' and target.kind=='switch' then title=L['Switch condition'];contextLabel=L['Switch condition'] else
            local row=data.IndexRotationSteps(self.workspace:Snapshot()).byId[target]
            if row then
                contextLabel=row.section=='cooldowns' and L['Cooldown'] or L['Rotation']
                local step=row.step;local name=self:FieldText(target,'name',step.name or '')
                if name:find('%S') then title=name
                elseif step.type=='spell' or step.type=='pet' or step.type=='any' then title=addon:SpellLabel(step.action)
                elseif step.type=='none' then title=L['Stop']
                elseif step.type=='item' then title=L['Item']
                else title=L['Edit Condition'] end
                title=addon:PlainWorkbenchName(title)
            end
        end
        local saved=self.workspace.session:Baseline();local savedCondition
        if type(target)=='table' and target.kind=='switch' then savedCondition=saved.switch or {} else local tree=data.IndexRotationSteps(saved,{allowMissingIds=true});savedCondition=tree and tree.byId[target] and tree.byId[target].step.conditions or {} end
        addon:ShowConditionEditor(1,spec,editorTarget.condition,function(applied)
            if not applied then return end
            local ok,problem=editorTarget.commit(editorTarget.condition)
            if self.active then if ok then self:Render() else self:Message(problem) end end
        end,editorTarget.valid,{readOnly=editorTarget.readOnly,persistentOwner=true,savedValue=savedCondition,title=title,contextLabel=contextLabel,rotationName=self:RotationDisplayName()})
    end
    function pane:ShowCardHelp(model)
        local kind=model.step.type=='branch' and 'branch' or model.section=='cooldowns' and 'cooldown' or 'rotation'
        local heading=model.displayName and model.displayName~='' and model.displayName or model.step.type=='branch' and L['Branch'] or model.section=='cooldowns' and L['Cooldown'] or L['Rotation']
        if addon.ShowWorkbenchHelp then addon:ShowWorkbenchHelp(heading,addon:WorkbenchInteractionHelp(kind),self:RotationDisplayName()) end
    end
    function pane:BuildFields(card,model,alive)
        if addon.BuildRotationCardFields then addon:BuildRotationCardFields(self,card,model,alive) end
    end
    addon:InstallRotationFieldDrafts(pane)
    local function tool(label,width,callback,icon)
        local control=icon and addon:CreateWorkbenchLabeledIconButton(pane.frame,icon,label,width==24 and 68 or width) or addon:CreateWorkbenchButton(pane.frame,label,width)
        control.action=callback;pane.tools[#pane.tools+1]=control;return control
    end
    pane.undo=tool(L['Undo'],24,function() if not pane:FlushName() then return end;local flushed,reason=pane:FlushFieldEdits();if not flushed then pane:Message(reason);return end;local ok,problem=workspace.session:Undo();if ok then pane:Render() else pane:Message(problem) end end,'undo')
    pane.redo=tool(L['Redo'],24,function() local ok,problem=workspace.session:Redo();if ok then pane:Render() else pane:Message(problem) end end,'redo')
    pane.switchButton=addon:CreateWorkbenchButton(pane.frame,'',300);pane.switch=pane.switchButton
    pane.switchText=pane.switchButton:GetFontString();pane.switchText:ClearAllPoints();pane.switchText:SetPoint('TOPLEFT',6,-4);pane.switchText:SetWordWrap(true);pane.switchText:SetJustifyH('LEFT')
    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);pane.switchLabel:GetFontString():SetFontObject('GameFontNormal');pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)
    pane.switch.tooltip=L['Click condition text on any card to view or edit its conditions.']
    pane.compare=tool(L['Compare rotations'],126,function()
        pane:RequestLeave(function() if addon.ShowRotationComparison then addon:ShowRotationComparison(spec,id) end end)
    end,'compare')
    table.remove(pane.tools);pane.compare:Hide()
    pane.clone=tool(workspace.readOnly and L['Clone to edit'] or L['Duplicate'],110,function()
        local function duplicate()
            local generated,problem,reference
            local name=string.format(L['Copy of %s'],workspace:Snapshot().name or workspace.title)
            if workspace.readOnly then generated,problem,reference=addon:CloneDefaultRotation(spec,workspace.builtin,name)
            else generated,problem,reference=addon:DuplicateCustomRotation(spec,id,name) end
            if generated and onSelect then onSelect(spec,reference or generated) else pane:Message(problem) end
        end
        if pane.RequestLeave then pane:RequestLeave(duplicate) else duplicate() end
    end,'copy')
    table.remove(pane.tools);pane.clone:Hide()
    pane.enable=tool(workspace.readOnly and L['Enable Built In'] or L['Enabled'],116,function()
        if workspace.readOnly then
            local current=workspace.source.enabled;local ok,problem=addon:SetDefaultRotationEnabled(workspace.builtin,not current)
            if ok then workspace.source.enabled=not current;if pane:RefreshAdvice() then pane:Render() end else pane:Message(problem) end
        else pane:Command('SetBodyField','disabled',not workspace:Snapshot().disabled) end
    end)
    local oldEnable=pane.enable;oldEnable:Hide();table.remove(pane.tools)
    pane.enable=addon:CreateWorkbenchPill(pane.frame,L['Enabled'],70);pane.enable.action=oldEnable.action
    pane.delete=tool(L['Delete'],24,function() if pane.ConfirmDelete then pane:ConfirmDelete() end end)
    pane.delete:SetText('');pane.delete.art:Hide();pane.delete.icon=pane.delete:CreateTexture(nil,'ARTWORK');pane.delete.icon:SetAllPoints(pane.delete);pane.delete.icon:SetTexture(addon:ControlTexture('trash'));pane.delete.icon:SetVertexColor(1,.3,.3,1);pane.delete.tooltip=L['Delete rotation']
    table.remove(pane.tools)
    pane.canvas=self:CreateRotationCanvas(pane.frame,pane)
    addon:InstallRotationView(pane)
    pane.hint=text(pane.frame);pane.hint:SetPoint('BOTTOMLEFT',8,12);pane.hint:SetText(L['Click condition text on any card to view or edit its conditions.'])
    pane.apply=self:CreateWorkbenchButton(pane.frame,L['Apply'],86);pane.apply:SetPoint('BOTTOMRIGHT',-100,8)
    pane.discard=self:CreateWorkbenchButton(pane.frame,L['Discard'],86);pane.discard:SetPoint('BOTTOMRIGHT',-8,8)
    function pane:RefreshAdvice(previous,previousId)
        local change=beginActive(addon)
        local function current() return activeCurrent(addon,change) end
        local function optional(name,...)
            local available=addon[name]
            if not current() then return false end
            if available then
                local method=addon[name]
                if not current() then return false end
                method(addon,...)
            end
            return current()
        end
        if previous and addon.currentSpec==spec and (addon.currentRotation==(previousId or id) or addon.currentRotation==id or workspace.effectiveFallback and addon.currentRotation==DEFAULT) then
            -- Removed/changed actions must be cleared using their old identities.
            for _,step in ipairs(previous.cooldowns or {}) do
                if not current() then return false end
                local available=addon.GetSpellIds and addon.GlowCooldown
                if not current() then return false end
                if available then
                    local get=addon.GetSpellIds
                    if not current() then return false end
                    local ids=get(addon,step)
                    if not current() then return false end
                    for _,spell in ipairs(ids) do
                        if not current() then return false end
                        local glow=addon.GlowCooldown
                        if not current() then return false end
                        glow(addon,spell,false)
                        if not current() then return false end
                    end
                end
            end
            if not optional('GlowClear') then return false end
            addon.currentSpell=nil;addon.avail_announced={};addon.announced={};addon.skipAnnounce=true
        end
        if not current() or not optional('UpdateAutoSwitch') then return false end
        local available=addon.SwitchRotation
        if not current() then return false end
        if available then
            local switch=addon.SwitchRotation
            if not current() then return false end
            local _,nextChange=switch(addon);change=nextChange or change
        end
        if not current() or not optional('EvaluateNextAction') then return false end
        local saved=self.onSaved
        if not current() then return false end
        if saved then
            saved=self.onSaved
            if not current() then return false end
            saved()
        end
        return current()
    end
    function pane:AfterDelete() self.deleted=true;if onSelect then onSelect(spec,DEFAULT) else self:Release() end end
    function pane:Apply()
        if not self.active then return nil,'rotation-pane-released' end
        local fieldsOk,fieldsError=self:FlushFieldEdits();if not fieldsOk then self:Message(fieldsError);return nil,fieldsError end
        local flushed,flushError=self:FlushName();if not flushed then return nil,flushError end
        local previous=workspace.original and data.CopyData(workspace.original)
        local previousId=id;local profile=addon.db.profile;local ok,problem=workspace:Apply()
        if ok then
            if not self.active or self.workspace~=workspace or addon.db.profile~=profile then return ok,problem end
            if workspace.id~=id then
                self:Open(spec,workspace.id,onSelect)
            end
            self:Message('');if self:RefreshAdvice(previous,previousId) then self:Render() end
        else self:Message(problem) end
        return ok,problem
    end
    function pane:EffectiveTags(snapshot)
        snapshot=snapshot or self.workspace:Snapshot();local manifest=self.workspace.source and self.workspace.source.envelope
        if not manifest then for _,kind in ipairs({'origins','imports'}) do local record=self.workspace.reserved and self.workspace.reserved[kind];if type(record)=='table' and type(record.manifest)=='table' then manifest=record.manifest;break end end end
        return data.GetRotationTags({body=snapshot,tags=manifest and manifest.tags}) or {}
    end
    function pane:EffectiveScope() return self.scopeDirty and self.scopeDraft or self.workspace.scope end
    function pane:BaselineScope() return self.workspace.session.BaselineOwnership and self.workspace.session:BaselineOwnership() end
    function pane:FlushName()
        if self.deleted or workspace.readOnly then return true end
        if self.nameDirty and not workspace.fallback then local ok,problem=workspace:Command('SetBodyField','name',self.name:GetText());if not ok then self:Message(problem);return nil,problem end;self.nameDirty=false end
        if self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty then
            local snapshot=workspace:Snapshot();local tags=snapshot.tags;local priority=snapshot.priority
            if self.priorityDirty then
                local text=self.priority:GetText();local parsed=data.GetRotationPriority(text:match('^%s*$') and nil or tonumber(text))
                if parsed==nil or not text:match('^%s*$') and tonumber(text)==nil then self.priority:SetTextColor(1,.35,.35);self:Message(L['Switch priority must be a whole number between -100000 and 100000.']);return nil,'invalid-priority' end
                if snapshot.priority~=nil or parsed~=0 then priority=parsed end
            end
            if self.tagsDirty then
                local parsed=data.ParseRotationTags(self.tags:GetText());if not parsed then self.tags:SetTextColor(1,.35,.35);self:Message(L['Invalid tags. Use up to 64 tags of 64 characters, separated by commas.']);return nil,'invalid-tags' end
                if snapshot.tags~=nil and not data.NormalizeRotationTags(snapshot.tags) or data.FormatRotationTags(parsed)~=data.FormatRotationTags(self:EffectiveTags(snapshot)) then tags=parsed end
            end
            local metadata=self.metadataDirty and self.metadataDraft or snapshot.metadata;if snapshot.metadata==nil and type(metadata)=='table' and next(metadata)==nil then metadata=nil end
            local details={description=self.descriptionDirty and self.description:GetText() or snapshot.description,metadata=metadata,tags=tags,priority=priority}
            local ok,problem=workspace:Command('SetDetails',details);if not ok then self:Message(problem);return nil,problem end
            self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self:Message('')
        end
        if self.scopeDirty then local ok,problem=workspace:Command('SetOwnership',self.scopeDraft);if not ok then self:Message(problem);return nil,problem end;self.scopeDirty=false end
        return true
    end
    function pane:HasUnsavedChanges() return not self.deleted and not self.workspace.readOnly and (self.workspace:IsDirty() or self.nameDirty==true or self.descriptionDirty==true or self.metadataDirty==true or self.tagsDirty==true or self.priorityDirty==true or self.scopeDirty==true or self:HasPendingFields()) end
    function pane:LayoutGeometry()
        if not self.ready then return end
        local width,height=self.frame:GetWidth(),self.frame:GetHeight();local x,y=8,34
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',86,-4);self.name:SetWidth(math.max(100,width-94-self.info:GetWidth()-8))
        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-4)
        for _,control in ipairs(self.tools) do
                if x+control:GetWidth()>width-112 then x=8;y=y+24 end
            control:ClearAllPoints();control:SetPoint('TOPLEFT',self.frame,'TOPLEFT',x,-y);x=x+control:GetWidth()+4
        end
        self.delete:ClearAllPoints();self.delete:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-34)
        self.enable:ClearAllPoints();self.enable:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-36,-35)
        local available=self.validation and self.validation.valid and self.validation.supported and self.validation.resolved and not self:HasInvalidPendingFields()
        self.validationButton:ClearAllPoints();self.validationButton:SetPoint('TOPLEFT',8,-y-26);self.validationButton:SetWidth(math.max(100,width-16))
        if available then self.validationButton:Hide() else self.validationButton:Show() end
        local switchTop=y+30+(available and 0 or 24)
        self.switchLabel:ClearAllPoints();self.switchLabel:SetPoint('TOPLEFT',8,-switchTop)
        self.switch:ClearAllPoints();self.switch:SetPoint('TOPLEFT',8,-switchTop-22)
        self.switchText:SetWidth(math.max(100,width-28))
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(self.workspace:Snapshot().switch or {},spec)))
        local switchHeight=math.max(20,self.switchText:GetStringHeight());self.switchText:SetHeight(math.min(72,switchHeight))
        self.switch:SetSize(math.max(100,width-16),math.min(72,switchHeight)+8)
        self.switch:Show()
        local top=self:LayoutViewControls(switchTop+22+math.min(72,switchHeight)+18,width)
        self.canvas.frame:ClearAllPoints();self.canvas.frame:SetPoint('TOPLEFT',8,-top)
        self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48));self.canvas:LayoutScrollBar();self.status:SetWidth(math.max(1,width-330));self.hint:SetWidth(math.max(1,width-330));if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end
    end
    function pane:Layout() self:LayoutGeometry();self:Render() end
    function pane:SetWidth(value) self.frame:SetWidth(value) end
    function pane:SetHeight(value) self.frame:SetHeight(value) end
    function pane:Release()
        if self.active then self:FlushName() end
        if self.leavePrompt then self.leavePrompt.frame:Hide() end
        if self.deletePrompt then self.deletePrompt.frame:Hide() end
        if self.metadataWindow then self.metadataWindow:Close(true) end
        self.active=false;self.generation=(self.generation or 0)+1;self.canvas:Release();self.name:ClearFocus();self.description:ClearFocus();self.frame:Hide()
    end
    function pane:Open(nextSpec,nextId,nextSelect)
        local selected,problem=addon:GetRotationEditWorkspace(nextSpec,nextId);if not selected then return nil,problem end
        if self.active then self:Release() end
        workspace=selected;spec=nextSpec;id=selected.id;onSelect=nextSelect;self.workspace=workspace
        workspace.uiView=workspace.uiView or {collapsed={},expanded={},detailsHeights={}};self.view=workspace.uiView
        local preferred=addon.db.profile.rotation_view=='list' and 'list' or 'diagram'
        if self.view.defaultLayout~=preferred then self.view.layout=preferred;self.view.defaultLayout=preferred end
        self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self.metadataDraft=nil;self.deleted=false;self.active=true;self.generation=(self.generation or 0)+1
        local token=self.generation
        local function alive() return self.active and self.generation==token end
        for _,control in ipairs(self.tools) do
            addon:SetUIScript(control,'OnClick',function() if alive() then control.action() end end)
        end
        addon:SetUIScript(self.compare,'OnClick',function() if alive() then self.compare.action() end end)
        addon:SetUIScript(self.clone,'OnClick',function() if alive() then self.clone.action() end end)
        addon:SetUIScript(self.info,'OnClick',function() if alive() then self.metadataWindow:Open() end end)
        addon:SetUIScript(self.enable,'OnClick',function() if alive() then self.enable.action() end end)
        addon:SetUIScript(self.delete,'OnClick',function() if alive() then self.delete.action() end end)
        addon:SetUIScript(self.validationButton,'OnClick',function()
            if not alive() or not addon.ShowConditionText then return end
            local lines={L['This rotation cannot run until its incomplete or unavailable data is resolved.']}
            for _,problem in ipairs(self.validation and self.validation.diagnostics or {}) do lines[#lines+1]=problem.path..': '..problem.code end
            for stepId in pairs(self.view.pendingFields or {}) do local reason=self:PendingFieldProblem(stepId);if reason then lines[#lines+1]=stepId..': '..reason end end
            addon:ShowConditionText(table.concat(lines,'\n'),L['Rotation validation'])
        end)
        addon:SetUIScript(self.description,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly then self.descriptionDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.description,'OnEditFocusGained',workspace.readOnly and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.switchLabel,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        addon:SetUIScript(self.switch,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        self.view.section=self.view.section=='cooldowns' and 'cooldowns' or 'rotation'
        self.view.cardStates=self.view.cardStates or {};self.view.sectionsCollapsed={};self.view.hiddenChildren=self.view.hiddenChildren or {};self.view.switchCollapsed=nil
        self:BindViewControls(alive)
        addon:SetUIScript(self.name,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly and not workspace.fallback then self.nameDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.name,'OnEnterPressed',function(control) if alive() then control:ClearFocus();if self:FlushName() then self:Render() end end end)
        addon:SetUIScript(self.name,'OnEditFocusGained',(workspace.readOnly or workspace.fallback) and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.apply,'OnClick',function() if alive() then self:Apply() end end)
        addon:SetUIScript(self.discard,'OnClick',function()
            if not alive() then return end
            local ok,reason=workspace:Discard();if ok then self.metadataWindow:Close(true); self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self:ClearPendingFields();self:Render() else self:Message(reason) end
        end)
        if workspace.readOnly then self.apply:Disable();self.discard:Disable() else self.apply:Enable();self.discard:Enable() end
        for _,control in ipairs({self.compare,self.clone}) do if workspace.pending then control:Disable() else control:Enable() end end
        self.name:EnableMouse(not workspace.readOnly and not workspace.fallback);self.canvas.frame:Show();self.frame:Show();self:Message('')
        self.frame:SetSize(parent:GetWidth(),parent:GetHeight());self:Layout();return self
    end
    addon:SetUIScript(pane.frame,'OnSizeChanged',function() pane:Layout() end)
    addon:InstallRotationMetadata(pane)
    addon:InstallRotationUnsaved(pane);addon:InstallRotationChangeReview(pane)
    pane.ready=true;parent.rmRotationEditor=pane
    if addon.InstallRotationNavigation then addon:InstallRotationNavigation(pane) end
    return pane:Open(spec,id,onSelect)
end
]====],
    },
    ['tests/fixtures/addon.lua'] = {
        old = [======[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env)
        if path=='Data/plain.lua' then chunk('rotationmaster',addon);return load('Data/rotation_revision.lua') end
        return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Core/dependency_revisions.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]======],
        new = [======[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env)
        if path=='Data/plain.lua' then chunk('rotationmaster',addon);return load('Data/rotation_revision.lua') end
        return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Core/dependency_revisions.lua');load('Core/rotation_active.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]======],
    },
}

return function(text, path)
    text = dofile('tests/fixtures/restore_workbench_resize.lua')(text, path)

    if path == 'Core/rotation_scope.lua' and text:find('local prepareChoicePublication', 1, true) or path
        == 'Core/rotation_library.lua'
        and text:find('local invalidateChoiceContext', 1, true) then
        text = dofile('tests/fixtures/restore_rotation_choice_preferences.lua')(text, path)
    end
    if path == 'Core/rotation_lifecycle.lua' then
        text = dofile('tests/fixtures/restore_questie_wiring.lua')(text, path)
    end
    if path == 'main.lua' then
        text = dofile('tests/fixtures/restore_cpu_work_views.lua')(text, path)
    end

    local row = assert(rows[path], 'unknown active-transition inverse path')
    assert(text == row.new, 'active-transition source differs: ' .. path)
    return row.old
end
