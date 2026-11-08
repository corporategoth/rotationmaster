-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition NEXT_SWING: compares the seconds until your next main-hand or off-hand swing, from the game's own
-- swing timer (addon.Platform:GetNextSwingObservation, Platform/swing_timer.lua: PLAYER_SWING carries each swing's
-- duration with haste included). It exists only where the client has that timer (Forever), and works in combat there,
-- where Weapon Swing Time Remaining is not available. Loaded from RotationMaster.toc after Conditions/combat_events.lua.
-- Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Borrow related artwork until a dedicated icon is available.
addon.Artwork.condition['NEXT_SWING'] = addon.Artwork.condition['NEXT_SWING']
    or addon.Artwork.condition['SWING_TIME_REMAIN']

local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/swing_timer.lua'] = {
    ['Functions.values.isin'] = 'builtin:utils.lua:isin',
    ['Functions.values.compare'] = 'builtin:utils.lua:compare',
    ['Functions.presentation.nullable'] = 'builtin:utils.lua:nullable',
    ['Functions.presentation.compareString'] = 'builtin:utils.lua:compareString',
}

-- NEXT_SWING: compares the seconds until the next swing of the chosen hand with `value` using `operator`.
addon:RegisterCondition('NEXT_SWING', {
    description = L['Time Until Next Swing'],
    icon = addon.Artwork.condition['NEXT_SWING'],
    fields = { offhand = 'boolean', operator = 'string', value = 'number' },
    -- Checks that the saved fields of the NEXT_SWING condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    valid = function(_, value)
        return value.operator ~= nil
            and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == 'number'
            and value.value >= 0
            and (value.offhand == nil or type(value.offhand) == 'boolean')
    end,
    -- Compares the seconds until the next swing with the configured number; 0 while no swing is under way.
    -- @param value table  The saved condition fields.
    -- @param _ any  Unused.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, _, evalStart)
        local left, reason = addon.Platform:GetNextSwingObservation(value.offhand, evalStart)

        if left == nil then
            return nil, reason
        end

        return Functions.values.compare(value.operator, left, value.value)
    end,
    -- Builds the readable rule summary for the NEXT_SWING condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary.
    print = function(_, value)
        return Functions.presentation.compareString(
            value.operator,
            value.offhand and L['Time until your next off-hand swing'] or L['Time until your next main-hand swing'],
            string.format(L['%s seconds'], Functions.presentation.nullable(value.value))
        )
    end,
    -- Builds the editor controls: the hand and the seconds comparison.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')

        local refresh = function()
            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end

        local hand = addon:CreateConditionCheckBox()
        hand:SetLabel(L['Off Hand'])
        hand:SetValue(value.offhand == true)

        hand:SetCallback('OnValueChanged', function(_, _, v)
            value.offhand = v == true or nil
            refresh()
        end)

        parent:AddChild(hand)
        parent:AddChild(addon:Widget_OperatorWidget(value, L['Seconds'], refresh))
    end,
    -- Builds the help page for the NEXT_SWING condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(
            L['Compares the seconds until your next melee swing with the chosen number, using the game\'s own swing timer, which includes haste and still reads in combat. While no swing is under way it reads 0. Only clients with that timer (Forever) offer it; elsewhere use Weapon Swing Time Remaining.']
        ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/swing_timer.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/swing_timer.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
