local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
addon:RegisterCondition("BEYOND_MELEE",{
    description=L["Beyond Melee Range"],icon = addon.Artwork.condition["BEYOND_MELEE"],
    fields={unit="string"},requiredFields={"unit"},
    valid=function(_,value) return type(value.unit)=="string" and addon.units[value.unit]~=nil end,
    evaluate=function(value)
        if type(UnitExists)~="function" then return nil,"missing-api" end
        local ok,exists=pcall(UnitExists,value.unit)
        if not ok then return nil,"api-error" end
        if not addon.Platform:CanReadValue(exists) then return nil,"restricted-value" end
        if exists==nil or exists==false then return false end
        if exists~=true and exists~=1 then return nil,"invalid-api-result" end
        return addon.Platform:IsBeyondMeleeRange(value.unit)
    end,
    print=function(_,value) return string.format(L["%s {{!is|is not}} beyond melee range"],addon.units[value.unit] or L["<unit>"]) end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData("top")
        parent:AddChild(addon:Widget_UnitWidget(value,addon.units,function()
            top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"),spec))
        end))
    end,
    help=function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Uses the native Attack range check when available. Otherwise it uses LibRangeCheck's public interval to distinguish close range from beyond five yards; that estimate does not prove exact melee geometry for every target. An interval spanning the boundary, missing data or restricted data stays unavailable, including under NOT."]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/range.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/range.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
