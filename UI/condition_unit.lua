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
        local choices=units
        local parent=unit.parent
        local top
        for _=1,128 do
            if not parent then break end
            top=parent:GetUserData('top')
            if top then break end
            parent=parent.parent
        end
        if field=='unit' and (value[field]=='announcementtarget' or top and top:GetUserData('announcementTarget')==true) then
            choices={};for key,label in pairs(units) do choices[key]=label end
            choices.announcementtarget=L['Announcement target']
        end
        unit:SetList(choices, addon.keys(choices))
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
