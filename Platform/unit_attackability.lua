local _,addon=...
local platform=addon.Platform
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end

-- Attackability keeps the native player attacker and selected unit. A known
-- false at either early stage needs no later fact; unknown data cannot match.
function platform:GetUnitAttackabilityObservation(unit)
    if readClientPolicy(self)~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    if type(UnitCanAttack)~='function' then return nil,'missing-api' end
    local attackOk,attack=pcall(UnitCanAttack,'player',unit)
    if not attackOk then return nil,'api-error' end
    if not self:CanReadValue(attack) then return nil,'restricted-value' end
    if attack==nil then return nil,'attackability-data-unavailable' end
    if type(attack)~='boolean' then return nil,'invalid-api-result' end
    if not attack then return false end
    if type(UnitIsDead)~='function' then return nil,'missing-api' end
    local deadOk,dead=pcall(UnitIsDead,unit)
    if not deadOk then return nil,'api-error' end
    if not self:CanReadValue(dead) then return nil,'restricted-value' end
    if dead==nil then return nil,'death-data-unavailable' end
    if type(dead)~='boolean' then return nil,'invalid-api-result' end
    return not dead
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitAttackabilityObservation" then return addon.Platform.GetUnitAttackabilityObservation end
        if name=="readClientPolicy" then return readClientPolicy end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_attackability.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_attackability.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
