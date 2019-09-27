local addon_name, addon = ...

local _G = _G

_G.RotationMaster = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local SpellRange = LibStub("SpellRange-1.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local getCached
local DBIcon = LibStub("LibDBIcon-1.0")

local ThreatClassic = LibStub("ThreatClassic-1.0")
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    ThreatClassic:Disable()
else
    UnitThreatSituation = ThreatClassic.UnitThreatSituation

    local LibClassicDurations = LibStub("LibClassicDurations")
    LibClassicDurations:Register(addon_name)
end

local pairs, color, string = pairs, color, string
local floor = math.floor

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")
local DataBroker = LibStub("LibDataBroker-1.1"):NewDataObject("RotationMaster",
        { type = "data source", label = addon.pretty_name, icon = "Interface\\AddOns\\RotationMaster\\textures\\RotationMaster-Minimap" })

--
-- Initialization
--

BINDING_HEADER_ROTATIONMASTER = addon.pretty_name
BINDING_NAME_ROTATIONMASTER_TOGGLE = string.format(L["Toggle %s"], addon.pretty_name)

local defaults = {
    profile = {
        enable = true,
        poll = 0.15,
        ignore_mana = false,
        ignore_range = false,
        effect = "Ping",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = 'CENTER',
        xoffs = 0,
        yoffs = 0,
        debug = false,
        verbose = false,
        disable_autoswitch = false,
        live_config_update = 2,
        spell_history = 60,
        minimap = {
            hide = false,
        }
    },
    char = {
        rotations = {},
        itemsets = {},
        bindings = {},
    },
    global = {
        itemsets = {
            ["e626834f-60b1-413f-9c87-8ddeeb4374aa"] = {
                name = "Conjured Food",
                items = { 22895, 8076, 8075, 1487, 1114, 1113, 5349, },
            },
            ["3b10f7d6-abb2-430c-b153-7189eca75838"] = {
                name = "Conjured Water",
                items = { 8079, 8078, 8077, 3772, 2136, 2288, 5350, },
            },
        },
        effects = {
            {
                type = "texture",
                name = "Ping",
                texture = "Interface\\Cooldown\\ping4",
            },
            {
                type = "texture",
                name = "Star",
                texture = "Interface\\Cooldown\\star4",
            },
            {
                type = "texture",
                name = "Starburst",
                texture = "Interface\\Cooldown\\starburst",
            },
            {
                type = "blizzard",
                name = "Glow",
            },
            {
                type = "pixel",
                name = "Pixel",
            },
            {
                type = "autocast",
                name = "Auto Cast",
            }
        },
    }
}
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    defaults.global.itemsets["e8d1525c-0412-40c1-95a4-00da22bc169e"] = {
        name = "Combination Conjured Food",
        items = { 113509, 80618, 80610, 65499, 43523, 43518, 65517, 65516, 65515, 65500, }
    }
    defaults.global.itemsets["6079c534-5f69-430e-b1bd-b487a31dcdd3"] = {
        name = "Mana Potions",
        items = { 152495, 127835, 109222, 76098, 57192, 33448, 40067, 31677, 22732, 28101, 13444, 13443, 6149, 3827, 3385, 2455, },
    }
    defaults.global.itemsets["9294d112-681b-43bc-ac62-5d6bec5c1f7d"] = {
        name = "Healing Potions",
        items = { 169451, 152494, 127834, 152615, 109223, 57191, 39671, 22829, 28100, 13446, 3928, 1710, 929, 858, 118, },
    }
    defaults.global.itemsets["e66d5cfe-a0f0-4276-aa00-40464eab30df"] = {
        name = "Bandages",
        items = { 158382, 158381, 133942, 133940, 111603, 72986, 72985, 53051, 53050, 53049, 34722, 34721,
                  21991, 21990, 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251, },
    }
    defaults.global.itemsets["fed2659d-cb7b-43e1-8f53-6dda0391b8c6"] = {
        name = "Healthstones",
        items = {
            "Legion Healthstone",
            "Fel Healthstone",
            "Demonic Healthstone",
            "Master Healthstone",
            "Major Healthstone",
            "Greater Healthstone",
            "Healthstone",
            "Lesser Healthstone",
            "Minor Healthstone",
        },
    }
else
    defaults.global.itemsets["6079c534-5f69-430e-b1bd-b487a31dcdd3"] = {
        name = "Mana Potions",
        items = { 13444, 13443, 6149, 3827, 3385, 2455, },
    }
    defaults.global.itemsets["9294d112-681b-43bc-ac62-5d6bec5c1f7d"] = {
        name = "Healing Potions",
        items = { 13446, 3928, 1710, 929, 858, 118, },
    }
    defaults.global.itemsets["e66d5cfe-a0f0-4276-aa00-40464eab30df"] = {
        name = "Bandages",
        items = { 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251, },
    }
    defaults.global.itemsets["fed2659d-cb7b-43e1-8f53-6dda0391b8c6"] = {
        name = "Healthstones",
        items = {
            "Major Healthstone",
            "Greater Healthstone",
            "Healthstone",
            "Lesser Healthstone",
            "Minor Healthstone",
        },
    }
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
    'PLAYER_ENTERING_WORLD',
    'ACTIONBAR_HIDEGRID',
    'ACTIONBAR_PAGE_CHANGED',
    'LEARNED_SPELL_IN_TAB',
    'UPDATE_MACROS',

    -- Special Purpose
    'NAME_PLATE_UNIT_ADDED',
    'NAME_PLATE_UNIT_REMOVED',

    'CURSOR_UPDATE',
    'BAG_UPDATE',
}

local mainline_events = {
    'PLAYER_FOCUS_CHANGED',
    'VEHICLE_UPDATE',
    'UNIT_ENTERED_VEHICLE',
    'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED',
    'PLAYER_SPECIALIZATION_CHANGED',
}

local classic_events = {

}

function addon:HandleCommand(str)

    local cmd, npos = AceConsole:GetArgs(str, 1, 1)

    if not cmd or cmd == "help" then
        addon:info(L["/rm help                - This text"])
        addon:info(L["/rm config              - Open the config dialog"])
        addon:info(L["/rm disable             - Disable battle rotation"])
        addon:info(L["/rm enable              - Enable battle rotation"])
        addon:info(L["/rm current             - Print out the name of the current rotation"])
        addon:info(L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."])
        addon:info(L["                          This is reset upon switching specializations."])

    elseif cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(addon.Rotation)
        InterfaceOptionsFrame_OpenToCategory(addon.Rotation)

    elseif cmd == "disable" then
        addon:disable()

    elseif cmd == "enable" then
        addon:enable()

    elseif cmd == "current" then
        if self.currentRotation == nil then
            addon:info(L["No rotation is currently active."])
        else
            addon:info(L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO], addon:GetRotationName(self.currentRotation))
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

    self:upgrade()

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

    -- This is a list of rotations that are available (ie. they are complete).  So we don't
    -- have to call validate in a time of battle.
    self.autoswitchRotation = {}

    self.currentRotation = nil

    self.manualRotation = false

    self.inCombat = false

    self.rotationTimer = nil

    self.fetchTimer = nil

    -- This is a cache of spec based spell names -> IDs.  Updated when we switch specs.
    self.specSpells = nil

    self.specTalents = {}

    self.unitsInRange = {}

    self.spellHistory = {}
    self.playerUnitFrame = nil

    self.announced = {}
    self.skipAnnounce = true

    self.currentConditionEval = nil
    self.conditionEvalTimer = nil
    self.lastCacheReport = GetTime()

    self.itemSetCallback = nil
    self.bindingItemSet = nil

    self.evaluationProfile = addon:ProfiledCode()

    -- This is here because of order of loading.
    getCached = addon.getCached

    -- This will cache the items so that we can USE them for harmful_distance calculations.
    for id, _ in pairs(addon.friendly_distance) do
        IsItemInRange(id, "player")
    end
    for id, _ in pairs(addon.harmful_distance) do
        IsItemInRange(id, "player")
    end
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

local function minimapToggleRotation(self, arg1, arg2, checked)
    if checked then
        addon:enable()
    else
        addon:disable()
    end
end

local function minimapChangeRotation(self, arg1, arg2, checked)
    if arg1 == nil then
        addon.manualRotation = false
        addon:SwitchRotation()
    else
        addon.manualRotation = true
        if addon.currentSpec ~= arg1 then
            addon:RemoveAllCurrentGlows()
            addon.currentRotation = arg1
            addon.skipAnnounce = true
            addon.announced = {}
            addon:EnableRotationTimer()
            DataBroker.text = addon:GetRotationName(arg1)
            AceEvent:SendMessage("ROTATIONMASTER_ROTATION", addon.currentRotation, addon:GetRotationName(addon.currentRotation))
        end
        addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],
                addon:GetRotationName(arg1))
    end
end

function minimapInitialize(self, level, menuList)
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

function DataBroker.OnClick(self, button)
    local frame = CreateFrame("Frame", "RotationMasterLDBFrame")
    local dropdownFrame = CreateFrame("Frame", "RotationMasterLDBDropdownFrame", frame, "UIDropDownMenuTemplate")

    if button == "RightButton" then
        UIDropDownMenu_Initialize(dropdownFrame, minimapInitialize)
        ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
    elseif button == "LeftButton" then
        InterfaceOptionsFrame_OpenToCategory(addon.Rotation)
        InterfaceOptionsFrame_OpenToCategory(addon.Rotation)
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
    for k, v in pairs(events) do
        self:RegisterEvent(v)
    end
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        self.currentSpec = GetSpecializationInfo(GetSpecialization())
        if self.specTab then
            self.specTab:SelectTab(self.currentSpec)
        end
        for k, v in pairs(mainline_events) do
            self:RegisterEvent(v)
        end
    else
        self.currentSpec = 0
        for k, v in pairs(classic_events) do
            self:RegisterEvent(v)
        end
    end

    self.playerUnitFrame = CreateFrame('Frame')
    self.playerUnitFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')

    self.playerUnitFrame:SetScript('OnEvent', function(_, event, unit, lineId, spellId)
        if IsPlayerSpell(spellId) then
            table.insert(self.spellHistory, 1, {
                spell = spellId,
                time = GetTime()
            })
        end
    end)

    self:UpdateSkills()
    self:EnableRotation()
end

function addon:disable()
    self:DisableRotation()
    if self.playerUnitFrame ~= nil then
        self.playerUnitFrame:UnregisterAllEvents()
    end
    self.playerUnitFrame = nil
    self.spellHistory = {}
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
        for k, v in pairs(rot.cooldowns) do
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
        for k, v in pairs(rot.rotation) do
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

    return itemfound
end

function addon:UpdateAutoSwitch()
    self.autoswitchRotation = {}

    if self.db.char.rotations[self.currentSpec] ~= nil then
        for id, rot in pairs(self.db.char.rotations[self.currentSpec]) do
            if id ~= DEFAULT then
                -- The switch condition is nontrivial and valid.
                if rot.switch and not rot.disabled and addon:usefulSwitchCondition(rot.switch) and
                        self:validateSwitchCondition(rot.switch, self.currentSpec) and
                        self:rotationValidConditions(rot, self.currentSpec) then
                    addon:debug(L["Rotaion " .. color.WHITE .. "%s" .. color.DEBUG .. " is now available for auto-switching."], rot.name)
                    table.insert(self.autoswitchRotation, id)
                    break
                end
            end
        end
    end

    -- We autoswitch to the lowest (alphabetically) matching rotation.
    table.sort(self.autoswitchRotation, function(lhs, rhs)
        return self.db.char.rotations[self.currentSpec][lhs].name <
                self.db.char.rotations[self.currentSpec][rhs].name
    end)

    if self.db.char.rotations[self.currentSpec] ~= nil and self.db.char.rotations[self.currentSpec][DEFAULT] ~= nil and
            self:rotationValidConditions(self.db.char.rotations[self.currentSpec][DEFAULT]) then
        addon:debug(L["Rotaion " .. color.WHITE .. "%s" .. color.DEBUG .. " is now available for auto-switching."], DEFAULT)
        table.insert(self.autoswitchRotation, DEFAULT)
    end
    addon:debug(L["Autoswitch rotation list has been updated."])
end

-- Figure out which of the autoswitch rotations best matches
function addon:SwitchRotation()
    if self.db.profile.disable_autoswitch or self.manualRotation then
        return
    end

    for k, v in pairs(self.autoswitchRotation) do
        if addon:evaluateSwitchCondition(self.db.char.rotations[self.currentSpec][v].switch) then
            if self.currentRotation ~= v then
                addon:info(L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO], self:GetRotationName(v))
                self:RemoveAllCurrentGlows()
                self.currentRotation = v
                self.skipAnnounce = true
                self.announced = {}
                self:EnableRotationTimer()
                DataBroker.text = self:GetRotationName(v)
                AceEvent:SendMessage("ROTATIONMASTER_ROTATION", self.currentRotation, self:GetRotationName(self.currentRotation))
            end
            return
        end
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
    self:DestroyAllOverlays()
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
    self.fetchTimer = self:ScheduleTimer('Fetch', 0.5)
end

local function UpdateUnitInfo(cache, unit, record)
    if record.attackable then
        record.enemy = getCached(cache, UnitIsEnemy, "plater", unit)
        if record.enemy then
            record.threat = getCached(cache, UnitThreatSituation, "player", unit)
        else
            record.threat = nil
        end
    end
    --record.health = getCached(cache, UnitHealth, unit)
    --record.inrange = getCached(cache, UnitInRange, unit)
end

local function announce_cooldown(cache, cond, spellid)
    local dest
    if cond.announce == "partyraid" then
        if getCached(cache, IsInRaid) then
            dest = "RAID"
        elseif getCached(cache, IsInGroup) then
            dest = "PARTY"
        end
    elseif cond.announce == "party" then
        dest = "PARTY"
    elseif cond.announce == "raidwarn" then
        dest = "RAID_WARNING"
    elseif cond.announce == "say" then
        dest = "SAY"
    elseif cond.announce == "yell" then
        dest = "YELL"
    end
    if dest ~= nil then
        local link = getCached(addon.longtermCache, GetSpellLink, spellid)
        SendChatMessage(string.format(L["%s is now available!"], link), dest)
    end
end

function addon:EvaluateNextAction()
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
    elseif self.db.char.rotations[self.currentSpec] ~= nil and
            self.db.char.rotations[self.currentSpec][self.currentRotation] ~= nil then
        self.evaluationProfile:start()

        local cache = {}
        if not self.inCombat then
            self.combatCache = cache
        end

        self.evaluationProfile:child("environment"):start()
        for unit, entity in pairs(self.unitsInRange) do
            addon:verbose("Updating Unit " .. unit .. " (" .. entity.name .. ")")
            UpdateUnitInfo(cache, unit, entity)
        end

        local threshold_time = GetTime() - self.db.profile.spell_history
        while true do
            if #self.spellHistory == 0 then
                break
            end

            if self.spellHistory[#self.spellHistory].time < threshold_time then
                table.remove(self.spellHistory, #self.spellHistory)
            else
                break
            end
        end
        self.evaluationProfile:child("environment"):stop()

        -- The common way to evaluate any rotation or cooldown condition.
        local function eval(cond)
            local spellid, enabled = nil, false
            if cond.action ~= nil and (cond.disabled == nil or cond.disabled == false) then
                local spellids
                if cond.type ~= "pet" or getCached(self.longtermCache, IsSpellKnown, cond.action, true) then
                    spellids = addon:GetSpellIds(cond)
                end

                if spellids ~= nil then
                    spellid = addon:FindSpell(spellids)
                    if (spellid and addon:evaluateCondition(cond.conditions)) then
                        local avail, nomana = getCached(cache, IsUsableSpell, spellid)
                        if avail and (self.db.profile.ignore_mana or not nomana) then
                            if self.db.profile.ignore_range then
                                enabled = true
                            else
                                local inrange = getCached(cache, SpellRange.IsSpellInRange, spellid, "target")
                                if inrange == nil then
                                    enabled = true
                                else
                                    enabled = (inrange == 1)
                                end
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
            for id, cond in pairs(rot.cooldowns) do
                local spellid, enabled = eval(cond)
                if spellid then
                    if enabled then
                        addon:verbose("Cooldown %d [%s] is enabled", id, cond.id)
                        if addon.announced[cond.id] ~= spellid then
                            if not addon.skipAnnounce then
                                announce_cooldown(cache, cond, spellid)
                            end
                            addon.announced[cond.id] = spellid;
                            AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, cond.type, spellid)
                        end
                    else
                        if addon.announced[cond.id] then
                            addon.announced[cond.id] = nil;
                            AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                        end
                        addon:verbose("Cooldown %d [%s] is disabled", id, cond.id)
                    end
                    addon:GlowCooldown(spellid, enabled, cond)
                else
                    if addon.announced[cond.id] then
                        addon.announced[cond.id] = nil;
                        AceEvent:SendMessage("ROTATIONMASTER_COOLDOWN_UPDATE", self.currentRotation, id, cond.id, nil)
                    end
                end
            end
        end
        self.evaluationProfile:child("cooldowns"):stop()

        -- We only skip the FIRST cycle of enabling/disabling cooldowns.
        addon.skipAnnounce = false

        self.evaluationProfile:stop()
    end

    if GetTime() - self.lastCacheReport > 15 then
        addon:ReportCacheStats()
        addon:debug("%s", self.evaluationProfile:report())
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
    if rot.type == "spell" or rot.type == "pet" then
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
        if rot.action then
            local spellids = {}
            if type(rot.action) == "string" then
                local itemset = nil
                if self.db.char.itemsets[rot.action] ~= nil then
                    itemset = self.db.char.itemsets[rot.action]
                elseif self.db.global.itemsets[rot.action] ~= nil then
                    itemset = self.db.global.itemsets[rot.action]
                end
                if itemset ~= nil then
                    for _, item in ipairs(itemset.items) do
                        local spellid = select(2, getCached(self.longtermCache, GetItemSpell, item));
                        if spellid then
                            table.insert(spellids, spellid)
                        end
                    end
                    return spellids
                end
            else
                for _, item in ipairs(rot.action) do
                    local spellid = select(2, getCached(self.longtermCache, GetItemSpell, item));
                    if spellid then
                        table.insert(spellids, spellid)
                    end
                end
                return spellids
            end
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
        for id, rot in pairs(self.db.char.rotations[self.currentSpec][self.currentRotation].cooldowns) do
            for _, spellid in pairs(addon:GetSpellIds(rot)) do
                addon:GlowCooldown(spellid, false)
            end
        end
        addon:GlowClear()
    end
end

function addon:UpdateSkills()
    addon:verbose("Skill update triggered")
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        local spec = GetSpecializationInfo(GetSpecialization())
        if spec == nil then
            return
        end
        self.currentSpec = spec
        if self.specTab then
            self.specTab:SelectTab(spec)
        end
    end

    self:UpdateAutoSwitch()
    self:SwitchRotation()
    self:ButtonFetch()

    self.longtermCache = {}

    SpellData:UpdateFromSpellBook()
    if self.specSpells == nil then
        self.specSpells = {}
    end

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        self.specSpells[0] = {}
    end
    for i=2, GetNumSpellTabs() do
        local _, _, offset, numSpells, _, offspecId = GetSpellTabInfo(i)
        if offspecId == 0 then
            offspecId = self.currentSpec
        end
        if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            self.specSpells[offspecId] = {}
        end
        for i = offset, offset + numSpells - 1 do
            local name, _, spellId = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if spellId then
                self.specSpells[offspecId][name] = spellId
            end
        end
    end

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
    end
end

function addon:GetSpecSpellID(spec, name)
    if self.specSpells == nil or self.specSpells[spec] == nil then
        return nil
    end

    return self.specSpells[spec][name]
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

    local slot = bindings[id]
    if slot then
        local type, actionType = GetActionInfo(slot);
        if type == "item" then
            local itemid = addon:FindFirstItemOfItemSet({}, id, true)
            if itemid and itemid ~= actionType then
                addon:debug("Updaeted slot %s to new item %d", slot, itemid)
                PickupItem(itemid)
                PlaceAction(slot)
                ClearCursor()
            end
        else
            bindings[id] = nil
        end
    end
end

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = addon.SwitchRotation
addon.PARTY_MEMBERS_CHANGED = addon.SwitchRotation
addon.PLAYER_FLAGS_CHANGED = addon.SwitchRotation
addon.UPDATE_SHAPESHIFT_FORM = addon.SwitchRotation
addon.UPDATE_STEALTH = addon.SwitchRotation

addon.ACTIONBAR_SLOT_CHANGED = function(self, event, slot)
    local bindings = self.db.char.bindings
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    addon:ButtonFetch()

    local pickupItemSet
    for id, bslot in pairs(bindings) do
        if bslot == slot then
            pickupItemSet = id
            bindings[id] = nil
            if addon.itemSetCallback then
                addon.itemSetCallback(id)
            end
        end
    end

    if addon.bindingItemSet then
        bindings[addon.bindingItemSet] = slot
        if addon.itemSetCallback then
            addon.itemSetCallback(addon.bindingItemSet)
        end
        addon.bindingItemSet = nil
    end

    if pickupItemSet ~= nil then
        local type, action = GetCursorInfo()
        if type == "item" and addon:FindItemInItemSet(pickupItemSet, action) ~= nil then
            addon.bindingItemSet = pickupItemSet
        end
    end
end

addon.ACTIONBAR_HIDEGRID = addon.ButtonFetch
addon.ACTIONBAR_PAGE_CHANGED = addon.ButtonFetch
addon.UPDATE_MACROS = addon.ButtonFetch
addon.VEHICLE_UPDATE = addon.ButtonFetch

function addon:PLAYER_TARGET_CHANGED()
    addon:verbose("Player targeted something else.")
    if not self.inCombat then
        self:SwitchRotation()
    end

    self:EvaluateNextAction()
end

addon.PLAYER_FOCUS_CHANGED = function()
    addon:PLAYER_TARGET_CHANGED()
end

function addon:UNIT_PET(unit)
    if unit == "player" then
        addon:verbose("Player changed pet.")
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

function addon:PLAYER_CONTROL_LOST()
    addon:verbose("Player lost control.")
    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
end

addon.PLAYER_TALENT_UPDATE = addon.UpdateSkills
addon.ACTIVE_TALENT_GROUP_CHANGED = addon.UpdateSkills
addon.CHARACTER_POINTS_CHANGED = addon.UpdateSkills
addon.PLAYER_SPECIALIZATION_CHANGED = addon.UpdateSkills
addon.LEARNED_SPELL_IN_TAB = addon.UpdateSkills

function addon:ZONE_CHANGED()
    addon:verbose("Player switched zones.")
    if not self.inCombat then
        self:SwitchRotation()
    end
end

addon.ZONE_CHANGED_INDOORS = addon.ZONE_CHANGED
addon.GROUP_ROSTER_UPDATE = addon.ZONE_CHANGED

function addon:PLAYER_ENTERING_WORLD()
    local bindings = self.db.char.bindings

    addon:verbose("Player entered world.")
    self:UpdateButtonGlow()
    self:UpdateSkills()

    for id, slot in pairs(bindings) do
        self:UpdateBoundButton(id)
    end
end

function addon:PLAYER_REGEN_DISABLED()
    addon:verbose("Player is in combat.")
    self.inCombat = true
    self.combatCache = {}
end

function addon:PLAYER_REGEN_ENABLED()
    addon:verbose("Player is out of combat.")
    self.inCombat = false
    self.combatCache = {}

    addon:SwitchRotation()
end

function addon:UNIT_ENTERED_VEHICLE(event, unit)
    if unit == "player" then
        addon:verbose("Player on a vehicle.")
        addon:PLAYER_CONTROL_LOST()
    end
end

function addon:UNIT_EXITED_VEHICLE(event, unit)
    if unit == "player" then
        addon:verbose("Player off a vehicle.")
        addon:PLAYER_CONTROL_GAINED()
    end
end

local function CreateUnitInfo(unit)
    local info = {
        name = UnitName(unit),
        attackable = UnitCanAttack("player", unit),
        enemy = UnitIsEnemy("player", unit),
        --health = UnitHealth(unit),
        --inrange = UnitInRange(unit)
    }
    if info.enemy then
        info.threat = UnitThreatSituation("player", unit)
    end
    return info
end

function addon:NAME_PLATE_UNIT_ADDED(event, unit)
    self.unitsInRange[unit] = CreateUnitInfo(unit)
end

function addon:NAME_PLATE_UNIT_REMOVED(event, unit)
    self.unitsInRange[unit] = nil
end

function addon:CURSOR_UPDATE(event)
    if addon.bindingItemSet then
        local type, action = GetCursorInfo()
        --print("[" .. tostring(addon.bindingItemSet) .. "] Got " .. tostring(type) .. "/" .. tostring(action) ..
        --    " cursor update: HasItem(" .. tostring(CursorHasItem()) .. "), GetMouseButtonClicked(" ..
        --    tostring(GetMouseButtonClicked()) .. ")")
        if type == nil and action == nil then
            return
        end
        if type ~= "item" or not addon:FindItemInItemSet(addon.bindingItemSet, action) then
            addon.bindingItemSet = nil
        end
    end
end

function addon:BAG_UPDATE(event)
    local bindings = self.db.char.bindings

    for id, slot in pairs(bindings) do
        self:UpdateBoundButton(id)
    end
end
