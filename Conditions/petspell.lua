local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Direct callback leaves use their owning modules; spell observation arguments,
-- rank resolution and book-bank selection keep their existing contracts.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/petspell.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

addon:RegisterCondition("PETSPELL_AVAIL", {
    description = L["Pet Spell Available"],
    icon = addon.Artwork.condition["PETSPELL_AVAIL"],
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        return Functions.cache.getCached(cache, addon.Platform.IsSpellReady, addon.Platform, spellid, evalStart)
    end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} available"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
})

addon:RegisterCondition("PETSPELL_RANGE", {
    description = L["Pet Spell In Range"],
    icon = addon.Artwork.condition["PETSPELL_RANGE"],
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} in range"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
})

addon:RegisterCondition("PETSPELL_COOLDOWN", {
    description = L["Pet Spell Cooldown"],
    icon = addon.Artwork.condition["PETSPELL_COOLDOWN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
                Functions.presentation.compareString(value.operator, string.format(L["cooldown on %s"],  Functions.presentation.nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cooldown"], L["Seconds"],
            "The number of seconds before you can cast " .. color.BLIZ_YELLOW .. L["Pet Spell"] .. color.RESET .. ".")
    end
})

addon:RegisterCondition("PETSPELL_REMAIN", {
    description = L["Pet Spell Recharge Time"],
    icon = addon.Artwork.condition["PETSPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["recharge time on %s"], Functions.presentation.nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Recharge Time"], L["Seconds"],
            L["Seconds until the next spell charge. Full charges and inactive recharge timers report zero. Missing, restricted, or non-charge spell data stays unavailable."])
    end
})

addon:RegisterCondition("PETSPELL_CHARGES", {
    description = L["Pet Spell Charges"],
    icon = addon.Artwork.condition["PETSPELL_CHARGES"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["the %s"],
            Functions.presentation.compareString(value.operator, string.format(L["number of charges on %s"], Functions.presentation.nullable(link, L["<spell>"])), Functions.presentation.nullable(value.value)))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Charges"], L["Charges"],
            "The number of charges of " .. color.BLIZ_YELLOW .. L["Pet Spell"] .. color.RESET .. " currently active.")
    end
})

addon:RegisterCondition("PETSPELL_HISTORY", {
    description = L["Pet Spell Cast History"],
    icon = addon.Artwork.condition["PETSPELL_HISTORY"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return Functions.presentation.compareString(value.operator, string.format(L["%s was cast"], Functions.presentation.nullable(link, L["<spell>"])),
                        string.format(L["%s casts ago"], Functions.presentation.nullable(value.value)))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cast History"], L["Count"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Pet Spell"] ..
            color.RESET .. " (by count).  A value of 1 means your last spell cast, 2 means two spells ago, etc.  " ..
            "Each instance of the same spell cast is treated separately.  Any spell cast more than the setting " ..
            "of " .. color.BLUE .. L["Pet Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation " ..
            "Master configuration screen ago will not be available.")
    end
})

addon:RegisterCondition("PETSPELL_HISTORY_TIME", {
    description = L["Pet Spell Cast History Time"],
    icon = addon.Artwork.condition["PETSPELL_HISTORY_TIME"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    validSpell and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
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
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return Functions.presentation.compareString(value.operator, string.format(L["%s was cast"], Functions.presentation.nullable(link, L["<spell>"])),
                string.format(L["%s seconds ago"], Functions.presentation.nullable(value.value)))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Pet Spell Cast History Time"], L["Seconds"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Pet Spell"] ..
            color.RESET .. " (by time).  Any spell cast more than the setting of " .. color.BLUE ..
            L["Pet Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

addon:RegisterCondition("PETSPELL_ACTIVE", {
    description = L["Pet Spell Active or Pending"],
    icon = addon.Artwork.condition["PETSPELL_ACTIVE"],
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        if value.spell ~= nil then
            local validSpell = addon.IsConditionSpellID(value.spell)
            return validSpell
        else
            return false
        end
    end,
    evaluate = function(value, cache)
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        return Functions.cache.getCached(cache, addon.Platform.IsCurrentSpell, addon.Platform, spellid)
    end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, false)
        return string.format(L["%s {{!is|is not}} active or pending"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
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
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
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
