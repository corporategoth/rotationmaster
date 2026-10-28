-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions on Blizzard's Assisted Combat: ASSISTED_SUGGESTION (the spell it suggests next, or any spell),
-- ASSISTED_ROTATION_SPELL (a spell is in the specialization's Assisted Combat set) and ASSISTED_AVAILABLE (the game
-- offers it to this character). All read Platform observations from Platform/assisted_combat.lua through the per-poll
-- cache, so this file touches no game API; the feature exists on Retail (declared on Forever), and elsewhere or when an
-- answer cannot be read the conditions are unavailable (nil, reason), also under NOT. Core/condition_support.lua
-- declares the required API for each. Loaded from RotationMaster.toc after Conditions/anyspell.lua. Callback bodies and
-- the helpers they bind are hashed by saved copies and bundles: never add or change text inside a function body, and
-- leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Blizzard's Assisted Combat suggestion (Platform/assisted_combat.lua). The
-- one observation is cached per evaluation. A missing API, an unreadable
-- value or Assisted Combat being unavailable for this character is
-- unavailable, including under NOT; "nothing suggested" is a real false.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    presentation = { nullable = addon.Functions.presentation.nullable },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/assisted.lua"] = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
}

-- ============================================================================
-- Suggestion
-- ============================================================================

-- ASSISTED_SUGGESTION: true when Assisted Combat suggests the chosen spell as the next cast (an override and its base
-- spell count as the same); with no spell chosen, true whenever it suggests anything. Stores `spell` and `ranked`
-- (both optional). False when nothing is suggested; `nil, reason` when the suggestion or the spell ID cannot be read
-- ("assisted-unavailable", "spell-data-unavailable" or the Platform's reason).
addon:RegisterCondition("ASSISTED_SUGGESTION", {
    description = L["Assisted Combat Suggestion"],
    icon = addon.Artwork.condition["ASSISTED_SUGGESTION"],
    fields = { spell = "number", ranked = "boolean" },
    -- Valid with no spell, or with a valid spell ID and an optional boolean ranked flag.
    valid = function(_, value)
        return (value.spell == nil or addon.IsConditionSpellID(value.spell))
            and (value.ranked == nil or type(value.ranked) == "boolean")
    end,
    -- Unavailable when Assisted Combat cannot be read at all; "nothing suggested" (false from the Platform) is a real
    -- false, checked before the spell ID is resolved.
    evaluate = function(value, cache)
        local suggestion, reason = Functions.cache.getCached(cache, addon.Platform.GetAssistedSuggestion, addon.Platform)
        if suggestion == nil then return nil, reason or "assisted-unavailable" end
        if value.spell == nil then return suggestion ~= false end
        if suggestion == false then return false end
        local spellid, why = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, why or "spell-data-unavailable" end
        return addon.Platform:IsAssistedSpellMatch(spellid, suggestion)
    end,
    -- Readable summary; says "a spell" when none is chosen, otherwise names it with a link.
    print = function(_, value)
        if value.spell == nil then
            return L["Assisted Combat {{!is|is not}} suggesting a spell"]
        end
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["Assisted Combat {{!suggests|does not suggest}} %s"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- widget builds the spell picker (spells on the rotation's specialization); help draws the help page.
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
    end,
})

-- ============================================================================
-- Rotation set
-- ============================================================================

-- Whether a spell is in this specialization's Assisted Combat rotation set
-- (C_AssistedCombat.GetRotationSpells, refreshed on SPELLS_CHANGED as
-- Blizzard's own manager does). It answers "can Blizzard's suggestion ever
-- be this spell", so a rotation can highlight what Assisted Combat leaves
-- out. Unavailable when Assisted Combat is not offered for this character or
-- specialization, or the set cannot be read.
-- Stores `spell` and `ranked`; a spell is required.
addon:RegisterCondition("ASSISTED_ROTATION_SPELL", {
    description = L["Assisted Combat Rotation Spell"],
    icon = addon.Artwork.condition["ASSISTED_ROTATION_SPELL"],
    fields = { spell = "number", ranked = "boolean" },
    -- Valid with a valid spell ID and an optional boolean ranked flag.
    valid = function(_, value)
        return value.spell ~= nil and addon.IsConditionSpellID(value.spell)
            and (value.ranked == nil or type(value.ranked) == "boolean")
    end,
    -- Unavailable when the spell ID does not resolve or the Platform cannot read the rotation set.
    evaluate = function(value, cache)
        local spellid, why = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, why or "spell-data-unavailable" end
        return Functions.cache.getCached(cache, addon.Platform.IsAssistedRotationSpell, addon.Platform, spellid)
    end,
    -- Readable summary with the spell link.
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} in Blizzard's Assisted Combat rotation"], Functions.presentation.nullable(link, L["<spell>"]))
    end,
    -- widget builds the spell picker (spells on the rotation's specialization); help draws the help page.
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
        frame:AddChild(helpers.CreateText(L["Matches when this spell is one Blizzard's Assisted Combat can suggest for your current specialization. Its current override and its base spell count too. Use it to highlight what Assisted Combat leaves out, for example a cooldown that is not in the set."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["The set is read again whenever your spells change, never guessed. Where the game does not offer Assisted Combat for this character or specialization, or the set cannot be read, this condition is unavailable rather than false, including under NOT."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellwidget_help(frame)
    end,
})

-- ============================================================================
-- Availability
-- ============================================================================

-- Whether the game offers Assisted Combat to this character and
-- specialization right now (C_AssistedCombat.IsAvailable). Unlike the other
-- Assisted Combat conditions this is a real false when it is not offered, so
-- a rotation can fall back to its own steps. Unavailable only where the API
-- is missing or its answer cannot be read.
-- Stores no fields.
addon:RegisterCondition("ASSISTED_AVAILABLE", {
    description = L["Assisted Combat Available"],
    icon = addon.Artwork.condition["ASSISTED_AVAILABLE"],
    fields = {},
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Anything but a readable true counts as false; only an unreadable answer is unavailable
    -- (default reason "assisted-unavailable").
    evaluate = function(_, cache)
        local available, why = Functions.cache.getCached(cache, addon.Platform.GetAssistedCombatAvailability, addon.Platform)
        if available == nil then return nil, why or "assisted-unavailable" end
        return available == true
    end,
    -- Readable summary; there are no fields to mention.
    print = function()
        return L["Assisted Combat {{!is|is not}} available"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when the game offers Blizzard's Assisted Combat for your character and current specialization. When it does not (for example a specialization Blizzard has no Assisted Combat rotation for, or a client that declares the API but does not offer the feature), this is false, so a branch can fall back to your own steps."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Unavailable only where the client has no Assisted Combat API or its answer cannot be read, including under NOT."]))
    end,
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
