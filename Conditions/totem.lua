local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, totems = addon.operators, addon.totems

-- From utils
local compare, compareString, nullable, keys, isin, getCached, isSpellOnSpec, round =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached, addon.isSpellOnSpec, addon.round

addon:RegisterCondition("TOTEM", {
    description = L["Totem Present"],
    icon = "Interface\\Icons\\spell_nature_manaregentotem",
    valid = function(spec, value)
        return value.spell ~= nil and value.spell >= 1 and value.spell <= 4
    end,
    evaluate = function(value, cache, evalStart)
        local _, _, start = getCached(cache, GetTotemInfo, value.spell)
        return start ~= 0
    end,
    print = function(spec, value)
        return string.format(L["%s totem is active"], nullable(totems[value.spell], L["<element>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = AceGUI:Create("Dropdown")
        parent:AddChild(totem)
        totem.configure = function()
            totem:SetLabel(L["Totem"])
            totem:SetList(totems, keys(totems))
            totem:SetValue(value.spell)
            totem:SetCallback("OnValueChanged", function(widget, event, v)
                value.spell = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end
    end,
})

addon:RegisterCondition("TOTEM_SPELL", {
    description = L["Specific Totem Present"],
    icon = "Interface\\Icons\\spell_nature_stoneskintotem",
    valid = function(spec, value)
        return value.spell ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        local targetTotem = getCached(addon.longtermCache, GetSpellInfo, value.spell)
        for i=1,4 do
            local _, totemName, _, _ = getCached(cache, GetTotemInfo, i)
            if totemName == targetTotem then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
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
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return (isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
})

addon:RegisterCondition("TOTEM_REMAIN", {
    description = L["Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_nature_agitatingtotem",
    valid = function(spec, value)
        return (value.spell ~= nil and value.spell >= 1 and value.spell <= 4 and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local _, _, start, duration = getCached(cache, GetTotemInfo, value.spell)
        if start ~= nil then
            local remain = round(duration - (GetTime() - start), 3)
            return compare(value.operator, remain, value.value)
        end
        return false
    end,
    print = function(spec, value)
        return string.format(L["you have a %s totem active with %s"],
            nullable(totems[value.spell], L["<element>"]),
                compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = AceGUI:Create("Dropdown")
        parent:AddChild(totem)
        totem.configure = function()
            totem:SetLabel(L["Totem"])
            totem:SetList(totems, keys(totems))
            totem:SetValue(value.spell)
            totem:SetCallback("OnValueChanged", function(widget, event, v)
                value.spell = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
})

addon:RegisterCondition("TOTEM_SPELL_REMAIN", {
    description = L["Specific Totem Time Remaining"],
    icon = "Interface\\Icons\\spell_fireresistancetotem_01",
    valid = function(spec, value)
        return (value.spell ~= nil and value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
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
    print = function(spec, value)
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
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return (isSpellOnSpec(spec, v) and string.find(GetSpellInfo(v), L["Totem"])) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
})
