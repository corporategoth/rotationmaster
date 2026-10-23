local _,addon=...

-- Keep the old player-level lifetime, but only promote a valid observation.
-- Unknown/absent observations live in the evaluation cache and retry next pass.
function addon:GetConditionUnitLevel(unit,cache)
    if not self.Platform:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if self.Platform:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
    local longterm=self.longtermCache
    if unit=='player' and type(longterm)=='table' then
        local level=longterm.conditionPlayerLevel
        if not self.Platform:CanReadValue(level) then return nil,'restricted-value' end
        if level~=nil then
            if type(level)~='number' or level~=level or level<=0 or level==math.huge or level%1~=0 then return nil,'invalid-api-result' end
            return level
        end
    end
    local record,reason=addon.Functions.cache.getCached(cache,self.Platform.GetUnitLevelObservation,self.Platform,unit)
    if not record then return nil,reason end
    if not record.exists then return false end
    if unit=='player' and type(longterm)=='table' then longterm.conditionPlayerLevel=record.level end
    return record.level
end

if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('GetConditionUnitLevel',addon.GetConditionUnitLevel)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetConditionUnitLevel" then return addon.GetConditionUnitLevel end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/level_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/level_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
