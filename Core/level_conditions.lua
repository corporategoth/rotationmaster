-- Unit level reader for the LEVEL condition (Conditions/character.lua). Owns addon:GetConditionUnitLevel, which returns
-- a unit's level, false when the unit does not exist, or nil and a reason; it draws nothing and holds no saved data.
-- Loaded from the Core condition-service group of RotationMaster.toc, after Core/condition_runtime.lua, whose
-- DeclareConditionRuntimeHelper it calls so the Built In LEVEL condition can prove its helper is the shipped one. The
-- level comes from Platform:GetUnitLevelObservation and passes platform:CanReadValue first (restricted clients). The
-- function body is frozen: saved custom conditions bind to its exact text, and the generated block at the end of the
-- file is rewritten by tools/generate_builtin_sources.py.
local _, addon = ...

-- Reads a unit's level for the LEVEL condition.
-- @param unit string  The unit token to read (non-empty).
-- @param cache table|nil  The per-pass evaluation cache; nil reads uncached.
-- @return number|boolean|nil  The unit's level; false when the unit does not exist; nil when the level is unavailable.
-- @return string|nil  The reason code when the first return is nil (restricted-value, invalid-unit, unsupported-client,
--   invalid-api-result, or the platform's own reason); nil otherwise.
--
-- Keeps the old player-level lifetime, but only promotes a valid observation. Unknown/absent observations live in the
-- evaluation cache and retry next pass.
function addon:GetConditionUnitLevel(unit, cache)
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

-- Enrolls the helper with the condition runtime; skipped when the condition runtime is not loaded.
if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('GetConditionUnitLevel', addon.GetConditionUnitLevel)
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
