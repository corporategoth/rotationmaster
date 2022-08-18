local addon_name, addon = ...

local _G = _G

_G.RotationMaster = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local ItemData = LibStub("AceGUI-3.0-ItemLoader")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local getCached, getRetryCached
local DBIcon = LibStub("LibDBIcon-1.0")
local Media = LibStub("LibSharedMedia-3.0")

local ThreatClassic = LibStub("ThreatClassic-1.0")
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    UnitThreatSituation = ThreatClassic.UnitThreatSituation

    local LibClassicDurations = LibStub("LibClassicDurations")
    LibClassicDurations:Register(addon_name)
else
    ThreatClassic:Disable()
end

local pairs, color, string = pairs, color, string
local floor = math.floor
local isin, starts_with, isint = addon.isin, addon.starts_with, addon.isint

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject("RotationMaster",
        { type = "data source", label = addon.pretty_name, icon = "Interface\\AddOns\\RotationMaster\\textures\\RotationMaster-Minimap" })

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
        minimap = {
            hide = false,
        }
    },
    char = {
        rotations = {},
        itemsets = {},
        bindings = {},
        announces = {},
    },
    global = {
        itemsets = {},
        effects = {},
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
    'LEARNED_SPELL_IN_TAB',
    'UPDATE_MACROS',
    'SPELLS_CHANGED',

    -- Special Purpose
    'NAME_PLATE_UNIT_ADDED',
    'NAME_PLATE_UNIT_REMOVED',

    'BAG_UPDATE',
    'UNIT_COMBAT',

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

    "SPELL_DATA_LOAD_RESULT",
    "ITEM_DATA_LOAD_RESULT"
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

    if not cmd or cmd == "help" then
        addon:print(L["/rm help                - This text"])
        addon:print(L["/rm config              - Open the config dialog"])
        addon:print(L["/rm disable             - Disable battle rotation"])
        addon:print(L["/rm enable              - Enable battle rotation"])
        addon:print(L["/rm toggle              - Toggle between enabled and disabled"])
        addon:print(L["/rm current             - Print out the name of the current rotation"])
        addon:print(L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."])
        addon:print(L["                          This is reset upon switching specializations."])

    elseif cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.Rotation.frame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.Rotation.frame)

    elseif cmd == "disable" then
        addon:disable()

    elseif cmd == "enable" then
        addon:enable()

    elseif cmd == "toggle" then
        if addon.playerUnitFrame then
            addon:disable()
        else
            addon:enable()
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
            if self.db.char.rotations[self.currentSpec] ~= nil then
                for id, rot in pairs(self.db.char.rotations[self.currentSpec]) do
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
    else
        addon:warn(L["Invalid option " .. color.WHITE .. "%s" .. color.WARN], cmd)
    end
end

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RotationMasterDB", defaults, true)
    self:init()

    AceConsole:RegisterChatCommand("rm", function(str)
        addon:HandleCommand(str)
    end)
    AceConsole:RegisterChatCommand("rotationmaster", function(str)
        addon:HandleCommand(str)
    end)

    if type(self.db.profile.minimap) == "boolean" then
        self.db.profile.minimap = nil
    end
    DBIcon:Register(addon.name, DataBroker, self.db.profile.minimap)
    DataBroker.text = color.RED .. OFF

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
    self.playerUnitFrame = nil

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

    -- This is here because of order of loading.
    getCached = addon.getCached
    getRetryCached = addon.getRetryCached

    --self:SetupOptions()
end

function addon:GetRotationName(id)
    if id == DEFAULT then
        return DEFAULT
    elseif self.db.char.rotations[self.currentSpec] ~= nil  and
           self.db.char.rotations[self.currentSpec][id] ~= nil then
        return self.db.char.rotations[self.currentSpec][id].name
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
    if addon.db.char.rotations[addon.currentSpec] ~= nil then
        for id, rot in pairs(addon.db.char.rotations[addon.currentSpec]) do
            if id ~= DEFAULT then
                info.text, info.arg1, info.checked = rot.name, id, (addon.manualRotation == true and addon.currentRotation == id)
                UIDropDownMenu_AddButton(info)
            end
        end
    end
end

function DataBroker.OnClick(_, button)
    local frame = CreateFrame("Frame", "RotationMasterLDBFrame")
    local dropdownFrame = CreateFrame("Frame", "RotationMasterLDBDropdownFrame", frame, "UIDropDownMenuTemplate")

    if button == "RightButton" then
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        InterfaceOptionsFrame_OpenToCategory(addon.optionsFrames.Rotation.frame)
        InterfaceOptionsFrame_OpenToCategory(addon.optionsFrames.Rotation.frame)
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
    for _, v in pairs(events) do
        self:RegisterEvent(v)
    end
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        self.currentSpec = GetSpecializationInfo(addon:GetSpecialization())
        if self.specTab then
            self.specTab:SelectTab(self.currentSpec)
        end
        for _, v in pairs(mainline_events) do
            self:RegisterEvent(v)
        end
    elseif (LE_EXPANSION_LEVEL_CURRENT == 2) then
        self.currentSpec = addon:GetSpecialization()
        for _, v in pairs(wrath_events) do
            self:RegisterEvent(v)
        end
    elseif (LE_EXPANSION_LEVEL_CURRENT == 1) then
        self.currentSpec = 0
        for _, v in pairs(tbc_events) do
            self:RegisterEvent(v)
        end
    elseif (LE_EXPANSION_LEVEL_CURRENT == 0) then
        self.currentSpec = 0
        for _, v in pairs(classic_events) do
            self:RegisterEvent(v)
        end
    end

    self.playerUnitFrame = CreateFrame('Frame')
    self.playerUnitFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
    self.playerUnitFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'pet')

    self.playerUnitFrame:SetScript('OnEvent', function(_, _, _, _, spellId)
        if IsPlayerSpell(spellId) then
            table.insert(self.spellHistory, 1, {
                spell = spellId,
                time = GetTime()
            })
        end
    end)

    self:UpdateSkill()
    self:EnableRotation()
end

function addon:disable()
    self:DisableRotation()
    if self.playerUnitFrame ~= nil then
        self.playerUnitFrame:UnregisterAllEvents()
    end
    self.playerUnitFrame = nil
    self.spellHistory = {}
    self.combatHistory = {}
    self:UnregisterAllEvents()
end

function addon:OnEnable()
    self:info(L["Starting up version %s"], GetAddOnMetadata(addon_name, "Version"))

    if self.db.profile.live_config_update and not self.conditionEvalTimer then
        self.conditionEvalTimer = self:ScheduleRepeatingTimer('UpdateCurrentCondition', self.db.profile.live_config_update)
    end

    if self.db.profile.enable then
        self:enable()
    end
end

function addon:rotationValidConditions(rot, spec)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    -- We found a cooldown OR a rotation step
    local itemfound = false
    if rot.cooldowns ~= nil then
        -- All cooldowns are valid
        for _, v in pairs(rot.cooldowns) do
            if not v.disabled then
                if (v.type == nil or v.action == nil or not self:validateCondition(v.conditions, spec)) then
                    return false
                end
                if v.type == "item" then
                    if type(v.action) == "string" then
                        local itemset
                        if itemsets[v.action] ~= nil then
                            itemset = itemsets[v.action]
                        elseif global_itemsets[v.action] ~= nil then
                            itemset = global_itemsets[v.action]
                        end
                        if not itemset or #itemset.items == 0 then
                            return false
                        end
                    else
                        if #v.action == 0 then
                            return false
                        end
                    end
                end
                itemfound = true
            end
        end
    end
    if rot.rotation ~= nil then
        -- All rotation steps are valid
        for _, v in pairs(rot.rotation) do
            if not v.disabled then
                if (v.type == nil or not self:validateCondition(v.conditions, spec)) then
                    return false
                end
                if (v.type ~= "none" and v.action == nil) then
                    return false
                end
                if v.type == "item" then
                    if type(v.action) == "string" then
                        local itemset
                        if itemsets[v.action] ~= nil then
                            itemset = itemsets[v.action]
                        elseif global_itemsets[v.action] ~= nil then
                            itemset = global_itemsets[v.action]
                        end
                        if not itemset or #itemset.items == 0 then
                            return false
                        end
                    else
                        if #v.action == 0 then
                            return false
                        end
                    end
                end
                itemfound = true
            end
        end
    end

    return itemfound
end

function addon:UpdateAutoSwitch()
    self.autoswitchRotation = {}

    if self.db.char.rotations[self.currentSpec] ~= nil then
        for id, rot in pairs(self.db.char.rotations[self.currentSpec]) do
            if id ~= DEFAULT then
                -- The switch condition is nontrivial and valid.
                if rot.switch and not rot.disabled and addon:usefulCondition(rot.switch) and
                        self:validateCondition(rot.switch, self.currentSpec) and
                        self:rotationValidConditions(rot, self.currentSpec) then
                    addon:debug(L["Rotaion " .. color.WHITE .. "%s" .. color.DEBUG .. " is now available for auto-switching."], rot.name)
                    table.insert(self.autoswitchRotation, id)
                end
            end
        end
    end

    -- We autoswitch to the lowest (alphabetically) matching rotation.
    table.sort(self.autoswitchRotation, function(lhs, rhs)
        return self.db.char.rotations[self.currentSpec][lhs].name <
                self.db.char.rotations[self.currentSpec][rhs].name
    end)

    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figure out which of the autoswitch rotations best matches
function addon:SwitchRotation()
    if self.db.profile.disable_autoswitch or self.manualRotation then
        return
    end

    local newRotation
    for _, v in pairs(self.autoswitchRotation) do
        if addon:evaluateCondition(self.db.char.rotations[self.currentSpec][v].switch) then
            newRotation = v
            break
        end
    end
    if not newRotation and self.db.char.rotations[self.currentSpec] ~= nil and
        self.db.char.rotations[self.currentSpec][DEFAULT] ~= nil and
        self:rotationValidConditions(self.db.char.rotations[self.currentSpec][DEFAULT], self.currentSpec) then
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
    DataBroker.text = color.RED .. OFF
    AceEvent:SendMessage("ROTATIONMASTER_ROTATION", nil)
    addon:info(L["Battle rotation disabled"])
end

function addon:EnableRotationTimer()
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

local function announce(cache, cond, text)
    local dest
    if cond.announce == "local" then
        addon:announce(text)
    elseif cond.announce == "partyraid" then
        if getCached(cache, IsInRaid) then
            dest = "RAID"
        elseif getCached(cache, IsInGroup) then
            dest = "PARTY"
        else
            addon:announce(text)
        end
    elseif cond.announce == "party" then
        if getCached(cache, IsInGroup) then
            dest = "PARTY"
        end
    elseif cond.announce == "raidwarn" then
        if getCached(cache, IsInRaid) then
            if getCached(cache, IsRaidLeader) then
                dest = "RAID_WARNING"
            else
                dest = "RAID"
            end
        elseif getCached(cache, IsInGroup) then
            dest = "PARTY"
        else
            addon:announce(text)
        end
    elseif cond.announce == "say" then
        dest = "SAY"
    elseif cond.announce == "yell" then
        dest = "YELL"
    elseif cond.announce == "emote" then
        dest = "EMOTE"
    end
    if dest ~= nil then
        SendChatMessage(text, dest)
    end
    if cond.announce_sound then
        PlaySoundFile(Media:Fetch("sound", cond.announce_sound), "Master")
    end
end

function addon:EvaluateNextAction()
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
    elseif self.db.char.rotations[self.currentSpec] ~= nil and
            self.db.char.rotations[self.currentSpec][self.currentRotation] ~= nil then
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

        -- The common way to evaluate any rotation or cooldown condition.
        local function eval(cond)
            local spellid, enabled = nil, false
            if cond.action ~= nil and (cond.disabled == nil or cond.disabled == false) then
                local spellids, itemids
                if cond.type ~= "any" or getCached(addon.longtermCache, IsSpellKnown, cond.action, false) or
                                         getCached(cache, IsSpellKnown, cond.action, true) then
                    spellids, itemids = addon:GetSpellIds(cond)
                end

                if spellids ~= nil then
                    local idx
                    spellid, idx = addon:FindSpell(spellids)
                    if (spellid and addon:evaluateCondition(cond.conditions)) then
                        local avail, nomana = getCached(cache, IsUsableSpell, spellid)
                        if avail and (self.db.profile.ignore_mana or not nomana) then
                            if self.db.profile.ignore_range then
                                enabled = true
                            else
                                local inrange
                                if cond.type == BOOKTYPE_SPELL or cond.type == BOOKTYPE_PET then
                                    local sbid = getCached(cond.type == BOOKTYPE_SPELL and addon.longtermCache or cache,
                                                           FindSpellBookSlotBySpellID, spellid, cond.type == BOOKTYPE_PET)
                                    inrange = getCached(cache, IsSpellInRange, sbid, cond.type, "target")
                                elseif cond.type == "any" then
                                    local sbid = getCached(addon.longtermCache, FindSpellBookSlotBySpellID, spellid, false)
                                    if sbid ~= nil then
                                        inrange = getCached(cache, IsSpellInRange, sbid, BOOKTYPE_SPELL, "target")
                                    else
                                        sbid = getCached(cache, FindSpellBookSlotBySpellID, spellid, true)
                                        if sbid ~= nil then
                                            inrange = getCached(cache, IsSpellInRange, sbid, BOOKTYPE_PET, "target")
                                        end
                                    end
                                elseif cond.type == "item" then
                                    inrange = getCached(cache, IsItemInRange, itemids[idx], "target")
                                end
                                enabled = (inrange ~= nil and inrange or true)
                            end
                        end
                    end
                end
            end
            return spellid, enabled
        end

        self.evaluationProfile:child("rotation"):start()
        local rot = self.db.char.rotations[self.currentSpec][self.currentRotation]
        if rot.rotation ~= nil then
            local enabled
            for id, cond in pairs(rot.rotation) do
                if cond.type == "none" and (cond.disabled == nil or cond.disabled == false) and
                        addon:evaluateCondition(cond.conditions) then
                    break
                end
                local spellid
                spellid, enabled = eval(cond)
                if spellid and enabled then
                    addon:verbose("Rotation step %d satisfied it's condition.", id)
                    if not addon:IsGlowing(spellid) then
                        addon:GlowNextSpell(spellid)
                        if WeakAuras then
                            WeakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", cond.type, spellid)
                        end
                        AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
                    end
                    break
                else
                    addon:verbose("Rotation step %d did not satisfy it's condition.", id)
                end
            end
            if not enabled then
                addon:GlowClear()
                if WeakAuras then
                    WeakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
                end
                AceEvent:SendMessage("ROTATIONMASTER_SPELL_UPDATE", self.currentRotation, nil)
            end
        end
        self.evaluationProfile:child("rotation"):stop()
        self.evaluationProfile:child("cooldowns"):start()
        if rot.cooldowns ~= nil then
            local enabled_cooldowns = {}
            local disabled_cooldowns = {}
            for id, cond in pairs(rot.cooldowns) do
                local spellid, enabled = eval(cond)
                if spellid then
                    if enabled then
                        addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)
                        if addon.avail_announced[cond.id] ~= spellid then
                            if not addon.skipAnnounce then
                                local link = SpellData:SpellLink(spellid)
                                announce(cache, cond, string.format(L["%s is now available!"], link))
                            end
                            addon.avail_announced[cond.id] = spellid;
                            AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
                        end
                        if not enabled_cooldowns[spellid] then
                            enabled_cooldowns[spellid] = cond
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
                addon:GlowCooldown(spellid, true, cond)
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
                    return SpellData:GetAllSpellIds(rot.action) or {}
                end
            else
                return { rot.action }
            end
        elseif rot.type == "item" then
            local spellids = {}
            local itemids = {}
            if type(rot.action) == "string" then
                local itemset
                if self.db.char.itemsets[rot.action] ~= nil then
                    itemset = self.db.char.itemsets[rot.action]
                elseif self.db.global.itemsets[rot.action] ~= nil then
                    itemset = self.db.global.itemsets[rot.action]
                end

                if itemset ~= nil then
                    for _, item in ipairs(itemset.items) do
                        local spellid = select(2, getRetryCached(self.longtermCache, GetItemSpell, item));
                        if spellid then
                            table.insert(spellids, spellid)
                            if isint(item) then
                                table.insert(itemids, item)
                            else
                                local itemid = getRetryCached(self.longtermCache, GetItemInfoInstant, item)
                                table.insert(itemids, itemid)
                            end
                        end
                    end
                end
            else
                for _, item in ipairs(rot.action) do
                    local spellid = select(2, getRetryCached(self.longtermCache, GetItemSpell, item));
                    if spellid then
                        table.insert(spellids, spellid)
                        if isint(item) then
                            table.insert(itemids, item)
                        else
                            local itemid = getRetryCached(self.longtermCache, GetItemInfoInstant, item)
                            table.insert(itemids, itemid)
                        end
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
    if self.currentSpec ~= nil and self.currentRotation ~= nil and
        self.db.char.rotations[self.currentSpec][self.currentRotation] ~= nil and
        self.db.char.rotations[self.currentSpec][self.currentRotation].cooldowns ~= nil then
        for _, rot in pairs(self.db.char.rotations[self.currentSpec][self.currentRotation].cooldowns) do
            for _, spellid in pairs(addon:GetSpellIds(rot)) do
                addon:GlowCooldown(spellid, false)
            end
        end
        addon:GlowClear()
    end
end

function addon:UpdateSpecSpells()
    local currentSpecSpells = SpellData:UpdateFromSpellBook(self.currentSpec)
    for spec,spells in pairs(currentSpecSpells) do
        if not self.specSpells[spec] or spec ~= BOOKTYPE_PET then
            self.specSpells[spec] = {}
            self.specSpellsReverse[spec] = {}
        end
        for spell,v in pairs(spells) do
            self.specSpells[spec][spell] = v
            self.specSpellsReverse[spec][SpellData:SpellName(spell, true)] = spell
        end
    end
end

function addon:UpdateSkill()
    addon:verbose("Skill update triggered")
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        local spec = GetSpecializationInfo(addon:GetSpecialization())
        if spec == nil then
            return
        end
        self.currentSpec = spec
        if self.specTab then
            self.specTab:SelectTab(spec)
        end
    elseif (LE_EXPANSION_LEVEL_CURRENT >= 2) then
        local spec = addon:GetSpecialization()
        if spec == nil then
            return
        end
        self.currentSpec = spec
        if self.specTab then
            self.specTab:SelectTab(tostring(spec))
        end
    end

    self:UpdateSpecSpells()
    self:UpdateAutoSwitch()
    self:SwitchRotation()
    self:ButtonFetch()

    self.longtermCache = {}
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        if self.specTalents[self.currentSpec] == nil then
            self.specTalents[self.currentSpec] = {}

            for i = 1, 21 do
                local _, name, icon = GetTalentInfo(floor((i - 1) / 3) + 1, ((i - 1) % 3) + 1, 1)
                self.specTalents[self.currentSpec][i] = {
                    name = name,
                    icon = icon
                }
            end
        end
    elseif (LE_EXPANSION_LEVEL_CURRENT >= 2) then
        if self.specTalents[self.currentSpec] == nil then
            self.specTalents[self.currentSpec] = {}

            for i = 1, GetNumTalentTabs() do
                self.specTalents[self.currentSpec][i] = {}
                for j = 1, GetNumTalents(i) do
                    local name, icon, _, _, rank = GetTalentInfo(i, j)
                    self.specTalents[self.currentSpec][i][j] = {
                        name = name,
                        icon = icon,
                        rank = rank
                    }
                end
            end
        end
    end
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
    local bindings = self.db.char.bindings

    if bindings[id] then
        for idx,slot in pairs(bindings[id]) do
            local type, actionType = GetActionInfo(slot);
            if type == "item" then
                local itemid = addon:FindFirstItemOfItemSet({}, id, true)
                if itemid and itemid ~= actionType then
                    addon:debug("Updated slot %s to new item %d", slot, itemid)
                    PickupItem(itemid)
                    PlaceAction(slot)
                    ClearCursor()
                end
            else
                table.remove(bindings[id], idx)
                if addon.tablelength(bindings[id]) < 1 then
                    bindings[id] = nil
                end
            end
        end
    end
end

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = addon.SwitchRotation
addon.PARTY_MEMBERS_CHANGED = addon.SwitchRotation
addon.PLAYER_FLAGS_CHANGED = addon.SwitchRotation
addon.UPDATE_SHAPESHIFT_FORM = function(var)
    local newForm = GetShapeshiftForm()
    if addon.currentForm ~= newForm then
        addon.currentForm = newForm
        -- addon.skipAnnounce = true
        -- We need the delay because multiple shapeshift events come in at once
        -- and there is no way to know which will be the final one.
        if addon.shapeshiftTimer == nil then
            addon.shapeshiftTimer = addon:ScheduleTimer(function ()
                addon.shapeshiftTimer = nil
                addon:SwitchRotation()
            end, 0.25)
            addon:ButtonFetch()
        end
    end
end
addon.UPDATE_STEALTH = addon.SwitchRotation

addon.ACTIONBAR_SLOT_CHANGED = function(self, _, slot)
    local bindings = self.db.char.bindings
    addon:ButtonFetch()

    local pickupItemSet
    for id, slots in pairs(bindings) do
        for idx, bslot in pairs(slots) do
            if bslot == slot then
                local type, action = GetCursorInfo()
                -- Sometimes we get this when we didn't actually pick up anything.  Odd.
                if type == "item" and addon:FindItemInItemSet(id, action) ~= nil then
                    pickupItemSet = id
                    table.remove(bindings[id], idx)
                    if addon.tablelength(bindings[id]) < 1 then
                        bindings[id] = nil
                    end
                    if addon.itemSetCallback then
                        addon.itemSetCallback(id)
                    end
                end
            end
        end
    end

    if addon.bindingItemSet then
        if not bindings[addon.bindingItemSet] then
            bindings[addon.bindingItemSet] = { slot }
        else
            table.insert(bindings[addon.bindingItemSet], slot)
        end
        if addon.itemSetCallback then
            addon.itemSetCallback(addon.bindingItemSet)
        end
        addon.bindingItemSet = nil
    end

    if pickupItemSet ~= nil then
        addon.bindingItemSet = pickupItemSet
    end
end

addon.PET_BAR_HIDEGRID = addon.ButtonFetch
addon.ACTIONBAR_HIDEGRID = addon.ButtonFetch
addon.PET_BAR_UPDATE = addon.ButtonFetch
addon.ACTIONBAR_PAGE_CHANGED = addon.ButtonFetch
addon.UPDATE_MACROS = addon.ButtonFetch
addon.VEHICLE_UPDATE = addon.ButtonFetch

function addon:PLAYER_TARGET_CHANGED()
    addon:verbose("Player targeted something else.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self.lastMainSwing = nil
    self.lastOffSwing = nil

    self:EvaluateNextAction()
end

addon.PLAYER_FOCUS_CHANGED = function()
    addon:PLAYER_TARGET_CHANGED()
end

function addon:UNIT_PET(unit)
    if unit == "pet" then
        addon:verbose("Player %s changed pet.", unit)
        self:UpdateSpecSpells()

        if not self.inCombat then
            self:SwitchRotation()
        end

        self:EvaluateNextAction()
    end
end

function addon:PLAYER_CONTROL_GAINED()
    addon:verbose("Player regained control.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self:EnableRotationTimer()
    self:EvaluateNextAction()
end

function addon:UpdateBagContents(cache)
    self.bagContents = {}
    for i=0,4 do
        for j=1, GetContainerNumSlots(i) do
            local _, qty, _, _, _, _, _, _, _, itemId = getCached(cache, GetContainerItemInfo, i, j);
            if itemId then
                if self.bagContents[itemId] == nil then
                    self.bagContents[itemId] = {
                        count = qty,
                        spell = getRetryCached(addon.longtermCache, GetItemSpell, itemId),
                        slots = { j }
                    }
                else
                    self.bagContents[itemId].count = self.bagContents[itemId].count + qty
                    table.insert(self.bagContents[itemId].slots, j)
                end
            end
        end
    end
end

function addon:PLAYER_CONTROL_LOST()
    addon:verbose("Player lost control.")
    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
end

addon.PLAYER_TALENT_UPDATE = addon.UpdateSkill
addon.ACTIVE_TALENT_GROUP_CHANGED = addon.UpdateSkill
addon.SPELLS_CHANGED = addon.UpdateSkill
addon.CHARACTER_POINTS_CHANGED = addon.UpdateSkill
addon.PLAYER_SPECIALIZATION_CHANGED = addon.UpdateSkill
addon.LEARNED_SPELL_IN_TAB = addon.UpdateSkill

function addon:ZONE_CHANGED()
    addon:verbose("Player switched zones.")
    if not self.inCombat then
        self:SwitchRotation()
    end
end

addon.ZONE_CHANGED_INDOORS = addon.ZONE_CHANGED
addon.GROUP_ROSTER_UPDATE = addon.ZONE_CHANGED

function addon:PLAYER_ENTERING_WORLD()
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets
    local bindings = self.db.char.bindings

    addon:verbose("Player entered world.")
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
end

function addon:PLAYER_REGEN_DISABLED()
    addon:verbose("Player is in combat.")
    self.inCombat = true
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.combatCache = {}
end

function addon:PLAYER_REGEN_ENABLED()
    addon:verbose("Player is out of combat.")
    self.inCombat = false
    self.lastMainSwing = nil
    self.lastOffSwing = nil
    self.combatCache = {}

    addon:SwitchRotation()

    -- Item Slots can't be updated while in combat.
    for id, _ in pairs(addon.db.char.bindings) do
        self:UpdateBoundButton(id)
    end

    for id, _ in pairs(addon.db.char.itemsets) do
        self:UpdateItemSetButtons(id)
    end
    for id, _ in pairs(addon.db.global.itemsets) do
        self:UpdateItemSetButtons(id)
    end
end

function addon:UNIT_ENTERED_VEHICLE(_, unit)
    if unit == "player" then
        addon:verbose("Player on a vehicle.")
        addon:PLAYER_CONTROL_LOST()
    end
end

function addon:UNIT_EXITED_VEHICLE(_, unit)
    if unit == "player" then
        addon:verbose("Player off a vehicle.")
        addon:PLAYER_CONTROL_GAINED()
    end
end

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        self.unitsInRange[guid].unit = unit
    else
        self.unitsInRange[guid] = CreateUnitInfo({}, unit)
    end
end

function addon:NAME_PLATE_UNIT_REMOVED(_, unit)
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
end

function addon:BAG_UPDATE()
    local bindings = self.db.char.bindings

    for id, _ in pairs(bindings) do
        self:UpdateBoundButton(id)
    end

    self:UpdateBagContents()
end

function addon:UNIT_COMBAT(_, unit, action, severity, value, type)
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
end

local currentSpells = {}
local lastCastTarget = {} -- work around UNIT_SPELLCAST_SENT not always triggering
local currentChannel

local function spellcast(_, event, unit, castguid, spellid)
    -- even though we check it later, this skips rows entirely.
    if unit == 'player' or unit == "pet" then
        for _, value in ipairs(addon.db.char.announces) do
            if value.value and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
                (event == "UNIT_SPELLCAST_" .. value.event or event == "UNIT_SPELLCAST_CHANNEL_" .. value.event) then
                local skip = false
                if addon.announced[value.id] then
                    for _, val in ipairs(addon.announced[value.id]) do
                        if val == castguid then
                            skip = true
                        end
                    end
                end

                if not skip then
                    local ent = addon.deepcopy(value)
                    if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                        ent.action = ent.spell
                    elseif unit == ent.type == "item" then
                        ent.action = ent.item
                    end

                    local spellids, itemids = addon:GetSpellIds(ent)
                    for idx, sid in ipairs(spellids) do
                        if spellid == sid then
                            local text = ent.value
                            if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                                local link = SpellData:SpellLink(sid)
                                text = text:gsub("{{spell}}", link)
                            elseif ent.type == "item" then
                                local link = select(2, getRetryCached(addon.longtermCache, GetItemInfo, itemids[idx]))
                                text = text:gsub("{{item}}", link)
                            end
                            text = text:gsub("{{event}}", addon.events[ent.event])
                            if currentSpells[castguid] or lastCastTarget[spellid] then
                                text = text:gsub("{{target}}", currentSpells[castguid] or lastCastTarget[spellid])
                            end
                            announce({}, ent, text)
                            if addon.announced[value.id] == nil then
                                addon.announced[value.id] = { castguid }
                            else
                                table.insert(addon.announced[value.id], castguid)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

addon.UNIT_SPELLCAST_START = spellcast
addon.UNIT_SPELLCAST_STOP = function(_, event, unit, castguid, spellid)
    spellcast(_, event, unit, castguid, spellid)
    if unit == 'player' then
        currentSpells[castguid] = nil
        addon.lastMainSwing = nil
        addon.lastOffSwing = nil
    end
end
addon.UNIT_SPELLCAST_SUCCEEDED = function(_, event, unit, castguid, spellid)
    spellcast(_, event, unit, castguid, spellid)
    if unit == 'player' then
        if currentChannel then
            currentChannel = castguid
        end
    end
end
addon.UNIT_SPELLCAST_INTERRUPTED = spellcast
addon.UNIT_SPELLCAST_FAILED = spellcast
addon.UNIT_SPELLCAST_DELAYED = spellcast
addon.UNIT_SPELLCAST_CHANNEL_START = function(_, event, unit, castguid, spellid)
    spellcast(_, event, unit, castguid, spellid)
    if unit == 'player' then
        currentChannel = true
    end
end
addon.UNIT_SPELLCAST_CHANNEL_STOP = function(_, event, unit, castguid, spellid)
    spellcast(_, event, unit, castguid, spellid)
    if unit == 'player' then
        if currentChannel ~= nil then
            currentSpells[currentChannel] = nil
        end
        currentChannel = nil
        addon.lastMainSwing = nil
        addon.lastOffSwing = nil
    end
end

addon.UNIT_SPELLCAST_SENT = function(_, _, unit, target, castguid, spellid)
    if (unit == 'player') then
        currentSpells[castguid] = target
        lastCastTarget[spellid] = target
    end
end

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
addon.COMBAT_LOG_EVENT_UNFILTERED = function() handle_combat_log(CombatLogGetCurrentEventInfo()) end

addon.SPELL_DATA_LOAD_RESULT = function(self, _, spellId, success)
    if success then
        SpellData:UpdateSpell(spellId)
    end
end

addon.ITEM_DATA_LOAD_RESULT = function(self, _, itemId, success)
    if success then
        ItemData:UpdateItem(itemId)
    end
end