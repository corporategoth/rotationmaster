-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions BOSS (the unit is a boss), ELITE (the unit is elite or better: Elite, Rare Elite or World Boss)
-- and CASTING_ANY (the unit is casting or channeling anything). BOSS and ELITE read
-- addon.Platform:GetUnitRankObservation (Platform/unit_rank.lua); CASTING_ANY reads the cast and channel records of
-- Platform:GetUnitCastObservation (Platform/casting.lua) without interpreting the spell, so a cast the game hides as a
-- secret still counts. All read on Retail and Forever. A unit that does not exist is false; an unreadable value is
-- unavailable (nil, reason), also under NOT. Loaded from RotationMaster.toc after Conditions/channeling.lua.
-- Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Borrow related artwork until dedicated icons are available.
addon.Artwork.condition['BOSS'] = addon.Artwork.condition['BOSS'] or addon.Artwork.condition['CLASSIFICATION']
addon.Artwork.condition['ELITE'] = addon.Artwork.condition['ELITE'] or addon.Artwork.condition['CLASSIFICATION']
addon.Artwork.condition['CASTING_ANY'] = addon.Artwork.condition['CASTING_ANY'] or addon.Artwork.condition['CASTING']

-- Canonical helper leaves these callbacks call; the table below names the Built In helper behind each one.
local Functions = {
    values = { isin = addon.Functions.values.isin },
    cache = { getCached = addon.Functions.cache.getCached },
    collections = { deepcopy = addon.Functions.collections.deepcopy },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/unit_rank.lua'] = {
    ['Functions.values.isin'] = 'builtin:utils.lua:isin',
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
    ['Functions.collections.deepcopy'] = 'builtin:Functions/collections.lua:deepcopy',
}

-- Checks that the saved unit is one of the selectable unit tokens; used by CASTING_ANY.
-- @param _ any  Unused; the current specialization the engine passes.
-- @param value table  The saved condition fields; reads unit.
-- @return boolean  True when value.unit is a key of addon.units.
local function valid(_, value)
    return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
end

-- Checks that the saved unit is a selectable unit other than you and your pet, who are never bosses or elites; shared
-- by BOSS and ELITE.
-- @param _ any  Unused; the current specialization the engine passes.
-- @param value table  The saved condition fields; reads unit.
-- @return boolean  True when value.unit is a key of addon.units other than player and pet.
local function validOther(_, value)
    return value.unit ~= nil and value.unit ~= 'player' and value.unit ~= 'pet' and Functions.values.isin(
        addon.units,
        value.unit
    )
end

-- Builds the unit selector without you and your pet (who are never bosses or elites); shared by BOSS and ELITE.
-- @param parent table  The editor group the selector is added to.
-- @param spec any  The specialization the condition is being edited for.
-- @param value table  The saved condition fields; the selector edits unit in place.
local function otherUnitWidget(parent, spec, value)
    local top = parent:GetUserData('top')

    parent:AddChild(addon:Widget_UnitWidget(
        value,
        Functions.collections.deepcopy(addon.units, { 'player', 'pet' }),
        function()
            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end
    ))
end

-- BOSS: true when the unit is a boss: the game marks it a boss mob (UnitIsBossMob, where the client has it), it is a
-- World Boss, or it is an elite of unknown (skull) level. Stores one field, unit.
addon:RegisterCondition('BOSS', {
    description = L['Is a Boss'],
    icon = addon.Artwork.condition['BOSS'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = validOther,
    -- Decides whether the unit is a boss; a unit that does not exist is false.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        local rank, reason = Functions.cache.getCached(
            cache,
            addon.Platform.GetUnitRankObservation,
            addon.Platform,
            value.unit
        )

        if rank == nil then
            return nil, reason
        end

        return rank ~= false and rank.boss == true
    end,
    -- Builds the readable rule summary for the BOSS condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return addon.Functions.presentation.phrase(
            value.unit == 'player' and L['{unit} {{!are a boss|are not a boss}}']
                or L['{unit} {{!is a boss|is not a boss}}'],
            {
                unit = addon.units[value.unit] or L['<unit>'],
            }
        )
    end,
    widget = otherUnitWidget,
    -- Builds the help page for the BOSS condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(addon.help_funcs.CreateText(
            L['Matches when the selected unit is a boss: the game marks it as a boss, it is a World Boss, or it is an elite whose level shows as a skull. For "a boss fight is in progress", use Boss Encounter.']
        ))
    end,
})

-- ELITE: true when the unit's classification is Elite, Rare Elite or World Boss. Stores one field, unit.
addon:RegisterCondition('ELITE', {
    description = L['Is Elite'],
    icon = addon.Artwork.condition['ELITE'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = validOther,
    -- Decides whether the unit is elite or better; a unit that does not exist is false.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        local rank, reason = Functions.cache.getCached(
            cache,
            addon.Platform.GetUnitRankObservation,
            addon.Platform,
            value.unit
        )

        if rank == nil then
            return nil, reason
        end

        return rank ~= false and rank.elite == true
    end,
    -- Builds the readable rule summary for the ELITE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return addon.Functions.presentation.phrase(
            value.unit == 'player' and L['{unit} {{!are elite|are not elite}}']
                or L['{unit} {{!is elite|is not elite}}'],
            {
                unit = addon.units[value.unit] or L['<unit>'],
            }
        )
    end,
    widget = otherUnitWidget,
    -- Builds the help page for the ELITE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(addon.help_funcs.CreateText(
            L['Matches when the selected unit is elite or better: Elite, Rare Elite or World Boss. Unit Classification matches one classification exactly.']
        ))
    end,
})

-- CASTING_ANY: true when the unit is casting or channeling any spell. Which spell does not matter, so a cast the game
-- hides still counts. Unavailable only when neither the cast nor the channel can be read and neither is active.
-- Stores one field, unit.
addon:RegisterCondition('CASTING_ANY', {
    description = L['Casting or Channeling'],
    icon = addon.Artwork.condition['CASTING_ANY'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = valid,
    -- Decides whether the unit is casting or channeling anything.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        local cast, castReason = Functions.cache.getCached(
            cache,
            addon.Platform.GetUnitCastObservation,
            addon.Platform,
            value.unit,
            'cast'
        )

        if cast and cast.active then
            return true
        end

        local channel, channelReason = Functions.cache.getCached(
            cache,
            addon.Platform.GetUnitCastObservation,
            addon.Platform,
            value.unit,
            'channel'
        )

        if channel and channel.active then
            return true
        end
        if not cast then
            return nil, castReason
        end
        if not channel then
            return nil, channelReason
        end

        return false
    end,
    -- Builds the readable rule summary for the CASTING_ANY condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return addon.Functions.presentation.phrase(
            value.unit == 'player' and L['{unit} {{!are casting or channeling|are not casting or channeling}}']
                or L['{unit} {{!is casting or channeling|is not casting or channeling}}'],
            { unit = addon.units[value.unit] or L['<unit>'] }
        )
    end,
    -- Builds the unit selector, which refreshes the status line on change.
    -- @param parent table  The editor group the selector is added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the selector edits unit in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')

        parent:AddChild(addon:Widget_UnitWidget(value, addon.units, function()
            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end))
    end,
    -- Builds the help page for the CASTING_ANY condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(addon.help_funcs.CreateText(
            L['Matches when the selected unit is casting or channeling any spell. It does not look at which spell, so it still works when the game hides the spell from addons.']
        ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/unit_rank.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/unit_rank.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
