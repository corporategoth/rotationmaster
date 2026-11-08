-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Preview window across profile changes: switching, copying or resetting the profile rebuilds the preview from the new
-- profile, so the poll keeps filling it (or it goes away when the new profile has none) instead of leaving a window bound
-- to the old profile that drops every recommendation while the action bar keeps glowing.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local root = assert(io.popen('pwd'):read('*l'))

local function make(engine, preview)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    local c = build({ buttons = true, target = true, poll = .15, preview = preview })
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine))
    c.a.print = function() end

    for _ = 1, 4 do
        c.tick()
    end

    return c
end

local function poll(c)
    for _ = 1, 6 do
        c.tick()
    end
end

local function shownIcons(window)
    local shown = 0

    for _, icon in ipairs(window.icons) do
        if icon:IsShown() then
            shown = shown + 1
        end
    end

    return shown
end

-- The preview is live for the current profile and shows what the poll recommends.
local function assertShowing(c, label)
    local a = c.a
    local window = a.nextWindow
    assert(window, label .. ': no preview window')
    assert(window:Valid(), label .. ': preview window bound to another profile')
    assert(window.profile == a.db.profile, label .. ': preview profile is not the current profile')
    assert(a.currentSpell, label .. ': nothing recommended')
    assert(window.count >= 1 and shownIcons(window) >= 1, label .. ': no preview icon shown')
    assert(window.frame:IsShown(), label .. ': preview frame hidden')
end

for _, engine in ipairs({ 'standard', 'lean' }) do
    test(engine .. ': switching to a profile with a preview fills the new preview', function()
        local c = make(engine, 3)
        assertShowing(c, 'before')
        local old = c.a.nextWindow.profile
        c.a.db.profiles.Other = { preview_spells = 2, idle_poll = 0 }
        c.a.db:SetProfile('Other')
        poll(c)
        assert(c.a.db.profile ~= old)
        assertShowing(c, 'after')
        assert(c.a.nextWindow.slots == 2, 'slot count not taken from the new profile')
    end)

    test(engine .. ': switching to a profile without a preview removes it', function()
        local c = make(engine, 3)
        local window = c.a.nextWindow
        c.a.db.profiles.Other = { preview_spells = 0, idle_poll = 0 }
        c.a.db:SetProfile('Other')
        poll(c)
        assert(c.a.nextWindow == nil, 'preview window kept')
        assert(not window.frame:IsShown(), 'old preview strip still on screen')
        assert(c.a.currentSpell, 'advice stopped')
    end)

    test(engine .. ': copying a profile with a preview creates the preview at its saved place', function()
        local c = make(engine, 0)
        -- The fixture always opens a window; at zero preview spells the real addon has none.
        c.a:RefreshPreviewWindow()
        assert(c.a.nextWindow == nil)

        c.a.db.profiles.Source = {
            preview_spells = 3,
            idle_poll = 0,
            preview_window = { point = 'TOPLEFT', relpoint = 'TOPLEFT', xoffs = 40, yoffs = -60 },
            previewHeaderlessGeometry = true,
        }

        c.a.db:CopyProfile('Source')
        poll(c)
        assertShowing(c, 'after copy')
        local point, _, relative, x, y = c.a.nextWindow.frame:GetPoint(1)
        assert(point == 'TOPLEFT' and relative == 'TOPLEFT' and x == 40 and y == -60, 'saved position not applied')
    end)

    test(engine .. ': resetting the profile applies its default of no preview', function()
        local c = make(engine, 3)
        local window = c.a.nextWindow
        c.a.db:ResetProfile()
        poll(c)
        assert(c.a.nextWindow == nil, 'preview window kept after reset')
        assert(not window.frame:IsShown(), 'old preview strip still on screen')
    end)
end

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
