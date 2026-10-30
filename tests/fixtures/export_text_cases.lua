-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared cases for the export text format suites (docs/quality/export-text-format.md).
local NBSP, ZWSP, BOM, LSEP = '\194\160', '\226\128\139', '\239\187\191', '\226\128\168'
local H = { NBSP = NBSP, ZWSP = ZWSP, BOM = BOM, LSEP = LSEP }

-- An independent statement of the rule: every 76 characters get a newline, the last one is dropped.
function H.reference(text)
    return (text:gsub(string.rep('.', 76), '%0\n'):gsub('\n$', ''))
end

function H.lines(text)
    local result = {}

    for line in (text .. '\n'):gmatch('(.-)\n') do
        result[#result + 1] = line
    end

    return result
end

function H.equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for key, value in pairs(a) do
        if not H.equal(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

-- Every way a copy of the wrapped text may arrive. None may change what decodes.
function H.variants(a, wire)
    local wrapped = a:FormatExportText(wire)
    local every = wrapped:gsub('\n', '\r\n')
    local indented = wrapped:gsub('([^\n]+)', '    %1'):gsub('\n', '\n\t')
    local noisy = {}

    for index = 1, #wire, 17 do
        noisy[#noisy + 1] = wire:sub(index, index + 16)
    end

    return {
        { 'unwrapped', wire },
        { 'wrapped', wrapped },
        { 'crlf', every },
        { 'cr only', (wrapped:gsub('\n', '\r')) },
        { 'indented', indented },
        { 'trailing blank lines', wrapped .. '\n\n\n' },
        { 'trailing crlf blank lines', every .. '\r\n\r\n' },
        { 'leading blank lines', '\n\n' .. wrapped },
        { 'extra leading and trailing space', '  ' .. wrapped .. '  ' },
        { 'one tab each side', '\t' .. wrapped .. '\t' },
        { 'marker on its own line', (wire:gsub('^RM1:', 'RM1:\n')) },
        { 'no-break spaces', table.concat(noisy, NBSP) },
        { 'zero-width spaces', table.concat(noisy, ZWSP) },
        { 'byte order mark and separators', BOM .. table.concat(noisy, LSEP) },
        { 'mixed', BOM .. '  ' .. table.concat(noisy, '\r\n' .. NBSP .. ZWSP .. '\t') .. '\r\n' },
    }
end

return H
