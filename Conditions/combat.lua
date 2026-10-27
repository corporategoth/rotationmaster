-- Built In conditions about combat and the player's own state: COMBAT, PET, PET_NAME, STEALTHED, INCONTROL, LOC_TYPE,
-- LOC_BLOCKED, MOVING, THREAT, THREAT_COUNT, FORM, ATTACKABLE, ENEMY, COMBAT_HISTORY, COMBAT_HISTORY_TIME and
-- TIME_IN_COMBAT. Game data comes through addon.Platform observation readers and the combat history that main.lua
-- records from UNIT_COMBAT; on Retail and Forever every value passes platform:CanReadValue, and an unreadable one makes
-- the condition unavailable (nil and a reason), never false. Loaded from RotationMaster.toc after Conditions/item.lua
-- and before Conditions/unit_states.lua. Callback bodies are recorded by tools/generate_builtin_sources.py and saved
-- copies bind to their exact text.
local addon_name, addon = ...

-- ============================================================================
-- Shared setup
-- ============================================================================

-- Records each definition with the lean-engine witness when Core/condition_runtime.lua is loaded, so the declaration at
-- the end of the file can prove it was not replaced; otherwise it passes the definition through unchanged.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/combat.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs
local helpers = addon.help_funcs

-- Private canonical leaves preserve explicit saved-source dependency identities.
local PetSummary = { phrase = addon.Functions.presentation.phrase }

-- Canonical helper leaves the callbacks below call; the bindings table names the Built In helper behind each one.
local Functions = {
    collections = { deepcopy = addon.Functions.collections.deepcopy, keys = addon.Functions.collections.keys },
    values = { compare = addon.Functions.values.compare, isin = addon.Functions.values.isin },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        playerize = addon.Functions.presentation.playerize,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

-- Declares the stable Built In identity of each leaf above so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/combat.lua"] = {
    ["PetSummary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- ============================================================================
-- Combat state and player flags
-- ============================================================================

-- COMBAT: true when the unit is in combat (UnitAffectingCombat), false when it is not or does not exist. Returns nil
-- and a reason when the flag is unreadable or the API is missing. Stores one field, unit.
addon:RegisterCondition("COMBAT", runtimeCondition('COMBAT', {
    requiredFields = { "unit" },
    description = L["In Combat"],
    icon = addon.Artwork.condition["COMBAT"],
    fields = { unit = "string" },
    -- Configuration check: unit must be one of the selectable unit tokens.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    -- Reads the combat flag once per poll through the evaluation cache. Unavailable when the flag is unreadable.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "combat")
    end,
    -- Rule summary; the verb agrees with the player ("are") or another unit ("is").
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} in combat"], L["%s {{!is|is not}} in combat"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Editor control: the unit selector.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
}))

-- PET: true when the pet unit exists, whether or not it is alive, in range or able to act. Returns nil and a reason
-- when the pet cannot be read. Stores no fields.
addon:RegisterCondition("PET", {
    description = L["Have Pet"],
    icon = addon.Artwork.condition["PET"],
    fields = {},
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Reads the pet's existence only (the name is not requested), once per poll.
    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, false)
        if not record then return nil,reason end
        return record.exists
    end,
    -- Rule summary.
    print = function()
        return L["you {{!have|do not have}} a pet"]
    end,
    -- Help page: what existence of a pet does and does not imply.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when your pet unit exists. This does not check whether the pet is alive, in range or able to use an ability."] ))
    end,
})

-- PET_NAME: true when the pet exists and its name equals the saved name exactly, false when there is no pet or the name
-- differs. Returns nil and a reason when the pet or its name cannot be read. Stores one field, value (the name).
addon:RegisterCondition("PET_NAME", {
    description = L["Have Named Pet"],
    icon = addon.Artwork.condition["PET_NAME"],
    fields = { value = "string" },
    -- Configuration check: a name must be set.
    valid = function(_, value)
        return value.value ~= nil
    end,
    -- Reads the pet with its name (the second argument asks for it) once per poll.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, true)
        if not record then return nil,reason end
        if not record.exists then return false end
        return record.name == value.value
    end,
    -- Rule summary; shows <name> until a name is entered.
    print = function(_, value)
        return PetSummary.phrase(L["you {{!have|do not have}} a pet named {name}"], {name = Functions.presentation.nullable(value.value, L["<name>"])})
    end,
    -- Editor control: a text box that stores the name when Enter is pressed.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local petname = addon:CreateConditionEditBox()
        petname:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        petname:SetLabel(NAME)
        if (value.value ~= nil) then
            petname:SetText(value.value)
        end
        parent:AddChild(petname)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
            "The name of the pet you have summoned."))
    end,
})

-- STEALTHED: true while the game reports the player as stealthed (IsStealthed); says nothing about enemy detection.
-- Returns nil and a reason when the flag is unreadable. Stores no fields.
addon:RegisterCondition("STEALTHED", runtimeCondition('STEALTHED', {
    description = L["Stealth"],
    icon = addon.Artwork.condition["STEALTHED"],
    fields = {},
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Reads the player's "stealthed" flag once per poll through the evaluation cache.
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "stealthed")
    end,
    -- Rule summary.
    print = function()
        return L["you {{!are|are not}} stealthed"]
    end,
    -- Help page: what the flag does and does not test.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches while the game reports your character as stealthed. It does not test whether an enemy can detect you."] ))
    end,
}))

-- INCONTROL: true while the game reports that the player has full control of the character (HasFullControl). Returns
-- nil and a reason when the flag is unreadable. Stores no fields.
addon:RegisterCondition("INCONTROL", {
    description = L["In Control"],
    icon = addon.Artwork.condition["INCONTROL"],
    fields = {},
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Reads the player's "control" flag once per poll through the evaluation cache.
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "control")
    end,
    -- Rule summary.
    print = function()
        return L["you {{!are|are not}} in control of your character"]
    end,
    -- Help page: what the flag does and does not guarantee.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when the game reports that you have full control of your character. This does not guarantee that a particular spell is usable."] ))
    end,
})

-- ============================================================================
-- Loss of control
-- ============================================================================

-- LOC_TYPE: compares the seconds remaining on the first active loss-of-control effect of the chosen type (after mapping
-- through addon.loc_equivalent) with the saved value; false when no such effect is active. Returns nil and a reason
-- when the effect list, the effect or its remaining time cannot be read. Stores operator, value (seconds) and loc_type.
addon:RegisterCondition("LOC_TYPE", {
    description = L["Loss Of Control Type"],
    icon = addon.Artwork.condition["LOC_TYPE"],
    fields = { operator = "string", value = "number", loc_type = "string" },
    -- Configuration check: a known operator, a non-negative number of seconds and a known control type.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.loc_type ~= nil and Functions.values.isin(addon.loc_types, value.loc_type))
    end,
    -- Walks the active effects by index through the evaluation cache. Unavailable cases: the count or an effect is
    -- unreadable, or the matching effect has no readable remaining time.
    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "type")
            if not record then return nil,why end
            local loc_type = record.locType
            if addon.loc_equivalent[loc_type] then
                loc_type = addon.loc_equivalent[loc_type]
            end
            if loc_type == value.loc_type then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,
    -- Rule summary: the time remaining on the chosen control type compared with the saved seconds.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["time remaining on %s"],
                Functions.presentation.nullable(addon.loc_types[value.loc_type], L["<control type>"])), string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    -- Editor controls: the control type dropdown and the seconds comparison.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local loc_type = addon:CreateConditionDropdown()
        loc_type:SetLabel(L["Control Type"])
        loc_type:SetCallback("OnValueChanged", function(_, _, v)
            value.loc_type = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        loc_type.configure = function()
            loc_type:SetList(addon.loc_types)
            loc_type:SetValue(value.loc_type)
        end
        parent:AddChild(loc_type)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the control type, then the seconds comparison.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Control Type"] .. color.RESET .. " - " ..
                "The type of loss of control you are subject to."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Loss Of Control Type"], L["Seconds"],
            "How long until the loss of control expires.")
    end,
})

-- LOC_BLOCKED: compares the seconds remaining on the first active loss-of-control effect that locks out the chosen
-- spell school with the saved value; false when none does. The effect's lockout is a bit mask, and the school number
-- selects bit school-1. Returns nil and a reason when the effects, the mask arithmetic or the remaining time cannot be
-- read. Stores operator, value (seconds) and school.
addon:RegisterCondition("LOC_BLOCKED", {
    description = L["Loss Of Control Blocked"],
    icon = addon.Artwork.condition["LOC_BLOCKED"],
    fields = { operator = "string", value = "number", school = "number" },
    -- Configuration check: a known operator, a non-negative number of seconds and a school from SCHOOL_STRINGS.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.school ~= nil and Functions.values.isin(SCHOOL_STRINGS, value.school))
    end,
    -- Walks the active effects by index through the evaluation cache. Unavailable cases: the count or an effect is
    -- unreadable, the bit library or a mask result is missing, secret or not a finite whole number, or the blocking
    -- effect has no readable remaining time.
    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "school")
            if not record then return nil,why end
            if not addon.Platform:CanReadValue(bit) then return nil,"restricted-value" end
            if type(bit)~="table" then return nil,"missing-api" end
            local shiftOk,selectedBit=pcall(function() return bit.lshift(1, value.school-1) end)
            if not shiftOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(selectedBit) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(selectedBit) then return nil,"restricted-value" end
            if type(selectedBit)~="number" or selectedBit~=selectedBit or selectedBit==math.huge or selectedBit==-math.huge or selectedBit%1~=0 then return nil,"invalid-api-result" end
            local bandOk,blocked=pcall(function() return bit.band(record.lockoutSchool, selectedBit) end)
            if not bandOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(blocked) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(blocked) then return nil,"restricted-value" end
            if type(blocked)~="number" or blocked~=blocked or blocked==math.huge or blocked==-math.huge or blocked%1~=0 then return nil,"invalid-api-result" end
            if blocked~=0 then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,
    -- Rule summary: the time remaining on the block of the chosen school compared with the saved seconds.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["time remaining on block of your %s abilities"],
            Functions.presentation.nullable(SCHOOL_STRINGS[value.school], L["<school>"])), string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    -- Editor controls: the blocked school dropdown and the seconds comparison.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local school = addon:CreateConditionDropdown()
        school:SetLabel(L["School Blocked"])
        school:SetCallback("OnValueChanged", function(_, _, v)
            value.school = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        school.configure = function()
            school:SetList(SCHOOL_STRINGS)
            school:SetValue(value.school)
        end
        parent:AddChild(school)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the blocked school, then the seconds comparison.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["School Blocked"] .. color.RESET .. " - " ..
            "The type of ability you are prevented from using."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Loss Of Control Blocked"], L["Seconds"],
            "How long until the loss of control expires.")
    end,
})

-- ============================================================================
-- Movement and threat
-- ============================================================================

-- MOVING: true while the player's current movement speed is not zero; says nothing about the target. Returns nil and a
-- reason when the speed is unreadable, which on Retail and Forever includes the restricted-stats case. Stores no
-- fields.
addon:RegisterCondition("MOVING", runtimeCondition('MOVING', {
    description = L["Moving"],
    icon = addon.Artwork.condition["MOVING"],
    fields = {},
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Reads the player's movement speed once per poll through the evaluation cache.
    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetPlayerMovementObservation,addon.Platform)
        if not record then return nil,reason end
        return record.speed~=0
    end,
    -- Rule summary.
    print = function()
        return L["you {{!are|are not}} moving"]
    end,
    -- Help page: what "moving" is based on.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches while your character is moving, based on current movement speed. It does not test the movement of your target."] ))
    end,
}))

-- THREAT: true when the player's threat on the unit (UnitThreatSituation status 0 to 3) is at least the chosen level;
-- the saved threat number 1 to 4 maps to status threat-1. False when the unit does not exist, is not an enemy or the
-- player has no threat on it. Returns nil and a reason when the status is unreadable. Stores unit and threat.
addon:RegisterCondition("THREAT", {
    description = L["Threat"],
    icon = addon.Artwork.condition["THREAT"],
    fields = { unit = "string", threat = "number" },
    -- Configuration check: a selectable unit and a threat level from 1 to 4.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
               value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    -- Reads the threat status once per poll through the evaluation cache.
    evaluate = function(value, cache)
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitThreatObservation, addon.Platform, value.unit)
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed >= value.threat - 1
    end,
    -- Rule summary from addon.threatPredicates; level 1 uses the possessive unit names.
    print = function(_, value)
        local predicate = addon.threatPredicates[value.threat]
        if not predicate then
            return string.format(L["you {{!are|are not}} at least %s on %s"], Functions.presentation.nullable(nil, L["<threat>"]),
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
        end
        local units = value.threat == 1 and addon.unitsPossessive or addon.units
        return string.format(predicate, Functions.presentation.nullable(units[value.unit], L["<unit>"]))
    end,
    -- Editor controls: the unit selector (player and pet are left out of the list), then the threat level.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local val = addon:CreateConditionDropdown()
        val:SetLabel(L["Threat"])
        val:SetCallback("OnValueChanged", function(_, _, v)
            value.threat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        val.configure = function()
            val:SetList(addon.threat)
            val:SetValue(value.threat)
        end
        parent:AddChild(val)
    end,
    -- Help page: the unit, then each threat level and when it counts as reached.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " - " ..
            "The amount of threat you have with " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
            "condition will not be successful if you have no threat whatsoever (that is, you are not considered in " ..
            "combat with that unit).  It is successful at the chosen level or any level below it in this list: tanking " ..
            "securely also counts as tanking, and tanking counts as having at least as much threat as the tank."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no threat risk"] .. color.RESET .. " - " ..
            "You are not in danger of taking threat away from whoever has threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher threat than tank"] .. color.RESET .. " - " ..
            "You are in danger of pulling threat away from the current tank, and should reduce the amount of " ..
            "threat generated (by using threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ", however " ..
            "you are not at the top of the threat table, and thus are at risk of them switching targets " ..
            "to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " and are " ..
            "not at risk of them switching targets at the moment.")))
    end,
})

-- THREAT_COUNT: compares the number of enemies on which the player has at least the chosen threat level with the saved
-- count. The counting is addon:GetConditionThreatCount (Core/threat_count_conditions.lua): it reads the unit snapshot,
-- or nameplate units on a restricted client, so only enemies within nameplate distance are counted. Returns nil and a
-- reason when a required fact is unavailable. Stores threat, operator and value (the count).
addon:RegisterCondition("THREAT_COUNT", {
    description = L["Threat Count"],
    icon = addon.Artwork.condition["THREAT_COUNT"],
    fields = { threat = "number", operator = "string", value = "number" },
    -- Configuration check: a non-negative count, a known operator and a threat level from 1 to 4.
    valid = function(_, value)
        return value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    -- Counts enemies at status threat-1 or higher, then compares. Unavailable when the count cannot be proven.
    evaluate = function(value, cache)
        local count,reason=addon:GetConditionThreatCount(value.threat-1,cache)
        if count==nil then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Rule summary built from addon.threatCounts; a placeholder stands in for an unknown level.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
                        addon.threatCounts[value.threat] or string.format(L["the number of enemies on which you are at least %s"],
                        Functions.presentation.nullable(nil, L["<threat>"])),
                        Functions.presentation.nullable(value.value))
    end,
    -- Editor controls: the threat level dropdown and the count comparison.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local val = addon:CreateConditionDropdown()
        val:SetLabel(L["Threat"])
        val:SetCallback("OnValueChanged", function(_, _, v)
            value.threat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        val.configure = function()
            val:SetList(addon.threat)
            val:SetValue(value.threat)
        end
        parent:AddChild(val)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the threat levels, the count comparison and the nameplate distance limit.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " - " ..
                "The minimum amount of threat you have with other units."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no threat risk"] .. color.RESET .. " - " ..
                "You are not in danger of taking threat away from whoever has threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher threat than tank"] .. color.RESET .. " - " ..
                "You are in danger of pulling threat away from the current tank, and should reduce the amount of " ..
                "threat generated (by using threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
                "You are currently tanking, however you are not at the top of the threat table, and thus are at " ..
                "risk of them switching targets to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
                "You are currently tanking and are not at risk of them switching targets at the moment.")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Threat Count"], L["Count"],
                "The number of units you have at least " .. color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " on.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText("Threat is measured only on units within a maximum measurable range. The maximum " ..
                "range is set using Game Options -> Interface -> Game tab -> Names -> Nameplate Distance."))
    end,
})

-- ============================================================================
-- Shapeshift form
-- ============================================================================

-- The player's class token, fixed for the session. FORM uses it to special-case Shaman, whose single form (spell 2645)
-- is looked up directly instead of through the stance bar.
local character_class = select(2, UnitClass("player"))

-- FORM: true when the player is in the chosen shapeshift form. A condition stores either form (a form spell ID, matched
-- at any rank, preferred) or the older value (a stance bar slot, 0 meaning humanoid) kept for conditions saved before
-- spell IDs were used. False when the player is in a different form. Returns nil and a reason when the active form
-- cannot be read. Not marked pure at the end of the file because valid reads the number of forms the player has.
addon:RegisterCondition("FORM", runtimeCondition('FORM', {
    description = L["Shapeshift Form"],
    icon = addon.Artwork.condition["FORM"],
    fields = { value = "number", form = "number" },
    -- Configuration check: a whole-number form spell ID, or a slot from 0 to the player's number of forms (1 for a
    -- Shaman).
    valid = function(_, value)
        -- A form spell ID is stable; the stance-bar slot `value` shifts as
        -- forms are learned and is kept for conditions saved before IDs.
        if value.form ~= nil then
            return type(value.form) == "number" and value.form > 0 and value.form < math.huge and value.form % 1 == 0
        end
        return value.value ~= nil and value.value >= 0 and value.value <= (character_class == "SHAMAN" and 1 or GetNumShapeshiftForms())
    end,
    -- A saved spell ID is matched against the active form's spell; a saved slot is matched against the active form
    -- index. Unavailable when the active form cannot be read.
    evaluate = function(value, cache)
        if value.form ~= nil then
            local spell,why=Functions.cache.getCached(cache, addon.Platform.GetPlayerFormSpellObservation, addon.Platform)
            if spell==nil then return nil,why end
            if spell==0 then return false end
            return addon.Platform:MatchSpellIdentity(spell, nil, nil, value.form, false)
        end
        local form,reason=Functions.cache.getCached(cache, addon.Platform.GetPlayerFormObservation, addon.Platform)
        if form==nil then return nil,reason end
        return form == value.value
    end,
    -- Rule summary naming the form by its spell, "humanoid form" for slot 0, or a placeholder when none is chosen.
    print = function(_, value)
        local form
        if value.form ~= nil then
            local info = addon.Platform:GetSpellInfo(value.form)
            form = info and info.name
        elseif value.value ~= nil then
            if value.value == 0 then
                form = L["humanoid form"]
            elseif character_class == "SHAMAN" then
                local info = addon.Platform:GetSpellInfo(2645)
                form = info and info.name
            else
                local info = addon.Platform:GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
                form = info and info.name
            end
        end
        return string.format(L["you {{!are|are not}} in %s"], Functions.presentation.nullable(form, L["<form>"]))
    end,
    -- Editor controls: a form icon and a dropdown of humanoid, the stance bar forms, the class's other forms on this
    -- client and, for a condition saved by slot, that slot. The dropdown stores a spell ID or a slot number.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local forms = {}
        local formsOrder = {}

        forms["0"] = L["humanoid"]
        table.insert(formsOrder, "0")
        -- Forms are chosen by spell: those on the stance bar, then the class's
        -- other forms on this client, so a form can be picked before it is
        -- learned. A condition saved by slot keeps its slot entry.
        local names = {}
        local function add_form(id)
            local info = addon.Platform:GetSpellInfo(id)
            local name = info and info.name
            if name and names[name] then return end
            if name then names[name] = true end
            forms["spell:" .. id] = name or string.format(L["Unknown spell (%s)"], id)
            table.insert(formsOrder, "spell:" .. id)
        end
        if type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function" then
            for i=1,GetNumShapeshiftForms() do
                local spellid = select(4, GetShapeshiftFormInfo(i))
                if spellid == nil then
                    break
                end
                add_form(spellid)
            end
        end
        for _, id in ipairs(addon.Platform:GetFormSpellCandidates(character_class)) do
            add_form(id)
        end
        if value.form ~= nil and not forms["spell:" .. value.form] then
            forms["spell:" .. value.form] = string.format(L["Unknown spell (%s)"], value.form)
            table.insert(formsOrder, "spell:" .. value.form)
        end
        if value.form == nil and value.value ~= nil and value.value ~= 0 then
            local slot
            if character_class == "SHAMAN" then
                local info = addon.Platform:GetSpellInfo(2645)
                slot = info and info.name
            elseif type(GetShapeshiftFormInfo) == "function" then
                local info = addon.Platform:GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
                slot = info and info.name
            end
            forms[tostring(value.value)] = string.format(L["Stance bar slot %s (%s)"], value.value, slot or L["<form>"])
            table.insert(formsOrder, tostring(value.value))
        end

        local formIcon = addon:CreateConditionIcon()
        local function set_form_icon()
            if value.form ~= nil then
                local info = addon.Platform:GetSpellInfo(value.form)
                formIcon:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
            elseif value.value ~= nil then
                if value.value == 0 then
                    formIcon:SetImage("Interface\\Icons\\inv_misc_head_human_02")
                else
                    if character_class == "SHAMAN" then
                        if value.value == 1 then
                            local info = addon.Platform:GetSpellInfo(2645)
                            formIcon:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                    else
                        formIcon:SetImage(GetShapeshiftFormInfo(value.value))
                    end
                end
            else
                formIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end

        formIcon:SetWidth(44)
        formIcon:SetHeight(44)
        formIcon:SetImageSize(36, 36)
        set_form_icon()
        parent:AddChild(formIcon)

        local form = addon:CreateConditionDropdown()
        form:SetLabel(L["Form"])
        form:SetCallback("OnValueChanged", function(_, _, v)
            local spell = type(v) == "string" and tonumber(v:match("^spell:(%d+)$"))
            if spell then
                value.form, value.value = spell, nil
            else
                value.form, value.value = nil, tonumber(v)
            end
            form:SetValue(v)
            set_form_icon()
            top:SetStatusText(funcs:print(root, spec))
        end)
        form.configure = function()
            form:SetList(forms, formsOrder)
            if value.form ~= nil then
                form:SetValue("spell:" .. value.form)
            elseif (value.value) then
                form:SetValue(tostring(value.value))
            end
        end
        parent:AddChild(form)
    end,
    -- Help page: what a form is, then how forms are chosen and when the result is unavailable.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Form"] .. color.RESET .. " - " ..
            "You are shapeshifted into a different form.  This includes stances for warriors and stealth.  " ..
            color.GREEN .. L["humanoid"] .. color.RESET .. " can be used to indicate you are NOT shapeshifted."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["A form is chosen by its spell, so the condition keeps working as new forms are learned and on every client language. Any rank of the form matches. The list shows the forms on your stance bar, then your class's other forms on this client. A condition saved by stance bar slot keeps that slot until you choose a form. If the client cannot read the active form, the condition is unavailable, including under NOT."]))
    end,
}))

-- ============================================================================
-- Target relationship
-- ============================================================================

-- ATTACKABLE: whether the player can attack the unit, as decided by the attackability reader (UnitCanAttack, with
-- UnitIsDead). Returns nil and a reason when the unit or the answer cannot be read. Stores one field, unit.
addon:RegisterCondition("ATTACKABLE", runtimeCondition('ATTACKABLE', {
    requiredFields = { "unit" },
    description = L["Attackable"],
    icon = addon.Artwork.condition["ATTACKABLE"],
    fields = { unit = "string" },
    -- Configuration check: unit must be one of the selectable unit tokens.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    -- Reads the attackability once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitAttackabilityObservation, addon.Platform, value.unit)
    end,
    -- Rule summary; the verb agrees with the player ("are") or another unit ("is").
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} attackable"], L["%s {{!is|is not}} attackable"]), Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Editor control: the unit selector (player and pet are left out of the list).
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
}))

-- ENEMY: true when the unit is an enemy of the player (UnitIsEnemy), false when it is not or does not exist. Returns
-- nil and a reason when the flag is unreadable. Stores one field, unit.
addon:RegisterCondition("ENEMY", {
    description = L["Hostile"],
    icon = addon.Artwork.condition["ENEMY"],
    fields = { unit = "string" },
    -- Configuration check: unit must be one of the selectable unit tokens.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    -- Reads the enemy flag once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "enemy")
    end,
    -- Rule summary; the verb agrees with the player ("are") or another unit ("is").
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} an enemy"], L["%s {{!is|is not}} an enemy"]), Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Editor control: the unit selector (player and pet are left out of the list).
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
})

-- ============================================================================
-- Combat history and timing
-- ============================================================================

-- COMBAT_HISTORY: true when an action of the chosen kind sits at a position in the unit's combat history that passes
-- the comparison (position 1 is the latest action). The history is addon.combatHistory[unit], newest first, recorded
-- by main.lua from UNIT_COMBAT; Core/conditions.lua stamps addon:WantHistory whenever this runs, which is what makes
-- main.lua record it. An action matches by name, or by name plus severity. False when nothing matches; nil and
-- "restricted-value" when no entry matches but a candidate position held an action that could not be read. Stores unit,
-- action, operator and value (the position).
addon:RegisterCondition("COMBAT_HISTORY", {
    description = L["Combat Action History"],
    icon = addon.Artwork.condition["COMBAT_HISTORY"],
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    -- Configuration check: a selectable unit, a known action, a known operator and a non-negative position.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.action ~= nil and Functions.values.isin(addon.actions, value.action) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Scans the unit's history by position. Takes no cache because the history is already in memory.
    evaluate = function(value)
        local unknown
        if addon.combatHistory[value.unit] ~= nil then
            for idx, entry in pairs(addon.combatHistory[value.unit]) do
                if (Functions.values.compare(value.operator, idx, value.value)) then
                    -- An action that could not be read (restricted clients) may be this one.
                    if entry.action == false then unknown = true
                    elseif (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                        return true
                    end
                end
            end
        end
        if unknown then return nil, "restricted-value" end
        return false
    end,
    -- Rule summary, phrased as a number of actions ago.
    print = function(_, value)
        local ago = addon.historyActionsAgo[value.operator]
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!were|were not}} %s %s"], L["%s {{!was|was not}} %s %s"]),
                             Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.actions[value.action], L["<action>"]),
                             ago and string.format(ago, Functions.presentation.nullable(value.value))
                             or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s actions ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Editor controls: the unit selector (limited to player, pet and target), the action type and the position.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = addon:CreateConditionDropdown()
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, Functions.collections.keys(addon.actions))
            action:SetValue(value.action)
        end
        parent:AddChild(action)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the unit, the action kind, and how far back the history reaches (by count).
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Action"] .. color.RESET .. " - " ..
                "The kind of combat action to look for (Hit, Miss, Parried, etc)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Combat Action History"], L["Count"],
            "How far back in your combat history to look for " .. color.BLIZ_YELLOW .. L["Action"] .. color.RESET ..
            " (by count).  A value of 1 means the last combat action, 2 means two combat actions ago, etc.  " ..
            "Each combat action is treated separately.  Any combat action more than the setting of " .. color.BLUE ..
            L["Combat History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end,
})

-- COMBAT_HISTORY_TIME: like COMBAT_HISTORY, but the comparison is on how many seconds ago the action happened, measured
-- from the start time of this evaluation pass. Returns nil and "restricted-value" when no entry matches but an action
-- in the window could not be read, and nil with an "invalid-combat-history-*" reason when a time is not a finite
-- number. Stores unit, action, operator and value (seconds).
addon:RegisterCondition("COMBAT_HISTORY_TIME", {
    description = L["Combat Action History Time"],
    icon = addon.Artwork.condition["COMBAT_HISTORY_TIME"],
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    -- Configuration check: a selectable unit, a known action, a known operator and a non-negative number of seconds.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.action ~= nil and Functions.values.isin(addon.actions, value.action) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Scans the unit's history, measuring each entry's age against evalStart (the pass's GetTime(), the third
    -- argument). Every number is checked for readability and finiteness before it is used in arithmetic.
    evaluate = function(value, _, evalStart)
        local unknown
        if addon.combatHistory[value.unit] ~= nil then
            for _, entry in pairs(addon.combatHistory[value.unit]) do
                local compare,operator=Functions.values.compare,value.operator
                if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-history-time' end
                if not addon.Platform:CanReadValue(entry) then return nil,'restricted-value' end
                if type(entry)~='table' then return nil,'invalid-combat-history-entry' end
                local timestamp=entry.time
                if not addon.Platform:CanReadValue(timestamp) then return nil,'restricted-value' end
                if type(timestamp)~='number' or timestamp~=timestamp or timestamp>=math.huge or timestamp<=-math.huge then return nil,'invalid-combat-history-time' end
                local elapsed=evalStart-timestamp
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-history-elapsed' end
                if compare(operator, elapsed, value.value) then
                    -- An action that could not be read (restricted clients) may be this one.
                    if entry.action == false then unknown = true
                    elseif (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                        return true
                    end
                end
            end
        end
        if unknown then return nil, "restricted-value" end
        return false
    end,
    -- Rule summary, phrased as a number of seconds ago.
    print = function(_, value)
        local ago = addon.historySecondsAgo[value.operator]
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!were|were not}} %s %s"], L["%s {{!was|was not}} %s %s"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.actions[value.action], L["<action>"]),
            ago and string.format(ago, Functions.presentation.nullable(value.value))
            or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s seconds ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Editor controls: the unit selector (limited to player, pet and target), the action type and the seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = addon:CreateConditionDropdown()
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, Functions.collections.keys(addon.actions))
            action:SetValue(value.action)
        end
        parent:AddChild(action)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the unit, the action kind, and how far back the history reaches (by time).
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Action"] .. color.RESET .. " - " ..
                "The kind of combat action to look for (Hit, Miss, Parried, etc)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Combat Action History Time"], L["Seconds"],
            "How far back in " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "'s combat history to look for " ..
            color.BLIZ_YELLOW .. L["Action"] .. color.RESET .. " (by time).  The condition matches when any recorded " ..
            "combat action of that kind happened a number of seconds ago that passes the comparison; for example " ..
            "'is less than 3' means it happened within the last 3 seconds.  Each combat action is treated " ..
            "separately.  Combat actions older than " .. color.BLUE .. L["Combat History Memory (seconds)"] ..
            color.RESET .. " (set in the primary Rotation Master configuration screen) are not available.")
    end,
})

-- TIME_IN_COMBAT: compares the seconds since the player entered combat (addon.combatStart, set by main.lua on
-- PLAYER_REGEN_DISABLED) with the saved value. False whatever the operator while the player is out of combat, because
-- there is no start time. Returns nil and a reason when a time is secret or not a finite number. Stores operator and
-- value (seconds).
addon:RegisterCondition("TIME_IN_COMBAT", {
    description = L["Time Since Combat Start"],
    icon = addon.Artwork.condition["TIME_IN_COMBAT"],
    fields = { operator = "string", value = "number" },
    -- Configuration check: a known operator and a non-negative number of seconds.
    valid = function(_, value)
        return ( value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and value.value ~= nil and value.value >= 0)
    end,
    -- Elapsed time is evalStart (the pass's GetTime(), the third argument) minus the combat start.
    evaluate = function(value, _, evalStart)
        local start=addon.combatStart
        if not addon.Platform:CanReadValue(start) then return nil,'restricted-value' end
        if start==nil then return false end
        if type(start)~='number' or start~=start or start>=math.huge or start<=-math.huge then return nil,'invalid-combat-start' end
        if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
        if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-time' end
        local elapsed=evalStart-start
        if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
        if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-elapsed' end
        return Functions.values.compare(value.operator,elapsed,value.value)
    end,
    -- Rule summary: "Time in combat" compared with the saved seconds.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,L["Time in combat"],string.format(L["%s seconds"],Functions.presentation.nullable(value.value)))
    end,
    -- Editor control: the seconds comparison.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: how the elapsed time is compared, with opener examples.
    help = function(frame)
        addon.layout_condition_operatorwidget_help(frame, L["Time Since Combat Start"], L["Seconds"],
        "This condition checks how long you've been in combat. For example, if the operator is set to 'is less than' and the " ..
        "value is set to 5, this condition will only be true if you have been in combat for less than 5 seconds, or if the " ..
        "operator is set to 'is greater than' and the value is set to 10, the condition will only be true if you have been in " ..
        "combat for more than 10 seconds. This is very useful for adjusting rotation priorities for openers vs. normal rotation")
    end,
})

-- ============================================================================
-- Lean-engine declarations
-- ============================================================================

-- Source-owned configuration validators and optional notification facts.
-- `pure = true` says the condition's valid callback depends only on the saved fields, so the lean engine may memoize
-- it; FORM is not pure because its valid callback reads the player's number of forms.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/combat.lua', {
        COMBAT = { pure = true },
        ATTACKABLE = { pure = true },
        MOVING = { pure = true },
        FORM = { pure = false },
        STEALTHED = { pure = true },
    })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="character_class" then return character_class end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/combat.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/combat.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
