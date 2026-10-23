local _,addon=...
local platform=addon.Platform

-- Identity is native return two, independent of the localized caption in one.
function platform:GetUnitCreatureTypeID(unit)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    local native=UnitCreatureType
    if type(native)~='function' then return nil,'missing-api' end
    local observed,_,id=pcall(native,unit)
    if not observed then return nil,'api-error' end
    if not self:CanReadValue(id) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(id) then return nil,'restricted-value' end
    if id==nil then return nil,'unit-creature-type-unavailable' end
    if type(id)~='number' or id~=id or id==math.huge or id==-math.huge then return nil,'invalid-api-result' end
    return id
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitCreatureTypeID" then return addon.Platform.GetUnitCreatureTypeID end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/creature_type.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/creature_type.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
