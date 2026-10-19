local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local unit_class_num

-- Snapshot only the explicit pure/cache leaves used by these callbacks.
-- Native observations, source variants and captured class values stay intact.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
    cache={getCached=addon.Functions.cache.getCached},
    collections={deepcopy=addon.Functions.collections.deepcopy,keys=addon.Functions.collections.keys},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/character.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
}

addon:RegisterCondition("ISSAME", {
    description = L["Is Same As"],
    icon = addon.Artwork.condition["ISSAME"],
    fields = { unit = "string", otherunit = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.otherunit ~= nil and Functions.values.isin(addon.units, value.otherunit))
    end,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitIdentityObservation, addon.Platform, value.unit, value.otherunit)
    end,
    print = function(_, value)
        return string.format(L["%s {{!is|is not}} %s"], Functions.presentation.nullable(addon.units[value.unit]), Functions.presentation.nullable(addon.units[value.otherunit]))
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
    end
})

addon:RegisterCondition("CLASS", {
    description = L["Class"],
    icon = addon.Artwork.condition["CLASS"],
    fields = { unit = "string", value = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(LOCALIZED_CLASS_NAMES_MALE, value.value))
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local _, englishClass = Functions.cache.getCached(cache, UnitClass, value.unit)
        return englishClass == value.value
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} a %s"], L["%s {{!is|is not}} a %s"]),
            Functions.presentation.nullable(addon.units[value.unit]), Functions.presentation.nullable(LOCALIZED_CLASS_NAMES_MALE[value.value], L["<class>"]))
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
    end
})

local character_class = select(2, UnitClass("player"))
addon:RegisterCondition("CLASS_GROUP", {
    description = L["Class In Group"],
    icon = addon.Artwork.condition["CLASS_GROUP"],
    fields = { class = "string", operator = "string", value = "number", raid = "boolean" },
    valid = function(_, value)
        return (value.class ~= nil and Functions.values.isin(LOCALIZED_CLASS_NAMES_MALE, value.class) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, IsInGroup) then
            return Functions.values.compare(value.operator, (character_class == value.class and 1 or 0), value.value)
        end

        local count = 0
        local prefix, size = "party", 4
        if value.raid and Functions.cache.getCached(cache, IsInRaid) then
            prefix, size = "raid", 40
        end
        if prefix == "party" and character_class == value.class then
            count = count + 1
        end
        for i=1,size do
            if select(2, Functions.cache.getCached(cache, UnitClass, prefix .. tostring(i))) == value.class then
                count = count + 1
            end
        end
        return Functions.values.compare(value.operator, count, value.value)
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
    end
})

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then


    addon:RegisterCondition("ROLE", {
        builtinSourceVariant = "inspect",
        description = L["Role"],
        icon = addon.Artwork.condition["ROLE"],
        fields = { unit = "string", value = "string" },
        valid = function(_, value)
            return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                    value.value ~= nil and Functions.values.isin(addon.roles, value.value))
        end,
        evaluate = function(value, cache)
            if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
            local role = select(6, Functions.cache.getCached(cache, GetSpecializationInfoByID, Functions.cache.getCached(cache, GetInspectSpecialization, value.unit)))
            return role == value.value
        end,
        print = function(_, value)
            return string.format(L["%s {{!is|is not}} in a %s role"],
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
        end
    })
else


    if LE_EXPANSION_LEVEL_CURRENT >= 2 then
        addon:RegisterCondition("ROLE", {
            builtinSourceVariant = "talent",
            description = L["Role"],
            icon = addon.Artwork.condition["ROLE"],
            fields = { value = "string" },
            valid = function(_, value)
                return value.value ~= nil and Functions.values.isin(addon.roles, value.value)
            end,
            evaluate = function(value, cache)
                return Functions.cache.getCached(cache, GetTalentGroupRole, addon.currentSpec) == value.value
            end,
            print = function(_, value)
                return string.format(L["Your talent {{!is|is not}} a %s role"],
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
                        "The current role of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Tank"] .. color.RESET .. " - " ..
                        "Designed to keep the attention and take most of the hits from enemies.  aka. Meat Shields.")))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["DPS"] .. color.RESET .. " - " ..
                        "The primary damage dealers against enemies, and lovers of standing in fire.")))
                frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Healer"] .. color.RESET .. " - " ..
                        "Those who keep everyone else alive by healing them.  Thank them!")))
            end
        })
    end
end

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or LE_EXPANSION_LEVEL_CURRENT >= 2) then
    unit_class_num = select(3, UnitClass("player"))
    addon:RegisterCondition("GLYPH", {
        description = L["Glyph"],
        icon = addon.Artwork.condition["GLYPH"],
        fields = { item = "number" },
        valid = function(_, value)
            if value.item ~= nil then
                return addon.Platform:GetGlyphItemInfo(value.item, unit_class_num) ~= nil
            else
                return false
            end
        end,
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
            local link = value.item and select(2, GetItemInfo(value.item)) or nil
            return string.format(L["you {{!have|do not have}} %s glyph"], Functions.presentation.nullable(link, L["<glyph>"]))
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
            addon.layout_condition_spellwidget_help(frame)
        end
    })
end

addon:RegisterCondition("CREATURE", {
    description = L["Creature Type"],
    icon = addon.Artwork.condition["CREATURE"],
    fields = { unit = "string", value = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(addon.creatures, value.value))
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitCreatureType, value.unit) == addon.creatures[value.value])
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} a %s"], L["%s {{!is|is not}} a %s"]),
            Functions.presentation.nullable(addon.units[value.unit]), Functions.presentation.nullable(addon.creatures[value.value], L["<creature type>"]))
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
    end
})

addon:RegisterCondition("CLASSIFICATION", {
    description = L["Unit Classification"],
    icon = addon.Artwork.condition["CLASSIFICATION"],
    fields = { unit = "string", value = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and Functions.values.isin(addon.classifications, value.value))
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitClassification, value.unit) == value.value)
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} a %s"], L["%s {{!is|is not}} a %s"]),
                Functions.presentation.nullable(addon.units[value.unit]), Functions.presentation.nullable(addon.classifications[value.value], L["<classification>"]))
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
                "can be used to create conditions only apply to certain unit addon.classifications (eg. bosses)."))
    end
})

addon:RegisterCondition("LEVEL", {
    requiredFields = {"unit","operator","value"},
    description = L["Level"],
    icon = addon.Artwork.condition["LEVEL"],
    fields = { unit = "string", operator = "string", value = "number", relative = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and (value.relative or value.value >= 0))
    end,
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
        addon.layout_condition_operatorwidget_help(frame, L["Relative"], L["Relative"],
                "Should the level be relative to the player's or absolute.")
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Level"], L["Level"],
                "The character's level")
    end
})

addon:RegisterCondition("GROUP", {
    description = L["In Group"],
    icon = addon.Artwork.condition["GROUP"],
    fields = { raid = "boolean" },
    valid = function()
        return true
    end,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)
    end,
    print = function(_, value)
        return value.raid and L["you {{!are|are not}} in a raid"] or L["you {{!are|are not}} in a group"]
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

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
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Raid"] .. color.RESET ..
                " - " .. "Check to see if we are in a raid, instead of just a party (note that with ."
                      .. "this option off, this condition will be true if you are in a part OR a raid)."))
    end
})

if MI2_GetMobData then
addon:RegisterCondition("RUNNER", {
    description = L["Runner"],
    icon = addon.Artwork.condition["RUNNER"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        return (data.lowHpAction and true or false)
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
    end
})

addon:RegisterCondition("RESIST", {
    description = L["Resistant"],
    icon = addon.Artwork.condition["RESIST"],
    fields = { unit = "string", school = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit)) and
               (value.school ~= nil and Functions.values.isin(addon.spell_schools, value.school)) and
               (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)) and
               (value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] > 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return Functions.values.compare(value.operator, (data.resists[value.school] / hits), value.value)
        end
        return false
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["%s's resistance to %s"],
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.spell_schools[value.school], L["<school>"])),
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
    end
})

addon:RegisterCondition("IMMUNE", {
    description = L["Immune"],
    icon = addon.Artwork.condition["IMMUNE"],
    fields = { unit = "string", school = "string", partial = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit)) and
                (value.school ~= nil and Functions.values.isin(addon.spell_schools, value.school))
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] < 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return value.partial or (hits < 1)
        end
        return false
    end,
    print = function(_, value)
        return string.format(value.partial and L["%s {{!is|is not}} sometimes immune to %s"] or L["%s {{!is|is not}} immune to %s"],
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
    end
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
