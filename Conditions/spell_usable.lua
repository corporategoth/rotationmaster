-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition SPELL_USABLE: what the game says about casting a spell right now, apart from its cooldown. With
-- check "usable" it is the game's own usable answer, which already includes resources, stance or form, and the
-- reactive requirements of spells such as Execute (target health), Overpower or Revenge; with check "affordable" it is
-- only whether you have the resources. Both come from addon.Platform:IsSpellUsable (Platform/actions.lua), which
-- applies platform:CanReadValue; C_Spell.IsSpellUsable carries no secret annotation, so this reads on Retail and Forever
-- in combat, where the target's health and your own power may be hidden. Loaded from RotationMaster.toc after
-- Conditions/proc_glow.lua. Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind to
-- their exact text.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Borrow related artwork until a dedicated icon is available.
addon.Artwork.condition['SPELL_USABLE'] = addon.Artwork.condition['SPELL_USABLE']
    or addon.Artwork.condition['SPELL_AVAIL']

local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    presentation = { nullable = addon.Functions.presentation.nullable },
}

-- Declares the stable Built In identity of each Functions leaf so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/spell_usable.lua'] = {
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
    ['Functions.presentation.nullable'] = 'builtin:utils.lua:nullable',
}

-- SPELL_USABLE: true when the game says the spell is usable now (check "usable", the default) or that you have the
-- resources for it (check "affordable"). Cooldowns are not part of either answer. Returns nil and a reason when the
-- spell cannot be resolved or the game's answer cannot be read. Stores spell, ranked and check.
addon:RegisterCondition('SPELL_USABLE', {
    description = L['Spell Usable'],
    icon = addon.Artwork.condition['SPELL_USABLE'],
    requiredFields = { 'spell' },
    fields = { spell = 'number', ranked = 'boolean', check = 'string' },
    -- Checks that the saved fields of the SPELL_USABLE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    valid = function(_, value)
        return value.spell ~= nil
            and addon.IsConditionSpellID(value.spell)
            and (value.ranked == nil or type(value.ranked) == 'boolean')
            and (value.check == nil or value.check == 'usable' or value.check == 'affordable')
    end,
    -- Decides whether the game says the spell is usable now, or that you can afford it.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    evaluate = function(value, cache)
        local spellid, why = addon:Widget_GetSpellId(value.spell, value.ranked)

        if not spellid then
            return nil, why or 'spell-data-unavailable'
        end

        local usable, power, reason = Functions.cache.getCached(
            cache,
            addon.Platform.IsSpellUsable,
            addon.Platform,
            spellid
        )

        if usable == nil then
            return nil, reason
        end
        if value.check == 'affordable' then
            return power == false
        end

        return usable == true
    end,
    -- Builds the readable rule summary for the SPELL_USABLE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        local link = Functions.presentation.nullable(addon:Widget_GetSpellLink(value.spell, value.ranked), L['<spell>'])

        if value.check == 'affordable' then
            return string.format(L['you {{!have|do not have}} the resources for %s'], link)
        end

        return string.format(L['%s {{!is|is not}} usable now'], link)
    end,
    -- Builds the editor controls: the spell picker and the usable or affordable choice.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData('top')
        local root = top:GetUserData('root')
        local funcs = top:GetUserData('funcs')

        local spell_group = addon:Widget_SpellWidget(
            spec,
            'Spec_EditBox',
            value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function()
                top:SetStatusText(funcs:print(root, spec))
            end
        )

        parent:AddChild(spell_group)

        local choices = { usable = L['Usable now'], affordable = L['Enough resources'] }
        local check = addon:CreateConditionDropdown()
        check:SetLabel(L['Check'])

        check:SetCallback('OnValueChanged', function(_, _, selected)
            value.check = selected
            top:SetStatusText(funcs:print(root, spec))
        end)

        check.configure = function()
            check:SetList(choices, { 'usable', 'affordable' })
            check:SetValue(value.check or 'usable')
        end

        parent:AddChild(check)
    end,
    -- Builds the help page for the SPELL_USABLE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(
            L['Usable now matches when the game says you can cast the spell now, apart from its cooldown: resources, stance or form, and a spell\'s own requirements, such as a target at low health or a recent dodge, are all part of the answer. Enough resources matches when only the cost is covered. Both still read in combat on clients that hide your power and your target\'s health from addons, so Usable now on a spell that needs a low-health target tells you whether the target is low enough.']
        ))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/spell_usable.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/spell_usable.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
