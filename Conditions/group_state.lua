local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Your party or raid as numbers: its size, how many members hold each assigned
-- role, and how many members other than you are dead. One pass over the party
-- or raid tokens (Platform:GetGroupSnapshot, Platform/world_state.lua) answers
-- all three, once per evaluation. Group members are never identity-restricted,
-- so these read on Retail and Forever as well; a member whose value cannot be
-- read makes the count unavailable (also under NOT) instead of understating it.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/group_state.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
        and type(value.value) == "number" and value.value == value.value and value.value >= 0 and value.value < math.huge
end
-- The assigned roles that can be counted, in the order they are listed.
local ROLES = { "TANK", "HEALER", "DAMAGER" }

addon:RegisterCondition("GROUP_SIZE", {
    description = L["Group Size"],
    icon = addon.Artwork.condition["GROUP_SIZE"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value, cache)
        local group, reason = Functions.cache.getCached(cache, addon.Platform.GetGroupSnapshot, addon.Platform)
        if not group then return nil, reason end
        return Functions.values.compare(value.operator, group.size, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the number of players in your group"],
            Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Players"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.GROUP_SIZE"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Group Size"], L["Players"],
            L["The number of players in your party or raid, counting you; 1 when you are alone."])
    end,
})

addon:RegisterCondition("GROUP_ROLE_COUNT", {
    description = L["Group Role Count"],
    icon = addon.Artwork.condition["GROUP_ROLE_COUNT"],
    requiredFields = { "role", "operator", "value" },
    fields = { role = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return value.role ~= nil and Functions.values.isin(addon.roles, value.role) and validCompare(value)
    end,
    evaluate = function(value, cache)
        local group, reason = Functions.cache.getCached(cache, addon.Platform.GetGroupSnapshot, addon.Platform)
        if not group then return nil, reason end
        if group.roles == nil then return nil, group.rolesReason or "group-data-unavailable" end
        return Functions.values.compare(value.operator, group.roles[value.role] or 0, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
            string.format(L["the number of group members whose assigned role is %s"], Functions.presentation.nullable(addon.roles[value.role], L["<role>"])),
            Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local role = addon:CreateConditionDropdown()
        role:SetLabel(L["Role"])
        role:SetCallback("OnValueChanged", function(_, _, v)
            value.role = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        role.configure = function()
            local choices = {}
            for _, key in ipairs(ROLES) do choices[key] = addon.roles[key] end
            role:SetList(choices, ROLES)
            if value.role ~= nil then role:SetValue(value.role) end
        end
        parent:AddChild(role)

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Players"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.GROUP_ROLE_COUNT"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Group Role Count"], L["Players"],
            L["The number of group members, counting you, who hold the chosen role."])
    end,
})

addon:RegisterCondition("GROUP_DEAD_COUNT", {
    description = L["Dead Group Members"],
    icon = addon.Artwork.condition["GROUP_DEAD_COUNT"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value, cache)
        local group, reason = Functions.cache.getCached(cache, addon.Platform.GetGroupSnapshot, addon.Platform)
        if not group then return nil, reason end
        if group.dead == nil then return nil, group.deadReason or "group-data-unavailable" end
        return Functions.values.compare(value.operator, group.dead, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the number of dead or ghost members of your group"],
            Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Players"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.GROUP_DEAD_COUNT"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Dead Group Members"], L["Players"],
            L["The number of other members of your party or raid who are dead or ghosts."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="ROLES" then return ROLES end
        if name=="helpers" then return helpers end
        if name=="validCompare" then return validCompare end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/group_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/group_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
