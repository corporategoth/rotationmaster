-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shows and exports the numbers addon.Metrics (Analytics/metrics.lua) collected. The report is a window of graphs, not
-- text: a gauge for how closely the advice was followed, a bar of where the casts went, a chart of how long it took to
-- act on the advice, output by how closely the advice was followed, the most common deviations and, when it was tracked,
-- how often the forecast was right. The JSON the website reads opens in the selectable text window
-- (addon:ShowConditionText) so Ctrl-A, Ctrl-C copies it; it is data, not interface text, and stays in English. Owns no
-- saved data. Loaded from the UI section of RotationMaster.toc; used by UI/settings_general.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

local WIDTH, HEIGHT, CONTENT = 660, 600, 600

local GREEN, YELLOW, RED, GRAY, BLUE = { .35, .8, .4 }, { .95, .75, .2 }, { .9, .35, .3 }, { .5, .52, .56 }, {
    .35,
    .6,
    .95,
}

local TRACK = { .14, .15, .17 }
local MAX_TABS, MAX_DEVIATIONS = 5, 8

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
-- The window
-- ============================================================================

-- Returns the one report window, creating it on first use.
-- @return table  The dialog { frame, scroll, content, tabs, ... }.
local function getWindow()
    local dialog = addon.metricsWindow

    if dialog then
        return dialog
    end

    dialog = { frame = CreateFrame('Frame', nil, UIParent), tabs = {} }
    addon.metricsWindow = dialog
    local frame = dialog.frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint('CENTER')
    frame:EnableMouse(true)
    local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    title:SetPoint('TOPLEFT', 12, -8)
    dialog.chrome = addon:CreateWorkbenchDialogChrome(frame, title)
    dialog.close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
    dialog.close:SetPoint('TOPRIGHT', -6, -6)

    addon:SetUIScript(dialog.close, 'OnClick', function()
        frame:Hide()
    end)

    local scroll = addon:CreateWorkbenchScrollFrame(frame)
    scroll:SetPoint('TOPLEFT', 16, -62)
    scroll:SetSize(CONTENT, HEIGHT - 100)
    dialog.scroll = scroll
    dialog.content = CreateFrame('Frame', nil, scroll)
    dialog.content:SetSize(CONTENT, 10)
    scroll:SetScrollChild(dialog.content)
    dialog.ctx = { content = dialog.content, textures = {}, texts = {}, usedTextures = 0, usedTexts = 0 }

    -- Window-registry interface: addon:OpenPopup and addon.HideOnEscape call Show and Hide on the dialog table.
    function dialog:Show()
        frame:Show()
    end

    -- Hides the dialog frame.
    function dialog:Hide()
        frame:Hide()
    end

    -- Draws one rotation of the report and lights its tab.
    -- @param index number  The rotation's place in the report.
    function dialog:Select(index)
        local rotation = self.report and self.report.rotations[index]

        if not rotation then
            return
        end

        self.selected = index
        self.content:SetHeight(draw(self.ctx, rotation) + 10)
        self.scroll:SetVerticalScroll(0)
        self.scroll:UpdateScrollChildRect()

        for position, tab in ipairs(self.tabs) do
            tab:SetSelected(position == index)
        end
    end

    addon.HideOnEscape(dialog)
    return dialog
end

-- Shows the graphs of what was recorded, with a tab for each rotation.
-- @return table|nil  The window; nil when nothing is recorded.
function addon:ShowMetricsGraphs()
    local metrics = addon.Metrics

    if not metrics or not metrics:HasData() then
        self:print(L['No metrics have been recorded yet.'])
        return nil
    end

    local dialog = getWindow()
    dialog.report = metrics:Report(rotationName, spellName)
    dialog.chrome:SetContext(L['Rotation metrics'], L['Report'], '')
    local count = math.min(#dialog.report.rotations, MAX_TABS)
    local width = math.floor((CONTENT - (count - 1) * 4) / math.max(1, count))

    for index = 1, count do
        local tab = dialog.tabs[index]

        if not tab then
            tab = addon:CreateWorkbenchButton(dialog.frame, '', width)
            dialog.tabs[index] = tab

            addon:SetUIScript(tab, 'OnClick', function()
                dialog:Select(index)
            end)
        end

        local rotation = dialog.report.rotations[index]
        tab:SetText(rotation.name or rotation.id)
        tab:SetWidth(width)
        tab:ClearAllPoints()
        tab:SetPoint('TOPLEFT', dialog.frame, 'TOPLEFT', 16 + (index - 1) * (width + 4), -34)

        if count > 1 then
            tab:Show()
        else
            tab:Hide()
        end
    end

    for index = count + 1, #dialog.tabs do
        dialog.tabs[index]:Hide()
    end

    dialog:Show()
    self:OpenPopup(dialog)
    dialog:Select(1)
    return dialog
end

-- Opens the website export of the metrics in the selectable window, or the graphs.
-- @param kind string  "report" for the graphs, "json" for the export.
-- @return boolean  True when a window was shown.
function addon:ShowMetricsExport(kind)
    local metrics = addon.Metrics

    if kind ~= 'json' then
        return self:ShowMetricsGraphs() ~= nil
    end

    if not metrics or not metrics:HasData() then
        self:print(L['No metrics have been recorded yet.'])
        return false
    end

    local report = metrics:Report(rotationName, spellName)
    return pcall(self.ShowConditionText, self, metrics:ToJSON(report, clientFacts()), L['Metrics export']) == true
end

-- Deletes every recorded number.
function addon:ClearMetrics()
    if addon.Metrics then
        addon.Metrics:Clear()
    end

    self:print(L['Metrics cleared.'])
end
