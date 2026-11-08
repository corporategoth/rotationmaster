-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Forecast: predicts the recommendations after the first one by walking the rotation again as if the earlier ones had
-- been cast (docs/architecture/forecast.md). Each pass runs the real rotation executor and the real conditions against a
-- fresh cache, while a few Platform readers are replaced for the length of the call by projections of the same reads:
-- cooldowns and charges (the spells predicted so far are on cooldown, the others have moved on in time), usability and
-- power (their costs spent, regeneration added), auras (aged, plus the ones a predicted spell is known to apply) and
-- health (the damage and healing a predicted spell is known to do). Everything else is read as it is. A reader that cannot
-- be read stays unreadable; nothing is guessed for a hidden value. The originals are put back before the call returns,
-- also when a condition raises an error. Owns no frames and no events; Platform/forecast_events.lua learns the per-spell
-- facts and UI/preview.lua shows the confidence. Loaded from RotationMaster.toc after Core/action_policy.lua.

local _, addon = ...
local platform = addon.Platform

local forecast = {}
addon.Forecast = forecast

local MAX_SPELLS = 160
local BASE_GCD, MIN_STEP = 1.5, 0.05
-- Per-step confidence before anything specific is known, and its penalties.
local STEP_CONFIDENCE, CAST_TIME_PENALTY, REPEAT_PENALTY, UNMODELED_PENALTY = 0.9, 0.95, 0.9, 0.88

-- The projection in force while a pass runs, and the originals it replaced.
local state, originals = nil, {}

-- Returns the saved per-spell facts the forecast has learned, creating the table.
-- @return table|nil  { version, spells = { [id] = { damage, heal, applies = { unit, aura, duration } } } }.
local function store()
    local db = addon.db

    if not db or not db.global then
        return nil
    end

    local saved = db.global.forecast

    if type(saved) ~= 'table' or saved.version ~= 1 or type(saved.spells) ~= 'table' then
        saved = { version = 1, spells = {} }
        db.global.forecast = saved
    end

    return saved
end

-- Returns what is known about a spell.
-- @param spell number  The spell id.
-- @param create boolean|nil  True to create the record (up to the cap).
-- @return table|nil  { damage, heal, applies = { unit, aura, duration, name } } or nil.
function forecast:Known(spell, create)
    local saved = store()

    if not saved then
        return nil
    end

    local entry = saved.spells[spell]

    if entry or not create then
        return entry
    end

    local count = 0

    for _ in pairs(saved.spells) do
        count = count + 1
    end

    if count >= MAX_SPELLS then
        return nil
    end

    entry = {}
    saved.spells[spell] = entry
    return entry
end

-- Forgets everything learned.
function forecast:Clear()
    local db = addon.db

    if db and db.global then
        db.global.forecast = nil
    end
end

-- Reads a finite number from a reader's field.
-- @param value any  The value.
-- @return number|nil  The value when it is a readable finite number.
local function number(value)
    if platform:CanReadValue(value) and type(value) == 'number' and value == value and math.abs(value) ~= math.huge then
        return value
    end
end

-- Copies a flat table.
-- @param source table  The table.
-- @return table  A shallow copy.
local function copy(source)
    local out = {}

    for key, value in pairs(source) do
        out[key] = value
    end

    return out
end

-- The base cooldown and whether a spell is on the global cooldown, from the game's spell data.
-- @param spell number  The spell id.
-- @return number  The base cooldown in seconds (0 when none or unknown).
-- @return boolean  Whether the spell is on the global cooldown (true when unknown).
local function baseCooldown(spell)
    local reader = GetSpellBaseCooldown

    if type(reader) ~= 'function' then
        return 0, true
    end

    local ok, cooldown, gcd = pcall(reader, spell)

    if not ok then
        return 0, true
    end

    cooldown, gcd = number(cooldown), number(gcd)
    return (cooldown or 0) / 1000, gcd == nil or gcd > 0
end

-- The power costs of a spell.
-- @param spell number  The spell id.
-- @return table  A list of { type, cost }; empty when none or unreadable.
local function costs(spell)
    local reader = C_Spell and C_Spell.GetSpellPowerCost

    if type(reader) ~= 'function' then
        return {}
    end

    local ok, list = pcall(reader, spell)
    local out = {}

    if ok and type(list) == 'table' then
        for _, entry in ipairs(list) do
            local kind, cost = number(entry.type), number(entry.cost)

            if kind and cost and cost > 0 then
                out[#out + 1] = { type = kind, cost = cost }
            end
        end
    end

    return out
end

-- The seconds the player is busy after pressing a spell: its cast time, or the global cooldown, whichever is longer.
-- @param spell number  The spell id.
-- @return number  Seconds, at least MIN_STEP.
local function stepLength(spell)
    local info = platform:GetSpellInfo(spell)
    local cast = info and number(info.castTime) or 0
    local _, onGCD = baseCooldown(spell)
    local gcd = onGCD and (state.gcd or BASE_GCD) or 0

    return math.max(MIN_STEP, cast / 1000, gcd)
end

-- ============================================================================
-- Projected readers
-- ============================================================================

local wrappers = {}

-- Reads a spell's cooldown as it will be at the projected time.
-- @param self table  The platform.
-- @param spell number|string  The spell.
-- @return table|nil  { startTime, duration, isEnabled, modRate }, as the real reader returns it.
-- @return string|nil  The reason code when the first return is nil.
-- @return boolean|nil  When only the times are secret: isEnabled, as the real reader returns it.
-- @return boolean|nil  When only the times are secret: isActive.
-- @return boolean|nil  When only the times are secret: isOnGCD.
function wrappers.GetSpellCooldown(self, spell)
    local record, why, a, b, c = originals.GetSpellCooldown(self, spell)
    local cast = state.cast[spell]

    if cast then
        return {
            startTime = state.now + cast.at - state.t,
            duration = cast.cooldown,
            isEnabled = true,
            modRate = 1,
        }
    end

    if type(record) == 'table' then
        local start, duration = number(record.startTime), number(record.duration)

        if start and duration and duration > 0 then
            local out = copy(record)
            out.startTime = start - state.t
            return out
        end
    end

    return record, why, a, b, c
end

-- Tells whether a spell can be used at a time, from the projected cooldown.
-- @param self table  The platform.
-- @param spell number|string  The spell.
-- @param now number  The time to test.
-- @return boolean|nil  True or false; nil when it cannot be decided.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.IsSpellReady(self, spell, now)
    local record, why = wrappers.GetSpellCooldown(self, spell)

    if type(record) ~= 'table' then
        return originals.IsSpellReady(self, spell, now)
    end

    local start, duration = number(record.startTime), number(record.duration)

    if not start or not duration then
        return originals.IsSpellReady(self, spell, now)
    end
    if record.isEnabled == false then
        return false
    end

    return duration == 0 or start + duration <= now + MIN_STEP
end

-- Reads a spell's charges with the predicted uses taken off.
-- @param self table  The platform.
-- @param spell number|string  The spell.
-- @return table|nil  { currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate, isActive }.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetSpellCharges(self, spell)
    local record, why = originals.GetSpellCharges(self, spell)

    if type(record) ~= 'table' then
        return record, why
    end

    local out = copy(record)
    local current = number(record.currentCharges)
    local start = number(record.cooldownStartTime)

    if start then
        out.cooldownStartTime = start - state.t
    end
    if current and state.uses[spell] then
        out.currentCharges = math.max(0, current - state.uses[spell])
    end

    return out
end

-- The current value of one of the player's power types at the projected time.
-- @param kind number  The power type.
-- @param current number  The value read now.
-- @param maximum number|nil  The maximum, when known.
-- @return number  The projected value.
local function projectedPower(kind, current, maximum)
    local value = current - (state.spent[kind] or 0) + (state.regen[kind] or 0) * state.t

    if maximum then
        value = math.min(value, maximum)
    end

    return math.max(0, value)
end

-- Tells whether a spell is usable and whether it lacks power, with the projected power.
-- @param self table  The platform.
-- @param id number  The spell id.
-- @return boolean|nil  Whether the spell is usable.
-- @return boolean|nil  Whether it lacks the power to cast.
-- @return string|nil  The reason code when the first two returns are nil.
function wrappers.IsSpellUsable(self, id)
    local usable, lacks, why = originals.IsSpellUsable(self, id)

    if usable == nil or not state.power then
        return usable, lacks, why
    end

    local short = false

    for _, entry in ipairs(costs(id)) do
        local have = state.power[entry.type]

        if have ~= nil and projectedPower(entry.type, have.current, have.maximum) < entry.cost then
            short = true
        end
    end

    if short then
        return false, true
    end

    if lacks == true then
        -- Short now, but regeneration covers it by then: nothing else stops it when it is only the power that was missing.
        return true, false
    end

    return usable, lacks
end

-- Reads a unit's power with the predicted spending and regeneration.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param resource string  "mana" or "current".
-- @param includeMaximum boolean|nil  Whether to read the maximum too.
-- @return table|nil  { exists, powerType, current, maximum? }.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetUnitPowerObservation(self, unit, resource, includeMaximum)
    local record, why = originals.GetUnitPowerObservation(self, unit, resource, includeMaximum)

    if unit ~= 'player' or type(record) ~= 'table' or not record.exists then
        return record, why
    end

    local current, kind = number(record.current), number(record.powerType)

    if not current or not kind then
        return record, why
    end

    local out = copy(record)
    out.current = projectedPower(kind, current, number(record.maximum))
    return out
end

-- Reads a unit's health with the damage and healing the predicted spells are known to do.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param includeMaximum boolean|nil  Whether to read the maximum too.
-- @return table|nil  { exists, current, maximum? }.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetUnitHealthObservation(self, unit, includeMaximum)
    local record, why = originals.GetUnitHealthObservation(self, unit, includeMaximum)

    if type(record) ~= 'table' or not record.exists then
        return record, why
    end

    local current = number(record.current)
    local change = unit == 'target' and -state.damage or unit == 'player' and state.heal or 0

    if not current or change == 0 then
        return record, why
    end

    local out = copy(record)
    local maximum = number(record.maximum)
    out.current = math.max(0, maximum and math.min(maximum, current + change) or current + change)
    return out
end

-- Builds the projected aura list of a unit and filter: the real auras aged to the projected time, then the ones the
-- predicted spells apply.
-- @param unit string  The unit token.
-- @param filter string  The aura filter.
-- @return table|nil  The list of aura records; nil when the auras cannot be read.
-- @return string|nil  The reason code when the first return is nil.
local function auraList(unit, filter)
    local key = unit .. '\0' .. filter
    local cached = state.auras[key]

    if cached then
        return cached
    end

    local list = {}
    local now = state.now

    for index = 1, 64 do
        local aura, why = originals.GetAuraByIndex(platform, unit, index, filter)

        if not aura then
            if why and index == 1 then
                return nil, why
            end

            break
        end

        local expiration = number(aura.expirationTime)
        local kept = true

        if expiration and expiration > 0 then
            if expiration - state.t <= now then
                kept = false
            else
                aura = copy(aura)
                aura.expirationTime = expiration - state.t
            end
        end

        if kept then
            list[#list + 1] = aura
        end
    end

    for _, applied in ipairs(state.applied) do
        local harmful = filter ~= 'HELPFUL'

        local expiry = applied.record.expirationTime

        if applied.unit == unit and applied.harmful == harmful and (expiry == 0 or expiry > now) then
            local replaced = false

            for index, aura in ipairs(list) do
                if number(aura.spellID) == applied.aura then
                    list[index] = applied.record
                    replaced = true
                end
            end

            if not replaced then
                list[#list + 1] = applied.record
            end
        end
    end

    state.auras[key] = list
    return list
end

-- Reads one aura of a unit by position from the projected list.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param index number  The position.
-- @param filter string  The aura filter.
-- @return table|nil  The aura; nil when there is none.
-- @return string|nil  The reason code when it cannot be read.
function wrappers.GetAuraByIndex(self, unit, index, filter)
    if
        type(unit) ~= 'string' or type(index) ~= 'number' or type(filter) ~= 'string' or not platform:CanReadValue(unit)
    then
        return originals.GetAuraByIndex(self, unit, index, filter)
    end

    local list, why = auraList(unit, filter)

    if not list then
        return nil, why
    end

    return list[index]
end

-- ============================================================================
-- Running a pass
-- ============================================================================

-- Puts the projected readers in place.
local function install()
    for name, wrapper in pairs(wrappers) do
        if type(platform[name]) == 'function' then
            originals[name] = platform[name]
            platform[name] = wrapper
        end
    end
end

-- Puts the real readers back.
local function uninstall()
    for name, original in pairs(originals) do
        platform[name] = original
        originals[name] = nil
    end

    state = nil
end

-- The regeneration per second of each power type the player has, as far as it can be known.
-- @return table  { [powerType] = perSecond }.
local function regeneration()
    local out = {}
    local types = Enum and Enum.PowerType

    if type(types) ~= 'table' then
        return out
    end

    if types.Mana and type(GetManaRegen) == 'function' then
        local ok, base, casting = pcall(GetManaRegen)
        out[types.Mana] = ok and (number(casting) or number(base)) or nil
    end

    if types.Energy then
        out[types.Energy] = 10
    end

    return out
end

-- Starts the projected state for a pass.
-- @param now number  The real time.
-- @return table  The state.
local function newState(now)
    local s = {
        now = now,
        t = 0,
        cast = {},
        uses = {},
        spent = {},
        regen = regeneration(),
        applied = {},
        auras = {},
        damage = 0,
        heal = 0,
        gcd = nil,
        power = nil,
        confidence = 1,
    }

    local gcdRecord = type(platform.GetGlobalCooldown) == 'function' and platform:GetGlobalCooldown()

    if type(gcdRecord) == 'table' and number(gcdRecord.duration) and gcdRecord.duration > 0 then
        s.gcd = gcdRecord.duration
    end

    local read = type(platform.GetUnitPowerObservation) == 'function' and platform:GetUnitPowerObservation(
        'player',
        'current',
        true
    )

    if type(read) == 'table' and read.exists and number(read.current) and number(read.powerType) then
        s.power = { [read.powerType] = { current = read.current, maximum = number(read.maximum) } }
    end

    local mana = Enum and Enum.PowerType and Enum.PowerType.Mana

    local manaRead = mana and type(platform.GetUnitPowerObservation) == 'function' and platform:GetUnitPowerObservation(
        'player',
        'mana',
        true
    )

    if type(manaRead) == 'table' and manaRead.exists and number(manaRead.current) then
        s.power = s.power or {}
        s.power[mana] = { current = manaRead.current, maximum = number(manaRead.maximum) }
    end

    return s
end

-- Applies a spell cast at the projected time to the state: its cooldown, cost, charges, auras and health effects, and
-- moves the projected time to when the player can act again.
-- @param spell number  The spell id.
-- @return number  A confidence factor for the assumptions this made (1 when nothing was assumed).
local function apply(spell)
    local factor = 1
    local cooldown = baseCooldown(spell)
    local length = stepLength(spell)
    local info = platform:GetSpellInfo(spell)

    if cooldown > 0 then
        -- Every rank of the spell is on that cooldown, not only the one that was picked: the rotation may name another.
        local catalog = addon.SpellCatalog

        local found, ids = pcall(function()
            return catalog and catalog.GetAllSpellIds and catalog:GetAllSpellIds(spell)
        end)

        ids = found and ids or nil

        for _, id in ipairs(ids or { spell }) do
            state.cast[id] = { at = state.t, cooldown = cooldown }
        end

        state.cast[spell] = { at = state.t, cooldown = cooldown }
    end

    state.uses[spell] = (state.uses[spell] or 0) + 1

    for _, entry in ipairs(costs(spell)) do
        state.spent[entry.type] = (state.spent[entry.type] or 0) + entry.cost

        if state.power == nil or state.power[entry.type] == nil then
            factor = factor * UNMODELED_PENALTY
        end
    end

    local known = forecast:Known(spell)

    if known then
        if known.damage then
            state.damage = state.damage + known.damage
        end
        if known.heal then
            state.heal = state.heal + known.heal
        end

        if known.applies and known.applies.aura then
            local applies = known.applies
            local name = platform:GetSpellInfo(applies.aura)
            local duration = applies.duration or 0

            -- The expiry is filled in once the projected time has moved on (below), because it is written relative to it.
            local record = {
                name = name and name.name or tostring(applies.aura),
                spellId = applies.aura,
                spellID = applies.aura,
                applications = 1,
                duration = duration,
                expirationTime = 0,
                sourceUnit = 'player',
            }

            state.applied[#state.applied + 1] = {
                unit = applies.unit,
                harmful = applies.unit ~= 'player',
                aura = applies.aura,
                record = record,
                at = state.t,
            }
        end
    end

    if info and (number(info.castTime) or 0) > 0 then
        factor = factor * CAST_TIME_PENALTY
    end

    state.t = state.t + length
    state.auras = {}

    for _, applied in ipairs(state.applied) do
        -- An aura's expiry is written for the projected time the next pass reads it at.
        if applied.record.duration > 0 then
            applied.record.expirationTime = state.now + applied.at + applied.record.duration - state.t
        end
    end

    return factor
end

-- Finds the first step that matches and is ready in the projected state.
-- @param rot table  The rotation body.
-- @param cache table  The pass's own cache.
-- @param ready function  The pass's readiness memo.
-- @return table|nil  { spell, cond, index, item } for the selected step.
local function pickStep(rot, cache, ready)
    local found

    addon:EvaluateRotationSequence(
        rot,
        function(condition, context)
            return addon:evaluateConditionWithCache(condition, cache, state.now, context)
        end,
        function(cond, ordinal)
            if cond.type == 'mark' or cond.type == 'assisted' or cond.disabled or cond.action == nil then
                return true
            end

            local outcome = addon:evaluateConditionWithCache(cond.conditions, cache, state.now, { stepId = cond.id })

            if outcome.status ~= 'match' then
                return true
            end

            local spellids, itemids = addon:GetSpellIds(cond)

            for index, id in ipairs(spellids or {}) do
                local itemId = itemids and itemids[index]
                local mapped = addon:FindSpell({ id }, cond.type == 'item' and { itemId } or nil)

                if mapped and ready(cond.type, id, itemId) then
                    found = { spell = mapped, cond = cond, index = ordinal, item = itemId }
                    return false
                end
            end

            return true
        end
    )

    return found
end

-- Tells which spell the player is casting or channeling right now.
-- @return number|nil  The spell id; nil when the player is not casting, or the id cannot be read.
--
-- While a spell is being cast the preview shows what follows it (Run with this spell as the first), so the bar is never
-- empty during a cast.
function forecast:CastingSpell()
    if type(platform.GetUnitCastObservation) ~= 'function' then
        return nil
    end

    for _, kind in ipairs({ 'cast', 'channel' }) do
        local record = platform:GetUnitCastObservation('player', kind)

        if record and record.active and type(record.spellID) == 'number' then
            return record.spellID
        end
    end
end

local WAIT_STEP, WAIT_MAX, WAIT_REUSE = 1, 10, 0.5
local lastWait = { at = -1 }

-- Predicts what will be recommended while nothing can be cast now (everything is on cooldown): time is moved forward until
-- a step becomes ready, that is the first slot, and the later slots follow from the state after it. The answer is kept for
-- half a second, since the rotation is asked many times a second and its answer changes slowly.
-- @param rot table  The rotation body being advised from.
-- @param count number  How many slots to predict, 1 to 5.
-- @return table  A list of { spell, cond, index, item, confidence, at } (at: seconds from now); empty when nothing becomes
--   ready within WAIT_MAX seconds, or on failure.
function forecast:Wait(rot, count)
    local out = {}

    if type(rot) ~= 'table' or type(count) ~= 'number' or count < 1 or state then
        return out
    end

    local clock = GetTime()

    if lastWait.rot == rot and lastWait.count == count and clock - lastWait.at < WAIT_REUSE then
        return lastWait.out
    end

    local ok, err = pcall(function()
        state = newState(clock)
        install()
        local confidence = state.confidence

        for slot = 1, math.min(5, count) do
            local pick

            local limit = state.t + WAIT_MAX

            while state.t <= limit do
                local ready = addon:NewActionReadiness(state.now)
                pick = pickStep(rot, {}, ready)

                if pick then
                    break
                end

                state.t = state.t + WAIT_STEP
            end

            if not pick then
                break
            end

            confidence = confidence * STEP_CONFIDENCE * apply(pick.spell)

            out[#out + 1] = {
                spell = pick.spell,
                cond = pick.cond,
                index = pick.index,
                item = pick.item,
                confidence = math.max(0.05, math.min(1, confidence)),
                at = state.t,
            }
        end
    end)

    uninstall()

    if not ok then
        pcall(addon.verbose, addon, 'Forecast wait failed: ' .. tostring(err))
        out = {}
    end

    lastWait.rot, lastWait.count, lastWait.at, lastWait.out = rot, count, clock, out
    return out
end

-- Predicts the recommendations after the first.
-- @param rot table  The rotation body being advised from.
-- @param first number  The first recommendation's spell (the one about to be cast).
-- @param count number  How many more to predict, 1 to 4.
-- @return table  A list of { spell, cond, index, item, confidence, at } for the predicted slots (shorter than count when
--   a pass finds nothing); empty on failure.
function forecast:Run(rot, first, count)
    local out = {}

    if type(rot) ~= 'table' or type(first) ~= 'number' or type(count) ~= 'number' or count < 1 or state then
        return out
    end

    local ok, err = pcall(function()
        state = newState(GetTime())
        install()
        local confidence = state.confidence * apply(first)
        local previous = first

        for slot = 1, math.min(4, count) do
            local cache = {}
            local ready = addon:NewActionReadiness(state.now)
            local pick = pickStep(rot, cache, ready)

            if not pick then
                break
            end

            confidence = confidence * STEP_CONFIDENCE

            if pick.spell == previous then
                confidence = confidence * REPEAT_PENALTY
            end

            local factor = apply(pick.spell)
            confidence = confidence * factor
            local measured = addon.Metrics and addon.Metrics.PredictionRate and addon.Metrics:PredictionRate(slot + 1)
            local shown = measured and (confidence + measured) / 2 or confidence

            out[#out + 1] = {
                spell = pick.spell,
                cond = pick.cond,
                index = pick.index,
                item = pick.item,
                confidence = math.max(0.05, math.min(1, shown)),
                at = state.t,
            }

            previous = pick.spell
        end
    end)

    uninstall()

    if not ok then
        pcall(addon.verbose, addon, 'Forecast failed: ' .. tostring(err))
        return {}
    end

    if #out > 0 and addon.Metrics and addon.Metrics.Predicted then
        local spells, confidence = {}, {}

        for index, slot in ipairs(out) do
            spells[index], confidence[index] = slot.spell, slot.confidence
        end

        addon.Metrics:Predicted(first, spells, confidence)
    end

    return out
end
