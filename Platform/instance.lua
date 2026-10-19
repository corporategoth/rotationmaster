local _,addon=...
local platform=addon.Platform

-- One public world-state tuple; membership and type have independent readiness.
function platform:GetInstanceObservation()
    local family=self:GetClientInfo().family
    if family~='retail' and family~='forever' and family~='era' and family~='tbc' and family~='progression' then return nil,'unsupported-policy' end
    if type(IsInInstance)~='function' then return nil,'missing-api' end
    local ok,inInstance,instanceType=pcall(IsInInstance)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(inInstance) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(inInstance) then return nil,'restricted-value' end
    if inInstance==nil then return nil,'instance-data-unavailable' end
    if type(inInstance)~='boolean' then return nil,'invalid-api-result' end
    if not inInstance then return {inInstance=false} end
    if not self:CanReadValue(instanceType) then return {inInstance=true,instanceTypeReason='restricted-value'} end
    if canaccessvalue and not canaccessvalue(instanceType) then return {inInstance=true,instanceTypeReason='restricted-value'} end
    if instanceType==nil then return {inInstance=true,instanceTypeReason='instance-type-unavailable'} end
    if type(instanceType)~='string' then return {inInstance=true,instanceTypeReason='invalid-api-result'} end
    return {inInstance=true,instanceType=instanceType}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetInstanceObservation" then return addon.Platform.GetInstanceObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/instance.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/instance.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
