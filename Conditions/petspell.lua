-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Pet spell conditions: PETSPELL_AVAIL, PETSPELL_RANGE, PETSPELL_COOLDOWN, PETSPELL_REMAIN, PETSPELL_CHARGES,
-- PETSPELL_HISTORY, PETSPELL_HISTORY_TIME and PETSPELL_ACTIVE. They mirror the player spell conditions but pick the
-- spell from the pet spellbook (BOOKTYPE_PET) and are false whenever the spell is not known. Every game read goes
-- through addon.Platform (IsSpellKnown, IsSpellReady, GetSpellCooldown, GetSpellCharges, GetSpellRangeState,
-- IsCurrentSpell) via the evaluation cache, so a hidden value on a restricted client (Retail, Forever) gives nil and a
-- reason rather than a compared secret; the history conditions also test platform:CanReadValue themselves. They read
-- addon.spellHistory, which main.lua fills from player and pet casts. Loaded from the Conditions group of
-- RotationMaster.toc, after Conditions/known_spell.lua. The callback bodies are frozen: saved custom conditions bind to
-- their exact text, and the generated block at the end of the file is rewritten by tools/generate_builtin_sources.py.
local addon_name, addon = ...

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

addon.builtinCallbackBindings["Conditions/petspell.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- ============================================================================
-- Availability and range
-- ============================================================================

-- PETSPELL_AVAIL tests that a pet spell is known and ready to cast now. Returns false for an unknown spell, and
-- nil and a reason when the spell id or the known/ready state cannot be read. Stores spell; the ranked flag is declared
-- but this condition never passes it on (the spell id is always resolved unranked).
addon:RegisterCondition("PETSPELL_AVAIL", {
    description = L["Pet Spell Available"],
    icon = addon.Artwork.condition["PETSPELL_AVAIL"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the PETSPELL_AVAIL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell id the client knows is chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    -- Decides whether the chosen pet spell is known and ready to cast now; false for an unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, or whatever reason IsSpellKnown or IsSpellReady gives. evalStart is the
    -- poll's time, which readiness is judged against.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        return Functions.cache.getCached(cache, addon.Platform.IsSpellReady, addon.Platform, spellid, evalStart)
    end,
    -- Builds the readable rule summary for the PETSPELL_AVAIL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; the {{!is|is not}} pair flips under NOT.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} available"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the PETSPELL_AVAIL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
                                    function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
                                    function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the PETSPELL_AVAIL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared spell picker text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- PETSPELL_RANGE tests that the current target is in range of a pet spell. Returns false with no target, with an
-- unknown spell, or when the spell has no range to test; nil and a reason when any of those reads fails. Stores spell.
addon:RegisterCondition("PETSPELL_RANGE", {
    description = L["Pet Spell In Range"],
    icon = addon.Artwork.condition["PETSPELL_RANGE"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the PETSPELL_RANGE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell id the client knows is chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    -- Decides whether the current target is in range of the chosen pet spell, measured from the pet; false with no
    -- target, an unknown spell or a spell with no range.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: unit-data-unavailable (target presence), spell-data-unavailable, or the reason from IsSpellKnown or
    -- GetSpellRangeState. The range is measured from the pet to the target.
    evaluate = function(value, cache)
        local exists,presenceReason=Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, "target")
        if exists==nil then return nil,presenceReason or 'unit-data-unavailable' end
        if not exists then return false end
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, "target", "pet")
        if not range then return nil, why end
        return range.applicable and range.inRange or false
    end,
    -- Builds the readable rule summary for the PETSPELL_RANGE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} in range"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the PETSPELL_RANGE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the PETSPELL_RANGE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared spell picker text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- ============================================================================
-- Cooldown and charges
-- ============================================================================

-- PETSPELL_COOLDOWN compares the seconds left on a pet spell's cooldown. Returns false for an unknown spell, and nil
-- and a reason when the cooldown cannot be read or is held (not enabled). Stores spell, operator and value (seconds).
addon:RegisterCondition("PETSPELL_COOLDOWN", {
    description = L["Pet Spell Cooldown"],
    icon = addon.Artwork.condition["PETSPELL_COOLDOWN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the PETSPELL_COOLDOWN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known spell, a listed operator and a non-negative number of seconds.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the seconds left on the chosen pet spell's cooldown with the configured number; false for an unknown
    -- spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, cooldown-held (the cooldown is paused), or the reason from IsSpellKnown or
    -- GetSpellCooldown. The remaining time is measured against evalStart, the poll's time, and rounded to milliseconds.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local cooldown, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCooldown, addon.Platform, spellid)
        if not cooldown then return nil, why end
        if not cooldown.isEnabled then return nil, "cooldown-held" end
        local remain = math.max(0, addon.Functions.values.round(cooldown.startTime + cooldown.duration - evalStart, 3))
        return Functions.values.compare(value.operator, remain, value.value)
    end,
    -- Builds the readable rule summary for the PETSPELL_COOLDOWN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
                Functions.presentation.compareString(value.operator, string.format(L["cooldown on %s"],  Functions.presentation.nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the PETSPELL_COOLDOWN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker, then the operator and seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
                                    function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
                                    function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the PETSPELL_COOLDOWN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the spell picker text, then the operator text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cooldown"], L["Seconds"],
            "The number of seconds before you can cast " .. color.BLIZ_YELLOW .. L["Pet Spell"] .. color.RESET .. ".")
    end,
})

-- PETSPELL_REMAIN compares the seconds until a pet spell's next charge returns; zero when no recharge is running.
-- Returns false for an unknown spell, and nil and a reason when the charge data is unreadable. Stores spell, operator
-- and value (seconds).
addon:RegisterCondition("PETSPELL_REMAIN", {
    description = L["Pet Spell Recharge Time"],
    icon = addon.Artwork.condition["PETSPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the PETSPELL_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known spell, a listed operator and a non-negative number of seconds.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the seconds until the chosen pet spell's next charge returns (zero when no recharge is running) with the
    -- configured number; false for an unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, or the reason from IsSpellKnown or GetSpellCharges (missing, restricted or a
    -- spell without charges). evalStart is the poll's time.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local charges, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCharges, addon.Platform, spellid)
        if not charges then return nil, why end
        local remain = 0
        if charges.isActive then
            remain = math.max(0, charges.cooldownStartTime + charges.cooldownDuration - evalStart)
        end
        return Functions.values.compare(value.operator, remain, value.value)
    end,
    -- Builds the readable rule summary for the PETSPELL_REMAIN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["recharge time on %s"], Functions.presentation.nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the PETSPELL_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker, then the operator and seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the PETSPELL_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the spell picker text, then the operator text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Recharge Time"], L["Seconds"],
            L["Seconds until the next spell charge. Full charges and inactive recharge timers report zero. Missing, restricted, or non-charge spell data stays unavailable."])
    end,
})

-- PETSPELL_CHARGES compares the number of charges a pet spell currently holds. Returns false for an unknown spell, and
-- nil and a reason when the charge data is unreadable. Stores spell, operator and value (a count).
addon:RegisterCondition("PETSPELL_CHARGES", {
    description = L["Pet Spell Charges"],
    icon = addon.Artwork.condition["PETSPELL_CHARGES"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the PETSPELL_CHARGES condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known spell, a listed operator and a non-negative count.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the number of charges the chosen pet spell currently holds with the configured number; false for an
    -- unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, or the reason from IsSpellKnown or GetSpellCharges.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local charges, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCharges, addon.Platform, spellid)
        if not charges then return nil, why end
        return Functions.values.compare(value.operator, charges.currentCharges, value.value)
    end,
    -- Builds the readable rule summary for the PETSPELL_CHARGES condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["number of charges on %s"], Functions.presentation.nullable(link, L["<spell>"])), Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the PETSPELL_CHARGES condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker, then the operator and charge count.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Charges"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the PETSPELL_CHARGES condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the spell picker text, then the operator text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Charges"], L["Charges"],
            "The number of charges of " .. color.BLIZ_YELLOW .. L["Pet Spell"] .. color.RESET .. " currently active.")
    end,
})

-- ============================================================================
-- Cast history
-- ============================================================================

-- PETSPELL_HISTORY tests whether a pet spell was cast a given number of casts ago (1 is the last cast). Walks
-- addon.spellHistory, newest first, so the first matching entry decides. Returns false when nothing matches, and nil
-- and "restricted-value" when only a cast whose spell was hidden could match. Stores spell, operator and value (casts).
addon:RegisterCondition("PETSPELL_HISTORY", {
    description = L["Pet Spell Cast History"],
    icon = addon.Artwork.condition["PETSPELL_HISTORY"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the PETSPELL_HISTORY condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known spell, a listed operator and a non-negative cast count.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Decides whether the chosen pet spell was cast the configured number of casts ago (1 is the last cast); false for
    -- an unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, the reason from IsSpellKnown, or restricted-value when a hidden cast might
    -- have been this spell and no readable entry matched.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local unknown
        for idx, entry in pairs(addon.spellHistory) do
            local spell = entry.spell
            if spell == false then
                -- A cast whose spell was secret (restricted clients) may be this one.
                if Functions.values.compare(value.operator, idx, value.value) ~= false then unknown = true end
            else
                local matches = spell == spellid and Functions.values.compare(value.operator, idx, value.value)
                if matches ~= false then return matches end
            end
        end
        if unknown then return nil, "restricted-value" end
        return false
    end,
    -- Builds the readable rule summary for the PETSPELL_HISTORY condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; falls back to a generic "casts ago" wording for an unlisted operator.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        local ago = addon.historyCastsAgo[value.operator]
        return string.format(L["%s {{!was|was not}} cast %s"], Functions.presentation.nullable(link, L["<spell>"]),
                        ago and string.format(ago, Functions.presentation.nullable(value.value))
                        or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s casts ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the PETSPELL_HISTORY condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker, then the operator and cast count.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the PETSPELL_HISTORY condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the spell picker text, then how the count and the history memory setting work.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cast History"], L["Count"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Pet Spell"] ..
            color.RESET .. " (by count).  A value of 1 means your last spell cast, 2 means two spells ago, etc.  " ..
            "Each instance of the same spell cast is treated separately.  Any spell cast more than the setting " ..
            "of " .. color.BLUE .. L["Pet Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation " ..
            "Master configuration screen ago will not be available.")
    end,
})

-- PETSPELL_HISTORY_TIME tests whether a pet spell was cast a given number of seconds ago. Walks addon.spellHistory,
-- newest first, and compares the age of each matching cast. Returns false when nothing matches, and nil and a reason
-- when a timestamp is unreadable. Stores spell, operator and value (seconds).
addon:RegisterCondition("PETSPELL_HISTORY_TIME", {
    description = L["Pet Spell Cast History Time"],
    icon = addon.Artwork.condition["PETSPELL_HISTORY_TIME"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the PETSPELL_HISTORY_TIME condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known spell, a listed operator and a non-negative number of seconds.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Decides whether the chosen pet spell was cast a number of seconds ago that passes the comparison; false for an
    -- unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, the reason from IsSpellKnown, restricted-value (a hidden timestamp, or a
    -- hidden cast that might match), or history-time-unavailable (a timestamp that is not a finite number).
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        local unknown
        for _, entry in pairs(addon.spellHistory) do
            local spell = entry.spell
            local secret = spell == false
            if secret or spell == spellid then
                local compare,operator=Functions.values.compare,value.operator
                local recorded=entry.time
                if not addon.Platform:CanReadValue(evalStart) or not addon.Platform:CanReadValue(recorded) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart==math.huge or evalStart==-math.huge
                    or type(recorded)~='number' or recorded~=recorded or recorded==math.huge or recorded==-math.huge then return nil,'history-time-unavailable' end
                local elapsed=evalStart-recorded
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed==math.huge or elapsed==-math.huge then return nil,'history-time-unavailable' end
                local matches=compare(operator,elapsed,value.value)
                -- A cast whose spell was secret (restricted clients) may be this one.
                if secret then
                    if matches ~= false then unknown = true end
                elseif matches ~= false then return matches end
            end
        end
        if unknown then return nil, "restricted-value" end
        return false
    end,
    -- Builds the readable rule summary for the PETSPELL_HISTORY_TIME condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; falls back to a generic "seconds ago" wording for an unlisted operator.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        local ago = addon.historySecondsAgo[value.operator]
        return string.format(L["%s {{!was|was not}} cast %s"], Functions.presentation.nullable(link, L["<spell>"]),
                ago and string.format(ago, Functions.presentation.nullable(value.value))
                or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s seconds ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the PETSPELL_HISTORY_TIME condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker, then the operator and seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the PETSPELL_HISTORY_TIME condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the spell picker text, then how the time window and the history memory setting work.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cast History Time"], L["Seconds"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Pet Spell"] ..
            color.RESET .. " (by time).  Any spell cast more than the setting of " .. color.BLUE ..
            L["Pet Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end,
})

-- ============================================================================
-- Pending cast
-- ============================================================================

-- PETSPELL_ACTIVE tests whether a pet spell is the game's current (active or pending) spell. Returns false for an
-- unknown spell, and nil and a reason when the state cannot be read. Stores spell.
addon:RegisterCondition("PETSPELL_ACTIVE", {
    description = L["Pet Spell Active or Pending"],
    icon = addon.Artwork.condition["PETSPELL_ACTIVE"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the PETSPELL_ACTIVE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a spell id the client knows is chosen.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    -- Decides whether the chosen pet spell is the game's current (active or pending) spell; false for an unknown spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: spell-data-unavailable, or the reason from IsSpellKnown or IsCurrentSpell.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        return Functions.cache.getCached(cache, addon.Platform.IsCurrentSpell, addon.Platform, spellid)
    end,
    -- Builds the readable rule summary for the PETSPELL_ACTIVE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} active or pending"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the PETSPELL_ACTIVE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the pet spell picker.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget((BOOKTYPE_PET or "pet"), "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID((BOOKTYPE_PET or "pet"), v) end,
            function(v) return addon.isSpellOnSpec((BOOKTYPE_PET or "pet"), v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the PETSPELL_ACTIVE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the shared spell picker text.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/petspell.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/petspell.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
