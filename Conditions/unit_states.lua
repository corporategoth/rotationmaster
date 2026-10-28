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

-- Checks that the saved unit is one of the selectable unit tokens; shared by DEAD and FRIENDLY.
-- @param _ any  Unused; the current specialization the engine passes.
-- @param value table  The saved condition fields; reads unit.
-- @return boolean  True when value.unit is a key of addon.units.
local function valid(_, value) return value.unit~=nil and Functions.values.isin(addon.units,value.unit) end

-- Builds the unit selector, which refreshes the status line on change; shared by DEAD and FRIENDLY.
-- @param parent table  The editor group the selector is added to.
-- @param spec any  The specialization the condition is being edited for.
-- @param value table  The saved condition fields; the selector edits unit in place.
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
    -- Decides whether the unit is dead or a ghost; a unit that does not exist is unavailable, not false.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads the "dead" state once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'dead')
    end,
    -- Builds the readable rule summary for the DEAD condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary; the verb agrees with the player ("are") or another unit ("is").
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are dead or a ghost|are alive}}'] or L['{unit} {{!is dead or a ghost|is alive}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    -- Builds the help page for the DEAD condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
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
    -- Decides whether the game reports the unit as friendly to the player; a unit that does not exist is unavailable,
    -- not false.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads the "friendly" state once per poll through the evaluation cache.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'friendly')
    end,
    -- Builds the readable rule summary for the FRIENDLY condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary; the wording differs for the player and for other units.
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are friendly|are not friendly}}'] or L['{unit} {{!is friendly to you|is not friendly to you}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    -- Builds the help page for the FRIENDLY condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
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
