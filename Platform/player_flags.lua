-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for three zero-argument player predicates: IsStealthed, HasFullControl and IsOutdoors.
-- Owns platform:GetPlayerFlagObservation (the `value or nil, reason` reader); it must not combine the flags or
-- infer anything from them. Runs under the probe and restricted policies. The reader is a Built In helper whose body
-- is recorded in the generated block at the end of the file and must keep its exact text.
-- Loaded from RotationMaster.toc after Platform/unit_states.lua.
local _, addon = ...
local platform = addon.Platform

-- These predicates are independent, zero-argument observations of the player.
-- Keep their native facts distinct from existence, instances or spell usability.
-- kind is "stealthed", "control" or "outdoors"; returns the boolean answer, or nil and a reason code.
function platform:GetPlayerFlagObservation(kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(kind) then return nil,'restricted-value' end
    if kind~='stealthed' and kind~='control' and kind~='outdoors' then return nil,'invalid-player-flag-query' end
    local api
    if kind=='stealthed' then api=IsStealthed
    elseif kind=='control' then api=HasFullControl
    else api=IsOutdoors end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result=pcall(api)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'player-flag-unavailable' end
    if type(result)~='boolean' then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerFlagObservation" then return addon.Platform.GetPlayerFlagObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/player_flags.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/player_flags.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
