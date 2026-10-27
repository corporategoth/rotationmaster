-- Platform adapter for the player's pet: UnitExists("pet") and, on request, GetUnitName("pet").
-- Owns platform:GetPetObservation (the `value or nil, reason` reader); it must not decide what a pet means for a
-- rotation. Runs under the probe and restricted policies. The reader is a Built In helper whose body is recorded in
-- the generated block at the end of the file and must keep its exact text.
-- Loaded from RotationMaster.toc after Platform/unit_presence.lua.
local _, addon = ...
local platform = addon.Platform

-- Presence and display-name availability are independent requested facts.
-- Keep the existing GetUnitName wrapper and its omitted optional argument.
-- Returns { exists = boolean, name = string or nil }; name is read only when includeName is true and the pet exists.
-- Returns nil and a reason code when presence, or a requested name, cannot be read.
function platform:GetPetObservation(includeName)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(includeName) then return nil,'restricted-value' end
    if includeName~=nil and type(includeName)~='boolean' then return nil,'invalid-pet-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,'pet')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'pet-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    local record={exists=exists}
    if not exists or not includeName then return record end
    if type(GetUnitName)~='function' then return nil,'missing-api' end
    local nameOk,name=pcall(GetUnitName,'pet')
    if not nameOk then return nil,'api-error' end
    if not self:CanReadValue(name) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(name) then return nil,'restricted-value' end
    if name==nil then return nil,'pet-name-unavailable' end
    if type(name)~='string' or name=='' then return nil,'invalid-api-result' end
    record.name=name
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPetObservation" then return addon.Platform.GetPetObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/pet.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/pet.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
