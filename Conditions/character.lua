-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions about who a unit is: ISSAME, CLASS, CLASS_GROUP, ROLE, GLYPH, CREATURE, CLASSIFICATION, LEVEL and
-- GROUP, plus the MobInfo2-backed RUNNER, RESIST and IMMUNE, which exist only when the MobInfo2 addon is loaded.
-- Values come from addon.Platform observations (GetUnitIdentityObservation, GetUnitMetadataObservation,
-- GetInspectRoleObservation, GetGroupMembership, GetGlyphSocketSnapshot, GetMobInfo2Observation) and the Core helpers
-- addon:GetClassGroupCount, GetConditionUnitLevel and GetConditionCreatureTypeMatch; this file calls no game API
-- directly, so restricted-client reads stay behind platform:CanReadValue. ROLE and GLYPH are defined per edition (see
-- their comments). Loaded from RotationMaster.toc right after Conditions/common.lua and before Conditions/talent.lua.
-- Callback bodies and the helpers named in the generated block at the end are frozen Built In source: never edit
-- inside them.
local addon_name, addon = ...

-- Registers each definition with the runtime witness (Core/condition_runtime.lua) when it exists, so the enrollment at
-- the bottom of the file can prove LEVEL was not replaced; otherwise it passes the definition through.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/character.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Set at load only on clients that have glyphs (see GLYPH); the player's numeric class ID used to validate glyph items.
local unit_class_num

-- Snapshot only the explicit pure/cache leaves used by these callbacks.
-- Native observations, source variants and captured class values stay intact.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
        playerize = addon.Functions.presentation.playerize,
    },
    cache = { getCached = addon.Functions.cache.getCached },
    collections = { deepcopy = addon.Functions.collections.deepcopy, keys = addon.Functions.collections.keys },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/character.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
}

-- ============================================================================
-- Identity and class
-- ============================================================================

-- ISSAME: true when two unit tokens name the same unit (for example target and focus). Returns the Platform's identity
-- observation unchanged, so `nil, reason` when either unit is missing or its identity is unreadable. Stores `unit`
-- and `otherunit`. The editor's first unit list leaves out player and pet; the second offers every unit.
addon:RegisterCondition("ISSAME", {
    description = L["Is Same As"],
    icon = addon.Artwork.condition["ISSAME"],
    fields = { unit = "string", otherunit = "string" },
    -- Both tokens must be known units.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.otherunit ~= nil and Functions.values.isin(addon.units, value.otherunit))
    end,
    -- Unavailable (`nil, reason`) when the identity observation cannot be made this poll.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitIdentityObservation, addon.Platform, value.unit, value.otherunit)
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} %s"], L["%s {{!is|is not}} %s"]), Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.units[value.otherunit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local otherunit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end, "otherunit")
        parent:AddChild(otherunit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
})

-- CLASS: true when the unit's class is the chosen class token (for example "WARRIOR"). False when the unit does not
-- exist; `nil, reason` when its class cannot be read (restricted or not yet known). Stores `unit` and `value`.
addon:RegisterCondition("CLASS", {
    description = L["Class"],
    icon = addon.Artwork.condition["CLASS"],
    fields = { unit = "string", value = "string" },
    -- A known unit and a class token the client has a name for.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(LOCALIZED_CLASS_NAMES_MALE, value.value))
    end,
    -- Unavailable when the metadata observation is nil; a missing unit (observation false) is false.
    evaluate = function(value, cache)
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "class")
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed == value.value
    end,
    print = function(_, value)
        return string.format(L["%s class {{!is|is not}} %s"],
            Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(LOCALIZED_CLASS_NAMES_MALE[value.value], L["<class>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Class"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(LOCALIZED_CLASS_NAMES_MALE, CLASS_SORT_ORDER)
            if (value.value ~= nil) then
                class:SetValue(value.value)
            end
        end
        parent:AddChild(class)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Class"] .. color.RESET .. " - " ..
            "The character class of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
    end,
})

-- The player's class token, captured at load. Nothing in this file reads it; it is listed in the generated block at
-- the end so saved source that names it still resolves.
local character_class = select(2, UnitClass("player"))

-- CLASS_GROUP: compares how many party (or raid, with `raid`) members have the chosen class with `value` using
-- `operator`; the player counts as a member. Returns `nil, reason` when any needed roster slot is unreadable.
-- Stores `class`, `operator`, `value` and `raid`.
addon:RegisterCondition("CLASS_GROUP", {
    description = L["Class In Group"],
    icon = addon.Artwork.condition["CLASS_GROUP"],
    fields = { class = "string", operator = "string", value = "number", raid = "boolean" },
    -- A class token, a known operator and a non-negative count.
    valid = function(_, value)
        return (value.class ~= nil and Functions.values.isin(LOCALIZED_CLASS_NAMES_MALE, value.class) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Unavailable when addon:GetClassGroupCount cannot complete the roster count.
    evaluate = function(value, cache)
        local count,reason=addon:GetClassGroupCount(cache,value.class,value.raid)
        if count==nil then return nil,reason end
        return Functions.values.compare(value.operator,count,value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["Number of %ss in the %s"],
                Functions.presentation.nullable(LOCALIZED_CLASS_NAMES_MALE[value.class], L["<class>"]),
                (value.raid and RAID or PARTY)), Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Class"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.class = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(LOCALIZED_CLASS_NAMES_MALE, CLASS_SORT_ORDER)
            if (value.class ~= nil) then
                class:SetValue(value.class)
            end
        end
        parent:AddChild(class)

        local raid = addon:CreateConditionCheckBox()
        raid:SetWidth(100)
        raid:SetLabel(L["Raid"])
        raid:SetValue(value.raid and true or false)
        raid:SetCallback("OnValueChanged", function(_, _, v)
            value.raid = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(raid)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Class"] .. color.RESET .. " - " ..
                "The character class we are interested in."))

        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Raid"] .. color.RESET ..
                " - " .. "Check the entire raid, or just our party."))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Count"], L["Count"],
                "Number of party or raid members of the desired class.")
    end,
})

-- ============================================================================
-- Role and glyphs
-- ============================================================================

-- ROLE comes in two editions of the same tag; only one is registered per client. Retail checks any unit's assigned
-- group role; Wrath and later Classic clients check only your own active talent group's role; Classic Era (expansion
-- level below 2) has no ROLE condition at all.
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    -- ROLE (Retail): true when the unit's assigned role is the chosen one (tank, healer or damage). False when the unit
    -- has no role; `nil, reason` when the role cannot be read. Stores `unit` and `value`.
    addon:RegisterCondition("ROLE", {
        -- Selects the recorded "inspect" source variant in the Built In source catalog.
        builtinSourceVariant = "inspect",
        description = L["Role"],
        icon = addon.Artwork.condition["ROLE"],
        fields = { unit = "string", value = "string" },
        -- A known unit and a known role.
        valid = function(_, value)
            return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                    value.value ~= nil and Functions.values.isin(addon.roles, value.value))
        end,
        -- Unavailable when the inspect role observation is nil; a unit with no role (observation false) is false.
        evaluate = function(value, cache)
            local role,reason=Functions.cache.getCached(cache, addon.Platform.GetInspectRoleObservation, addon.Platform, value.unit)
            if role==nil then return nil,reason end
            if role==false then return false end
            return role == value.value
        end,
        print = function(_, value)
            return string.format(L["%s role {{!is|is not}} %s"],
                Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]),
                Functions.presentation.nullable(addon.roles[value.value], L["<role>"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(unit)

            local role = addon:CreateConditionDropdown()
            role:SetLabel(L["Role"])
            role:SetCallback("OnValueChanged", function(_, _, v)
                value.value = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            role.configure = function()
                role:SetList(addon.roles, Functions.collections.keys(addon.roles))
                if (value.value ~= nil) then
                    role:SetValue(value.value)
                end
            end
            parent:AddChild(role)
        end,
        help = function(frame)
            addon.layout_condition_unitwidget_help(frame)

            frame:AddChild(helpers.Gap())
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Role"] .. color.RESET .. " - " ..
                "The current role of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Tank"] .. color.RESET .. " - " ..
                "Designed to keep the attention and take most of the hits from enemies.  aka. Meat Shields.")))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["DPS"] .. color.RESET .. " - " ..
                "The primary damage dealers against enemies, and lovers of standing in fire.")))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Healer"] .. color.RESET .. " - " ..
                "Those who keep everyone else alive by healing them.  Thank them!")))
        end,
    })
else
    if LE_EXPANSION_LEVEL_CURRENT >= 2 then
        -- ROLE (Wrath and later Classic): true when the role of your active talent group is the chosen one. Returns
        -- `nil, reason` when the talent group's role cannot be read. Stores `value` only; it is always about you.
        addon:RegisterCondition("ROLE", {
            -- Selects the recorded "talent" source variant in the Built In source catalog.
            builtinSourceVariant = "talent",
            description = L["Role"],
            icon = addon.Artwork.condition["ROLE"],
            fields = { value = "string" },
            -- A known role.
            valid = function(_, value)
                return value.value ~= nil and Functions.values.isin(addon.roles, value.value)
            end,
            -- Unavailable when the talent group role observation is nil; addon.currentSpec picks the group.
            evaluate = function(value, cache)
                local role,reason=Functions.cache.getCached(cache, addon.Platform.GetTalentGroupRoleObservation, addon.Platform, addon.currentSpec)
                if role==nil then return nil,reason end
                return role == value.value
            end,
            print = function(_, value)
                return string.format(L["%s role {{!is|is not}} %s"], addon.unitsPossessive.player,
                        Functions.presentation.nullable(addon.roles[value.value], L["<role>"]))
            end,
            widget = function(parent, spec, value)
                local top = parent:GetUserData("top")
                local root = top:GetUserData("root")
                local funcs = top:GetUserData("funcs")

                local role = addon:CreateConditionDropdown()
                role:SetLabel(L["Role"])
                role:SetCallback("OnValueChanged", function(_, _, v)
                    value.value = v
                    top:SetStatusText(funcs:print(root, spec))
                end)
                role.configure = function()
                    role:SetList(addon.roles, Functions.collections.keys(addon.roles))
                    if (value.value ~= nil) then
                        role:SetValue(value.value)
                    end
                end
                parent:AddChild(role)
            end,
            help = function(frame)
                frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Role"] .. color.RESET .. " - " ..
                        "The role set for your active talent group."))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Tank"] .. color.RESET .. " - " ..
                        "Designed to keep the attention and take most of the hits from enemies.  aka. Meat Shields.")))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["DPS"] .. color.RESET .. " - " ..
                        "The primary damage dealers against enemies, and lovers of standing in fire.")))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Healer"] .. color.RESET .. " - " ..
                        "Those who keep everyone else alive by healing them.  Thank them!")))
            end,
        })
    end
end

-- Glyphs exist on Retail and from Wrath on. Core/condition_support.lua additionally marks the condition unsupported on
-- clients whose glyph layout the Platform does not handle (Mists).
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or LE_EXPANSION_LEVEL_CURRENT >= 2) then
    unit_class_num = select(3, UnitClass("player"))

    -- GLYPH: true when the chosen glyph item is active in one of your glyph sockets, matched by the glyph's spell
    -- name. False when every socket is read and none matches; `nil, reason` when the item, its display info, a socket's
    -- spell or the socket list cannot be read. Stores `item` (a glyph item ID of your class).
    addon:RegisterCondition("GLYPH", {
        description = L["Glyph"],
        icon = addon.Artwork.condition["GLYPH"],
        fields = { item = "number" },
        -- The item must be a glyph of your own class.
        valid = function(_, value)
            if value.item ~= nil then
                return addon.Platform:GetGlyphItemInfo(value.item, unit_class_num) ~= nil
            else
                return false
            end
        end,
        -- Unavailable on any unreadable step; an incomplete socket snapshot never yields false.
        evaluate = function(value, cache)
            local item, itemReason = Functions.cache.getCached(cache, addon.Platform.GetGlyphItemInfo, addon.Platform, value.item, unit_class_num)
            if not item then return nil, itemReason end
            local info, infoReason = Functions.cache.getCached(cache, addon.Platform.GetItemDisplayInfo, addon.Platform, item.itemID)
            if not info then return nil, infoReason end
            local snapshot, snapshotReason = Functions.cache.getCached(cache, addon.Platform.GetGlyphSocketSnapshot, addon.Platform)
            if not snapshot then return nil, snapshotReason end
            local unavailable
            for _, slot in ipairs(snapshot.slots) do
                if slot.active then
                    local spell, spellReason = Functions.cache.getCached(cache, addon.Platform.GetSpellInfo, addon.Platform, slot.spellID)
                    if spell then
                        if spell.name == info.name then return true end
                    else
                        unavailable = unavailable or spellReason or "spell-data-unavailable"
                    end
                elseif slot.active == nil then
                    unavailable = unavailable or slot.reason or "glyph-socket-unavailable"
                end
            end
            if unavailable then return nil, unavailable end
            if not snapshot.complete then return nil, "glyph-socket-unavailable" end
            return false
        end,
        print = function(_, value)
            local info = value.item and addon.Platform:GetItemDisplayInfo(value.item) or nil
            local link = info and info.link or nil
            return string.format(L["you {{!have|do not have}} %s active"], Functions.presentation.nullable(link, L["<glyph>"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local item_group = addon:Widget_SingleItemWidget(spec, "Glyph_EditBox", value,
                    function(v)
                        return addon.Platform:GetGlyphItemInfo(v, unit_class_num) ~= nil
                    end,
                    function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(item_group)
        end,
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " - " ..
                "The glyph, entered as its item ID or item name; the icon beside the field shows the glyph " ..
                "selected.  Only glyphs of your class are accepted.  The condition matches while that glyph " ..
                "is active in one of your glyph sockets."))
        end,
    })
end

-- ============================================================================
-- Creature type, classification and level
-- ============================================================================

-- CREATURE: true when the unit's creature type (Beast, Undead, ...) is the chosen one, decided by
-- addon:GetConditionCreatureTypeMatch, which owns the type-key map. Returns `nil, reason` when the type cannot be
-- read. Stores `unit` and `value`.
addon:RegisterCondition("CREATURE", {
    description = L["Creature Type"],
    icon = addon.Artwork.condition["CREATURE"],
    fields = { unit = "string", value = "string" },
    -- A known unit and a known creature type key.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(addon.creatures, value.value))
    end,
    -- Delegates to the Core helper; unavailable cases are its `nil, reason`.
    evaluate = function(value, cache)
        return addon:GetConditionCreatureTypeMatch(value.unit,value.value,cache)
    end,
    print = function(_, value)
        return string.format(L["%s creature type {{!is|is not}} %s"],
            Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.creatures[value.value], L["<creature type>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Creature Type"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(addon.creatures, Functions.collections.keys(addon.creatures))
            if (value.value ~= nil) then
                class:SetValue(value.value)
            end
        end
        parent:AddChild(class)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Creature Type"] .. color.RESET .. " - " ..
                "The creature type of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
                "can be used to create conditions that are restricted by creature type (eg. Banish)."))
    end,
})

-- CLASSIFICATION: true when the unit's classification (normal, elite, boss, ...) is the chosen one. False when the
-- unit does not exist; `nil, reason` when the classification cannot be read. Stores `unit` and `value`.
addon:RegisterCondition("CLASSIFICATION", {
    description = L["Unit Classification"],
    icon = addon.Artwork.condition["CLASSIFICATION"],
    fields = { unit = "string", value = "string" },
    -- A known unit and a known classification key.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(addon.classifications, value.value))
    end,
    -- Unavailable when the metadata observation is nil; a missing unit (observation false) is false.
    evaluate = function(value, cache)
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "classification")
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed == value.value
    end,
    print = function(_, value)
        return string.format(L["%s classification {{!is|is not}} %s"],
                Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.classifications[value.value], L["<classification>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Unit Classification"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(addon.classifications, Functions.collections.keys(addon.classifications))
            if (value.value ~= nil) then
                class:SetValue(value.value)
            end
        end
        parent:AddChild(class)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Unit Classification"] .. color.RESET .. " - " ..
                "The classification of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
                "can be used to create conditions that only apply to certain unit classifications (eg. bosses)."))
    end,
})

-- LEVEL: compares the unit's level with `value` using `operator`. With `relative`, `value` is an offset from your own
-- level (negative allowed). False when the unit does not exist; `nil, reason` when a level cannot be read, when
-- your own level is needed and unreadable ("player-level-unavailable"), or when the threshold is not finite
-- ("invalid-level-threshold"). Stores `unit`, `operator`, `value` and `relative`. Enrolled below as a pure condition
-- with the 'level' fact.
addon:RegisterCondition("LEVEL", runtimeCondition('LEVEL', {
    -- Unit, operator and value are all needed; a partly filled condition is incomplete.
    requiredFields = { "unit", "operator", "value" },
    description = L["Level"],
    icon = addon.Artwork.condition["LEVEL"],
    fields = { unit = "string", operator = "string", value = "number", relative = "boolean" },
    -- A known unit and operator; the value may be negative only when relative.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and (value.relative or value.value >= 0))
    end,
    -- Unavailable cases are listed above; the level itself comes from addon:GetConditionUnitLevel.
    evaluate = function(value, cache)
        local observed,reason=addon:GetConditionUnitLevel(value.unit,cache)
        if observed==nil then return nil,reason end
        if observed==false then return false end
        local level = value.value
        if value.relative then
            local playerLevel,why=addon:GetConditionUnitLevel("player",cache)
            if playerLevel==nil then return nil,why end
            if playerLevel==false then return nil,"player-level-unavailable" end
            level = playerLevel + value.value
            if level~=level or level==math.huge or level==-math.huge then return nil,"invalid-level-threshold" end
        end
        return Functions.values.compare(value.operator, observed, level)
    end,
    print = function(_, value)
        local level = value.value
        if value.relative and value.value ~= nil then
            local playerLevel=addon:GetConditionUnitLevel("player")
            level = type(playerLevel)=="number" and playerLevel + value.value or nil
            if level and (level~=level or level==math.huge or level==-math.huge) then level=nil end
        end
        return Functions.presentation.compareString(value.operator, Functions.presentation.playerize(value.unit, L["your level"], string.format(L["%s's level"],
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))), Functions.presentation.nullable(level, L["<level>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local nr_button = addon:CreateConditionCheckBox()
        nr_button:SetLabel(L["Relative"])
        nr_button:SetValue(value.relative or false)
        nr_button:SetCallback("OnValueChanged", function(_, _, val)
            value.relative = val
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(nr_button)

        local operator_group = addon:Widget_OperatorWidget(value, L["Level"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Relative"] .. color.RESET .. " - " ..
                "When checked, " .. color.BLIZ_YELLOW .. L["Level"] .. color.RESET .. " is an offset from your own " ..
                "level (for example -3 means three levels below yours); otherwise it is an absolute level."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Level"], L["Level"],
                "The level " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "'s level is compared with.")
    end,
}))

-- ============================================================================
-- Group membership
-- ============================================================================

-- GROUP: true when a unit is in your party (or raid, with `raid`). With no unit, or the player, it asks about you.
-- `spellrecipient` is meaningful only inside an announcement, where it names the recipient of the announced spell
-- (read from cache.announcementRecipient). Returns `nil, reason` for an unreadable unit, a missing announcement
-- recipient ("cast-recipient-unavailable"), an unknown unit ("invalid-unit"), or an unreadable membership. Stores
-- `unit` and `raid`.
addon:RegisterCondition("GROUP", {
    description = L["In Group"],
    icon = addon.Artwork.condition["GROUP"],
    fields = { raid = "boolean", unit = "string" },
    -- The unit may be absent, the announcement recipient or a known unit; it must be readable (not secret).
    valid = function(_, value)
        return addon.Platform:CanReadValue(value.unit) and
            (value.unit == nil or value.unit == "spellrecipient" or Functions.values.isin(addon.units, value.unit))
    end,
    -- Unavailable cases are listed above; every unit value is checked with CanReadValue before it is used.
    evaluate = function(value, cache)
        local unit=value.unit
        if unit==nil then
            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)
        end
        if not addon.Platform:CanReadValue(unit) then return nil,"restricted-value" end
        if unit=="player" then
            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)
        end
        if unit=="spellrecipient" then
            if not addon.Platform:CanReadValue(cache) or type(cache)~="table" then return nil,"cast-recipient-unavailable" end
            unit=rawget(cache,"announcementRecipient")
            if not addon.Platform:CanReadValue(unit) or type(unit)~="string" or unit=="" then return nil,"cast-recipient-unavailable" end
            return Functions.cache.getCached(cache, addon.Platform.GetAnnouncementRecipientGroupMembership, addon.Platform, unit, value.raid)
        elseif not Functions.values.isin(addon.units,unit) then return nil,"invalid-unit" end
        return Functions.cache.getCached(cache, addon.Platform.GetUnitGroupMembership, addon.Platform, unit, value.raid)
    end,
    print = function(_, value)
        if value.unit==nil or value.unit=="player" then
            return value.raid and L["you {{!are|are not}} in a raid"] or L["you {{!are|are not}} in a group"]
        end
        local label=value.unit=="spellrecipient" and L["Spell recipient"] or Functions.presentation.nullable(addon.units[value.unit],L["<unit>"])
        return addon:CreateConditionSummaryPhrase(value.raid and L["{unit} {{!is|is not}} in a raid"] or L["{unit} {{!is|is not}} in a group"],{unit=label})
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local units=Functions.collections.deepcopy(addon.units)
        if top:GetUserData("announcement")==true or value.unit=="spellrecipient" then units.spellrecipient=L["Spell recipient"] end
        if top:GetUserData("announcementTarget")==true or value.unit=="announcementtarget" then units.announcementtarget=L["Announcement target"] end
        local unit=addon:Widget_UnitWidget(value,units,function() top:SetStatusText(funcs:print(root,spec)) end)
        unit.configure=function() unit:SetList(units,Functions.collections.keys(units));unit:SetValue(value.unit or "player") end
        parent:AddChild(unit)
        local raid = addon:CreateConditionCheckBox()
        raid:SetWidth(100)
        raid:SetLabel(L["Raid"])
        raid:SetValue(value.raid and true or false)
        raid:SetCallback("OnValueChanged", function(_, _, v)
            value.raid = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(raid)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.GROUP.unit"]))
        frame:AddChild(helpers.CreateText(L["Help.GROUP.raid"]))
    end,
})

-- ============================================================================
-- MobInfo2 conditions
-- ============================================================================

-- RUNNER, RESIST and IMMUNE exist only when the MobInfo2 addon is loaded (it defines MI2_GetMobData). They read what
-- MobInfo2 has recorded about a mob type through Platform:GetMobInfo2Observation. A mob never met before has no record,
-- so each of them is false for it; they return `nil, reason` when the observation cannot be made.
if MI2_GetMobData then
    -- RUNNER: true when MobInfo2 has recorded a low-health action for the unit's mob type (it flees). Stores `unit`.
    addon:RegisterCondition("RUNNER", {
        description = L["Runner"],
        icon = addon.Artwork.condition["RUNNER"],
        fields = { unit = "string" },
        -- A known unit.
        valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
        evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"runner",nil,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        return observation.runner
    end,
        print = function(_, value)
        return string.format(L["%s {{!will|will not}} run"], Functions.presentation.nullable(addon.units[value.unit]), Functions.presentation.nullable(addon.units[value.otherunit]))
    end,
        widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
        help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end,
    })

    -- RESIST: compares the unit's recorded resistance ratio (resists divided by hits, 0 to 1) to a damage school with
    -- `value` using `operator`. Stores `unit`, `school`, `operator` and `value`.
    addon:RegisterCondition("RESIST", {
        description = L["Resistant"],
        icon = addon.Artwork.condition["RESIST"],
        fields = { unit = "string", school = "string", operator = "string", value = "number" },
        -- A known unit, school and operator, and a ratio between 0 and 1.
        valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit)) and
               (value.school ~= nil and Functions.values.isin(addon.spell_schools, value.school)) and
               (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)) and
               (value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
        evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"resist",value.school,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        return Functions.values.compare(value.operator,observation.ratio,value.value)
    end,
        print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["%s resistance to %s"],
                Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.spell_schools[value.school], L["<school>"])),
                Functions.presentation.nullable(value.value and value.value * 100 or nil) .. '%')
    end,
        widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local school = addon:CreateConditionDropdown()
        school:SetLabel(L["Spell School"])
        school:SetCallback("OnValueChanged", function(_, _, v)
            value.school = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        school.configure = function()
            school:SetList(addon.spell_schools)
            if (value.school ~= nil) then
                school:SetValue(value.school)
            end
        end
        parent:AddChild(school)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Resistance"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
        help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Spell School"] .. color.RESET .. " - " ..
                "The school of magic resistance to check."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Resistance"], L["Resistance"],
                "The resistance of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " to the specified school " ..
                "of magic as a percentage")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end,
    })

    -- IMMUNE: true when MobInfo2 has recorded immunity of the unit's mob type to a damage school. With `partial`, any
    -- recorded immunity counts; without it, the recorded hit count for that school must also be below 1, so an
    -- unknown hit count ("hitsReason") makes it unavailable. Stores `unit`, `school` and `partial`.
    addon:RegisterCondition("IMMUNE", {
        description = L["Immune"],
        icon = addon.Artwork.condition["IMMUNE"],
        fields = { unit = "string", school = "string", partial = "boolean" },
        -- A known unit and school.
        valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit)) and
                (value.school ~= nil and Functions.values.isin(addon.spell_schools, value.school))
    end,
        evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"immune",value.school,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        if value.partial then return value.partial end
        if observation.hits==nil then return nil,observation.hitsReason end
        return observation.hits < 1
    end,
        print = function(_, value)
        local template
        if value.partial then
            template = Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} sometimes immune to %s"], L["%s {{!is|is not}} sometimes immune to %s"])
        else
            template = Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} immune to %s"], L["%s {{!is|is not}} immune to %s"])
        end
        return string.format(template,
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.spell_schools[value.school], L["<school>"]))
    end,
        widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local school = addon:CreateConditionDropdown()
        school:SetLabel(L["Spell School"])
        school:SetCallback("OnValueChanged", function(_, _, v)
            value.school = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        school.configure = function()
            school:SetList(addon.spell_schools)
            if (value.school ~= nil) then
                school:SetValue(value.school)
            end
        end
        parent:AddChild(school)

        local partial = addon:CreateConditionCheckBox()
        partial:SetWidth(100)
        partial:SetLabel(L["Partial"])
        partial:SetValue(value.partial and true or false)
        partial:SetCallback("OnValueChanged", function(_, _, v)
            value.partial = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(partial)
    end,
        help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Spell School"] .. color.RESET .. " - " ..
                "The school of magic resistance to check."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Partial"] .. color.RESET .. " - " ..
                "Allow partial immunity (ie. the mob is only sometimes immune to this type of magic) to count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end,
    })
end

-- Enrolls LEVEL with the lean engine's runtime (Core/condition_runtime.lua) as a pure condition tied to the 'level'
-- fact: its result may be reused between polls until a level event. The other conditions here are read fresh each poll.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/character.lua', {
        LEVEL = {
            pure = true,
            fact = 'level',
            methods = { 'GetConditionUnitLevel' },
            platform = { 'GetUnitLevelObservation', 'CanReadValue', 'GetClientInfo' },
            namespaces = { C_Secrets = { 'HasSecretRestrictions' } },
            native = { 'UnitLevel', 'UnitExists', 'issecretvalue', 'canaccessvalue', 'C_Secrets' },
        },
    })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="character_class" then return character_class end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
        if name=="unit_class_num" then return unit_class_num end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/character.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/character.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
