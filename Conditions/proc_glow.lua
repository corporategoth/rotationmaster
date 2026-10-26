local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- SPELL_GLOW: whether a spell is showing the game's activation (proc) glow,
-- the golden border an action button gets when a proc makes the spell
-- castable or stronger. C_SpellActivationOverlay.IsSpellOverlayed takes a
-- plain spell ID, returns a plain boolean and carries no secret annotation, so
-- this reads on Retail and Forever in combat, where an aura read for the same
-- proc may be secret. The game asks about the spell ID the button shows, which
-- can be an override of the spell you chose, so the spell and its base and
-- override relatives are each asked. Where the game never glows the spell the
-- answer is simply false.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    presentation={nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/proc_glow.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

addon:RegisterCondition("SPELL_GLOW", {
    description = L["Spell Proc Glow"],
    icon = addon.Artwork.condition["SPELL_GLOW"],
    requiredFields = { "spell" },
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        return value.spell ~= nil and addon.IsConditionSpellID(value.spell)
            and (value.ranked == nil or type(value.ranked) == "boolean")
    end,
    evaluate = function(value, cache)
        local spellid, why = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, why or "spell-data-unavailable" end
        local related = addon.GetSpellIdRelatives and addon:GetSpellIdRelatives(spellid) or {}
        if #related == 0 then related = { spellid } end
        local reason
        for _, id in ipairs(related) do
            local glowing, problem = Functions.cache.getCached(cache, addon.Platform.IsSpellGlowing, addon.Platform, id)
            if glowing then return true end
            if glowing == nil then reason = reason or problem end
        end
        -- One relative that could not be read leaves "not glowing" unproven.
        if reason then return nil, reason end
        return false
    end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} glowing with a proc"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return addon.isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.SPELL_GLOW"]))
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
        addon:RegisterBuiltinSourceModule("Conditions/proc_glow.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/proc_glow.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
