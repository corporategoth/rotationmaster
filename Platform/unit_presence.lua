local _,addon=...
local platform=addon.Platform

-- Public presence is independent of enemy-combat observation policy. Only a
-- readable Boolean false establishes absence; no additional unit facts apply.
function platform:GetUnitPresenceObservation(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    return exists
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitPresenceObservation" then return addon.Platform.GetUnitPresenceObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_presence.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_presence.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
