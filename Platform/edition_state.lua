-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for edition-specific mechanics: pet happiness, Stagger, Balance Eclipse and the ranged swing speed.
-- Owns the `value or nil, reason` readers over GetPetHappiness, UnitStagger, GetEclipseDirection, UnitPower and
-- UnitRangedDamage; it must not decide what any of them mean for a rotation (the conditions named below do). Each
-- reader checks the combat data policy first and reports "unsupported-policy" on a client that lacks the mechanic.
-- Loaded from RotationMaster.toc after Platform/world_state.lua; needs Platform/client.lua.
local _, addon = ...
local platform = addon.Platform

-- Mechanics that belong to particular editions, read through the platform
-- adapter for Conditions/pet_happiness.lua, Conditions/stagger.lua,
-- Conditions/eclipse.lua and the ranged swing timer in Conditions/weapon.lua.
-- Reasons are the platform's: missing-api, api-error, restricted-value,
-- invalid-api-result. A reason makes the condition unavailable (also under
-- NOT); a readable "no" is an ordinary false.
--
-- Evidence: GetPetHappiness (Classic Era, Burning Crusade, Wrath), UnitStagger
-- (documented ConditionalSecret on Retail and Forever, plain on Mists),
-- GetEclipseDirection and UnitPower(Enum.PowerType.Balance) (Wrath through
-- Mists; Blizzard_UnitFrame/Cata/EclipseBarFrame.lua in the 5.5.4 client draws
-- the Sun at the right end and the Moon at the left of its bar), UnitRangedDamage
-- (every client).

-- Whether a value is a real finite number (not NaN, not infinite).
-- @param value any  The value to test.
-- @return boolean  True for a finite number.
local function finite(value)
    return type(value) == 'number' and value == value and value < math.huge and value > -math.huge
end

-- Packs varargs with their count, so a trailing nil is not lost.
-- @param ... any  The values to pack.
-- @return table  The values in the array part, with the count in field n.
local function pack(...)
    return { n = select('#', ...), ... }
end

-- Calls a native function under pcall and packs its results.
-- @param self table  The platform table, used for its CanReadValue method.
-- @param api function|nil  The native function; a non-function is "missing-api".
-- @param ... any  The arguments passed to api.
-- @return table|nil  The packed results (the pcall flag is at index 1, the native returns follow); nil when the
--   function is missing, throws or returns any restricted value.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function call(self, api, ...)
    if type(api) ~= 'function' then
        return nil, 'missing-api'
    end

    local results = pack(pcall(api, ...))

    if not results[1] then
        return nil, 'api-error'
    end

    for index = 2, results.n do
        if not self:CanReadValue(results[index]) then
            return nil, 'restricted-value'
        end
    end

    return results
end

-- Reads the player's class token.
-- @param self table  The platform table, used for its CanReadValue method.
-- @return string|nil  The class file name (for example "DRUID"); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function playerClass(self)
    local results, reason = call(self, UnitClass, 'player')

    if not results then
        return nil, reason
    end

    local class = results[3]

    if type(class) ~= 'string' or class == '' then
        return nil, 'invalid-api-result'
    end

    return class
end

-- Reads a hunter pet's mood (GetPetHappiness).
-- @return number|false|nil  1 unhappy, 2 content or 3 happy; false when there is no hunter pet (no pet, or a pet that
--   has no happiness); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetPetHappinessObservation()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' then
        return nil, 'unsupported-policy'
    end

    local results, reason = call(self, GetPetHappiness)

    if not results then
        return nil, reason
    end

    local happiness = results[2]

    if happiness == nil then
        return false
    end
    if happiness ~= 1 and happiness ~= 2 and happiness ~= 3 then
        return nil, 'invalid-api-result'
    end

    return happiness
end

-- Reads the player's Stagger (UnitStagger).
-- @param asPercent boolean|nil  True to return the pool as a percentage of maximum health; nil or false returns the
--   damage waiting in the delayed pool.
-- @return number|nil  The damage, or the percentage; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Maximum health is secret on Retail and Forever, so the percentage is unavailable there.
function platform:GetStaggerObservation(asPercent)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(asPercent) then
        return nil, 'restricted-value'
    end

    local results, reason = call(self, UnitStagger, 'player')

    if not results then
        return nil, reason
    end

    local amount = results[2]

    if amount == nil then
        amount = 0
    end

    if not finite(amount) or amount < 0 then
        return nil, 'invalid-api-result'
    end
    if not asPercent then
        return amount
    end

    local maximum, why = call(self, UnitHealthMax, 'player')

    if not maximum then
        return nil, why
    end

    local health = maximum[2]

    if not finite(health) or health <= 0 then
        return nil, 'invalid-api-result'
    end

    return amount / health * 100
end

-- Reads the Balance Druid Eclipse state (Wrath through Mists).
-- @param kind string  "energy" for the signed bar from -100 (Lunar Eclipse) to 100 (Solar Eclipse), or "direction"
--   for where the bar is heading.
-- @return number|string|nil  The energy as a number, or the direction as "sun", "moon" or "none"; nil when it cannot
--   be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Another class has no Eclipse bar and reads as unavailable, never as a confident zero.
function platform:GetEclipseObservation(kind)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(kind) then
        return nil, 'restricted-value'
    end
    if kind ~= 'energy' and kind ~= 'direction' then
        return nil, 'invalid-eclipse-query'
    end

    local class, reason = playerClass(self)

    if not class then
        return nil, reason
    end
    if class ~= 'DRUID' then
        return nil, 'eclipse-unavailable'
    end

    if kind == 'direction' then
        local results, why = call(self, GetEclipseDirection)

        if not results then
            return nil, why
        end

        local direction = results[2]

        if direction == nil then
            return 'none'
        end
        if direction ~= 'sun' and direction ~= 'moon' and direction ~= 'none' then
            return nil, 'invalid-api-result'
        end

        return direction
    end

    local enum = Enum

    if not self:CanReadValue(enum) then
        return nil, 'restricted-value'
    end

    local types = type(enum) == 'table' and rawget(enum, 'PowerType') or nil

    if not self:CanReadValue(types) then
        return nil, 'restricted-value'
    end

    local balance = type(types) == 'table' and rawget(types, 'Balance') or nil

    if not self:CanReadValue(balance) then
        return nil, 'restricted-value'
    end
    if type(balance) ~= 'number' then
        return nil, 'power-type-unavailable'
    end

    local results, why = call(self, UnitPower, 'player', balance)

    if not results then
        return nil, why
    end

    local power = results[2]

    if power == nil then
        return nil, 'power-data-unavailable'
    end
    if not finite(power) then
        return nil, 'invalid-api-result'
    end

    return power
end

-- Reads the speed of the ranged weapon (the Auto Shot or Shoot interval).
-- @return number|false|nil  The speed in seconds (the first value of UnitRangedDamage); false with no ranged attack;
--   nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetRangedSwingSpeed()
    -- UnitRangedDamage is SecretWhenUnitStatsRestricted, as UnitAttackSpeed is: a
    -- hidden value is unavailable (call checks readability), not unsupported.
    -- The time remaining also needs the combat log; that is declared in
    -- Core/condition_support.lua.
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end

    local results, reason = call(self, UnitRangedDamage, 'player')

    if not results then
        return nil, reason
    end

    local speed = results[2]

    if speed == nil or speed == 0 then
        return false
    end
    if not finite(speed) or speed < 0 then
        return nil, 'invalid-api-result'
    end

    return speed
end
