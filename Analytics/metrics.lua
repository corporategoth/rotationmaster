-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Metrics: how closely the player follows a rotation's advice, how long they take to act on it, what they cast
-- instead, and how much damage and healing a fight produced. Pure bookkeeping: no WoW API, no frames, no events, no
-- allocation per call after the first record of a spell (docs/architecture/metrics.md). Platform/metrics_events.lua feeds
-- it; UI/metrics_report.lua shows and exports it. The numbers live in RotationMasterDB.global.metrics, bounded: at most
-- MAX_ROTATIONS rotations, MAX_SPELLS advised spells each, MAX_DEVIATIONS replacements per spell, RING fights per
-- rotation. Nothing here identifies a character, a target or a realm.
-- Loaded from RotationMaster.toc after Analytics/capture.lua.

local _, addon = ...

local metrics = {}
addon.Metrics = metrics

local MAX_ROTATIONS, MAX_SPELLS, MAX_DEVIATIONS, RING = 24, 64, 8, 40
local MIN_FIGHT, MAX_DELAY = 8, 30
local FORMAT, VERSION = 'rm-metrics', 1

-- Upper edges, in seconds, of the delay histogram's buckets; the last bucket is everything slower.
local EDGES = { 0.25, 0.5, 1, 2, 4 }

-- The volatile state of the running fight: nil outside combat.
local fight
-- The advice the player is looking at: the spell, when it appeared, and the rotation it came from.
local adviceSpell, adviceAt, adviceRotation

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
    }

    saved.rotations[id] = rec
    saved.order[#saved.order + 1] = id
    return rec
end

-- Returns the per-spell record of an advised spell, creating it up to the cap.
-- @param rec table  The rotation record.
-- @param spell number  The spell id.
-- @return table|nil  { followed, delaySum, superseded, replaced = { [spell] = count } }; nil when full.
local function spellRecord(rec, spell)
    local entry = rec.spells[spell]

    if entry then
        return entry
    end

    local count = 0

    for _ in pairs(rec.spells) do
        count = count + 1
    end

    if count >= MAX_SPELLS then
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
    end

    if spell == adviceSpell and rotation == adviceRotation then
        return
    end

    adviceSpell, adviceRotation = spell, rotation
    adviceAt = spell and now or nil

    if fight and spell and rotation then
        local rec = record(rotation)

        if rec then
            spellRecord(rec, spell)
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

    rec.casts = rec.casts + 1
    fight.casts = fight.casts + 1

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

        fight.followed = fight.followed + 1
        fight.delaySum = fight.delaySum + delay
        adviceAt = now
        return
    end

    if not adviceSpell then
        rec.unadvised = rec.unadvised + 1
        return
    end

    local entry = spellRecord(rec, adviceSpell)
    rec.deviations = rec.deviations + 1

    if entry then
        bump(entry.replaced, spell, MAX_DEVIATIONS)
    end
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
function metrics:FightStart(now)
    fight = {
        startedAt = now,
        rotation = adviceRotation,
        casts = 0,
        followed = 0,
        delaySum = 0,
        damage = 0,
        healing = 0,
    }
end

-- Ends the fight and files it under the rotation that was active.
-- @param now number  The time in seconds.
-- @return boolean  True when a fight long enough to count was filed.
function metrics:FightEnd(now)
    local done = fight
    fight = nil

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
    return true
end

-- Forgets the volatile advice and fight, without filing anything (used when collection stops).
function metrics:Reset()
    fight, adviceSpell, adviceAt, adviceRotation = nil, nil, nil, nil
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
    }

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
-- @return table  { format, version, rotations = { summary, ... } }.
function metrics:Report(names, spellName)
    local saved = store()
    local report = { format = FORMAT, version = VERSION, rotations = {} }

    if not saved then
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
healing per second in fights where I followed the advice closely and loosely. Spell numbers are WoW spell IDs.

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
