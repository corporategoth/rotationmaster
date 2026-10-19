local _,addon=...
local platform=addon.Platform

-- Keep the native numeric observation unchanged; form labels and configured
-- class-dependent bounds belong to the authored condition and its Fields UI.
function platform:GetPlayerFormObservation()
    if self:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if type(GetShapeshiftForm)~='function' then return nil,'missing-api' end
    local ok,result=pcall(GetShapeshiftForm)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'form-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerFormObservation" then return addon.Platform.GetPlayerFormObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/form.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/form.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
