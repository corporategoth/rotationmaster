-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The native rotation card: the frame, controls and text of one step (action, Branch, Stop, Blizzard suggestion) or
-- cooldown in the rotation editor, plus the live-status stripe and tooltip shared with the switch field. A card only
-- draws what a layout model tells it (`card:Place(model)`; the model comes from the pure layout in
-- Core/rotation_canvas.lua and UI/rotation_canvas.lua places it) and never edits the rotation; callbacks are attached
-- by the canvas and cleared again in `card:Release` because cards are pooled. Spell data is read through
-- `addon.Platform:GetSpellInfo`. Loaded from RotationMaster.toc before UI/rotation_canvas.lua and
-- UI/rotation_editor.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Warnings, icons and live status
-- ============================================================================

local tones = {
    white = { .85, .85, .85 },
    green = { .25, .55, .32 },
    red = { .8, .24, .2 },
    gray = { .4, .4, .4 },
    amber = { 1, .72, .25 },
}

-- The warning a card wears when no action button holds its action (the
-- editor's model.unbound, from addon:GetStepBinding): amber, apart from the
-- red of invalid data. A row on a normal card; an icon when compact or open.
local SUGGESTION_LIST = 5

-- Lists the spells that are off the action bars, as many as read well in a tooltip: the first few by name, then how
-- many more.
-- @param missing number[]  The spell ids that sit on no action bar.
-- @return string  The comma-separated names (or ids when a name is unknown), with "and N more" when the list is cut.
local function suggestionNames(missing)
    local names = {}

    for i, id in ipairs(missing) do
        if i > SUGGESTION_LIST then
            break
        end

        local info = addon.Platform and addon.Platform:GetSpellInfo(id)
        names[i] = info and info.name or tostring(id)
    end

    local text = table.concat(names, ', ')

    if #missing > SUGGESTION_LIST then
        text = string.format(L['%s, and %d more'], text, #missing - SUGGESTION_LIST)
    end

    return text
end

-- Returns the amber row text on Blizzard's suggestion card: how many of the spells Blizzard can suggest sit on no
-- action bar (they are skipped when suggested).
-- @param missing table  The spell ids that sit on no action bar; only its length is used.
-- @return string  The localized sentence.
function addon:DescribeSuggestionGap(missing)
    if #missing == 1 then
        return L["1 of the spells Blizzard can suggest isn't on your action bars, so the card skips it."]
    end

    return string.format(
        L["%d of the spells Blizzard can suggest aren't on your action bars, so the card skips them."],
        #missing
    )
end

-- Returns the tooltip for the card's not-on-your-bars warning: the missing-spell list for Blizzard's suggestion,
-- otherwise the cooldown or step wording.
-- @param model table  The card model; model.unbound must be set (with .missing for Blizzard's suggestion) and
--   model.section tells a cooldown from a step.
-- @return string  The localized tooltip text.
local function unboundTooltip(model)
    local unbound = model.unbound

    if unbound.missing then
        return string.format(L['Not on your action bars: %s.'], suggestionNames(unbound.missing))
            .. '\n\n'
            .. L["Rotation Master highlights an action by lighting the button that holds it, so it can't highlight these. The card still works for every suggestion that is on your bars: it skips one only when it is suggested, and the next step is used instead. Put these on an action bar to use them."]
    end
    if model.section == 'cooldowns' then
        return L["Rotation Master highlights a cooldown by lighting the action button that holds it. No action bar button holds this action right now, so this cooldown is never shown or announced. Put it on an action bar to use it. Spells inside macros count only where the game lets addons read macros (not on Retail)."]
    end

    return L["Rotation Master highlights a step by lighting the action button that holds it. No action bar button holds this action right now, so this step is skipped and the next step is used instead. Put it on an action bar to use it. Spells inside macros count only where the game lets addons read macros (not on Retail)."]
end

-- The icons of the two steps that have no spell of their own.
-- Blizzard's suggestion wears the icon Blizzard gives its one-button
-- assistant: the spell "Single-Button Assistant" (1229376), whose icon is
-- ui_spellbook_onebutton, read from the client so no file name is guessed.
-- A client without that spell (Classic) keeps the condition icon.
-- Stop has its own artwork in the condition family (Assets/Conditions/stop);
-- StepArtwork.stop.shipped says the file is in the addon, and a copy without
-- it keeps the condition icon rather than a blank texture.
addon.AssistedCombatSpell = 1229376

addon.StepArtwork = addon.StepArtwork or {
    stop = { texture = 'Interface\\AddOns\\' .. addon_name .. '\\Assets\\Conditions\\stop', shipped = true },
}

-- Returns the icon of the Single-Button Assistant spell as the client reports it, or nil on a client without that
-- spell, so the caller keeps its fallback icon.
-- @return number|string|nil  The icon id or texture path; nil when the client has no such spell.
function addon:GetAssistedStepIcon()
    local platform = self.Platform

    local info = type(platform) == 'table' and type(platform.GetSpellInfo) == 'function' and platform:GetSpellInfo(
        self.AssistedCombatSpell
    )
        or nil

    local icon = type(info) == 'table' and info.iconID or nil

    if type(icon) == 'number' and icon > 0 or type(icon) == 'string' and icon ~= '' then
        return icon
    end
end

-- Returns the icon a rotation card shows for a step. A Stop step wears its shipped artwork, Blizzard's suggestion the
-- assistant spell's icon; every other step (and any missing artwork) keeps the fallback.
-- @param step table|nil  The rotation step ({ type = 'spell'|'pet'|'any'|'item'|'branch'|'stop'|'assisted', ... }).
-- @param fallback number|string|nil  What the card showed before (the spell's icon, else its condition's).
-- @return number|string|nil  The icon id or texture path to draw; the fallback when the step has no icon of its own.
function addon:GetStepIcon(step, fallback)
    if type(step) ~= 'table' then
        return fallback
    end

    if step.type == 'stop' then
        local art = self.StepArtwork and self.StepArtwork.stop

        if type(art) == 'table' and art.shipped == true and type(art.texture) == 'string' and art.texture ~= '' then
            return art.texture
        end
    elseif step.type == 'assisted' then
        return self:GetAssistedStepIcon() or fallback
    elseif step.type == 'mark' then
        return self:GetMarkStepIcon(step)
    end

    return fallback
end

-- The live bar: a thin stripe down the left edge of a condition field (the
-- card's, or the switch's) showing that condition for the player right now
-- (the editor's model.live, refreshed at the Live Status Update Frequency
-- while the editor is open). Green when it matches, red when it does not,
-- dimmed grey when it cannot be read; none without a condition. It sits
-- inside the field, clear of the card border, and takes no space.
local LIVE_COLORS = {
    satisfied = { .3, .85, .4, 1 },
    unsatisfied = { .9, .27, .22, 1 },
    unavailable = { .55, .55, .55, .55 },
}

-- Returns the stripe color for a live status; an unknown status reads as unavailable.
-- @param status string|nil  'satisfied', 'unsatisfied' or 'unavailable'.
-- @return table  The color { r, g, b, a }.
function addon:LiveStatusColor(status)
    return LIVE_COLORS[status] or LIVE_COLORS.unavailable
end

-- Builds the headline ("Currently Matches"...) and the details that follow the field's own tooltip text.
-- @param state table  The live state ({ status = 'satisfied'|'unsatisfied'|..., reason, chosen, at }); it must be a
--   table.
-- @return string  The localized headline.
-- @return string[]  The detail lines (what was chosen, how many seconds ago it was checked); may be empty.
function addon:DescribeLiveStatus(state)
    local headline

    if state.status == 'satisfied' then
        headline = L['Currently Matches']
    elseif state.status == 'unsatisfied' then
        headline = L['Does Not Currently Match']
    else
        headline = string.format(L['Unavailable: %s'], tostring(state.reason or L['unreadable right now']))
    end

    local details = {}

    if state.chosen then
        details[#details + 1] = state.chosen
    end
    if type(state.at) == 'number' and type(GetTime) == 'function' then
        details[#details + 1] = string.format(L['Checked %d seconds ago.'], math.max(0, math.floor(
            GetTime() - state.at + .5
        )))
    end

    return headline, details
end

-- Shows a condition field's tooltip: the live headline on its own line, coloured like the bar, then the field's text,
-- then when it was checked. Without a live state only the text is shown. Does nothing when GameTooltip is missing.
-- @param owner table  The frame the tooltip anchors to.
-- @param text string|nil  The field's own tooltip text.
-- @param state table|nil  The live state (see DescribeLiveStatus); nil for a plain tooltip.
function addon:ShowConditionFieldTooltip(owner, text, state)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')

    if type(state) ~= 'table' then
        GameTooltip:SetText(text or '', 1, 1, 1, 1, true)
        return
    end

    local headline, details = self:DescribeLiveStatus(state)
    local color = self:LiveStatusColor(state.status)
    GameTooltip:SetText(headline, color[1], color[2], color[3], 1, true)

    if text then
        GameTooltip:AddLine(text, 1, 1, 1, true)
    end

    for _, line in ipairs(details) do
        GameTooltip:AddLine(line, .85, .85, .85, true)
    end

    GameTooltip:Show()
end

-- Creates the 3 pixel live stripe inside the left edge of `field`; `bar:SetState(state)` colors it or hides it when
-- there is no state. The stripe takes no layout space.
-- @param field table  The condition field frame the stripe sits in.
-- @return table  The stripe texture, initially hidden.
function addon:CreateLiveStatusBar(field)
    local bar = field:CreateTexture(nil, 'OVERLAY')
    bar:SetPoint('TOPLEFT', field, 'TOPLEFT', 0, 0)
    bar:SetPoint('BOTTOMLEFT', field, 'BOTTOMLEFT', 0, 0)
    bar:SetWidth(3)

    -- Colors and shows the stripe for a live state, or hides it when the state is nil.
    -- @param state table|nil  The live state ({ status = ... }); anything but a table hides the stripe.
    function bar:SetState(state)
        self.state = state

        if type(state) ~= 'table' then
            self:Hide()
            return
        end

        local color = addon:LiveStatusColor(state.status)
        self:SetColorTexture(color[1], color[2], color[3], color[4])
        self:Show()
    end

    bar:Hide()
    return bar
end

-- ============================================================================
-- The card
-- ============================================================================

-- Builds one pooled rotation card frame on `parent` with all of its controls and returns the card object. Nothing is
-- placed or filled here: `card:Place(model)` does that for each use and `card:Release()` undoes it.
-- @param parent table  The frame the card is created on (also the anchor for Place).
-- @return table  The card object ({ frame, controls, Place, SetSelected, PlaceUnbound, SetLive, SetValidation, Release
--   }).
function addon:CreateRotationCard(parent)
    local card = { frame = CreateFrame('Frame', nil, parent), controls = {} }
    local frame = card.frame
    frame:EnableMouse(true)
    card.decoration = self:CreateRoundedCardDecoration(frame)
    card.expand = self:CreateConditionChevron(frame)
    card.expand:SetPoint('TOPLEFT', 4, -4)
    card.expand.tooltip = L['Expand or collapse the card. Click action or condition text for details.']
    card.title = self:CreateWorkbenchButton(frame, '', 268)
    card.title:SetPoint('TOPLEFT', 26, -3)
    card.title.art:SetAlpha(.1)
    card.title:RegisterForDrag('LeftButton')
    card.name = self:CreateWorkbenchEditBox(frame)
    card.name:SetSize(248, 24)
    card.name:SetTextInsets(3, 3, 0, 0)
    card.name:SetPoint('TOPLEFT', 32, -5)
    card.name:SetMaxLetters(120)
    card.name:Hide()
    card.preview = CreateFrame('Frame', nil, frame)
    card.preview:SetSize(18, 18)
    card.preview:SetPoint('TOPLEFT', 26, -27)
    card.icon = card.preview:CreateTexture(nil, 'ARTWORK')
    card.icon:SetAllPoints(card.preview)
    card.action = self:CreateWorkbenchButton(frame, '', 256)
    card.action:SetPoint('TOPLEFT', 48, -25)
    card.action.art:SetAlpha(.08)
    card.condition = self:CreateWorkbenchButton(frame, '', 280)
    card.condition.tooltip = L['Click condition text on any card to view or edit its conditions.']
    card.condition:SetPoint('TOPLEFT', 26, -46)
    card.condition:SetHeight(24)
    local caption = card.condition:GetFontString()
    caption:ClearAllPoints()
    caption:SetPoint('LEFT', 3, 0)
    caption:SetWidth(274)
    caption:SetJustifyH('LEFT')
    caption:SetWordWrap(true)

    for _, entry in ipairs({
        { 'up', 'up', L['Move Up'] },
        { 'down', 'down', L['Move Down'] },
        { 'duplicate', 'copy', L['Duplicate'] },
        { 'remove', 'trash', L['Delete'] },
    }) do
        card.controls[entry[1]] = self:CreateWorkbenchIconButton(frame, entry[2], entry[3])
    end

    card.controls.up:SetSize(18, 18)
    card.controls.down:SetSize(18, 18)
    card.controls.up:SetPoint('TOPLEFT', 4, -28)
    card.controls.down:SetPoint('TOPLEFT', 4, -46)
    card.controls.duplicate:SetPoint('TOPRIGHT', -5, -24)
    card.controls.remove.icon:SetVertexColor(1, .3, .3, 1)
    card.controls.enable = self:CreateWorkbenchPill(frame, '', 64)
    card.armToggle = self:CreateWorkbenchIconButton(frame, 'branch', L['Show or hide branch paths'])
    card.armToggle:SetPoint('TOPLEFT', 28, -4)
    card.armToggle:SetSize(18, 18)
    card.controls.help = self:CreateWorkbenchHelpButton(frame, L['Help'])
    card.controls.help:SetSize(20, 20)
    card.controls.help.icon:SetSize(18, 18)
    card.controls.help:SetPoint('TOPRIGHT', -5, -3)
    card.fields = CreateFrame('Frame', nil, frame)
    card.unbound = self:CreateWorkbenchLabeledIconButton(frame, 'warning', '', 284)
    card.unbound.art:SetAlpha(.08)
    card.unbound.icon:SetVertexColor(tones.amber[1], tones.amber[2], tones.amber[3], 1)

    do
        local caption = card.unbound:GetFontString()
        caption:SetTextColor(tones.amber[1], tones.amber[2], tones.amber[3])
        caption:SetWordWrap(true)
    end

    card.unbound:Hide()
    card.liveBar = self:CreateLiveStatusBar(card.condition)

    -- Positions and fills the card from a layout model: title, action and condition text, icon, pills, which controls
    -- show in the normal, compact or expanded layout, and the glow preview on cooldown cards. Safe to call again on a
    -- pooled card; it recomputes everything from the model.
    -- @param model table  The layout model (x, y, width, height, step, compact, expanded, unbound, live, ...).
    -- @param readOnly boolean|nil  True disables every control but Help.
    function card:Place(model, readOnly)
        self.model = model
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', parent, 'TOPLEFT', model.x, -model.y)
        frame:SetSize(model.width, model.height)
        self:SetValidation(model.invalid)
        local step = model.step
        local branch = step.type == 'branch'
        local normal = not model.compact and not model.expanded

        local action = branch and L['Click to add branch name']
            or step.type == 'stop' and L['Stop']
            or step.type == 'assisted' and L["Blizzard's suggestion"]
            or step.type == 'mark' and addon:DescribeMarkStep(step)
            or (step.type == 'spell' or step.type == 'pet' or step.type == 'any') and addon:SpellLabel(step.action)
            or L['Item']

        self.defaultTitle = branch and model.compact and addon:DescribeCardCondition(step.conditions or {}, self.spec)
            or action

        if not branch then
            local info = addon.Platform and addon.Platform:GetSpellInfo(step.action)

            if info and (step.type == 'spell' or step.type == 'pet' or step.type == 'any') then
                self.defaultTitle = info.name
            end
        end

        if not branch then
            self.defaultTitle = addon:PlainWorkbenchName(self.defaultTitle):gsub('^%[(.*)%]$', '%1')
        end

        local suppliedName = model.displayName

        if suppliedName == nil then
            suppliedName = step.name
        end

        self.title:SetText(addon:PlainWorkbenchName(
            suppliedName and suppliedName ~= '' and suppliedName or self.defaultTitle
        ))

        local pillWidth = branch and 118 or 64
        self.title:ClearAllPoints()
        self.title:SetPoint('TOPLEFT', branch and 50 or 26, -3)
        self.title:SetWidth((model.compact and model.width - 52 or model.width - pillWidth - 56) - (branch and 24 or 0))
        addon:AlignWorkbenchTextLeft(self.title, 3)

        if branch then
            self.armToggle:Show()
            self.armToggle:SetSelected(model.collapsed)
        else
            self.armToggle:Hide()
        end

        self.name:ClearAllPoints()
        self.name:SetPoint('TOPLEFT', self.title, 'TOPLEFT', 0, 0)
        self.name:SetSize(self.title:GetWidth(), self.title:GetHeight())
        self.action:SetText(action)
        self.action:SetWidth(math.max(256, model.width - 84))
        addon:AlignWorkbenchTextLeft(self.action, 3)
        -- The not-on-your-bars row sits under the action and pushes the
        -- conditions down by the height the layout added for it.
        local unboundRow = model.unbound ~= nil and not branch and normal and step.type ~= 'stop'
        local shift = unboundRow and (addon.RotationCardNoticeHeight or 30) or 0
        self.condition:ClearAllPoints()
        self.condition:SetPoint('TOPLEFT', 26, branch and -28 or -46 - shift)

        self.condition:SetText(addon:PlainWorkbenchName(
            model.pendingProblem and string.format(L['Incomplete input: %s'], model.pendingProblem)
                or addon:DescribeCardCondition(step.conditions or {}, self.spec)
        ))

        local ownHeader = model.headerHeight or 84

        self.condition:SetHeight(math.max(
            24,
            ownHeader - shift - (branch and 32 or model.section == 'cooldowns' and 54 or 50)
        ))

        self.condition:GetFontString():SetTextColor(
            model.invalid and 1 or .7,
            model.invalid and .35 or .75,
            model.invalid and .3 or .7
        )

        local spell = addon.Platform and addon.Platform:GetSpellInfo(step.action)

        self.icon:SetTexture(addon:GetStepIcon(
            step,
            spell and spell.iconID or addon:GetConditionIcon(step.conditions and step.conditions.type)
        ))

        self.icon:SetAlpha(model.inactive and .4 or 1)
        self.expand:PointState(model.compact and 'compact' or model.expanded and 'expanded' or 'normal')
        self.controls.enable:SetWidth(pillWidth)
        self.controls.enable:ClearAllPoints()
        self.controls.enable:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -28, -4)
        self.controls.remove:ClearAllPoints()
        self.controls.remove:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -4, -44)

        self.controls.enable:SetText(
            branch
                and ((step.mode or 'evaluate') == 'evaluate' and L['Evaluate condition']
                    or step.mode == 'true' and L['Always true']
                    or L['Always false'])
                or step.disabled and L['Disabled']
                or L['Enabled']
        )

        self.controls.enable:SetSelected(branch and step.mode == 'true' or not branch and not step.disabled)
        self.fields:ClearAllPoints()
        self.fields:SetPoint('TOPLEFT', 28, -28)

        self.fields:SetSize(model.width - 56, math.max(
            1,
            model.height - 28 - ((model.conditionHeight or 0) > 0 and model.conditionHeight + 4 or 0)
        ))

        if model.expanded then
            self.fields:Show()
        else
            self.fields:Hide()
        end

        for _, control in pairs(self.controls) do
            if model.compact then
                control:Hide()
            else
                control:Show()
            end
        end

        if not model.compact and (normal or (model.conditionHeight or 0) > 0) then
            self.condition:Show()
        else
            self.condition:Hide()
        end

        if normal and not branch then
            self.action:Show()
            self.preview:Show()
        else
            self.action:Hide()
            self.preview:Hide()
        end

        if model.section == 'cooldowns' then
            self.controls.up:Hide()
            self.controls.down:Hide()
        end

        if model.section == 'cooldowns' and normal then
            self.preview:SetSize(36, 36)
            self.preview:SetPoint('TOPLEFT', 26, -28)
            self.action:SetPoint('TOPLEFT', 68, -26)
            self.action:SetWidth(model.width - 96)
            self.condition:SetPoint('TOPLEFT', 68, -50 - shift)
            self.condition:SetWidth(model.width - 96)
            self.condition:GetFontString():SetWidth(model.width - 102)
            local profile = addon.db.profile
            local effect = (addon.db.global.effects or {})[step.effect or profile.effect]

            if effect and addon.Glow then
                addon:Glow(
                    self.preview,
                    'rotation-card-preview',
                    effect,
                    addon:ResolveHighlightColor(step.color),
                    step.magnification or profile.magnification or 1,
                    step.setpoint or profile.setpoint or 'CENTER',
                    step.xoffs or profile.xoffs or 0,
                    step.yoffs or profile.yoffs or 0,
                    step.angle
                )
            end
        else
            self.preview:SetSize(18, 18)
            self.preview:SetPoint('TOPLEFT', 26, -27)
            self.action:SetPoint('TOPLEFT', 48, -25)
            self.condition:SetWidth(math.max(280, model.width - 60))
            self.condition:GetFontString():SetWidth(math.max(274, model.width - 66))
        end

        if (model.conditionHeight or 0) > 0 then
            self.condition:ClearAllPoints()
            self.condition:SetPoint('TOPLEFT', 26, -model.height + model.conditionHeight + 4)
            self.condition:SetSize(model.width - 56, model.conditionHeight)
            self.condition:GetFontString():SetWidth(model.width - 62)
        end

        self:PlaceUnbound(model, unboundRow, pillWidth, branch)
        self.liveBar:SetState(model.live)

        if self.name:HasFocus() then
            self.name:Show()
            self.title:Hide()
        else
            self.name:Hide()
            self.title:Show()
        end

        for key, control in pairs(self.controls) do
            if
                (readOnly and key ~= 'help')
                or (key == 'up' and not model.canMoveUp)
                or (key == 'down' and not model.canMoveDown)
            then
                control:Disable()
            else
                control:Enable()
            end
        end

        frame:SetAlpha(model.inactive and .6 or 1)
        frame:Show()
    end

    -- Draws or removes the gold outline a selected card wears over its border (the edge textures are created on first
    -- use).
    -- @param selected boolean|nil  True selects the card; anything else clears it.
    function card:SetSelected(selected)
        if selected and not self.selection then
            self.selection = {}

            for _, side in ipairs({
                { 'TOPLEFT', 'TOPRIGHT', 'h' },
                { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'h' },
                { 'TOPLEFT', 'BOTTOMLEFT', 'v' },
                { 'TOPRIGHT', 'BOTTOMRIGHT', 'v' },
            }) do
                local edge = frame:CreateTexture(nil, 'OVERLAY')
                edge:SetColorTexture(1, .82, .2, .95)
                edge:SetPoint(side[1])
                edge:SetPoint(side[2])

                if side[3] == 'h' then
                    edge:SetHeight(2)
                else
                    edge:SetWidth(2)
                end

                self.selection[#self.selection + 1] = edge
            end
        end

        self.selected = selected == true

        for _, edge in ipairs(self.selection or {}) do
            if self.selected then
                edge:Show()
            else
                edge:Hide()
            end
        end
    end

    -- Shows the not-on-your-bars warning for the card, or hides it. A normal card gets a text row under the action; a
    -- compact or open card gets an icon beside the title (and the title is narrowed to make room), with the text in the
    -- tooltip.
    -- @param model table  The layout model; unbound, step, section, width and compact are read.
    -- @param row boolean  True for a normal card (text row), false for an icon beside the title.
    -- @param pillWidth number  The width of the enable pill, which the icon is placed clear of.
    -- @param branch boolean  True for a Branch card, which never shows the warning.
    function card:PlaceUnbound(model, row, pillWidth, branch)
        local warning = self.unbound

        if model.unbound == nil or branch or model.step.type == 'stop' then
            warning:Hide()
            return
        end

        warning.tooltip = unboundTooltip(model)
        warning:ClearAllPoints()

        if row then
            local left = model.section == 'cooldowns' and 68 or 26
            warning:SetPoint('TOPLEFT', left, -46)
            warning:SetSize(model.width - left - 30, (addon.RotationCardNoticeHeight or 30) - 2)
            warning.art:Show()

            warning:SetText(
                model.unbound.missing and addon:DescribeSuggestionGap(model.unbound.missing)
                    or L["Not on your action bars, so it can't be highlighted. It is skipped."]
            )
        else
            -- Compact or open: an icon beside the title, the text in its tooltip.
            warning:SetText('')
            warning.art:Hide()
            warning:SetSize(20, 20)
            warning:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', model.compact and -6 or -(pillWidth + 32), -3)
            self.title:SetWidth(math.max(40, self.title:GetWidth() - 22))
        end

        warning:Show()
    end

    -- Stores a new live state and repaints the stripe, without a full re-place of the card.
    -- @param state table|nil  The live state; nil hides the stripe.
    function card:SetLive(state)
        if self.model then
            self.model.live = state
        end

        self.liveBar:SetState(state)
    end

    -- Colors the card border: red for invalid data, amber when no action button holds its action, else the model's own
    -- border tone.
    -- @param invalid boolean|nil  True when the step has invalid data.
    function card:SetValidation(invalid)
        self.model.invalid = invalid

        local tone = invalid and tones.red
            or self.model.unbound and not self.model.inactive and tones.amber
            or tones[self.model.border]
            or tones.green

        self.decoration:SetColors(tone[1], tone[2], tone[3], .75, .06)
    end

    -- Returns the card to the pool: hides it, drops focus, selection and the glow preview, and clears every script the
    -- canvas installed so a reused card cannot call back into the previous owner.
    function card:Release()
        self.token = nil
        self.frame:Hide()
        self.name:ClearFocus()
        self:SetSelected(false)

        if addon.HideGlow then
            addon:HideGlow(self.preview, 'rotation-card-preview')
        end
        if self.fieldSpellIcon then
            self.fieldSpellIcon:Hide()
        end

        if self.releaseFields then
            self.releaseFields()
            self.releaseFields = nil
        end

        for _, control in pairs(self.controls) do
            addon:SetUIScript(control, 'OnClick', nil)
        end

        for _, control in ipairs({
            self.title,
            self.action,
            self.condition,
            self.expand,
            self.armToggle,
            self.frame,
        }) do
            for _, event in ipairs({
                'OnClick',
                'OnMouseDown',
                'OnMouseUp',
                'OnMouseWheel',
                'OnDragStart',
                'OnDragStop',
                'OnEnter',
                'OnLeave',
            }) do
                if control:HasScript(event) then
                    addon:SetUIScript(control, event, nil)
                end
            end
        end

        for _, event in ipairs({ 'OnEditFocusGained', 'OnEditFocusLost', 'OnUpdate' }) do
            addon:SetUIScript(self.name, event, nil)
        end

        addon:SetUIScript(self.name, 'OnTextChanged', nil)
        addon:SetUIScript(self.name, 'OnEnterPressed', nil)
        addon:SetUIScript(self.name, 'OnEscapePressed', nil)
    end

    return card
end
