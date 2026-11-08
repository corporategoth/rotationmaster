-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug spells: checks, read only, every spell ID the shipped premades for this character name against this client
-- and lists the ones the client does not know. A premade's spell IDs come from guides and research, not from the
-- client, so an ID that belongs to another edition (a Season of Discovery rune, a Retail talent) shows up here. It lists
-- the action of every spell, pet and "any" step and the numeric spell of every condition (a totem condition names a slot
-- and is skipped). It changes no saved data and casts nothing. The report is plain English like the other debug reports.
-- Loaded from RotationMaster.toc after Diagnostics/raid_marks.lua; Diagnostics/glow.lua routes /rm debug spells here.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Records where a spell ID is named.
-- @param found table  Spell ID -> list of places.
-- @param id number  The spell ID.
-- @param where string  A short description of the place.
local function note(found, id, where)
    local places = found[id]

    if not places then
        places = {}
        found[id] = places
    end

    if #places < 4 then
        places[#places + 1] = where
    end
end

-- Collects every spell ID a premade body names, with where.
-- @param node any  A step, a condition, or a list of them.
-- @param found table  Spell ID -> list of places; filled in.
local function collect(node, found)
    if type(node) ~= 'table' then
        return
    end

    local kind = node.type

    if (kind == 'spell' or kind == 'pet' or kind == 'any') and type(node.action) == 'number' then
        note(found, node.action, 'step ' .. tostring(node.id))
    elseif type(kind) == 'string' and kind:match('^[A-Z_]+$') and kind ~= 'TOTEM' and type(node.spell) == 'number' then
        note(found, node.spell, 'condition ' .. kind)
    end

    for _, child in pairs(node) do
        if type(child) == 'table' then
            collect(child, found)
        end
    end
end

-- Builds the report lines.
-- @return string[]  The report, one string per line.
-- @return number  How many spell IDs the client did not know.
function addon:BuildPremadeSpellDiagnostic()
    local platform = self.Platform
    local lines, unknown, checked = {}, 0, 0
    local info = platform and platform.GetClientInfo and platform:GetClientInfo() or {}
    lines[#lines + 1] = string.format('== Premade spell IDs on %s', tostring(info.family))

    if type(self.GetBuiltinStates) ~= 'function' or not platform or type(platform.GetSpellInfo) ~= 'function' then
        lines[#lines + 1] = 'The premade list or the spell reader is not available in this build.'
        return lines, 0
    end

    local rows = self:GetBuiltinStates(self.currentSpec or 0) or {}

    for _, row in ipairs(rows) do
        if row.fits and type(row.body) == 'table' then
            local found, ids, missing = {}, {}, {}
            collect(row.body, found)
            checked = checked + 1

            for id in pairs(found) do
                ids[#ids + 1] = id
            end

            table.sort(ids)

            for _, id in ipairs(ids) do
                if platform:GetSpellInfo(id) == nil then
                    missing[#missing + 1] = string.format('  %s: %s', tostring(id), table.concat(found[id], ', '))
                end
            end

            if #missing > 0 then
                unknown = unknown + #missing

                lines[#lines + 1] = string.format(
                    '%s: %d spell ID(s) unknown to this client',
                    tostring(row.id),
                    #missing
                )

                for _, line in ipairs(missing) do
                    lines[#lines + 1] = line
                end
            end
        end
    end

    lines[#lines + 1] = string.format(
        '%d premade(s) checked, %d unknown spell ID(s). An ID the client knows may still not be learnable by this class.',
        checked,
        unknown
    )

    return lines, unknown
end

-- Saves the report (in RotationMasterDB.diagnostics.spells) and opens it in the copyable window; chat gets only the total.
-- @return number  How many spell IDs the client did not know.
function addon:RunPremadeSpellDiagnostic()
    local lines, unknown = self:BuildPremadeSpellDiagnostic()
    local global = self.db and self.db.global

    if global then
        global.diagnostics = global.diagnostics or {}
        global.diagnostics.spells = { lines = lines, at = type(time) == 'function' and time() or 0 }
    end

    self:ShowPremadeSpellDiagnostic(lines)
    self:print('%s', lines[#lines])
    return unknown
end

-- Opens the saved report (or the lines given) in the copyable window.
-- @param lines string[]|nil  The lines to show; nil shows the last saved report.
function addon:ShowPremadeSpellDiagnostic(lines)
    local saved = self.db and self.db.global and self.db.global.diagnostics and self.db.global.diagnostics.spells

    lines = lines or saved and saved.lines

    if not lines then
        self:print('No premade spell report is saved yet. Run /rm debug spells.')
        return
    end

    if self.ShowConditionText then
        self:ShowConditionText(table.concat(lines, '\n'), L['Diagnostics'])
    end
end
