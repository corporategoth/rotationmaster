local _, addon = ...
local platform = addon.Platform
local cacheKey = {}

local function query(cache, unit, index, filter)
    if not cache then return platform:GetAuraByIndex(unit, index, filter) end
    -- Only normalized observations enter this per-evaluation cache. Avoid the
    -- legacy CRC cache's tostring/tuple path for restricted native records.
    local units = cache[cacheKey]

    if not units then
        units = {}
        cache[cacheKey] = units
    end

    local filters = units[unit]

    if not filters then
        filters = {}
        units[unit] = filters
    end

    local records = filters[filter]

    if not records then
        records = {}
        filters[filter] = records
    end

    -- records[index] is the aura or false; reasons are rare and kept apart.
    local aura = records[index]

    if aura == nil then
        local reason
        aura, reason = platform:GetAuraByIndex(unit, index, filter)

        if reason then
            records.reasons = records.reasons or {}
            records.reasons[index] = reason
        end

        records[index] = aura or false
    end

    return aura or nil, records.reasons and records.reasons[index]
end

local function matchesAura(aura, value, mode, identity)
    local matches

    if mode == "stealable" then
        local stealable, why = platform:ReadAuraField(aura, "isStealable")
        if why then return nil, why end
        if stealable == nil then return nil, "aura-stealability-unavailable" end
        matches = stealable
    elseif mode == "dispel" then
        local dispel, why = platform:ReadAuraField(aura, "dispelName")
        if why then return nil, why end
        matches = dispel == value.debufftype or (value.debufftype == "Enrage" and dispel == "")
    else
        local field = type(value.spell) == "number" and "spellID" or "name"
        local spell, why = platform:ReadAuraField(aura, field)
        if why then return nil, why end
        if spell == nil then return nil, "aura-identity-unavailable" end
        matches = spell == value.spell

        if not matches and field == 'spellID' and value.anyrank == true then
            if not identity.resolved then
                identity.resolved = true

                if type(platform.GetSpellInfo) ~= 'function' then
                    identity.reason = 'missing-api'
                else
                    local info, reason = platform:GetSpellInfo(value.spell)
                    identity.name = info and info.name
                    identity.reason = reason
                end
            end

            if not identity.name then return nil, identity.reason or 'spell-data-unavailable' end
            local name, reason = platform:ReadAuraField(aura, 'name')
            if reason then return nil, reason end
            if name == nil then return nil, 'aura-identity-unavailable' end
            matches = name == identity.name
        end
    end

    if matches and (value.ownbuff or value.owndebuff) then
        local source, why = platform:ReadAuraField(aura, "sourceUnit")
        if why then return nil, why end
        matches = source == "player"
    end

    return matches
end

-- Walking every aura costs one new native table per aura, every poll. For a
-- spell match one lookup by name gives the walk's answer: the walk's first
-- match carries that name, and nothing of that name means no match. It is
-- used only where that holds exactly (no secrets, a result of the requested
-- rank, the player's own aura when asked); anything else walks as before.
local spellNames = {}

local function lookupByName(value, filter, mode)
    if not platform.secretsUnrestricted or type(platform.GetAuraBySpellName) ~= "function" then return end
    if mode ~= "present" and mode ~= "remaining" and mode ~= "stacks" then return end
    local spell, name = value.spell, nil

    if type(spell) == "string" then
        name = spell
    elseif type(spell) == "number" then
        name = spellNames[spell]

        if not name and type(platform.GetSpellInfo) == "function" then
            local info = platform:GetSpellInfo(spell)
            name = info and info.name

            if type(name) == "string" and name ~= "" then
                spellNames[spell] = name
            else
                name = nil
            end
        end
    end

    if not name then return end
    local own = value.ownbuff or value.owndebuff
    local aura, reason = platform:GetAuraBySpellName(value.unit, name, own and filter .. "|PLAYER" or filter)
    if reason then return end
    if not aura then return "none" end
    if aura.unavailable then return end
    if type(spell) == "number" and value.anyrank ~= true and aura.spellID ~= spell then return end
    if own and aura.sourceUnit ~= "player" then return end
    return "found", aura
end

local function auraResult(aura, value, mode, start)
    if mode == "remaining" then
        local remaining, why = platform:AuraRemaining(aura, start or GetTime())
        if remaining == nil then return nil, why end
        return addon.Functions.values.compare(value.operator, remaining, value.value)
    elseif mode == "stacks" then
        local stacks, why = platform:ReadAuraField(aura, "applications")
        if why then return nil, why end
        if stacks == nil then return nil, "aura-stacks-unavailable" end
        return addon.Functions.values.compare(value.operator, stacks, value.value)
    end

    return true
end

-- Scratch memo for one scan's any-rank name; reset per scan, never retained.
local identity = {}

function addon:EvaluateAuraCondition(value, cache, start, filter, mode)
    if type(UnitExists) ~= "function" then return nil, "missing-api" end
    local ok, exists = pcall(UnitExists, value.unit)
    if not ok then return nil, "api-error" end
    if not platform:CanReadValue(exists) then return nil, "restricted-value" end
    if exists == nil or exists == false then return false end
    if exists ~= true and exists ~= 1 then return nil, "invalid-api-result" end

    if mode == "dispel" and value.dispellable then filter = "HARMFUL|RAID" end
    local direct, found = lookupByName(value, filter, mode)
    if direct == "none" then return false end
    if direct == "found" then return auraResult(found, value, mode, start) end
    local existential = mode == "present" or mode == "dispel" or mode == "stealable"
    local pendingReason
    identity.resolved, identity.name, identity.reason = nil, nil, nil

    for index = 1, 256 do
        local aura, reason = query(cache, value.unit, index, filter)
        if reason then return nil, reason end

        if not aura then
            if pendingReason then return nil, pendingReason end
            return false
        end

        local matches, why = matchesAura(aura, value, mode, identity)

        if why then
            if not existential then return nil, why end
            pendingReason = pendingReason or why
        end

        if matches then return auraResult(aura, value, mode, start) end
    end

    return nil, pendingReason or "aura-scan-limit"
end

if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('EvaluateAuraCondition', addon.EvaluateAuraCondition)
end
