local addon_name, addon = ...

local _G = _G

_G.RotationMaster = LibStub("AceAddon-3.0"):NewAddon(addon, addon_name, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local SpellRange = LibStub("SpellRange-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local getCached

local pairs, color = pairs, color
local floor = math.floor

addon.pretty_name = GetAddOnMetadata(addon_name, "Title")

--
-- Initialization
--

local defaults = {
    profile = {
        enable = true,
        poll = 0.15,
        overlay = "Ping",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = 'CENTER',
        xoffs = 0,
        yoffs = 0,
        rotations = {},
        debug = false,
        verbose = false,
        disable_autoswitch = false,
        live_config_update = 2,
    },
    global = {
        textures = {
            {
                name = "Ping",
                texture = "Interface\\Cooldown\\ping4",
            },
            {
                name = "Star",
                texture = "Interface\\Cooldown\\star4",
            },
            {
                name = "Starburst",
                texture = "Interface\\Cooldown\\starburst",
            }
        }
    }
}

local events = {
    -- Conditions that indicate a major combat event that should trigger an immediate
    -- evaluation of the rotation conditions (or will disable your rotation entirely).
    'PLAYER_TARGET_CHANGED',
    'PLAYER_FOCUS_CHANGED',
    'PLAYER_REGEN_DISABLED',
    'PLAYER_REGEN_ENABLED',
    'UNIT_PET',
    'VEHICLE_UPDATE',
    'PLAYER_CONTROL_GAINED',
    'PLAYER_CONTROL_LOST',
    'UNIT_ENTERED_VEHICLE',

    -- Conditions that affect whether the rotation should be switched.
    'ZONE_CHANGED',
    'ZONE_CHANGED_INDOORS',
    'GROUP_ROSTER_UPDATE',
    'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED',
    'CHARACTER_POINTS_CHANGED',
    'PLAYER_SPECIALIZATION_CHANGED',
    "PLAYER_FLAGS_CHANGED",

    -- Conditions that affect affect the contents of highlighted buttons.
    'ACTIONBAR_SLOT_CHANGED',
    'PLAYER_ENTERING_WORLD',
    'ACTIONBAR_HIDEGRID',
    'ACTIONBAR_PAGE_CHANGED',
    'LEARNED_SPELL_IN_TAB',
    'UPDATE_MACROS',
}

function addon:HandleCommand(str)

    local cmd, npos = AceConsole:GetArgs(str, 1, 1)

    if not cmd or cmd == "help" then
        addon:info(L["/rm help                - This text"])
        addon:info(L["/rm config              - Open the config dialog"])
        addon:info(L["/rm current             - Print out the name of the current rotation"])
        addon:info(L["/rm set [auto|profile]  - $witch to a specific rotation, or use automatic switching again."])
        addon:info(L["                          This is reset upon switching specializations."])

    elseif cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(addon.pretty_name)

    elseif cmd == "current" then
        if self.currentRotation == nil then
            addon:info(L["No roation is currently active."])
        elseif self.currentRotation == DEFAULT then
            addon:info(L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO], DEFAULT)
        else
            addon:info(L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO],
                    self.db.profile.rotations[self.currentSpec][self.currentRotation].name .. "|r")
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
            self:EnableRotationTimer()
            addon:info(L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO], name)
        else
            if self.db.profile.rotations[self.currentSpec] ~= nil then
                for id,rot in pairs(self.db.profile.rotations[self.currentSpec]) do
                    if rot.name == name then
                        self:RemoveAllCurrentGlows()
                        self.manualRotation = true
                        self.currentRotation = id
                        self:EnableRotationTimer()
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

    AceConsole:RegisterChatCommand("rm", function(str) addon:HandleCommand(str) end)
    AceConsole:RegisterChatCommand("rotationmaster", function(str) addon:HandleCommand(str) end)

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

    self.lastConfigUpdate = GetTime()

    -- This is here because of order of loading.
    getCached = addon.getCached
end

function addon:OnEnable()
    addon:info(L["Starting up version %s"], GetAddOnMetadata(addon_name, "Version"))
    self.currentSpec = GetSpecializationInfo(GetSpecialization())

    if self.db.profile.enable then
        for k,v in pairs(events) do
            self:RegisterEvent(v)
        end
        self:EnableRotation()
    end
end

function addon:rotationValidConditions(rot, spec)
    -- We found a cooldown OR a rotation step
    local itemfound = false
    if rot.cooldowns ~= nil then
        -- All cooldowns are valid
        for k,v in pairs(rot.cooldowns) do
            if v.type == nil or v.action == nil or not self:validateCondition(v.conditions, spec) then
                return false
            end
            itemfound = true
        end
    end
    if rot.rotation ~= nil then
        -- All rotation steps are valid
        for k,v in pairs(rot.rotation) do
            if v.type == nil or v.action == nil or not self:validateCondition(v.rotation, spec) then
                return false
            end
            itemfound = true
        end
    end

    return itemfound
end

function addon:UpdateAutoSwitch()
    self.autoswitchRotation = {}

    if self.db.profile.rotations[self.currentSpec] ~= nil then
        for id,rot in pairs(self.db.profile.rotations[self.currentSpec]) do
            if id ~= DEFAULT then
                -- The switch condition is nontrivial and valid.
                if rot.switch and addon:usefulSwitchCondition(rot.switch) and
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
    table.sort(self.autoswitchRotation, function (lhs, rhs) return self.db.profile.rotations[self.currentSpec][lhs].name <
                                                                   self.db.profile.rotations[self.currentSpec][rhs].name end)

    if self.db.profile.rotations[self.currentSpec] ~= nil and self.db.profile.rotations[self.currentSpec][DEFAULT] ~= nil and
            self:rotationValidConditions(self.db.profile.rotations[self.currentSpec][DEFAULT]) then
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

    for k,v in pairs(self.autoswitchRotation) do
        if addon:evaluateSwitchCondition(self.db.profile.rotations[self.currentSpec][v].switch) then
            if self.currentRotation ~= v then
                if v == DEFAULT then
                    addon:info(L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO], DEFAULT)
                else
                    addon:info(L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO],
                            self.db.profile.rotations[self.currentSpec][v].name)
                end

                self:RemoveAllCurrentGlows()
                self.currentRotation = v
                self:EnableRotationTimer()
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
    addon:debug(L["Battle rotation enabled"])
end

function addon:DisableRotation()
    if not self.currentRotation then
        return
    end

    self:DisableRotationTimer()
    self:RemoveAllCurrentGlows()
    self:DestroyAllOverlays()
    self.currentRotation = nil
    addon:debug(L["Battle rotation disabled"])
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

function addon:EvaluateNextAction()
    if self.currentRotation == nil then
        addon:DisableRotationTimer()
    elseif self.db.profile.rotations[self.currentSpec] ~= nil and
           self.db.profile.rotations[self.currentSpec][self.currentRotation] ~= nil then
        local cache = {}
        local rot = self.db.profile.rotations[self.currentSpec][self.currentRotation]
        if rot.rotation ~= nil then
            local enabled
            for id,cond in pairs(rot.rotation) do
                if cond.action ~= nil then
                    -- If we can't highlight the spell, may as well skip to the next one!
                    local spellid
                    if cond.type == "spell" and getCached(self.longtermCache, IsSpellKnown, cond.action, false) then
                        spellid = cond.action
                    elseif cond.type == "pet" and getCached(cache, IsSpellKnown, cond.action, true) then
                        spellid = cond.action
                    elseif cond.type == "item" then
                        local _
                        _, spellid = getCached(self.longtermCache, GetItemSpell, cond.action)
                    end
                    if (addon:FindSpell(spellid) and addon:evaluateCondition(cond.conditions)) then
                        enabled = (SpellRange.IsSpellInRange(spellid, "target"))
                        if enabled == nil then enabled = true end
                    end
                    if enabled then
                        addon:verbose("Rotation step %d satisfied it's condition.", id)
                        if not addon:IsGlowing(spellid) then
                            addon:GlowNextSpell(spellid)
                            if WeakAuras then
                                WeakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", self.type, spellid)
                            end
                        end
                        break
                    else
                        addon:verbose("Rotation step %d dis not satisfy it's condition.", id)
                    end
                end
            end
            if not enabled then
                addon:GlowClear()
                if WeakAuras then
                    WeakAuras.ScanEvents("ROTATIONMASTER_SPELL_UPDATE", nil, nil)
                end
            end
        end
        if rot.cooldowns ~= nil then
            for id,cond in pairs(rot.cooldowns) do
                if cond.action ~= nil then
                    local spellid, enabled
                    if cond.type == "spell" and getCached(self.longtermCache, IsSpellKnown, cond.action, false) then
                        spellid = cond.action
                    elseif cond.type == "pet" and getCached(cache, IsSpellKnown, cond.action, true) then
                        spellid = cond.action
                    elseif cond.type == "item" then
                        local _
                        _, spellid = getCached(self.longtermCache, GetItemSpell, cond.action)
                    end
                    if (addon:FindSpell(spellid) and addon:evaluateCondition(cond.conditions)) then
                        enabled = (SpellRange.IsSpellInRange(spellid, "target"))
                        if enabled == nil then enabled = true end
                    end
                    if enabled then
                        addon:verbose("Cooldown %d is enabled", id)
                    else
                        addon:verbose("Cooldown %d is disabled", id)
                    end
                    addon:GlowCooldown(spellid, enabled, cond)
                end
            end
        end

        -- Update the live config config .. just to be nice :)
        if self.db.profile.live_config_update > 0 and GetTime() - self.lastConfigUpdate > self.db.profile.live_config_update then
            AceConfigRegistry:NotifyChange(addon.name .. "Class")
            self.lastConfigUpdate = GetTime()
            addon:debug(L["Notified configuration to update it's status."])
        end
    end
end

function addon:RemoveCooldownGlowIfCurrent(spec, rotation, action_type, action)
    if spec == self.currentSpec and rotation == self.currentRotation and action ~= nil then
        if action_type == "item" then
            local _, spellid = GetItemSpell(action)
            addon:GlowCooldown(spellid, false)
        else
            addon:GlowCooldown(action, false)
        end
    end
end

function addon:RemoveAllCurrentGlows()
    addon:debug(L["Removing all glows."])
    if self.currentSpec ~= nil and self.currentRotation ~= nil then
        for id,rot in pairs(self.db.profile.rotations[self.currentSpec][self.currentRotation].cooldowns) do
            if rot.type == "item" then
                local _, spellid = GetItemSpell(rot.action)
                addon:GlowCooldown(spellid, false)
            else
                addon:GlowCooldown(rot.action, false)
            end
        end
        addon:GlowClear()
    end
end

function addon:UpdateSkills()
    addon:verbose("Skill update triggered")
    local spec = GetSpecializationInfo(GetSpecialization())
    if spec == nil then
        return
    end
    self.currentSpec = spec
    self:UpdateAutoSwitch()
    self:SwitchRotation()
    self:ButtonFetch()

    self.longtermCache = {}

    local maxbook = 2
    if self.specSpells == nil then
        maxbook = GetNumSpellTabs()
        self.specSpells = {}
    end
    for i=2,maxbook do
        local _, _, offset, numSpells, _, offspecId = GetSpellTabInfo(i)
        if offspecId == 0 then offspecId = self.currentSpec end
        self.specSpells[offspecId] = {}
        for i=offset,offset+numSpells-1 do
            local name, _, spellId = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if spellId then
                self.specSpells[offspecId][name] = spellId;
            end
        end
    end

    if self.specTalents[self.currentSpec] == nil then
        self.specTalents[self.currentSpec] = {}

        for i=1,21 do
            local _, name, icon = GetTalentInfo(floor((i-1) / 3) + 1, ((i-1) % 3) + 1, 1)
            self.specTalents[self.currentSpec][i] = {
		    name = name,
		    icon = icon
	    }
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
        return string.format(L["[Tier: %d, Column: %d]"], floor((idx-1) / 3) + 1, ((idx-1) % 3) + 1)
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

-- The only action for ALL of these is to check to see if the rotation should be switched.
addon.PLAYER_FOCUS_CHANGED = addon.SwitchRotation
addon.ZONE_CHANGED = addon.SwitchRotation
addon.ZONE_CHANGED_INDOORS = addon.SwitchRotation
addon.PARTY_MEMBERS_CHANGED = addon.SwitchRotation
addon.PLAYER_FLAGS_CHANGED = addon.SwitchRotation

addon.ACTIONBAR_SLOT_CHANGED = addon.ButtonFetch
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

addon.PLAYER_FOCUS_CHANGED = function() addon:PLAYER_TARGET_CHANGED() end

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
    addon:verbose("Player entered world.")
    self:UpdateButtonGlow()
    self:UpdateSkills()
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


