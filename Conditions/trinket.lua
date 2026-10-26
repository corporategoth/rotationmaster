local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- TRINKET_COOLDOWN: the cooldown left on the item in a trinket slot, whichever
-- item that is, so one rotation works for every trinket. The equipped item is
-- read from the build context (refreshed on equipment changes, so no native
-- read per evaluation); its cooldown is read fresh through
-- Platform:GetItemCooldown, the same reader as the Item Cooldown condition.
-- An empty slot is false; a trinket with no on-use effect has no cooldown to
-- read and is unavailable, never a confident zero.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/trinket.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

-- Inventory slots 13 and 14.
local SLOTS = { [13] = L["Trinket 1"], [14] = L["Trinket 2"] }
local SLOT_ORDER = { 13, 14 }

addon:RegisterCondition("TRINKET_COOLDOWN", {
    description = L["Trinket Cooldown"],
    icon = addon.Artwork.condition["TRINKET_COOLDOWN"],
    requiredFields = { "slot", "operator", "value" },
    fields = { slot = "number", operator = "string", value = "number" },
    valid = function(_, value)
        return value.slot ~= nil and Functions.values.isin(SLOTS, value.slot)
            and value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == "number" and value.value == value.value and value.value >= 0 and value.value < math.huge
    end,
    evaluate = function(value, cache, now)
        if not addon.GetEquippedSlotInfo then return nil, "build-context-unavailable" end
        local item, reason = addon:GetEquippedSlotInfo(value.slot)
        if item == nil then return nil, reason end
        if item == false then return false end
        local cooldown, problem = Functions.cache.getCached(cache, addon.Platform.GetItemCooldown, addon.Platform, item.itemID)
        if not cooldown then return nil, problem end
        if not cooldown.isEnabled then return nil, "trinket-has-no-use-effect" end
        if not addon.Platform:CanReadValue(now) or type(now) ~= "number" then return nil, "invalid-time" end
        local remaining = math.max(0, cooldown.startTime + cooldown.duration - now)
        if remaining ~= remaining or remaining == math.huge then return nil, "invalid-api-result" end
        return Functions.values.compare(value.operator, math.floor(remaining * 1000 + 0.5) / 1000, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
            string.format(L["the cooldown on your %s"], Functions.presentation.nullable(SLOTS[value.slot], L["<trinket slot>"])),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local slot = addon:CreateConditionDropdown()
        slot:SetLabel(L["Trinket Slot"])
        slot:SetCallback("OnValueChanged", function(_, _, v)
            value.slot = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        slot.configure = function()
            slot:SetList(SLOTS, SLOT_ORDER)
            if value.slot ~= nil then slot:SetValue(value.slot) end
        end
        parent:AddChild(slot)

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Seconds"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.TRINKET_COOLDOWN"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Trinket Cooldown"], L["Seconds"],
            L["The number of seconds before you can use the item in the chosen trinket slot; 0 means it is ready."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="SLOTS" then return SLOTS end
        if name=="SLOT_ORDER" then return SLOT_ORDER end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/trinket.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/trinket.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
