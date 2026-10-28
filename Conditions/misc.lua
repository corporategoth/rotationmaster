-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Miscellaneous character and place conditions: SELF_LEVEL (your level), PVP (a unit's PVP flag), ZONEPVP (the zone's
-- PVP status), INSTANCE (the kind, difficulty and ID of the instance you are in) and OUTDOORS. Level comes from
-- addon:GetConditionUnitLevel (Core/level_conditions.lua); the rest come from Platform readers (GetUnitFlagObservation,
-- GetZonePVPObservation, GetInstanceObservation, GetInstanceDetails, GetPlayerFlagObservation) called through the
-- evaluation cache, which return a record or nil and a reason, so a value hidden on a restricted client (Retail,
-- Forever) is unavailable rather than compared. Which client each one can work on is declared in
-- Core/condition_support.lua. Loaded from the Conditions group of RotationMaster.toc, after Conditions/build.lua. The
-- callback and helper bodies are frozen: saved custom conditions bind to their exact text, and the generated block at
-- the end is written by a tool.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Explicit callback leaves; retain raw game observations and argument order.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
        playerize = addon.Functions.presentation.playerize,
    },
    cache = { getCached = addon.Functions.cache.getCached },
    collections = { deepcopy = addon.Functions.collections.deepcopy, keys = addon.Functions.collections.keys },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/misc.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
}

-- ============================================================================
-- Level and PVP
-- ============================================================================

-- SELF_LEVEL compares the player's level. Returns false when the level reads as false (no player), and nil and a reason
-- when the level cannot be read. Stores operator and value (a level).
addon:RegisterCondition("SELF_LEVEL", {
    description = L["Level"],
    icon = addon.Artwork.condition["SELF_LEVEL"],
    fields = { operator = "string", value = "number" },
    -- Checks that the saved fields of the SELF_LEVEL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a listed operator and a non-negative level.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Compares the player's level with the configured number; false when the level reads as false (no player).
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reason from addon:GetConditionUnitLevel (restricted-value, unsupported-client, a missing level).
    evaluate = function(value, cache)
        local level,reason=addon:GetConditionUnitLevel("player",cache)
        if level==nil then return nil,reason end
        if level==false then return false end
        return Functions.values.compare(value.operator, level, value.value)
    end,
    -- Builds the readable rule summary for the SELF_LEVEL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["your level"], Functions.presentation.nullable(value.value, L["<level>"]))
    end,
    -- Builds the editor controls for the SELF_LEVEL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the operator and level.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local operator_group = addon:Widget_OperatorWidget(value, L["Level"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SELF_LEVEL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the operator text.
    help = function(frame)
        addon.layout_condition_operatorwidget_help(frame, L["Level"], L["Level"],
                "The level you are at.")
    end,
})

-- PVP tests whether a unit is flagged for PVP. Returns the flag as the Platform reports it, or nil and a reason when
-- the unit's flag cannot be read. Stores unit.
addon:RegisterCondition("PVP", {
    description = L["PVP Flagged"],
    icon = addon.Artwork.condition["PVP"],
    fields = { unit = "string" },
    -- Checks that the saved fields of the PVP condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a unit from the unit list.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    -- Decides whether the unit is flagged for PVP.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: whatever reason Platform:GetUnitFlagObservation gives for the "pvp" flag.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "pvp")
    end,
    -- Builds the readable rule summary for the PVP condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; "are" for the player, "is" for anyone else.
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} PVP flagged"], L["%s {{!is|is not}} PVP flagged"]),
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Builds the editor controls for the PVP condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the unit picker, without the pet entry.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local funits = Functions.collections.deepcopy(addon.units, { "pet" })

        local unit = addon:Widget_UnitWidget(value, funits,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    -- Builds the help page for the PVP condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared unit picker text.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
})

-- ============================================================================
-- Zone PVP status
-- ============================================================================

-- ZONEPVP tests the PVP status of the zone you are in (none, arena, friendly, contested, hostile, sanctuary, combat).
-- Returns whether the zone's status equals the chosen one, or nil and a reason when the zone cannot be read. A value of
-- nil stands for "no PVP". Stores value.
addon:RegisterCondition("ZONEPVP", {
    description = L["Zone PVP"],
    icon = addon.Artwork.condition["ZONEPVP"],
    fields = { value = "string" },
    -- Checks that the saved fields of the ZONEPVP condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid when unset (no PVP) or one of the listed statuses.
    valid = function(_, value)
        return value.value == nil or Functions.values.isin(addon.zonepvp, value.value)
    end,
    -- Decides whether the PVP status of the zone you are in is the chosen one (a nil value stands for "no PVP").
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: whatever reason Platform:GetZonePVPObservation gives.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetZonePVPObservation, addon.Platform)
        if not record then return nil,reason end
        return value.value == record.pvpType
    end,
    -- Builds the readable rule summary for the ZONEPVP condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return string.format(L["the zone's PVP status {{!is|is not}} %s"], Functions.presentation.nullable(addon.zonepvp[value.value], L["no PVP"]))
    end,
    -- Builds the editor controls for the ZONEPVP condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: a dropdown of statuses, where the empty key stands for "no PVP".
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp_local = Functions.collections.deepcopy(addon.zonepvp)
        zonepvp_local[""] = L["no PVP"]

        local zone = addon:CreateConditionDropdown()
        zone:SetLabel(L["Mode"])
        zone:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        zone.configure = function()
            zone:SetList(zonepvp_local, Functions.collections.keys(zonepvp_local))
            if (value.value ~= nil) then
                zone:SetValue(value.value)
            else
                zone:SetValue("")
            end
        end
        parent:AddChild(zone)
    end,
    -- Builds the help page for the ZONEPVP condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: what each status means.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The PVP status of the area you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no PVP"] .. color.RESET .. " - " ..
                "This area does not allow PVP with other players.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "You are in an arena.  PVP is enabled in this area, but reset on exit.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Controlled by your faction"] .. color.RESET .. " - " ..
                "This area is controlled by your faction.  You will not enter PVP in this region, however " ..
                "opposing factions will be automatically flagged for PVP upon entering.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Contested"] .. color.RESET .. " - " ..
                "This area is contested.  You will not automatically be flagged for PVP (on a PvE server), " ..
                "however you may attack the opposing faction, flagging for PVP.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Controlled by opposing faction"] .. color.RESET .. " - " ..
                "This area is controlled by the opposing faction.  You will be automatically flagged for " ..
                "PVP, however opposing faction players may not be (if on a PvE server) unless they choose to.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Sanctuary (no PVP)"] .. color.RESET .. " - " ..
                "This is a sanctuary city.  No PVP is possible.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Combat (auto-flagged)"] .. color.RESET .. " - " ..
                "This is a combat zone (eg. a battleground), all players will be automatically flagged as PVP.")))
    end,
})

-- ============================================================================
-- Instance
-- ============================================================================

-- The difficulty IDs the INSTANCE editor offers, in the order they are listed.
-- The game names each one (GetDifficultyInfo, in the player's language) and an
-- ID the client does not know is left out. 0 is "not in an instance".
local DIFFICULTIES = {0, 1, 2, 23, 8, 24, 205, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17, 33, 208, 11, 12}

-- Names the kind of group a difficulty is for.
-- @param group any  The group token GetDifficultyInfo returns ("party", "raid" or "scenario").
-- @return string|nil  The localized word for the group; nil for any other group.
local function difficultyKind(group)
    if group == "party" then return L["Dungeon"] end
    if group == "raid" then return L["Raid"] end
    if group == "scenario" then return L["Scenario"] end
end

-- Builds the display name of a difficulty ID, with its group kind appended when the game gives one.
-- @param id any  The difficulty ID; 0 means "not in an instance".
-- @return string|nil  The name; nil when the client does not know the ID or the name is hidden or empty, so callers
--     fall back to the number.
local function difficultyName(id)
    if id == 0 then return L["Not in an instance"] end
    if type(id) ~= "number" then return nil end
    local ok, name, group = pcall(GetDifficultyInfo, id)
    if ok and addon.Platform:CanReadValue(name) and type(name) == "string" and name ~= "" then
        local kind = addon.Platform:CanReadValue(group) and difficultyKind(group)
        if kind then return string.format(L["%s (%s)"], name, kind) end
        return name
    end
    return nil
end

-- True for a finite whole number from 0 up to 2^31 (the range of a difficulty or instance ID).
-- @param value any  The value to test.
-- @return boolean  True when value is a number in that range with no fractional part.
local function validWhole(value)
    return type(value) == "number" and value == value and value >= 0 and value < 2^31 and value % 1 == 0
end

-- INSTANCE tests the kind of instance you are in. Difficulty and the exact
-- instance (by ID, which does not change with the game language the way a zone
-- name does) are optional additions: a condition saved without them is
-- unchanged, and one with them matches only when every part given matches.
-- Returns whether every part given matches, or nil and a reason when a part that was asked about cannot be read.
-- Stores value (the kind), difficulty and instanceID.
addon:RegisterCondition("INSTANCE", {
    description = L["Instance"],
    icon = addon.Artwork.condition["INSTANCE"],
    fields = { value = "string", difficulty = "number", instanceID = "number" },
    -- Checks that the saved fields of the INSTANCE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid when each part given is a listed kind or a whole number; every part is optional.
    valid = function(_, value)
        return (value.value == nil or Functions.values.isin(addon.instances, value.value))
            and (value.difficulty == nil or validWhole(value.difficulty))
            and (value.instanceID == nil or validWhole(value.instanceID))
    end,
    -- Decides whether every part given (kind of instance, difficulty and instance ID) matches the instance you are in.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: whatever reason Platform:GetInstanceObservation or GetInstanceDetails gives, the instance type
    -- reason, or instance-data-unavailable (or a per-field reason) when the difficulty or ID is asked for but is
    -- unreadable.
    evaluate = function(value, cache)
        local extra = value.difficulty ~= nil or value.instanceID ~= nil
        -- The kind of instance, as before; with no kind chosen and a difficulty
        -- or an ID given, the kind is not part of the question.
        if value.value ~= nil or not extra then
            local record,reason=Functions.cache.getCached(cache, addon.Platform.GetInstanceObservation, addon.Platform)
            if not record then return nil,reason end
            local matches
            if value.value == "none" then matches = not record.inInstance
            elseif not record.inInstance then matches = false
            else
                if record.instanceType==nil then return nil,record.instanceTypeReason end
                matches = value.value == record.instanceType
            end
            if not extra or not matches then return matches end
        end
        local details, why = Functions.cache.getCached(cache, addon.Platform.GetInstanceDetails, addon.Platform)
        if not details then return nil, why end
        if value.difficulty ~= nil then
            if details.difficultyID == nil then return nil, details.reasons.difficultyID or "instance-data-unavailable" end
            if details.difficultyID ~= value.difficulty then return false end
        end
        if value.instanceID ~= nil then
            if details.instanceID == nil then return nil, details.reasons.instanceID or "instance-data-unavailable" end
            if details.instanceID ~= value.instanceID then return false end
        end
        return true
    end,
    -- Builds the readable rule summary for the INSTANCE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; the short form when only the kind is set, else a list of the parts given.
    print = function(_, value)
        if value.difficulty == nil and value.instanceID == nil then
            return string.format(L["your instance type {{!is|is not}} %s"],
                    Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
        end
        local parts = {}
        if value.value ~= nil then
            parts[#parts + 1] = string.format(L["type %s"], Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
        end
        if value.difficulty ~= nil then
            parts[#parts + 1] = string.format(L["difficulty %s"], difficultyName(value.difficulty) or tostring(value.difficulty))
        end
        if value.instanceID ~= nil then
            parts[#parts + 1] = string.format(L["ID %s"], tostring(value.instanceID))
        end
        return string.format(L["you {{!are|are not}} in an instance (%s)"], table.concat(parts, ", "))
    end,
    -- Builds the editor controls for the INSTANCE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the kind dropdown, the difficulty dropdown, the instance ID box, and a note naming the current instance.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(addon.instances, Functions.collections.keys(addon.instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)

        -- Optional: a difficulty the game names, or any.
        local choices, order = { [""] = L["Any difficulty"] }, { "" }
        for _, id in ipairs(DIFFICULTIES) do
            local name = difficultyName(id)
            if name then choices[id] = name; order[#order + 1] = id end
        end
        -- A difficulty saved for another client is kept and still shown.
        if validWhole(value.difficulty) and choices[value.difficulty] == nil then
            choices[value.difficulty] = difficultyName(value.difficulty) or string.format(L["difficulty %d"], value.difficulty)
            order[#order + 1] = value.difficulty
        end
        local difficulty = addon:CreateConditionDropdown()
        difficulty:SetLabel(L["Instance Difficulty"])
        difficulty:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then value.difficulty = nil else value.difficulty = v end
            top:SetStatusText(funcs:print(root, spec))
        end)
        difficulty.configure = function()
            difficulty:SetList(choices, order)
            difficulty:SetValue(value.difficulty ~= nil and value.difficulty or "")
        end
        parent:AddChild(difficulty)

        -- Optional: one particular instance by its ID (blank for any).
        local edit = addon:CreateConditionEditBox()
        edit:SetFullWidth(true)
        edit:SetLabel(L["Instance ID"])
        edit:SetText(value.instanceID and tostring(value.instanceID) or "")
        edit:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber(text)
            value.instanceID = validWhole(id) and id or nil
            edit:SetText(value.instanceID and tostring(value.instanceID) or "")
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(edit)

        -- Authoring aid: the instance you are in right now.
        local note = addon:CreateConditionLabel()
        note:SetFullWidth(true)
        local platform = addon.Platform
        local details = type(platform.GetInstanceDetails) == "function" and platform:GetInstanceDetails()
        if details and details.instanceID ~= nil and details.name ~= nil then
            note:SetText(string.format(L["You are in %s (instance ID %d)."], details.name, details.instanceID))
        else
            note:SetText(L["The instance you are in cannot be read right now."])
        end
        parent:AddChild(note)
    end,
    -- Builds the help page for the INSTANCE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: what each kind of instance means, then the difficulty and ID text.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The type of instance you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Outside"] .. color.RESET .. " - " ..
                "You are not in an instance (this does not necessarily mean you are outdoors, just not in any " ..
                "kind of instance.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Battleground"] .. color.RESET .. " - " ..
                "You are in a battleground (an ad-hoc instance where the opponent is the opposing faction.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "A close quarters fight with the opposing faction, where death is a loss.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Dungeon"] .. color.RESET .. " - " ..
                "A five-person dungeon, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Raid"] .. color.RESET .. " - " ..
                "An instance that accommodates more than five people, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Scenario"] .. color.RESET .. " - " ..
                "A single-person instance, similar to a dungeon but completed solo.")))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Help.Conditions.INSTANCE_DETAILS"]))
    end,
})

-- ============================================================================
-- Outdoors
-- ============================================================================

-- OUTDOORS tests whether the game reports you as outdoors, which is not the same as being outside an instance. Returns
-- the flag as the Platform reports it, or nil and a reason when it cannot be read. Stores no fields.
addon:RegisterCondition("OUTDOORS", {
    description = L["Outdoors"],
    icon = addon.Artwork.condition["OUTDOORS"],
    fields = {},
    -- Checks that the saved fields of the OUTDOORS condition are complete and in range.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Always valid: there is nothing to configure.
    valid = function()
        return true
    end,
    -- Decides whether the game reports you as outdoors, which is not the same as being outside an instance.
    -- @param _ any  Unused; this condition has no fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: whatever reason Platform:GetPlayerFlagObservation gives for the "outdoors" flag.
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "outdoors")
    end,
    -- Builds the readable rule summary for the OUTDOORS condition.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function()
        return L["you {{!are|are not}} outdoors"]
    end,
    -- Builds the help page for the OUTDOORS condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: one explanatory paragraph. There is no widget callback because the condition has no options.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when the game reports that you are outdoors. Being outdoors is different from being outside an instance."] ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="DIFFICULTIES" then return DIFFICULTIES end
        if name=="color" then return color end
        if name=="difficultyKind" then return difficultyKind end
        if name=="difficultyName" then return difficultyName end
        if name=="helpers" then return helpers end
        if name=="validWhole" then return validWhole end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/misc.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/misc.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
