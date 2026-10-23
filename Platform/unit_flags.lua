local _,addon=...
local platform=addon.Platform
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end

-- Closed flag kinds preserve the existing native query and selected unit.
-- Only readable false existence establishes absence; required unknowns do not.
function platform:GetUnitFlagObservation(unit,kind)
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
