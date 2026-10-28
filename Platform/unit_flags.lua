-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for three Boolean unit flags: in combat (UnitAffectingCombat), enemy of the player (UnitIsEnemy)
-- and PvP flagged (UnitIsPVP), selected by a closed `kind`. Returns `boolean, nil` or `nil, reason`; game values pass
-- platform:CanReadValue first. Only the probe and restricted combat-data policies read. Loaded from
-- RotationMaster.toc after Platform/unit_attackability.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; readClientPolicy and the
-- reader are Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- Returns the combat data policy ("probe", "restricted" or other) for the platform; replaced just below by the
-- allocation-free reader that Platform/client.lua hands over.
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

-- Closed flag kinds preserve the existing native query and selected unit.
-- Only readable false existence establishes absence; required unknowns do not.
-- kind is "combat", "enemy" or "pvp". Returns the flag, false for a unit that does not exist, or nil and a reason.
function platform:GetUnitFlagObservation(unit, kind)
    local policy=readClientPolicy(self)
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='combat' and kind~='enemy' and kind~='pvp' then return nil,'invalid-unit-flag-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    local api
    if kind=='combat' then api=UnitAffectingCombat
    elseif kind=='enemy' then api=UnitIsEnemy
    else api=UnitIsPVP end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result
    if kind=='enemy' then ok,result=pcall(api,'player',unit)
    else ok,result=pcall(api,unit) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'unit-flag-unavailable' end
    if type(result)~='boolean' then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitFlagObservation" then return addon.Platform.GetUnitFlagObservation end
        if name=="readClientPolicy" then return readClientPolicy end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_flags.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_flags.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
