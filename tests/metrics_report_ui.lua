-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The Metrics tab (UI/metrics_report.lua): the recording switches, the period buttons (last fight, this instance, a timed
-- period with a slider, all time), a tab for each rotation, the graphs, Reset (press twice) and the export with its option
-- to add instructions for a language model; and the pooled drawing that allocates nothing on a second draw.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local FIREBALL, FROSTBOLT, BLINK = 133, 116, 1953

local PATHS = {
    'Platform/spells.lua', 'Data/catalog.lua', 'Data/rotation_store.lua', 'Core/rotation_library.lua',
    'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Help/general.lua', 'UI/window.lua', 'UI/help.lua',
    'UI/settings_roster_order.lua', 'UI/settings_layout.lua', 'UI/settings_ordered.lua', 'UI/settings_draft.lua',
    'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_form.lua', 'UI/settings_transfer.lua',
    'UI/collection_compare.lua', 'UI/settings_collections.lua'
}

-- A settings pane showing the Metrics page, with the metrics recorder loaded.
local function page()
    local f = F.new(5, 1, 'MAGE')
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local codecData, codecDeps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = codecData

    a.NewRotationCodec = function()
        return codecData.NewCodec(codecDeps)
    end

    a.pretty_name, a.name, a.configPaneGeneration = 'Rotation Master', 'rotationmaster', 1

    f.env.GetBuildInfo = function()
        return '2.5.6', '1', '', 20506
    end

    for _, path in ipairs(PATHS) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    a.db.profile = { metrics_adherence = true }
    a.db.global = a.db.global or {}
    f.load('Analytics/metrics.lua')
    f.load('UI/metrics_report.lua')

    a.Platform.GetSpellInfo = function(_, id)
        return { name = 'Spell ' .. id, iconID = 1000 + id }
    end

    local printed = {}

    a.print = function(_, message, ...)
        printed[#printed + 1] = string.format(message, ...)
    end

    local parent = create('Frame')
    parent:SetSize(1000, 700)
    return f, a, parent, printed
end

-- Records one fight.
local function fight(m, rotation, steps)
    m:FightStart(100)

    for _, step in ipairs(steps) do
        if step.advice ~= nil then
            m:Advice(rotation, step.advice or nil, step.at)
        end
        if step.cast then
            m:Cast(step.cast, step.at)
        end
    end

    m:Output(30000, 1000)
    return m:FightEnd(130)
end

-- Opens the Metrics page and returns the pane and the controls it made.
local function open(a, parent)
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildMetricsSettings(form)
    end)

    return p, p.metricsControls
end

local function texts(controls)
    local out = {}

    for index = 1, controls.canvas.ctx.usedTexts do
        out[#out + 1] = controls.canvas.ctx.texts[index].text
    end

    return table.concat(out, '\n')
end

local function click(control)
    control.scripts.OnClick(control)
end

test('with nothing recorded the page says so and the export is off', function()
    local _, a, parent = page()
    local _, c = open(a, parent)
    assert(texts(c):find('Nothing was recorded for this period.', 1, true))
    assert(not c.export:IsEnabled() and not c.tabs[1]:IsShown() and not c.minutes:IsShown())
end)

test('the page draws the gauge, where the casts went, the reaction chart, the deviations and the output', function()
    local _, a, parent = page()

    fight(a.Metrics, 'rot', {
        { advice = FIREBALL, at = 101 },
        { cast = FIREBALL, at = 101.5 },
        { advice = FROSTBOLT, at = 103 },
        { cast = BLINK, at = 104 },
        { advice = FIREBALL, at = 105 },
        { cast = FIREBALL, at = 105.2 },
    })

    local _, c = open(a, parent)
    local shown = texts(c)
    assert(shown:find('Followed the advice', 1, true) and shown:find('67%', 1, true), shown)
    assert(shown:find('Where your casts went', 1, true) and shown:find('Followed: 2', 1, true), shown)
    assert(shown:find('Outside the rotation: 1', 1, true), 'Blink was never advised: outside the rotation')
    assert(shown:find('Time to act on advice', 1, true) and shown:find('Average time to act', 1, true), shown)
    assert(shown:find('Damage per second: 1000', 1, true), shown)
    assert(shown:find('Most common deviations', 1, true) and shown:find('Spell 116', 1, true))
    assert(not shown:find('Forecast accuracy', 1, true), 'no forecast was tracked')
    assert(c.canvas:GetHeight() > 400 and c.export:IsEnabled(), 'it is as tall as what was drawn')
end)

test('a period is chosen with its button, the timed one has a slider, and a rotation with its tab', function()
    local _, a, parent = page()
    local clock = 5000

    a.Metrics.clock = function()
        return clock
    end

    local steps = { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } }
    fight(a.Metrics, 'one', steps)
    clock = clock + 3600
    fight(a.Metrics, 'two', steps)
    fight(a.Metrics, 'two', steps)
    local _, c = open(a, parent)
    assert(c.report.scope == 'last' and #c.report.rotations == 1, 'it opens on the last fight')
    click(c.scope.all)
    assert(#c.report.rotations == 2 and c.tabs[1]:IsShown() and c.tabs[2]:IsShown())
    assert(c.report.rotations[1].id == 'two' and texts(c):find('2 fights', 1, true), 'most fights first')
    click(c.tabs[2])
    assert(texts(c):find('1 fights', 1, true), 'the second tab is the other rotation')
    click(c.scope.minutes)
    assert(c.minutes:IsShown() and c.scope.minutes.text == 'Last 30 minutes', c.scope.minutes.text)
    assert(#c.report.rotations == 1 and c.report.rotations[1].id == 'two', 'half an hour back is only the later fights')
    clock = clock + 7200
    c.minutes:SetValue(180)
    c.minutes.scripts.OnValueChanged(c.minutes, 180)
    assert(c.scope.minutes.text == 'Last 180 minutes' and #c.report.rotations == 2, 'three hours back reaches both')
    click(c.scope.instance)
    assert(texts(c):find('Nothing was recorded for this period.', 1, true), 'no instance is known here')
    assert(not c.minutes:IsShown() and not c.tabs[1]:IsShown())
end)

test('Reset asks to be pressed twice, then deletes everything and says so', function()
    local _, a, parent, printed = page()
    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    local _, c = open(a, parent)
    click(c.reset)
    assert(c.reset.text == 'Confirm' and a.Metrics:HasData(), 'the first press only asks')
    click(c.reset)
    assert(not a.Metrics:HasData() and printed[#printed] == 'Metrics cleared.', 'the second press deletes')
    assert(c.reset.text == 'Reset' and texts(c):find('Nothing was recorded for this period.', 1, true))
end)

test('the export is under the graphs, for what is shown, with or without instructions for a language model', function()
    local _, a, parent = page()
    local shown

    a.ShowConditionText = function(_, text, title)
        shown = { text = text, title = title }
    end

    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    local _, c = open(a, parent)
    click(c.export)
    assert(shown.text:find('"format":"rm-metrics"', 1, true) and shown.title == 'Metrics export')
    assert(not shown.text:find('Please tell me', 1, true), 'plain data')
    c.instructions:SetChecked(true)
    click(c.instructions)
    click(c.export)
    assert(shown.text:find('Please tell me', 1, true) and shown.text:find('"format":"rm-metrics"', 1, true))
    assert(shown.title == 'Metrics for a language model')
end)

test('the recording switches are on this page, and drawing the page again creates no new regions', function()
    local _, a, parent = page()
    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    local p, c = open(a, parent)
    assert(p.fields.metrics_adherence and p.fields.metrics_effectiveness and p.fields.metrics_prediction)
    local textures, labels = #c.canvas.ctx.textures, #c.canvas.ctx.texts
    p:Draw()
    c = p.metricsControls
    assert(#c.canvas.ctx.textures == textures and #c.canvas.ctx.texts == labels, 'a second draw reuses the pools')
end)

test('this session is the fights since the session began, and a timed period has a unit', function()
    local _, a, parent = page()
    local clock = 5000

    a.Metrics.clock = function()
        return clock
    end

    local steps = { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } }
    fight(a.Metrics, 'one', steps)
    clock = clock + 7200
    a.Metrics.session = clock - 60
    fight(a.Metrics, 'two', steps)
    local _, c = open(a, parent)
    click(c.scope.session)
    assert(#c.report.rotations == 1 and c.report.rotations[1].id == 'two', 'only the fight since the session began')
    assert(c.scope.session.text == 'This session' and c.scope.session.selected)
    click(c.scope.minutes)
    click(c.units[2])
    assert(c.scope.minutes.text == 'Last 30 hours' and #c.report.rotations == 2, c.scope.minutes.text)
    click(c.units[3])
    assert(c.scope.minutes.text == 'Last 30 days')
    c.minutes:SetValue(3)
    c.minutes.scripts.OnValueChanged(c.minutes, 3)
    assert(c.scope.minutes.text == 'Last 3 days')
end)

test('a period can be compared with another period, an instance or another rotation, and says what changed', function()
    local _, a, parent = page()
    local clock = 5000

    a.Metrics.clock = function()
        return clock
    end

    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    clock = clock + 3600
    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = BLINK, at = 102 } })
    local _, c = open(a, parent)
    assert(not texts(c):find('Comparison', 1, true), 'nothing is compared at first')
    click(c.compare)
    assert(c.compare.text == 'Compare with: The previous fight', c.compare.text)
    local shown = texts(c)
    assert(shown:find('Comparison', 1, true) and shown:find('The previous fight (1 fights, 1 casts)', 1, true), shown)
    assert(shown:find('-100.0', 1, true) and shown:find('Green is better, red is worse.', 1, true), shown)
    click(c.scope.all)
    assert(not c.compare.text:find('previous', 1, true), 'a comparison that makes no sense for the period is dropped')

    fight(a.Metrics, 'other', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    click(c.scope.all)
    local seen = {}

    for _ = 1, 8 do
        click(c.compare)
        seen[#seen + 1] = c.compare.text

        if c.compare.text == 'Compare with: Another rotation' then
            break
        end
    end

    assert(c.compare.text == 'Compare with: Another rotation', table.concat(seen, ' | '))
    assert(c.compareDetail:IsShown() and c.compareDetail.text ~= '', 'the other rotation is named')
    assert(texts(c):find('Comparison', 1, true))
end)

test('the page spreads over the width of the pane, the choices share one row, and it follows a resize', function()
    local _, a, parent = page()
    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    local p, c = open(a, parent)
    assert(c.canvas:GetWidth() == p.width and p.width > 900, 'the whole width, not a part: ' .. tostring(p.width))
    local row = c.scope.last.point[3]
    assert(c.scope.session.point[3] == row and c.scope.all.point[3] == row and c.reset.point[3] == row, 'one row')
    local wide = c.scope.last:GetWidth()
    p.frame:SetWidth(500)
    p:Draw()
    c = p.metricsControls
    assert(c.canvas:GetWidth() == p.width and p.width < 500, 'it follows the pane')
    assert(c.scope.last:GetWidth() < wide or c.scope.all.point[3] ~= c.scope.last.point[3], 'narrower, or wrapped')
    p.frame:SetWidth(340)
    p:Draw()
    c = p.metricsControls
    assert(c.scope.all.point[3] ~= c.scope.last.point[3], 'too narrow for one row: it wraps')
end)

finish()
