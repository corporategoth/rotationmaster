-- The rotation editor's footer: Discard, Apply, View Changes, the selection
-- bar (count and card actions) and the hint/status text. Every visible
-- control owns its space, at the narrowest width the editor gets (a minimum
-- window, 800 px) and a normal one, on a Built In (read-only: no editing
-- actions at all) and on your own rotation, in English, German and Russian.
-- Geometry is resolved from the real anchors (tests/fixtures/layout_audit.lua);
-- text is measured per character, not per byte, as the client measures it.
local F = dofile('tests/fixtures/addon.lua')
local audit = dofile('tests/fixtures/layout_audit.lua')

local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local fixture, card = assert(loadstring(prefix .. '\nreturn fixture,card', '@rotation-footer-fixture'))()
local test, finish = F.suite()
-- Content width of the editor pane: window 800 -> list column 210 + gap 18.
local WIDTHS = { min = 800 - 24 - 210 - 18, normal = 1120 - 24 - 270 - 18 }
local HEIGHT = 420

local function characters(text)
    local n = 0

    for _ in (text or ''):gmatch('[^\128-\191]') do
        n = n + 1
    end

    return n
end

local function open(language, id, width)
    local f, parent = fixture()

    if language ~= 'enUS' then
        f.env.GetLocale = function() return language end
        f.load('Locales/' .. language .. '.lua')
    end

    parent:SetSize(width, HEIGHT)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, id))

    for _, frame in ipairs(f.nativeFrames) do
        if frame.kind == 'FontString' then
            function frame:GetStringWidth()
                return characters(self.text) * 7
            end

            if frame == pane.status or frame == pane.hint then
                frame.height = 12
            end
        end
    end

    pane:Layout()
    return f, pane
end

local function select(pane, id)
    local c = card(pane, id)
    local frame = c.frame
    frame.scripts.OnMouseUp(frame, 'LeftButton')
end

local function children(pane)
    local list = {
        { name = 'discard', frame = pane.discard },
        { name = 'apply', frame = pane.apply },
        { name = 'view changes', frame = pane.viewChanges },
        { name = 'hint', frame = pane.hint },
        { name = 'status', frame = pane.status },
    }

    local bar = pane.selectionBar

    if bar:IsShown() then
        list[#list + 1] = { name = 'selection label', frame = bar.label }

        for _, key in ipairs(bar.order) do
            if bar.buttons[key]:IsShown() then
                list[#list + 1] = { name = 'selection ' .. key, frame = bar.buttons[key] }
            end
        end
    end

    list[#list + 1] = { name = 'canvas', frame = pane.canvas.frame }
    return list
end

local function check(pane, label, selected)
    local root = pane.frame
    local resolve = audit.resolver(root)
    local seen = {}

    for _, item in ipairs(children(pane)) do
        local frame = item.frame
        local drawn = frame:IsShown() and not (frame.kind == 'FontString' and (frame.text or '') == '')

        if drawn then
            local rect = resolve(frame)
            assert(rect, label .. ': ' .. item.name .. ' has no resolvable position')

            assert(rect.right >= rect.left, string.format(
                '%s: %s is squeezed to a negative width [%.1f..%.1f]',
                label,
                item.name,
                rect.left,
                rect.right
            ))

            if item.name ~= 'canvas' then
                assert(rect.left >= -.5 and rect.right <= root.width + .5, string.format(
                    '%s: %s leaves the pane [%.1f..%.1f] of %d',
                    label,
                    item.name,
                    rect.left,
                    rect.right,
                    root.width
                ))
            end

            seen[#seen + 1] = { name = item.name, rect = rect, frame = frame }
        end
    end

    for i = 1, #seen do
        for j = i + 1, #seen do
            local a, b = seen[i].rect, seen[j].rect
            local across = a.left < b.right - .5 and b.left < a.right - .5
            local down = a.bottom < b.top - .5 and b.bottom < a.top - .5

            assert(not (across and down), string.format(
                '%s: %s [%.1f..%.1f x %.1f..%.1f] overlaps %s [%.1f..%.1f x %.1f..%.1f]',
                label,
                seen[i].name,
                a.left,
                a.right,
                a.bottom,
                a.top,
                seen[j].name,
                b.left,
                b.right,
                b.bottom,
                b.top
            ))
        end
    end

    return seen
end

local function names(seen)
    local out = {}

    for _, item in ipairs(seen) do
        out[item.name] = true
    end

    return out
end

for _, language in ipairs({ 'enUS', 'deDE', 'ruRU' }) do
    for _, size in ipairs({ 'min', 'normal' }) do
        test(
            language
                .. ' '
                .. size
                .. ' width: the footer controls do not overlap on a Built In and on your own rotation',
            function()
                for _, case in ipairs({ { 'builtin', 'Built In' }, { 'mine', 'own' } }) do
                    local _, pane = open(language, case[1], WIDTHS[size])
                    local label = case[2]
                    check(pane, label .. ' no selection')
                    assert(not pane.selectionBar:IsShown(), label .. ' opens with cards selected')
                    select(pane, 'yes')

                    if case[1] == 'builtin' then
                        -- A Built In has nothing to copy, delete or enable: a click never selects.
                        assert(
                            not pane.selectionBar:IsShown() and #pane.canvas:SelectedIds(false) == 0,
                            'a click selected a card on a Built In'
                        )

                        check(pane, label .. ' clicked')
                    else
                        assert(pane.selectionBar:IsShown(), label .. ' selection bar')
                        local seen = check(pane, label .. ' one selected', true)
                        local present = names(seen)
                        assert(present['selection clear'], 'Clear is missing')

                        for _, key in ipairs({ 'duplicate', 'enable', 'disable', 'remove' }) do
                            assert(present['selection ' .. key], key .. ' is missing')
                        end

                        assert(pane.viewChanges.icon == nil, 'View Changes draws a glyph of its own')
                        -- Selecting more and clearing again keeps the footer clean.
                        select(pane, 'no')
                        pane.selectionBar.buttons.clear:Click()
                        assert(not pane.selectionBar:IsShown())
                        check(pane, label .. ' cleared')
                    end
                end
            end
        )
    end
end

test('a Built In never starts with a card selected, even after one was selected in an earlier visit', function()
    local f, pane = open('enUS', 'mine', WIDTHS.min)
    select(pane, 'yes')
    assert(pane.selectionBar:IsShown() and #pane.canvas:SelectedIds(false) == 1)
    pane:Open(0, 'builtin', function() end)
    assert(not pane.selectionBar:IsShown() and #pane.canvas:SelectedIds(false) == 0, 'the earlier selection came back')

    for _, c in ipairs(pane.canvas.cards) do
        assert(not c.selected, 'a card is drawn selected')
    end
end)

test(
    'when the row cannot hold the selection bar and a readable hint, the bar takes its own row and the canvas gives way',
    function()
        local _, pane = open('ruRU', 'mine', WIDTHS.min)
        select(pane, 'yes')
        assert(pane.footerStacked, 'the long Russian footer does not stack at the minimum width')
        local resolve = audit.resolver(pane.frame)
        local bar, canvas = resolve(pane.selectionBar), resolve(pane.canvas.frame)
        assert(bar.top <= canvas.bottom + .5 or bar.bottom >= canvas.top - .5, 'the stacked bar sits on the canvas')
        pane.selectionBar.buttons.clear:Click()
        assert(not pane.footerStacked)
        local _, wide = open('enUS', 'mine', WIDTHS.normal)
        select(wide, 'yes')
        assert(not wide.footerStacked, 'a wide English footer stacked')
    end
)

finish()
