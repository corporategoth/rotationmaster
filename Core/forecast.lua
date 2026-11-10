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
-- What a guess costs: a cost taken from the game's tables instead of read, an item whose cooldown has never been seen, and the
-- share of a possible miss that would change what follows (a miss does not always change the next step).
local ESTIMATE_PENALTY, ITEM_PENALTY, MISS_WEIGHT = 0.97, 0.95, 0.5
-- An item whose cooldown is not known is taken as used once in the window the forecast looks at.
local UNKNOWN_ITEM_COOLDOWN = 600
-- An aura a cast is only sometimes seen to leave is projected when it is seen at least this often; below it, the likelier
-- outcome (not there) is the projection. The casts it is counted over are never fewer than MIN_CASTS.
local PROC_FLOOR, MIN_CASTS = 0.5, 2
local WAIT_DECAY = 0.97

-- The projection in force while a pass runs, and the originals it replaced.
local state, originals = nil, {}

-- When the player last cast each spell, and any spell, on the game's clock (fed by main.lua's cast handlers): what a
-- cooldown whose times are hidden (a restricted client in combat) is worked out from.
local lastCast, lastAny = {}, nil

-- Notes a spell the player has just cast.
-- @param spell number|nil  The spell id; nil when it cannot be read.
-- @param at number  The time of the cast.
function forecast:NoteCast(spell, at)
    lastAny = at

    if type(spell) == 'number' then
        lastCast[spell] = at
    end
end

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

-- The last costs read for each spell while the game let them be read. In combat on a restricted client the numbers are hidden,
-- and nothing that sets a cost can change then (gear, talents, level and the maximum mana all change out of combat), so the
-- last readable answer is still the right one. Every readable read refreshes it, so a change is picked up the next time the
-- game lets the cost be read.
local costCache, warmedAt = {}, nil
local WARM_EVERY = 5

local MANA = 0
local calibrated = {}

-- The player's level.
-- @return number|nil  The level; nil when it cannot be read.
local function playerLevel()
    local read = type(platform.GetUnitLevelObservation) == 'function' and platform:GetUnitLevelObservation('player')

    return type(read) == 'table' and read.exists and number(read.level) or nil
end

-- The player's base mana, which a cost given as a percentage is a share of. The game does not say it; it is worked out from a
-- cost read live for a spell whose table row has a percentage (and kept per level, because it changes with nothing else that
-- gear or talents do), so a change of level starts it over.
-- @return number|nil  The base mana; nil when no spell has shown it yet at this level.
local function baseMana()
    local level = playerLevel()

    if not level then
        return nil
    end
    if calibrated.level == level and calibrated.mana then
        return calibrated.mana
    end

    local saved = store()
    local base = saved and saved.base

    if type(base) == 'table' and base.level == level and number(base.mana) then
        calibrated.level, calibrated.mana = level, base.mana
        return base.mana
    end
end

-- Learns the base mana from a cost read live, when the game's tables give that spell's cost as a percentage of it.
-- @param spell number  The spell id.
-- @param list table  The costs just read, a list of { type, cost }.
local function calibrate(spell, list)
    local effects = forecast:Effects(spell)
    local row = effects and effects.costs[MANA]
    local level = playerLevel()

    if not row or row.percent <= 0 or not level then
        return
    end

    for _, entry in ipairs(list) do
        if entry.type == MANA and entry.cost > row.flat then
            local mana = (entry.cost - row.flat) / row.percent * 100

            if calibrated.level ~= level or math.abs((calibrated.mana or 0) - mana) > 1 then
                calibrated.level, calibrated.mana = level, mana

                local saved = store()

                if saved then
                    saved.base = { level = level, mana = mana }
                end
            end
        end
    end
end

-- What the game's tables say a spell costs, for a spell whose cost was never readable: the flat amount plus its percentage of
-- the base mana (left out while the base mana is not known). A guess: gear, talents and auras that change a cost are not in it.
-- @param spell number  The spell id.
-- @return table|nil  A list of { type, cost, estimated = true }; nil when the tables say nothing.
local function estimatedCosts(spell)
    local effects = forecast:Effects(spell)
    local out

    for kind, row in pairs(effects and effects.costs or {}) do
        local cost = row.flat

        if row.percent > 0 then
            local base = kind == MANA and baseMana() or nil
            cost = base and cost + base * row.percent / 100 or nil
        end

        if cost and cost > 0 then
            out = out or {}
            out[#out + 1] = { type = kind, cost = cost, estimated = true }
        end
    end

    return out
end

-- The power costs of a spell.
-- @param spell number  The spell id.
-- @return table  A list of { type, cost, estimated }; empty when none, or unreadable and never read and not in the tables.
local function costs(spell)
    local reader = C_Spell and C_Spell.GetSpellPowerCost

    if type(reader) ~= 'function' then
        return costCache[spell] or estimatedCosts(spell) or {}
    end

    local ok, list = pcall(reader, spell)

    if ok and type(list) == 'table' then
        local out, hidden = {}, false

        for _, entry in ipairs(list) do
            local kind, cost = number(entry.type), number(entry.cost)

            if kind and cost then
                if cost > 0 then
                    out[#out + 1] = { type = kind, cost = cost }
                end
            else
                hidden = true
            end
        end

        if not hidden then
            costCache[spell] = out
            calibrate(spell, out)
            return out
        end
    end

    return costCache[spell] or estimatedCosts(spell) or {}
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

-- Notes that something becomes ready that long after the projected time, so a pass that finds nothing can move straight to
-- the soonest of them.
-- @param seconds number  Seconds after the projected time.
local function wake(seconds)
    if state and (state.wake == nil or seconds < state.wake) then
        state.wake = seconds
    end
end

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

    local start, duration

    if type(record) == 'table' then
        start, duration = number(record.startTime), number(record.duration)
    end

    if not start or not duration then
        -- The times are hidden (restricted client in combat): what the game says now is all that is known, and time moving on
        -- is estimated from the spell's own cooldown, or the global cooldown for a spell with none.
        local ready, reason = originals.IsSpellReady(self, spell, now)

        if ready == false and type(spell) == 'number' then
            local base = baseCooldown(spell)
            local gcd = state.gcd or BASE_GCD
            local remaining

            if base > 0 and lastCast[spell] then
                remaining = base - (state.now - lastCast[spell])
            elseif base == 0 and lastAny then
                remaining = gcd - (state.now - lastAny)
            end

            if remaining and remaining > 0 then
                if remaining > state.t then
                    wake(remaining - state.t)
                end

                return state.t >= remaining
            end

            if state.t > 0 then
                -- Not known when it was cast: it is taken as cast just now.
                local need = base > 0 and base or gcd

                if need > state.t then
                    wake(need - state.t)
                end

                return state.t >= need
            end
        end

        return ready, reason
    end

    if record.isEnabled == false then
        return false
    end

    local left = start + duration - now

    if left > MIN_STEP then
        wake(left)
    end

    return duration == 0 or left <= MIN_STEP
end

-- Reads what a unit is casting: the player is no longer casting by the time the projected spells are cast.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param kind string  "cast" or "channel".
-- @return table|nil  The record, as the real reader returns it.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetUnitCastObservation(self, unit, kind)
    if unit == 'player' then
        return { active = false }
    end

    return originals.GetUnitCastObservation(self, unit, kind)
end

-- Answers the player's movement as standing still while the projection is of what would be advised then.
-- @param self table  The platform.
-- @return table|nil  The record, as the real reader returns it.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetPlayerMovementObservation(self)
    if state and state.stationary then
        return { speed = 0, known = true, moving = false }
    end

    return originals.GetPlayerMovementObservation(self)
end

-- Answers that the player is in combat once a predicted spell has been cast that starts it (a pull such as Charge), so the
-- rotation's out-of-combat branch, which usually ends in a Stop, does not end every slot after the pull.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param kind string  "combat", "enemy" or "pvp".
-- @return boolean|nil  The flag, as the real reader returns it.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetUnitFlagObservation(self, unit, kind)
    local value, why = originals.GetUnitFlagObservation(self, unit, kind)

    if state and state.pulled and unit == 'player' and kind == 'combat' and value == false then
        return true
    end

    return value, why
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

-- Remembers how long an item's cooldown is, from a cooldown seen running, on the spell it casts: the tables do not list it.
-- @param item number|string  The item.
-- @param duration number  The cooldown's length in seconds.
local function learnItemCooldown(item, duration)
    local id = platform:GetItemID(item)

    if not id then
        return
    end

    local spell = state.itemSpell[id]

    if spell == nil then
        local use = platform:GetItemUseSpell(id)
        spell = use and use.spellID or false
        state.itemSpell[id] = spell
    end

    local entry = spell and forecast:Known(spell, true)

    -- The longest seen: a cooldown shared with another item (a second trinket) is shorter than the item's own.
    if entry and (entry.cooldown or 0) < duration - 0.5 then
        entry.cooldown = duration
    end
end

-- Reads an item's cooldown as it will be at the projected time: an item the predicted steps use is on its cooldown from then.
-- @param self table  The platform.
-- @param item number|string  The item.
-- @return table|nil  { startTime, duration, isEnabled }, as the real reader returns it.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetItemCooldown(self, item)
    local record, why = originals.GetItemCooldown(self, item)
    local id = self:GetItemID(item)
    local used = id and state.items[id]

    if used then
        return { startTime = state.now + used.at - state.t, duration = used.cooldown, isEnabled = true }
    end

    if type(record) == 'table' then
        local start, duration = number(record.startTime), number(record.duration)

        if start and duration and duration > 0 then
            if duration > 2.5 and start > 0 then
                learnItemCooldown(item, duration)
            end

            local out = copy(record)
            out.startTime = start - state.t
            return out
        end
    end

    return record, why
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

-- Applies the projected points of a resource to a reading.
-- @param kind number  The power type.
-- @param current number  The real reading.
-- @return number  The reading after the predicted builders and finishers.
local function projectedPoints(kind, current)
    local row = state.points[kind]

    if not row then
        return current
    end

    return math.max(0, (row.base or current) + row.delta)
end

-- Reads a unit's point resource (combo points, holy power, ...) with the predicted builders and finishers applied.
-- @param self table  The platform.
-- @param unit string  The unit token.
-- @param powerType number  The power type.
-- @param kind string  "current" or "maximum".
-- @return number|nil  The quantity; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetUnitPointPowerObservation(self, unit, powerType, kind)
    local value, why = originals.GetUnitPointPowerObservation(self, unit, powerType, kind)
    local current = number(value)

    if unit ~= 'player' or kind ~= 'current' or not current or not number(powerType) then
        return value, why
    end

    local maximum = number(originals.GetUnitPointPowerObservation(self, unit, powerType, 'maximum'))
    local projected = projectedPoints(powerType, current)

    return maximum and math.min(maximum, projected) or projected
end

-- Reads the player's combo points on the clients that count them against the target, with the predicted builders and
-- finishers applied.
-- @param self table  The platform.
-- @param powerType number  The power type.
-- @param kind string  "current" or "maximum".
-- @return number|nil  The quantity; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil.
function wrappers.GetPlayerComboPointObservation(self, powerType, kind)
    local value, why = originals.GetPlayerComboPointObservation(self, powerType, kind)
    local current = number(value)

    if kind ~= 'current' or not current or not number(powerType) then
        return value, why
    end

    local maximum = number(originals.GetPlayerComboPointObservation(self, powerType, 'maximum'))
    local projected = projectedPoints(powerType, current)

    return maximum and math.min(maximum, projected) or projected
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

-- Reads the costs of the rotation's spells while the game lets them be read, so the numbers are known once they are hidden.
-- @param rot table  The rotation body.
--
-- Does nothing in combat, and at most once every few seconds.
local function warmCosts(rot)
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then
        return
    end

    local clock = GetTime()

    if warmedAt and clock - warmedAt < WARM_EVERY then
        return
    end

    warmedAt = clock

    -- Walks a list of steps, into branches too.
    -- @param list table|nil  The steps.
    local function walk(list)
        for _, step in ipairs(list or {}) do
            if step.type == 'branch' then
                walk(step.onTrue or step.ontrue)
                walk(step.onFalse or step.onfalse)
            elseif step.action ~= nil and not step.disabled then
                local ok, ids = pcall(addon.GetSpellIds, addon, step)

                for _, id in ipairs(ok and ids or {}) do
                    if type(id) == 'number' then
                        costs(id)
                    end
                end
            end
        end
    end

    pcall(walk, rot and rot.rotation or rot)
end

-- Starts the projected state for a pass.
-- @param now number  The real time.
-- @return table  The state.
local function newState(now)
    local s = {
        now = now,
        t = 0,
        cast = {},
        items = {},
        itemSpell = {},
        uses = {},
        spent = {},
        regen = regeneration(),
        applied = {},
        points = {},
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

-- Rewrites what depends on the projected time after it moved: the aura cache and the expiry of the auras applied so far.
local function retime()
    state.auras = {}

    for _, applied in ipairs(state.applied) do
        -- An aura's expiry is written for the projected time the next pass reads it at.
        if applied.record.duration > 0 then
            applied.record.expirationTime = state.now + applied.at + applied.record.duration - state.t
        end
    end
end

-- What the game's own spell tables say a cast leaves behind (Data/spell_effects_<family>.lua, written by
-- tools/generate_spell_effects.py), parsed on first use and kept.
local effectRows

-- Drops the parsed spell tables, so the next read parses them again (after the data changed).
function forecast:ResetEffects()
    effectRows = nil
end

-- Lists what a spell is known from the game's tables to leave behind.
-- @param spell number  The spell id.
-- @return table|nil  { auras = list of { unit ('target' or 'player'), aura, duration (seconds; 0 until removed), stacks (the most
--   it stacks to; nil when it does not) }, points = { [powerType] = points gained }, finisher = the point power type it spends
--   all of, or nil, harmful = true when it is aimed at an enemy, school = its school mask, gains = { [powerType] = amount of a
--   primary resource it gives }, costs = { [powerType] = { flat, percent (of base mana) } } }; nil when the tables say nothing
--   about the spell (or this client has none).
function forecast:Effects(spell)
    if effectRows == nil then
        effectRows = {}

        local family = type(platform.GetClientFamily) == 'function' and platform:GetClientFamily() or nil
        local data = family and addon.SpellEffectData and addon.SpellEffectData[family]

        if type(data) == 'table' and type(data.rows) == 'string' then
            for id, list in data.rows:gmatch('(%d+)=([^;]+)') do
                local entry = { auras = {}, points = {}, gains = {}, costs = {} }

                for kind, first, second, third in list:gmatch('(%a):([%d%.]+):?([%d%.]*):?([%d%.]*)') do
                    if kind == 'g' then
                        entry.points[tonumber(first)] = (entry.points[tonumber(first)] or 0) + (tonumber(second) or 1)
                    elseif kind == 'e' then
                        entry.gains[tonumber(first)] = (entry.gains[tonumber(first)] or 0) + (tonumber(second) or 0)
                    elseif kind == 'c' then
                        entry.costs[tonumber(first)] = { flat = tonumber(second) or 0, percent = tonumber(third) or 0 }
                    elseif kind == 'f' then
                        entry.finisher = tonumber(first)
                    elseif kind == 'h' then
                        entry.harmful = true
                        entry.school = tonumber(first)
                    else
                        entry.auras[#entry.auras + 1] = {
                            unit = kind == 't' and 'target' or 'player',
                            aura = tonumber(first),
                            duration = tonumber(second) or 0,
                            stacks = tonumber(third),
                        }
                    end
                end

                effectRows[tonumber(id)] = entry
            end
        end
    end

    return effectRows[spell]
end

-- Reads how many applications of an aura a unit has in the projected state.
-- @param unit string  "target" or "player".
-- @param aura number  The aura's spell id.
-- @return number  The count; 0 when the aura is not there.
local function projectedStacks(unit, aura)
    local filter = unit == 'player' and 'HELPFUL' or 'HARMFUL'

    for index = 1, 64 do
        local row = platform:GetAuraByIndex(unit, index, filter)

        if not row then
            break
        end

        if number(row.spellID) == aura then
            return number(row.applications) or 1
        end
    end

    return 0
end

-- The aura kinds a condition can test, and whether each reads the unit's harmful or helpful auras.
local AURA_CONDITIONS = { BUFF = true, BUFF_REMAIN = true, DEBUFF = true, DEBUFF_REMAIN = true }
-- How long an aura is taken to last when only the rotation says a spell applies it (a refresh threshold is no duration).
local INFERRED_DURATION, INFERRED_PENALTY = 30, 0.95

-- Finds the aura tests in a condition tree.
-- @param node any  A condition (leaf, AND, OR or NOT) or a list.
-- @param into table  The list to append { type, unit, spell } leaves to.
local function auraTests(node, into)
    if type(node) ~= 'table' then
        return
    end

    if AURA_CONDITIONS[node.type] and node.spell ~= nil then
        into[#into + 1] = node
    end

    if type(node.value) == 'table' then
        auraTests(node.value, into)
    end

    for _, child in ipairs(node) do
        auraTests(child, into)
    end
end

-- Tells whether a spell id or name in an aura test is the spell being cast (its aura carries the spell's own name).
-- @param aura number|string  The aura the condition names.
-- @param spell number  The spell cast.
-- @return boolean  True when they are the same spell or share a name.
local function sameName(aura, spell)
    if aura == spell then
        return true
    end

    local cast = platform:GetSpellInfo(spell)
    local named = type(aura) == 'number' and platform:GetSpellInfo(aura) or nil
    local want = type(aura) == 'string' and aura or named and named.name

    return type(want) == 'string' and cast ~= nil and cast.name == want
end

-- Works out, from the rotation itself, what aura a spell leaves when nothing has been seen of it yet: a step that casts a
-- spell only while its own buff or debuff is missing (or running out) is the upkeep step for that aura, so casting it is
-- taken to apply it. The tested unit tells where the aura lands. Nothing is learned from this and it is a guess, which
-- costs a little confidence.
-- @param spell number  The spell cast.
-- @return table|nil  { unit, aura, duration, inferred = true } or nil.
local function inferApplies(spell)
    local found

    -- Walks a list of steps, into branches too, stopping at the first upkeep step for the spell.
    -- @param list table|nil  The steps.
    local function walk(list)
        for _, step in ipairs(list or {}) do
            if found then
                return
            end

            if step.type == 'branch' then
                walk(step.onTrue or step.ontrue)
                walk(step.onFalse or step.onfalse)
            elseif step.action ~= nil and not step.disabled and step.conditions ~= nil then
                local ok, ids = pcall(addon.GetSpellIds, addon, step)
                local mine = false

                for _, id in ipairs(ok and ids or {}) do
                    mine = mine or id == spell
                end

                if mine then
                    local tests = {}
                    auraTests(step.conditions, tests)

                    for _, test in ipairs(tests) do
                        if sameName(test.spell, spell) then
                            local aura = type(test.spell) == 'number' and test.spell or spell
                            local unit = type(test.unit) == 'string' and test.unit or 'player'

                            found = { unit = unit, aura = aura, duration = INFERRED_DURATION, inferred = true }
                            return
                        end
                    end
                end
            end
        end
    end

    walk(state and state.rot and state.rot.rotation or state and state.rot)
    return found
end

-- Finds the item a rotation step uses to cast a spell: the item the rotation names for that spell.
-- @param spell number  The spell id (the spell an item casts when used).
-- @return number|nil  The item id; nil when no item step of the rotation casts that spell.
local function itemOf(spell)
    local found

    -- Walks a list of steps, into branches too.
    -- @param list table|nil  The steps.
    local function walk(list)
        for _, step in ipairs(list or {}) do
            if found then
                return
            end

            if step.type == 'branch' then
                walk(step.onTrue or step.ontrue)
                walk(step.onFalse or step.onfalse)
            elseif step.type == 'item' and step.action ~= nil and not step.disabled then
                local ok, spellIds, itemIds = pcall(addon.GetSpellIds, addon, step)

                for index, id in ipairs(ok and spellIds or {}) do
                    if id == spell and type(itemIds) == 'table' and type(itemIds[index]) == 'number' then
                        found = itemIds[index]
                        return
                    end
                end
            end
        end
    end

    walk(state and state.rot and state.rot.rotation or state and state.rot)
    return found
end

-- Lists the auras a spell was seen to leave on this client that it leaves often enough to project.
-- @param known table  What was learned of the spell.
-- @return table|nil  A list of { unit, aura, duration, chance }, sorted by aura; nil when the spell has not been watched.
local function learnedAuras(known)
    local list = {}

    if type(known.seen) == 'table' then
        local casts = math.max(known.casts or 0, MIN_CASTS)

        for aura, row in pairs(known.seen) do
            local chance = math.min(1, (row.n or 0) / casts)

            if chance >= PROC_FLOOR then
                list[#list + 1] = { unit = row.unit, aura = aura, duration = row.duration, chance = chance }
            end
        end

        table.sort(list, function(a, b)
            return a.aura < b.aura
        end)

        return list
    end

    -- Saved by a version that kept one aura and never asked how often.
    if known.applies and known.applies.aura then
        return { known.applies }
    end

    return nil
end

-- Tells whether casting a spell would start combat with the target: the game's tables aim it at an enemy, or it is known to do
-- damage.
-- @param spell number  The spell id.
-- @return boolean  True when it would; false when it would not or nothing is known of the spell.
local function startsCombat(spell)
    local known = forecast:Known(spell)

    if known and known.damage then
        return true
    end

    local effects = forecast:Effects(spell)

    return effects ~= nil and effects.harmful == true
end

-- Percent chance for an attack to miss a target of 0 to 3 levels above the player, with no hit rating (Classic-era values; a
-- guess, used only to take a little confidence). The client API manifests list no way to read the player's hit, so it is not read.
local MELEE_MISS, SPELL_MISS = { 5, 5.5, 6, 8 }, { 4, 5, 6, 17 }

-- Estimates the chance that a spell cast at the target now misses it, from the player's and the target's level. Retail has no hit chance to speak of, and a spell the tables do not aim at an enemy cannot miss.
-- @param effects table|nil  What the tables say of the spell.
-- @param known table|nil  What was learned of the spell.
-- @return number  The chance, 0 to 1.
local function missChance(effects, known)
    local family = type(platform.GetClientFamily) == 'function' and platform:GetClientFamily() or 'unknown'

    if family == 'retail' or family == 'unknown' or not ((effects and effects.harmful) or (known and known.damage)) then
        return 0
    end
    if type(platform.GetUnitLevelObservation) ~= 'function' or type(platform.GetUnitFlagObservation) ~= 'function' then
        return 0
    end

    local mine, theirs = playerLevel(), platform:GetUnitLevelObservation('target')
    local enemy = platform:GetUnitFlagObservation('target', 'enemy')

    if not mine or enemy ~= true or type(theirs) ~= 'table' then
        return 0
    end

    -- A level the game does not show (a skull) is taken as three above.
    local level = theirs.exists and number(theirs.level) or mine + 3

    local base = ((effects and effects.school or 1) == 1 and MELEE_MISS or SPELL_MISS)[math.max(0, math.min(
        3,
        level - mine
    ))
        + 1]

    return base / 100
end

-- Applies a spell cast at the projected time to the state: its cooldown, cost, charges, auras and health effects, and
-- moves the projected time to when the player can act again.
-- @param spell number  The spell id (for an item, the spell it casts when used).
-- @param itemId number|nil  The item id when the step uses an item.
-- @return number  A confidence factor for the assumptions this made (1 when nothing was assumed).
local function apply(spell, itemId)
    local factor = 1
    local cooldown = baseCooldown(spell)
    local length = stepLength(spell)
    local info = platform:GetSpellInfo(spell)
    local known = forecast:Known(spell)

    if itemId then
        -- An item is on its cooldown from its use; the spell tables do not know an item's cooldown, so it is what was last seen
        -- of it, or (never seen) once for the window the forecast looks at.
        if cooldown <= 0 then
            cooldown = known and known.cooldown or 0
        end

        if cooldown <= 0 then
            cooldown = UNKNOWN_ITEM_COOLDOWN
            factor = factor * ITEM_PENALTY
        end

        state.items[itemId] = { at = state.t, cooldown = cooldown }
    end

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

    if not state.pulled and startsCombat(spell) then
        state.pulled = true
    end

    for _, entry in ipairs(costs(spell)) do
        state.spent[entry.type] = (state.spent[entry.type] or 0) + entry.cost

        if state.power == nil or state.power[entry.type] == nil then
            factor = factor * UNMODELED_PENALTY
        elseif entry.estimated then
            factor = factor * ESTIMATE_PENALTY
        end
    end

    if known then
        if known.damage then
            state.damage = state.damage + known.damage
        end
        if known.heal then
            state.heal = state.heal + known.heal
        end
    end

    -- What the cast leaves behind, from the most to the least certain source: what was seen of this spell on this client (the
    -- auras seen often enough; one seen less often is a proc, a guess that is not projected), what the game's own tables say,
    -- and (a guess, which costs a little confidence) what the rotation's upkeep step implies.
    local applied
    local effects = forecast:Effects(spell)
    local seen = known and learnedAuras(known)
    local watched = seen ~= nil and (known.casts or 0) >= 5

    if seen and #seen > 0 then
        applied = seen
    elseif not watched and not (known and (known.none or 0) >= 5) then
        applied = effects and #effects.auras > 0 and effects.auras or nil

        if not applied then
            local inferred = inferApplies(spell)

            if inferred then
                applied = { inferred }
                factor = factor * INFERRED_PENALTY
            end
        end
    end

    for _, applies in ipairs(applied or {}) do
        local name = platform:GetSpellInfo(applies.aura)
        local duration = applies.duration or 0
        local most = applies.stacks

        -- An aura seen after only some casts is projected when it is the likelier outcome, at a cost to the confidence.
        if applies.chance and applies.chance < 1 then
            factor = factor * (0.5 + 0.5 * applies.chance)
        end

        -- What was seen on this client does not say how far an aura stacks; the game's tables do.
        if not most and effects then
            for _, row in ipairs(effects.auras) do
                if row.aura == applies.aura then
                    most = row.stacks
                end
            end
        end

        -- Another application adds one stack (to the most it stacks to) and refreshes the aura.
        local count = most and math.min(most, projectedStacks(applies.unit, applies.aura) + 1) or 1

        -- The expiry is filled in once the projected time has moved on (below), because it is written relative to it.
        local record = {
            name = name and name.name or tostring(applies.aura),
            spellId = applies.aura,
            spellID = applies.aura,
            applications = count,
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

    -- Points of a resource (combo points, holy power): a finisher spends every one there is, a builder adds its own.
    if effects then
        if effects.finisher then
            state.points[effects.finisher] = { base = 0, delta = 0 }
        end

        for kind, gained in pairs(effects.points) do
            local row = state.points[kind] or { delta = 0 }

            row.delta = row.delta + gained
            state.points[kind] = row
        end
    end

    -- A resource the cast gives (rage from Charge, focus from a builder) is power the later steps can spend.
    for kind, gained in pairs(effects and effects.gains or {}) do
        state.spent[kind] = (state.spent[kind] or 0) - gained
    end

    local miss = missChance(effects, known)

    if miss > 0 then
        factor = factor * (1 - miss * MISS_WEIGHT)
    end
    if info and (number(info.castTime) or 0) > 0 then
        factor = factor * CAST_TIME_PENALTY
    end

    state.t = state.t + length
    retime()

    return factor
end

-- Finds the first step that matches and is ready in the projected state.
-- @param rot table  The rotation body.
-- @param cache table  The pass's own cache.
-- @param ready function  The pass's readiness memo.
-- @return table|nil  { spell, cond, index, item } for the selected step.
local function pickStep(rot, cache, ready)
    local found

    local result = addon:EvaluateRotationSequence(
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

    forecast.passEnded = result and result.status or 'unknown'
    return found
end

-- Tells which spell the player is casting or channeling right now.
-- @return number|nil  The spell id; nil when the player is not casting, or the id cannot be read.
-- @return number|nil  The seconds the cast has left, when the game lets them be read.
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
            return record.spellID, number(record.remainingSeconds)
        end
    end
end

-- Tells whether the player is moving now.
-- @return boolean  True when the movement speed is readable and not zero.
function forecast:PlayerMoving()
    if type(platform.GetPlayerMovementObservation) ~= 'function' then
        return false
    end

    local record = platform:GetPlayerMovementObservation()
    local speed = type(record) == 'table' and record.speed or nil
    speed = number(speed)
    return speed ~= nil and speed ~= 0
end

local WAIT_STEP, WAIT_MAX, WAIT_REUSE = 1, 10, 0.5
local lastWait = { at = -1 }

-- Finds the next step that can be cast in the projected state, judged by the preview's own readiness options, moving the projected time forward a second at a time while
-- nothing is ready (everything is cooling down), for at most WAIT_MAX seconds.
-- @param rot table  The rotation body.
-- @return table|nil  The step as pickStep returns it; nil when nothing becomes ready in time.
-- @return number  How many seconds the projected time was moved.
local function nextStep(rot)
    state.wake = nil
    local pick = pickStep(rot, {}, addon:NewActionReadiness(state.now, 'preview'))
    local start = state.t

    -- Only a pass that ran to its end found nothing ready; a Stop step, or a pass that could not read, is not waited out.
    -- Time moves to the soonest moment something becomes ready, or a second on when no cooldown says.
    while not pick and forecast.passEnded == 'complete' and state.t - start < WAIT_MAX do
        local step = state.wake and math.max(MIN_STEP, state.wake + 0.01) or WAIT_STEP
        state.t = state.t + math.min(step, WAIT_MAX - (state.t - start) + MIN_STEP)
        retime()
        state.wake = nil
        pick = pickStep(rot, {}, addon:NewActionReadiness(state.now, 'preview'))
    end

    return pick, state.t - start
end

-- Predicts what will be recommended while nothing can be cast now (everything is on cooldown): time is moved forward until
-- a step becomes ready, that is the first slot, and the later slots follow from the state after it. The answer is kept for
-- half a second, since the rotation is asked many times a second and its answer changes slowly.
-- @param rot table  The rotation body being advised from.
-- @param count number  How many slots to predict, 1 to 5.
-- @param stationary boolean|nil  True to predict as if the player stood still (a preview that ignores moving).
-- @return table  A list of { spell, cond, index, item, confidence, at, delay } (at: seconds from now when the player can act
--   again; delay: seconds from now it would be cast); empty when nothing becomes
--   ready within WAIT_MAX seconds, or on failure.
function forecast:Wait(rot, count, stationary)
    local out = {}

    if type(rot) ~= 'table' or type(count) ~= 'number' or count < 1 or state then
        return out
    end

    local clock = GetTime()

    if
        lastWait.rot == rot
        and lastWait.count == count
        and lastWait.stationary == (stationary == true)
        and clock - lastWait.at < WAIT_REUSE
    then
        -- The kept answer is aged: each slot is that much nearer.
        -- Only the wait for the first slot shrinks with time; the casts after it keep their length.
        local first = lastWait.out[1]
        local aged = first and math.min(clock - lastWait.at, first.base) or 0

        for _, slot in ipairs(lastWait.out) do
            slot.delay = math.max(0, slot.base - aged)
        end

        return lastWait.out
    end

    warmCosts(rot)

    local ok, err = pcall(function()
        state = newState(clock)
        state.rot = rot
        state.stationary = stationary == true
        install()
        local confidence = state.confidence

        for slot = 1, math.min(5, count) do
            local pick, waited = nextStep(rot)

            if not pick then
                break
            end

            local cast = state.t
            confidence = confidence * STEP_CONFIDENCE * apply(pick.spell, pick.item) * WAIT_DECAY ^ waited

            out[#out + 1] = {
                spell = pick.spell,
                cond = pick.cond,
                index = pick.index,
                item = pick.item,
                confidence = math.max(0.05, math.min(1, confidence)),
                at = state.t,
                delay = cast,
                base = cast,
            }
        end
    end)

    uninstall()

    forecast.lastError = not ok and tostring(err) or nil

    if not ok then
        pcall(addon.verbose, addon, 'Forecast wait failed: ' .. tostring(err))
        out = {}
    end

    lastWait.rot, lastWait.count, lastWait.at, lastWait.out = rot, count, clock, out
    lastWait.stationary = stationary == true
    return out
end

-- Predicts the recommendations after the first.
-- @param rot table  The rotation body being advised from.
-- @param first number  The first recommendation's spell (the one about to be cast).
-- @param count number  How many more to predict, 1 to 4.
-- @param remaining number|nil  Seconds a cast of `first` already under way has left; its time is then counted from now.
-- @return table  A list of { spell, cond, index, item, confidence, at } for the predicted slots (shorter than count when
--   a pass finds nothing); empty on failure.
function forecast:Run(rot, first, count, remaining)
    local out = {}

    if type(rot) ~= 'table' or type(first) ~= 'number' or type(count) ~= 'number' or count < 1 or state then
        return out
    end

    warmCosts(rot)

    local ok, err = pcall(function()
        state = newState(GetTime())
        state.rot = rot
        install()

        if remaining and remaining >= 0 then
            -- A cast under way ends `remaining` from now, whatever its full length: it started that long before.
            state.t = remaining - stepLength(first)
        end

        local confidence = state.confidence * apply(first, itemOf(first))
        local previous = first
        local ceiling = 1
        forecast.lastWaited = 0

        for slot = 1, math.min(4, count) do
            local pick, waited = nextStep(rot)

            if not pick then
                break
            end

            confidence = confidence * STEP_CONFIDENCE * WAIT_DECAY ^ waited
            forecast.lastWaited = forecast.lastWaited + waited

            if pick.spell == previous then
                confidence = confidence * REPEAT_PENALTY
            end

            local cast = state.t
            local factor = apply(pick.spell, pick.item)
            confidence = confidence * factor
            local measured = addon.Metrics and addon.Metrics.PredictionRate and addon.Metrics:PredictionRate(slot + 1)
            local shown = measured and (confidence + measured) / 2 or confidence

            -- A later step only comes true if the earlier ones did, so it is never surer than they were.
            shown = math.min(shown, ceiling)
            ceiling = shown

            out[#out + 1] = {
                spell = pick.spell,
                cond = pick.cond,
                index = pick.index,
                item = pick.item,
                confidence = math.max(0.05, math.min(1, shown)),
                at = state.t,
                delay = cast,
            }

            previous = pick.spell
        end
    end)

    uninstall()

    forecast.lastError = not ok and tostring(err) or nil

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
