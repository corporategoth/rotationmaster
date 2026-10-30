-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In Shaman totem conditions: TOTEM (the totem in an element slot is active), TOTEM_REMAIN (compares its seconds
-- left), TOTEM_SPELL (a specific totem spell is active in any slot) and TOTEM_SPELL_REMAIN (compares that totem's
-- seconds left). Slots are read through Platform:GetTotemInfo and GetTotemSlotCount (Platform/totems.lua), which return
-- a record or nil and a reason; on Retail and Forever a slot the client hides as a secret value makes the condition
-- unavailable (nil, reason), also under NOT. An empty, zero-duration or expired totem is a readable false.
-- The whole file returns at load for any class but Shaman, so nothing is registered for other classes. Loaded from
-- RotationMaster.toc after Conditions/debuffs.lua. Callback and helper bodies are hashed by saved copies and bundles:
-- never add or change text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

-- Skip these if we're not a shaman .. no point having totem conditions for other classes.
if select(2, UnitClass("player")) ~= "SHAMAN" then
    return
end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical leaves for direct callbacks; private observation and validation
-- helpers keep their existing source contracts for saved custom requirements.
local Functions = {
    collections = { keys = addon.Functions.collections.keys },
    values = { compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/totem.lua"] = {
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
}

local platform = addon.Platform

-- ============================================================================
-- Helpers
-- ============================================================================

-- Calls a Platform reader through the per-poll cache.
-- @param cache table  The per-pass memo table the read is cached in.
-- @param method function  The Platform method to call (with the platform as self).
-- @param ... any  Arguments passed to method after the platform.
-- @return any  The reader's value; nil when it cannot be read.
-- @return string|nil  The reason code when the value is nil; nil otherwise.
local function observe(cache, method, ...)
    return addon.getCached(cache,method,platform,...)
end

-- Computes the seconds left on a totem record.
-- @param record table  A totem record with active, startTime and duration.
-- @param start number|nil  The time to measure against (the poll's time); nil means now.
-- @return number  The seconds left, never below 0; 0 for an inactive slot.
local function remaining(record, start)
    if not record.active then return 0 end
    return math.max(0,record.startTime+record.duration-(start or GetTime()))
end

-- True when value.spell is one of the four element slots (1 to 4: Fire, Earth, Water, Air) the TOTEM conditions use.
-- @param value table  The saved condition fields; reads spell.
-- @return boolean  True when spell is a valid spell ID that is at most 4.
local function element(value)
    return addon.IsConditionSpellID(value.spell) and value.spell<=4
end

-- True when the saved fields carry a known operator and a finite, non-negative number to compare against.
-- @param value table  The saved condition fields; reads operator and value.
-- @return boolean  True when value is a finite number of at least 0 and operator is one of addon.operators.
local function amount(value)
    return type(value.value)=="number" and value.value==value.value and value.value>=0 and value.value<math.huge
        and type(value.operator)=="string" and addon.isin(addon.operators,value.operator)
end

-- True when value.spell is a spell ID and value.ranked, if set, is a boolean (the TOTEM_SPELL conditions).
-- @param value table  The saved condition fields; reads spell and ranked.
-- @return boolean  True when the fields have that shape.
local function specific(value)
    return addon.IsConditionSpellID(value.spell) and (value.ranked==nil or type(value.ranked)=="boolean")
end

-- Scans every totem slot for an active totem of the chosen spell.
-- @param value table  The saved condition fields: spell, ranked and, with compareTime, operator and value.
-- @param cache table  The per-pass memo table the reads are cached in.
-- @param start number|nil  The time to measure remaining seconds against (the poll's time); nil means now.
-- @param compareTime boolean  True to also require the remaining seconds (rounded to milliseconds) to pass the operator
--     test.
-- @return boolean|nil  True on the first match, false when no slot matches and every slot was readable; nil when no
--     match was found but some slot could not be read well enough to rule one out.
-- @return string|nil  The reason code when the first value is nil ("totem-data-unavailable", "totem-rank-unavailable",
--     "totem-identity-unavailable" or the Platform's); nil otherwise.
--
-- Without ranked it matches by spell ID or by the localized name (looking up a nameless slot's spell to compare names);
-- with ranked it needs the exact spell ID.
local function findSpecific(value, cache, start, compareTime)
    local target,reason=observe(cache,platform.GetSpellInfo,value.spell)
    if not target then return nil,reason end
    local count,why=observe(cache,platform.GetTotemSlotCount)
    if not count then return nil,why end
    local unavailable
    for slot=1,count do
        local record,problem=observe(cache,platform.GetTotemInfo,slot)
        if not record then unavailable=unavailable or problem or "totem-data-unavailable"
        elseif record.active and remaining(record,start)>0 then
            local matches=false
            if value.ranked then
                if record.spellID then matches=record.spellID==value.spell
                elseif record.name==target.name or record.name=="" then unavailable=unavailable or "totem-rank-unavailable" end
            else
                matches=record.spellID==value.spell or record.name==target.name
                if not matches and record.name=="" then
                    local info,issue
                    if record.spellID then info,issue=observe(cache,platform.GetSpellInfo,record.spellID) end
                    if info then matches=info.name==target.name
                    else unavailable=unavailable or issue or "totem-identity-unavailable" end
                end
            end
            if matches and (not compareTime or addon.compare(value.operator,addon.round(remaining(record,start),3),value.value)) then return true end
        end
    end
    if unavailable then return nil,unavailable end
    return false
end

-- ============================================================================
-- Totem in an element slot
-- ============================================================================

-- TOTEM: true when the totem in the chosen element slot is active with time left. Stores `spell` (the slot number,
-- 1 to 4, despite the field name). False for an empty, zero-duration or expired slot; `nil, reason` when the slot
-- cannot be read.
addon:RegisterCondition("TOTEM", {
    description = L["Totem Present"],
    icon = addon.Artwork.condition["TOTEM"],
    fields = { spell = "number" },
    requiredFields = { "spell" },
    -- Checks that the saved fields of the TOTEM condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once an element slot is chosen.
    valid = function(_, value) return element(value) end,
    -- Decides whether the totem in the chosen element slot is active with time left.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the slot record is unreadable (for example a secret value on a restricted client).
    evaluate = function(value, cache, start)
        local record,reason=observe(cache,platform.GetTotemInfo,value.spell)
        if not record then return nil,reason end
        return record.active and remaining(record,start)>0
    end,
    -- Builds the readable rule summary for the TOTEM condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary naming the element.
    print = function(_, value)
        return string.format(L["%s totem {{!is|is not}} active"], Functions.presentation.nullable(addon.totems[value.spell], L["<element>"]))
    end,
    -- Builds the editor controls for the TOTEM condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the element dropdown; help explains the slot.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = addon:CreateConditionDropdown()
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(addon.totems, Functions.collections.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)
    end,
    -- Builds the help page for the TOTEM condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            L["The elemental slot to check: Fire, Earth, Water or Air. Empty, zero-duration and expired totems do not match."]))
    end,
})

-- ============================================================================
-- Specific totem spell
-- ============================================================================

-- TOTEM_SPELL: true when an active totem of the chosen spell is in any slot. Stores `spell` and `ranked` (match the
-- exact rank). Result and unavailable cases are those of findSpecific.
addon:RegisterCondition("TOTEM_SPELL", {
    description = L["Specific Totem Present"],
    icon = addon.Artwork.condition["TOTEM_SPELL"],
    fields = { spell = "number", ranked = "boolean" },
    requiredFields = { "spell" },
    -- Checks that the saved fields of the TOTEM_SPELL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a spell ID and an optional boolean ranked flag.
    valid = function(_, value) return specific(value) end,
    -- Decides whether an active totem of the chosen spell is in any slot.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Delegates to findSpecific without a time comparison.
    evaluate = function(value, cache, start) return findSpecific(value,cache,start,false) end,
    -- Builds the readable rule summary for the TOTEM_SPELL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} active"], Functions.presentation.nullable(link, L["<totem>"]))
    end,
    -- Builds the editor controls for the TOTEM_SPELL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds a spell picker limited to totem spells on the rotation's specialization; help explains the rank
    -- checkbox.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v)
                local info=addon.Platform:GetSpellInfo(v)
                return addon.isSpellOnSpec(spec,v) and info and string.find(info.name,L["Totem"],1,true)~=nil
            end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the TOTEM_SPELL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            L["The active totem to check. Unticked, Use this exact spell rank matches its localized name across ranks. Ticked, it requires the native spell ID; name-only observations are unavailable."]))
    end,
})

-- ============================================================================
-- Time remaining
-- ============================================================================

-- TOTEM_REMAIN: compares the seconds left on the totem in the chosen element slot with a number. Stores `spell` (the
-- slot number, 1 to 4), `operator` and `value`. False for an empty or expired slot, whatever the operator; `nil,
-- reason` when the slot cannot be read.
addon:RegisterCondition("TOTEM_REMAIN", {
    description = L["Totem Time Remaining"],
    icon = addon.Artwork.condition["TOTEM_REMAIN"],
    fields = { spell = "number", operator = "string", value = "number" },
    requiredFields = { "spell", "operator", "value" },
    -- Checks that the saved fields of the TOTEM_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with an element slot and a comparison (known operator, finite non-negative number).
    valid = function(_, value) return element(value) and amount(value) end,
    -- Compares the seconds left on the totem in the chosen element slot with the configured number; false for an empty
    -- or expired slot.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the slot record is unreadable; the remaining seconds are rounded to milliseconds first.
    evaluate = function(value, cache, start)
        local record,reason=observe(cache,platform.GetTotemInfo,value.spell)
        if not record then return nil,reason end
        local seconds=remaining(record,start)
        return record.active and seconds>0 and Functions.values.compare(value.operator,addon.Functions.values.round(seconds,3),value.value)
    end,
    -- Builds the readable rule summary for the TOTEM_REMAIN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary naming the element and the comparison.
    print = function(_, value)
        return string.format(L["you {{!have|do not have}} a %s totem active where %s"],
            Functions.presentation.nullable(addon.totems[value.spell], L["<element>"]),
                Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the TOTEM_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the element dropdown and an operator-and-seconds control; help explains both.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = addon:CreateConditionDropdown()
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(addon.totems, Functions.collections.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the TOTEM_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                L["The elemental slot to check: Fire, Earth, Water or Air. Empty, zero-duration and expired totems do not match."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Totem Time Remaining"], L["Seconds"],
            L["Compare the active totem's remaining seconds with this amount. An absent or expired totem does not match; unavailable observations stay unavailable."])
    end,
})

-- TOTEM_SPELL_REMAIN: true when an active totem of the chosen spell, in any slot, has remaining seconds that pass the
-- comparison. Stores `spell`, `ranked`, `operator` and `value`. Result and unavailable cases are those of
-- findSpecific with the time comparison on.
addon:RegisterCondition("TOTEM_SPELL_REMAIN", {
    description = L["Specific Totem Time Remaining"],
    icon = addon.Artwork.condition["TOTEM_SPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    requiredFields = { "spell", "operator", "value" },
    -- Checks that the saved fields of the TOTEM_SPELL_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a spell ID, an optional boolean ranked flag and a comparison.
    valid = function(_, value) return specific(value) and amount(value) end,
    -- Decides whether an active totem of the chosen spell, in any slot, has remaining seconds that pass the comparison.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Delegates to findSpecific with the time comparison.
    evaluate = function(value, cache, start) return findSpecific(value,cache,start,true) end,
    -- Builds the readable rule summary for the TOTEM_SPELL_REMAIN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary with the spell link and the comparison.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} active where %s"], Functions.presentation.nullable(link, L["<totem>"]),
            Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the TOTEM_SPELL_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds a totem spell picker and an operator-and-seconds control; help explains both.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v)
                local info=addon.Platform:GetSpellInfo(v)
                return addon.isSpellOnSpec(spec,v) and info and string.find(info.name,L["Totem"],1,true)~=nil
            end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the TOTEM_SPELL_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                L["The active totem to check. Unticked, Use this exact spell rank matches its localized name across ranks. Ticked, it requires the native spell ID; name-only observations are unavailable."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Specific Totem Time Remaining"], L["Seconds"],
            L["Compare the active totem's remaining seconds with this amount. An absent or expired totem does not match; unavailable observations stay unavailable."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="amount" then return amount end
        if name=="color" then return color end
        if name=="element" then return element end
        if name=="findSpecific" then return findSpecific end
        if name=="helpers" then return helpers end
        if name=="observe" then return observe end
        if name=="platform" then return platform end
        if name=="remaining" then return remaining end
        if name=="specific" then return specific end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/totem.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/totem.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
