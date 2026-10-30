-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for distance questions: native spell range (C_Spell.IsSpellInRange / IsSpellInRange with the
-- Attack spell), the nameplateMaxDistance CVar, and the optional LibRangeCheck-3.0 library as a fallback. Readers
-- return `value, nil` or `nil, reason`; game values pass platform:CanReadValue first. Must not claim an exact
-- distance from an interval or treat a missing result as "outside". Loaded from RotationMaster.toc near the end of
-- the Platform group.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the two published readers
-- are Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- Decides whether a unit is beyond melee range.
-- @param unit string  The unit token to test; must be a non-empty string.
-- @return boolean|nil  True when the unit is beyond melee range, false when within it; nil when it cannot be decided.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
-- @return string|nil  The source used when decided: "native-attack-range" or "estimated-five-yard-range".
--
-- Native Attack range, when the client supports that query, includes the game's melee geometry. An invalid nil result
-- may use a conservative public estimate from LibRangeCheck.
function platform:IsBeyondMeleeRange(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil, "invalid-unit"
    end

    local fn, spell

    if C_Spell and type(C_Spell.IsSpellInRange) == "function" then
        fn, spell = C_Spell.IsSpellInRange, 6603
    elseif type(IsSpellInRange) == "function" then
        local info, why = self:GetSpellInfo(6603)

        if info then
            fn, spell = IsSpellInRange, info.name
        elseif why == "restricted-value" or why == "api-error" then
            return nil, why
        end
    end

    if fn then
        local ok, inRange = pcall(fn, spell, unit)

        if not ok then
            return nil, "api-error"
        end
        if not self:CanReadValue(inRange) then
            return nil, "restricted-value"
        end
        if inRange == true or inRange == 1 then
            return false, nil, "native-attack-range"
        end
        if inRange == false or inRange == 0 then
            return true, nil, "native-attack-range"
        end
        if inRange ~= nil then
            return nil, "invalid-api-result"
        end
    end

    if not LibStub then
        return nil, "missing-range-provider"
    end

    local loaded, provider = pcall(function() return LibStub("LibRangeCheck-3.0", true) end)

    if not loaded or not provider or type(provider.GetRange) ~= "function" then
        return nil, "missing-range-provider"
    end

    local ok, minimum, maximum = pcall(provider.GetRange, provider, unit, true)

    if not ok then
        return nil, "range-provider-error"
    end

    for _, value in pairs({ min = minimum, max = maximum }) do
        if not self:CanReadValue(value) then
            return nil, "restricted-value"
        end
        if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
            return nil, "invalid-range-result"
        end
    end

    if minimum == nil and maximum == nil then
        return nil, "range-unavailable"
    end
    if minimum and maximum and minimum > maximum then
        return nil, "invalid-range-result"
    end

    -- These are intervals rather than exact distances. A failed five-yard check
    -- yields a lower bound of five; an interval spanning it stays unavailable.
    if maximum and maximum <= 5 then
        return false, nil, "estimated-five-yard-range"
    end
    if minimum and minimum >= 5 then
        return true, nil, "estimated-five-yard-range"
    end

    return nil, "range-uncertain"
end

-- Reads the nameplateMaxDistance CVar.
-- @return number|nil  The distance in yards, a positive number; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- This setting limits nameplate visibility, not the completeness of any scan.
function platform:GetNameplateMaxDistance()
    local query=C_CVar and C_CVar.GetCVar or GetCVar
    if type(query)~='function' then return nil,'missing-api' end
    local ok,value=pcall(query,'nameplateMaxDistance')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if type(value)~='string' and type(value)~='number' then return nil,'nameplate-distance-unavailable' end
    local maximum=tonumber(value)
    if not maximum or maximum~=maximum or maximum<=0 or maximum==math.huge then return nil,'nameplate-distance-unavailable' end
    return maximum
end

-- Reads the LibRangeCheck distance interval for a unit.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @return table|nil  { minimum = number|nil, maximum = number|nil } with at least one bound present; nil when it
--   cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Public LibRangeCheck intervals retain their bounds. Never invent an exact distance from either bound or turn an
-- absent result into an outside result.
function platform:GetRangeCheckBounds(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if not LibStub then return nil,'missing-range-provider' end
    local loaded,provider=pcall(function() return LibStub('LibRangeCheck-3.0',true) end)
    if not loaded or not provider or type(provider.GetRange)~='function' then return nil,'missing-range-provider' end
    local ok,minimum,maximum=pcall(provider.GetRange,provider,unit)
    if not ok then return nil,'range-provider-error' end
    if not self:CanReadValue(minimum) or not self:CanReadValue(maximum) then return nil,'restricted-value' end
    for _,bound in pairs({minimum=minimum,maximum=maximum}) do
        if type(bound)~='number' or bound~=bound or bound<0 or bound==math.huge then return nil,'invalid-range-result' end
    end
    if minimum==nil and maximum==nil then return nil,'range-unavailable' end
    if minimum and maximum and minimum>maximum then return nil,'invalid-range-result' end
    return {minimum=minimum,maximum=maximum}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetNameplateMaxDistance" then return addon.Platform.GetNameplateMaxDistance end
        if name=="Platform_GetRangeCheckBounds" then return addon.Platform.GetRangeCheckBounds end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/range.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/range.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
