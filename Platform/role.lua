-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for unit and talent-group roles: GetInspectSpecialization (C_SpecializationInfo first, global as
-- fallback), GetSpecializationInfoByID and the legacy GetTalentGroupRole. Readers return `value, nil` or
-- `nil, reason`, never issue an inspection request and never infer a role; every game value passes
-- platform:CanReadValue first. Loaded from RotationMaster.toc after Platform/roster_class.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; everything in this file is
-- referenced from it (readField, roleValue and both readers), so every function body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Returns object[key] read under pcall, or nil and a reason when object is restricted, not a table, the read throws or
-- the value is restricted. A missing key is a readable nil, not an error.
local function readField(self, object, key)
    if not self:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-api-result' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- Validates a role result: returns the readable non-empty string unchanged, or nil and a reason. Unknown future role
-- strings are passed through rather than matched against TANK/HEALER/DAMAGER.
local function roleValue(self, value)
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(value) then return nil,'restricted-value' end
    if value==nil then return nil,'role-unavailable' end
    if type(value)~='string' or value=='' then return nil,'invalid-api-result' end
    return value
end

-- No inspection requests or inferred roles. A chosen modern capability's
-- failure never falls through to the legacy global capability.
-- Returns the role string for the unit's inspected specialization, false when the unit does not exist, or nil and a
-- reason. Works on probe and restricted policies only.
function platform:GetInspectRoleObservation(unit)
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
    local namespace,reason=readField(self,_G,'C_SpecializationInfo')
    if reason then return nil,reason end
    local inspect
    if namespace~=nil then
        inspect,reason=readField(self,namespace,'GetInspectSpecialization')
        if reason then return nil,reason end
    end
    if type(inspect)~='function' then
        inspect,reason=readField(self,_G,'GetInspectSpecialization')
        if reason then return nil,reason end
    end
    if type(inspect)~='function' then return nil,'missing-api' end
    local ok,spec=pcall(inspect,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(spec) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(spec) then return nil,'restricted-value' end
    if spec==nil or spec==0 then return nil,'specialization-unavailable' end
    if type(spec)~='number' or spec~=spec or spec>=math.huge or spec<=0 or spec%1~=0 then return nil,'invalid-api-result' end
    local metadata
    metadata,reason=readField(self,_G,'GetSpecializationInfoByID')
    if reason then return nil,reason end
    if type(metadata)~='function' then return nil,'missing-api' end
    local roleOk,role=pcall(function() return (select(5,metadata(spec))) end)
    if not roleOk then return nil,'api-error' end
    return roleValue(self,role)
end

-- Keep the live legacy group argument exactly, including readable nil. Its
-- historical declaration is incomplete; no group-domain inference is added.
-- Returns the first result of GetTalentGroupRole(group) as a role string, or nil and a reason.
function platform:GetTalentGroupRoleObservation(group)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(group) then return nil,'restricted-value' end
    local query,reason=readField(self,_G,'GetTalentGroupRole')
    if reason then return nil,reason end
    if type(query)~='function' then return nil,'missing-api' end
    local ok,role=pcall(query,group)
    if not ok then return nil,'api-error' end
    return roleValue(self,role)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetInspectRoleObservation" then return addon.Platform.GetInspectRoleObservation end
        if name=="Platform_GetTalentGroupRoleObservation" then return addon.Platform.GetTalentGroupRoleObservation end
        if name=="readField" then return readField end
        if name=="roleValue" then return roleValue end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/role.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/role.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
