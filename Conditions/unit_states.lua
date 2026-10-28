-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions DEAD (unit is dead or a ghost) and FRIENDLY (unit is friendly to the player). Both read one
-- Boolean through addon.Platform:GetUnitStateObservation (Platform/unit_states.lua), which applies
-- platform:CanReadValue, so on Retail and Forever a secret or missing value makes the condition unavailable instead of
-- false. They share one `valid` and one `widget`, defined below, because they store the same single field, unit.
-- Loaded from RotationMaster.toc after Conditions/combat.lua and before Conditions/casting.lua.
-- Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Canonical helper leaves these callbacks call; the table below names the Built In helper behind each one.
local Functions = {
    values = { isin = addon.Functions.values.isin },
    cache = { getCached = addon.Functions.cache.getCached },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/unit_states.lua'] = {
    ['Functions.values.isin'] = 'builtin:utils.lua:isin',
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
}

-- Shared configuration check: the saved unit must be one of the selectable unit tokens.
local function valid(_, value) return value.unit~=nil and Functions.values.isin(addon.units,value.unit) end

-- Shared editor control: the unit selector, which refreshes the status line on change.
local function widget(parent, spec, value)
    local top=parent:GetUserData('top')
    parent:AddChild(addon:Widget_UnitWidget(value,addon.units,function()
        top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec))
    end))
end

-- DEAD: true when the unit is dead or a ghost (UnitIsDeadOrGhost), false when it is alive. A unit that does not exist
-- is unavailable (nil and "unit-data-unavailable"), not false, so NOT never turns a missing unit into a match. Other
-- unreadable cases return nil and the observation's reason. Stores one field, unit.
addon:RegisterCondition('DEAD', {
    description = L['Is Dead or Ghost'],
    icon = addon.Artwork.condition['DEAD'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = valid,
    -- Reads the "dead" state once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'dead')
    end,
    -- Rule summary; the verb agrees with the player ("are") or another unit ("is").
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are dead or a ghost|are alive}}'] or L['{unit} {{!is dead or a ghost|is alive}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    -- Help page: the unit selector, then what counts as dead and the Via Macro announcement note.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Matches when the selected unit is dead or a ghost. A missing or unreadable unit is unavailable, including under NOT. In a Via Macro announcement, choose Announcement target to follow the supplied unit.']))
    end,
})

-- FRIENDLY: true when the game reports the unit as friendly to the player (UnitIsFriend), which does not imply party or
-- raid membership. A unit that does not exist is unavailable (nil and "unit-data-unavailable"), as for DEAD. Stores one
-- field, unit.
addon:RegisterCondition('FRIENDLY', {
    description = L['Is Friendly'],
    icon = addon.Artwork.condition['FRIENDLY'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = valid,
    -- Reads the "friendly" state once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'friendly')
    end,
    -- Rule summary; the wording differs for the player and for other units.
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are friendly|are not friendly}}'] or L['{unit} {{!is friendly to you|is not friendly to you}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    -- Help page: the unit selector, then what counts as friendly and when the result is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Matches when the game reports the selected unit as friendly to you. This does not imply party or raid membership. A missing or unreadable unit is unavailable.']))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/unit_states.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/unit_states.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
