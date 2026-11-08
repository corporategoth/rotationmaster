-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions ENEMIES_TARGETING (how many enemies on nameplates are targeting you) and RECENT_KILL (you or your
-- group killed something within the last N seconds). They read addon.Platform:GetEnemiesTargetingPlayer and
-- GetLastKillTime (Platform/combat_events.lua), which stay readable without the combat log; the count is unavailable
-- where the game hides target comparisons (dungeons and raids on Retail and Forever). Loaded from RotationMaster.toc
-- after Conditions/unit_rank.lua. Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind
-- to their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Borrow related artwork until dedicated icons are available.
addon.Artwork.condition['ENEMIES_TARGETING'] = addon.Artwork.condition['ENEMIES_TARGETING']
    or addon.Artwork.condition['THREAT_COUNT']

addon.Artwork.condition['RECENT_KILL'] = addon.Artwork.condition['RECENT_KILL']
    or addon.Artwork.condition['COMBAT_HISTORY_TIME']

local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/combat_events.lua'] = {
    ['Functions.values.isin'] = 'builtin:utils.lua:isin',
    ['Functions.values.compare'] = 'builtin:utils.lua:compare',
    ['Functions.presentation.nullable'] = 'builtin:utils.lua:nullable',
    ['Functions.presentation.compareString'] = 'builtin:utils.lua:compareString',
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
}

-- ENEMIES_TARGETING: compares the number of hostile nameplates targeting you with `value` using `operator`.
addon:RegisterCondition('ENEMIES_TARGETING', {
    description = L['Enemies Targeting You'],
    icon = addon.Artwork.condition['ENEMIES_TARGETING'],
    fields = { operator = 'string', value = 'number' },
    -- Checks that the saved fields of the ENEMIES_TARGETING condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    valid = function(_, value)
        return value.operator ~= nil
            and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == 'number'
            and value.value >= 0
    end,
    -- Compares the number of enemies targeting you with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        local count, reason = Functions.cache.getCached(cache, addon.Platform.GetEnemiesTargetingPlayer, addon.Platform)

        if count == nil then
            return nil, reason
        end

        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Builds the readable rule summary for the ENEMIES_TARGETING condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary.
    print = function(_, value)
        return Functions.presentation.compareString(
            value.operator,
            L['Number of enemies with you as their target'],
            Functions.presentation.nullable(value.value)
        )
    end,
    -- Builds the editor controls: the count comparison.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')

        parent:AddChild(addon:Widget_OperatorWidget(value, L['Count'], function()
            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end))
    end,
    -- Builds the help page for the ENEMIES_TARGETING condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(
            L['Counts the enemies with a nameplate whose target is you, for example to switch to an area or defensive priority when several are on you. Nameplates must be shown. Retail and Forever hide target comparisons in dungeons and raids, where the count is unavailable.']
        ))
    end,
})

-- RECENT_KILL: true when you or your group killed something within the last `value` seconds.
addon:RegisterCondition('RECENT_KILL', {
    description = L['Recent Kill'],
    icon = addon.Artwork.condition['RECENT_KILL'],
    fields = { value = 'number' },
    -- Checks that the saved fields of the RECENT_KILL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    valid = function(_, value)
        return type(value.value) == 'number' and value.value > 0
    end,
    -- Decides whether the last kill by you or your group happened within the configured seconds.
    -- @param value table  The saved condition fields.
    -- @param _ any  Unused.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, _, evalStart)
        local last = addon.Platform:GetLastKillTime()

        if not last then
            return false
        end
        if type(evalStart) ~= 'number' then
            return nil, 'invalid-combat-time'
        end

        return evalStart - last <= value.value
    end,
    -- Builds the readable rule summary for the RECENT_KILL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return string.format(
            L['you or your group {{!killed|did not kill}} something in the last %s seconds'],
            Functions.presentation.nullable(value.value)
        )
    end,
    -- Builds the editor controls: the number of seconds.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')
        local seconds = addon:CreateConditionEditBox()
        seconds:SetLabel(L['Seconds'])

        if value.value ~= nil then
            seconds:SetText(tostring(value.value))
        end

        seconds:SetCallback('OnEnterPressed', function(_, _, v)
            value.value = tonumber(v)
            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end)

        parent:AddChild(seconds)
    end,
    -- Builds the help page for the RECENT_KILL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(
            L['Matches when you or a member of your group killed something within the chosen number of seconds, from the game\'s kill event, which still fires when the combat log is closed to addons. Useful for abilities that a kill makes available.']
        ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/combat_events.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/combat_events.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
