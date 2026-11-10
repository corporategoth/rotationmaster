-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- What the forecast has learned (Platform/forecast_events.lua), as a report in the copyable text window, and the button that
-- forgets it: per spell, the auras it was seen to leave (on the target or on you, for how long, after how many of the casts
-- watched, and whether that is often enough to be projected), the damage and healing it does and, for an item's spell, its
-- cooldown. Opened from the Preview page; nothing here runs on the poll. Loaded from RotationMaster.toc after
-- UI/settings_preview.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Names a spell for the report.
-- @param id number  The spell id.
-- @return string  The spell's name, or its id when the client does not know it.
local function spellName(id)
    local info = addon.Platform and addon.Platform:GetSpellInfo(id)

    return info and type(info.name) == 'string' and info.name or tostring(id)
end

-- Formats how long an aura lasts.
-- @param seconds number|nil  The duration; zero or nil is until removed.
-- @return string  The text.
local function lasts(seconds)
    if type(seconds) == 'number' and seconds > 0 then
        return string.format(L['%d seconds'], math.floor(seconds + 0.5))
    end

    return L['until removed']
end

-- Tells whether what was seen of an aura is what the game's own tables already say a spell leaves, so showing it would add
-- nothing (Lightning Shield leaving Lightning Shield for ten minutes).
-- @param spell number  The spell id.
-- @param aura number  The aura's spell id.
-- @param row table  { unit, duration } as seen.
-- @return boolean  True when the tables list that aura, on that unit, for the same time (within a second).
local function builtIn(spell, aura, row)
    local effects = addon.Forecast and addon.Forecast:Effects(spell)

    for _, known in ipairs(effects and effects.auras or {}) do
        if
            known.aura == aura and known.unit == row.unit and math.abs((known.duration or 0) - (row.duration or 0)) <= 1
        then
            return true
        end
    end

    return false
end

-- Lists what was learned about one spell that the game's tables do not already say.
-- @param entry table  The saved record of the spell.
-- @param spell number  The spell id.
-- @return string[]  The lines (empty when there is nothing worth showing).
local function learnedLines(entry, spell)
    local lines = {}
    local casts = entry.casts or 0
    local seen = type(entry.seen) == 'table' and entry.seen or nil

    if seen then
        local auras = {}

        for aura in pairs(seen) do
            auras[#auras + 1] = aura
        end

        table.sort(auras, function(a, b)
            return seen[a].n > seen[b].n or seen[a].n == seen[b].n and a < b
        end)

        for _, aura in ipairs(auras) do
            local row = seen[aura]
            local proc = row.n / math.max(casts, 2) < 0.5

            if proc or not builtIn(spell, aura, row) then
                local format = row.unit == 'player' and L['    on you: %s, %s, seen after %d of %d casts']
                    or L['    on the target: %s, %s, seen after %d of %d casts']

                local text = string.format(format, spellName(aura), lasts(row.duration), row.n, math.max(casts, row.n))

                -- Seen after fewer than half the casts: a proc, which the forecast does not project.
                lines[#lines + 1] = proc and text .. L[' - a proc, not projected'] or text
            end
        end
    elseif entry.applies and entry.applies.aura and not builtIn(spell, entry.applies.aura, entry.applies) then
        local row = entry.applies

        local format = row.unit == 'player' and L['    on you: %s, %s, seen after %d of %d casts']
            or L['    on the target: %s, %s, seen after %d of %d casts']

        lines[#lines + 1] = string.format(format, spellName(row.aura), lasts(row.duration), row.n or 1, row.n or 1)
    end

    -- A spell watched leaving no aura where the tables say it leaves one is worth knowing; leaving none as they say is not.
    local effects = addon.Forecast and addon.Forecast:Effects(spell)

    if not seen and (entry.none or 0) >= 5 and effects and #effects.auras > 0 then
        lines[#lines + 1] = L['    leaves no aura']
    end
    if entry.damage then
        lines[#lines + 1] = string.format(L['    does about %d damage'], math.floor(entry.damage + 0.5))
    end
    if entry.heal then
        lines[#lines + 1] = string.format(L['    heals you for about %d'], math.floor(entry.heal + 0.5))
    end
    if entry.cooldown then
        lines[#lines + 1] = string.format(L['    cooldown %d seconds'], math.floor(entry.cooldown + 0.5))
    end

    return lines
end

-- Lists the spells the forecast has learned something about that the game's tables do not already say.
-- @return table[]  A list of { id, name, lines }, sorted by name; empty when there is none.
function addon:GetForecastLearnedSpells()
    local saved = addon.db and addon.db.global and addon.db.global.forecast
    local spells = type(saved) == 'table' and type(saved.spells) == 'table' and saved.spells or {}
    local list = {}

    for id, entry in pairs(spells) do
        if type(id) == 'number' and type(entry) == 'table' then
            local lines = learnedLines(entry, id)

            if #lines > 0 then
                list[#list + 1] = { id = id, name = spellName(id), lines = lines, casts = entry.casts or 0 }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end

        return a.id < b.id
    end)

    return list
end

-- Returns the base mana the forecast worked out for the player's level.
-- @return string|nil  A line saying it; nil when none was worked out.
function addon:GetForecastLearnedBase()
    local saved = addon.db and addon.db.global and addon.db.global.forecast
    local base = type(saved) == 'table' and saved.base

    if type(base) == 'table' and type(base.level) == 'number' and type(base.mana) == 'number' then
        return string.format(L['Base mana at level %d: %d'], base.level, math.floor(base.mana + 0.5))
    end
end

-- Builds the report lines.
-- @return string[]  The lines, a heading first; a single explanation when nothing worth showing has been learned.
function addon:BuildForecastLearned()
    local lines = { L['What the forecast has learned'], '' }
    local list = self:GetForecastLearnedSpells()

    if #list == 0 then
        lines[#lines
            + 1] = L['Nothing has been learned yet. With the forecast on, it watches the first twenty casts of each spell.']

        return lines
    end

    for _, spell in ipairs(list) do
        lines[#lines + 1] = string.format(L['%s (%d): %d casts watched'], spell.name, spell.id, spell.casts)

        for _, line in ipairs(spell.lines) do
            lines[#lines + 1] = line
        end
    end

    local base = self:GetForecastLearnedBase()

    if base then
        lines[#lines + 1] = ''
        lines[#lines + 1] = base
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = L["What agrees with the game's own spell tables is not shown."]
    return lines
end

-- Shows what the forecast has learned in the copyable text window.
function addon:ShowForecastLearned()
    if self.ShowConditionText then
        self:ShowConditionText(table.concat(self:BuildForecastLearned(), '\n'), L['What the forecast has learned'])
    end
end

-- Forgets everything the forecast has learned.
function addon:ClearForecast()
    if self.Forecast then
        self.Forecast:Clear()
    end

    self:print(L['Forecast learning cleared.'])
end
