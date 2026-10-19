local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

function addon:Widget_UnitWidget(value, units, update, field)
    if field == nil then
        field = "unit"
    end
    local unit = addon:CreateConditionDropdown()
    unit:SetLabel(L["Unit"])
    unit:SetCallback("OnValueChanged", function(_, _, v)
        value[field] = v
        update()
    end)
    unit:SetDisabled(value.disabled)
    unit.configure = function()
        unit:SetList(units, addon.keys(units))
        unit:SetValue(value[field])
    end

    return unit
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Widget_UnitWidget" then return addon.Widget_UnitWidget end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_unit.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_unit.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
