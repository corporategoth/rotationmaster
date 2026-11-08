-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug preview [seconds|show]: records, for a few seconds, what the preview was given on each poll and why: how the walk
-- ended, what the rotation advised, what the forecast was asked and answered, and what the game said about the cooldown,
-- readiness and usability of the rotation's spells (a hidden value is shown as "secret"). The report is saved in
-- RotationMasterDB.diagnostics.preview and shown only by /rm debug preview show. Nothing is recorded until the command runs.
-- Called from the poll in main.lua through addon:PreviewTrace. Loaded from RotationMaster.toc after Diagnostics/glow.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

local DEFAULT_SECONDS, SAMPLE_EVERY, MAX_LINES, MAX_SPELLS = 20, 0.4, 700, 12

local recording

-- Formats a value for the report.
-- @param value any  The value.
-- @return string  "secret" for a hidden value, "nil", or the value.
local function show(value)
    local platform = addon.Platform

    if platform and type(platform.CanReadValue) == 'function' and not platform:CanReadValue(value) then
        return 'secret'
    end
    if value == nil then
        return 'nil'
    end
    if type(value) == 'number' and value % 1 ~= 0 then
        return string.format('%.2f', value)
    end

    return tostring(value)
end

-- Reads a platform function under pcall.
-- @param name string  The platform method.
-- @param ... any  The arguments.
-- @return any  What it returned first, or "error: ..." text.
-- @return any  What it returned second.
-- @return any  What it returned third.
local function read(name, ...)
    local platform = addon.Platform

    if not platform or type(platform[name]) ~= 'function' then
        return 'absent'
    end

    local ok, a, b, c = pcall(platform[name], platform, ...)

    if not ok then
        return 'error: ' .. tostring(a)
    end

    return a, b, c
end

-- Lists the spell ids of the rotation's top-level steps.
-- @param rot table  The rotation body.
-- @return number[]  Up to MAX_SPELLS distinct spell ids.
local function stepSpells(rot)
    local out, seen = {}, {}

    -- Collects the spell ids of a list of steps, into branches too.
    -- @param list table|nil  The steps.
    local function walk(list)
        for _, step in ipairs(list or {}) do
            if #out >= MAX_SPELLS then
                return
            end

            if step.type == 'branch' then
                walk(step.onTrue or step.ontrue)
                walk(step.onFalse or step.onfalse)
            elseif step.action ~= nil and not step.disabled then
                local ok, ids = pcall(addon.GetSpellIds, addon, step)

                for _, id in ipairs(ok and ids or {}) do
                    if type(id) == 'number' and not seen[id] then
                        seen[id] = true
                        out[#out + 1] = id
                    end
                end
            end
        end
    end

    walk(rot and rot.rotation)
    return out
end

-- Describes one spell's state as the game reports it now.
-- @param id number  The spell id.
-- @return string  A line.
local function spellLine(id)
    local info = read('GetSpellInfo', id)
    local name = type(info) == 'table' and info.name or '?'
    local record, why = read('GetSpellCooldown', id)
    local ready, readyWhy = read('IsSpellReady', id, GetTime())
    local usable, lacks = read('IsSpellUsable', id)
    local cooldown = 'none'

    if type(record) == 'table' then
        cooldown = string.format('start %s duration %s enabled %s', show(record.startTime), show(record.duration), show(
            record.isEnabled
        ))
    elseif record ~= nil then
        cooldown = show(record)
    elseif why then
        cooldown = 'unreadable (' .. tostring(why) .. ')'
    end

    return string.format(
        '    %s (%s): cooldown %s; ready %s%s; usable %s lacks %s',
        name,
        id,
        cooldown,
        show(ready),
        readyWhy and ' (' .. tostring(readyWhy) .. ')' or '',
        show(usable),
        show(lacks)
    )
end

-- Writes down one poll (called from the poll; cheap when nothing is recording).
-- @param info table  { engine, rot, ended, real (the recommendations read now), casting, forecast ("run", "wait" or nil), slots }.
function addon:PreviewTrace(info)
    if not recording or type(info) ~= 'table' then
        return
    end

    local now = GetTime()

    if now - recording.last < SAMPLE_EVERY or #recording.lines >= MAX_LINES then
        return
    end

    recording.last = now
    local lines = recording.lines

    local shown = {}

    for _, slot in ipairs(info.slots or {}) do
        local infoSpell = read('GetSpellInfo', slot.spell)

        shown[#shown + 1] = string.format(
            '%s%s',
            type(infoSpell) == 'table' and infoSpell.name or tostring(slot.spell),
            slot.at and string.format(' @%.1fs', slot.at) or ''
        )
    end

    local gcd = read('GetGlobalCooldown')

    lines[#lines + 1] = string.format(
        '[%.1fs] %s: walk ended %s; rotation advised %d now; casting %s; forecast %s -> %d slot(s)%s; global cooldown %s',
        now - recording.started,
        tostring(info.engine),
        tostring(info.ended),
        info.real or 0,
        tostring(info.casting),
        tostring(info.forecast or 'not asked'),
        #(info.slots or {}),
        #shown > 0 and ' (' .. table.concat(shown, ', ') .. ')' or '',
        type(gcd) == 'table' and show(gcd.duration) or show(gcd)
    )

    for _, id in ipairs(stepSpells(info.rot)) do
        lines[#lines + 1] = spellLine(id)
    end
end

-- Returns the saved diagnostics table, creating it.
-- @return table|nil  The table; nil when the saved variables are not loaded.
local function store()
    local saved = rawget(_G, addon.savedVariableName or 'RotationMasterDB')

    if type(saved) ~= 'table' then
        return nil
    end

    if type(saved.diagnostics) ~= 'table' then
        saved.diagnostics = {}
    end

    return saved.diagnostics
end

-- Saves what was recorded.
local function finish()
    local run = recording
    recording = nil

    if not run then
        return
    end

    local diagnostics = store()
    local lines = run.lines

    if #lines == 0 then
        lines[1] = 'Nothing was polled while recording: is a rotation active?'
    end
    if diagnostics then
        diagnostics.preview = { lines = lines, at = type(time) == 'function' and time() or 0 }
    end

    addon:print('Preview report saved (%d lines). /rm debug preview show opens it.', #lines)
end

-- Starts recording, or opens the saved report.
-- @param rest string|nil  A number of seconds, "show" or empty (twenty seconds).
function addon:RunPreviewDiagnostic(rest)
    if rest == 'show' then
        local diagnostics = store()
        local saved = diagnostics and diagnostics.preview

        if not saved then
            self:print('No preview report is saved yet. Run /rm debug preview.')
            return
        end

        if self.ShowConditionText then
            self:ShowConditionText(table.concat(saved.lines, '\n'), L['Diagnostics'])
        end

        return
    end

    local seconds = math.max(3, math.min(120, tonumber(rest) or DEFAULT_SECONDS))
    recording = { started = GetTime(), last = -1, lines = {} }
    self:print('Recording the preview for %d seconds: cast a few spells. Then /rm debug preview show.', seconds)

    if C_Timer and C_Timer.After then
        local mine = recording

        C_Timer.After(seconds, function()
            if recording == mine then
                finish()
            end
        end)
    end
end
