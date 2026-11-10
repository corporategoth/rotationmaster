-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The preview window's background (UI/preview.lua, Assets/Preview/): a themed border round the icons that follows the player's
-- class, scales with the icon size, tiles along each side and puts a stud at every joint between two icons; a plain box in the
-- chosen color when the art is off; nothing at zero opacity. The art files themselves are checked by tests/test_preview_art.py.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- Builds the addon with the native preview window loaded.
-- @param class string|nil  The player's class token; nil leaves UnitClass out.
-- @param profile table|nil  Profile settings to apply.
-- @return table  The fixture.
-- @return table  The addon.
local function fixture(class, profile)
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local a = f.addon
    a.db.profile.preview_spells = 3
    a.db.profile.preview_opacity = 1

    for key, value in pairs(profile or {}) do
        a.db.profile[key] = value
    end

    if class then
        f.env.UnitClass = function() return 'Name', class end
    end

    a.Platform.GetSpellInfo = function(_, id) return { name = 'Spell ' .. id, iconID = id + 10 } end
    f.load('UI/preview.lua')
    return f, a
end

-- Reads the border state the window drew.
-- @param w table  The preview window.
-- @return table  { rails = lit flags per drawn rail, studs = lit flags per drawn stud }.
local function border(w)
    local out = { rails = {}, studs = {} }

    for index, rail in ipairs(w.rails) do
        if rail:IsShown() then
            local c = rail.texCoord
            local lowest = #c == 8 and math.min(c[2], c[4], c[6], c[8]) or math.min(c[3], c[4])

            -- The sheet's lit rail is its second row (from 0.25 down); the dim one is the first.
            out.rails[index] = lowest >= 0.25 and 'lit' or 'dim'
        end
    end

    for index, stud in ipairs(w.studs) do
        if stud:IsShown() then
            out.studs[index] = stud.texCoord[1] == 0.125 and 'lit' or 'dim'
        end
    end

    return out
end

test(
    'the painting follows the class and the direction, one texture per slot, and a class without one gets the plain box',
    function()
        local _, a = fixture('SHAMAN', { preview_spells = 3 })
        local w = a:CreateNativePreviewWindow()
        w:Configure()

        for index = 1, 3 do
            assert(w.cells[index]:IsShown() and w.cells[index]:GetTexture():find('shaman%-w' .. index .. '$'), index)
        end

        for index = 4, 5 do
            assert(not w.cells[index]:IsShown(), 'a cell for each slot and no more')
        end

        a.db.profile.preview_vertical = true
        w:Configure()
        assert(w.cells[2]:GetTexture():find('shaman%-t2$'), tostring(w.cells[2]:GetTexture()))

        -- A class without a painting of its own gets the neutral one when there is one, and the plain box when there is not; an
        -- unreadable class and a missing UnitClass are treated the same way.
        local source = io.open('UI/preview.lua'):read('*a')
        local neutral = source:find("'rotation%-master%-w1'") ~= nil
        local absent

        for _, token in ipairs({
            'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'DEATHKNIGHT', 'MAGE', 'WARLOCK', 'MONK', 'DRUID',
            'DEMONHUNTER', 'EVOKER'
        }) do
            absent = absent or (not source:find("'" .. token:lower() .. "%-w1'") and token or nil)
        end

        for _, class in ipairs({ absent or 'MYSTERY', 'MYSTERY', false }) do
            local f, other = fixture(class or nil, { preview_icon_size = 64 })

            if not class then
                f.env.UnitClass = nil
            end

            local window = other:CreateNativePreviewWindow()
            window:Configure()

            if neutral then
                assert(window.useArt and window.cells[1]:GetTexture():find('rotation%-master%-w1$'), tostring(class))
            else
                assert(not window.useArt and window.body:IsShown() and window.body.color[1] == 0.055, tostring(class))
                assert(window.frame:GetWidth() == 3 * 64 + 8, 'the plain box keeps its four')
            end
        end
    end
)

test(
    'each slot gets its own chapter over its slot, the first and last running out under the padding so no bar shows at the ends',
    function()
        local _, a = fixture('SHAMAN', { preview_icon_size = 64 })
        local w = a:CreateNativePreviewWindow()

        for slots = 1, 5 do
            a.db.profile.preview_spells = slots
            a.db.profile.preview_vertical = false
            w:Configure()

            assert(
                w.frame:GetWidth() == slots * 64 + 12 and w.frame:GetHeight() == 64 + 12,
                'a border of six round the slots'
            )

            local covered = 0

            for index = 1, slots do
                local point = w.cells[index].points[1]
                local width = w.cells[index]:GetWidth()
                local first, last = index == 1, index == slots

                -- Together the cells run from the left edge of the window to its right edge.
                assert(
                    point[1] == 'TOPLEFT' and point[4] == (first and 0 or 6 + (index - 1) * 64) and point[5] == -6,
                    slots .. '/' .. index
                )

                assert(width == 64 + (first and 6 or 0) + (last and 6 or 0) and w.cells[index]:GetHeight() == 64)
                covered = covered + width
            end

            assert(covered == w.frame:GetWidth(), slots .. ': no bar of the box left at the ends')

            a.db.profile.preview_vertical = true
            w:Configure()
            local last = w.cells[slots].points[1]
            local ends = w.cells[slots]:GetHeight()
            assert(last[4] == 6 and last[5] == -(slots == 1 and 0 or 6 + (slots - 1) * 64), slots .. ' tall')
            assert(ends == 64 + 6 + (slots == 1 and 6 or 0), slots .. ' tall length')
        end
    end
)

test('the Preview background choice picks the painting: my class, any class, the neutral one or a plain box', function()
    local _, a = fixture('SHAMAN', { preview_spells = 2 })
    local w = a:CreateNativePreviewWindow()
    w:Configure()
    assert(w.useArt and w.cells[1]:GetTexture():find('shaman%-w1$'), 'default: my class')

    for choice, expected in pairs({
        MAGE = 'mage%-w1$',
        ROTATION_MASTER = 'rotation%-master%-w1$',
        class = 'shaman%-w1$',
    }) do
        a.db.profile.preview_art = choice
        w:Configure()
        assert(w.useArt and w.cells[1]:GetTexture():find(expected), choice)
    end

    a.db.profile.preview_art = 'solid'
    w:Configure()
    assert(not w.useArt and not w.cells[1]:IsShown() and w.frame:GetWidth() == 2 * 64 + 8)

    -- A profile saved with the old background switch off is a plain box, whatever painting it names.
    a.db.profile.preview_art = 'class'
    a.db.profile.preview_background = false
    w:Configure()
    assert(not w.useArt)
    a.db.profile.preview_background = true
    w:Configure()
    assert(w.useArt)

    -- Something that is not a painting is the player's class.
    a.db.profile.preview_art = 'NOT_A_CLASS'
    w:Configure()
    assert(w.useArt and w.cells[1]:GetTexture():find('shaman%-w1$'))
    assert(#a:GetPreviewArtChoices() == 14 and a:GetPreviewArtChoices()[14] == 'ROTATION_MASTER')
end)

test('the border is a tenth of the icon size, between five and twelve pixels, and four for a plain box', function()
    local _, a = fixture('SHAMAN', { preview_spells = 2 })
    local w = a:CreateNativePreviewWindow()

    for size, pad in pairs({ [24] = 5, [48] = 5, [64] = 6, [96] = 10, [128] = 12, [160] = 12 }) do
        a.db.profile.preview_icon_size = size
        w:Configure()
        assert(w.frame:GetWidth() == 2 * size + 2 * pad, size .. ': ' .. tostring(w.frame:GetWidth()))
    end

    a.db.profile.preview_icon_size = 64
    a.db.profile.preview_art = 'solid'
    w:Configure()
    assert(w.frame:GetWidth() == 2 * 64 + 8, 'the plain box keeps its four')
    a.db.profile.preview_art = 'class'
    a.db.profile.preview_opacity = 0
    w:Configure()
    assert(w.frame:GetWidth() == 2 * 64, 'no border when fully transparent')
end)

test(
    'the border fills up with the icons: lit rails for the slots that hold one, lit studs where both neighbours do',
    function()
        local _, a = fixture('SHAMAN', { preview_spells = 4, preview_icon_size = 64 })
        local w = a:CreateNativePreviewWindow()
        w:Configure()

        -- Nothing shown: every rail and stud is dim, four slots have eight rails and three joints six studs.
        local state = border(w)

        for index = 1, 8 do
            assert(state.rails[index] == 'dim', 'rail ' .. index)
        end

        assert(state.rails[9] == nil, 'no rails past the slots')

        for index = 1, 6 do
            assert(state.studs[index] == 'dim', 'stud ' .. index)
        end

        assert(state.studs[7] == nil)

        -- Two icons shown: the first two slots' rails (both sides) are lit, and the joint between them, not the others.
        w.count = 2
        w:LayoutArt()
        state = border(w)

        for index = 1, 4 do
            assert(state.rails[index] == 'lit', 'rail ' .. index)
        end

        for index = 5, 8 do
            assert(state.rails[index] == 'dim', 'rail ' .. index)
        end

        assert(state.studs[1] == 'lit' and state.studs[2] == 'lit', 'the joint between 1 and 2')
        assert(state.studs[3] == 'dim' and state.studs[6] == 'dim', 'the others')

        w.count = 4
        w:LayoutArt()
        state = border(w)

        for index = 1, 8 do
            assert(state.rails[index] == 'lit')
        end

        for index = 1, 6 do
            assert(state.studs[index] == 'lit')
        end

        -- Sample icons count as shown, and the publication batch ending redraws the border.
        w.count, w.sampleCount = 0, 3
        w:LayoutArt()
        assert(border(w).rails[5] == 'lit' and border(w).rails[7] == 'dim')
        w.sampleCount = 0
        local drawn = 0
        local layout = w.LayoutArt

        function w:LayoutArt()
            drawn = drawn + 1
            return layout(self)
        end

        w:ResumeLayout()
        assert(drawn >= 1, 'ResumeLayout redraws the border')
    end
)

test(
    'the art is at the window opacity, a plain box takes the chosen color without it, nothing is drawn at zero',
    function()
        local _, a = fixture('SHAMAN', { preview_opacity = 0.5 })
        local w = a:CreateNativePreviewWindow()
        w:Configure()
        assert(w.cells[1]:IsShown() and w.cells[1]:GetAlpha() == 0.5 and w.rails[1]:GetAlpha() == 0.5)
        assert(w.body.color[1] == 0.055, 'the art sits on the default slate, not the chosen color')

        a.db.profile.preview_art = 'solid'
        a.db.profile.preview_color = { r = 0.2, g = 0.4, b = 0.6, a = 0.5 }
        w:Configure()
        assert(w.body:IsShown() and w.body:GetAlpha() == 0.5)
        assert(w.body.color[1] == 0.2 and w.body.color[2] == 0.4 and w.body.color[3] == 0.6 and w.body.color[4] == 0.5)
        assert(not w.cells[1]:IsShown() and not w.rails[1]:IsShown() and not w.corners[1]:IsShown())

        -- Something that is not a color falls back to the default slate rather than failing.
        a.db.profile.preview_color = 'red'
        w:Configure()
        assert(w.body.color[1] == 0.055)

        a.db.profile.preview_art = 'class'
        a.db.profile.preview_opacity = 0
        w:Configure()

        assert(
            w.body:GetAlpha() == 0 and not w.cells[1]:IsShown() and not w.corners[1]:IsShown(),
            'nothing is drawn at zero'
        )
    end
)

finish()
