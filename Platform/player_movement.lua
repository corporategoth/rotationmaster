-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for GetUnitSpeed("player"): how fast the player is currently moving, falling back to the movement
-- events while the client hides the speed.
-- Owns platform:GetPlayerMovementObservation (the `value or nil, reason` reader); it must not decide what counts as
-- "moving" for a rotation. Runs under the probe and restricted policies. The reader is a Built In helper: its body is
-- recorded in Data/builtin_sources.lua, so run tools/generate_builtin_sources.py --write after changing it.
-- Loaded from RotationMaster.toc after Platform/unit_power.lua.
local _, addon = ...
local platform = addon.Platform

-- Whether the player is moving, from PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING and from the last readable speed.
-- Retail and Forever hide GetUnitSpeed in combat (SecretWhenUnitStatsRestricted); these events carry no secret
-- annotation and exist on every client, so the reader can still say moving or not. `speed` is the last readable
-- moving speed, reported while moving and estimated.
local movement = { known = false, moving = false, speed = 7 }

if type(CreateFrame) == 'function' then
    local events = CreateFrame('Frame')

    for _, event in ipairs({ 'PLAYER_STARTED_MOVING', 'PLAYER_STOPPED_MOVING' }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript('OnEvent', function(_, event)
        movement.known, movement.moving = true, event == 'PLAYER_STARTED_MOVING'
    end)
end

-- Reads how fast the player is currently moving (GetUnitSpeed("player")).
-- @return table{speed=number,estimated=boolean|nil}|nil  The observation, with speed in yards per second (never
--   negative); nil when the speed is missing, not a finite number or negative, or secret with no movement event or
--   readable speed seen yet. A secret speed is answered from the movement events: 0 when stopped, the last readable
--   moving speed when moving, with estimated = true.
-- @return string|nil  The reason code when the first return is nil; nil on success.
function platform:GetPlayerMovementObservation()
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if type(GetUnitSpeed)~='function' then return nil,'missing-api' end
    local ok,speed=pcall(GetUnitSpeed,'player')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(speed) or canaccessvalue and not canaccessvalue(speed) then
        if movement.known then return {speed=movement.moving and movement.speed or 0,estimated=true} end
        return nil,'restricted-value'
    end
    if speed==nil then return nil,'movement-data-unavailable' end
    if type(speed)~='number' or speed~=speed or speed==math.huge or speed==-math.huge or speed<0 then return nil,'invalid-api-result' end
    movement.known,movement.moving=true,speed>0
    if speed>0 then movement.speed=speed end
    return {speed=speed}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerMovementObservation" then return addon.Platform.GetPlayerMovementObservation end
        if name=="movement" then return movement end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/player_movement.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/player_movement.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
