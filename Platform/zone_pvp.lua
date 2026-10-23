local _,addon=...
local platform=addon.Platform

-- Successful empty zone classification differs from an unavailable observation.
function platform:GetZonePVPObservation()
    local family=self:GetClientFamily()
    if family~='retail' and family~='forever' and family~='era' and family~='tbc' and family~='progression' then return nil,'unsupported-policy' end
    local namespace=C_PvP
    if not self:CanReadValue(namespace) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(namespace) then return nil,'restricted-value' end
    local api
    if type(namespace)=='table' then api=namespace.GetZonePVPInfo end
    if not self:CanReadValue(api) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(api) then return nil,'restricted-value' end
    if type(api)~='function' then
        api=GetZonePVPInfo
        if not self:CanReadValue(api) then return nil,'restricted-value' end
        if canaccessvalue and not canaccessvalue(api) then return nil,'restricted-value' end
        if type(api)~='function' then return nil,'missing-api' end
    end
    local ok,pvpType=pcall(api)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(pvpType) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(pvpType) then return nil,'restricted-value' end
    if pvpType==nil then return {} end
    if type(pvpType)~='string' then return nil,'invalid-api-result' end
    return {pvpType=pvpType}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetZonePVPObservation" then return addon.Platform.GetZonePVPObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/zone_pvp.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/zone_pvp.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
