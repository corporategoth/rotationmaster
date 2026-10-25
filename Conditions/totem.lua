local addon_name, addon = ...

-- Skip these if we're not a shaman .. no point having totem conditions for other classes.
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical leaves for direct callbacks; private observation and validation
-- helpers keep their existing source contracts for saved custom requirements.
local Functions={
    collections={keys=addon.Functions.collections.keys},
    values={compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/totem.lua"]={
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
}

local platform=addon.Platform
local function observe(cache,method,...)
    return addon.getCached(cache,method,platform,...)
end
local function remaining(record,start)
    if not record.active then return 0 end
    return math.max(0,record.startTime+record.duration-(start or GetTime()))
end
local function element(value)
    return addon.IsConditionSpellID(value.spell) and value.spell<=4
end
local function amount(value)
    return type(value.value)=="number" and value.value==value.value and value.value>=0 and value.value<math.huge
        and type(value.operator)=="string" and addon.isin(addon.operators,value.operator)
end
local function specific(value)
    return addon.IsConditionSpellID(value.spell) and (value.ranked==nil or type(value.ranked)=="boolean")
end
local function findSpecific(value,cache,start,compareTime)
    local target,reason=observe(cache,platform.GetSpellInfo,value.spell)
    if not target then return nil,reason end
    local count,why=observe(cache,platform.GetTotemSlotCount)
    if not count then return nil,why end
    local unavailable
    for slot=1,count do
        local record,problem=observe(cache,platform.GetTotemInfo,slot)
        if not record then unavailable=unavailable or problem or "totem-data-unavailable"
        elseif record.active and remaining(record,start)>0 then
            local matches=false
            if value.ranked then
                if record.spellID then matches=record.spellID==value.spell
                elseif record.name==target.name or record.name=="" then unavailable=unavailable or "totem-rank-unavailable" end
            else
                matches=record.spellID==value.spell or record.name==target.name
                if not matches and record.name=="" then
                    local info,issue
                    if record.spellID then info,issue=observe(cache,platform.GetSpellInfo,record.spellID) end
                    if info then matches=info.name==target.name
                    else unavailable=unavailable or issue or "totem-identity-unavailable" end
                end
            end
            if matches and (not compareTime or addon.compare(value.operator,addon.round(remaining(record,start),3),value.value)) then return true end
        end
    end
    if unavailable then return nil,unavailable end
    return false
end

addon:RegisterCondition("TOTEM", {
    description = L["Totem Present"],
    icon = addon.Artwork.condition["TOTEM"],
    fields = { spell = "number" }, requiredFields = { "spell" },
    valid = function(_, value) return element(value) end,
    evaluate = function(value, cache, start)
        local record,reason=observe(cache,platform.GetTotemInfo,value.spell)
        if not record then return nil,reason end
        return record.active and remaining(record,start)>0
    end,
    print = function(_, value)
        return string.format(L["%s totem {{!is|is not}} active"], Functions.presentation.nullable(addon.totems[value.spell], L["<element>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = addon:CreateConditionDropdown()
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(addon.totems, Functions.collections.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            L["The elemental slot to check: Fire, Earth, Water or Air. Empty, zero-duration and expired totems do not match."]))
    end
})

addon:RegisterCondition("TOTEM_SPELL", {
    description = L["Specific Totem Present"],
    icon = addon.Artwork.condition["TOTEM_SPELL"],
    fields = { spell = "number", ranked = "boolean" }, requiredFields = { "spell" },
    valid = function(_, value) return specific(value) end,
    evaluate = function(value, cache, start) return findSpecific(value,cache,start,false) end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} active"], Functions.presentation.nullable(link, L["<totem>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v)
                local info=addon.Platform:GetSpellInfo(v)
                return addon.isSpellOnSpec(spec,v) and info and string.find(info.name,L["Totem"],1,true)~=nil
            end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
            L["The active totem to check. Unranked checks match its localized name across ranks. Exact-rank checks require the native spell ID; name-only observations are unavailable."]))
    end
})

addon:RegisterCondition("TOTEM_REMAIN", {
    description = L["Totem Time Remaining"],
    icon = addon.Artwork.condition["TOTEM_REMAIN"],
    fields = { spell = "number", operator = "string", value = "number" }, requiredFields = { "spell", "operator", "value" },
    valid = function(_, value) return element(value) and amount(value) end,
    evaluate = function(value, cache, start)
        local record,reason=observe(cache,platform.GetTotemInfo,value.spell)
        if not record then return nil,reason end
        local seconds=remaining(record,start)
        return record.active and seconds>0 and Functions.values.compare(value.operator,addon.Functions.values.round(seconds,3),value.value)
    end,
    print = function(_, value)
        return string.format(L["you {{!have|do not have}} a %s totem active where %s"],
            Functions.presentation.nullable(addon.totems[value.spell], L["<element>"]),
                Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local totem = addon:CreateConditionDropdown()
        totem:SetLabel(L["Totem"])
        totem:SetCallback("OnValueChanged", function(_, _, v)
            value.spell = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        totem.configure = function()
            totem:SetList(addon.totems, Functions.collections.keys(addon.totems))
            totem:SetValue(value.spell)
        end
        parent:AddChild(totem)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                L["The elemental slot to check: Fire, Earth, Water or Air. Empty, zero-duration and expired totems do not match."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Totem Time Remaining"], L["Seconds"],
            L["Compare the active totem's remaining seconds with this amount. An absent or expired totem does not match; unavailable observations stay unavailable."])
    end
})

addon:RegisterCondition("TOTEM_SPELL_REMAIN", {
    description = L["Specific Totem Time Remaining"],
    icon = addon.Artwork.condition["TOTEM_SPELL_REMAIN"],
    fields = { spell = "number", ranked = "boolean", operator = "string", value = "number" }, requiredFields = { "spell", "operator", "value" },
    valid = function(_, value) return specific(value) and amount(value) end,
    evaluate = function(value, cache, start) return findSpecific(value,cache,start,true) end,
    print = function(_, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s {{!is|is not}} active where %s"], Functions.presentation.nullable(link, L["<totem>"]),
            Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Totem_EditBox", value,
            function(v) return addon.getSpecSpellID(spec, v) end,
            function(v)
                local info=addon.Platform:GetSpellInfo(v)
                return addon.isSpellOnSpec(spec,v) and info and string.find(info.name,L["Totem"],1,true)~=nil
            end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Totem"] .. color.RESET .. " - " ..
                L["The active totem to check. Unranked checks match its localized name across ranks. Exact-rank checks require the native spell ID; name-only observations are unavailable."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Specific Totem Time Remaining"], L["Seconds"],
            L["Compare the active totem's remaining seconds with this amount. An absent or expired totem does not match; unavailable observations stay unavailable."])
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="amount" then return amount end
        if name=="color" then return color end
        if name=="element" then return element end
        if name=="findSpecific" then return findSpecific end
        if name=="helpers" then return helpers end
        if name=="observe" then return observe end
        if name=="platform" then return platform end
        if name=="remaining" then return remaining end
        if name=="specific" then return specific end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/totem.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/totem.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
