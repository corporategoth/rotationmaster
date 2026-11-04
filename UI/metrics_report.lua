-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shows and exports the numbers addon.Metrics (Analytics/metrics.lua) collected: a readable report, the JSON the website
-- can read, and the same JSON behind instructions for a language model. Each opens in the selectable text window
-- (addon:ShowConditionText) so Ctrl-A, Ctrl-C copies it. The JSON and the model instructions are data, not interface text,
-- and stay in English. Owns no saved data. Loaded from the UI section of RotationMaster.toc; used by
-- UI/settings_general.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

-- Names a spell.
-- @param id number  The spell id.
-- @return string|nil  The spell's name, or nil when the game does not know it.
local function spellName(id)
    local info = platform:GetSpellInfo(id)
    return info and type(info.name) == 'string' and info.name or nil
end

-- Names a rotation.
-- @param id string  The rotation id.
-- @return string|nil  The rotation's name.
local function rotationName(id)
    if type(addon.GetRotationName) ~= 'function' then
        return nil
    end

    local ok, name = pcall(addon.GetRotationName, addon, id)
    return ok and type(name) == 'string' and name or nil
end

-- Describes the client in plain facts for the export.
-- @return table  { family, interface }.
local function clientFacts()
    local info = platform:GetClientInfo()
    return { family = info.family, interface = select(4, GetBuildInfo()) }
end

-- Formats a spell as its name and id.
-- @param entry table  Anything with spell and optional name.
-- @return string  "Name (id)" or the id alone.
local function label(entry)
    return entry.name and string.format('%s (%d)', entry.name, entry.spell) or tostring(entry.spell)
end

-- The labels of the adherence tiers.
local tierNames = {
    low = L['Low adherence'],
    middle = L['Medium adherence'],
    high = L['High adherence'],
}

-- Builds the readable report.
-- @param report table  The result of addon.Metrics:Report.
-- @return string  The text.
local function readable(report)
    local lines = {}

    for _, rotation in ipairs(report.rotations) do
        lines[#lines + 1] = rotation.name or rotation.id

        lines[#lines + 1] = string.format(
            L['%d fights, %d seconds, %d casts'],
            rotation.fights,
            rotation.seconds,
            rotation.casts
        )

        if rotation.followedPercent then
            lines[#lines + 1] = string.format(
                L['Followed the advice for %s%% of casts; %d out of order, %d outside the rotation, %d with no advice'],
                tostring(rotation.followedPercent),
                rotation.outOfOrder,
                rotation.outside,
                rotation.unadvised
            )
        end
        if rotation.meanDelay then
            lines[#lines + 1] = string.format(L['Average time to act on a recommendation: %s seconds'], tostring(
                rotation.meanDelay
            ))
        end
        if rotation.dps then
            lines[#lines + 1] = string.format(
                L['Damage per second: %d, healing per second: %d'],
                rotation.dps,
                rotation.hps or 0
            )
        end

        for _, tier in ipairs(rotation.byAdherence) do
            lines[#lines + 1] = string.format(
                L['%s: %d fights, %d damage per second, %d healing per second'],
                tier.tier,
                tier.fights,
                tier.dps,
                tier.hps
            )
        end

        for index, spell in ipairs(rotation.spells) do
            if index > 12 then
                break
            end

            local replaced = {}

            for position, other in ipairs(spell.replacedBy) do
                if position > 3 then
                    break
                end

                replaced[#replaced + 1] = string.format('%s x%d', label(other), other.count)
            end

            lines[#lines + 1] = string.format(
                L['  %s: followed %d, not acted on %d, instead: %s'],
                label(spell),
                spell.followed,
                spell.superseded,
                #replaced > 0 and table.concat(replaced, ', ') or '-'
            )
        end

        lines[#lines + 1] = ''
    end

    return table.concat(lines, '\n')
end

-- Opens one of the metrics texts in the selectable window.
-- @param kind string  "report", "json" or "prompt".
-- @return boolean  True when a window was shown.
function addon:ShowMetricsExport(kind)
    local metrics = addon.Metrics

    if not metrics or not metrics:HasData() then
        self:print(L['No metrics have been recorded yet.'])
        return false
    end

    local report = metrics:Report(rotationName, spellName)
    local text, title

    if kind == 'json' then
        text, title = metrics:ToJSON(report, clientFacts()), L['Metrics export']
    elseif kind == 'prompt' then
        text, title = metrics:ToPrompt(report, clientFacts()), L['Metrics for a language model']
    else
        text, title = readable(report), L['Rotation metrics']
    end

    return pcall(self.ShowConditionText, self, text, title) == true
end

-- Deletes every recorded number.
function addon:ClearMetrics()
    if addon.Metrics then
        addon.Metrics:Clear()
    end

    self:print(L['Metrics cleared.'])
end
