-- Built In spell-state conditions for one spell ID: SPELL_AVAIL, SPELL_RANGE, SPELL_COOLDOWN, SPELL_REMAIN,
-- SPELL_CHARGES, SPELL_HISTORY, SPELL_HISTORY_TIME, SPELL_ACTIVE and SPELL_AUTOREPEAT. Every read goes through
-- addon.Platform (IsSpellReady, GetSpellCooldown, GetSpellCharges, GetSpellRangeState, IsCurrentSpell,
-- IsAutoRepeatActive) behind the per-poll cache, and the spell ID is resolved by addon:Widget_GetSpellId from
-- Conditions/common.lua; this file reads no game value itself, so a restricted or missing answer is `nil, reason`.
-- The cast-history conditions read addon.spellHistory, where a cast whose spell was secret is recorded as `false`.
-- All store `spell` and `ranked`; the editors use the shared spell widget. Loaded from RotationMaster.toc after
-- Conditions/ext_stats.lua and before Conditions/anyspell.lua. Callback bodies are frozen Built In source (saved
-- custom copies bind to them byte for byte): never edit inside one, and leave the generated block at the end alone.
local addon_name, addon = ...

-- Registers each definition with the runtime witness (Core/condition_runtime.lua) when it exists, so the enrollment at
-- the bottom of the file can prove SPELL_ACTIVE and SPELL_AUTOREPEAT were not replaced; otherwise it passes the
-- definition through.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/spell.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Direct callback leaves use their owning modules. Spell observations,
-- rank resolution and cache call arguments keep their existing contracts.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    cache = { getCached = addon.Functions.cache.getCached },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/spell.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
}

-- ============================================================================
-- Availability and range
-- ============================================================================

-- SPELL_AVAIL: true when the spell can be used at this poll's time `evalStart` (a spell whose cooldown ends inside the
-- running global cooldown counts as ready). Returns `nil, reason` when the spell ID cannot be resolved or the cooldown
-- state is unreadable. Stores `spell` and `ranked`.
addon:RegisterCondition("SPELL_AVAIL", {
    description = L["Spell Available"],
    icon = addon.Artwork.condition["SPELL_AVAIL"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the SPELL_AVAIL condition are complete and in range.
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
    -- Decides whether the chosen spell can be used at this pass's time; a spell whose cooldown ends inside the running
    -- global cooldown counts as ready.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable (`nil, reason`) when the spell ID does not resolve ("spell-data-unavailable") or when the Platform
    -- cannot read the cooldown; otherwise the readiness boolean.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        return Functions.cache.getCached(cache, addon.Platform.IsSpellReady, addon.Platform, spellid, evalStart)
    end,
    -- Builds the readable rule summary for the SPELL_AVAIL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} available"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the SPELL_AVAIL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
                                    function(v) return addon.getSpecSpellID(spec, v) end,
                                    function(v) return addon.isSpellOnSpec(spec, v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the SPELL_AVAIL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- SPELL_RANGE: true when your target is within the spell's range. False when there is no target or the spell has no
-- range; `nil, reason` when target presence, the spell ID or the range state cannot be read. Always checks "target".
-- Stores `spell` and `ranked`.
addon:RegisterCondition("SPELL_RANGE", {
    description = L["Spell In Range"],
    icon = addon.Artwork.condition["SPELL_RANGE"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the SPELL_RANGE condition are complete and in range.
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
    -- Decides whether your target is within the chosen spell's range; false when there is no target or the spell has no
    -- range.
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
        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, "target", "spell")
        if not range then return nil, why end
        return range.applicable and range.inRange or false
    end,
    -- Builds the readable rule summary for the SPELL_RANGE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} in range"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the SPELL_RANGE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the SPELL_RANGE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- ============================================================================
-- Cooldowns and charges
-- ============================================================================

-- SPELL_COOLDOWN: compares the seconds left on the spell's cooldown (rounded to milliseconds, never below zero)
-- with `value` using `operator`. Returns `nil, reason` when the cooldown cannot be read, and "cooldown-held" when the
-- client reports the cooldown as not running (isEnabled false, for example a spell held by a buff). Stores `spell`,
-- `ranked`, `operator` and `value`.
addon:RegisterCondition("SPELL_COOLDOWN", {
    description = L["Spell Cooldown"],
    icon = addon.Artwork.condition["SPELL_COOLDOWN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the SPELL_COOLDOWN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a spell ID, a known operator and a non-negative number of seconds.
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
    -- Unavailable when the spell ID does not resolve, the cooldown is unreadable, or the cooldown is held.
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local cooldown, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCooldown, addon.Platform, spellid)
        if not cooldown then return nil, why end
        if not cooldown.isEnabled then return nil, "cooldown-held" end
        local remain = math.max(0, addon.Functions.values.round(cooldown.startTime + cooldown.duration - evalStart, 3))
        return Functions.values.compare(value.operator, remain, value.value)
    end,
    -- Builds the readable rule summary for the SPELL_COOLDOWN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
                Functions.presentation.compareString(value.operator, string.format(L["cooldown on %s"],  Functions.presentation.nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the SPELL_COOLDOWN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
                                    function(v) return addon.getSpecSpellID(spec, v) end,
                                    function(v) return addon.isSpellOnSpec(spec, v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SPELL_COOLDOWN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cooldown"], L["Seconds"],
            "The number of seconds before you can cast " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. ".")
    end,
})

-- SPELL_REMAIN: compares the seconds until the next charge of a spell with charges with `value`; full charges and an
-- inactive recharge timer count as zero. Returns `nil, reason` for a spell without charges or unreadable charge data.
-- Stores `spell`, `ranked`, `operator` and `value`.
addon:RegisterCondition("SPELL_REMAIN", {
    description = L["Spell Recharge Time"],
    icon = addon.Artwork.condition["SPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the SPELL_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a spell ID, a known operator and a non-negative number of seconds.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the seconds until the next charge of the chosen spell returns with the configured number; full charges
    -- and an inactive recharge timer count as zero.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the charge record cannot be read (including "no charges").
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
    -- Builds the readable rule summary for the SPELL_REMAIN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["recharge time on %s"], Functions.presentation.nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Builds the editor controls for the SPELL_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SPELL_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Recharge Time"], L["Seconds"],
            L["Seconds until the next spell charge. Full charges and inactive recharge timers report zero. Missing, restricted, or non-charge spell data stays unavailable."])
    end,
})

-- SPELL_CHARGES: compares the number of charges currently available on a spell with `value`. Returns `nil, reason`
-- for a spell without charges or unreadable charge data. Stores `spell`, `ranked`, `operator` and `value`.
addon:RegisterCondition("SPELL_CHARGES", {
    description = L["Spell Charges"],
    icon = addon.Artwork.condition["SPELL_CHARGES"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the SPELL_CHARGES condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a spell ID, a known operator and a non-negative count.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Compares the number of charges currently available on the chosen spell with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the charge record cannot be read.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local charges, why = Functions.cache.getCached(cache, addon.Platform.GetSpellCharges, addon.Platform, spellid)
        if not charges then return nil, why end
        return Functions.values.compare(value.operator, charges.currentCharges, value.value)
    end,
    -- Builds the readable rule summary for the SPELL_CHARGES condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["number of charges on %s"], Functions.presentation.nullable(link, L["<spell>"])), Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the SPELL_CHARGES condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Charges"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SPELL_CHARGES condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Charges"], L["Charges"],
            "The number of charges of " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " currently active.")
    end,
})

-- ============================================================================
-- Cast history
-- ============================================================================

-- SPELL_HISTORY: true when the spell was cast `value` casts ago (compared with `operator`; 1 is your latest cast),
-- read from addon.spellHistory, which only keeps casts newer than the history-memory setting. Returns `nil,
-- "restricted-value"` when no readable cast matches but a cast whose spell was secret could have. Stores `spell`,
-- `ranked`, `operator` and `value`.
addon:RegisterCondition("SPELL_HISTORY", {
    description = L["Spell Cast History"],
    icon = addon.Artwork.condition["SPELL_HISTORY"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the SPELL_HISTORY condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a spell ID, a known operator and a non-negative cast count.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Decides whether the chosen spell was cast the configured number of casts ago (1 is your latest cast).
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve, or when the history holds an unreadable (secret) cast that could
    -- satisfy the comparison and no readable cast settles it.
    evaluate = function(value)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
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
    -- Builds the readable rule summary for the SPELL_HISTORY condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        local ago = addon.historyCastsAgo[value.operator]
        return string.format(L["%s {{!was|was not}} cast %s"], Functions.presentation.nullable(link, L["<spell>"]),
                        ago and string.format(ago, Functions.presentation.nullable(value.value))
                        or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s casts ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the SPELL_HISTORY condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SPELL_HISTORY condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cast History"], L["Count"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Spell"] ..
            color.RESET .. " (by count).  A value of 1 means your last spell cast, 2 means two spells ago, etc.  " ..
            "Each instance of the same spell cast is treated separately.  Any spell cast more than the setting " ..
            "of " .. color.BLUE .. L["Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation " ..
            "Master configuration screen ago will not be available.")
    end,
})

-- SPELL_HISTORY_TIME: true when the spell was cast `value` seconds ago (compared with `operator`), measured from this
-- poll's `evalStart` to the recorded cast time in addon.spellHistory. Returns `nil, reason` for unreadable or
-- non-finite times and for a secret cast that could match. Stores `spell`, `ranked`, `operator` and `value`.
addon:RegisterCondition("SPELL_HISTORY_TIME", {
    description = L["Spell Cast History Time"],
    icon = addon.Artwork.condition["SPELL_HISTORY_TIME"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    -- Checks that the saved fields of the SPELL_HISTORY_TIME condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a spell ID, a known operator and a non-negative number of seconds.
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    -- Decides whether the chosen spell was cast a number of seconds ago that passes the comparison.
    -- @param value table  The saved condition fields.
    -- @param _ any  Unused; the cast history is already in memory, so no cache is needed.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began; each cast's age is measured
    --     against it.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable ("restricted-value", "history-time-unavailable") when the poll time or a recorded time is secret or
    -- not a finite number, or when a secret cast could match. (The note at the end of the line below does not describe
    -- this condition; nothing here computes a cooldown.)
    evaluate = function(value, _, evalStart) -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
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
    -- Builds the readable rule summary for the SPELL_HISTORY_TIME condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        local ago = addon.historySecondsAgo[value.operator]
        return string.format(L["%s {{!was|was not}} cast %s"], Functions.presentation.nullable(link, L["<spell>"]),
                ago and string.format(ago, Functions.presentation.nullable(value.value))
                or Functions.presentation.nullable(nil, L["<operator>"]) .. " " .. string.format(L["%s seconds ago"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the SPELL_HISTORY_TIME condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the SPELL_HISTORY_TIME condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cast History Time"], L["Seconds"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Spell"] ..
            color.RESET .. " (by time).  Any spell cast more than the setting of " .. color.BLUE ..
            L["Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end,
})

-- ============================================================================
-- Current spell state
-- ============================================================================

-- SPELL_ACTIVE: true when the spell is your current spell, meaning queued for the next swing or currently active.
-- Returns `nil, reason` when the spell ID does not resolve or the client cannot answer. Stores `spell` and `ranked`.
-- Enrolled below as a volatile (not pure) observation, so it is never reused across polls.
addon:RegisterCondition("SPELL_ACTIVE", runtimeCondition('SPELL_ACTIVE', {
    description = L["Spell Active or Pending"],
    icon = addon.Artwork.condition["SPELL_ACTIVE"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the SPELL_ACTIVE condition are complete and in range.
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
    -- Decides whether the chosen spell is your current spell, meaning queued for the next swing or currently active.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the Platform cannot read the current-spell state.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        return Functions.cache.getCached(cache, addon.Platform.IsCurrentSpell, addon.Platform, spellid)
    end,
    -- Builds the readable rule summary for the SPELL_ACTIVE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} active or pending"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the SPELL_ACTIVE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the SPELL_ACTIVE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end,
}))

-- SPELL_AUTOREPEAT: true while the spell is auto-repeating (Shoot, Auto Shot); a merely queued cast does not count.
-- Returns `nil, reason` when the spell ID does not resolve or the client cannot answer (the Platform answers only
-- under the probe and restricted policies). Stores `spell` and `ranked`. Enrolled below as a volatile observation.
addon:RegisterCondition("SPELL_AUTOREPEAT", runtimeCondition('SPELL_AUTOREPEAT', {
    description = L["Spell Auto-Repeat Active"],
    icon = addon.Artwork.condition["SPELL_AUTOREPEAT"],
    fields = { spell = "number", ranked = "boolean" },
    -- Checks that the saved fields of the SPELL_AUTOREPEAT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a positive integer spell ID and an absent or boolean `ranked`.
    valid = function(_, value)
        return addon.IsConditionSpellID(value.spell) and (value.ranked == nil or type(value.ranked) == "boolean")
    end,
    -- Decides whether the chosen spell is auto-repeating (Shoot, Auto Shot); a merely queued cast does not count.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the spell ID does not resolve or the auto-repeat state is unreadable.
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        return Functions.cache.getCached(cache, addon.Platform.IsAutoRepeatActive, addon.Platform, spellid)
    end,
    -- Builds the readable rule summary for the SPELL_AUTOREPEAT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} auto-repeating"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- Builds the editor controls for the SPELL_AUTOREPEAT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    -- Builds the help page for the SPELL_AUTOREPEAT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Tests whether the selected spell is currently auto-repeating, such as Shoot or Auto Shot. This is different from a spell being current or queued: a queued cast alone does not satisfy this condition. Unavailable client observations remain unavailable even when negated."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellwidget_help(frame)
    end,
}))

-- Source-owned volatile observations; only configuration-only validators memoize.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/spell.lua', {
        SPELL_ACTIVE = { pure = false },
        SPELL_AUTOREPEAT = { pure = false },
    })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/spell.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/spell.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
