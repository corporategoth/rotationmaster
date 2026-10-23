local _,addon=...
local platform=addon.Platform

-- Retail and Forever make UnitPower and GetComboPoints SecretWhenUnitPowerRestricted:
-- "secret values for power types not explicitly flagged as being never secret,
-- unless the subject unit does not have a power of this type". UnitPowerMax is
-- SecretWhenUnitPowerMaxRestricted: secret "when the unit isn't
-- player-controlled", per-type flags taking priority. Blizzard's generated API
-- documentation (Gethe/wow-ui-source, Blizzard_APIDocumentationGenerated:
-- UnitDocumentation.lua, SecretPredicatesDocumentation.lua) at live
-- e7aa82019dc298e0351c7159d60c2a9b916b9b67 (12.1.5.70529) and forever
-- ca8368f2f2380cbe696854f7f2646387c278a61b (1.60.1.70532); the annotations and
-- predicates are identical on both. The per-type flag is client data
-- (C_Secrets.GetPowerTypeSecrecy), not documentation. Blizzard named the
-- player's secondary resources it no longer makes secret (12.0.0 beta, compiled
-- on warcraft.wiki.gg Patch_12.0.0/Planned_API_changes): Combo Points, Runes,
-- Soul Shards, Holy Power, Chi, Arcane Charges and Essence; primary resources
-- stay secret, and GetComboPoints follows the combo-point rule. Under the
-- restricted policy POINT reads only these types, by Enum name, and every
-- value still passes CanReadValue: a secret one is unavailable, never a number.
local neverSecretPointPowers={'ComboPoints','Runes','SoulShards','HolyPower','Chi','ArcaneCharges','Essence'}
function platform:IsNeverSecretPointPower(powerType)
    if not self:CanReadValue(powerType) then return false end
    if canaccessvalue and not canaccessvalue(powerType) then return false end
    if type(powerType)~='number' then return false end
    local enum=Enum
    if not self:CanReadValue(enum) or type(enum)~='table' then return false end
    local types=rawget(enum,'PowerType')
    if not self:CanReadValue(types) or type(types)~='table' then return false end
    for _,name in ipairs(neverSecretPointPowers) do
        local id=rawget(types,name)
        if self:CanReadValue(id) and (not canaccessvalue or canaccessvalue(id)) and type(id)=='number' and id==powerType then return true end
    end
    return false
end

-- POINT has its own explicit secondary-resource selection policy. These reads
-- neither choose the primary power bar nor redirect the configured unit.
-- Identity is guarded value by value, so the restricted policy reads it too.
function platform:GetUnitPointIdentityObservation(unit,includeClass)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(includeClass) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(includeClass)~='boolean' then return nil,'invalid-point-identity-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOK,exists=pcall(UnitExists,unit)
    if not existsOK then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    if not includeClass then return {exists=true} end
    if type(UnitClass)~='function' then return nil,'missing-api' end
    local ok,_,class=pcall(UnitClass,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(class) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(class) then return nil,'restricted-value' end
    if class==nil then return nil,'point-class-unavailable' end
    if type(class)~='string' or class=='' then return nil,'invalid-api-result' end
    return {exists=true,class=class}
end

-- Burning Embers (Destruction Warlock, Mists of Pandaria Classic) are one
-- power read in fragments. Blizzard's 5.5.4 ember bar reads
-- UnitPower/UnitPowerMax("player", Enum.PowerType.BurningEmbers, true) and
-- fills one ember per MAX_POWER_PER_EMBER = 10 fragments (Gethe/wow-ui-source
-- classic 45eb466ddb, Blizzard_UnitFrame/Mists/ShardBar.lua and
-- Blizzard_FrameXMLBase/Classic/Constants.lua). Without the flag the client
-- returns whole embers only. POINT reports embers with their fraction: 35
-- fragments are 3.5 embers, so "at least 3.5" and "one whole ember" are both
-- expressible. The divisor is Blizzard's constant, not a global an addon may
-- have replaced. The type is captured at load on progression clients only, so
-- every other client keeps its exact reads.
local pointFragmentsPerWhole=10
local pointFragmentType
do
    local project=WOW_PROJECT_ID
    if type(project)=='number' and (project==WOW_PROJECT_MISTS_CLASSIC or project==WOW_PROJECT_CATACLYSM_CLASSIC or project==WOW_PROJECT_WRATH_CLASSIC) then
        local enum=Enum
        if platform:CanReadValue(enum) and type(enum)=='table' then
            local types=rawget(enum,'PowerType')
            if platform:CanReadValue(types) and type(types)=='table' then
                local id=rawget(types,'BurningEmbers')
                if platform:CanReadValue(id) and type(id)=='number' and id>=0 and id%1==0 and id<math.huge then pointFragmentType=id end
            end
        end
    end
end
function platform:GetUnitPointFragmentObservation(unit,powerType,kind)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    local api
    if kind=='current' then api=UnitPower else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result=pcall(api,unit,powerType,true)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result/pointFragmentsPerWhole
end

function platform:GetUnitPointPowerObservation(unit,powerType,kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and (policy~='restricted' or not self:IsNeverSecretPointPower(powerType)) then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    if powerType==pointFragmentType then return self:GetUnitPointFragmentObservation(unit,powerType,kind) end
    local api
    if kind=='current' then api=UnitPower else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result=pcall(api,unit,powerType)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- Explicit player/target combo transport. Other units/resources use the observer above.
function platform:GetPlayerComboPointObservation(powerType,kind)
    local info=self:GetClientInfo()
    if info.combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    local family
    if self:CanReadValue(info) and type(info)=='table' then family=rawget(info,'family') end
    if not self:CanReadValue(family) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(family) then return nil,'restricted-value' end
    if family~='tbc' then return nil,'unsupported-point-transport' end
    if not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    local api
    if kind=='current' then api=GetComboPoints else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result
    if kind=='current' then ok,result=pcall(api,'player','target') else ok,result=pcall(api,'player',powerType) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerComboPointObservation" then return addon.Platform.GetPlayerComboPointObservation end
        if name=="Platform_GetUnitPointFragmentObservation" then return addon.Platform.GetUnitPointFragmentObservation end
        if name=="Platform_GetUnitPointIdentityObservation" then return addon.Platform.GetUnitPointIdentityObservation end
        if name=="Platform_GetUnitPointPowerObservation" then return addon.Platform.GetUnitPointPowerObservation end
        if name=="pointFragmentType" then return pointFragmentType end
        if name=="pointFragmentsPerWhole" then return pointFragmentsPerWhole end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/points.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/points.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
