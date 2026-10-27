-- Platform adapter for the player's threat status against a unit (UnitExists, UnitIsEnemy, UnitThreatSituation).
-- Returns `status, nil`, `false` for known absence, non-enemy or no threat, or `nil, reason`; game values pass
-- platform:CanReadValue first. Only the probe and restricted combat-data policies read. Loaded from RotationMaster.toc
-- after Platform/pet.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Preserve the ordered native threat predicate, including optional nil status.
-- False is known absence/nonenemy/no-threat; unavailable required facts are nil.
-- On success returns the numeric UnitThreatSituation("player", unit) status (0 to 3).
function platform:GetUnitThreatObservation(unit)
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
    if type(UnitIsEnemy)~='function' then return nil,'missing-api' end
    local enemyOk,enemy=pcall(UnitIsEnemy,'player',unit)
    if not enemyOk then return nil,'api-error' end
    if not self:CanReadValue(enemy) then return nil,'restricted-value' end
    if enemy==nil then return nil,'unit-data-unavailable' end
    if type(enemy)~='boolean' then return nil,'invalid-api-result' end
    if not enemy then return false end
    if type(UnitThreatSituation)~='function' then return nil,'missing-api' end
    local threatOk,threat=pcall(UnitThreatSituation,'player',unit)
    if not threatOk then return nil,'api-error' end
    if not self:CanReadValue(threat) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(threat) then return nil,'restricted-value' end
    if threat==nil then return false end
    if type(threat)~='number' or threat~=threat or threat==math.huge or threat==-math.huge then return nil,'invalid-api-result' end
    return threat
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitThreatObservation" then return addon.Platform.GetUnitThreatObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/threat.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/threat.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
