-- The unit dropdown widget that Built In condition editors share (Conditions/*.lua call addon:Widget_UnitWidget).
-- Owns only the dropdown that edits one unit field of a condition's saved table; it does not read game state.
-- Loaded from the UI section of RotationMaster.toc after UI/condition_inputs.lua, before any Conditions/ file runs.
-- The widget is recorded as a Built In helper (see the generated bindings block at the end of the file), so the body
-- of Widget_UnitWidget is frozen: saved custom copies hash its exact text. Do not edit inside it.

local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Builds a condition dropdown that edits value[field] (default "unit") from the choice table units, and returns it.
-- When the owning window is an announcement editor (or the value already holds "announcementtarget") the list gains
-- an "Announcement target" choice. The list is rebuilt by unit.configure each time the editor lays the widget out.
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
