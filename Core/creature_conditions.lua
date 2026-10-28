-- Creature-type matching for the Built In creature type condition (Conditions/character.lua calls it).
-- Owns the key-to-creature-type-id map and the platform read; it holds no state and must not cache anything itself.
-- Loaded from RotationMaster.toc between Core/class_group_conditions.lua and Core/health_forecast_conditions.lua.
-- The functions here are Built In helpers that saved custom conditions bind to by text: do not edit a function body.
-- Reads game data, so it goes through platform:CanReadValue. The block at the end is generated; never hand-edit it.

local _, addon = ...

-- Maps a stored creature-type key to the numeric creature type id the client reports.
-- @param key string  The stored creature-type key (for example 'BEAST').
-- @return number|nil  The creature type id; nil for an unknown key.
--
-- Existing stored keys retain their identities, including GAS_CLUUD's spelling. This is one executable map; no mutable
-- caption table enters gameplay matching.
local function configuredID(key)
    if key=='BEAST' then return 1
    elseif key=='DRAGONKIN' then return 2
    elseif key=='DEMON' then return 3
    elseif key=='ELEMENTAL' then return 4
    elseif key=='GIANT' then return 5
    elseif key=='UNDEAD' then return 6
    elseif key=='HUMANOID' then return 7
    elseif key=='CRITTER' then return 8
    elseif key=='MECHANICAL' then return 9
    elseif key=='OTHER' then return 10
    elseif key=='TOTEM' then return 11
    elseif key=='NONCOMBAT_PET' then return 12
    elseif key=='GAS_CLUUD' then return 13 end
end

-- Answers whether the unit's creature type is the one selected by a stored key.
-- @param unit string  The unit token to inspect (non-empty).
-- @param key string  The stored creature-type key.
-- @param cache table|nil  The per-pass evaluation cache; nil reads uncached.
-- @return boolean|nil  True when the types match, false when they differ or the unit has no creature type; nil when the
--   answer is unavailable.
-- @return string|nil  The reason code when the first return is nil (restricted-value, invalid-unit,
--   invalid-creature-type-selection, or the platform's own reason); nil otherwise.
--
-- The unit and key are checked with CanReadValue first because a restricted client can hand back secret values.
function addon:GetConditionCreatureTypeMatch(unit, key, cache)
    if not self.Platform:CanReadValue(unit) or not self.Platform:CanReadValue(key) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(key)~='string' then return nil,'invalid-creature-type-selection' end
    local expected=configuredID(key)
    if expected==nil then return nil,'invalid-creature-type-selection' end
    local observed,reason=addon.Functions.cache.getCached(cache,self.Platform.GetUnitCreatureTypeID,self.Platform,unit)
    if observed==nil then return nil,reason end
    if observed==false then return false end
    return observed==expected
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetConditionCreatureTypeMatch" then return addon.GetConditionCreatureTypeMatch end
        if name=="configuredID" then return configuredID end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/creature_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/creature_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
