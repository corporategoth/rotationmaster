-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Horizontal and Vertical offset sit side by side, splitting the row beside
-- the position pad (50/50 with a small gap), in the rotation card's effect
-- fields and on the General page, at the narrowest editor and settings width,
-- in English, German and Russian. The letters H and V name them; the full
-- text is the tooltip. Geometry is resolved from the real anchors
-- (tests/fixtures/layout_audit.lua).
local F = dofile('tests/fixtures/addon.lua')
local audit = dofile('tests/fixtures/layout_audit.lua')

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local cardPrefix = assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local cardFixture, card = assert(loadstring(cardPrefix .. '\nreturn fixture,card', '@offset-card-fixture'))()
local pagePrefix = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local pageFixture = assert(loadstring(pagePrefix .. '\nreturn fixture', '@offset-page-fixture'))()
local test, finish = F.suite()

local function characters(text)
    local n = 0

    for _ in (text or ''):gmatch('[^\128-\191]') do
        n = n + 1
    end

    return n
end

local function language(f, name)
    if name ~= 'enUS' then
        f.env.GetLocale = function() return name end
        f.load('Locales/' .. name .. '.lua')
    end
end

-- Both inputs on one row, left and right halves of the space beside the pad, not overlapping, inside the pane.
local function check(resolve, x, y, label, pad, limit)
    local a, b = resolve(x), resolve(y)
    assert(a and b, label .. ': an offset field has no position')
    assert(math.abs((a.top + a.bottom) - (b.top + b.bottom)) < 1, label .. ': the offsets are not on one row')

    assert(a.right <= b.left - 2, string.format(
        '%s: not side by side without overlap [%.1f..%.1f] [%.1f..%.1f]',
        label,
        a.left,
        a.right,
        b.left,
        b.right
    ))

    assert(a.left >= pad.right - .5, label .. ': the horizontal field sits under the pad')
    local wa, wb = a.right - a.left, b.right - b.left
    assert(math.abs(wa - wb) <= 1.5, string.format('%s: not a 50/50 split (%.1f vs %.1f)', label, wa, wb))
    assert(wa >= 30, label .. ': an input is too narrow to type in (' .. wa .. ')')
    assert(b.right <= limit + .5, string.format('%s: leaves the row (%.1f > %.1f)', label, b.right, limit))
end

for _, name in ipairs({ 'enUS', 'deDE', 'ruRU' }) do
    test(
        name .. ': the rotation card puts Horizontal and Vertical offset side by side at the narrowest width',
        function()
            local f, parent = cardFixture()
            language(f, name)
            local a = f.addon
            parent:SetSize(548, 420)
            local pane = assert(a:CreateRotationEditor(parent, 0, 'mine'))
            card(pane, 'optional').action:Click()
            local c = card(pane, 'optional')
            local fields = c.fieldControls
            assert(fields.xoffs and fields.yoffs, 'the offset fields are missing')
            local resolve = audit.resolver(pane.frame)

            check(
                resolve,
                fields.xoffs,
                fields.yoffs,
                name .. ' card',
                resolve(fields.positionUp or c.fieldControls.positionCenter),
                resolve(c.fields).right
            )

            assert(
                fields.xoffs.tooltip and fields.yoffs.tooltip and fields.xoffs.tooltip ~= fields.yoffs.tooltip,
                'the full names are not the tooltips'
            )

            -- Both stay editable and in step with Center / Default.
            fields.xoffs:SetText('3')
            fields.xoffs.scripts.OnTextChanged(fields.xoffs, true)
            fields.yoffs:SetText('-4')
            fields.yoffs.scripts.OnTextChanged(fields.yoffs, true)
            assert(pane:HasUnsavedChanges(), 'edits to the offsets are not staged')
            c = card(pane, 'optional')
            c.fieldControls.positionCenter:Click()
            c = card(pane, 'optional')

            assert(
                tonumber(c.fieldControls.xoffs:GetText()) == 0 and tonumber(c.fieldControls.yoffs:GetText()) == 0,
                'Center did not reset both offsets'
            )
        end
    )

    test(name .. ': the General page puts H and V side by side at the narrowest width', function()
        local f, parent = pageFixture()
        language(f, name)
        local a = f.addon
        parent:SetSize(800 - 24 - 210 - 18, 600)

        a.db.profile = {
            enable = true,
            poll = .1,
            minimap = { hide = false },
            live_config_update = 1,
            color = { r = 1, g = 1, b = 1, a = 1 },
            effect = 'e',
        }

        a.db.global.effects = { e = { name = 'Pixel', type = 'pixel' } }
        a.Glow = function() end
        a.HideGlow = function() end
        a.RemoveAllCurrentGlows = function() end
        local p = a:CreateSettingsForm(parent)

        p:Open(function(form)
            a:BuildGeneralSettings(form)
        end)

        local x, y, pad = p.fields.xoffs, p.fields.yoffs, p.fields.positionPad
        assert(x and y and pad, 'the position controls are missing')
        local resolve = audit.resolver(p.child)
        check(resolve, x, y, name .. ' General', resolve(pad), p.width)
        assert(x.tooltip and y.tooltip, 'the full names are not the tooltips')
        x:SetText('7')
        x.scripts.OnTextChanged(x, true)
        y:SetText('9')
        y.scripts.OnTextChanged(y, true)
        assert(p:FlushEdits())
        assert(a.db.profile.xoffs == 7 and a.db.profile.yoffs == 9, 'the offsets are not both editable')
        pad.buttons.Center:Click()

        assert(
            a.db.profile.xoffs == 0 and a.db.profile.yoffs == 0 and a.db.profile.setpoint == 'CENTER',
            'Center did not reset both'
        )
    end)
end

finish()
