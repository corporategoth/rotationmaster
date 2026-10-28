-- Built In spell-state conditions for any spell ID: ANYSPELL_AVAIL, ANYSPELL_RANGE, ANYSPELL_COOLDOWN, ANYSPELL_REMAIN
-- and ANYSPELL_CHARGES. They test the same things as SPELL_AVAIL, SPELL_RANGE, SPELL_COOLDOWN, SPELL_REMAIN and
-- SPELL_CHARGES in Conditions/spell.lua, but the picker takes any spell instead of one from the rotation's
-- specialization. Every read goes through addon.Platform (IsSpellReady, GetSpellCooldown, GetSpellCharges,
-- GetSpellRangeState, GetUnitPresenceObservation) behind the per-poll cache, and the ID is resolved by
-- addon:Widget_GetSpellId (Conditions/common.lua), so this file reads no game value itself: a hidden or missing answer
-- on a restricted client is `nil, reason`. All store `spell` and `ranked`. Loaded from RotationMaster.toc after
-- Conditions/spell.lua. Callback bodies are frozen Built In source (saved custom copies bind to them byte for byte):
-- never edit inside one, and leave the generated block at the end alone.
local addon_name, addon = ...

local SpellData = addon.SpellCatalog
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

-- Direct callback leaves use their owning modules; spell observation arguments,
-- rank resolution and book-bank selection keep their existing contracts.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/anyspell.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- ============================================================================
-- Availability and range
-- ============================================================================

-- ANYSPELL_AVAIL: true when the spell can be used at this poll's time `evalStart`. Returns `nil, reason` when the
-- spell ID cannot be resolved or the cooldown state is unreadable. Stores `spell` and `ranked`.
addon:RegisterCondition("ANYSPELL_AVAIL", {
    description = L["Any Spell Available"],
    icon = addon.Artwork.condition["ANYSPELL_AVAIL"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the ANYSPELL_AVAIL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a positive integer spell ID is chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    -- Decides whether the chosen spell is ready to use at this pass's time.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve ("spell-data-unavailable") or the Platform cannot read the
    -- cooldown; otherwise the readiness boolean.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        return Functions.cache.getCached(cache, addon.Platform.IsSpellReady, addon.Platform, spellid, evalStart)
    end,
    -- Builds the readable rule summary for the ANYSPELL_AVAIL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} available"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the ANYSPELL_AVAIL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the spell picker (any spell, no specialization filter); help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return SpellData:GetSpellId(v) end,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the ANYSPELL_AVAIL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- ANYSPELL_RANGE: true when your target is within the spell's range. False when there is no target or the spell has no
-- range; `nil, reason` when target presence, the spell ID or the range state cannot be read. Always checks "target".
-- Stores `spell` and `ranked`.
addon:RegisterCondition("ANYSPELL_RANGE", {
    description = L["Any Spell In Range"],
    icon = addon.Artwork.condition["ANYSPELL_RANGE"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the ANYSPELL_RANGE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a positive integer spell ID is chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    -- Decides whether the target exists and is within the chosen spell's range.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when target presence, the spell ID or the range state is unreadable; a missing target is false.
    evaluate = function(value, cache)
        local exists,presenceReason=Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, "target")
        if exists==nil then return nil,presenceReason or 'unit-data-unavailable' end
        if not exists then return false end
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, "target", "any")
        if not range then return nil, why end
        return range.applicable and range.inRange or false
    end,
    -- Builds the readable rule summary for the ANYSPELL_RANGE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} in range"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the ANYSPELL_RANGE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the spell picker (any spell, no specialization filter); help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return SpellData:GetSpellId(v) end,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the ANYSPELL_RANGE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- ============================================================================
-- Cooldown, recharge and charges
-- ============================================================================

-- ANYSPELL_COOLDOWN: compares the seconds left on the spell's cooldown (measured against this poll's `evalStart`,
-- rounded to milliseconds, 0 when ready) with a number. Stores `spell`, `ranked`, `operator` and `value`. Returns
-- `nil, reason` when the spell ID or the cooldown cannot be read, or when the cooldown is held ("cooldown-held").
addon:RegisterCondition("ANYSPELL_COOLDOWN", {
    description = L["Any Spell Cooldown"],
    icon = addon.Artwork.condition["ANYSPELL_COOLDOWN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the ANYSPELL_COOLDOWN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell ID, a known operator and a non-negative number of seconds are chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the seconds left on the chosen spell's cooldown with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve, the cooldown is unreadable, or the cooldown is paused by the game
    -- (isEnabled false, reason "cooldown-held"); otherwise the comparison of the remaining seconds.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local cooldown, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCooldown, addon.Platform, spellid)
        if not cooldown then return nil, why end
        if not cooldown.isEnabled then return nil, "cooldown-held" end
        local remain = math.max(0, addon.Functions.values.round(cooldown.startTime + cooldown.duration - evalStart, 3))
        return Functions.values.compare(value.operator, remain, value.value)
    end,
    -- Builds the readable rule summary for the ANYSPELL_COOLDOWN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the comparison, with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
                Functions.presentation.compareString(value.operator, string.format(L["cooldown on %s"],  Functions.presentation.nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the ANYSPELL_COOLDOWN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the spell picker (any spell) and an operator-and-seconds control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return SpellData:GetSpellId(v) end,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the ANYSPELL_COOLDOWN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cooldown"], L["Seconds"],
            "The number of seconds before you can cast " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. ".")
    end,
})

-- ANYSPELL_REMAIN: compares the seconds until the spell's next charge returns, measured against `evalStart`, with a
-- number. A spell at full charges, or with no recharge running, counts as 0. Stores `spell`, `ranked`, `operator` and
-- `value`. Returns `nil, reason` when the spell ID or the charge data cannot be read (including a spell that has no
-- charges).
addon:RegisterCondition("ANYSPELL_REMAIN", {
    description = L["Any Spell Recharge Time"],
    icon = addon.Artwork.condition["ANYSPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the ANYSPELL_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell ID, a known operator and a non-negative number of seconds are chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the seconds until the chosen spell's next charge returns with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the Platform cannot read the charges.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local charges, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCharges, addon.Platform, spellid)
        if not charges then return nil, why end
        local remain = 0
        if charges.isActive then
            remain = math.max(0, charges.cooldownStartTime + charges.cooldownDuration - evalStart)
        end
        return Functions.values.compare(value.operator, remain, value.value)
    end,
    -- Builds the readable rule summary for the ANYSPELL_REMAIN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the comparison, with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["recharge time on %s"], Functions.presentation.nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the ANYSPELL_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the spell picker (any spell) and an operator-and-seconds control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return SpellData:GetSpellId(v) end,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the ANYSPELL_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Recharge Time"], L["Seconds"],
            L["Seconds until the next spell charge. Full charges and inactive recharge timers report zero. Missing, restricted, or non-charge spell data stays unavailable."])
    end,
})

-- ANYSPELL_CHARGES: compares the spell's current number of charges with a number. Stores `spell`, `ranked`,
-- `operator` and `value`. Returns `nil, reason` when the spell ID or the charge data cannot be read.
addon:RegisterCondition("ANYSPELL_CHARGES", {
    description = L["Any Spell Charges"],
    icon = addon.Artwork.condition["ANYSPELL_CHARGES"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the ANYSPELL_CHARGES condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell ID, a known operator and a non-negative count are chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the chosen spell's current number of charges with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the Platform cannot read the charges (a hidden count on a
    -- restricted client included).
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local charges, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCharges, addon.Platform, spellid)
        if not charges then return nil, why end
        return Functions.values.compare(value.operator, charges.currentCharges, value.value)
    end,
    -- Builds the readable rule summary for the ANYSPELL_CHARGES condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the comparison, with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["number of charges on %s"], Functions.presentation.nullable(link, L["<spell>"])), Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the ANYSPELL_CHARGES condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the spell picker (any spell) and an operator-and-charges control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return SpellData:GetSpellId(v) end,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Charges"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the ANYSPELL_CHARGES condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Charges"], L["Charges"],
            "The number of charges of " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " currently active.")
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="SpellData" then return SpellData end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/anyspell.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/anyspell.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
