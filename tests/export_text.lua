-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Export text format (docs/quality/export-text-format.md): the pure helpers. Runs
-- under Lua 5.1 and LuaJIT; the codec and window suites are export_text_transfer.lua.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local H = dofile('tests/fixtures/export_text_cases.lua')
local NBSP, ZWSP, BOM, LSEP, reference, lines = H.NBSP, H.ZWSP, H.BOM, H.LSEP, H.reference, H.lines

local function formatter()
    return F.new().addon
end

test('the export rule: 76-character lines, LF only, no trailing newline, marker on the first line', function()
    local a = formatter()
    assert(a.ExportTextWidth == 76)
    assert(a:FormatExportText('') == '' and a:FormatExportText(nil) == '' and a:FormatExportText(12) == '')

    for _, size in ipairs({1, 4, 71, 72, 75, 76, 77, 78, 151, 152, 153, 154, 228, 229, 1000, 4567}) do
        local text = string.rep('QUJD', math.ceil(size / 4)):sub(1, size)
        local shown = a:FormatExportText(text)
        assert(shown == reference(text), 'size ' .. size .. ' differs from the rule')
        assert(shown:gsub('\n', '') == text, 'size ' .. size .. ' changed the data')

        assert(
            not shown:find('\r') and not shown:find('\n$') and not shown:find('\n\n') and not shown:find('^\n'),
            'size ' .. size
        )

        local rows = lines(shown)
        assert(#rows == math.ceil(size / 76), 'size ' .. size .. ' has ' .. #rows .. ' lines')

        for index, row in ipairs(rows) do
            assert(
                #row == 76 or index == #rows and #row >= 1 and #row <= 76,
                'size ' .. size .. ' line ' .. index .. ' has ' .. #row
            )
        end
    end

    assert(a:FormatExportText(string.rep('A', 76)) == string.rep('A', 76), 'a full line gets no trailing newline')
    assert(a:FormatExportText(string.rep('A', 77)) == string.rep('A', 76) .. '\nA')
    local marked = 'RM1:' .. string.rep('A', 200)
    local shown = a:FormatExportText(marked)
    local rows = lines(shown)

    assert(
        rows[1]:sub(1, 4) == 'RM1:' and #rows[1] == 76 and #rows[2] == 76 and #rows[3] == 52,
        'the marker counts toward the first line'
    )

    assert(shown:gsub('\n', '') == marked)
    assert(a:FormatExportText(shown) == shown, 'formatting a wrapped string is stable')
    assert(a:FormatExportText((shown:gsub('\n', '\r\n'))) == shown, 'CRLF input normalizes to LF output')

    assert(
        a:FormatExportText('A' .. string.rep('B', 9), 4) == 'ABBB\nBBBB\nBB' and a:FormatExportText(
            string.rep('A', 100),
            0
        )
            == reference(string.rep('A', 100)),
        'an explicit width is honored, a bad one falls back to 76'
    )
end)

test('import normalization removes whitespace and invisible characters and nothing the encoding uses', function()
    local a = formatter()
    local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=:'
    assert(a:NormalizeImportText(alphabet) == alphabet and a:NormalizeImportText('RM1:AbC+/z==') == 'RM1:AbC+/z==')

    for _, whitespace in ipairs({
        ' ', '\t', '\r', '\n', '\v', '\f', NBSP, ZWSP, BOM, LSEP, '\226\128\175', '\226\128\141', '\226\128\142',
        '\226\128\172', '\226\129\160', '\226\129\166', '\227\128\128', '\194\173', '\194\133', '\225\154\128',
        '\226\128\128', '\226\128\138'
    }) do
        assert(
            a:NormalizeImportText('AB' .. whitespace .. 'CD' .. whitespace .. whitespace) == 'ABCD',
            'not removed: ' .. whitespace:gsub('.', function(c) return string.format('\\%d', c:byte()) end)
        )
    end

    for position = 1, #alphabet do
        assert(a:NormalizeImportText(alphabet:sub(position, position)) == alphabet:sub(position, position))
    end

    assert(
        a:NormalizeImportText('') == ''
            and a:NormalizeImportText(nil) == ''
            and a:NormalizeImportText({}) == ''
            and a:NormalizeImportText(' \r\n\t ') == ''
    )

    assert(
        a:NormalizeImportText('AB\226\130\172CD') == 'AB\226\130\172CD',
        'a visible multibyte character is data and must reach the decoder'
    )

    assert(a:NormalizeImportText('A\226\128\144B') == 'A\226\128\144B', 'U+2010 is a hyphen, not whitespace')
end)

finish()
