-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition MACRO_CONDITION: true when macro conditionals hold, as the game evaluates them
-- (Platform/macro_conditions.lua), for example "[combat,harm]", "[stance:2]", "[mod:shift]" or "[@focus,exists,nodead]".
-- Several groups are OR'd, as in a macro. The game answers in combat on every client, Retail and Forever included.
-- Stores one field, value (the conditionals). Loaded from the TOC after Conditions/unit_rank.lua. Callback bodies are
-- recorded by tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Borrow related artwork until a dedicated icon is available.
addon.Artwork.condition['MACRO_CONDITION'] = addon.Artwork.condition['MACRO_CONDITION']
    or addon.Artwork.condition['COMBAT']

-- Canonical helper leaves these callbacks call; the table below names the Built In helper behind each one.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/macro_conditions.lua'] = {
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
}

-- MACRO_CONDITION: true when the macro conditionals hold. Stores one field, value.
addon:RegisterCondition('MACRO_CONDITION', {
    description = L['Macro Condition'],
    icon = addon.Artwork.condition['MACRO_CONDITION'],
    fields = { value = 'string' },
    requiredFields = { 'value' },
    -- Checks that the saved text is only macro conditionals.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when value.value is one or more bracketed conditional groups and nothing else.
    valid = function(_, value)
        return addon.Platform:IsMacroConditionText(value.value)
    end,
    -- Asks the game whether the conditionals hold.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        return Functions.cache.getCached(
            cache,
            addon.Platform.GetMacroConditionObservation,
            addon.Platform,
            value.value
        )
    end,
    -- Builds the readable rule summary for the MACRO_CONDITION condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return addon.Functions.presentation.phrase(L['the macro conditions {conditions} {{!hold|do not hold}}'], {
            conditions = type(value.value) == 'string' and value.value or L['<conditions>'],
        })
    end,
    -- Builds the text box for the conditionals; text that is not only conditionals is not stored.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the box edits value in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')
        local box = addon:CreateConditionEditBox()
        box:SetLabel(L['Macro conditions'])

        box:SetCallback('OnEnterPressed', function(_, _, v)
            if addon.Platform:IsMacroConditionText(v) then
                value.value = v
            end

            top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), spec))
        end)

        if value.value ~= nil then
            box:SetText(value.value)
        end

        parent:AddChild(box)
    end,
    -- Builds the help page for the MACRO_CONDITION condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(
            L['Matches when the macro conditions hold, exactly as they would in a macro: for example [combat,harm], [stance:2], [mod:shift] or [@focus,exists,nodead]. Several bracketed groups match when any of them does. The game evaluates them itself, so this works in combat on every client. Only the bracketed conditions are accepted, never a command.']
        ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/macro_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/macro_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
