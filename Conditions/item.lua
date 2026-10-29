-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Item conditions: EQUIPPED, CARRYING, ITEM (available to use), ITEM_RANGE and ITEM_COOLDOWN. Each names an item
-- reference: one item set (a string key into db.profile.itemsets or db.global.itemsets) or a list of item ids and
-- names, and an optional trinket slot for ITEM_COOLDOWN. The conditions only declare fields, editors and text;
-- evaluation is addon:EvaluateItemCondition in Core/item_conditions.lua, which reads the game through Platform
-- adapters via the evaluation cache and returns nil and a reason for anything missing or hidden (restricted clients
-- included), so no callback here touches a game API. Loaded from the Conditions group of RotationMaster.toc, after
-- Conditions/totem.lua. The callback and helper bodies are frozen: saved custom conditions bind to their exact text,
-- and the generated block at the end is written by a tool.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Select pure helpers from their actual owners for authored and cloned callbacks.
local Functions = {
    values = { isin = addon.Functions.values.isin },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

-- Summary text builders: phrase fills a {name} template, predicate renders an operator as words.
local Summary = {
    phrase = addon.Functions.presentation.phrase,
    predicate = addon.Functions.presentation.predicate,
}

-- Literal-template builder for the summary lines that carry no operator.
local Literal = { phrase = addon.Functions.presentation.phrase }
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/item.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Literal.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Summary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Summary.predicate"] = "builtin:Functions/presentation.lua:predicate",
}

-- ============================================================================
-- Shared helpers
-- ============================================================================

-- Fills a help page with the body shared by every item condition: the item picker text and the note on how item sets
-- are resolved.
-- @param frame table  The help page container that text widgets are added to.
local function itemHelp(frame)
    addon.layout_condition_itemwidget_help(frame)
    frame:AddChild(helpers.Gap())
    frame:AddChild(helpers.CreateText(L["Item sets are checked in priority order. Bag counts use the first carried candidate, not the sum. Availability, range and cooldown checks use the first carried or equipped candidate. Missing or restricted observations stay unavailable, including under NOT."]))
end

-- Describes an item reference for a summary line.
-- @param items string|table|nil  An item set name, or a list of item IDs or names.
-- @return string|nil  A colored item set name (white for a profile set, cyan for a global one), or the first item's
--     link or name plus a count of the others; nil when the reference is invalid or empty.
local function get_item_desc(items)
    if not addon:IsConditionItemReference(items) then return nil end
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets
    if itemsets~=nil and type(itemsets)~='table' or global_itemsets~=nil and type(global_itemsets)~='table' then return nil end

    if type(items) == "string" then
        local set=(itemsets or {})[items];local tint=color.WHITE
        if set==nil then set=(global_itemsets or {})[items];tint=color.CYAN end
        if type(set)=='table' and type(set.name)=='string' then return string.format(L["a %s item set item"],tint..set.name..color.RESET) end
    elseif items and #items > 0 then
        local info=addon.Platform:GetItemMetadata(items[1])
        local link=info and (info.link or info.name) or items[1]
        if #items > 1 then
            return string.format(L["%s or %d others"], link, #items-1)
        else
            return link
        end
    end
    return nil
end

-- ============================================================================
-- Equipped, carried and available items
-- ============================================================================

-- EQUIPPED tests that one of the referenced items is worn. Returns false when none is, and nil and a reason when a
-- read is unavailable. Stores item (and the notcarrying flag, which this condition does not use).
addon:RegisterCondition("EQUIPPED", {
    description = L["Have Item Equipped"],
    icon = addon.Artwork.condition["EQUIPPED"],
    requiredFields = { 'item' },
    fields = { item = { "string", { "string", "number" } } },
    -- Checks that the saved fields of the EQUIPPED condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with an item set name or a list of items.
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    -- Decides whether one of the referenced items is worn.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param now number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateItemCondition returns (item-set-unavailable, a failed item or equipment
    -- read). now is the poll's time.
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("EQUIPPED",value,cache,now)
    end,
    -- Builds the readable rule summary for the EQUIPPED condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return Literal.phrase(L["you {{!have|do not have}} {item} equipped"], {item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"])})
    end,
    -- Builds the editor controls for the EQUIPPED condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the item picker.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
    -- Builds the help page for the EQUIPPED condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared item text.
    help = function(frame)
        itemHelp(frame)
    end,
})

-- CARRYING compares how many of the first carried candidate are in the bags (not the sum over candidates). Returns the
-- comparison, with a count of 0 when none is carried, or nil and a reason when the bag counts are unavailable. Stores
-- item, operator and value (a count).
addon:RegisterCondition("CARRYING", {
    description = L["Have Item In Bags"],
    icon = addon.Artwork.condition["CARRYING"],
    requiredFields = { 'item', 'operator', 'value' },
    fields = { item = { "string", { "string", "number" } }, operator = "string", value = "number" },
    -- Checks that the saved fields of the CARRYING condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with an item reference, a listed operator and a finite non-negative count.
    valid = function(_, value)
        return (addon:IsConditionItemReference(value.item) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    -- Compares how many of the first carried candidate item are in the bags with the configured count.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param now number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateItemCondition returns (item-set-unavailable, a failed bag-count read).
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("CARRYING",value,cache,now)
    end,
    -- Builds the readable rule summary for the CARRYING condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return Summary.phrase(L["the number of {item} you are carrying {comparison} {quantity}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            comparison = Summary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value, L["<quantity>"]),
        })
    end,
    -- Builds the editor controls for the CARRYING condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the item picker, then the operator and quantity.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Quantity"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the CARRYING condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared item text, then the operator text.
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Have Item In Bags"], L["Quantity"],
            "The quantity of " .. color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " you are carrying in your bags.")
    end,
})

-- ITEM tests that the first carried or equipped candidate can be used now: its required level is met and its cooldown
-- is enabled and either idle or ending with the global cooldown. Returns false when none is held (unless notcarrying
-- judges the first candidate anyway), and nil and a reason when a read is unavailable. Stores item and notcarrying.
addon:RegisterCondition("ITEM", {
    description = L["Item Available"],
    icon = addon.Artwork.condition["ITEM"],
    requiredFields = { 'item' },
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    -- Checks that the saved fields of the ITEM condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with an item reference and an optional notcarrying flag.
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    -- Decides whether the first carried or equipped candidate item can be used now.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param now number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateItemCondition returns (invalid-time, a failed cooldown, level or global
    -- cooldown read, invalid-api-result).
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM",value,cache,now)
    end,
    -- Builds the readable rule summary for the ITEM condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return Literal.phrase(L["{item} {{!is|is not}} available{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
    end,
    -- Builds the editor controls for the ITEM condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the item picker and the Check If Not Carrying checkbox.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    -- Builds the help page for the ITEM condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared item text, what availability means, then the Check If Not Carrying checkbox.
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Item Available checks the required level and enabled item cooldown. An active cooldown qualifies only when it ends with the readable global cooldown. This condition does not bypass the action's implicit ownership, usability and range checks."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end,
})

-- ITEM_RANGE tests that the current target is in range of the first carried or equipped candidate. Returns false when
-- none is held (unless notcarrying judges the first candidate anyway) or the item has no range to test, and nil and a
-- reason when a read is unavailable. Stores item and notcarrying.
addon:RegisterCondition("ITEM_RANGE", {
    description = L["Item In Range"],
    icon = addon.Artwork.condition["ITEM_RANGE"],
    requiredFields = { 'item' },
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    -- Checks that the saved fields of the ITEM_RANGE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with an item reference and an optional notcarrying flag.
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    -- Decides whether the current target is in range of the first carried or equipped candidate item.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param now number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateItemCondition returns (a failed item id or range read).
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_RANGE",value,cache,now)
    end,
    -- Builds the readable rule summary for the ITEM_RANGE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return Literal.phrase(L["{item} {{!is|is not}} in range{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
    end,
    -- Builds the editor controls for the ITEM_RANGE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the item picker and the Check If Not Carrying checkbox.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    -- Builds the help page for the ITEM_RANGE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared item text, then the Check If Not Carrying checkbox.
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end,
})

-- ============================================================================
-- Item cooldown
-- ============================================================================

-- The trinket slots ITEM_COOLDOWN can read instead of a named item (inventory slots 13 and 14).
local TRINKET_SLOTS = { [13] = L["Trinket 1"], [14] = L["Trinket 2"] }
local TRINKET_SLOT_ORDER = { 13, 14 }

-- Either an item (or item set) is named, or a trinket slot is chosen and the item is ignored.
-- ITEM_COOLDOWN compares the seconds left on that item's cooldown. Returns false for an empty trinket slot or when no
-- candidate is held, and nil and a reason when a read is unavailable (item-cooldown-disabled, or
-- trinket-has-no-use-effect for a slot whose trinket has no on-use effect). Stores item or slot, notcarrying, operator
-- and value (seconds).
addon:RegisterCondition("ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = addon.Artwork.condition["ITEM_COOLDOWN"],
    requiredFields = { 'operator', 'value' },
    fields = {
        item = { "string", { "string", "number" } },
        slot = "number",
        notcarrying = "boolean",
        operator = "string",
        value = "number",
    },
    -- Checks that the saved fields of the ITEM_COOLDOWN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a trinket slot or an item reference, a listed operator and a finite non-negative number of seconds.
    valid = function(_, value)
        local source
        if value.slot ~= nil then source = Functions.values.isin(TRINKET_SLOTS, value.slot) else source = addon:IsConditionItemReference(value.item) end
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                source and (value.notcarrying==nil or type(value.notcarrying)=="boolean") and type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    -- Compares the seconds left on the item's (or chosen trinket slot's) cooldown with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param now number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateItemCondition returns, including build-context-unavailable for a slot
    -- before the equipment snapshot exists. now is the poll's time.
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_COOLDOWN",value,cache,now)
    end,
    -- Builds the readable rule summary for the ITEM_COOLDOWN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; a trinket slot reads as "your Trinket n".
    print = function(_, value)
        if value.slot ~= nil then
            return Functions.presentation.compareString(value.operator,
                string.format(L["the cooldown on your %s"], Functions.presentation.nullable(TRINKET_SLOTS[value.slot], L["<trinket slot>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
        end
        return Summary.phrase(L["the cooldown on {item} {comparison} {duration}{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            comparison = Summary.predicate(value.operator, true),
            duration = string.format(L["%s seconds"], Functions.presentation.nullable(value.value)),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
    end,
    -- Builds the editor controls for the ITEM_COOLDOWN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the item picker, the optional trinket slot, the operator and seconds, and Check If Not Carrying.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        -- Optional: read a trinket slot instead of the item above.
        local slot = addon:CreateConditionDropdown()
        slot:SetLabel(L["Trinket Slot"])
        slot:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then value.slot = nil else value.slot = v end
            top:SetStatusText(funcs:print(root, spec))
        end)
        slot.configure = function()
            local choices, order = { [""] = L["None (use the item above)"] }, { "" }
            for _, key in ipairs(TRINKET_SLOT_ORDER) do choices[key] = TRINKET_SLOTS[key]; order[#order + 1] = key end
            slot:SetList(choices, order)
            slot:SetValue(value.slot ~= nil and value.slot or "")
        end
        parent:AddChild(slot)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    -- Builds the help page for the ITEM_COOLDOWN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared item text, the trinket slot, the operator text, then Check If Not Carrying.
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Trinket Slot"] .. color.RESET .. " - " .. L["Choose a trinket slot to read whatever is equipped there, so one rotation works for every trinket; the item above is then ignored. An empty slot is false, and a trinket with no on-use effect is unavailable."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Item Cooldown"], L["Seconds"],
            "The number of seconds before you can use the top item found in " .. color.BLIZ_YELLOW .. L["Item Set"] ..
            color.RESET .. ".  If you are not carrying any item in the item set, this condition will not be " ..
            "successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="TRINKET_SLOTS" then return TRINKET_SLOTS end
        if name=="TRINKET_SLOT_ORDER" then return TRINKET_SLOT_ORDER end
        if name=="color" then return color end
        if name=="get_item_desc" then return get_item_desc end
        if name=="helpers" then return helpers end
        if name=="itemHelp" then return itemHelp end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/item.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/item.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
