local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color
local floor = math.floor

-- From constants
local units, unitsPossessive, roles, creatures, classifications, operators, spell_schools =
    addon.units, addon.unitsPossessive, addon.roles, addon.creatures, addon.classifications, addon.operators, addon.spell_schools

-- From utils
local nullable, keys, isin, deepcopy, getCached, playerize, compare, compareString =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.getCached, addon.playerize, addon.compare, addon.compareString

local helpers = addon.help_funcs
local CreateText, Indent, Gap =
    helpers.CreateText, helpers.Indent, helpers.Gap

addon:RegisterCondition(nil, "ISSAME", {
    description = L["Is Same As"],
    icon = 134167,
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.otherunit ~= nil and isin(units, value.otherunit))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        return getCached(cache, UnitIsUnit, value.unit, value.otherunit)
    end,
    print = function(_, value)
        return string.format(L["%s is %s"], nullable(units[value.unit]), nullable(units[value.otherunit]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local otherunit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end, "otherunit")
        parent:AddChild(otherunit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition(nil, "CLASS", {
    description = L["Class"],
    icon = "Interface\\Icons\\achievement_general_stayclassy",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(LOCALIZED_CLASS_NAMES_MALE, value.value))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local _, englishClass = getCached(cache, UnitClass, value.unit);
        return englishClass == value.value
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s are a %s"], L["%s is a %s"]),
            nullable(units[value.unit]), nullable(LOCALIZED_CLASS_NAMES_MALE[value.value], L["<class>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = AceGUI:Create("Dropdown")
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

        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Class"] .. color.RESET .. " - " ..
            "The character class of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
    end
})

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition(nil, "ROLE", {
        description = L["Role"],
        icon = "Interface\\Icons\\petbattle_health",
        valid = function(_, value)
            return (value.unit ~= nil and isin(units, value.unit) and
                    value.value ~= nil and isin(roles, value.value))
        end,
        evaluate = function(value, cache)
            if not getCached(cache, UnitExists, value.unit) then return false end
            local role = select(6, getCached(cache, GetSpecializationInfoByID, getCached(cache, GetInspectSpecialization, value.unit)))
            return role == value.value
        end,
        print = function(_, value)
            return string.format(L["%s is in a %s role"],
                nullable(unitsPossessive[value.unit], L["<unit>"]),
                nullable(roles[value.value], L["<role>"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(unit)

            local role = AceGUI:Create("Dropdown")
            role:SetLabel(L["Role"])
            role:SetCallback("OnValueChanged", function(_, _, v)
                value.value = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            role.configure = function()
                role:SetList(roles, keys(roles))
                if (value.value ~= nil) then
                    role:SetValue(value.value)
                end
            end
            parent:AddChild(role)
        end,
        help = function(frame)
            addon.layout_condition_unitwidget_help(frame)

            frame:AddChild(Gap())
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Role"] .. color.RESET .. " - " ..
                "The current role of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Tank"] .. color.RESET .. " - " ..
                "Designed to keep the attention and take most of the hits from enemies.  aka. Meat Shields.")))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["DPS"] .. color.RESET .. " - " ..
                "The primary damage dealers against enemies, and lovers of standing in fire.")))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Healer"] .. color.RESET .. " - " ..
                "Those who keep everyone else alive by healing them.  Thank them!")))
        end
    })

    addon:RegisterCondition(nil, "TALENT", {
        description = L["Talent"],
        icon = "Interface\\Icons\\Inv_misc_book_11",
        valid = function(_, value)
            return value.value ~= nil and value.value >= 1 and value.value <= 21
        end,
        evaluate = function(value)
            local selected = select(4, getCached(addon.longtermCache, GetTalentInfo, floor((value.value-1) / 3) + 1, ((value.value-1) % 3) + 1, 1))
            return selected
        end,
        print = function(spec, value)
            return string.format(L["you are talented in %s"], nullable(addon:GetSpecTalentName(spec, value.value), L["<talent>"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local talents = {}
            local talentsOrder = {}
            for i=1,21 do
                talents[i] = addon:GetSpecTalentName(spec, i)
                table.insert(talentsOrder, i)
            end

            local talentIcon = AceGUI:Create("Icon")
            talentIcon:SetWidth(44)
            talentIcon:SetHeight(44)
            talentIcon:SetImageSize(36, 36)
            talentIcon:SetImage(addon:GetSpecTalentIcon(spec, value.value))
            parent:AddChild(talentIcon)

            local talent = AceGUI:Create("Dropdown")
            talent:SetLabel(L["Talent"])
            talent:SetCallback("OnValueChanged", function(_, _, v)
                value.value = v
                talentIcon:SetImage(addon:GetSpecTalentIcon(spec, value.value))
                top:SetStatusText(funcs:print(root, spec))
            end)
            talent.configure = function()
                talent:SetList(talents, talentsOrder)
                if (value.value) then
                    talent:SetValue(value.value)
                end
            end
            parent:AddChild(talent)
        end,
        help = function(frame)
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Talent"] .. color.RESET .. " - " ..
                "A talent you have enabled in your specialization.  If you are currently in the same spec " ..
                "as the rotation you are configuring (or have switched specializations without reloading " ..
                "your user interface), this will show the talents.  Otherwise, this will simply show the " ..
                "level and selection numbers (this is a restriction imposed by the game itself.)"))
        end
    })
else
    addon:RegisterCondition(nil, "TALENT", {
        description = L["Talent"],
        icon = "Interface\\Icons\\Inv_misc_book_11",
        valid = function(_, value)
            return (value.tree ~= nil and value.tree >= 1 and value.tree <= GetNumTalentTabs() and
                    value.talent ~= nil and value.talent >= 1 and value.talent <= GetNumTalents(value.talent) and
                    value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value)
            local _, _, _, _, rank = getCached(addon.longtermCache, GetTalentInfo, value.tree, value.talent)
            return compare(value.operator, rank, value.value)
        end,
        print = function(_, value)
            return compareString(value.operator, string.format(L["talent points in %s (%s)"],
                    nullable((value.tree and value.talent) and GetTalentInfo(value.tree, value.talent) or nil, L["<talent>"]),
                    nullable(value.tree and GetTalentTabInfo(value.tree) or nil, L["<talent tree>"])),
                    nullable(value.value))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local talentTrees = {}
            local talentTreesOrder = {}
            for i=1,GetNumTalentTabs() do
                talentTrees[i] = GetTalentTabInfo(i)
                table.insert(talentTreesOrder, i)
            end

            local talents = {}
            local talentsOrder = {}
            if value.tree then
                for i=1,GetNumTalents(value.tree) do
                    talents[i] = GetTalentInfo(value.tree, i)
                    table.insert(talentsOrder, i)
                end
            end

            local talentTree = AceGUI:Create("Dropdown")
            local talentIcon = AceGUI:Create("Icon")
            local talent = AceGUI:Create("Dropdown")

            local talentTreeName
            if value.tree then
                talentTreeName = GetTalentTabInfo(value.tree)
            else
                talent:SetDisabled(true)
            end
            local talentName, talentImage
            if value.tree and value.talent then
                talentName, talentImage = GetTalentInfo(value.tree, value.talent)
            end

            talentTree:SetLabel(L["Talent Tree"])
            talentTree:SetCallback("OnValueChanged", function(_, _, v)
                if v == value.tree then
                    return
                end

                value.tree = v
                talentTreeName = GetTalentTabInfo(v)
                talentTree:SetValue(v)
                top:SetStatusText(funcs:print(root, spec))

                talents = {}
                talentsOrder = {}
                for i=1,GetNumTalents(value.tree) do
                    talents[i] = GetTalentInfo(value.tree, i)
                    table.insert(talentsOrder, i)
                end
                talentIcon:SetImage(nil)
                talent:SetList(talents, talentsOrder)
                talent:SetDisabled(false)
                talentName, talentImage = nil, nil
                talent:SetValue(nil)
                talent:SetText(nil)
            end)
            talentTree.configure = function()
                talentTree:SetList(talentTrees, talentTreesOrder)
                if value.tree then
                    talentTree:SetValue(value.tree)
                end
            end
            parent:AddChild(talentTree)

            talentIcon:SetWidth(44)
            talentIcon:SetHeight(44)
            talentIcon:SetImageSize(36, 36)
            if value.tree and value.talent then
                talentIcon:SetImage(talentImage)
            end
            parent:AddChild(talentIcon)
            talent:SetLabel(L["Talent"])
            talent:SetCallback("OnValueChanged", function(_, _, v)
                if v == value.talent then
                    return
                end

                value.talent = v
                talentName, talentImage = GetTalentInfo(value.tree, v)
                talentIcon:SetImage(talentImage)
                talent:SetValue(v)
                top:SetStatusText(funcs:print(root, spec))
            end)
            talent.configure = function()
                talent:SetList(talents, talentsOrder)
                if value.tree and value.talent then
                    talent:SetValue(value.talent)
                end
            end
            parent:AddChild(talent)

            local operator_group = addon:Widget_OperatorWidget(value, L["Points"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)
        end,
        help = function(frame)
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Talent Tree"] .. color.RESET .. " - " ..
                "The tree that the talent this condition is testing is from."))

            frame:AddChild(Gap())
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Talent"] .. color.RESET .. " - " ..
                "A talent you have available to you."))

            frame:AddChild(Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Talent"], L["Points"],
                "How many points you have put into " .. color.BLIZ_YELLOW .. L["Talent"] .. color.RESET .. ".");
        end
    })
end

addon:RegisterCondition(nil, "CREATURE", {
    description = L["Creature Type"],
    icon = "Interface\\Icons\\ability_rogue_disguise",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(creatures, value.value))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        return (getCached(cache, UnitCreatureType, value.unit) == creatures[value.value])
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s are a %s"], L["%s is a %s"]),
            nullable(units[value.unit]), nullable(creatures[value.value], L["<creature type>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = AceGUI:Create("Dropdown")
        class:SetLabel(L["Creature Type"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(creatures, keys(creatures))
            if (value.value ~= nil) then
                class:SetValue(value.value)
            end
        end
        parent:AddChild(class)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Creature Type"] .. color.RESET .. " - " ..
                "The creature type of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
                "can be used to create conditions that are restricted by creature type (eg. Banish)."))
    end
})

addon:RegisterCondition(nil, "CLASSIFICATION", {
    description = L["Unit Classification"],
    icon = "Interface\\Icons\\inv_mask_01",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(classifications, value.value))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        return (getCached(cache, UnitClassification, value.unit) == value.value)
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s are a %s"], L["%s is a %s"]),
                nullable(units[value.unit]), nullable(classifications[value.value], L["<classification>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local class = AceGUI:Create("Dropdown")
        class:SetLabel(L["Unit Classification"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(classifications, keys(classifications))
            if (value.value ~= nil) then
                class:SetValue(value.value)
            end
        end
        parent:AddChild(class)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)

        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Unit Classification"] .. color.RESET .. " - " ..
                "The classification of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
                "can be used to create conditions only apply to certain unit classifications (eg. bosses)."))
    end
})

addon:RegisterCondition(nil, "LEVEL", {
    description = L["Level"],
    icon = "Interface\\Icons\\spell_holy_blessedrecovery",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and (value.relative or value.value >= 0))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local level = value.value
        if value.relative then
            level = getCached(addon.longtermCache, UnitLevel, "player") + value.value
        end
        return compare(value.operator, getCached(cache, UnitLevel, value.unit), level)
    end,
    print = function(_, value)
        local level = value.value
        if value.relative and value.value ~= nil then
            level = getCached(addon.longtermCache, UnitLevel, "player") + value.value
        end
        return compareString(value.operator, playerize(value.unit, L["your level"], string.format(L["%s's level"],
                nullable(units[value.unit], L["<unit>"]))), nullable(level, L["<level>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local nr_button = AceGUI:Create("CheckBox")
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
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Relative"], L["Relative"],
                "Should the level be relative to the player's or absolute.")
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Level"], L["Level"],
                "The character's level")
    end
})

if MI2_GetMobData then
addon:RegisterCondition(nil, "RUNNER", {
    description = L["Runner"],
    icon = 135996,
    valid = function(_, value)
        return value.unit ~= nil and isin(units, value.unit)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        return (data.lowHpAction and true or false)
    end,
    print = function(_, value)
        return string.format(L["%s will run"], nullable(units[value.unit]), nullable(units[value.otherunit]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end
})

addon:RegisterCondition(nil, "RESIST", {
    description = L["Resistant"],
    icon = 132295,
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit)) and
               (value.school ~= nil and isin(spell_schools, value.school)) and
               (value.operator ~= nil and isin(operators, value.operator)) and
               (value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] > 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return compare(value.operator, (data.resists[value.school] / hits), value.value)
        end
        return false
    end,
    print = function(_, value)
        return compareString(value.operator, string.format(L["%s's resistance to %s"],
                nullable(units[value.unit], L["<unit>"]), nullable(spell_schools[value.school], L["<school>"])),
                nullable(value.value and value.value * 100 or nil) .. '%')
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local school = AceGUI:Create("Dropdown")
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell School"] .. color.RESET .. " - " ..
                "The school of magic resistance to check."))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Resistance"], L["Resistance"],
                "The resistance of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " to the specified school " ..
                "of magic as a percentage")
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end
})

addon:RegisterCondition(nil, "IMMUNE", {
    description = L["Immune"],
    icon = 132137,
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit)) and
                (value.school ~= nil and isin(spell_schools, value.school))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] < 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return value.partial or (hits < 1)
        end
        return false
    end,
    print = function(_, value)
        return string.format(value.partial and L["%s is sometimes immune to %s"] or L["%s is immune to %s"],
                nullable(units[value.unit], L["<unit>"]), nullable(spell_schools[value.school], L["<school>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local school = AceGUI:Create("Dropdown")
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

        local partial = AceGUI:Create("CheckBox")
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell School"] .. color.RESET .. " - " ..
                "The school of magic resistance to check."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Partial"] .. color.RESET .. " - " ..
                "Allow partial immunity (ie. the mob is only sometimes immune to this type of magic) to count."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.RED .. "This condition uses data from the MobInfo2 addon.  As such " ..
                "it relies on previous interactions with the type of mob in question, which may be inaccurate. " ..
                "Additionally, until you encounter the mob at least once, this condition will always be false."))
    end
})
end