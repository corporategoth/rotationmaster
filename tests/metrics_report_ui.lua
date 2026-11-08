-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The graphical metrics report (UI/metrics_report.lua): the gauge, the bar of where casts went, the reaction chart, output by
-- adherence, the deviations and the forecast accuracy, a tab for each rotation, and the pooled drawing that allocates nothing
-- on a second opening.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local FIREBALL, FROSTBOLT, BLINK = 133, 116, 1953

local function client()
    local f = F.new(5, 1, 'MAGE')
    f.addon.db = { global = {}, profile = {} }
    f.env.GetBuildInfo = function() return '2.5.6', '1', '', 20506 end
    f.load('Analytics/metrics.lua')
    f.load('UI/metrics_report.lua')
    local printed = {}

    f.addon.print = function(_, message, ...)
        printed[#printed + 1] = string.format(message, ...)
    end

    f.addon.Platform.GetSpellInfo = function(_, id)
        return { name = 'Spell ' .. id, iconID = 1000 + id }
    end

    return f, f.addon, printed
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

local function texts(dialog)
    local out = {}

    for index = 1, dialog.ctx.usedTexts do
        out[#out + 1] = dialog.ctx.texts[index].text
    end

    return table.concat(out, '\n')
end

test('with nothing recorded the report says so and opens no window', function()
    local _, a, printed = client()
    assert(a:ShowMetricsGraphs() == nil and printed[1] == 'No metrics have been recorded yet.')
end)

test('the report draws the gauge, where the casts went, the reaction chart, the deviations and the output', function()
    local _, a = client()

    fight(a.Metrics, 'rot', {
        { advice = FIREBALL, at = 101 },
        { cast = FIREBALL, at = 101.5 },
        { advice = FROSTBOLT, at = 103 },
        { cast = BLINK, at = 104 },
        { advice = FIREBALL, at = 105 },
        { cast = FIREBALL, at = 105.2 },
    })

    local dialog = a:ShowMetricsGraphs()
    assert(dialog and dialog.frame:IsShown() and dialog.report.rotations[1].id == 'rot')
    local shown = texts(dialog)
    assert(shown:find('Followed the advice', 1, true) and shown:find('67%', 1, true), shown)
    assert(shown:find('Where your casts went', 1, true) and shown:find('Followed: 2', 1, true), shown)
    assert(shown:find('Outside the rotation: 1', 1, true), 'Blink was never advised: outside the rotation')
    assert(shown:find('Time to act on advice', 1, true) and shown:find('Average time to act', 1, true), shown)

    assert(
        shown:find('Damage and healing per second', 1, true) and shown:find('Damage per second: 1000', 1, true),
        shown
    )

    assert(
        shown:find('Most common deviations', 1, true) and shown:find('Spell 116', 1, true),
        'the spell that was not cast'
    )

    assert(not shown:find('Forecast accuracy', 1, true), 'no forecast was tracked')
    assert(dialog.content:GetHeight() > 400, 'the content is as tall as what was drawn')
end)

test('there is a tab for each rotation, and choosing one redraws', function()
    local _, a = client()
    local steps = { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } }
    fight(a.Metrics, 'one', steps)
    fight(a.Metrics, 'two', steps)
    fight(a.Metrics, 'two', steps)
    local dialog = a:ShowMetricsGraphs()
    assert(#dialog.report.rotations == 2 and dialog.tabs[1]:IsShown() and dialog.tabs[2]:IsShown())
    assert(dialog.report.rotations[1].id == 'two', 'most fights first')
    assert(texts(dialog):find('2 fights', 1, true))
    dialog.tabs[2].scripts.OnClick(dialog.tabs[2])
    assert(dialog.selected == 2 and texts(dialog):find('1 fights', 1, true), texts(dialog))
end)

test('opening it again reuses the drawing; the export is still the website JSON in the text window', function()
    local _, a = client()
    local shown

    a.ShowConditionText = function(_, text, title)
        shown = { text = text, title = title }
    end

    fight(a.Metrics, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    local dialog = a:ShowMetricsGraphs()
    local textures, texts_ = #dialog.ctx.textures, #dialog.ctx.texts
    a:ShowMetricsGraphs()
    assert(#dialog.ctx.textures == textures and #dialog.ctx.texts == texts_, 'a second opening creates nothing new')
    assert(a:ShowMetricsExport('json') == true and shown.text:find('"format":"rm-metrics"', 1, true))
    assert(a.Metrics.ToPrompt == nil, 'the language model export is gone')
end)

finish()
