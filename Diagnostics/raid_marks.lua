-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug marks: prints, read only, what this client offers for raid marks (which functions and events exist), the
-- raid mark table (mark, GUID, token, reachable, age since last seen), what each mark unit type resolves to now, and the
-- state of the Set Mark step (support, hidden buttons made). It starts the mark watch for the usual lease so the table
-- is current, changes no saved data and sets no mark. The report is plain English like the other debug reports.
-- Loaded from RotationMaster.toc after Diagnostics/timeline.lua; Diagnostics/glow.lua routes /rm debug marks here.
local _, addon = ...

-- Shows a boolean as yes or no, and nil as unknown.
local function yes(value)
    if value == nil then
        return 'unknown'
    end

    return value and 'yes' or 'no'
end

-- Shows any value for the report.
local function show(value)
    if value == nil then
        return '-'
    end

    return tostring(value)
end

-- Builds the report lines.
-- Returns:
--   lines (table): the report, one string per line.
function addon:BuildRaidMarkDiagnostic()
    local platform = self.Platform
    local lines = {}

    -- Appends one formatted line.
    local function add(format, ...)
        lines[#lines + 1] = string.format(format, ...)
    end

    if type(platform) ~= 'table' or type(platform.GetRaidMarkSnapshot) ~= 'function' then
        add('Raid marks are not available in this build.')
        return lines
    end

    local support = platform:GetRaidMarkSupport()
    local caps = platform:GetRaidMarkCapabilities()
    local info = platform:GetClientInfo()
    add('== Raid marks on %s (data policy %s)', show(info.family), show(info.combatDataPolicy))
    add('Reading marks: %s', support and ('unavailable (' .. support .. ')') or 'available')

    add(
        'Functions: GetRaidTargetIndex=%s SetRaidTarget=%s target marker command=%s UnitTokenFromGUID=%s',
        yes(caps.read),
        yes(caps.set),
        yes(caps.command),
        yes(caps.tokenFromGUID)
    )

    local names = {}

    for event in pairs(caps.events) do
        names[#names + 1] = event
    end

    table.sort(names)
    local known = {}

    for _, event in ipairs(names) do
        known[#known + 1] = event .. '=' .. yes(caps.events[event])
    end

    add('Event catalog says: %s', table.concat(known, ' '))
    local snapshot = support and platform:GetRaidMarkSnapshot() or platform:ObserveRaidMarks()
    local registered = {}

    for event, on in pairs(snapshot.registered) do
        if on then
            registered[#registered + 1] = event
        end
    end

    table.sort(registered)

    add(
        'Watching: %s; %d events registered; %d scans, %d changes, %d unreadable reads in the last scan; started %d times, stopped %d',
        yes(snapshot.watching),
        #registered,
        snapshot.scans,
        snapshot.updates,
        snapshot.unreadable,
        snapshot.starts,
        snapshot.stops
    )

    if #registered > 0 then
        add('Registered: %s', table.concat(registered, ' '))
    end

    add('Table (mark: guid, token, reachable, seconds since seen, enemy, friendly):')
    local keys = platform.RaidMarks.keys

    for _, index in ipairs(platform.RaidMarks.priority) do
        local entry = snapshot.marks[index]
        local label = string.format('%-8s %d', keys[index], index)

        if entry.held then
            add(
                '  %s: %s, %s, %s, %s, %s, %s',
                label,
                show(entry.guid),
                show(entry.token or ('last ' .. show(entry.lastToken))),
                entry.reachable and 'reachable' or 'NOT reachable',
                entry.age and string.format('%.1fs', entry.age) or '-',
                yes(entry.enemy),
                yes(entry.friend)
            )
        else
            add('  %s: -', label)
        end
    end

    add('Mark unit types now:')

    for _, index in ipairs(platform.RaidMarks.priority) do
        local kind = keys[index]
        local token, reason = platform:ResolveGroupUnit(kind)
        add('  %-9s %s', kind, token and ('-> ' .. token) or ('unavailable (' .. show(reason) .. ')'))
    end

    local token, reason = platform:ResolveGroupUnit('anymark')
    add('  %-9s %s', 'anymark', token and ('-> ' .. token) or ('unavailable (' .. show(reason) .. ')'))
    local offered = self.units and self.units.skull ~= nil
    add('Offered in the unit pickers: %s', yes(offered))
    local action = platform:GetMarkActionSupport()
    local built = 0

    for _ in pairs(self.markButtons or {}) do
        built = built + 1
    end

    add(
        'Set Mark step: %s; hidden buttons made %d; macros on the bars recognized: %s',
        action and ('unavailable (' .. action .. ')') or 'available',
        built,
        yes(platform:IsMarkActionTracking())
    )

    local allowed, why = platform:CanSetRaidMark()
    add('You may place marks now: %s%s', yes(allowed), why and (' (' .. why .. ')') or '')
    return lines
end

-- Prints the report to chat. Arguments are ignored.
function addon:RunRaidMarkDiagnostic()
    for _, line in ipairs(self:BuildRaidMarkDiagnostic()) do
        self:print('%s', line)
    end
end
