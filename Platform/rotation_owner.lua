local _, addon = ...
local platform = addon.Platform

-- Ownership needs a fresh public player class token, not eligibility facts.
-- Consume only UnitClass's second return and leave its other fields alone.
function platform:GetPlayerOwnerClassObservation()
    if type(UnitClass)~='function' then return nil,'missing-api' end
    local ok,_,class=pcall(UnitClass,'player')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(class) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(class) then return nil,'restricted-value' end
    if class==nil then return nil,'class-data-unavailable' end
    if type(class)~='string' or class=='' then return nil,'invalid-api-result' end
    return class
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerOwnerClassObservation" then return addon.Platform.GetPlayerOwnerClassObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/rotation_owner.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/rotation_owner.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
