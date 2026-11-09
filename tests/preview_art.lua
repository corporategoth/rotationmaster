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

test(
    'the background image follows the class and the direction, and a class without a painting gets the plain box',
    function()
        local _, a = fixture('SHAMAN')
        local w = a:CreateNativePreviewWindow()
        w:Configure()
        assert(w.backdrop:GetTexture():find('shaman%-wide$'), tostring(w.backdrop:GetTexture()))
        assert(w.backdrop:IsShown())
        a.db.profile.preview_vertical = true
        w:Configure()
        assert(w.backdrop:GetTexture():find('shaman%-tall$'), tostring(w.backdrop:GetTexture()))

        -- A class that has no painting yet, an unreadable class, and no UnitClass at all draw nothing over the slate.
        for _, class in ipairs({ 'MAGE', 'MYSTERY', false }) do
            local f, other = fixture(class or nil)

            if not class then
                f.env.UnitClass = nil
            end

            local window = other:CreateNativePreviewWindow()
            window:Configure()
            assert(not window.backdrop:IsShown(), tostring(class))
            assert(window.body:IsShown() and window.body.color[1] == 0.055, 'the slate shows')
        end
    end
)

test('a window of n slots shows the first n cells of the image, stretched over the whole window', function()
    local _, a = fixture('SHAMAN', { preview_icon_size = 64 })
    local w = a:CreateNativePreviewWindow()

    for slots = 1, 5 do
        a.db.profile.preview_spells = slots
        a.db.profile.preview_vertical = false
        w:Configure()
        local c = w.backdrop.texCoord
        assert(c[1] == 0 and c[3] == 0 and c[4] == 1, slots .. ' wide: ' .. table.concat(c, ','))
        assert(math.abs(c[2] - slots * 96 / 512) < 1e-9, slots .. ' wide: ' .. c[2])

        a.db.profile.preview_vertical = true
        w:Configure()
        c = w.backdrop.texCoord
        assert(c[1] == 0 and c[2] == 1 and c[3] == 0, slots .. ' tall: ' .. table.concat(c, ','))
        assert(math.abs(c[4] - slots * 96 / 512) < 1e-9, slots .. ' tall: ' .. c[4])
    end

    assert(w.backdrop.allPoints == w.frame, 'over the whole frame')
end)

test('the background art does not change the window size: the padding is the same with it on or off', function()
    local _, a = fixture('SHAMAN', { preview_spells = 3, preview_icon_size = 64 })
    local w = a:CreateNativePreviewWindow()
    w:Configure()
    assert(w.frame:GetWidth() == 3 * 64 + 8 and w.frame:GetHeight() == 64 + 8)
    a.db.profile.preview_background = false
    w:Configure()
    assert(w.frame:GetWidth() == 3 * 64 + 8 and w.frame:GetHeight() == 64 + 8)
    a.db.profile.preview_opacity = 0
    w:Configure()
    assert(w.frame:GetWidth() == 3 * 64, 'no padding when fully transparent')
end)

test(
    'the image is at the window opacity, a plain box takes the chosen color without it, nothing is drawn at zero',
    function()
        local _, a = fixture('SHAMAN', { preview_opacity = 0.5 })
        local w = a:CreateNativePreviewWindow()
        w:Configure()
        assert(w.backdrop:IsShown() and w.backdrop:GetAlpha() == 0.5)
        assert(w.body.color[1] == 0.055, 'the image sits on the default slate, not the chosen color')

        a.db.profile.preview_background = false
        a.db.profile.preview_color = { r = 0.2, g = 0.4, b = 0.6, a = 0.5 }
        w:Configure()
        assert(w.body:IsShown() and w.body:GetAlpha() == 0.5)
        assert(w.body.color[1] == 0.2 and w.body.color[2] == 0.4 and w.body.color[3] == 0.6 and w.body.color[4] == 0.5)
        assert(not w.backdrop:IsShown())

        -- Something that is not a color falls back to the default slate rather than failing.
        a.db.profile.preview_color = 'red'
        w:Configure()
        assert(w.body.color[1] == 0.055)

        a.db.profile.preview_background = true
        a.db.profile.preview_opacity = 0
        w:Configure()
        assert(w.body:GetAlpha() == 0 and not w.backdrop:IsShown(), 'nothing is drawn at zero')
    end
)

finish()
