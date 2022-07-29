local _, addon = ...

-- Skip these if we're not a shaman .. no point having totem conditions for other classes.
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local operators, totems = addon.operators, addon.totems

-- From utils
local compare, compareString, nullable, keys, isin, getCached, isSpellOnSpec, getSpecSpellID, round =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached, addon.isSpellOnSpec, addon.getSpecSpellID, addon.round

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

addon.condition_totem = {
    description = L["Totem Present"],
    icon = "Interface\\Icons\\spell_nature_manaregentotem",
    valid = function(_, value)
        return value.spell ~= nil and value.spell >= 1 and value.spell <= 4
    end,
    evaluate = function(value, cache)
        local _, _, start = getCached(cache, GetTotemInfo, value.spell)
        return start ~= 0
    end,
    print = function(_, value)
        return string.format(L["%s totem is active"], nullable(totems[value.spell], L["<element>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = AceGUI:Create("Dropdown")
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(totems, keys(totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            "The style of totem that must be placed (Fire, Wind, Water or Earth.)"))
    end
}

addon.condition_totem_spell = {
    description = L["Specific Totem Present"],
    icon = "Interface\\Icons\\spell_nature_stoneskintotem",
    valid = function(_, value)
        return value.spell ~= nil
    end,
    evaluate = function(value, cache)
        local targetTotem = getCached(addon.longtermCache, GetSpellInfo, value.spell)
        for i=1,4 do
            local _, totemName, _, _ = getCached(cache, GetTotemInfo, i)
            if totemName == targetTotem then
                return true
            end
        end
        return false
    end,
    print = function(_, value)
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["%s is active"], nullable(link, L["<totem>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return getSpecSpellID(spec, v) end,
            function(v) return (isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            "The specific totem (by name) to check to ensure it is placed."))
    end
}

addon.condition_totem_remain = {
    description = L["Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_nature_agitatingtotem",
    valid = function(_, value)
        return (value.spell ~= nil and value.spell >= 1 and value.spell <= 4 and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local _, _, start, duration = getCached(cache, GetTotemInfo, value.spell)
        if start ~= nil then
            local remain = round(duration - (GetTime() - start), 3)
            return compare(value.operator, remain, value.value)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["you have a %s totem active with %s"],
            nullable(totems[value.spell], L["<element>"]),
                compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = AceGUI:Create("Dropdown")
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(totems, keys(totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                "The style of totem that must be placed (Fire, Wind, Water or Earth.)"))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Totem Time Remaining"], L["Count"],
            "The amount of time remaining on " .. color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " before it" ..
            "expire.")
    end
}

addon.condition_totem_spell_remain = {
    description = L["Specific Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_fireresistancetotem_01",
    valid = function(_, value)
        return (value.spell ~= nil and value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local targetTotem = getCached(addon.longtermCache, GetSpellInfo, value.spell)
        for i=1,4 do
            local _, totemName, start, duration = getCached(cache, GetTotemInfo, i)
            if totemName == value.spell then
                local remain = round(duration - (GetTime() - start), 3)
                return compare(value.operator, remain, targetTotem)
            end
        end
        return false
    end,
    print = function(_, value)
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["%s is active with %s"], nullable(link, L["<totem>"]),
            compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return getSpecSpellID(spec, v) end,
            function(v) return (isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                "The specific totem (by name) to check to ensure it is placed."))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Specific Totem Time Remaining"], L["Count"],
            "The amount of time remaining on " .. color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " before it" ..
                    "expire.")
    end
}
