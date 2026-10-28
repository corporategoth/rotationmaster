-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for "can the player attack this unit" (UnitExists, UnitCanAttack, UnitIsDead). Returns
-- `true/false, nil` or `nil, reason`; game values pass platform:CanReadValue first. Only the probe and restricted
-- combat-data policies read. Loaded from RotationMaster.toc after Platform/player_movement.lua; consumed by the
-- attackable condition in Conditions/combat.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; readClientPolicy and the
-- reader are Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- Reads the combat data policy of the client.
-- @param current table  The platform table whose client info is read.
-- @return string  The policy name: "probe", "restricted" or another value for an unsupported client.
--
-- Replaced just below by the allocation-free reader that Platform/client.lua hands over.
local function readClientPolicy(current)
    return current:GetClientInfo().combatDataPolicy
end

-- Takes the private client-policy reader from addon:ConsumeClientPolicyReader (Platform/client.lua), which hands it to
-- the addon table alone; buttons.lua removes that method once the consumers have loaded.
---@type fun(...): any
local consumeClientPolicy = addon.ConsumeClientPolicyReader

if type(consumeClientPolicy) == 'function' then
    readClientPolicy = consumeClientPolicy(addon)
end

-- Reads whether the player can attack a unit (UnitExists, UnitCanAttack, UnitIsDead).
-- @param unit string  The unit token to read; must be a non-empty string.
-- @return boolean|nil  False for an absent or unattackable unit, otherwise true when the unit is alive (false when it
--   is dead); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Attackability keeps the native player attacker and selected unit. A known false at either early stage needs no
-- later fact; unknown data cannot match.
function platform:GetUnitAttackabilityObservation(unit)
    local policy=readClientPolicy(self)
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
