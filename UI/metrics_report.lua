-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shows and exports the numbers addon.Metrics (Analytics/metrics.lua) collected, on the Metrics tab of the settings window.
-- The page holds the three recording switches and the report, which is graphs, not text: a gauge for how closely the advice was followed, a bar of where the casts went, a chart of how long it took to
-- act on the advice, output by how closely the advice was followed, the most common deviations and, when it was tracked,
-- how often the forecast was right. The JSON the website reads opens in the selectable text window
-- (addon:ShowConditionText) so Ctrl-A, Ctrl-C copies it; it is data, not interface text, and stays in English. Owns no
-- saved data. Loaded from the UI section of RotationMaster.toc; used by UI/settings_general.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

local CONTENT = 600
local GAP, ROW = 6, 26

local GREEN, YELLOW, RED, GRAY, BLUE = { .35, .8, .4 }, { .95, .75, .2 }, { .9, .35, .3 }, { .5, .52, .56 }, {
    .35,
    .6,
    .95,
}

local TRACK = { .14, .15, .17 }
local MAX_TABS, MAX_DEVIATIONS = 5, 8

-- The units of a timed period, with the minutes in one and the most of them the slider offers.
local UNITS = {
    { key = 'minutes', factor = 1, max = 180 },
    { key = 'hours', factor = 60, max = 72 },
    { key = 'days', factor = 1440, max = 30 },
}

-- The periods a report can be limited to, in the order of their buttons.
local SCOPES = { 'last', 'session', 'instance', 'minutes', 'all' }

-- Names a spell and finds its icon.
-- @param id number  The spell id.
-- @return string|nil  The spell's name, or nil when the game does not know it.
-- @return number|string|nil  The spell's icon.
local function spellFacts(id)
    local info = platform:GetSpellInfo(id)

    if not info then
        return nil
    end

    return type(info.name) == 'string' and info.name or nil, info.iconID
end

-- Names a spell.
-- @param id number  The spell id.
-- @return string|nil  The spell's name, or nil when the game does not know it.
local function spellName(id)
    return (spellFacts(id))
end

-- Names a rotation.
-- @param id string  The rotation id.
-- @return string|nil  The rotation's name.
local function rotationName(id)
    if type(addon.GetRotationName) ~= 'function' then
        return nil
    end

    local ok, name = pcall(addon.GetRotationName, addon, id)
    return ok and type(name) == 'string' and name or nil
end

-- Describes the client in plain facts for the export.
-- @return table  { family, interface }.
local function clientFacts()
    local info = platform:GetClientInfo()
    return { family = info.family, interface = select(4, GetBuildInfo()) }
end

-- The labels of the adherence tiers.
local tierNames = {
    low = L['Low adherence'],
    middle = L['Medium adherence'],
    high = L['High adherence'],
}

-- ============================================================================
-- Drawing: a pool of textures and text, reused on every redraw
-- ============================================================================

-- Starts a redraw: every pooled region is hidden and handed out again from the start.
-- @param ctx table  The drawing context { content, textures, texts, usedTextures, usedTexts }.
local function reset(ctx)
    for index = 1, ctx.usedTextures do
        ctx.textures[index]:Hide()
    end

    for index = 1, ctx.usedTexts do
        ctx.texts[index]:Hide()
    end

    ctx.usedTextures, ctx.usedTexts = 0, 0
end

-- Takes the next pooled texture, placed at a point and size.
-- @param ctx table  The drawing context.
-- @param x number  Left edge, from the content's left.
-- @param y number  Top edge, downward from the content's top.
-- @param w number  Width.
-- @param h number  Height.
-- @return table  The texture.
local function take(ctx, x, y, w, h)
    ctx.usedTextures = ctx.usedTextures + 1
    local texture = ctx.textures[ctx.usedTextures]

    if not texture then
        texture = ctx.content:CreateTexture(nil, 'ARTWORK')
        ctx.textures[ctx.usedTextures] = texture
    end

    texture:ClearAllPoints()
    texture:SetPoint('TOPLEFT', ctx.content, 'TOPLEFT', x, -y)
    texture:SetSize(math.max(0, w), math.max(0, h))
    return texture
end

-- Draws a filled rectangle.
-- @param ctx table  The drawing context.
-- @param x number  Left edge.
-- @param y number  Top edge, downward.
-- @param w number  Width.
-- @param h number  Height.
-- @param color table  { red, green, blue }.
-- @param alpha number|nil  Opacity; 1 by default.
local function rect(ctx, x, y, w, h, color, alpha)
    local texture = take(ctx, x, y, w, h)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    texture:Show()
end

-- Draws a spell icon.
-- @param ctx table  The drawing context.
-- @param x number  Left edge.
-- @param y number  Top edge, downward.
-- @param size number  Width and height.
-- @param icon number|string  The texture.
local function drawIcon(ctx, x, y, size, icon)
    local texture = take(ctx, x, y, size, size)
    texture:SetTexture(icon)
    texture:SetTexCoord(.07, .93, .07, .93)
    texture:SetVertexColor(1, 1, 1)
    texture:Show()
end

-- Draws a line of text.
-- @param ctx table  The drawing context.
-- @param x number  Left edge.
-- @param y number  Top edge, downward.
-- @param message string  The text.
-- @param font string|nil  The font object; the small highlighted font by default.
-- @param width number|nil  The width the text is held to.
-- @param justify string|nil  "LEFT" (default), "CENTER" or "RIGHT".
local function text(ctx, x, y, message, font, width, justify)
    ctx.usedTexts = ctx.usedTexts + 1
    local label = ctx.texts[ctx.usedTexts]

    if not label then
        label = ctx.content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        label:SetWordWrap(false)
        ctx.texts[ctx.usedTexts] = label
    end

    label:SetFontObject(font or 'GameFontHighlightSmall')
    label:ClearAllPoints()
    label:SetPoint('TOPLEFT', ctx.content, 'TOPLEFT', x, -y)
    label:SetWidth(width or CONTENT - x)
    label:SetJustifyH(justify or 'LEFT')
    label:SetText(message)
    label:Show()
end

-- Draws a section heading with a rule under it.
-- @param ctx table  The drawing context.
-- @param y number  Top edge.
-- @param message string  The heading.
-- @return number  The y under the heading.
local function heading(ctx, y, message)
    text(ctx, 0, y, message, 'GameFontNormal')
    rect(ctx, 0, y + 18, CONTENT, 1, GRAY, .5)
    return y + 26
end

-- Picks the color of an adherence percentage.
-- @param percent number|nil  The percentage.
-- @return table  Green from 85, yellow from 60, red below; gray when unknown.
local function adherenceColor(percent)
    if not percent then
        return GRAY
    end

    return percent >= 85 and GREEN or percent >= 60 and YELLOW or RED
end

-- ============================================================================
-- The sections
-- ============================================================================

-- Draws the gauge for how closely the advice was followed.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary from addon.Metrics:Report.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function gauge(ctx, rotation, y)
    local percent = rotation.followedPercent
    text(ctx, 0, y, L['Followed the advice'], 'GameFontNormal', 300)
    text(ctx, CONTENT - 200, y - 6, percent and (tostring(percent) .. '%') or '-', 'GameFontNormalHuge', 200, 'RIGHT')
    rect(ctx, 0, y + 24, CONTENT, 16, TRACK)

    if percent then
        rect(ctx, 0, y + 24, CONTENT * math.min(100, percent) / 100, 16, adherenceColor(percent))
    end

    -- Ticks where the tiers change: 60 and 85 percent.
    rect(ctx, CONTENT * .60, y + 22, 1, 20, GRAY)
    rect(ctx, CONTENT * .85, y + 22, 1, 20, GRAY)
    return y + 56
end

-- Draws the bar of where the casts went, and its legend.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function castBar(ctx, rotation, y)
    y = heading(ctx, y, L['Where your casts went'])

    local parts = {
        { L['Followed'], rotation.followed, GREEN },
        { L['Out of order'], rotation.outOfOrder, YELLOW },
        { L['Outside the rotation'], rotation.outside, RED },
        { L['No advice'], rotation.unadvised, GRAY },
    }

    local total = 0

    for _, part in ipairs(parts) do
        total = total + part[2]
    end

    rect(ctx, 0, y, CONTENT, 22, TRACK)

    if total > 0 then
        local x = 0

        for _, part in ipairs(parts) do
            local width = CONTENT * part[2] / total

            if width > 0 then
                rect(ctx, x, y, width, 22, part[3])
                x = x + width
            end
        end
    end

    y = y + 30

    for index, part in ipairs(parts) do
        local x, top = ((index - 1) % 2) * (CONTENT / 2), y + math.floor((index - 1) / 2) * 18
        local share = total > 0 and string.format(' (%d%%)', part[2] * 100 / total + .5) or ''
        rect(ctx, x, top + 3, 10, 10, part[3])
        text(ctx, x + 16, top, string.format('%s: %d%s', part[1], part[2], share), nil, CONTENT / 2 - 20)
    end

    return y + 44
end

-- Draws the chart of how long it took to act on the advice.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function reaction(ctx, rotation, y)
    y = heading(ctx, y, L['Time to act on advice'])
    local edges = addon.Metrics.DELAY_EDGES or {}
    local highest = 1

    for _, count in ipairs(rotation.delayHistogram) do
        highest = math.max(highest, count)
    end

    if rotation.meanDelay then
        text(
            ctx,
            0,
            y,
            string.format(L['Average time to act on a recommendation: %s seconds'], tostring(rotation.meanDelay)),
            nil,
            CONTENT
        )

        y = y + 20
    end

    local slot, base = CONTENT / #rotation.delayHistogram, y + 90

    for index, count in ipairs(rotation.delayHistogram) do
        local height = 70 * count / highest
        local x = (index - 1) * slot + slot * .2
        rect(ctx, x, base - height, slot * .6, height, BLUE)
        text(ctx, x - 10, base - height - 14, tostring(count), nil, slot * .6 + 20, 'CENTER')
        local label = index <= #edges and ('< ' .. tostring(edges[index])) or ('> ' .. tostring(edges[#edges] or ''))
        text(ctx, x - 10, base + 3, label, nil, slot * .6 + 20, 'CENTER')
    end

    rect(ctx, 0, base, CONTENT, 1, GRAY, .6)
    return base + 28
end

-- Draws damage and healing, and how they differ with how closely the advice was followed.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function output(ctx, rotation, y)
    if not rotation.dps then
        return y
    end

    y = heading(ctx, y, L['Damage and healing per second'])

    text(
        ctx,
        0,
        y,
        string.format(L['Damage per second: %d, healing per second: %d'], rotation.dps, rotation.hps or 0),
        nil,
        CONTENT
    )

    y = y + 22
    local highest = 1

    for _, tier in ipairs(rotation.byAdherence) do
        highest = math.max(highest, tier.dps)
    end

    for _, tier in ipairs(rotation.byAdherence) do
        local color = tier.tier == 'high' and GREEN or tier.tier == 'low' and RED or YELLOW
        text(ctx, 0, y, tierNames[tier.tier] or tostring(tier.tier), nil, 120)
        rect(ctx, 125, y, CONTENT - 125, 14, TRACK)
        rect(ctx, 125, y, (CONTENT - 125) * tier.dps / highest, 14, color)
        text(ctx, 130, y, string.format('%d  (%d)', tier.dps, tier.fights), nil, CONTENT - 135)
        y = y + 20
    end

    return y + 10
end

-- Counts how often a spell's advice was not followed.
-- @param spell table  One advised spell of the report.
-- @return number  Its not-acted-on count and every replacement count together.
local function deviations(spell)
    local total = spell.superseded

    for _, other in ipairs(spell.replacedBy) do
        total = total + other.count
    end

    return total
end

-- Draws the spells whose advice was most often not followed, and what was cast instead.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function deviationList(ctx, rotation, y)
    local rows = {}

    for _, spell in ipairs(rotation.spells) do
        if deviations(spell) > 0 then
            rows[#rows + 1] = spell
        end
    end

    table.sort(rows, function(a, b)
        return deviations(a) > deviations(b) or deviations(a) == deviations(b) and a.spell < b.spell
    end)

    if #rows == 0 and #rotation.outsideSpells == 0 then
        return y
    end

    y = heading(ctx, y, L['Most common deviations'])
    local highest = 1

    for index = 1, math.min(#rows, MAX_DEVIATIONS) do
        highest = math.max(highest, rows[index].followed + deviations(rows[index]))
    end

    local scale = (CONTENT - 200) / highest

    for index = 1, math.min(#rows, MAX_DEVIATIONS) do
        local spell = rows[index]
        local name, icon = spellFacts(spell.spell)
        local replaced = {}

        for position, other in ipairs(spell.replacedBy) do
            if position > 3 then
                break
            end

            replaced[#replaced + 1] = string.format('%s x%d', other.name or tostring(other.spell), other.count)
        end

        if icon then
            drawIcon(ctx, 0, y, 16, icon)
        end

        text(ctx, 22, y + 1, spell.name or name or tostring(spell.spell), nil, 170)
        rect(ctx, 195, y + 2, spell.followed * scale, 12, GREEN)
        rect(ctx, 195 + spell.followed * scale, y + 2, deviations(spell) * scale, 12, RED)
        local detail = string.format('%d  /  %d', spell.followed, deviations(spell))

        text(
            ctx,
            195,
            y + 1,
            detail .. (#replaced > 0 and ('   ' .. table.concat(replaced, ', ')) or ''),
            nil,
            CONTENT - 200
        )

        y = y + 22
    end

    for index = 1, math.min(#rotation.outsideSpells, 5) do
        local other = rotation.outsideSpells[index]
        local _, icon = spellFacts(other.spell)

        if icon then
            drawIcon(ctx, 0, y, 16, icon)
        end

        text(ctx, 22, y + 1, string.format('%s x%d', other.name or tostring(other.spell), other.count), nil, 170)
        rect(ctx, 195, y + 2, math.min(CONTENT - 200, other.count * scale), 12, YELLOW)
        y = y + 22
    end

    return y + 8
end

-- Draws how often the forecast of each later recommendation turned out right.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function forecastAccuracy(ctx, rotation, y)
    if #rotation.predictionAccuracy == 0 then
        return y
    end

    y = heading(ctx, y, L['Forecast accuracy'])

    for _, row in ipairs(rotation.predictionAccuracy) do
        local message = string.format(
            L['Prediction %d: right %d%% of the time, said %d%% sure'],
            row.slot,
            row.hitPercent,
            row.meanConfidencePercent
        )

        text(ctx, 0, y, message, nil, 330)
        rect(ctx, 340, y + 1, CONTENT - 340, 6, TRACK)
        rect(ctx, 340, y + 1, (CONTENT - 340) * row.hitPercent / 100, 6, GREEN)
        rect(ctx, 340, y + 9, CONTENT - 340, 6, TRACK)
        rect(ctx, 340, y + 9, (CONTENT - 340) * row.meanConfidencePercent / 100, 6, BLUE)
        y = y + 24
    end

    return y + 8
end

-- Writes a percentage, or a change in one, to a decimal place.
-- @param value number  The value.
-- @return string  The text.
local function percentText(value)
    return string.format('%.1f%%', value)
end

-- Writes a change to a decimal place, signed.
-- @param value number  The change.
-- @return string  The text.
local function signedText(value)
    return string.format('%+.1f', value)
end

-- Writes a whole number.
-- @param value number  The value.
-- @return string  The text.
local function wholeText(value)
    return string.format('%d', value)
end

-- Writes a whole change, signed.
-- @param value number  The change.
-- @return string  The text.
local function signedWholeText(value)
    return string.format('%+d', value)
end

-- The figures the comparison sets side by side: the label, the value of a summary (nil when it has none), whether more
-- is better, and how a value and a change in it are written.
local FIGURES = {
    {
        label = function()
            return L['Followed the advice']
        end,
        value = function(r)
            return r.followedPercent
        end,
        higher = true,
        show = percentText,
        change = signedText,
    },
    {
        label = function()
            return L['Time to act (seconds)']
        end,
        value = function(r)
            return r.meanDelay
        end,
        higher = false,
        show = function(v)
            return string.format('%.2f', v)
        end,
        change = function(v)
            return string.format('%+.2f', v)
        end,
    },
    {
        label = function()
            return L['Damage per second']
        end,
        value = function(r)
            return r.dps
        end,
        higher = true,
        show = wholeText,
        change = signedWholeText,
    },
    {
        label = function()
            return L['Healing per second']
        end,
        value = function(r)
            return r.hps
        end,
        higher = true,
        show = wholeText,
        change = signedWholeText,
    },
    {
        label = function()
            return L['Outside the rotation']
        end,
        value = function(r)
            return r.casts > 0 and r.outside * 100 / r.casts or nil
        end,
        higher = false,
        show = percentText,
        change = signedText,
    },
    {
        label = function()
            return L['Out of order']
        end,
        value = function(r)
            return r.casts > 0 and r.outOfOrder * 100 / r.casts or nil
        end,
        higher = false,
        show = percentText,
        change = signedText,
    },
}

-- Draws the figures of the rotation shown beside those of what it is compared with, and whether each got better.
-- @param ctx table  The drawing context.
-- @param rotation table  The rotation shown.
-- @param compare table  { label, summary } where summary is nil when nothing was recorded for the comparison.
-- @param y number  Top edge.
-- @return number  The y under the section.
local function comparison(ctx, rotation, compare, y)
    y = heading(ctx, y, L['Comparison'])
    local other = compare.summary

    if not other then
        text(ctx, 0, y, string.format(L['%s: nothing was recorded.'], compare.label), nil, CONTENT)
        return y + 28
    end

    text(
        ctx,
        0,
        y,
        string.format(L['%s (%d fights, %d casts)'], compare.label, other.fights, other.casts),
        'GameFontNormal',
        CONTENT
    )

    y = y + 22
    local nameW, valueW = CONTENT * .34, CONTENT * .2
    local shownX, otherX, changeX = nameW, nameW + valueW, nameW + valueW * 2
    text(ctx, shownX, y, L['Shown'], nil, valueW - 8, 'RIGHT')
    text(ctx, otherX, y, L['Compared'], nil, valueW - 8, 'RIGHT')
    text(ctx, changeX, y, L['Change'], nil, valueW - 8, 'RIGHT')
    y = y + 18

    for _, figure in ipairs(FIGURES) do
        local a, b = figure.value(rotation), figure.value(other)

        if a ~= nil or b ~= nil then
            text(ctx, 0, y, figure.label(), nil, nameW - 8)
            text(ctx, shownX, y, a ~= nil and figure.show(a) or '-', nil, valueW - 8, 'RIGHT')
            text(ctx, otherX, y, b ~= nil and figure.show(b) or '-', nil, valueW - 8, 'RIGHT')

            if a ~= nil and b ~= nil then
                local diff = a - b
                local label = figure.change(diff)
                local color = GRAY

                -- A change under two percent of what it is compared with, or that writes as zero, is no change.
                if math.abs(diff) > 0.02 * math.abs(b) and not label:find('^[+-]0%.?0*$') then
                    color = (diff > 0) == figure.higher and GREEN or RED
                end

                rect(ctx, changeX + valueW - 6, y + 2, 3, 12, color)
                text(ctx, changeX, y, label, nil, valueW - 14, 'RIGHT')
            end

            y = y + 18
        end
    end

    text(ctx, 0, y + 2, L['Green is better, red is worse.'], nil, CONTENT)
    return y + 26
end

-- Draws the note shown when nothing was recorded for the chosen period.
-- @param ctx table  The drawing context.
-- @return number  The height used.
local function drawEmpty(ctx)
    reset(ctx)
    text(ctx, 0, 20, L['Nothing was recorded for this period.'], 'GameFontNormal', CONTENT)
    return 60
end

-- Draws one rotation's whole report.
-- @param ctx table  The drawing context.
-- @param rotation table  One rotation's summary.
-- @param compare table|nil  What it is compared with: { label, summary }.
-- @return number  The height used.
local function draw(ctx, rotation, compare)
    reset(ctx)
    text(ctx, 0, 0, rotation.name or rotation.id, 'GameFontNormalLarge', CONTENT)

    local counts = string.format(
        L['%d fights, %d seconds, %d casts'],
        rotation.fights,
        rotation.seconds,
        rotation.casts
    )

    text(ctx, 0, 24, counts, nil, CONTENT)
    local y = 50

    if compare then
        y = comparison(ctx, rotation, compare, y)
    end

    y = gauge(ctx, rotation, y)
    y = castBar(ctx, rotation, y)
    y = reaction(ctx, rotation, y)
    y = output(ctx, rotation, y)
    y = deviationList(ctx, rotation, y)
    return forecastAccuracy(ctx, rotation, y)
end

-- ============================================================================
-- The Metrics page
-- ============================================================================

-- The view the player chose, kept while the window is open: the period, what it is compared with, the rotation tab and
-- the export option.
-- @return table  { scope = { kind, amount, unit }, compare = { kind, amount, unit, instance, rotation }, tab, instructions }.
local function viewState()
    local state = addon.metricsView

    if not state then
        state = { instructions = false, tab = 1 }
        addon.metricsView = state
    end

    state.compare = state.compare or { kind = 'none', amount = 1, unit = 'hours' }
    return state
end

-- Finds a unit of a timed period.
-- @param key string|nil  'minutes', 'hours' or 'days'.
-- @return table  The unit; minutes when unknown.
local function unitOf(key)
    for _, unit in ipairs(UNITS) do
        if unit.key == key then
            return unit
        end
    end

    return UNITS[1]
end

-- Names a unit of time.
-- @param key string  'minutes', 'hours' or 'days'.
-- @param capital boolean|nil  True for the name on its button.
-- @return string  The name.
local function unitName(key, capital)
    if key == 'hours' then
        return capital and L['Hours'] or L['hours']
    elseif key == 'days' then
        return capital and L['Days'] or L['days']
    end

    return capital and L['Minutes'] or L['minutes']
end

-- Writes a timed period.
-- @param spec table  { amount, unit }.
-- @return string  For example "Last 3 hours".
local function periodLabel(spec)
    return string.format(L['Last %d %s'], spec.amount or 30, unitName(spec.unit))
end

-- Tells how many minutes a timed period is.
-- @param spec table  { amount, unit }.
-- @return number  The minutes.
local function minutesOf(spec)
    return (spec.amount or 30) * unitOf(spec.unit).factor
end

-- Makes the recorder's scope of a kind of period.
-- @param kind string  The kind of period.
-- @param period table  { amount, unit }, read by the timed kinds.
-- @return table  The scope addon.Metrics:Report takes.
local function scopeOf(kind, period)
    if kind == 'minutes' or kind == 'before' then
        return { kind = kind, minutes = minutesOf(period) }
    end

    return { kind = kind }
end

-- Lists what a period can be compared with, in the order the button steps through them.
-- @param kind string  The kind of period being shown.
-- @param instances number  How many other instances have fights.
-- @param rotations number  How many other rotations have fights.
-- @return string[]  The kinds of comparison.
local function compareKinds(kind, instances, rotations)
    local out = { 'none' }

    if kind == 'last' then
        out[#out + 1] = 'previous'
    end
    if kind == 'minutes' then
        out[#out + 1] = 'before'
    end
    if kind ~= 'session' then
        out[#out + 1] = 'session'
    end
    if kind ~= 'instance' then
        out[#out + 1] = 'instance'
    end
    if instances > 0 then
        out[#out + 1] = 'otherInstance'
    end

    out[#out + 1] = 'minutes'

    if kind ~= 'all' then
        out[#out + 1] = 'all'
    end
    if rotations > 0 then
        out[#out + 1] = 'otherRotation'
    end

    return out
end

-- Draws the Metrics page into the settings pane: the recording switches, then the period buttons, the comparison, the
-- rotation tabs, the graphs and the export. Runs on every redraw of the page, which the pane does when it is resized; the
-- controls come from the pane's pools and spread over the pane's width.
-- @param p table  The settings pane.
function addon:BuildMetricsSettings(p)
    local profile = p:SettingsData().profile
    local metrics = addon.Metrics
    local state = viewState()
    CONTENT = math.max(340, p.width)
    p:Heading(L['Metrics'])

    p:Check(
        'metrics_adherence',
        L['Track how closely I follow the advice'],
        profile.metrics_adherence == true,
        function(v)
            profile.metrics_adherence = v

            p:RunSettingsEffect('metrics_adherence', function()
                self:ApplyMetricsSettings()
            end)
        end
    )

    p:Check(
        'metrics_effectiveness',
        L['Track damage and healing per fight'],
        profile.metrics_effectiveness == true,
        function(v)
            profile.metrics_effectiveness = v

            p:RunSettingsEffect('metrics_effectiveness', function()
                self:ApplyMetricsSettings()
            end)
        end
    )

    p:Check(
        'metrics_prediction',
        L['Track how accurate the predictions were'],
        profile.metrics_prediction == true,
        function(v)
            profile.metrics_prediction = v

            p:RunSettingsEffect('metrics_prediction', function()
                self:ApplyMetricsSettings()
            end)
        end
    )

    local top = p.y + 6
    local controls = { scope = {}, tabs = {}, units = {}, compareUnits = {}, generation = p.generation }
    p.metricsControls = controls

    -- Acquires a button from the pane's pool.
    -- @param key string  The pool.
    -- @param width number  Its first width.
    -- @return table  The button.
    local function button(key, width)
        return p:Acquire(key, function()
            return addon:CreateWorkbenchButton(p.child, '', width)
        end)
    end

    -- The period: one button for each, and Reset after them.
    for _, kind in ipairs(SCOPES) do
        local b = button('metricsScope', 110)
        controls.scope[kind] = b

        addon:SetUIScript(b, 'OnClick', p:Guard(function()
            local was = state.scope or {}
            state.scope, state.tab = { kind = kind, amount = was.amount or 30, unit = was.unit or 'minutes' }, 1
            controls.render()
        end))
    end

    -- Reset deletes everything recorded; it asks once more (the button reads Confirm for a few seconds) before it does.
    local reset = button('metricsReset', 80)
    reset:SetText(L['Reset'])
    controls.reset = reset
    local armed

    addon:SetUIScript(reset, 'OnClick', p:Guard(function()
        if not armed then
            armed = true
            reset:SetText(L['Confirm'])

            if C_Timer and type(C_Timer.After) == 'function' then
                C_Timer.After(4, function()
                    armed = nil
                    reset:SetText(L['Reset'])
                end)
            end

            return
        end

        armed = nil
        reset:SetText(L['Reset'])
        addon:ClearMetrics()
        controls.render()
    end))

    -- Makes the slider and unit buttons of a timed period.
    -- @param slider string  The slider's pool.
    -- @param list table  Where the unit buttons are kept.
    -- @param spec function  Returns the period table the controls change.
    -- @param active function  Returns true while the controls are in use.
    -- @return table  The slider.
    local function timeControls(slider, list, spec, active)
        local s = p:Acquire(slider, function()
            return addon:CreateWorkbenchSlider(p.child, 1, UNITS[1].max, 1, 200)
        end)

        addon:SetUIScript(s, 'OnValueChanged', function(_, value)
            value = math.floor((value or 30) + .5)

            if p:Valid(controls.generation) and not controls.syncing and active() and spec().amount ~= value then
                spec().amount = value
                controls.render()
            end
        end)

        for index, unit in ipairs(UNITS) do
            local b = button('metricsUnit', 70)
            list[index] = b

            addon:SetUIScript(b, 'OnClick', p:Guard(function()
                local period = spec()
                period.unit = unit.key
                period.amount = math.max(1, math.min(period.amount or 30, unit.max))
                controls.render()
            end))
        end

        return s
    end

    controls.minutes = timeControls(
        'metricsMinutes',
        controls.units,
        function()
            return state.scope
        end,
        function()
            return state.scope and state.scope.kind == 'minutes'
        end
    )

    -- What the period is compared with: a button that steps through the choices, and a second to choose within one.
    controls.compare = button('metricsCompare', 300)
    controls.compareDetail = button('metricsCompareDetail', 240)

    addon:SetUIScript(controls.compare, 'OnClick', p:Guard(function()
        local kinds = controls.compareKinds or { 'none' }
        local index = 1

        for position, kind in ipairs(kinds) do
            if kind == state.compare.kind then
                index = position
            end
        end

        state.compare.kind = kinds[index % #kinds + 1]
        controls.render()
    end))

    addon:SetUIScript(controls.compareDetail, 'OnClick', p:Guard(function()
        local choices = controls.compareChoices or {}

        if #choices == 0 then
            return
        end

        local key = state.compare.kind == 'otherInstance' and 'instance' or 'rotation'
        local index = 0

        for position, choice in ipairs(choices) do
            if choice.key == state.compare[key] then
                index = position
            end
        end

        state.compare[key] = choices[index % #choices + 1].key
        controls.render()
    end))

    controls.compareMinutes = timeControls(
        'metricsCompareMinutes',
        controls.compareUnits,
        function()
            return state.compare
        end,
        function()
            return state.compare.kind == 'minutes'
        end
    )

    -- A tab for each rotation, when there is more than one.
    for index = 1, MAX_TABS do
        local tab = button('metricsTab', 120)
        tab:Hide()
        controls.tabs[index] = tab

        addon:SetUIScript(tab, 'OnClick', p:Guard(function()
            state.tab = index
            controls.render()
        end))
    end

    local canvas = p:Acquire('metricsCanvas', function()
        return CreateFrame('Frame', nil, p.child)
    end)

    canvas.ctx = canvas.ctx or { content = canvas, textures = {}, texts = {}, usedTextures = 0, usedTexts = 0 }
    controls.canvas = canvas

    -- The export, under the graphs: the website's JSON of the period shown, or that behind instructions for a language model.
    local export = p:Acquire('metricsExport', function()
        return addon:CreateWorkbenchButton(p.child, L['Export for the website'], 200)
    end)

    export:SetText(L['Export for the website'])
    controls.export = export

    local instructions = p:Acquire('metricsInstructions', function()
        return addon:CreateWorkbenchCheckBox(p.child, L['Add instructions for a language model'], 320)
    end)

    instructions:SetChecked(state.instructions == true)
    controls.instructions = instructions

    addon:SetUIScript(instructions, 'OnClick', function()
        state.instructions = instructions:GetChecked() == true
    end)

    -- Places controls in rows across the width: as many to a row as fit at the least width, each taking an equal share.
    -- @param items table[]  The controls, in order.
    -- @param y number  Top of the first row.
    -- @param least number  The least width of one.
    -- @return number  The y under the rows.
    local function grid(items, y, least)
        local columns = math.max(1, math.min(#items, math.floor((CONTENT + GAP) / (least + GAP))))
        local width = math.floor((CONTENT - (columns - 1) * GAP) / columns)

        for index, item in ipairs(items) do
            local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
            item:ClearAllPoints()
            item:SetPoint('TOPLEFT', column * (width + GAP), -(y + row * (ROW + GAP)))
            item:SetWidth(width)
        end

        return y + math.ceil(#items / columns) * (ROW + GAP)
    end

    -- Places a timed period's slider and unit buttons in a row: the slider takes what the buttons leave.
    -- @param slider table  The slider.
    -- @param units table[]  The unit buttons.
    -- @param y number  Top of the row.
    -- @return number  The y under the row.
    local function timeRow(slider, units, y)
        local each = 70
        local width = #units * (each + GAP)
        slider:ClearAllPoints()
        slider:SetPoint('TOPLEFT', 8, -(y + 7))
        slider:SetWidth(math.max(80, CONTENT - width - 16))

        for index, unit in ipairs(units) do
            unit:ClearAllPoints()
            unit:SetPoint('TOPLEFT', CONTENT - width + (index - 1) * (each + GAP) + GAP, -y)
            unit:SetWidth(each)
        end

        return y + ROW + GAP
    end

    -- Shows or hides a timed period's controls, and sets them to the period.
    -- @param slider table  The slider.
    -- @param units table[]  The unit buttons.
    -- @param spec table  { amount, unit }.
    -- @param shown boolean  True to show them.
    local function syncTime(slider, units, spec, shown)
        for index, unit in ipairs(units) do
            unit:SetText(unitName(UNITS[index].key, true))
            unit:SetSelected(spec.unit == UNITS[index].key)

            if shown then
                unit:Show()
            else
                unit:Hide()
            end
        end

        if shown then
            local unit = unitOf(spec.unit)
            controls.syncing = true
            slider:SetMinMaxValues(1, unit.max)
            slider:SetValue(spec.amount or 30)
            controls.syncing = nil
            slider:Show()
        else
            slider:Hide()
        end
    end

    -- Finds the figures of the rotation shown in what it is compared with.
    -- @param shown table  The rotation shown.
    -- @param where table|nil  Where the player is.
    -- @return table|nil  { label, summary }, or nil when nothing is compared.
    local function baseline(shown, where)
        local cmp = state.compare
        local kind = cmp.kind

        if kind == 'none' then
            return nil
        end

        local scope, id, label

        if kind == 'otherRotation' then
            scope, id = scopeOf(state.scope.kind, state.scope), cmp.rotation
            label = rotationName(id) or tostring(id)
        elseif kind == 'otherInstance' then
            scope, id = { kind = 'instance', instance = cmp.instance }, shown.id

            for _, place in ipairs(metrics:Instances()) do
                if place.key == cmp.instance then
                    label = place.name or tostring(place.key)
                end
            end
        elseif kind == 'minutes' then
            scope, label = scopeOf('minutes', cmp), periodLabel(cmp)
        elseif kind == 'before' then
            scope, label = scopeOf('before', state.scope), L['The period before']
        elseif kind == 'previous' then
            scope, label = scopeOf(kind), L['The previous fight']
        elseif kind == 'instance' then
            scope, label = scopeOf(kind), L['This instance']
        elseif kind == 'session' then
            scope, label = scopeOf(kind), L['This session']
        else
            scope, label = scopeOf('all'), L['All time']
        end

        id = id or shown.id

        local report = metrics:Report(rotationName, spellName, scope, { instance = where and where.instance })
        local found

        for _, rotation in ipairs(report.rotations) do
            if rotation.id == id then
                found = rotation
            end
        end

        return { label = label or '', summary = found }
    end

    -- Draws everything below the switches for the period chosen, and sets the page's height to fit.
    function controls.render()
        local where = addon.GetMetricsWhere and addon:GetMetricsWhere() or nil
        local context = { instance = where and where.instance }

        if not state.scope then
            local last = #metrics:Report(nil, nil, { kind = 'last' }).rotations > 0
            state.scope = { kind = last and 'last' or 'all', amount = 30, unit = 'minutes' }
        end

        local scope = state.scope
        controls.report = metrics:Report(rotationName, spellName, scopeOf(scope.kind, scope), context)

        for kind, b in pairs(controls.scope) do
            local label = kind == 'last' and L['Last fight']
                or kind == 'session' and L['This session']
                or kind == 'instance' and L['This instance']
                or kind == 'minutes' and periodLabel(scope)
                or L['All time']

            b:SetText(label)
            b:SetSelected(scope.kind == kind)
        end

        local shownRotations = controls.report.rotations
        local count = math.min(#shownRotations, MAX_TABS)
        state.tab = math.max(1, math.min(state.tab or 1, math.max(1, count)))
        local shown = shownRotations[state.tab]

        -- What there is to compare with.
        local cmp = state.compare
        local places, others = {}, {}

        for _, place in ipairs(metrics:Instances()) do
            if place.key ~= context.instance then
                places[#places + 1] = place
            end
        end

        for _, rotation in ipairs(metrics:Report(nil, nil, nil).rotations) do
            if not shown or rotation.id ~= shown.id then
                others[#others + 1] = { key = rotation.id, name = rotationName(rotation.id) or rotation.id }
            end
        end

        local kinds = compareKinds(scope.kind, #places, #others)
        controls.compareKinds = kinds
        local valid

        for _, kind in ipairs(kinds) do
            valid = valid or kind == cmp.kind
        end

        cmp.kind = valid and cmp.kind or 'none'
        cmp.amount, cmp.unit = cmp.amount or 1, cmp.unit or 'hours'
        local choices = cmp.kind == 'otherInstance' and places or cmp.kind == 'otherRotation' and others or {}
        controls.compareChoices = choices
        local chosen

        for _, choice in ipairs(choices) do
            if choice.key == (cmp.kind == 'otherInstance' and cmp.instance or cmp.rotation) then
                chosen = choice
            end
        end

        chosen = chosen or choices[1]

        if chosen then
            cmp[cmp.kind == 'otherInstance' and 'instance' or 'rotation'] = chosen.key
        end

        local kindLabels = {
            none = L['Nothing'],
            previous = L['The previous fight'],
            before = L['The period before'],
            session = L['This session'],
            instance = L['This instance'],
            otherInstance = L['Another instance'],
            minutes = periodLabel(cmp),
            all = L['All time'],
            otherRotation = L['Another rotation'],
        }

        controls.compare:SetText(string.format(L['Compare with: %s'], kindLabels[cmp.kind]))
        controls.compare:SetSelected(cmp.kind ~= 'none')

        -- The controls, top to bottom.
        local y = top
        local items = {}

        for _, kind in ipairs(SCOPES) do
            items[#items + 1] = controls.scope[kind]
        end

        items[#items + 1] = reset
        y = grid(items, y, 112)

        syncTime(controls.minutes, controls.units, scope, scope.kind == 'minutes')

        if scope.kind == 'minutes' then
            y = timeRow(controls.minutes, controls.units, y)
        end

        local pair = { controls.compare }

        if chosen then
            controls.compareDetail:SetText(chosen.name or tostring(chosen.key))
            controls.compareDetail:Show()
            pair[2] = controls.compareDetail
        else
            controls.compareDetail:Hide()
        end

        y = grid(pair, y, 240)
        syncTime(controls.compareMinutes, controls.compareUnits, cmp, cmp.kind == 'minutes')

        if cmp.kind == 'minutes' then
            y = timeRow(controls.compareMinutes, controls.compareUnits, y)
        end

        local tabsAt = y
        local tabItems = {}

        for index, tab in ipairs(controls.tabs) do
            local rotation = shownRotations[index]

            if index <= count and count > 1 then
                tab:SetText(rotation.name or rotation.id)
                tab:SetSelected(index == state.tab)
                tab:Show()
                tabItems[#tabItems + 1] = tab
            else
                tab:Hide()
            end
        end

        if #tabItems > 0 then
            y = grid(tabItems, tabsAt, 120)
        end

        canvas:ClearAllPoints()
        canvas:SetPoint('TOPLEFT', 0, -(y + 4))
        canvas:SetWidth(CONTENT)
        local height

        if count == 0 then
            height = drawEmpty(canvas.ctx)
        else
            height = draw(canvas.ctx, shown, baseline(shown, where))
        end

        canvas:SetHeight(height)
        local below = y + 4 + height + 10
        export:ClearAllPoints()
        export:SetPoint('TOPLEFT', 0, -below)
        instructions:ClearAllPoints()
        instructions:SetPoint('LEFT', export, 'RIGHT', 12, 0)

        if count == 0 then
            export:Disable()
        else
            export:Enable()
        end

        p.y = below + 40
        p.child:SetHeight(p.y + 12)

        if p.scroll and p.scroll.UpdateWorkbenchScroll then
            p.scroll:UpdateWorkbenchScroll()
        end
    end

    addon:SetUIScript(export, 'OnClick', p:Guard(function()
        local where = addon.GetMetricsWhere and addon:GetMetricsWhere() or nil
        local scope = state.scope or { kind = 'all' }

        local report = metrics:Report(rotationName, spellName, scopeOf(scope.kind, scope), {
            instance = where and where.instance,
        })

        if #report.rotations == 0 then
            return
        end

        local withInstructions = state.instructions == true

        local data = withInstructions and metrics:ToPrompt(report, clientFacts()) or metrics:ToJSON(
            report,
            clientFacts()
        )

        pcall(
            addon.ShowConditionText,
            addon,
            data,
            withInstructions and L['Metrics for a language model'] or L['Metrics export']
        )
    end))

    controls.render()
end

-- Deletes every recorded number.
function addon:ClearMetrics()
    if addon.Metrics then
        addon.Metrics:Clear()
    end

    self:print(L['Metrics cleared.'])
end
