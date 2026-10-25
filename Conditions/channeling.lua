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
        if type(value.spell) ~= "number" then
            if record.name==nil then return nil,record.nameReason or "cast-spell-unavailable" end
            return record.name==value.spell
        end
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
        return Functions.presentation.compareString(value.operator,
            string.format(L["the time remaining on %s channel"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
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
        addon.layout_condition_operatorwidget_help(frame, L["Channel Time Remaining"], L["Seconds"],
            "The number of seconds remaining in the current spell being channeled by " .. color.BLIZ_YELLOW ..
            L["Unit"] .. color.RESET .. ".  If the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is " ..
            "not currently channeling, this condition will not be successful (regardless of the " ..
            color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

-- Share of the channel done (0..1, shown as a percentage), from the same cached
-- observation as CHANNELING_REMAIN: haste-proof, so a tick threshold is N/K.
if addon.Artwork and addon.Artwork.condition and addon.Artwork.condition["CHANNELING_PROGRESS"] == nil then
    addon.Artwork.condition["CHANNELING_PROGRESS"] = addon.Artwork.condition["CHANNELING_REMAIN"]
end
addon:RegisterCondition("CHANNELING_PROGRESS", {
    description = L["Channel Progress"],
    icon = addon.Artwork.condition["CHANNELING_PROGRESS"],
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and value.value <= 1)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"channel")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.remainingSeconds==nil then return nil,record.remainingReason end
        if record.durationSeconds==nil then return nil,record.durationReason end
        local done=1-record.remainingSeconds/record.durationSeconds
        if done<0 then done=0 end
        return Functions.values.compare(value.operator,done,value.value)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then v = v * 100 end
        return Functions.presentation.compareString(value.operator, string.format(L["%s channel progress"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Progress"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Channel Progress"], L["Progress"],
            (L["How much of the current channel of {unit} is done, from 0% when it starts to 100% when it ends. Ticks are evenly spaced through a channel, so tick N of a K-tick channel lands at N/K whatever your haste: to clip Mind Flay (3 ticks) after its second tick, use at least 66%. Pushback shortens a channel and the progress follows it. If the unit is not channeling, this condition is not successful, whatever the operator; if the channel's times cannot be read, it is unavailable, including under NOT."]:gsub("{unit}", color.BLIZ_YELLOW .. L["Unit"] .. color.RESET)))
    end
})

addon:RegisterCondition("CHANNEL_INTERRUPTABLE", {
    description = L["Channel Interruptible"],
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
        return string.format(L["%s channeled spell {{!is|is not}} interruptible"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]))
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

-- Cold, one-time seed for profiles created before the progress conditions
-- existed: add them to the Combat category once. Removing them later stays
-- saved; new and reset profiles get them from the packaged defaults.
local combatCategory="b3d7df2c-f257-4a2d-961e-66e49336d109"
function addon:InitializeCastProgressConditions(_, db)
    local profile = db and db.profile
    if type(profile) ~= "table" or profile.castProgressConditionsSeeded then return end
    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and category.id == combatCategory and type(category.conditions) == "table" then
            for _, tag in ipairs({"CASTING_PROGRESS", "CHANNELING_PROGRESS"}) do
                local found = false
                for _, existing in ipairs(category.conditions) do if existing == tag then found = true;break end end
                if not found then category.conditions[#category.conditions + 1] = tag end
            end
        end
    end
    profile.castProgressConditionsSeeded = true
end
local seedOwner = {}
function addon:InstallCastProgressConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then return end
    for _, event in ipairs({"OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied"}) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB) addon:InitializeCastProgressConditions(nil, currentDB) end)
    end
    self:InitializeCastProgressConditions(nil, db)
end

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
