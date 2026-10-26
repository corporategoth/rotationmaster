local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Where you are and what is going on there, from the game itself (no boss
-- mod): whether a boss encounter is in progress, the instance difficulty and
-- ID from GetInstanceInfo, and the Mythic+ keystone level. Each is read through
-- the platform adapter (Platform/world_state.lua), once per evaluation, and an
-- unreadable answer is unavailable (also under NOT).
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/encounter_state.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

local function validNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function validWhole(value)
    return validNumber(value) and value % 1 == 0 and value < 2^31
end
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and validNumber(value.value)
end

-- The difficulty IDs offered in the editor, in the order they are listed. The
-- game names each one (GetDifficultyInfo, in the player's language) and an ID
-- the client does not know is left out. 0 is "not in an instance".
local DIFFICULTIES = { 0, 1, 2, 23, 8, 24, 205, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17, 33, 208, 11, 12 }
-- The words after a difficulty name that say what kind of group it is for.
local function difficultyKind(group)
    if group == "party" then return L["Dungeon"] end
    if group == "raid" then return L["Raid"] end
    if group == "scenario" then return L["Scenario"] end
end
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

addon:RegisterCondition("ENCOUNTER", {
    description = L["Boss Encounter"],
    icon = addon.Artwork.condition["ENCOUNTER"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetEncounterObservation, addon.Platform)
    end,
    print = function()
        return L["a boss encounter {{!is|is not}} in progress"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.ENCOUNTER"]))
    end,
})

addon:RegisterCondition("INSTANCE_DIFFICULTY", {
    description = L["Instance Difficulty"],
    icon = addon.Artwork.condition["INSTANCE_DIFFICULTY"],
    requiredFields = { "value" },
    fields = { value = "number" },
    valid = function(_, value)
        return validWhole(value.value)
    end,
    evaluate = function(value, cache)
        local details, reason = Functions.cache.getCached(cache, addon.Platform.GetInstanceDetails, addon.Platform)
        if not details then return nil, reason end
        if details.difficultyID == nil then return nil, details.reasons.difficultyID or "instance-data-unavailable" end
        return details.difficultyID == value.value
    end,
    print = function(_, value)
        local name = difficultyName(value.value)
        if name == nil and validWhole(value.value) then name = string.format(L["difficulty %d"], value.value) end
        return string.format(L["your instance difficulty {{!is|is not}} %s"], Functions.presentation.nullable(name, L["<difficulty>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local choices, order = {}, {}
        for _, id in ipairs(DIFFICULTIES) do
            local name = difficultyName(id)
            if name then choices[id] = name; order[#order + 1] = id end
        end
        -- A difficulty saved for another client is kept and still shown.
        if validWhole(value.value) and choices[value.value] == nil then
            choices[value.value] = difficultyName(value.value) or string.format(L["difficulty %d"], value.value)
            order[#order + 1] = value.value
        end

        local difficulty = addon:CreateConditionDropdown()
        difficulty:SetLabel(L["Instance Difficulty"])
        difficulty:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        difficulty.configure = function()
            difficulty:SetList(choices, order)
            if value.value ~= nil then difficulty:SetValue(value.value) end
        end
        parent:AddChild(difficulty)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.INSTANCE_DIFFICULTY"]))
    end,
})

addon:RegisterCondition("INSTANCE_ID", {
    description = L["Specific Instance"],
    icon = addon.Artwork.condition["INSTANCE_ID"],
    requiredFields = { "value" },
    fields = { value = "number" },
    valid = function(_, value)
        return validWhole(value.value)
    end,
    evaluate = function(value, cache)
        local details, reason = Functions.cache.getCached(cache, addon.Platform.GetInstanceDetails, addon.Platform)
        if not details then return nil, reason end
        if details.instanceID == nil then return nil, details.reasons.instanceID or "instance-data-unavailable" end
        return details.instanceID == value.value
    end,
    print = function(_, value)
        return string.format(L["you {{!are|are not}} in instance %s"], Functions.presentation.nullable(value.value, L["<instance ID>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local edit = addon:CreateConditionEditBox()
        edit:SetFullWidth(true)
        edit:SetLabel(L["Instance ID"])
        edit:SetText(value.value and tostring(value.value) or "")
        edit:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber(text)
            value.value = validWhole(id) and id or nil
            edit:SetText(value.value and tostring(value.value) or "")
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
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.INSTANCE_ID"]))
    end,
})

addon:RegisterCondition("KEYSTONE_LEVEL", {
    description = L["Mythic+ Keystone Level"],
    icon = addon.Artwork.condition["KEYSTONE_LEVEL"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value, cache)
        local keystone, reason = Functions.cache.getCached(cache, addon.Platform.GetKeystoneObservation, addon.Platform)
        if not keystone then return nil, reason end
        return Functions.values.compare(value.operator, keystone.level, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the level of your active Mythic+ keystone"],
            Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Level"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.KEYSTONE_LEVEL"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mythic+ Keystone Level"], L["Level"],
            L["The keystone level of the Mythic+ dungeon you are running; 0 when you are not in one."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="DIFFICULTIES" then return DIFFICULTIES end
        if name=="difficultyKind" then return difficultyKind end
        if name=="difficultyName" then return difficultyName end
        if name=="helpers" then return helpers end
        if name=="validCompare" then return validCompare end
        if name=="validNumber" then return validNumber end
        if name=="validWhole" then return validWhole end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/encounter_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/encounter_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
