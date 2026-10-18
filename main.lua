local addon_name, addon = ...
-- SavedVariables identity must match the TOC, independent of folder casing.
addon.savedVariableName = "RotationMasterDB"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

_G[addon_name] = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceGUI = LibStub("AceGUI-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local ItemData = LibStub("AceGUI-3.0-ItemLoader")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local getCached
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
local isin, starts_with, isint = addon.isin, addon.starts_with, addon.isint

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
addon.delayed_condition = {}
local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(addon_name,
        { type = "data source", label = addon.pretty_name, icon = "Interface\\AddOns\\" .. addon_name .. "\\textures\\RotationMaster-Minimap" })

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

    elseif cmd == "config" then
        self:ShowConfig("Rotations")

    elseif cmd == "errors" then
        self:ShowErrors()

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
                for id, rot in pairs(self:GetRuntimeRotations(self.currentSpec,true)) do
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
    self.db = LibStub("AceDB-3.0"):New(self.savedVariableName, defaults, true)

    for ext_addon,conditions in pairs(self.delayed_condition) do
        if IsAddOnLoaded(ext_addon) then
            for name, condition in pairs(conditions) do
                self:RegisterCondition(name, condition)
            end
        end
    end

    self:init()
    self:validate(defaults)

    if type(self.db.profile.minimap) == "boolean" then
        self.db.profile.minimap = nil
    end
    DBIcon:Register(addon.name, DataBroker, self.db.profile.minimap)
    DataBroker.text = color.RED .. OFF

    self.funcDeserialize = {}
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

    -- This is here because of order of loading.
    getCached = addon.getCached

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
    elseif self:GetRuntimeRotation(self.currentSpec,id) then
        return self:GetRuntimeRotation(self.currentSpec,id).name
    else
        return nil
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
        for id, rot in pairs(addon:GetRuntimeRotations(addon.currentSpec,true)) do
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
    local frame = CreateFrame("Frame", addon_name .. "LDBFrame")
    local dropdownFrame = CreateFrame("Frame", addon_name .. "LDBDropdownFrame", frame, "UIDropDownMenuTemplate")

    if button == "RightButton" then
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        addon:ShowConfig("Rotations")
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
    local rotations=self:GetRotationCandidates(self.currentSpec)
    self.autoswitchRotation=self:GetOrderedAutoSwitchRotations(self.currentSpec,rotations)

    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figure out which of the autoswitch rotations best matches
function addon:SwitchRotation()
    if self.db.profile.disable_autoswitch or self.manualRotation then
        return
    end

    local newRotation
    local rotations=self:GetRuntimeRotations(self.currentSpec,true)
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

    if newRotation then
        if self.currentRotation ~= newRotation then
            addon:info(L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO], self:GetRotationName(newRotation))
            self:RemoveAllCurrentGlows()
            self.currentRotation = newRotation
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            self:EnableRotationTimer()
            DataBroker.text = self:GetRotationName(newRotation)
            AceEvent:SendMessage("ROTATIONMASTER_ROTATION", self.currentRotation, self:GetRotationName(self.currentRotation))
        end
        return
    end

    -- Could not find a rotation to switch to, even the default one.
    if self.currentRotation ~= nil then
        addon:warn(L["No rotation is active as there is none suitable to automatically switch to."])
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
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
        return
    elseif not self:GetRuntimeRotation(self.currentSpec,self.currentRotation) then
        self:DisableRotation()
        return
    else
        self.evaluationProfile:start()

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
        local rot = self:GetRuntimeRotation(self.currentSpec,self.currentRotation)
        local preview,suppressAttack=0,false
        local weakAuras=_G.WeakAuras
        ---@type AceGUIContainer
        local previewWindow=self.nextWindow
        if self.nextWindow then
            self.nextWindow:ReleaseChildren()
            self.nextWindow:PauseLayout()
        end
        local function recommend(spellid,cond,index,itemId)
            preview=preview+1
            if preview==1 then
                self.currentSpell=spellid
                if not addon:IsGlowing(spellid,itemId) then
                    if not self.db.profile.disable_buttons then addon:GlowNextSpell(spellid,itemId) end
                    if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",cond.type,spellid) end
                    AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,index,cond.id,cond.type,spellid)
                end
            end
            if self.nextWindow and self.nextWindow.AddRecommendation then
                ---@cast previewWindow RMRecommendationPreview
                previewWindow:AddRecommendation(spellid,itemId)
            elseif self.nextWindow then
                local icon=AceGUI:Create("Icon")
                local info=self.Platform:GetSpellInfo(spellid)
                icon:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon:SetImageSize(preview==1 and 54 or 36,preview==1 and 54 or 36)
                icon:SetLabel(info and info.name or string.format(L["Unknown spell (%s)"],spellid))
                icon:SetCallback("OnEnter",function()
                    GameTooltip:SetOwner(icon.frame,"ANCHOR_BOTTOMRIGHT",3)
                    GameTooltip:SetHyperlink("spell:"..spellid)
                end)
                icon:SetCallback("OnLeave",function() if GameTooltip:IsOwned(icon.frame) then GameTooltip:Hide() end end)
                previewWindow:AddChild(icon)
            end
        end
        local sequence=self:EvaluateRotationSequence(rot,function(condition,context)
            return addon:evaluateConditionResult(condition,context)
        end,function(cond,index)
            local spellid,enabled,itemId=eval(cond)
            if enabled then
                recommend(spellid,cond,index,itemId)
                if not self.nextWindow or preview>=self.db.profile.preview_spells then return false end
            end
            return true
        end)
        suppressAttack=sequence.suppressAttack
        if preview==0 and not suppressAttack and self.Platform:IsMeleeAttackNeeded("target")==true and actionReady("spell",6603) then
            local attack=addon:FindSpell({6603})
            if attack then recommend(attack,{id="RM-IMPLICIT:ATTACK",type="spell"},sequence.fallbackOrdinal or #(rot.rotation or {})+1) end
        end
        if preview==0 then
            self.currentSpell=nil
            if not self.db.profile.disable_buttons then addon:GlowClear() end
            if weakAuras and type(weakAuras.ScanEvents)=="function" then weakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE",nil,nil) end
            AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE",self.currentRotation,nil)
        end
        if self.nextWindow then
            self.nextWindow:ResumeLayout()
            self.nextWindow:DoLayout()
        end

        self.evaluationProfile:child("rotation"):stop()
        self.evaluationProfile:child("cooldowns"):start()
        if rot.cooldowns ~= nil then
            local enabled_cooldowns = {}
            local enabled_items = {}
            local disabled_cooldowns = {}
            for id, cond in pairs(rot.cooldowns) do
                local spellid, enabled, itemId = eval(cond)
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
                            addon.avail_announced[cond.id] = spellid;
                            AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
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
                addon:GlowCooldown(spellid, false, cond)
            end
            for spellid, cond in pairs(enabled_cooldowns) do
                addon:GlowCooldown(spellid, true, cond, enabled_items[spellid])
            end
        end
        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        addon.skipAnnounce = false
        addon.announced = {}

        self.evaluationProfile:stop()
    end

    if GetTime() - self.lastCacheReport > 15 then
        addon:ReportCacheStats()
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
addon.PLAYER_LEVEL_UP = wrapEvent(function(self)
    -- Level facts can still be old while the event is being dispatched.
    self:ScheduleTimer(function()
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
                    local ent = self.deepcopy(value)
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
        ItemData:UpdateItem(itemId)
    end
end)
