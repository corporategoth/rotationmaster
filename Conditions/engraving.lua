local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local platform = addon.Platform

-- Season of Discovery rune engraving (Platform/engraving.lua). Whether a rune
-- is engraved on one of the player's equipped items, named by the rune
-- itself (its skillLineAbilityID, what C_Engraving keys runes by) or by a
-- spell the rune teaches (portable, and nameable on any character). This is
-- not the Death Knight RUNE / RUNE_COOLDOWN resource. The engraved set is
-- read once per equipment or rune change (Core/build_context.lua), so a poll
-- costs a table lookup. Without C_Engraving, on a realm without engraving or
-- before the rune list has loaded, the condition is unavailable, including
-- under NOT.
local Functions={
    presentation={nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/engraving.lua"]={
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

-- No original artwork yet: this placeholder reuses the Equipped icon until a
-- semantic engraving icon is generated (tests/condition_icons.lua lists it as
-- pending). A generated catalog entry takes precedence.
if addon.Artwork and addon.Artwork.condition and addon.Artwork.condition["RUNE_ENGRAVED"] == nil then
    addon.Artwork.condition["RUNE_ENGRAVED"] = addon.Artwork.condition["EQUIPPED"]
end

local function identifier(value)
    return type(value) == "number" and value > 0 and value < 2147483648 and value % 1 == 0
end

-- A readable label: the known rune's name, else the taught spell's name, else
-- the raw ID.
local function runeLabel(value)
    local known = platform.FindKnownRune and platform:FindKnownRune(value.rune, value.spell)
    if known and known.name then return known.name end
    if value.spell ~= nil then
        local info = platform.GetSpellInfo and platform:GetSpellInfo(value.spell)
        if info and info.name then return info.name end
        return string.format(L["rune spell %s"], tostring(value.spell))
    end
    if value.rune ~= nil then return string.format(L["rune %s"], tostring(value.rune)) end
end

addon:RegisterCondition("RUNE_ENGRAVED", {
    description = L["Engraved Rune"],
    icon = addon.Artwork.condition["RUNE_ENGRAVED"],
    fields = { rune = "number", spell = "number" },
    valid = function(_, value)
        if value.rune ~= nil then return identifier(value.rune) and value.spell == nil end
        return identifier(value.spell)
    end,
    evaluate = function(value)
        if not addon.IsRuneEngraved then return nil, "build-context-unavailable" end
        return addon:IsRuneEngraved(value.rune, value.spell)
    end,
    print = function(_, value)
        return string.format(L["you {{!have|do not have}} the rune %s engraved"],
            Functions.presentation.nullable(runeLabel(value), L["<rune>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local function update() top:SetStatusText(funcs:print(root, spec)) end

        local groups, why
        if platform.GetKnownRunes then groups, why = platform:GetKnownRunes() else why = "missing-api" end
        if not groups then
            local label = addon:CreateConditionLabel()
            label:SetFullWidth(true)
            label:SetText(why == "rune-data-pending" and L["Your runes have not loaded yet. Reopen this condition shortly, or enter an ID below."]
                or L["This character cannot engrave runes. A rune entered by ID below is kept, and is unavailable here."])
            parent:AddChild(label)
            groups = {}
        end

        local slots, slotOrder = {}, {}
        local selectedSlot, selectedRune
        for index, group in ipairs(groups) do
            slots[index] = group.name or string.format(L["Slot %d"], group.category)
            slotOrder[#slotOrder + 1] = index
            for runeIndex, record in ipairs(group.runes) do
                local matches = value.rune ~= nil and record.rune == value.rune
                if value.spell ~= nil then
                    for _, spell in ipairs(record.spells) do if spell == value.spell then matches = true end end
                end
                if matches then selectedSlot, selectedRune = index, runeIndex end
            end
        end
        local runes, runeOrder = {}, {}
        local function choices()
            runes, runeOrder = {}, {}
            local group = selectedSlot and groups[selectedSlot]
            for index, record in ipairs(group and group.runes or {}) do
                runes[index] = record.name or string.format(L["rune %s"], tostring(record.rune))
                runeOrder[#runeOrder + 1] = index
            end
        end
        choices()

        local runeIcon, runePicker, spellBox, runeBox
        local slotPicker = addon:CreateConditionDropdown()
        slotPicker:SetLabel(L["Equipment Slot"])
        slotPicker:SetCallback("OnValueChanged", function(_, _, selected)
            if selected == selectedSlot then return end
            selectedSlot, selectedRune = selected, nil
            choices()
            runePicker:SetList(runes, runeOrder); runePicker:SetValue(nil); runePicker:SetDisabled(#runeOrder == 0)
        end)
        slotPicker.configure = function() slotPicker:SetList(slots, slotOrder); slotPicker:SetValue(selectedSlot) end
        slotPicker:SetDisabled(#slotOrder == 0)
        parent:AddChild(slotPicker)

        runeIcon = addon:CreateConditionIcon()
        runeIcon:SetWidth(44); runeIcon:SetHeight(44); runeIcon:SetImageSize(36, 36)
        local current = selectedSlot and groups[selectedSlot].runes[selectedRune]
        runeIcon:SetImage(current and current.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        parent:AddChild(runeIcon)

        runePicker = addon:CreateConditionDropdown()
        runePicker:SetLabel(L["Rune"])
        runePicker:SetCallback("OnValueChanged", function(_, _, selected)
            local record = selectedSlot and groups[selectedSlot].runes[selected]
            if not record then return end
            selectedRune = selected
            -- Prefer the taught spell: it names the rune on any character.
            if record.spells[1] then value.spell, value.rune = record.spells[1], nil
            else value.spell, value.rune = nil, record.rune end
            spellBox:SetText(value.spell and tostring(value.spell) or "")
            runeBox:SetText(value.rune and tostring(value.rune) or "")
            runeIcon:SetImage(record.icon)
            update()
        end)
        runePicker.configure = function() runePicker:SetList(runes, runeOrder); runePicker:SetValue(selectedRune) end
        runePicker:SetDisabled(#runeOrder == 0)
        parent:AddChild(runePicker)

        local function manual(box, key, other)
            box:SetCallback("OnEnterPressed", function(_, _, entered)
                local number = tonumber(entered)
                if not identifier(number) then box:SetText(value[key] and tostring(value[key]) or ""); return end
                value[key], value[other] = number, nil
                spellBox:SetText(value.spell and tostring(value.spell) or "")
                runeBox:SetText(value.rune and tostring(value.rune) or "")
                selectedRune = nil; runePicker:SetValue(nil)
                local known = platform.FindKnownRune and platform:FindKnownRune(value.rune, value.spell)
                runeIcon:SetImage(known and known.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                update()
            end)
            parent:AddChild(box)
        end
        spellBox = addon:CreateConditionEditBox()
        spellBox:SetLabel(L["Rune Spell ID"])
        if value.spell ~= nil then spellBox:SetText(tostring(value.spell)) end
        runeBox = addon:CreateConditionEditBox()
        runeBox:SetLabel(L["Rune ID"])
        if value.rune ~= nil then runeBox:SetText(tostring(value.rune)) end
        manual(spellBox, "spell", "rune")
        manual(runeBox, "rune", "spell")
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when a Season of Discovery rune is engraved on one of your equipped items. Passive runes count too, which a known-spell test cannot see."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune"] .. color.RESET .. " - " ..
            L["Pick one of your known runes by equipment slot. The rune is saved by the first spell it teaches, so a shared rotation names it on any character."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune Spell ID"] .. color.RESET .. " / " .. color.BLIZ_YELLOW .. L["Rune ID"] .. color.RESET .. " - " ..
            L["Enter a spell the rune teaches, or the rune's own ID (its skill line ability ID) for a rune that teaches no spell. Entering one clears the other."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Engraving exists only on Season of Discovery realms. Elsewhere, and until your runes have loaded after logging in, this condition is unavailable rather than false, including under NOT. The Phase 7 shoulder runes are not engravings and are not seen. This is not the Death Knight Rune condition."]))
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
        if name=="identifier" then return identifier end
        if name=="platform" then return platform end
        if name=="runeLabel" then return runeLabel end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/engraving.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/engraving.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
