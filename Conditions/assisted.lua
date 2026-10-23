local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Blizzard's Assisted Combat suggestion (Platform/assisted_combat.lua). The
-- one observation is cached per evaluation. A missing API, an unreadable
-- value or Assisted Combat being unavailable for this character is
-- unavailable, including under NOT; "nothing suggested" is a real false.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    presentation={nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/assisted.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

-- No original artwork yet: this placeholder reuses the Spell Available icon
-- until a semantic Assisted Combat icon is generated (tests/condition_icons.lua
-- lists it as pending). A generated catalog entry takes precedence.
if addon.Artwork and addon.Artwork.condition and addon.Artwork.condition["ASSISTED_SUGGESTION"] == nil then
    addon.Artwork.condition["ASSISTED_SUGGESTION"] = addon.Artwork.condition["SPELL_AVAIL"]
end

addon:RegisterCondition("ASSISTED_SUGGESTION", {
    description = L["Assisted Combat Suggestion"],
    icon = addon.Artwork.condition["ASSISTED_SUGGESTION"],
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        return (value.spell == nil or addon.IsConditionSpellID(value.spell))
            and (value.ranked == nil or type(value.ranked) == "boolean")
    end,
    evaluate = function(value, cache)
        local suggestion, reason = Functions.cache.getCached(cache, addon.Platform.GetAssistedSuggestion, addon.Platform)
        if suggestion == nil then return nil, reason or "assisted-unavailable" end
        if value.spell == nil then return suggestion ~= false end
        if suggestion == false then return false end
        local spellid, why = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, why or "spell-data-unavailable" end
        return addon.Platform:IsAssistedSpellMatch(spellid, suggestion)
    end,
    print = function(_, value)
        if value.spell == nil then
            return L["Assisted Combat {{!is|is not}} suggesting a spell"]
        end
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["Assisted Combat {{!suggests|does not suggest}} %s"], Functions.presentation.nullable(link, L["<spell>"]))
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
        frame:AddChild(helpers.CreateText(L["Matches when Blizzard's Assisted Combat suggests this spell as the next cast. An override counts as its base spell, and the base spell as its override. With no spell chosen, matches whenever Assisted Combat suggests anything."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Assisted Combat exists on Retail (and is declared on Forever). Where the game does not offer it, for this character or specialization, or the suggestion cannot be read, this condition is unavailable rather than false, including under NOT."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellwidget_help(frame)
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/assisted.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/assisted.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
