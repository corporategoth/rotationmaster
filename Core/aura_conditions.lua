-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Aura scan for the Built In buff/debuff conditions (Conditions/buffs.lua): decides whether a unit has an aura matching
-- a spell, a stealable aura or a dispellable one, and compares its remaining time or stacks. Owns
-- addon:EvaluateAuraCondition and the per-pass aura cache under it; draws nothing and stores nothing. Every aura read
-- goes through Platform adapters (GetAuraByIndex, ReadAuraField, AuraRemaining), which hide restricted values, so a
-- hidden field gives nil and a reason rather than a compared secret. Loaded from the Core group of RotationMaster.toc,
-- after Core/condition_runtime.lua. The scan runs on the poll path, so it avoids per-aura allocation where it can.
local _, addon = ...
local platform = addon.Platform
local cacheKey = {}

-- ============================================================================
-- Aura reads
-- ============================================================================

-- Reads the aura at an index of a unit's aura list.
-- @param cache table|nil  The per-pass cache; with it each (unit, filter, index) is read once per evaluation pass.
-- @param unit string  The unit token.
-- @param index number  The 1-based position in the filtered aura list.
-- @param filter string  The aura filter, for example "HELPFUL" or "HARMFUL".
-- @return table|nil  The aura record; nil at the end of the list or when the read failed.
-- @return string|nil  The reason when the read failed; nil otherwise.
local function query(cache, unit, index, filter)
    if not cache then
        return platform:GetAuraByIndex(unit, index, filter)
    end

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

-- ============================================================================
-- Matching
-- ============================================================================

-- Tells whether a condition matches its spell at any rank. Any rank is the default on a client with spell ranks; only a
-- condition saved with anyrank = false asks for the exact rank, and anyrank = true is honored on every client.
-- @param value table  The condition value.
-- @return boolean  True when a different rank of the spell matches too.
local function anyRank(value)
    if value.anyrank ~= nil then
        return value.anyrank == true
    end

    return type(addon.ClientHasSpellRanks) == "function" and addon:ClientHasSpellRanks() == true
end

-- Tests one aura against the condition.
-- @param aura table  The aura record to test.
-- @param value table  The condition value (spell, anyrank, debufftype, ownbuff, owndebuff).
-- @param mode string  What to compare: 'stealable', 'dispel' (by dispel type, where Enrage is the empty type) or
--   anything else for a spell by id or name.
-- @param identity table  Scratch memo for one scan's any-rank spell name; `anyrank` falls back to comparing names.
-- @return boolean|nil  True when the aura matches; nil when a needed field is unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Honors ownbuff and owndebuff via the aura's source unit.
local function matchesAura(aura, value, mode, identity)
    local matches

    if mode == "stealable" then
        local stealable, why = platform:ReadAuraField(aura, "isStealable")

        if why then
            return nil, why
        end
        if stealable == nil then
            return nil, "aura-stealability-unavailable"
        end

        matches = stealable
    elseif mode == "dispel" then
        local dispel, why = platform:ReadAuraField(aura, "dispelName")

        if why then
            return nil, why
        end

        matches = dispel == value.debufftype or (value.debufftype == "Enrage" and dispel == "")
    else
        local field = type(value.spell) == "number" and "spellID" or "name"
        local spell, why = platform:ReadAuraField(aura, field)

        if why then
            return nil, why
        end
        if spell == nil then
            return nil, "aura-identity-unavailable"
        end

        matches = spell == value.spell

        if not matches and field == 'spellID' and anyRank(value) then
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

            if not identity.name then
                return nil, identity.reason or 'spell-data-unavailable'
            end

            local name, reason = platform:ReadAuraField(aura, 'name')

            if reason then
                return nil, reason
            end
            if name == nil then
                return nil, 'aura-identity-unavailable'
            end

            matches = name == identity.name
        end
    end

    if matches and (value.ownbuff or value.owndebuff) then
        local source, why = platform:ReadAuraField(aura, "sourceUnit")

        if why then
            return nil, why
        end

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

-- Fast path: answers a spell condition with one lookup by name instead of walking every aura.
-- @param value table  The condition value (unit, spell, anyrank, ownbuff, owndebuff).
-- @param filter string  The aura filter, for example "HELPFUL" or "HARMFUL".
-- @param mode string  The evaluation mode; only 'present', 'remaining' and 'stacks' can use the fast path.
-- @return string|nil  "none" (no aura of that name, so no match) or "found"; nil when the walk must decide.
-- @return table|nil  The aura when the first return is "found"; nil otherwise.
--
-- The walk must decide for restricted values, an unresolvable name, a different rank, or a mode that needs more than
-- presence, remaining time or stacks.
--
-- Walking every aura costs one new native table per aura, every poll. For a spell match one lookup by name gives the
-- walk's answer: the walk's first match carries that name, and nothing of that name means no match. It is used only
-- where that holds exactly (no secrets, a result of the requested rank, the player's own aura when asked); anything
-- else walks as before.
local function lookupByName(value, filter, mode)
    if not platform.secretsUnrestricted or type(platform.GetAuraBySpellName) ~= "function" then
        return
    end
    if mode ~= "present" and mode ~= "remaining" and mode ~= "stacks" then
        return
    end

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

    if not name then
        return
    end

    local own = value.ownbuff or value.owndebuff
    local aura, reason = platform:GetAuraBySpellName(value.unit, name, own and filter .. "|PLAYER" or filter)

    if reason then
        return
    end
    if not aura then
        return "none"
    end
    if aura.unavailable then
        return
    end
    if type(spell) == "number" and not anyRank(value) and aura.spellID ~= spell then
        return
    end
    if own and aura.sourceUnit ~= "player" then
        return
    end

    return "found", aura
end

-- Tells whether the player has learned a spell.
-- @param spell number  The spell id.
-- @return boolean  True when the spell is known to the player.
local function playerKnows(spell)
    return type(platform.IsSpellKnown) == "function" and platform:IsSpellKnown(spell) == true
end

-- Whether each spell was last read on the player as present (true) or absent (false) while the game was showing auras.
local lastRead = {}

-- Answers a condition on the player's own buff by spell ID, for a restricted client where the walk of the player's auras
-- is refused in combat.
-- @param value table  The condition value (unit, spell, anyrank, ownbuff).
-- @param filter string  The aura filter; only "HELPFUL" is answered here.
-- @param mode string  The evaluation mode; 'present', 'remaining' and 'stacks'.
-- @return string|nil  "none" (the player has none of the spell's ranks, and the game is showing auras) or "found"; nil when
--   the walk must decide.
-- @return table|nil  The aura when the first return is "found"; nil otherwise.
--
-- Every known rank is asked for when any rank matches. A refusal, or an aura whose fields cannot be read, leaves the
-- walk to say so.
local function lookupPlayerBySpell(value, filter, mode)
    if platform.secretsUnrestricted or type(platform.GetPlayerAuraBySpellID) ~= "function" then
        return
    end
    if value.unit ~= "player" or filter ~= "HELPFUL" or type(value.spell) ~= "number" then
        return
    end
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        return
    end
    if mode ~= "present" and mode ~= "remaining" and mode ~= "stacks" then
        return
    end

    local ids = { value.spell }

    if anyRank(value) and addon.SpellCatalog and type(addon.SpellCatalog.GetAllSpellIds) == "function" then
        ids = addon.SpellCatalog:GetAllSpellIds(value.spell) or ids
    end

    -- Answers for an aura found: "found", or nil when its fields (needed for the mode) are hidden.
    -- @param aura table  The aura record.
    -- @param id number  The spell id it was asked for.
    -- @return string|nil  "found" or nil.
    -- @return table|nil  The aura when found.
    local function accept(aura, id)
        local hidden = aura.unavailable
        local ownerOnly = hidden and hidden.sourceUnit and next(hidden, next(hidden)) == nil

        -- A hidden owner is not a hidden aura: for presence, a spell the player knows and finds on themselves in combat is
        -- taken as their own (only a second caster of the same spell could make it someone else's).
        if
            hidden
            and not (mode == "present"
                and (not value.ownbuff or ownerOnly and (playerKnows(value.spell) or playerKnows(id))))
        then
            return
        end
        if not hidden and value.ownbuff and aura.sourceUnit ~= "player" then
            return
        end

        lastRead[value.spell] = true
        return "found", aura
    end

    for _, id in ipairs(ids) do
        local aura, reason = platform:GetPlayerAuraBySpellID(id)

        if reason then
            return
        end
        if aura then
            return accept(aura, id)
        end
    end

    -- No aura carries any of the spell's IDs, but a buff can carry another ID than the spell that casts it (a shield's
    -- proc spell, say), so it is also asked for by name before the answer is "none"; a refusal there leaves the walk to say so.
    local info = type(platform.GetSpellInfo) == "function" and platform:GetSpellInfo(value.spell)
    local name = info and info.name

    if type(name) == "string" and name ~= "" and type(platform.GetAuraBySpellName) == "function" then
        local aura, reason = platform:GetAuraBySpellName("player", name, "HELPFUL")

        if reason and reason ~= "missing-api" then
            return
        end
        if aura then
            return accept(aura, value.spell)
        end
    end

    -- While the game hides auras, nothing found is not proof that a buff that was up has gone (Forever hands back nothing
    -- for a buff that is up as combat starts): for a spell last read as present, the walk, the Cooldown Manager and the
    -- remembered read decide, and a step whose condition stays unavailable is simply not offered. A spell last read as
    -- absent, or never read, stays absent, so a Stop or Branch on a buff the player does not have is not held up.
    if type(platform.AreAurasHidden) == "function" and platform:AreAurasHidden() then
        if lastRead[value.spell] then
            return
        end

        return "none"
    end

    lastRead[value.spell] = false
    return "none"
end

-- ============================================================================
-- Evaluation
-- ============================================================================

-- Turns a matched aura into the condition's answer.
-- @param aura table  The matched aura record.
-- @param value table  The condition value (operator, value).
-- @param mode string  'remaining' compares remaining time, 'stacks' compares stacks, anything else is presence.
-- @param start number|nil  The poll's time for the remaining-time read; nil reads GetTime().
-- @return boolean|nil  True for presence, or the comparison of remaining time or stacks against the condition's
--   operator and value; nil when a field is unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function auraResult(aura, value, mode, start)
    if mode == "remaining" then
        local remaining, why = platform:AuraRemaining(aura, start or GetTime())

        if remaining == nil then
            return nil, why
        end

        return addon.Functions.values.compare(value.operator, remaining, value.value)
    elseif mode == "stacks" then
        local stacks, why = platform:ReadAuraField(aura, "applications")

        if why then
            return nil, why
        end
        if stacks == nil then
            return nil, "aura-stacks-unavailable"
        end

        return addon.Functions.values.compare(value.operator, stacks, value.value)
    end

    return true
end

-- Scratch memo for one scan's any-rank name; reset per scan, never retained.
local identity = {}

-- Scans a unit's auras for a buff or debuff condition on `value.unit`.
-- @param self table  The addon.
-- @param value table  The condition value (unit, spell, operator, value, dispellable, ...).
-- @param cache table|nil  The per-pass cache for aura reads.
-- @param start number|nil  The poll's time.
-- @param filter string  The aura list: "HELPFUL", "HARMFUL", ...
-- @param mode string  'present', 'remaining', 'stacks', 'dispel' or 'stealable'.
-- @return boolean|nil  The condition's answer (a missing unit is false); nil when unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- For presence-style modes a field read that fails only counts if no other aura matches; the other modes fail at once.
-- The scan stops at 256 auras.
local function evaluateAura(self, value, cache, start, filter, mode)
    if type(UnitExists) ~= "function" then
        return nil, "missing-api"
    end

    local ok, exists = pcall(UnitExists, value.unit)

    if not ok then
        return nil, "api-error"
    end
    if not platform:CanReadValue(exists) then
        return nil, "restricted-value"
    end
    if exists == nil or exists == false then
        return false
    end
    if exists ~= true and exists ~= 1 then
        return nil, "invalid-api-result"
    end

    if mode == "dispel" and value.dispellable then
        filter = "HARMFUL|RAID"
    end

    local direct, found = lookupByName(value, filter, mode)

    if direct == nil then
        direct, found = lookupPlayerBySpell(value, filter, mode)
    end

    if direct == "none" then
        return false
    end
    if direct == "found" then
        return auraResult(found, value, mode, start)
    end

    local existential = mode == "present" or mode == "dispel" or mode == "stealable"
    local pendingReason
    identity.resolved, identity.name, identity.reason = nil, nil, nil

    for index = 1, 256 do
        local aura, reason = query(cache, value.unit, index, filter)

        if reason then
            return nil, reason
        end

        if not aura then
            if pendingReason then
                return nil, pendingReason
            end

            -- An empty list of your own auras while the game hides auras is not proof of absence.
            if index == 1 and value.unit == "player" and platform:AreAurasHidden() then
                return nil, "auras-hidden"
            end

            return false
        end

        local matches, why = matchesAura(aura, value, mode, identity)

        if why then
            if not existential then
                return nil, why
            end

            pendingReason = pendingReason or why
        end

        if matches then
            return auraResult(aura, value, mode, start)
        end
    end

    return nil, pendingReason or "aura-scan-limit"
end

-- Evaluates a Built In buff or debuff condition, falling back where the game hides the aura data.
-- @param value table  The condition value (unit, spell, operator, value and the per-condition options).
-- @param cache table|nil  The per-pass cache.
-- @param start number|nil  The poll's time.
-- @param filter string  The aura list: "HELPFUL", "HARMFUL", ...
-- @param mode string  'present', 'remaining', 'stacks', 'dispel' or 'stealable'.
-- @return boolean|nil  The condition's answer; nil when unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- When the scan is unavailable, a presence check of a spell on you or your target asks the Cooldown Manager
-- (Platform/cooldown_viewer.lua). A "down" there counts on your target only for your own debuff, since another caster's
-- copy may still be up. With "Remember hidden buffs and cooldowns" on, your own auras then answer from what was last
-- read (Platform/auras.lua): presence, remaining time and stacks, until the remembered expiry.
function addon:EvaluateAuraCondition(value, cache, start, filter, mode)
    local result, reason = evaluateAura(self, value, cache, start, filter, mode)

    if result ~= nil or type(value.spell) ~= 'number' then
        return result, reason
    end

    -- The Cooldown Manager sees real presence, so it answers first.
    if
        mode == 'present' and (value.unit == 'player' or value.unit == 'target') and platform.GetCooldownViewerPresence
    then
        local up = platform:GetCooldownViewerPresence(value.spell, value.unit)

        if up == true or up == false and (value.unit == 'player' or value.owndebuff or value.ownbuff) then
            return up
        end
    end

    local profile = self.db and self.db.profile

    if
        value.unit == 'player'
        and (mode == 'present' or mode == 'remaining' or mode == 'stacks')
        and profile
        and profile.remember_hidden == true
        and platform.GetRememberedAura
    then
        local memory = platform:GetRememberedAura(value.spell)
        local now = start or (type(GetTime) == 'function' and GetTime()) or nil

        if memory and now then
            local left = memory.expires == 0 and math.huge or memory.expires - now

            if mode == 'present' then
                return left > 0
            elseif left <= 0 then
                return false
            elseif mode == 'remaining' then
                return addon.Functions.values.compare(value.operator, left, value.value)
            end

            return addon.Functions.values.compare(value.operator, memory.stacks or 1, value.value)
        end
    end

    return result, reason
end

-- Enrolls the helper with the condition runtime; skipped when the condition runtime is not loaded.
if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('EvaluateAuraCondition', addon.EvaluateAuraCondition)
end
