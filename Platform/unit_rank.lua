-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for a unit's rank: whether it is a boss and whether it is elite (UnitExists, UnitClassification,
-- UnitLevel, and UnitIsBossMob where the client has it). Returns a record, `false` for an absent unit, or `nil, reason`;
-- every game value passes platform:CanReadValue first. None of these APIs carries a secret annotation in Blizzard's
-- generated documentation (live and forever), so they read on Retail and Forever too. Only the probe and restricted
-- combat-data policies read. Loaded from RotationMaster.toc after Platform/unit_metadata.lua; Conditions/unit_rank.lua
-- uses it.
local _, addon = ...
local platform = addon.Platform

-- Classifications that count as elite or better.
local eliteRanks = { elite = true, rareelite = true, worldboss = true }

-- Reads a unit's rank.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @return table|false|nil  { classification = string, elite = boolean, boss = boolean }; false when the unit does not
--   exist; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- boss is true when UnitIsBossMob says so, for a World Boss, or for an elite of unknown (skull, -1) level. Without
-- UnitIsBossMob only the last two apply. An unreadable UnitIsBossMob or level leaves boss to the classification.
function platform:GetUnitRankObservation(unit)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(unit) then
        return nil, 'restricted-value'
    end
    if type(unit) ~= 'string' or unit == '' then
        return nil, 'invalid-unit'
    end
    if type(UnitExists) ~= 'function' or type(UnitClassification) ~= 'function' then
        return nil, 'missing-api'
    end

    local existsOk, exists = pcall(UnitExists, unit)

    if not existsOk then
        return nil, 'api-error'
    end
    if not self:CanReadValue(exists) then
        return nil, 'restricted-value'
    end
    if exists == nil then
        return nil, 'unit-data-unavailable'
    end
    if type(exists) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end
    if not exists then
        return false
    end

    local ok, classification = pcall(UnitClassification, unit)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(classification) then
        return nil, 'restricted-value'
    end
    if type(classification) ~= 'string' or classification == '' then
        return nil, 'invalid-api-result'
    end

    local elite = eliteRanks[classification] == true
    local boss = classification == 'worldboss'

    if not boss and type(UnitIsBossMob) == 'function' then
        local bossOk, bossMob = pcall(UnitIsBossMob, unit)
        boss = bossOk and self:CanReadValue(bossMob) and bossMob == true
    end

    if not boss and elite and type(UnitLevel) == 'function' then
        local levelOk, level = pcall(UnitLevel, unit)
        boss = levelOk and self:CanReadValue(level) and level == -1
    end

    return { classification = classification, elite = elite, boss = boss }
end

-- The client API that answers each unit kind (UNIT_KIND).
local kindReaders = {
    questboss = function() return UnitIsQuestBoss end,
    lieutenant = function() return UnitIsLieutenant end,
    minion = function() return UnitIsMinion end,
    trivial = function() return UnitIsTrivial end,
}

-- Reads whether a unit is of a kind: a quest boss, a lieutenant, a minion or trivial.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param kind string  A key of addon.unitKinds.
-- @return boolean|nil  Whether the unit is of that kind; false when the unit does not exist; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil ('missing-api' where the client lacks the kind).
function platform:GetUnitKindObservation(unit, kind)
    if not self:CanReadValue(unit) then
        return nil, 'restricted-value'
    end
    if type(unit) ~= 'string' or unit == '' then
        return nil, 'invalid-unit'
    end

    local reader = kindReaders[kind] and kindReaders[kind]()

    if type(reader) ~= 'function' or type(UnitExists) ~= 'function' then
        return nil, 'missing-api'
    end

    local existsOk, exists = pcall(UnitExists, unit)

    if not existsOk then
        return nil, 'api-error'
    end
    if not self:CanReadValue(exists) then
        return nil, 'restricted-value'
    end
    if not exists then
        return false
    end

    local ok, answer = pcall(reader, unit)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(answer) then
        return nil, 'restricted-value'
    end

    return answer == true or answer == 1
end
