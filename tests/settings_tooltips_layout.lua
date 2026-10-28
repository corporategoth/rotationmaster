-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
--
-- The Tooltips section of the General page lays its six check boxes out as a grid, two to a row: Show Rotation Master
-- in tooltips / Include disabled rotations, Include rotation conditions / Exclude disabled conditions, List item sets /
-- List rotations. In every game language, at every UI scale from 100% to 130% and at the narrowest and the widest
-- pages that scale allows, a caption that does not fit one line wraps inside its own cell, its row grows to hold it,
-- and no box overlaps another box, leaves its column or runs into the slider below. Geometry is resolved from the real
-- anchors (tests/fixtures/layout_audit.lua).
local F = dofile('tests/fixtures/addon.lua')
local audit = dofile('tests/fixtures/layout_audit.lua')

-- Reads a file whole.
local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local pagePrefix = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local pageFixture = assert(loadstring(pagePrefix .. '\nreturn fixture', '@tooltip-layout-fixture'))()
local test, finish = F.suite()

local LANGUAGES = {'enUS', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}
local SCALES = { 100, 110, 120, 130 }

-- The window is 800 wide at the least; the most it can be is the screen's width at the chosen scale. The page is the
-- window less the sidebar, the paddings and the scroll bar (the same sum tests/offset_fields_layout.lua uses).
local SCREENS = { 1280, 1920 }
local CHROME = 24 + 210 + 18

-- Returns the page widths to test at a UI scale: the narrowest, and the widest each screen allows.
local function pageWidths(scale)
    local widths = { [800 - CHROME] = true }

    for _, screen in ipairs(SCREENS) do
        widths[math.max(800, math.floor(screen / (scale / 100))) - CHROME] = true
    end

    local list = {}

    for width in pairs(widths) do
        list[#list + 1] = width
    end

    table.sort(list)
    return list
end

local GRID = {
    { 'tooltips', 'tooltip_disabled_rotations' },
    { 'tooltip_conditions', 'tooltip_exclude_disabled_conditions' },
    { 'tooltip_itemsets', 'tooltip_rotations' },
}

-- True when two rectangles share area (touching edges do not count).
local function intersects(a, b)
    return a.left < b.right - .5 and b.left < a.right - .5 and a.bottom < b.top - .5 and b.bottom < a.top - .5
end

-- Opens the General page at a width, in the fixture's current language, and checks the Tooltips grid. Returns whether
-- any caption wrapped to a second line.
local function check(f, scale, width, label)
    local a = f.addon
    local parent = f.parent
    parent:SetSize(width + CHROME, 600)

    if parent.SetScale then
        parent:SetScale(scale / 100)
    end

    a.db.profile = { enable = true, poll = .1, minimap = { hide = false }, color = { r = 1, g = 1, b = 1, a = 1 } }
    a.db.global.effects = {}
    a.Glow, a.HideGlow, a.RemoveAllCurrentGlows = function() end, function() end, function() end
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildGeneralSettings(form)
    end)

    local resolve = audit.resolver(p.child)
    local rects, wrapped = {}, false

    for rowIndex, row in ipairs(GRID) do
        for column, key in ipairs(row) do
            local control = assert(p.fields[key], label .. ': ' .. key .. ' is missing')
            local rect = assert(resolve(control), label .. ': ' .. key .. ' has no position')
            local text = control:GetFontString()
            local lineHeight = text:GetStringHeight()
            rects[key] = rect

            assert(lineHeight <= rect.top - rect.bottom + .5, string.format(
                '%s: %s caption (%.0f) is taller than its box (%.0f)',
                label,
                key,
                lineHeight,
                rect.top - rect.bottom
            ))

            assert(text.width <= rect.right - rect.left - 22 + .5, string.format(
                '%s: %s caption is wider than its box',
                label,
                key
            ))

            assert(rect.left >= -.5 and rect.right <= p.width + .5, string.format(
                '%s: %s leaves the column',
                label,
                key
            ))

            wrapped = wrapped or lineHeight > 20

            assert(
                column == 1 or rects[row[1]].right <= rect.left - 2,
                label .. ': the pair on row ' .. rowIndex .. ' touches'
            )

            assert(
                column == 1 or math.abs(rects[row[1]].top - rect.top) < 1,
                label .. ': row ' .. rowIndex .. ' is not on one line'
            )
        end
    end

    local keys = {}

    for _, row in ipairs(GRID) do
        for _, key in ipairs(row) do
            keys[#keys + 1] = key
        end
    end

    for i = 1, #keys do
        for j = i + 1, #keys do
            assert(not intersects(rects[keys[i]], rects[keys[j]]), label .. ': ' .. keys[i] .. ' overlaps ' .. keys[j])
        end
    end

    -- Each row sits wholly below the one above, and the slider below the last.
    for i = 2, #GRID do
        local above = math.min(rects[GRID[i - 1][1]].bottom, rects[GRID[i - 1][2]].bottom)
        local below = math.max(rects[GRID[i][1]].top, rects[GRID[i][2]].top)
        assert(below <= above + .5, label .. ': row ' .. i .. ' overlaps the row above')
    end

    local limit = assert(resolve(p.fields.tooltip_limit), label .. ': the slider has no position')
    local last = math.min(rects.tooltip_itemsets.bottom, rects.tooltip_rotations.bottom)
    assert(limit.top <= last + .5, label .. ': the slider overlaps the last row')

    -- The master switch turns off the other five and nothing else.
    p.fields.tooltips:Click()

    for _, key in ipairs(keys) do
        assert(p.fields[key]:IsEnabled() == (key == 'tooltips'), label .. ': master off, ' .. key)
    end

    return wrapped
end

for _, name in ipairs(LANGUAGES) do
    test(name .. ': the Tooltips grid keeps long captions in their cells at every scale and page width', function()
        local f, parent = pageFixture()
        f.language(name)
        f.parent = parent
        local wrappedSomewhere = false

        for _, scale in ipairs(SCALES) do
            for _, width in ipairs(pageWidths(scale)) do
                local label = string.format('%s %d%% %dpx', name, scale, width)

                if check(f, scale, width, label) then
                    wrappedSomewhere = true
                end
            end
        end

        -- The narrowest page must be tight enough for the test to mean something in the long languages.
        if name == 'deDE' or name == 'ruRU' or name == 'frFR' then
            assert(wrappedSomewhere, name .. ': no caption wrapped, so the test proves nothing about wrapping')
        end
    end)
end

test('a caption too long for its cell wraps and grows its row instead of overlapping the next', function()
    local f, parent = pageFixture()
    f.language('enUS')
    local a = f.addon
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        local long = string.rep('A very long caption ', 8)

        form:CheckGrid({
            { key = 'one', caption = long, value = false, changed = function() end },
            { key = 'two', caption = 'Short', value = false, changed = function() end },
            { key = 'three', caption = 'Next row', value = false, changed = function() end },
        })
    end)

    local resolve = audit.resolver(p.child)
    local one, two, three = resolve(p.fields.one), resolve(p.fields.two), resolve(p.fields.three)
    assert(one.top - one.bottom > 30, 'the long caption did not grow its box')
    assert(math.abs(one.top - two.top) < 1 and one.right <= two.left - 2, 'the pair is not side by side')
    assert(three.top <= one.bottom + .5, 'the next row overlaps the wrapped caption')
end)

finish()
