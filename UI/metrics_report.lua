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

local GREEN, YELLOW, RED, GRAY, BLUE = { .35, .8, .4 }, { .95, .75, .2 }, { .9, .35, .3 }, { .5, .52, .56 }, {
    .35,
    .6,
    .95,
}

local TRACK = { .14, .15, .17 }
local MAX_TABS, MAX_DEVIATIONS = 5, 8
local TIMED_MIN, TIMED_MAX, TIMED_DEFAULT = 1, 180, 30

-- The periods a report can be limited to, in the order of their buttons.
local SCOPES = { 'last', 'instance', 'minutes', 'all' }

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
-- @return number  The height used.
local function draw(ctx, rotation)
    reset(ctx)
    text(ctx, 0, 0, rotation.name or rotation.id, 'GameFontNormalLarge', CONTENT)

    local counts = string.format(
        L['%d fights, %d seconds, %d casts'],
        rotation.fights,
        rotation.seconds,
        rotation.casts
    )

    text(ctx, 0, 24, counts, nil, CONTENT)
    local y = gauge(ctx, rotation, 50)
    y = castBar(ctx, rotation, y)
    y = reaction(ctx, rotation, y)
    y = output(ctx, rotation, y)
    y = deviationList(ctx, rotation, y)
    return forecastAccuracy(ctx, rotation, y)
end

-- ============================================================================
-- The Metrics page
-- ============================================================================

-- The view the player chose, kept while the window is open: the period, the rotation tab and the export option.
-- @return table  { scope = { kind, minutes }, tab, instructions }.
local function viewState()
    local state = addon.metricsView

    if not state then
        state = { instructions = false, tab = 1 }
        addon.metricsView = state
    end

    return state
end

-- Draws the Metrics page into the settings pane: the recording switches, then the period buttons, the rotation tabs, the
-- graphs and the export. Runs on every redraw of the page; the controls come from the pane's pools.
-- @param p table  The settings pane.
function addon:BuildMetricsSettings(p)
    local profile = p:SettingsData().profile
    local metrics = addon.Metrics
    local state = viewState()
    CONTENT = math.max(420, math.min(760, p.width))
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
    local controls = { scope = {}, tabs = {}, generation = p.generation }
    p.metricsControls = controls

    -- The period: one button for each, and Reset beside them.
    for index, kind in ipairs(SCOPES) do
        local button = p:Acquire('metricsScope', function()
            return addon:CreateWorkbenchButton(p.child, '', 110)
        end)

        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', (index - 1) * 114, -top)
        button:SetWidth(110)
        controls.scope[kind] = button

        addon:SetUIScript(button, 'OnClick', p:Guard(function()
            local minutes = state.scope and state.scope.minutes or TIMED_DEFAULT
            state.scope, state.tab = { kind = kind, minutes = minutes }, 1
            controls.render()
        end))
    end

    -- Reset deletes everything recorded; it asks once more (the button reads Confirm for a few seconds) before it does.
    local reset = p:Acquire('metricsReset', function()
        return addon:CreateWorkbenchButton(p.child, L['Reset'], 80)
    end)

    reset:ClearAllPoints()
    reset:SetPoint('TOPRIGHT', p.child, 'TOPLEFT', CONTENT, -top)
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

    -- The slider that sets the minutes of the timed period.
    local slider = p:Acquire('metricsMinutes', function()
        return addon:CreateWorkbenchSlider(p.child, TIMED_MIN, TIMED_MAX, 1, CONTENT - 20)
    end)

    slider:ClearAllPoints()
    slider:SetPoint('TOPLEFT', 10, -(top + 36))
    slider:SetWidth(CONTENT - 20)
    controls.minutes = slider

    addon:SetUIScript(slider, 'OnValueChanged', function(_, value)
        value = math.floor((value or TIMED_DEFAULT) + .5)

        if
            p:Valid(controls.generation)
            and state.scope
            and state.scope.kind == 'minutes'
            and state.scope.minutes ~= value
        then
            state.scope.minutes = value
            controls.render()
        end
    end)

    -- A tab for each rotation, when there is more than one.
    for index = 1, MAX_TABS do
        local tab = p:Acquire('metricsTab', function()
            return addon:CreateWorkbenchButton(p.child, '', 120)
        end)

        tab:ClearAllPoints()
        tab:SetPoint('TOPLEFT', (index - 1) * 124, -(top + 58))
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
    canvas:ClearAllPoints()
    canvas:SetPoint('TOPLEFT', 0, -(top + 90))
    canvas:SetWidth(CONTENT)
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

    -- Draws everything below the switches for the period chosen, and sets the page's height to fit.
    function controls.render()
        local where = addon.GetMetricsWhere and addon:GetMetricsWhere() or nil

        if not state.scope then
            local last = #metrics:Report(nil, nil, { kind = 'last' }).rotations > 0
            state.scope = { kind = last and 'last' or 'all', minutes = TIMED_DEFAULT }
        end

        local scope = state.scope
        controls.report = metrics:Report(rotationName, spellName, scope, { instance = where and where.instance })

        for kind, button in pairs(controls.scope) do
            local label = kind == 'last' and L['Last fight']
                or kind == 'instance' and L['This instance']
                or kind == 'minutes' and string.format(L['Last %d minutes'], scope.minutes or TIMED_DEFAULT)
                or L['All time']

            button:SetText(label)
            button:SetSelected(scope.kind == kind)
        end

        if scope.kind == 'minutes' then
            slider:SetValue(scope.minutes or TIMED_DEFAULT)
            slider:Show()
        else
            slider:Hide()
        end

        local rotations = controls.report.rotations
        local count = math.min(#rotations, MAX_TABS)
        state.tab = math.max(1, math.min(state.tab or 1, math.max(1, count)))

        for index, tab in ipairs(controls.tabs) do
            local rotation = rotations[index]

            if index <= count and count > 1 then
                tab:SetText(rotation.name or rotation.id)
                tab:SetSelected(index == state.tab)
                tab:Show()
            else
                tab:Hide()
            end
        end

        local height

        if count == 0 then
            height = drawEmpty(canvas.ctx)
        else
            height = draw(canvas.ctx, rotations[state.tab])
        end

        canvas:SetHeight(height)
        local below = top + 90 + height + 10
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
        local report = metrics:Report(rotationName, spellName, state.scope, { instance = where and where.instance })

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
