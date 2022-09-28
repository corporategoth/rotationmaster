local addon_name, addon = ...

-- Skip these if we're not a shaman .. no point having totem conditions for other classes.
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

addon:RegisterCondition("TOTEM", {
    description = L["Totem Present"],
    icon = "Interface\\Icons\\spell_nature_manaregentotem",
    fields = { spell = "number" },
    valid = function(_, value)
        return value.spell ~= nil and value.spell >= 1 and value.spell <= 4
    end,
    evaluate = function(value, cache)
        local _, _, start = addon.getCached(cache, GetTotemInfo, value.spell)
        return start ~= 0
    end,
    print = function(_, value)
        return string.format(L["%s totem is active"], addon.nullable(addon.totems[value.spell], L["<element>"]))
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
            totem:SetList(addon.totems, addon.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            "The style of totem that must be placed (Fire, Wind, Water or Earth.)"))
    end
})

addon:RegisterCondition("TOTEM_SPELL", {
    description = L["Specific Totem Present"],
    icon = "Interface\\Icons\\spell_nature_stoneskintotem",
    fields = { spell = "number", ranked = "boolean" },
    valid = function(_, value)
        return value.spell ~= nil
    end,
    evaluate = function(value, cache)
        local targetTotem = addon.getCached(addon.longtermCache, GetSpellInfo, value.spell)
        for i=1,4 do
            local _, totemName, _, _ = addon.getCached(cache, GetTotemInfo, i)
            if totemName == targetTotem then
                return true
            end
        end
        return false
    end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s is active"], addon.nullable(link, L["<totem>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return (addon.isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            "The specific totem (by name) to check to ensure it is placed."))
    end
})

addon:RegisterCondition("TOTEM_REMAIN", {
    description = L["Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_nature_agitatingtotem",
    fields = { spell = "number", operator = "string", value = "string" },
    valid = function(_, value)
        return (value.spell ~= nil and value.spell >= 1 and value.spell <= 4 and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local _, _, start, duration = addon.getCached(cache, GetTotemInfo, value.spell)
        if start ~= nil then
            local remain = addon.round(duration - (GetTime() - start), 3)
            return addon.compare(value.operator, remain, value.value)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["you have a %s totem active with %s"],
            addon.nullable(addon.totems[value.spell], L["<element>"]),
                addon.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], addon.nullable(value.value))))
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
            totem:SetList(addon.totems, addon.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                "The style of totem that must be placed (Fire, Wind, Water or Earth.)"))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Totem Time Remaining"], L["Count"],
            "The amount of time remaining on " .. color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " before it" ..
            "expire.")
    end
})

addon:RegisterCondition("TOTEM_SPELL_REMAIN", {
    description = L["Specific Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_fireresistancetotem_01",
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "string" },
    valid = function(_, value)
        return (value.spell ~= nil and value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local targetTotem = addon.getCached(addon.longtermCache, GetSpellInfo, value.spell)
        for i=1,4 do
            local _, totemName, start, duration = addon.getCached(cache, GetTotemInfo, i)
            if totemName == value.spell then
                local remain = addon.round(duration - (GetTime() - start), 3)
                return addon.compare(value.operator, remain, targetTotem)
            end
        end
        return false
    end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s is active with %s"], addon.nullable(link, L["<totem>"]),
            addon.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], addon.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v) return (addon.isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                "The specific totem (by name) to check to ensure it is placed."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Specific Totem Time Remaining"], L["Count"],
            "The amount of time remaining on " .. color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " before it" ..
                    "expire.")
    end
})
