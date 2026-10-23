local _,addon=...
local platform=addon.Platform

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
