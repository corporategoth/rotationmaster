-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for GetUnitSpeed("player"): how fast the player is currently moving.
-- Owns platform:GetPlayerMovementObservation (the `value or nil, reason` reader); it must not decide what counts as
-- "moving" for a rotation. Runs under the probe and restricted policies. The reader is a Built In helper whose body
-- is recorded in the generated block at the end of the file and must keep its exact text.
-- Loaded from RotationMaster.toc after Platform/unit_power.lua.
local _, addon = ...
local platform = addon.Platform

-- Reads how fast the player is currently moving (GetUnitSpeed("player")).
-- @return table{speed=number}|nil  The observation, with speed in yards per second (never negative); nil when the
--   speed is missing, secret, not a finite number or negative.
-- @return string|nil  The reason code when the first return is nil; nil on success.
function platform:GetPlayerMovementObservation()
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if type(GetUnitSpeed)~='function' then return nil,'missing-api' end
    local ok,speed=pcall(GetUnitSpeed,'player')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(speed) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(speed) then return nil,'restricted-value' end
    if speed==nil then return nil,'movement-data-unavailable' end
    if type(speed)~='number' or speed~=speed or speed==math.huge or speed==-math.huge or speed<0 then return nil,'invalid-api-result' end
    return {speed=speed}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerMovementObservation" then return addon.Platform.GetPlayerMovementObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/player_movement.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/player_movement.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
