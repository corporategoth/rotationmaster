-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Metrics: how closely the player follows a rotation's advice, how long they take to act on it, what they cast
-- instead, and how much damage and healing a fight produced. Pure bookkeeping: no WoW API, no frames, no events, no
-- allocation per call after the first record of a spell (docs/architecture/metrics.md). Platform/metrics_events.lua feeds
-- it; UI/metrics_report.lua shows and exports it. The numbers live in RotationMasterDB.global.metrics, bounded: at most
-- MAX_ROTATIONS rotations, MAX_SPELLS advised spells each, MAX_DEVIATIONS replacements per spell, RING fights per
-- rotation, and the last RECENT fights each in full (what a report of the last fight, this instance or the last half
-- hour is made of). Nothing here identifies a character, a target or a realm.
-- Loaded from RotationMaster.toc after Analytics/capture.lua.

local _, addon = ...

local metrics = {}
addon.Metrics = metrics

-- The wall clock in seconds (the game's time()); a test sets its own.
metrics.clock = rawget(_G, 'time') or function()
    return 0
end

-- When this session began (the addon loading: logging in or reloading the interface), the start of the "this session" period.
metrics.session = metrics.clock()

local MAX_ROTATIONS, MAX_SPELLS, MAX_DEVIATIONS, RING = 24, 64, 8, 40
local RECENT, FIGHT_SPELLS, FIGHT_DEVIATIONS = 300, 24, 4
local MIN_FIGHT, MAX_DELAY = 8, 30
local FORMAT, VERSION = 'rm-metrics', 1

-- Upper edges, in seconds, of the delay histogram's buckets; the last bucket is everything slower.
local EDGES = { 0.25, 0.5, 1, 2, 4 }
metrics.DELAY_EDGES = EDGES

-- The volatile state of the running fight: nil outside combat.
local fight
-- The advice the player is looking at: the spell, when it appeared, and the rotation it came from.
local adviceSpell, adviceAt, adviceRotation
-- Forecasts waiting to be compared with what is highlighted next (see Predicted), whether prediction tracking is on, and
-- the forecast taken for the advice now showing.
local pending, predicting, epochForecast = {}, false, nil
local MAX_PENDING, MAX_SLOT = 4, 5

-- Returns the saved metrics table, creating it.
-- @return table|nil  { version, rotations = { [id] = record } }; nil before the saved variables exist.
local function store()
    local db = addon.db

    if not db or not db.global then
        return nil
    end

    local saved = db.global.metrics

    if type(saved) ~= 'table' or saved.version ~= VERSION or type(saved.rotations) ~= 'table' then
        saved = { version = VERSION, rotations = {}, order = {} }
        db.global.metrics = saved
    end

    return saved
end

-- The wall clock in seconds, for stamping a fight so a report can be limited to a period.
-- @return number  Seconds since 1970.
local function epoch()
    return metrics.clock()
end

-- A record with no fights, in the shape of a rotation's (without the ring and the prediction rows): the running fight is
-- tallied into one, and a report of a period is the sum of the fights' records.
-- @return table  The empty record.
local function blank()
    return {
        fights = 0,
        seconds = 0,
        damage = 0,
        healing = 0,
        casts = 0,
        followed = 0,
        deviations = 0,
        unadvised = 0,
        superseded = 0,
        delaySum = 0,
        delayN = 0,
        hist = { 0, 0, 0, 0, 0, 0 },
        spells = {},
    }
end

-- Returns a rotation's record, creating it (and dropping the least recently used rotation when full).
-- @param id string  The rotation id.
-- @return table|nil  The record.
local function record(id)
    local saved = store()

    if not saved or type(id) ~= 'string' then
        return nil
    end

    local rec = saved.rotations[id]

    if rec then
        return rec
    end

    if #saved.order >= MAX_ROTATIONS then
        local dropped = table.remove(saved.order, 1)
        saved.rotations[dropped] = nil
    end

    rec = {
        fights = 0,
        seconds = 0,
        damage = 0,
        healing = 0,
        casts = 0,
        followed = 0,
        deviations = 0,
        unadvised = 0,
        superseded = 0,
        delaySum = 0,
        delayN = 0,
        hist = { 0, 0, 0, 0, 0, 0 },
        spells = {},
        ring = {},
        ringNext = 1,
        predict = {},
    }

    saved.rotations[id] = rec
    saved.order[#saved.order + 1] = id
    return rec
end

-- Returns the per-spell record of an advised spell, creating it up to the cap.
-- @param rec table  The rotation record, or a fight's.
-- @param spell number  The spell id.
-- @param cap number|nil  The most spells the record may hold; MAX_SPELLS by default.
-- @return table|nil  { followed, delaySum, superseded, replaced = { [spell] = count } }; nil when full.
local function spellRecord(rec, spell, cap)
    local entry = rec.spells[spell]

    if entry then
        return entry
    end

    local count = 0

    for _ in pairs(rec.spells) do
        count = count + 1
    end

    if count >= (cap or MAX_SPELLS) then
        return nil
    end

    entry = { followed = 0, delaySum = 0, superseded = 0, replaced = {} }
    rec.spells[spell] = entry
    return entry
end

-- Adds one to a capped counter map.
-- @param map table  The map spell -> count.
-- @param key number  The spell id.
-- @param cap number  The most keys the map may hold.
local function bump(map, key, cap)
    if map[key] then
        map[key] = map[key] + 1
        return
    end

    local count = 0

    for _ in pairs(map) do
        count = count + 1
    end

    if count < cap then
        map[key] = 1
    end
end

-- Finds the histogram bucket of a delay.
-- @param delay number  Seconds.
-- @return number  1 to 6.
local function bucket(delay)
    for index, edge in ipairs(EDGES) do
        if delay < edge then
            return index
        end
    end

    return #EDGES + 1
end

-- The spell currently advised, as far as the recorder knows.
-- @return number|nil  The spell id.
function metrics:CurrentAdvice()
    return adviceSpell
end

-- Whether collection is running (a fight is open).
-- @return boolean  True during a fight.
function metrics:IsInFight()
    return fight ~= nil
end

-- Records that the recommended spell changed (or was cleared).
-- @param rotation string|nil  The active rotation id.
-- @param spell number|nil  The new first recommendation; nil when nothing is advised.
-- @param now number  The time in seconds.
--
-- The previous advice counts as superseded when it was shown during a fight and never acted on.
function metrics:Advice(rotation, spell, now)
    if fight and adviceSpell and adviceAt and spell ~= adviceSpell then
        local rec = record(adviceRotation)
        local entry = rec and spellRecord(rec, adviceSpell)

        if entry then
            entry.superseded = entry.superseded + 1
            rec.superseded = rec.superseded + 1
        end

        local inFight = spellRecord(fight.rec, adviceSpell, FIGHT_SPELLS)

        if inFight then
            inFight.superseded = inFight.superseded + 1
            fight.rec.superseded = fight.rec.superseded + 1
        end
    end

    if spell == adviceSpell and rotation == adviceRotation then
        return
    end

    if predicting and fight and spell then
        metrics:ResolvePredictions(rotation, spell)
    end

    adviceSpell, adviceRotation = spell, rotation
    adviceAt = spell and now or nil
    epochForecast = nil

    if fight and spell and rotation then
        local rec = record(rotation)

        if rec then
            spellRecord(rec, spell)
            spellRecord(fight.rec, spell, FIGHT_SPELLS)
        end
    end

    if fight and rotation then
        fight.rotation = rotation
    end
end

-- Records a spell the player pressed.
-- @param spell number  The spell id.
-- @param now number  The time in seconds.
--
-- Followed when it is the advised spell (the delay is how long after the advice appeared). A deviation otherwise, and
-- what replaced the advised spell is kept; whether the replacement is a spell the rotation also suggests is worked out
-- in the report, once the whole rotation's advice is known. Unadvised when nothing was advised.
function metrics:Cast(spell, now)
    if not fight or type(spell) ~= 'number' then
        return
    end

    local id = adviceRotation or fight.rotation
    local rec = record(id)

    if not rec then
        return
    end

    local inFight = fight.rec
    rec.casts = rec.casts + 1
    fight.casts = fight.casts + 1
    inFight.casts = inFight.casts + 1

    if adviceSpell == spell then
        local delay = math.max(0, math.min(MAX_DELAY, now - (adviceAt or now)))
        local entry = spellRecord(rec, spell)
        rec.followed = rec.followed + 1
        rec.delaySum = rec.delaySum + delay
        rec.delayN = rec.delayN + 1
        local slot = bucket(delay)
        rec.hist[slot] = rec.hist[slot] + 1

        if entry then
            entry.followed = entry.followed + 1
            entry.delaySum = entry.delaySum + delay
        end

        local fightEntry = spellRecord(inFight, spell, FIGHT_SPELLS)
        inFight.followed = inFight.followed + 1
        inFight.delaySum = inFight.delaySum + delay
        inFight.delayN = inFight.delayN + 1
        inFight.hist[slot] = inFight.hist[slot] + 1

        if fightEntry then
            fightEntry.followed = fightEntry.followed + 1
            fightEntry.delaySum = fightEntry.delaySum + delay
        end

        fight.followed = fight.followed + 1
        fight.delaySum = fight.delaySum + delay
        adviceAt = now
        return
    end

    if not adviceSpell then
        rec.unadvised = rec.unadvised + 1
        inFight.unadvised = inFight.unadvised + 1
        return
    end

    local entry = spellRecord(rec, adviceSpell)
    rec.deviations = rec.deviations + 1
    inFight.deviations = inFight.deviations + 1

    if entry then
        bump(entry.replaced, spell, MAX_DEVIATIONS)
    end

    local fightEntry = spellRecord(inFight, adviceSpell, FIGHT_SPELLS)

    if fightEntry then
        bump(fightEntry.replaced, spell, FIGHT_DEVIATIONS)
    end
end

-- Turns prediction tracking on or off.
-- @param on boolean  True to track how accurate the forecast was.
function metrics:SetPredicting(on)
    predicting = on == true

    if not predicting then
        pending, epochForecast = {}, nil
    end
end

-- Records the forecast made for the advice now showing, to be compared with what is highlighted next. Only the first
-- forecast of each advice counts: that is the one made ahead of time.
-- @param first number  The spell being advised now.
-- @param slots table  The predicted spells for the next highlights, in order.
-- @param confidence table  The confidence shown for each of them, 0 to 1.
function metrics:Predicted(first, slots, confidence)
    if not predicting or not fight or epochForecast or first ~= adviceSpell or #slots == 0 or not adviceRotation then
        return
    end

    local entry = { rotation = adviceRotation, seen = 0, slots = {}, confidence = {} }

    for index = 1, math.min(#slots, MAX_SLOT - 1) do
        entry.slots[index], entry.confidence[index] = slots[index], confidence[index] or 0
    end

    epochForecast = entry
    pending[#pending + 1] = entry

    if #pending > MAX_PENDING then
        table.remove(pending, 1)
    end
end

-- Compares each waiting forecast with the spell that has just become the advice: the first next highlight against the
-- forecast's first prediction, the second against its second, and so on.
-- @param rotation string|nil  The rotation advising now.
-- @param spell number  The spell that became the advice.
function metrics:ResolvePredictions(rotation, spell)
    local kept = {}

    for _, entry in ipairs(pending) do
        entry.seen = entry.seen + 1
        local expected = entry.slots[entry.seen]

        if expected ~= nil and entry.rotation == rotation then
            local rec = record(entry.rotation)

            if rec then
                local slot = entry.seen + 1
                local row = rec.predict[slot]

                if not row then
                    row = { 0, 0, 0 }
                    rec.predict[slot] = row
                end

                row[1] = row[1] + 1
                row[2] = row[2] + (expected == spell and 1 or 0)
                row[3] = row[3] + entry.confidence[entry.seen]
            end
        end

        if entry.seen < #entry.slots and entry.rotation == rotation then
            kept[#kept + 1] = entry
        end
    end

    pending = kept
end

-- How often the forecast's prediction for a slot turned out right, over everything recorded.
-- @param slot number  2 to 5 (the first recommendation is not predicted).
-- @return number|nil  The hit rate from 0 to 1; nil until 20 predictions have been checked.
function metrics:PredictionRate(slot)
    local saved = store()

    if not saved then
        return nil
    end

    local total, hits = 0, 0

    for _, rec in pairs(saved.rotations) do
        local row = rec.predict and rec.predict[slot]

        if row then
            total, hits = total + row[1], hits + row[2]
        end
    end

    return total >= 20 and hits / total or nil
end

-- Records damage or healing done by the player during the fight.
-- @param damage number  Damage done.
-- @param healing number  Healing done (effective).
function metrics:Output(damage, healing)
    if fight then
        fight.damage = fight.damage + damage
        fight.healing = fight.healing + healing
    end
end

-- Starts a fight.
-- @param now number  The time in seconds.
-- @param where table|nil  Where it is: { instance = a key for the instance or zone, name = its name }.
function metrics:FightStart(now, where)
    fight = {
        startedAt = now,
        rotation = adviceRotation,
        casts = 0,
        followed = 0,
        delaySum = 0,
        damage = 0,
        healing = 0,
        rec = blank(),
        instance = where and where.instance or nil,
        instanceName = where and where.name or nil,
    }
end

-- Names the encounter the running fight belongs to (a boss fight the game announced).
-- @param name string|nil  The encounter's name.
function metrics:Encounter(name)
    if fight and type(name) == 'string' then
        fight.encounter = name
    end
end

-- Ends the fight and files it under the rotation that was active.
-- @param now number  The time in seconds.
-- @return boolean  True when a fight long enough to count was filed.
function metrics:FightEnd(now)
    local done = fight
    fight = nil
    pending, epochForecast = {}, nil

    if not done or not done.rotation then
        return false
    end

    local duration = now - done.startedAt

    if duration < MIN_FIGHT or done.casts == 0 then
        return false
    end

    local rec = record(done.rotation)

    if not rec then
        return false
    end

    rec.fights = rec.fights + 1
    rec.seconds = rec.seconds + duration
    rec.damage = rec.damage + done.damage
    rec.healing = rec.healing + done.healing

    rec.ring[rec.ringNext] = {
        math.floor(duration + 0.5),
        math.floor(done.damage),
        math.floor(done.healing),
        done.casts,
        done.followed,
    }

    rec.ringNext = rec.ringNext % RING + 1

    -- The fight in full, for reports of a period: the last RECENT of them are kept.
    local saved = store()
    local filed = done.rec
    filed.fights, filed.seconds = 1, duration
    filed.damage, filed.healing = done.damage, done.healing
    filed.id, filed.t = done.rotation, epoch()
    filed.instance, filed.instanceName, filed.encounter = done.instance, done.instanceName, done.encounter
    saved.recent = saved.recent or {}
    saved.recent[#saved.recent + 1] = filed

    while #saved.recent > RECENT do
        table.remove(saved.recent, 1)
    end

    return true
end

-- Adds one fight's record to a sum of them.
-- @param into table  The sum, made by blank().
-- @param fightRec table  One fight's record.
local function merge(into, fightRec)
    for _, key in ipairs({
        'fights', 'seconds', 'damage', 'healing', 'casts', 'followed', 'deviations', 'unadvised', 'superseded',
        'delaySum', 'delayN'
    }) do
        into[key] = into[key] + (fightRec[key] or 0)
    end

    for index = 1, 6 do
        into.hist[index] = into.hist[index] + (fightRec.hist[index] or 0)
    end

    for spell, entry in pairs(fightRec.spells) do
        local sum = spellRecord(into, spell)

        if sum then
            sum.followed = sum.followed + entry.followed
            sum.delaySum = sum.delaySum + entry.delaySum
            sum.superseded = sum.superseded + entry.superseded

            for cast, count in pairs(entry.replaced) do
                local seen = sum.replaced[cast]

                if seen then
                    sum.replaced[cast] = seen + count
                else
                    local kept = 0

                    for _ in pairs(sum.replaced) do
                        kept = kept + 1
                    end

                    if kept < MAX_DEVIATIONS then
                        sum.replaced[cast] = count
                    end
                end
            end
        end
    end
end

-- Tells whether a stored fight is inside a scope.
-- @param entry table  A stored fight.
-- @param scope table  { kind = "last" | "previous" | "session" | "instance" | "minutes" | "before", minutes = number,
--   instance = a key }: the newest fight, the one before it, since this session began, an instance (the key given, else
--   the current one), the last `minutes`, or the `minutes` before those.
-- @param context table  What is true now: { instance = the current instance's key, now = the wall clock, newest, previous,
--   session = when the session began }.
-- @return boolean  True when the fight belongs to the scope.
local function inScope(entry, scope, context)
    local kind = scope.kind

    if kind == 'last' then
        return entry.t == context.newest
    elseif kind == 'previous' then
        return context.previous ~= nil and entry.t == context.previous
    elseif kind == 'session' then
        return entry.t >= context.session
    elseif kind == 'instance' then
        local key = scope.instance or context.instance
        return entry.instance ~= nil and entry.instance == key
    elseif kind == 'minutes' then
        return entry.t >= context.now - (scope.minutes or 30) * 60
    elseif kind == 'before' then
        local span = (scope.minutes or 30) * 60
        return entry.t < context.now - span and entry.t >= context.now - 2 * span
    end

    return true
end

-- Sums the stored fights of a scope, one record for each rotation.
-- @param scope table  See inScope.
-- @param context table|nil  What is true now; the clock is read when none is given.
-- @return table  Rotation id -> summed record (with ring rows for the fight list), and the ids in order of first fight.
-- @return string[]  The rotation ids.
local function scoped(scope, context)
    local saved = store()
    local sums, order = {}, {}

    if not saved or not saved.recent then
        return sums, order
    end

    context = context or {}
    context.now = context.now or epoch()
    context.session = context.session or metrics.session
    local newest, previous = 0, nil

    for _, entry in ipairs(saved.recent) do
        newest = math.max(newest, entry.t or 0)
    end

    for _, entry in ipairs(saved.recent) do
        if (entry.t or 0) < newest and (previous == nil or entry.t > previous) then
            previous = entry.t
        end
    end

    context.newest, context.previous = newest, previous

    for _, entry in ipairs(saved.recent) do
        if entry.id and inScope(entry, scope, context) then
            local sum = sums[entry.id]

            if not sum then
                sum = blank()
                sum.ring, sum.ringNext, sum.predict, sum.rows = {}, 1, {}, 0
                sums[entry.id] = sum
                order[#order + 1] = entry.id
            end

            merge(sum, entry)
            sum.rows = sum.rows + 1

            sum.ring[(sum.rows - 1) % RING + 1] = {
                math.floor(entry.seconds + 0.5),
                math.floor(entry.damage),
                math.floor(entry.healing),
                entry.casts,
                entry.followed,
            }

            sum.ringNext = sum.rows % RING + 1
        end
    end

    return sums, order
end

-- Lists the instances fights were recorded in, newest first, for choosing one to compare with.
-- @return table[]  { { key, name, fights, t } } where t is when the newest fight there ended.
function metrics:Instances()
    local saved = store()
    local found, out = {}, {}

    for _, entry in ipairs(saved and saved.recent or {}) do
        if entry.instance then
            local item = found[entry.instance]

            if not item then
                item = { key = entry.instance, name = entry.instanceName, fights = 0, t = 0 }
                found[entry.instance] = item
                out[#out + 1] = item
            end

            item.fights = item.fights + 1
            item.t = math.max(item.t, entry.t or 0)
            item.name = entry.instanceName or item.name
        end
    end

    table.sort(out, function(a, b)
        return a.t > b.t or a.t == b.t and tostring(a.key) < tostring(b.key)
    end)

    return out
end

-- Forgets the volatile advice and fight, without filing anything (used when collection stops).
function metrics:Reset()
    fight, adviceSpell, adviceAt, adviceRotation = nil, nil, nil, nil
    pending, epochForecast = {}, nil
end

-- Deletes every saved number.
function metrics:Clear()
    local db = addon.db

    if db and db.global then
        db.global.metrics = nil
    end

    self:Reset()
end

-- Whether anything has been recorded.
-- @return boolean  True when at least one rotation has a record.
function metrics:HasData()
    local saved = store()
    return saved ~= nil and #saved.order > 0
end

-- Rounds to one decimal place.
-- @param value number  The number.
-- @return number  The rounded number.
local function round(value)
    return math.floor(value * 10 + 0.5) / 10
end

-- Builds the plain-table summary of one rotation record, with the figures worked out.
-- @param id string  The rotation id.
-- @param rec table  The record.
-- @param name string|nil  The rotation's display name.
-- @param spellName function|nil  Called with a spell id and returning its name.
-- @return table  { id, name, fights, seconds, casts, followedPercent, meanDelay, dps, hps, ... }.
local function summarize(id, rec, name, spellName)
    local casts = rec.casts

    local out = {
        id = id,
        name = name,
        fights = rec.fights,
        seconds = round(rec.seconds),
        casts = casts,
        followed = rec.followed,
        outOfOrder = 0,
        outside = 0,
        unadvised = rec.unadvised,
        superseded = rec.superseded,
        followedPercent = casts > 0 and round(rec.followed * 100 / casts) or nil,
        meanDelay = rec.delayN > 0 and round(rec.delaySum / rec.delayN * 100) / 100 or nil,
        delayHistogram = { rec.hist[1], rec.hist[2], rec.hist[3], rec.hist[4], rec.hist[5], rec.hist[6] },
        dps = rec.seconds > 0 and math.floor(rec.damage / rec.seconds) or nil,
        hps = rec.seconds > 0 and math.floor(rec.healing / rec.seconds) or nil,
        spells = {},
        outsideSpells = {},
        fightList = {},
        predictionAccuracy = {},
    }

    for slot = 2, MAX_SLOT do
        local row = rec.predict and rec.predict[slot]

        if row and row[1] > 0 then
            out.predictionAccuracy[#out.predictionAccuracy + 1] = {
                slot = slot,
                checked = row[1],
                hitPercent = round(row[2] * 100 / row[1]),
                meanConfidencePercent = round(row[3] * 100 / row[1]),
            }
        end
    end

    local outsideTotals = {}

    for spell, entry in pairs(rec.spells) do
        local replaced = {}

        for cast, count in pairs(entry.replaced) do
            if rec.spells[cast] then
                out.outOfOrder = out.outOfOrder + count
            else
                outsideTotals[cast] = (outsideTotals[cast] or 0) + count
            end

            replaced[#replaced + 1] = { spell = cast, name = spellName and spellName(cast) or nil, count = count }
        end

        table.sort(replaced, function(a, b)
            return a.count > b.count or a.count == b.count and a.spell < b.spell
        end)

        out.spells[#out.spells + 1] = {
            spell = spell,
            name = spellName and spellName(spell) or nil,
            followed = entry.followed,
            meanDelay = entry.followed > 0 and round(entry.delaySum / entry.followed * 100) / 100 or nil,
            superseded = entry.superseded,
            replacedBy = replaced,
        }
    end

    table.sort(out.spells, function(a, b)
        return a.followed + a.superseded > b.followed + b.superseded
            or a.followed + a.superseded == b.followed + b.superseded and a.spell < b.spell
    end)

    for spell, count in pairs(outsideTotals) do
        out.outside = out.outside + count

        out.outsideSpells[#out.outsideSpells + 1] = {
            spell = spell,
            name = spellName and spellName(spell) or nil,
            count = count,
        }
    end

    -- Replacements beyond the per-spell cap are still deviations; they are outside what is listed.
    out.outside = out.outside + math.max(0, rec.deviations - out.outOfOrder - out.outside)

    table.sort(out.outsideSpells, function(a, b)
        return a.count > b.count or a.count == b.count and a.spell < b.spell
    end)

    for index = 1, RING do
        local row = rec.ring[(rec.ringNext - 1 + index - 1) % RING + 1]

        if row then
            out.fightList[#out.fightList + 1] = {
                seconds = row[1],
                damage = row[2],
                healing = row[3],
                casts = row[4],
                followed = row[5],
            }
        end
    end

    -- Output by how closely the fight followed the advice: three tiers, each shown only with three or more fights.
    local tiers = { { 'low', 0, 60 }, { 'middle', 60, 85 }, { 'high', 85, 101 } }
    out.byAdherence = {}

    for _, tier in ipairs(tiers) do
        local seconds, damage, healing, count = 0, 0, 0, 0

        for _, fightRow in ipairs(out.fightList) do
            local percent = fightRow.casts > 0 and fightRow.followed * 100 / fightRow.casts or 0

            if percent >= tier[2] and percent < tier[3] then
                seconds, damage, healing, count =
                    seconds + fightRow.seconds, damage + fightRow.damage, healing + fightRow.healing, count + 1
            end
        end

        if count >= 3 and seconds > 0 then
            out.byAdherence[#out.byAdherence + 1] = {
                tier = tier[1],
                fights = count,
                dps = math.floor(damage / seconds),
                hps = math.floor(healing / seconds),
            }
        end
    end

    return out
end

-- Builds the report: one summary per rotation, most fought first.
-- @param names function|nil  Called with a rotation id and returning its display name.
-- @param spellName function|nil  Called with a spell id and returning its name.
-- @param scope table|nil  Which fights to count: { kind = "last" } (the newest fight), "previous" (the one before it),
--   "session" (since this session began), { kind = "instance" } (those in the instance or zone named by scope.instance,
--   else context.instance), { kind = "minutes", minutes = n } (the last n minutes), "before" (the n minutes before those)
--   or nil or { kind = "all" } is everything ever recorded.
-- @param context table|nil  What is true now for a scope: { instance = the key of where the player is, now = wall clock }.
-- @return table  { format, version, scope, rotations = { summary, ... } }.
function metrics:Report(names, spellName, scope, context)
    local saved = store()
    local report = { format = FORMAT, version = VERSION, rotations = {}, scope = scope and scope.kind or 'all' }

    if not saved then
        return report
    end

    if scope and scope.kind ~= 'all' then
        local sums, order = scoped(scope, context)

        for _, id in ipairs(order) do
            report.rotations[#report.rotations + 1] = summarize(id, sums[id], names and names(id) or nil, spellName)
        end

        table.sort(report.rotations, function(a, b)
            return a.fights > b.fights or a.fights == b.fights and a.id < b.id
        end)

        return report
    end

    for _, id in ipairs(saved.order) do
        local rec = saved.rotations[id]

        if rec then
            report.rotations[#report.rotations + 1] = summarize(id, rec, names and names(id) or nil, spellName)
        end
    end

    table.sort(report.rotations, function(a, b)
        return a.fights > b.fights or a.fights == b.fights and a.id < b.id
    end)

    return report
end

-- ============================================================================
-- Export
-- ============================================================================

-- Quotes a string for JSON.
-- @param text string  The text.
-- @return string  The JSON string literal.
local function quote(text)
    return '"'
        .. text:gsub('[%c"\\]', function(c)
            local named = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r' }
            return named[c] or string.format('\\u%04x', c:byte())
        end)
        .. '"'
end

-- Encodes a plain value (nested tables of numbers, strings, booleans) as JSON. A table whose keys are 1..n is an array,
-- any other is an object with its keys in sorted order so the output is stable.
-- @param value any  The value.
-- @param out table  The list of pieces being built.
local function encode(value, out)
    local kind = type(value)

    if kind == 'number' then
        out[#out + 1] = (value % 1 == 0 and math.abs(value) < 1e15) and string.format('%d', value) or string.format(
            '%.4g',
            value
        )
    elseif kind == 'string' then
        out[#out + 1] = quote(value)
    elseif kind == 'boolean' then
        out[#out + 1] = value and 'true' or 'false'
    elseif kind == 'table' then
        local n = #value

        if n > 0 or next(value) == nil then
            out[#out + 1] = '['

            for index = 1, n do
                if index > 1 then
                    out[#out + 1] = ','
                end

                encode(value[index], out)
            end

            out[#out + 1] = ']'
        else
            local keys = {}

            for key in pairs(value) do
                keys[#keys + 1] = key
            end

            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)

            out[#out + 1] = '{'

            for index, key in ipairs(keys) do
                if index > 1 then
                    out[#out + 1] = ','
                end

                out[#out + 1] = quote(tostring(key))
                out[#out + 1] = ':'
                encode(value[key], out)
            end

            out[#out + 1] = '}'
        end
    else
        out[#out + 1] = 'null'
    end
end

-- Encodes a report as JSON.
-- @param report table  The result of Report.
-- @param client table|nil  Plain facts about the client to include ({ family = "tbc", interface = 20506 }).
-- @return string  The JSON text.
function metrics:ToJSON(report, client)
    local copy = { format = report.format, version = report.version, rotations = report.rotations, client = client }
    local out = {}
    encode(copy, out)
    return table.concat(out)
end

-- The instructions that go in front of the data when it is meant for a language model.
local PROMPT = [[
Below is data collected by the World of Warcraft addon Rotation Master about how I play a rotation. For each rotation:
"followedPercent" is the share of my casts that were the spell the addon was recommending when I pressed; "meanDelay" is
how many seconds after a recommendation appeared I acted on it (the global cooldown is part of that); "outOfOrder" are
casts of a spell the rotation does recommend, just not at that moment; "outside" are casts of spells the rotation never
recommends; "replacedBy" lists, for each recommended spell, what I cast instead; "byAdherence" compares damage or
healing per second in fights where I followed the advice closely and loosely. "predictionAccuracy" says how often the addon's forecast of the 2nd, 3rd... next recommendation matched what was then recommended ("meanConfidencePercent" is how sure it said it was). Spell numbers are WoW spell IDs.

Please tell me: where I deviate most and whether those deviations look deliberate (cooldowns, defensives, movement) or
like mistakes; where the rotation itself seems to be wrong for how I actually play, with the change you would make to
the priority order or conditions; and whether following the advice more closely correlates with better output.
]]

-- Builds the text meant to be pasted to a language model: instructions, then the data.
-- @param report table  The result of Report.
-- @param client table|nil  Plain facts about the client.
-- @return string  The text.
function metrics:ToPrompt(report, client)
    return PROMPT .. '\n' .. self:ToJSON(report, client) .. '\n'
end
