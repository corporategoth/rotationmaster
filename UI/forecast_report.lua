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

-- Builds the report lines.
-- @return string[]  The lines, a heading first; a single explanation when nothing has been learned.
function addon:BuildForecastLearned()
    local lines = { L['What the forecast has learned'], '' }
    local saved = addon.db and addon.db.global and addon.db.global.forecast
    local spells = type(saved) == 'table' and type(saved.spells) == 'table' and saved.spells or {}
    local ids = {}

    for id, entry in pairs(spells) do
        if type(id) == 'number' and type(entry) == 'table' and next(entry) ~= nil then
            ids[#ids + 1] = id
        end
    end

    if #ids == 0 then
        lines[#lines
            + 1] = L['Nothing has been learned yet. With the forecast on, it watches the first twenty casts of each spell.']

        return lines
    end

    table.sort(ids, function(a, b)
        local x, y = spellName(a), spellName(b)

        if x ~= y then
            return x < y
        end

        return a < b
    end)

    for _, id in ipairs(ids) do
        local entry = spells[id]
        local casts = entry.casts or 0
        lines[#lines + 1] = string.format(L['%s (%d): %d casts watched'], spellName(id), id, casts)

        if type(entry.seen) == 'table' then
            local auras = {}

            for aura in pairs(entry.seen) do
                auras[#auras + 1] = aura
            end

            table.sort(auras, function(a, b)
                return entry.seen[a].n > entry.seen[b].n or entry.seen[a].n == entry.seen[b].n and a < b
            end)

            for _, aura in ipairs(auras) do
                local row = entry.seen[aura]

                local format = row.unit == 'player' and L['    on you: %s, %s, seen after %d of %d casts']
                    or L['    on the target: %s, %s, seen after %d of %d casts']

                local text = string.format(format, spellName(aura), lasts(row.duration), row.n, math.max(casts, row.n))

                -- Seen after fewer than half the casts: a proc, which the forecast does not project.
                if row.n / math.max(casts, 2) < 0.5 then
                    text = text .. L[' - a proc, not projected']
                end

                lines[#lines + 1] = text
            end
        elseif entry.applies and entry.applies.aura then
            local row = entry.applies

            local format = row.unit == 'player' and L['    on you: %s, %s, seen after %d of %d casts']
                or L['    on the target: %s, %s, seen after %d of %d casts']

            lines[#lines + 1] = string.format(format, spellName(row.aura), lasts(row.duration), row.n or 1, row.n or 1)
        elseif (entry.none or 0) > 0 then
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
    end

    local base = type(saved) == 'table' and saved.base

    if type(base) == 'table' and type(base.level) == 'number' and type(base.mana) == 'number' then
        lines[#lines + 1] = ''
        lines[#lines + 1] = string.format(L['Base mana at level %d: %d'], base.level, math.floor(base.mana + 0.5))
    end

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
