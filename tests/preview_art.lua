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

-- Counts the studs that are drawn.
-- @param w table  The preview window.
-- @return number  How many.
local function studs(w)
    local count = 0

    for _, stud in ipairs(w.art.studs) do
        if stud:IsShown() then
            count = count + 1
        end
    end

    return count
end

test('the border art follows the class, with the neutral theme for a class it does not know', function()
    for class, theme in pairs({ MAGE = 'mage', DEATHKNIGHT = 'deathknight', EVOKER = 'evoker', ROGUE = 'rogue' }) do
        local _, a = fixture(class)
        local w = a:CreateNativePreviewWindow()
        w:Configure()

        for _, edge in ipairs(w.art.edges) do
            assert(edge:GetTexture():find(theme .. '%-edge$'), class .. ': ' .. tostring(edge:GetTexture()))
        end

        for _, piece in ipairs({ w.art.corners[1], w.art.studs[1] }) do
            assert(piece:GetTexture():find(theme .. '%-ornament$'), class .. ': ' .. tostring(piece:GetTexture()))
        end
    end

    for _, class in ipairs({ 'MYSTERY', false }) do
        local f, a = fixture(class or nil)

        if not class then
            f.env.UnitClass = nil
        end

        local w = a:CreateNativePreviewWindow()
        w:Configure()
        assert(w.art.edges[1]:GetTexture():find('rotation%-master%-edge$'), tostring(class))
    end
end)

test('the border is a share of the icon size, kept between six and sixteen pixels, and four for a plain box', function()
    local _, a = fixture('MAGE', { preview_spells = 2 })
    local w = a:CreateNativePreviewWindow()
    local expected = { [24] = 6, [48] = 6, [64] = 8, [96] = 12, [128] = 16, [160] = 16 }

    for size, border in pairs(expected) do
        a.db.profile.preview_icon_size = size
        w:Configure()
        assert(w.frame:GetWidth() == 2 * size + 2 * border, size .. ': ' .. tostring(w.frame:GetWidth()))
        assert(w.frame:GetHeight() == size + 2 * border)
    end

    a.db.profile.preview_icon_size = 64
    a.db.profile.preview_background = false
    w:Configure()
    assert(w.frame:GetWidth() == 2 * 64 + 8, 'the plain box keeps its four')
    a.db.profile.preview_background = true
    a.db.profile.preview_opacity = 0
    w:Configure()
    assert(w.frame:GetWidth() == 2 * 64, 'no border when fully transparent')
end)

test('the edges tile one cell per border width, flipped and turned to keep their outer side out', function()
    local _, a = fixture('PALADIN', { preview_spells = 3, preview_icon_size = 64 })
    local w = a:CreateNativePreviewWindow()
    w:Configure()
    local top, bottom, left, right = w.art.edges[1], w.art.edges[2], w.art.edges[3], w.art.edges[4]

    -- Three 64 px icons and an 8 px border: 208 by 80, the sides 192 and 64 long, tiles 8 px.
    assert(w.frame:GetWidth() == 208 and w.frame:GetHeight() == 80)
    assert(top.texCoord[2] == 24 and top.texCoord[3] == 0 and top.texCoord[4] == 1)
    assert(bottom.texCoord[2] == 24 and bottom.texCoord[3] == 1 and bottom.texCoord[4] == 0, 'flipped')

    -- The sides turn the tile a quarter, the tile's outer (top) side to the outside.
    assert(
        left.texCoord[3] == 8 and left.texCoord[2] == 0 and left.texCoord[4] == 0,
        'left: ' .. table.concat(left.texCoord, ',')
    )

    assert(
        right.texCoord[2] == 1 and right.texCoord[4] == 1 and right.texCoord[3] == 8,
        'right: ' .. table.concat(right.texCoord, ',')
    )

    -- The corners are the corner half of the ornament sheet, mirrored for the other three.
    local corners = w.art.corners
    assert(corners[1].texCoord[1] == 0 and corners[1].texCoord[2] == 0.5)
    assert(corners[2].texCoord[1] == 0.5 and corners[2].texCoord[2] == 0, 'mirrored across')
    assert(corners[3].texCoord[3] == 1 and corners[3].texCoord[4] == 0, 'mirrored down')
    assert(corners[4].texCoord[1] == 0.5 and corners[4].texCoord[3] == 1)

    for _, corner in ipairs(corners) do
        assert(corner:GetWidth() == 8 and corner:GetHeight() == 8)
    end
end)

test('a stud sits on each border at every joint between icons, so the art follows how many icons there are', function()
    local _, a = fixture('MAGE', { preview_icon_size = 64 })
    local w = a:CreateNativePreviewWindow()

    for slots, expected in pairs({ [1] = 0, [2] = 2, [3] = 4, [4] = 6, [5] = 8 }) do
        a.db.profile.preview_spells = slots
        w:Configure()
        assert(studs(w) == expected, slots .. ' icons: ' .. studs(w) .. ' studs')
    end

    -- Along the border at the joints: 8 px in, plus whole icons, less half a stud.
    a.db.profile.preview_spells = 3
    w:Configure()
    local first, second = w.art.studs[1], w.art.studs[3]
    assert(select(4, first:GetPoint(1)) == 8 + 64 - 4 and select(1, first:GetPoint(1)) == 'TOPLEFT')
    assert(select(4, second:GetPoint(1)) == 8 + 128 - 4)
    assert(select(1, w.art.studs[2]:GetPoint(1)) == 'BOTTOMLEFT', 'and the other long side')

    -- A column puts them on the left and right borders at the joints.
    a.db.profile.preview_vertical = true
    w:Configure()
    local stud = w.art.studs[1]

    assert(select(1, stud:GetPoint(1)) == 'TOPLEFT' and select(5, stud:GetPoint(1)) == -(8 + 64) + 4, tostring(select(
        5,
        stud:GetPoint(1)
    )))

    assert(select(1, w.art.studs[2]:GetPoint(1)) == 'TOPRIGHT')
end)

test(
    'the art is at the window opacity, a plain box takes the chosen color without it, nothing is drawn at zero',
    function()
        local _, a = fixture('MAGE', { preview_opacity = 0.5 })
        local w = a:CreateNativePreviewWindow()
        w:Configure()

        for _, piece in ipairs({ w.art.corners[1], w.art.edges[1], w.art.studs[1] }) do
            assert(piece:IsShown() and piece:GetAlpha() == 0.5)
        end

        assert(w.body.color[1] == 0.055, 'the art sits on the default slate, not the chosen color')

        a.db.profile.preview_background = false
        a.db.profile.preview_color = { r = 0.2, g = 0.4, b = 0.6, a = 0.5 }
        w:Configure()
        assert(w.body:IsShown() and w.body:GetAlpha() == 0.5)
        assert(w.body.color[1] == 0.2 and w.body.color[2] == 0.4 and w.body.color[3] == 0.6 and w.body.color[4] == 0.5)
        assert(not w.art.edges[1]:IsShown() and not w.art.corners[1]:IsShown() and studs(w) == 0)

        -- Something that is not a color falls back to the default slate rather than failing.
        a.db.profile.preview_color = 'red'
        w:Configure()
        assert(w.body.color[1] == 0.055)

        a.db.profile.preview_background = true
        a.db.profile.preview_opacity = 0
        w:Configure()
        assert(w.body:GetAlpha() == 0 and not w.art.edges[1]:IsShown() and studs(w) == 0, 'nothing is drawn at zero')
    end
)

finish()
