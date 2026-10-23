local addon_name, addon = ...
local runtimeCondition=addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness('Conditions/channeling.lua') or function(_,definition)return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical callback leaves preserve the repaired observation contract and
-- the original filtered unit choices, wording and validation semantics.
local LiteralSummary={phrase=addon.Functions.presentation.phrase}
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
    cache={getCached=addon.Functions.cache.getCached},
    collections={deepcopy=addon.Functions.collections.deepcopy},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/channeling.lua"]={
    ["LiteralSummary.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
}

addon:RegisterCondition("CHANNELING", runtimeCondition('CHANNELING',{
    description = L["Channeling"],
    icon = addon.Artwork.condition["CHANNELING"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"channel")
        if not record then return nil,reason end
        if not record.active then return false end
        return true
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently channeling"], L["%s {{!is|is not}} currently channeling"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
}))

addon:RegisterCondition("CHANNELING_SPELL", {
    description = L["Specific Spell Channeling"],
    icon = addon.Artwork.condition["CHANNELING_SPELL"],
    fields = { unit = "string", spell = {"string", "number"}, ranked = "boolean" },
    valid = function(_, value)
        -- A name (saved before spell IDs) or a spell ID picked in the editor.
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                (type(value.spell) ~= "number" or (value.spell > 0 and value.spell < math.huge and value.spell % 1 == 0)))
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"channel")
        if not record then return nil,reason end
        if not record.active then return false end
        if type(value.spell) ~= "number" then return record.name==value.spell end
        -- By ID, any rank unless the exact rank was asked for (locale-safe).
        return addon.Platform:MatchSpellIdentity(record.spellID, record.spellReason, record.name, value.spell, value.ranked == true)
    end,
    print = function(_, value)
        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!are|are not}} currently channeling {spell}"], L["{unit} {{!is|is not}} currently channeling {spell}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            spell = Functions.presentation.nullable(type(value.spell) == "number" and addon:CastSpellLabel(value) or value.spell, L["<spell>"]),
        })
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end, true)
        parent:AddChild(spell_group)
        local rank = addon:Widget_SpellRankWidget(value, function() top:SetStatusText(funcs:print(root, spec)) end)
        if rank then parent:AddChild(rank) end
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_castspell_help(frame)
    end
})

addon:RegisterCondition("CHANNELING_REMAIN", {
    description = L["Channel Time Remaining"],
    icon = addon.Artwork.condition["CHANNELING_REMAIN"],
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"channel")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.remainingSeconds==nil then return nil,record.remainingReason end
        return Functions.values.compare(value.operator,record.remainingSeconds,value.value)
    end,
    print = function(_, value)
        return Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
            Functions.presentation.compareString(value.operator, L["time remaining on spell channel"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Cast Time Remaining"], L["Seconds"],
            "The number of seconds remaining in the current spell being channeled by " .. color.BLIZ_YELLOW ..
            L["Unit"] .. color.RESET .. ".  If the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is " ..
            "not currently channeling, this condition will not be successful (regardless of the " ..
            color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("CHANNEL_INTERRUPTABLE", {
    description = L["Channel Interruptable"],
    icon = addon.Artwork.condition["CHANNEL_INTERRUPTABLE"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"channel")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.interruptible==nil then return nil,record.interruptibleReason end
        return record.interruptible
    end,
    print = function(_, value)
        return string.format(L["%s's channeled spell {{!is|is not}} interruptable"], Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

-- Source-owned volatile observations; only configuration-only validators memoize.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/channeling.lua',{ CHANNELING={pure=true} })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/channeling.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/channeling.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
