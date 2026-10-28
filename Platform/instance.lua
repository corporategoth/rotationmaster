-- Platform adapter for IsInInstance: whether the player is inside an instance, and of which type.
-- Owns the `value or nil, reason` reader platform:GetInstanceObservation; it must not interpret the type (party, raid,
-- pvp) for a rotation. Supported on every known client family; "unknown" is refused. GetInstanceObservation is a Built
-- In helper whose body is recorded in the generated block at the end of the file and must keep its exact text.
-- Loaded from RotationMaster.toc after Platform/threat.lua; needs Platform/client.lua for CanReadValue.
local _, addon = ...
local platform = addon.Platform

-- Reads whether the player is inside an instance and, when so, which type of instance.
-- @return table{inInstance=boolean,instanceType=string|nil,instanceTypeReason=string|nil}|nil  The observation:
--   { inInstance = false }, or { inInstance = true } carrying either instanceType or instanceTypeReason when the type
--   alone is unreadable; nil when membership itself cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- One public world-state tuple (IsInInstance); membership and type have independent readiness.
function platform:GetInstanceObservation()
    local family=self:GetClientFamily()
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
