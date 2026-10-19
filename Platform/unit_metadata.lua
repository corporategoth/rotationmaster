local _,addon=...
local platform=addon.Platform

-- Keep native metadata identities: class token, localized creature name, or
-- classification token. Unused tuple fields do not determine availability.
function platform:GetUnitMetadataObservation(unit,kind)
    if self:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='class' and kind~='creature' and kind~='classification' then return nil,'invalid-unit-metadata-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    local api
    if kind=='class' then api=UnitClass
    elseif kind=='creature' then api=UnitCreatureType
    else api=UnitClassification end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,observed
    if kind=='class' then ok,observed=pcall(function() return select(2,api(unit)) end)
    else ok,observed=pcall(api,unit) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(observed) then return nil,'restricted-value' end
    if observed==nil then return nil,'unit-metadata-unavailable' end
    if type(observed)~='string' or observed=='' then return nil,'invalid-api-result' end
    return observed
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitMetadataObservation" then return addon.Platform.GetUnitMetadataObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_metadata.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_metadata.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
