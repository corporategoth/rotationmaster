-- The native widget set every RM window is built from: flat buttons, icon buttons, pills, check boxes, edit boxes,
-- sliders, scroll frames and bars, the drag card and drop-zone helpers, the deferred reflow scheduler, the shared
-- layout constants (addon.WorkbenchLayout) and the splitter, position pad and edit-suggestion helpers. Pure
-- construction and geometry: it owns no saved data and no window, and depends on no other addon's frames. Everything
-- hangs off `addon` as addon:CreateWorkbench...; the first UI file in RotationMaster.toc, so every later UI file may
-- use it. Frames RM sizes answer GetWidth/GetHeight from the size RM last assigned (TrackWorkbenchSize), because the
-- client reports a stale rect until its next layout pass.

local addon_name, addon = ...

-- ============================================================================
-- Size tracking
-- ============================================================================

-- Native controls with the compact flat-button conventions used by modern
-- addon workbenches. No dependency on another installed addon's frames.
---@class RMWorkbenchButton: Button
---@field art Texture
---@field SetSelected fun(self: RMWorkbenchButton, value: boolean)
---@return RMWorkbenchButton
-- Makes a frame answer GetWidth/GetHeight from the size RM last assigned (or the client last reported) instead of the
-- stale rect.
-- @param frame Frame|nil  The frame to track; nil or an already tracked frame is returned unchanged.
-- @return Frame|nil  The same frame.
--
-- The client resolves a region's rect on its next layout pass: right after SetWidth/SetSize, or for a frame sized by
-- its anchors, GetWidth/GetHeight still return the previous size, and OnSizeChanged arrives a frame later. Layout code
-- reads sizes it has just assigned, so RM frames answer with the size RM last assigned (or the client last reported). A
-- size the client reports (window sizing, anchors) is noted before the frame's own OnSizeChanged handler runs, so that
-- handler reads it too. These are native controls with the compact flat-button conventions used by modern addon
-- workbenches, with no dependency on another installed addon's frames.
function addon:TrackWorkbenchSize(frame)
    if not frame or frame.rmTracksSize then
        return frame
    end

    frame.rmTracksSize = true

    local setWidth, setHeight, setSize, getWidth, getHeight =
        frame.SetWidth, frame.SetHeight, frame.SetSize, frame.GetWidth, frame.GetHeight

    -- Records a numeric width before passing the call on, so GetWidth can answer before the client lays the frame out.
    -- @param value number  The width.
    -- @param ... any  Further arguments of SetWidth.
    -- @return any  What the original SetWidth returns.
    function frame:SetWidth(value, ...)
        if type(value) == 'number' then
            self.rmWidth = value
        end

        return setWidth(self, value, ...)
    end

    -- Records a numeric height before passing the call on.
    -- @param value number  The height.
    -- @param ... any  Further arguments of SetHeight.
    -- @return any  What the original SetHeight returns.
    function frame:SetHeight(value, ...)
        if type(value) == 'number' then
            self.rmHeight = value
        end

        return setHeight(self, value, ...)
    end

    if setSize then
        -- Records numeric width and height before passing the call on.
        -- @param width number  The width.
        -- @param height number  The height.
        -- @param ... any  Further arguments of SetSize.
        -- @return any  What the original SetSize returns.
        function frame:SetSize(width, height, ...)
            if type(width) == 'number' then
                self.rmWidth = width
            end
            if type(height) == 'number' then
                self.rmHeight = height
            end

            return setSize(self, width, height, ...)
        end
    end

    -- Answers the width RM last assigned (or the client last reported), else the client's own value.
    -- @param ... any  Arguments of GetWidth, passed on when the client is asked.
    -- @return number|nil  The width.
    function frame:GetWidth(...)
        local value = self.rmWidth

        if value then
            return value
        end

        return getWidth(self, ...)
    end

    -- Answers the height RM last assigned (or the client last reported), else the client's own value.
    -- @param ... any  Arguments of GetHeight, passed on when the client is asked.
    -- @return number|nil  The height.
    function frame:GetHeight(...)
        local value = self.rmHeight

        if value then
            return value
        end

        return getHeight(self, ...)
    end

    if frame.SetScript and frame.HookScript and frame.HasScript and frame:HasScript('OnSizeChanged') then
        local setScript = frame.SetScript

        -- Wraps OnSizeChanged handlers so the reported size is noted before the handler reads it.
        -- @param event string  The script name.
        -- @param handler function|nil  The handler.
        -- @param ... any  Further arguments of SetScript.
        -- @return any  What the original SetScript returns.
        function frame:SetScript(event, handler, ...)
            if event == 'OnSizeChanged' and handler then
                local inner = handler

                handler = function(region, width, height, ...)
                    addon:NoteWorkbenchSize(region, width, height)
                    return inner(region, width, height, ...)
                end
            end

            return setScript(self, event, handler, ...)
        end

        local current = frame:GetScript('OnSizeChanged')

        if current then
            frame:SetScript('OnSizeChanged', current)
        end

        frame:HookScript('OnSizeChanged', function(region, width, height)
            addon:NoteWorkbenchSize(region, width, height)
        end)
    end

    return frame
end

-- Wraps `value` with TrackWorkbenchSize when it looks like a sized region and returns it; other values pass through.
-- @param value any  A region or a plain value from a pooled builder.
-- @return any  The tracked region, or the value unchanged.
--
-- Pooled builders may return any region or a plain table; only regions with their own geometry are tracked.
function addon:TrackWorkbenchRegion(value)
    if
        type(value) == 'table'
        and type(value.SetWidth) == 'function'
        and type(value.GetWidth) == 'function'
        and type(value.SetPoint) == 'function'
    then
        return self:TrackWorkbenchSize(value)
    end

    return value
end

-- Records a size the client reported (positive numbers only) on a tracked frame; ignored for untracked frames.
-- @param frame Frame  The frame the size was reported for.
-- @param width number  The reported width.
-- @param height number  The reported height.
function addon:NoteWorkbenchSize(frame, width, height)
    if not frame.rmTracksSize then
        return
    end

    if type(width) == 'number' and width > 0 then
        frame.rmWidth = width
    end
    if type(height) == 'number' and height > 0 then
        frame.rmHeight = height
    end
end

-- ============================================================================
-- Buttons and toggles
-- ============================================================================

-- Creates the flat button every other control builds on: a 20 px tall hit area, centered caption, dim background art, a
-- hover tooltip from `button.tooltip` and a dimmed look while disabled.
-- @param parent Frame  The parent frame.
-- @param label string|nil  The caption text.
-- @param width number|nil  The button width; defaults to 28.
-- @return RMWorkbenchButton  The new button.
function addon:CreateWorkbenchButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent)
    self:TrackWorkbenchSize(button)
    button:SetSize(width or 28, 20)
    button:EnableMouse(true)
    local caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("CENTER")
    button:SetFontString(caption)
    button:SetText(label or "")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    button.art = background

    -- Paints the resting background, lighter while the button is selected.
    local function rest()
        if button.selected then
            background:SetColorTexture(.24, .24, .24, .8)
        else
            background:SetColorTexture(.16, .16, .16, .5)
        end
    end

    -- Marks the button selected (lighter background) or not.
    -- @param value boolean|nil  True to select.
    function button:SetSelected(value)
        self.selected = value == true
        rest()
    end

    addon:SetUIScript(button, "OnEnter", function()
        background:SetColorTexture(.27, .27, .27, .8)

        if button.tooltip and GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(button.tooltip, 1, 1, 1, 1, true)
        end
    end)

    addon:SetUIScript(button, "OnLeave", function()
        rest()

        if GameTooltip and GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    addon:SetUIScript(button, "OnEnable", function()
        button:SetAlpha(1)
    end)

    addon:SetUIScript(button, "OnDisable", function()
        button:SetAlpha(.35)
    end)

    rest()
    ---@cast button RMWorkbenchButton
    return button
end

-- Returns the path of the control texture `name` in Assets/Controls (generated by tools/generate_control_icons.py).
-- @param name string  The texture name without extension.
-- @return string  The texture path.
function addon:ControlTexture(name)
    return "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Controls\\" .. name .. ".tga"
end

-- Creates a 20 px button showing control icon `name` (the trash icon is tinted red) with `tooltip` on hover.
-- @param parent Frame  The parent frame.
-- @param name string  The control icon name.
-- @param tooltip string|nil  The hover text.
-- @return RMIconButton  The new button.
---@class RMIconButton: RMWorkbenchButton
---@field icon Texture
---@return RMIconButton
function addon:CreateWorkbenchIconButton(parent, name, tooltip)
    local button = self:CreateWorkbenchButton(parent, "", 20)
    button:SetSize(20, 20)
    button.tooltip = tooltip
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(16, 16)
    button.icon:SetTexture(self:ControlTexture(name))

    if name == 'trash' then
        button.icon:SetVertexColor(1, .25, .25, 1)
    end

    button.art:Hide()
    ---@cast button RMIconButton
    return button
end

-- Creates the gold round "?" button used for help.
-- @param parent Frame  The parent frame.
-- @param tooltip string|nil  The hover text.
-- @return RMIconButton  The new button.
---@return RMIconButton
function addon:CreateWorkbenchHelpButton(parent, tooltip)
    local button = self:CreateWorkbenchIconButton(parent, 'help', tooltip)
    button:SetSize(20, 20)
    button.icon:SetSize(18, 18)
    button.icon:SetVertexColor(1, .82, .25, 1)
    return button
end

-- Creates an icon-plus-caption button (Undo/Redo style); `direction` names the icon.
-- @param parent Frame  The parent frame.
-- @param direction string  The control icon name ("undo" or "redo").
-- @param label string  The caption and the tooltip.
-- @return RMIconButton  The new button, 68 px wide; the caption is bounded by the button so a long label cannot spill
--   out.
function addon:CreateWorkbenchHistoryButton(parent, direction, label)
    local button = self:CreateWorkbenchIconButton(parent, direction, label)
    button:SetSize(68, 20)
    button:SetText(label)
    button.art:Show()
    button.icon:ClearAllPoints()
    button.icon:SetPoint('LEFT', 3, 0)
    -- The caption is bounded by the button so a long label cannot spill out.
    local caption = button:GetFontString()
    caption:ClearAllPoints()
    caption:SetPoint('LEFT', 24, 0)
    caption:SetPoint('RIGHT', -4, 0)
    caption:SetJustifyH('LEFT')
    caption:SetWordWrap(false)
    return button
end

-- Creates an icon-plus-caption button of the given width (default 100).
-- @param parent Frame  The parent frame.
-- @param icon string  The control icon name.
-- @param label string  The caption.
-- @param width number|nil  The width; defaults to 100.
-- @return RMIconButton  The new button.
function addon:CreateWorkbenchLabeledIconButton(parent, icon, label, width)
    local button = self:CreateWorkbenchHistoryButton(parent, icon, label)
    button:SetWidth(width or 100)
    return button
end

-- Shows a selector's current choice on `button`: the caption (or the entry text) and, when the entry has one, its icon.
-- @param button Button  The selector button to paint.
-- @param entry table|nil  The chosen entry ({ text, icon }).
-- @param caption string|nil  Text to show instead of the entry's text.
function addon:PaintSelectorSelection(button, entry, caption)
    button:SetText(caption or entry and entry.text or '')

    if entry and entry.icon then
        button.valueIcon = button.valueIcon or button:CreateTexture(nil, 'ARTWORK')
        button.valueIcon:ClearAllPoints()
        button.valueIcon:SetPoint('LEFT', 25, 0)
        button.valueIcon:SetSize(18, 18)
        button.valueIcon:SetTexture(entry.icon)
        button.valueIcon:Show()
        self:AlignWorkbenchTextLeft(button, 48)
    else
        if button.valueIcon then
            button.valueIcon:Hide()
        end

        self:AlignWorkbenchTextLeft(button, 26)
    end
end

-- Refits an aligned caption to its button's current width. An aligned caption keeps following its button when the
-- button is resized later, rather than keeping the width it had when aligned. A caller that narrows the caption itself
-- afterwards keeps that width until realigned.
-- @param button Button  A button previously aligned by AlignWorkbenchTextLeft.
local function refitAlignedText(button)
    local label = button:GetFontString()
    local inset = button.rmAlignInset

    if not label or not inset then
        return
    end

    addon:TrackWorkbenchSize(label)

    if math.abs((label:GetWidth() or 0) - (button.rmAlignWidth or -1)) > .5 then
        button.rmAlignInset = nil
        return
    end

    local width = math.max(1, button:GetWidth() - inset - 4)
    label:SetWidth(width)
    button.rmAlignWidth = width
end

-- Left-aligns a button's caption `inset` pixels in and sizes it to the button; later resizes of the button refit it.
-- @param button Button  The button whose caption is aligned.
-- @param inset number|nil  The left inset in pixels; defaults to 4.
function addon:AlignWorkbenchTextLeft(button, inset)
    local label = button:GetFontString()
    self:TrackWorkbenchSize(label)
    label:ClearAllPoints()
    label:SetPoint('LEFT', inset or 4, 0)
    label:SetJustifyH('LEFT')
    local width = math.max(1, button:GetWidth() - (inset or 4) - 4)
    label:SetWidth(width)
    button.rmAlignInset = inset or 4
    button.rmAlignWidth = width

    if not button.rmAlignFollows then
        button.rmAlignFollows = true
        local setWidth, setSize = button.SetWidth, button.SetSize

        -- Resizing the button refits its aligned caption to the new width.
        -- @param ... any  The arguments of SetWidth.
        function button:SetWidth(...)
            setWidth(self, ...)
            refitAlignedText(self)
        end

        -- Resizing the button refits its aligned caption to the new size.
        -- @param ... any  The arguments of SetSize.
        function button:SetSize(...)
            setSize(self, ...)
            refitAlignedText(self)
        end
    end
end

-- Creates a small rounded toggle (Enabled, If/Unless, All/Any); SetSelected lights it and SetAccent sets its color.
-- @param parent Frame  The parent frame.
-- @param label string  The caption.
-- @param width number|nil  The width; defaults to 56.
-- @return RMWorkbenchPill  The new pill.
---@class RMWorkbenchPill: RMWorkbenchButton
---@field SetAccent fun(self: RMWorkbenchPill, r: number, g: number, b: number, alpha?: number)
---@return RMWorkbenchPill
function addon:CreateWorkbenchPill(parent, label, width)
    local button = self:CreateWorkbenchButton(parent, label, width)
    button:SetSize(width or 56, 18)
    button.art:Hide()
    button.pillDecoration = self:CreateRoundedCardDecoration(button)
    local accent = { .35, .65, .4 }
    local accentAlpha = .7

    -- Repaints the pill border and fill for the selected and hover states.
    -- @param hover boolean  True while the pointer is over the pill.
    local function paint(hover)
        local color = button.selected and accent or { .48, .48, .48 }

        button.pillDecoration:SetColors(
            color[1],
            color[2],
            color[3],
            hover and 1 or button.selected and accentAlpha or .7,
            button.selected and .6 or .25
        )
    end

    -- Marks the pill selected (accent border and fill) or not.
    -- @param value boolean|nil  True to select.
    function button:SetSelected(value)
        self.selected = value == true
        paint(false)
    end

    -- Sets the border color and opacity used while the pill is selected.
    -- @param r number  The red channel, 0 to 1.
    -- @param g number  The green channel, 0 to 1.
    -- @param b number  The blue channel, 0 to 1.
    -- @param a number|nil  The opacity; defaults to .7.
    function button:SetAccent(r, g, b, a)
        accent = { r, g, b }
        accentAlpha = a or .7
        paint(false)
    end

    addon:SetUIScript(button, 'OnEnter', function()
        paint(true)

        if button.tooltip and GameTooltip then
            GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
            GameTooltip:SetText(button.tooltip, 1, 1, 1, 1, true)
        end
    end)

    addon:SetUIScript(button, 'OnLeave', function()
        paint(false)

        if GameTooltip and GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    paint(false)
    ---@cast button RMWorkbenchPill
    return button
end

-- Creates a check box button: a 16 px box with a gold check, SetChecked/GetChecked, and the label to its right.
-- @param parent Frame  The parent frame.
-- @param label string  The caption.
-- @param width number|nil  The width; defaults to 150.
-- @return RMWorkbenchCheckBox  The new check box.
---@class RMWorkbenchCheckBox: RMWorkbenchButton
---@field SetChecked fun(self: RMWorkbenchCheckBox, value: boolean)
---@field GetChecked fun(self: RMWorkbenchCheckBox): boolean
---@return RMWorkbenchCheckBox
function addon:CreateWorkbenchCheckBox(parent, label, width)
    local button = self:CreateWorkbenchButton(parent, label, width)
    button.art:Hide()
    local box = button:CreateTexture(nil, 'BACKGROUND')
    box:SetPoint('LEFT', 0, 0)
    box:SetSize(16, 16)
    box:SetColorTexture(.1, .1, .1, 1)
    local check = button:CreateTexture(nil, 'ARTWORK')
    check:SetPoint('LEFT', 0, 0)
    check:SetSize(16, 16)
    check:SetTexture(self:ControlTexture('check'))
    check:SetVertexColor(1, .82, .2, 1)
    button.check = check
    local text = button:GetFontString()
    text:ClearAllPoints()
    text:SetPoint('LEFT', 22, 0)
    text:SetWidth(math.max(1, (width or 150) - 22))
    text:SetJustifyH('LEFT')

    -- Shows or hides the check mark; only a literal `true` counts as checked.
    -- @param value boolean|nil  True to check.
    function button:SetChecked(value)
        self.checked = value == true

        if self.checked then
            check:Show()
        else
            check:Hide()
        end
    end

    -- Returns the stored checked state (nil before the first SetChecked).
    -- @return boolean|nil  The checked state.
    function button:GetChecked()
        return self.checked
    end

    button:SetChecked(false)
    ---@cast button RMWorkbenchCheckBox
    return button
end

-- Returns the icon for condition `tag`: an override, else the definition's icon, else the question-mark icon.
-- @param tag string  The condition tag.
-- @return string|number  The icon texture path or file ID.
function addon:GetConditionIcon(tag)
    local replacement = self.conditionIcons and self.conditionIcons[tag]
    local definition = (self.conditionDefinitions or {})[tag] or (self.conditionSpecials or {})[tag]
    local icon = replacement or definition and definition.icon
    return (type(icon) == "string" or type(icon) == "number") and icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Adds a nine-slice rounded fill and border to `frame`. Used by cards, pills and panels.
-- @param frame Frame  The frame to decorate.
-- @return table  A decoration { fill, border, SetColors(r, g, b, alpha, fillAlpha) } whose SetColors recolors it.
function addon:CreateRoundedCardDecoration(frame)
    local decoration = { fill = {}, border = {} }

    for _, layer in ipairs({
        { key = "fill", texture = "card-fill", draw = "BACKGROUND" },
        { key = "border", texture = "card-border", draw = "BORDER" },
    }) do
        for row = 1, 3 do
            for column = 1, 3 do
                local texture = frame:CreateTexture(nil, layer.draw)
                texture:SetTexture(self:ControlTexture(layer.texture))
                local coords = { 0, .125, .875, 1 }
                texture:SetTexCoord(coords[column], coords[column + 1], coords[row], coords[row + 1])
                local top = row == 1 and "TOP" or row == 3 and "BOTTOM" or ""
                local side = column == 1 and "LEFT" or column == 3 and "RIGHT" or ""

                if row == 2 and column == 2 then
                    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
                    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
                elseif row == 2 then
                    texture:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, -8)
                    texture:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 8)
                    texture:SetWidth(8)
                elseif column == 2 then
                    texture:SetPoint(top .. "LEFT", frame, top .. "LEFT", 8, 0)
                    texture:SetPoint(top .. "RIGHT", frame, top .. "RIGHT", -8, 0)
                    texture:SetHeight(8)
                else
                    texture:SetPoint(top .. side, frame, top .. side, 0, 0)
                    texture:SetSize(8, 8)
                end

                decoration[layer.key][#decoration[layer.key] + 1] = texture
            end
        end
    end

    -- Recolors the border and fill. Repainting the same colors (every redraw does) costs eighteen texture calls; skip
    -- it.
    -- @param r number  The border red channel, 0 to 1.
    -- @param g number  The border green channel, 0 to 1.
    -- @param b number  The border blue channel, 0 to 1.
    -- @param alpha number  The border opacity.
    -- @param fillAlpha number  The fill opacity.
    function decoration:SetColors(r, g, b, alpha, fillAlpha)
        local last = self.painted

        if last and last[1] == r and last[2] == g and last[3] == b and last[4] == alpha and last[5] == fillAlpha then
            return
        end

        self.painted = { r, g, b, alpha, fillAlpha }

        for _, part in ipairs(self.border) do
            part:SetVertexColor(r, g, b, alpha)
        end

        for _, part in ipairs(self.fill) do
            part:SetVertexColor(.15, .15, .15, fillAlpha)
        end
    end

    return decoration
end

-- Creates the card expand/collapse arrow; PointState('compact' | 'expanded' | other) picks the icon and rotation.
-- @param parent Frame  The parent frame.
-- @return RMConditionChevron  The new button.
---@class RMConditionChevron: RMIconButton
---@field PointDown fun(self: RMConditionChevron, down: boolean)
---@field PointState fun(self: RMConditionChevron, state: string)
---@return RMConditionChevron
function addon:CreateConditionChevron(parent)
    local button = self:CreateWorkbenchIconButton(parent, "chevron-right")
    button:SetSize(18, 18)

    -- Shows the chevron pointing down (expanded) or right (collapsed).
    -- @param down boolean|nil  True for down.
    function button:PointDown(down)
        self.icon:SetTexture(addon:ControlTexture(down and "chevron-down" or "chevron-right"))
    end

    -- Shows the chevron for a card state: 'compact' (rotated), 'expanded' (double) or normal.
    -- @param state string  'compact', 'expanded' or any other value for normal.
    function button:PointState(state)
        self.icon:SetRotation(state == 'compact' and math.pi or 0)

        self.icon:SetTexture(addon:ControlTexture(
            state == 'compact' and 'chevron-down' or state == 'expanded' and 'chevron-double-down' or 'chevron-down'
        ))
    end

    button:PointDown(false)
    ---@cast button RMConditionChevron
    return button
end

-- Removes hyperlink, color and texture markup from a name. Names are editable labels; spell hyperlinks belong in action
-- summaries.
-- @param value any  The name.
-- @return string  The plain name; an empty string for a non-string.
function addon:PlainWorkbenchName(value)
    if type(value) ~= 'string' then
        return ''
    end

    return (value:gsub('|H.-|h%[(.-)%]|h', '%1'):gsub('|H.-|h(.-)|h', '%1'):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub(
        '|r',
        ''
    ):gsub('|T.-|t', ''))
end

-- Makes an inline name edit box call `finish` when it loses focus or the player clicks anywhere outside it, which the
-- client would not otherwise report for a click on a non-focusable area.
-- @param input EditBox  The name edit box.
-- @param finish function  Called when editing ends.
function addon:BindWorkbenchInlineName(input, finish)
    -- True while either mouse button is held (used to detect a click outside the name box).
    -- @return boolean  True when a mouse button is down.
    local function down()
        return IsMouseButtonDown and (IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')) or false
    end

    input.rmNameMouseDown = down()

    addon:SetUIScript(input, 'OnEditFocusGained', function()
        input.rmNameMouseDown = down()
    end)

    addon:SetUIScript(input, 'OnEditFocusLost', finish)

    addon:SetUIScript(input, 'OnUpdate', function()
        local pressed = down()

        if pressed and not input.rmNameMouseDown and not addon:IsWorkbenchDropZoneUnderPointer(input, input) then
            input:ClearFocus()
            finish()
        end

        input.rmNameMouseDown = pressed
    end)
end

-- Puts a red outline and tooltip on a control when something beneath it stops a rotation being selected (the editor's
-- Rotation and Cooldowns tabs, the browser's rotation rows). Repainting the same state costs nothing.
-- @param control Frame  The control to mark.
-- @param text string|nil  The problem text shown as the tooltip; nil or a non-string clears the outline and restores
--   the control's own tooltip.
function addon:SetWorkbenchProblem(control, text)
    if type(text) ~= 'string' then
        text = nil
    end

    if control.problemText == text then
        return
    end

    if text and not control.problemEdges then
        control.problemEdges = {}

        for _, side in ipairs({
            { 'TOPLEFT', 'TOPRIGHT', 'h' },
            { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'h' },
            { 'TOPLEFT', 'BOTTOMLEFT', 'v' },
            { 'TOPRIGHT', 'BOTTOMRIGHT', 'v' },
        }) do
            local edge = control:CreateTexture(nil, 'OVERLAY')
            edge:SetColorTexture(.9, .25, .2, .95)
            edge:SetPoint(side[1])
            edge:SetPoint(side[2])

            if side[3] == 'h' then
                edge:SetHeight(2)
            else
                edge:SetWidth(2)
            end

            control.problemEdges[#control.problemEdges + 1] = edge
        end
    end

    if control.problemText == nil then
        control.problemBaseTooltip = control.tooltip
    end

    control.problemText = text

    for _, edge in ipairs(control.problemEdges or {}) do
        if text then
            edge:Show()
        else
            edge:Hide()
        end
    end

    if text then
        control.tooltip = text
    else
        control.tooltip = control.problemBaseTooltip
        control.problemBaseTooltip = nil
    end
end

-- Shows an amber bar down a row's left edge: a notice, not a blocking problem.
-- @param control Frame  The row.
-- @param shown boolean|nil  True to show the bar.
-- @param strong boolean|nil  True (a tie) makes it wider and brighter.
function addon:SetWorkbenchNotice(control, shown, strong)
    if not shown and not control.noticeBar then
        return
    end

    if not control.noticeBar then
        control.noticeBar = control:CreateTexture(nil, 'OVERLAY')
        control.noticeBar:SetPoint('TOPLEFT')
        control.noticeBar:SetPoint('BOTTOMLEFT')
    end

    control.noticeBar:SetWidth(strong and 5 or 3)
    control.noticeBar:SetColorTexture(1, .72, .25, strong and 1 or .7)
    control.noticeStrong = shown and strong or nil

    if shown then
        control.noticeBar:Show()
    else
        control.noticeBar:Hide()
    end
end

-- Creates a list row button (default 32 px tall).
-- @param parent Frame  The parent frame.
-- @param width number  The row width.
-- @param height number|nil  The row height; defaults to 32.
-- @return Button  The new row.
function addon:CreateWorkbenchListRow(parent, width, height)
    local row = self:CreateWorkbenchButton(parent, '', width)
    row:SetHeight(height or 32)
    return row
end

-- Highlights or clears a list row's selection tint.
-- @param control Button  The row.
-- @param selected boolean|nil  True to highlight.
function addon:SetWorkbenchListSelection(control, selected)
    if control.SetSelected then
        control:SetSelected(selected)
    end

    if not control.selection then
        control.selection = control:CreateTexture(nil, 'BACKGROUND')
        control.selection:SetAllPoints(control)
    end

    control.selection:SetColorTexture(.1, .25, .3, .8)

    if selected then
        control.selection:Show()
    else
        control.selection:Hide()
    end
end

-- ============================================================================
-- Text and number inputs
-- ============================================================================

-- Creates a flat single-line edit box (24 px, dark background, underline); callers set multi-line, limits and scripts.
-- @param parent Frame  The parent frame.
-- @return EditBox  The new edit box.
function addon:CreateWorkbenchEditBox(parent)
    local input = CreateFrame("EditBox", nil, parent)
    self:TrackWorkbenchSize(input)
    input:SetFontObject("GameFontHighlightSmall")
    input:SetAutoFocus(false)
    input:SetTextInsets(6, 6, 0, 0)
    input:SetHeight(24)
    local background = input:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(input)
    background:SetColorTexture(.08, .09, .10, .95)
    local line = input:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(.38, .43, .48, .8)
    input.art = background
    return input
end

-- Shows gray hint text inside an empty, unfocused edit box. Idempotent. Call input.RefreshWorkbenchSearchHint after
-- setting the text from code.
-- @param input EditBox  The edit box.
-- @param text string|nil  The hint; defaults to the localized "Search...".
-- @return FontString  The hint.
function addon:AttachWorkbenchSearchHint(input, text)
    if input.searchHint then
        return input.searchHint
    end

    local hint = input:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    input.searchHint = hint
    hint:SetPoint('LEFT', 6, 0)
    hint:SetJustifyH('LEFT')
    hint:SetText(text or LibStub('AceLocale-3.0'):GetLocale(addon_name)['Search...'])
    local focused = false

    -- Shows the hint only while the box is empty and unfocused, sized to the box.
    local function refresh()
        hint:SetWidth(math.max(1, input:GetWidth() - 12))

        if not focused and (input:GetText() or '') == '' then
            hint:Show()
        else
            hint:Hide()
        end
    end

    input:HookScript('OnEditFocusGained', function()
        focused = true
        refresh()
    end)

    input:HookScript('OnEditFocusLost', function()
        focused = false
        refresh()
    end)

    input:HookScript('OnTextChanged', refresh)
    input:HookScript('OnSizeChanged', refresh)

    input:HookScript('OnHide', function()
        focused = false
        refresh()
    end)

    input.RefreshWorkbenchSearchHint = refresh
    refresh()
    return hint
end

-- Creates a flat horizontal slider that obeys its step while dragging.
-- @param parent Frame  The parent frame.
-- @param minimum number  The lowest value.
-- @param maximum number  The highest value.
-- @param step number  The value step.
-- @param width number|nil  The width; defaults to 112.
-- @return Slider  The new slider.
function addon:CreateWorkbenchSlider(parent, minimum, maximum, step, width)
    local slider = CreateFrame("Slider", nil, parent)
    self:TrackWorkbenchSize(slider)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width or 112, 12)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)

    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(3)
    track:SetColorTexture(.3, .32, .34, 1)
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(7, 12)
    thumb:SetColorTexture(.78, .8, .82, 1)
    slider:SetThumbTexture(thumb)
    return slider
end

-- ============================================================================
-- Scrolling
-- ============================================================================

-- Creates a flat, narrow scroll bar with a proportional rectangular thumb, arrow buttons and page regions. This follows
-- the modern Details/Plater convention; these frames belong to RM, without a provider.
-- @param parent Frame  The parent frame.
-- @param orientation string|nil  'HORIZONTAL' or 'VERTICAL' (the default).
-- @return Slider  The bar; bar:UpdateExtent(content, visible) sets its range and shows or hides it.
function addon:CreateWorkbenchScrollBar(parent, orientation)
    local horizontal = orientation == 'HORIZONTAL'
    local bar = CreateFrame('Slider', nil, parent)
    bar:SetOrientation(orientation or 'VERTICAL')
    bar:SetSize(horizontal and 160 or 10, horizontal and 10 or 160)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:EnableMouseWheel(true)
    local track = bar:CreateTexture(nil, 'BACKGROUND')
    track:SetAllPoints(bar)
    track:SetColorTexture(.08, .08, .08, .85)
    local thumb = bar:CreateTexture(nil, 'ARTWORK')
    thumb:SetSize(horizontal and 30 or 8, horizontal and 8 or 30)
    thumb:SetColorTexture(.48, .48, .48, .9)
    bar.thumbTexture = thumb

    for _, entry in ipairs({ { 'back', 'up', -1 }, { 'forward', 'down', 1 } }) do
        local direction = entry[3]
        local control = self:CreateWorkbenchIconButton(bar, entry[2])
        control:SetSize(10, 10)
        control.icon:SetSize(9, 9)
        bar[entry[1]] = control

        if horizontal then
            control.icon:SetRotation(math.pi / 2)
        end

        control:SetPoint(
            horizontal and (direction < 0 and 'RIGHT' or 'LEFT') or (direction < 0 and 'BOTTOM' or 'TOP'),
            bar,
            horizontal and (direction < 0 and 'LEFT' or 'RIGHT') or (direction < 0 and 'TOP' or 'BOTTOM'),
            0,
            0
        )

        addon:SetUIScript(control, 'OnClick', function()
            bar:SetValue((bar:GetValue() or 0) + direction * 40)
        end)
    end

    -- Moves the thumb to match the bar's value within its travel.
    local function placeThumb()
        local length = horizontal and bar:GetWidth() or bar:GetHeight()
        local travel = math.max(0, length - (bar.thumbLength or 18))
        local fraction = (bar.scrollRange or 0) > 0 and bar:GetValue() / bar.scrollRange or 0
        thumb:ClearAllPoints()

        thumb:SetPoint(
            horizontal and 'LEFT' or 'TOP',
            horizontal and travel * fraction or 0,
            horizontal and 0 or -travel * fraction
        )
    end

    -- Keep repaint owned by this control, independently of consumer callbacks.
    -- Reflow can clamp the native value before its value-change hook runs.
    local nativeSetValue = bar.SetValue

    -- Sets the scroll value and moves the thumb in the same call. Keeps repaint owned by this control, independently of
    -- consumer callbacks: reflow can clamp the native value before its value-change hook runs.
    -- @param value number  The new scroll value.
    function bar:SetValue(value)
        nativeSetValue(self, value)
        placeThumb()
    end

    local drag = CreateFrame('Button', nil, bar)
    bar.thumbButton = drag
    drag:SetAllPoints(thumb)

    addon:SetUIScript(drag, 'OnMouseDown', function(_, button)
        if button ~= 'LeftButton' or not GetCursorPosition then
            return
        end

        local x, y = GetCursorPosition()
        bar.dragStart = { position = horizontal and x or y, value = bar:GetValue() }
    end)

    -- Ends a thumb drag.
    local function stop()
        bar.dragStart = nil
    end

    addon:SetUIScript(drag, 'OnMouseUp', stop)
    addon:SetUIScript(drag, 'OnHide', stop)

    -- Per-frame thumb drag: scrolls the bar by the cursor movement since the press, and ends the drag when the left
    -- button is released.
    addon:SetUIScript(drag, 'OnUpdate', function()
        local start = bar.dragStart

        if not start then
            return
        end

        if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
            stop()
            return
        end

        local x, y = GetCursorPosition()
        local delta = ((horizontal and x or y) - start.position) / bar:GetEffectiveScale()
        local length = horizontal and bar:GetWidth() or bar:GetHeight()
        local travel = math.max(1, length - (bar.thumbLength or 18))
        bar:SetValue(start.value + (horizontal and delta or -delta) * (bar.scrollRange or 0) / travel)
    end)

    drag:EnableMouseWheel(true)

    addon:SetUIScript(drag, 'OnMouseWheel', function(_, delta)
        bar:SetValue(bar:GetValue() - delta * 40)
    end)

    -- These regions cover only the empty track around the owned thumb.

    for _, entry in ipairs({ { 'pageBack', -1 }, { 'pageForward', 1 } }) do
        local control = CreateFrame('Button', nil, bar)
        bar[entry[1]] = control

        if horizontal then
            control:SetPoint('TOP', bar, 'TOP')
            control:SetPoint('BOTTOM', bar, 'BOTTOM')
            control:SetPoint('LEFT', entry[2] < 0 and bar or thumb, entry[2] < 0 and 'LEFT' or 'RIGHT')
            control:SetPoint('RIGHT', entry[2] < 0 and thumb or bar, entry[2] < 0 and 'LEFT' or 'RIGHT')
        else
            control:SetPoint('LEFT', bar, 'LEFT')
            control:SetPoint('RIGHT', bar, 'RIGHT')
            control:SetPoint('TOP', entry[2] < 0 and bar or thumb, entry[2] < 0 and 'TOP' or 'BOTTOM')
            control:SetPoint('BOTTOM', entry[2] < 0 and thumb or bar, entry[2] < 0 and 'TOP' or 'BOTTOM')
        end

        local direction = entry[2]

        addon:SetUIScript(control, 'OnMouseDown', function(_, button)
            if button == 'LeftButton' then
                bar:SetValue((bar:GetValue() or 0) + direction * (bar.pageSize or 1))
            end
        end)

        control:EnableMouseWheel(true)

        addon:SetUIScript(control, 'OnMouseWheel', function(_, delta)
            bar:SetValue((bar:GetValue() or 0) - delta * 40)
        end)
    end

    addon:SetUIScript(bar, 'OnMouseWheel', function(_, delta)
        bar:SetValue((bar:GetValue() or 0) - delta * 40)
    end)

    addon:SetUIScript(bar, 'OnEnter', function()
        thumb:SetColorTexture(.7, .7, .7, 1)
    end)

    addon:SetUIScript(bar, 'OnLeave', function()
        thumb:SetColorTexture(.48, .48, .48, .9)
    end)

    -- Sets the scroll range from the `content` and `visible` lengths, clamps the value, sizes the thumb and shows the
    -- bar only when there is something to scroll.
    -- @param content number  The length of the scrolled content.
    -- @param visible number  The length of the viewport.
    --
    -- Re-entrancy safe: a nested update (from a value-change callback) wins.
    function bar:UpdateExtent(content, visible)
        self.extentRevision = (self.extentRevision or 0) + 1
        local revision = self.extentRevision
        self.pageSize = math.max(1, visible)
        local range = math.max(0, content - visible)
        self.scrollRange = range
        self:SetMinMaxValues(0, range)

        if self.extentRevision ~= revision then
            return
        end

        self:SetValue(math.min(self:GetValue() or 0, range))

        if self.extentRevision ~= revision then
            return
        end

        local length = horizontal and self:GetWidth() or self:GetHeight()
        local size = math.min(length, math.max(18, length * math.min(1, visible / math.max(1, content))))

        if size ~= self.thumbLength then
            self.thumbLength = size

            if horizontal then
                thumb:SetWidth(size)
            else
                thumb:SetHeight(size)
            end
        end

        placeThumb()

        if range > 0 then
            self:Show()
        else
            self.dragStart = nil
            self:Hide()
        end
    end

    return bar
end

-- Creates a scroll frame with its own vertical bar (frame.workbenchBar). Scroll size follows the child, and
-- UpdateWorkbenchScroll re-measures after the child changes height.
-- @param parent Frame  The parent frame.
-- @return ScrollFrame  The new scroll frame.
function addon:CreateWorkbenchScrollFrame(parent)
    local scroll = CreateFrame('ScrollFrame', nil, parent)
    self:TrackWorkbenchSize(scroll)
    local bar = self:CreateWorkbenchScrollBar(scroll, 'VERTICAL')
    self:TrackWorkbenchSize(bar)
    scroll.workbenchBar = bar
    local setScrollChild = scroll.SetScrollChild

    -- Tracks the child's size, then installs it as the scroll child.
    -- @param child Frame  The scroll child.
    -- @param ... any  Further arguments of SetScrollChild.
    -- @return any  What the original SetScrollChild returns.
    function scroll:SetScrollChild(child, ...)
        addon:TrackWorkbenchSize(child)
        return setScrollChild(self, child, ...)
    end

    bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 4, -10)
    bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 4, 10)

    addon:SetUIScript(bar, 'OnValueChanged', function(_, value)
        local current = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or scroll.lastAppliedOffset

        if current == nil or math.abs(current - value) > .001 then
            scroll.lastAppliedOffset = value
            scroll:SetVerticalScroll(value)
        end
    end)

    -- Re-measures the child against the viewport and refits the column width.
    function scroll:UpdateWorkbenchScroll()
        local child = self:GetScrollChild()

        if not child then
            return
        end

        bar:UpdateExtent(child:GetHeight(), self:GetHeight())
        self:FitWorkbenchColumn()
    end

    -- Sets the width of a list column. A list column keeps its rows flush with the column's right edge: the bar takes
    -- its reserve only while the list actually scrolls. The owner's OnWorkbenchColumnResized refreshes row widths after
    -- a change.
    -- @param width number  The column width, at least 1.
    function scroll:SetWorkbenchColumnWidth(width)
        self.workbenchColumnWidth = math.max(1, width)
        self:FitWorkbenchColumn()
    end

    -- Resizes the viewport and child to the column width, minus the bar's reserve only while the bar shows; tells the
    -- owner.
    function scroll:FitWorkbenchColumn()
        local column = self.workbenchColumnWidth

        if not column or self.fittingColumn then
            return
        end

        local wanted = math.max(1, column - (bar:IsShown() and addon.WorkbenchLayout.scrollReserve or 0))
        local child = self:GetScrollChild()

        if math.abs(self:GetWidth() - wanted) < .01 and (not child or math.abs(child:GetWidth() - wanted) < .01) then
            return
        end

        self.fittingColumn = true
        self:SetWidth(wanted)

        if child then
            child:SetWidth(wanted)
        end

        self.fittingColumn = nil

        if self.OnWorkbenchColumnResized then
            self:OnWorkbenchColumnResized(wanted)
        end
    end

    addon:SetUIScript(scroll, 'OnScrollRangeChanged', function()
        scroll:UpdateWorkbenchScroll()
    end)

    addon:SetUIScript(scroll, 'OnSizeChanged', function()
        scroll:UpdateWorkbenchScroll()
    end)

    scroll:EnableMouseWheel(true)

    addon:SetUIScript(scroll, 'OnMouseWheel', function(_, delta)
        bar:SetValue((bar:GetValue() or 0) - delta * 40)
    end)

    return scroll
end

-- Creates a single native scroll host for measured RM groups. Content ownership and its callback lease are detached
-- before recycling, so old windows cannot resize a root that has already been borrowed by another editor.
-- @param parent Frame  The parent frame.
-- @return ScrollFrame  The viewport; scroll:SetConditionContent(root) hosts a group and
--   scroll:ReleaseConditionContent() detaches it.
function addon:CreateWorkbenchGroupViewport(parent)
    local scroll = self:CreateWorkbenchScrollFrame(parent)
    local empty = CreateFrame('Frame', nil, scroll)
    empty:SetSize(1, 1)
    scroll:SetScrollChild(empty)

    -- Detaches the hosted condition group and releases it if this viewport still holds its lease; resets to an empty
    -- child.
    function scroll:ReleaseConditionContent()
        local root, lease, finish = self.contentWidget, self.contentLease, self.originalLayoutFinished
        self.contentWidget = nil
        self.contentLease = nil
        self.originalLayoutFinished = nil
        self:SetScrollChild(empty)

        if root and root.rmLease == lease and root.rmActive then
            root.LayoutFinished = finish
            addon:ReleaseConditionWidget(root)
        end

        self:UpdateWorkbenchScroll()
    end

    -- Hosts the native condition group `root`: restores its layout callback on release and re-measures the scroll
    -- extent after each layout. Replaces any previous content.
    -- @param root table|nil  An active RM condition group widget (it must have DoLayout); nil just clears the content.
    function scroll:SetConditionContent(root)
        if root then
            assert(root.rmWidget and root.rmActive and root.DoLayout, 'native-condition-group-required')
        end

        if self.contentWidget == root and (not root or self.contentLease == root.rmLease) then
            if root then
                root:SetWidth(self:GetWidth())
            end

            return
        end

        self:ReleaseConditionContent()

        if not root then
            return
        end

        self.contentWidget = root
        local lease = root.rmLease
        self.contentLease = lease
        local finish = root.LayoutFinished
        self.originalLayoutFinished = finish

        -- Chains the group's own layout callback, then re-measures the scroll extent; ignored once the group is no
        -- longer this viewport's content.
        -- @param widget table  The group that finished laying out.
        -- @param width number  The laid out width.
        -- @param height number  The laid out height.
        root.LayoutFinished = function(widget, width, height)
            if scroll.contentWidget ~= widget or widget.rmLease ~= lease or not widget.rmActive then
                return
            end

            if finish then
                finish(widget, width, height)
            end

            scroll:UpdateWorkbenchScroll()
        end

        root.frame:SetParent(self)
        root.frame:ClearAllPoints()
        root.frame:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
        self:SetScrollChild(root.frame)
        root:SetWidth(self:GetWidth())
        root.frame:Show()
        self:UpdateWorkbenchScroll()
    end

    local resized = scroll:GetScript('OnSizeChanged')

    addon:SetUIScript(scroll, 'OnSizeChanged', function(frame, width, height)
        local root = frame.contentWidget

        if root then
            if root.rmActive and root.rmLease == frame.contentLease then
                root:SetWidth(width)
            else
                frame:ReleaseConditionContent()
            end
        end

        if resized then
            resized(frame, width, height)
        end
    end)

    return scroll
end

-- ============================================================================
-- Drag and drop
-- ============================================================================

-- True when the pointer is inside both `zone` and `viewport`, using cursor geometry where the client allows it and
-- mouse-over otherwise. Zones that scrolled out of the viewport must not accept a drop.
-- @param zone Frame  The drop zone.
-- @param viewport Frame|nil  The scroll viewport that clips the zone; nil skips that check on the mouse-over path.
-- @return boolean  True when the pointer is over the zone.
function addon:IsWorkbenchDropZoneUnderPointer(zone, viewport)
    if GetCursorPosition and zone.GetLeft and zone.GetRight and zone.GetTop and zone.GetBottom then
        local x, y = GetCursorPosition()

        -- True when the cursor lies within `frame`'s rectangle, in that frame's own scale.
        -- @param frame Frame  The frame to test.
        -- @return boolean  True when the cursor is inside.
        local function inside(frame)
            local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()

            if not left or not right or not top or not bottom then
                return false
            end

            local scale = frame:GetEffectiveScale()
            local cx, cy = x / scale, y / scale
            return cx >= left and cx <= right and cy >= bottom and cy <= top
        end

        return inside(viewport) and inside(zone)
    end

    local over = InputUtil and InputUtil.IsMouseOver or MouseIsOver
    return over and over(zone) and (not viewport or over(viewport)) or false
end

-- Creates the floating card that follows the pointer during a drag (title, summary, optional count and stacked layers).
-- Present shows it and FollowPointer tracks the cursor.
-- @return Frame  The card frame, hidden.
function addon:CreateWorkbenchDragCard()
    local frame = CreateFrame('Frame', nil, UIParent)
    frame:SetSize(340, 76)
    frame:SetFrameStrata('TOOLTIP')
    frame:EnableMouse(false)
    local art = self:CreateRoundedCardDecoration(frame)
    art:SetColors(.7, .7, .7, 1, .9)
    frame.label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    frame.label:SetPoint('TOPLEFT', 10, -8)
    frame.label:SetWidth(320)
    frame.label:SetJustifyH('LEFT')
    frame.label:SetMaxLines(1)
    frame.count = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    frame.count:SetPoint('TOPRIGHT', -10, -8)
    frame.count:SetWidth(84)
    frame.count:SetJustifyH('RIGHT')
    frame.stack = {}

    for i = 1, 2 do
        local layer = frame:CreateTexture(nil, 'BACKGROUND', nil, -2)
        layer:SetTexture(addon:ControlTexture('card-border'))
        layer:SetPoint('TOPLEFT', frame, 'TOPLEFT', i * 4, -i * 4)
        layer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', i * 4, -i * 4)
        layer:SetVertexColor(.7, .7, .7, .8)
        layer:Hide()
        frame.stack[i] = layer
    end

    frame.summary = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    frame.summary:SetPoint('TOPLEFT', 10, -28)
    frame.summary:SetWidth(320)
    frame.summary:SetWordWrap(true)
    frame.summary:SetJustifyH('LEFT')
    frame.summary:SetMaxLines(3)

    -- Moves the card next to the cursor.
    function frame:FollowPointer()
        if GetCursorPosition then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x / scale + 16, y / scale - 16)
        end
    end

    -- Fills and shows the card above `source`.
    -- @param title string  The one-line title.
    -- @param summary string  The summary text (up to three lines).
    -- @param source Frame|nil  The frame the drag started from; the card is raised above it and scaled to match it.
    -- @param count number|nil  A count over 1 adds the stacked look and "N cards" label.
    function frame:Present(title, summary, source, count)
        self:SetFrameStrata('TOOLTIP')
        self:SetFrameLevel((source and source:GetFrameLevel() or 0) + 500)
        self:SetClampedToScreen(true)
        self:SetToplevel(true)
        count = type(count) == 'number' and count or 1

        if count > 1 then
            self.count:SetText(string.format(LibStub('AceLocale-3.0'):GetLocale(addon_name)['%d cards'], count))
            self.count:Show()
            self.label:SetWidth(230)
        else
            self.count:Hide()
            self.label:SetWidth(320)
        end

        for _, layer in ipairs(self.stack) do
            if count > 1 then
                layer:Show()
            else
                layer:Hide()
            end
        end

        self.label:SetText(title)
        self.summary:SetText(summary)

        if source and UIParent.GetEffectiveScale then
            self:SetScale(source:GetEffectiveScale() / UIParent:GetEffectiveScale())
        end

        self:SetAlpha(.9)
        self:FollowPointer()
        self:Show()
    end

    self:InstallDragPresentation(frame, art)
    frame:Hide()
    return frame
end

-- True when entry `from` (or, with `tail`, it and every later entry) may be moved to gap `gap` of `items`. Gap indices
-- refer to the original list. A suffix cannot be dropped into itself; manual arrow controls always request a single
-- entry.
-- @param items table  The list.
-- @param from number  The index of the entry to move.
-- @param gap number  The target gap, from 1 (before the first entry) to #items + 1 (after the last).
-- @param tail boolean|nil  True to move the entry and every later one.
-- @return boolean  True when the move is legal and changes the order.
function addon:CanReorderWorkbenchRange(items, from, gap, tail)
    return type(items) == 'table'
        and type(from) == 'number'
        and from % 1 == 0
        and from >= 1
        and from <= #items
        and type(gap) == 'number'
        and gap % 1 == 0
        and gap >= 1
        and gap <= #items + 1
        and (tail and gap < from or not tail and gap ~= from and gap ~= from + 1)
end

-- Moves entry `from` (or it and every later entry when `tail`) to gap `gap` of `items` in place.
-- @param items table  The list; changed in place.
-- @param from number  The index of the entry to move.
-- @param gap number  The target gap, indexed in the original list.
-- @param tail boolean|nil  True to move the entry and every later one.
-- @return boolean  False, changing nothing, when CanReorderWorkbenchRange refuses the move; true otherwise.
function addon:ReorderWorkbenchRange(items, from, gap, tail)
    if not self:CanReorderWorkbenchRange(items, from, gap, tail) then
        return false
    end

    local count = tail and #items - from + 1 or 1
    local moved = {}

    for _ = 1, count do
        moved[#moved + 1] = table.remove(items, from)
    end

    local at = gap > from and gap - count or gap

    for i, value in ipairs(moved) do
        table.insert(items, at + i - 1, value)
    end

    return true
end

-- Makes `control` a drag source and keeps the release of a drag from also firing its click. Drag release may be
-- followed by the source button's click callback. Keep that release from also appending a card or opening the condition
-- picker.
-- @param control Button  The drag source.
-- @param start function  Called when a drag begins, with the drag-start arguments.
-- @param stop function  Called when the drag ends.
function addon:BindWorkbenchDragSource(control, start, stop)
    control:RegisterForDrag('LeftButton')
    local clickable = control:HasScript('OnClick')
    local click = clickable and control:GetScript('OnClick')
    local current = control:GetScript('OnMouseDown')

    if current ~= control.rmDragDownWrapper then
        control.rmDragOriginalDown = current
    end

    local down = control.rmDragOriginalDown

    -- OnMouseDown wrapper: clears the dragged flag, then runs the control's original handler.
    -- @param frame Button  The control.
    -- @param button string  The mouse button.
    -- @param ... any  Further arguments passed to the original handler.
    local wrapper = function(frame, button, ...)
        frame.rmDragged = false

        if down then
            down(frame, button, ...)
        end
    end

    addon:SetUIScript(control, 'OnMouseDown', wrapper)
    control.rmDragDownWrapper = control:GetScript('OnMouseDown')

    addon:SetUIScript(control, 'OnDragStart', function(...)
        control.rmDragged = true
        start(...)
    end)

    addon:SetUIScript(control, 'OnDragStop', stop)

    if clickable then
        addon:SetUIScript(control, 'OnClick', function(...)
            if control.rmDragged then
                control.rmDragged = false
                return
            end

            if click then
                return click(...)
            end
        end)
    end
end

-- ============================================================================
-- Scripts and deferred reflow
-- ============================================================================

-- Sets (or with nil clears) a frame script, wrapping a handler in the diagnostics boundary when it exists. This is the
-- explicit boundary for native RM scripts; no global handler or frame API is replaced. Clear callbacks using the native
-- API as usual.
-- @param frame Frame  The frame.
-- @param event string  The script name.
-- @param callback function|nil  The handler; nil clears the script.
-- @return function|nil  The handler actually installed.
function addon:SetUIScript(frame, event, callback)
    local handler = callback

    if handler and self.Diagnostics then
        handler = self.Diagnostics:Wrap({ module = 'ui', operation = event }, handler)
    end

    frame:SetScript(event, handler)
    return handler
end

-- Live reflow, coalesced. A window grip or divider drag reports a new size
-- every rendered frame, often through several nested frames. Owners do the
-- cheap geometry at once and request their expensive relayout here: one
-- shared driver runs each pending owner at most once per rendered frame,
-- the latest request winning, and then stops itself so idle frames cost
-- nothing. An owner that is not visible is dropped (it draws when opened
-- again). Each run is timed, and the owner's next run waits twice that long,
-- so a relayout that is slow on this machine takes at most a third of the
-- frames of a drag; the last request always runs once the waiting is over.
-- A settle request runs once its owner has had no reflow request for a few
-- rendered frames: the full drawing after a drag that reflowed cheaply.
local reflowQueue, settleQueue, reflowDriver = {}, {}, nil

-- Seconds from the best clock the client offers (a monotonic profile clock, else game time).
-- @return number  The time in seconds; 0 when no clock exists.
local function reflowClock()
    if type(debugprofilestop) == 'function' then
        return debugprofilestop() / 1000
    end
    if type(GetTime) == 'function' then
        return GetTime()
    end

    return 0
end

-- True when a queued owner's frame is visible; an invisible owner is dropped and redraws when it opens again.
-- @param frame Frame|nil  The owner's frame; nil counts as visible.
-- @return boolean  True when the owner should be redrawn.
local function reflowVisible(frame)
    if not frame then
        return true
    end
    if frame.IsVisible then
        return frame:IsVisible() and true or false
    end

    for _ = 1, 64 do
        if not frame then
            return true
        end
        if frame.IsShown and not frame:IsShown() then
            return false
        end

        frame = frame.GetParent and frame:GetParent() or nil
    end

    return true
end

-- Adds the stack a failing relayout failed in to its message. pcall alone loses it, leaving only the message and this
-- driver's own frame.
-- @param why any  The error from the relayout.
-- @return any  The message with the stack appended when both are available; otherwise the error unchanged.
local function reflowFailure(why)
    if type(why) ~= 'string' or type(debugstack) ~= 'function' then
        return why
    end

    local ok, stack = pcall(function() return debugstack(2) end)
    return ok and type(stack) == 'string' and why .. '\n' .. stack or why
end

-- The per-frame driver: runs each pending owner at most once (respecting its cost-based wait), then the settle requests
-- whose quiet period is over, and stops itself when both queues are empty. Errors go to the game's error handler, not
-- the caller.
-- @param driver Frame  The driver frame that runs this as its OnUpdate.
local function driveReflow(driver)
    local batch = reflowQueue
    reflowQueue = {}

    for owner, request in pairs(batch) do
        if reflowQueue[owner] then
            -- Requested again by a relayout that already ran this frame.
        elseif not reflowVisible(request.frame) then
            owner.rmReflowAfter = nil
        elseif (owner.rmReflowAfter or 0) > reflowClock() then
            reflowQueue[owner] = request
        else
            local start = reflowClock()
            local ok, why = xpcall(request.run, reflowFailure)
            local finish = reflowClock()
            owner.rmReflowAfter = finish + math.min(.25, math.max(0, finish - start) * 2)

            if not ok then
                local handler = geterrorhandler and geterrorhandler()

                if handler then
                    pcall(handler, why)
                end
            end
        end
    end

    local due = {}

    for owner, request in pairs(settleQueue) do
        if not reflowQueue[owner] then
            request.wait = request.wait - 1

            if request.wait <= 0 then
                settleQueue[owner] = nil

                if reflowVisible(request.frame) then
                    due[#due + 1] = request
                end
            end
        end
    end

    for _, request in ipairs(due) do
        local ok, why = xpcall(request.run, reflowFailure)

        if not ok then
            local handler = geterrorhandler and geterrorhandler()

            if handler then
                pcall(handler, why)
            end
        end
    end

    if next(reflowQueue) == nil and next(settleQueue) == nil then
        driver:SetScript('OnUpdate', nil)
    end
end

-- Queues `run()` as `owner`'s relayout for the next rendered frame; a newer request from the same owner replaces it.
-- @param owner table  The window or pane that owns the relayout (the queue key).
-- @param frame Frame|nil  The owner's frame; an invisible owner is dropped.
-- @param run function  The relayout function.
function addon:RequestWorkbenchReflow(owner, frame, run)
    if type(owner) ~= 'table' or type(run) ~= 'function' then
        return
    end

    reflowQueue[owner] = { frame = frame, run = run }
    reflowDriver = reflowDriver or CreateFrame('Frame')

    if not reflowDriver:GetScript('OnUpdate') then
        reflowDriver:SetScript('OnUpdate', driveReflow)
    end
end

-- Queues `run()` to fire once `owner` has made no reflow request for `frames` rendered frames: the full drawing after a
-- drag that only reflowed cheaply.
-- @param owner table  The window or pane that owns the relayout (the queue key).
-- @param frame Frame|nil  The owner's frame; an invisible owner is dropped.
-- @param run function  The relayout function.
-- @param frames number|nil  The quiet frames to wait; defaults to 6.
function addon:RequestWorkbenchSettle(owner, frame, run, frames)
    if type(owner) ~= 'table' or type(run) ~= 'function' then
        return
    end

    settleQueue[owner] = { frame = frame, run = run, wait = frames or 6 }
    reflowDriver = reflowDriver or CreateFrame('Frame')

    if not reflowDriver:GetScript('OnUpdate') then
        reflowDriver:SetScript('OnUpdate', driveReflow)
    end
end

-- Runs every pending relayout and settle now, without waiting for a frame or a cost window (for code and tests that
-- need the final layout at once).
function addon:FlushWorkbenchReflow()
    for _ = 1, 8 do
        if next(reflowQueue) == nil and next(settleQueue) == nil then
            break
        end

        for owner in pairs(reflowQueue) do
            if type(owner) == 'table' then
                owner.rmReflowAfter = nil
            end
        end

        for _, request in pairs(settleQueue) do
            request.wait = 1
        end

        driveReflow(reflowDriver)
    end
end

-- Removes a released owner from both queues.
-- @param owner table  The owner to forget.
function addon:CancelWorkbenchReflow(owner)
    reflowQueue[owner] = nil
    settleQueue[owner] = nil

    if type(owner) == 'table' then
        owner.rmReflowAfter = nil
    end
end

-- True when `owner` has a reflow or settle request queued.
-- @param owner table  The owner to check.
-- @return boolean  True when a request is pending.
function addon:IsWorkbenchReflowPending(owner)
    return reflowQueue[owner] ~= nil or settleQueue[owner] ~= nil
end

-- ============================================================================
-- Canvas helpers
-- ============================================================================

-- The pointer in a canvas child's own coordinates, for box selection on a card canvas.
-- @param child Frame  The canvas child frame.
-- @return number|nil  X right of the child's top-left, zoom included; nil when the client cannot tell.
-- @return number|nil  Y down from the child's top-left; nil when the client cannot tell.
function addon:WorkbenchPointerIn(child)
    if
        type(GetCursorPosition) ~= 'function'
        or not child
        or not child.GetLeft
        or not child.GetTop
        or not child.GetEffectiveScale
    then
        return
    end

    local ok, x, y = pcall(GetCursorPosition)
    local scale = child:GetEffectiveScale()
    local left, top = child:GetLeft(), child:GetTop()

    -- True only for a real, finite number.
    -- @param value any  The value to test.
    -- @return boolean  True when value is a finite number.
    local function finite(value)
        return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
    end

    if
        not ok
        or not finite(x)
        or not finite(y)
        or not finite(scale)
        or scale <= 0
        or not finite(left)
        or not finite(top)
    then
        return
    end

    return x / scale - left, top - y / scale
end

-- Creates the rubber-band rectangle for box selection: a faint gold fill with a 1px outline, hidden until placed.
-- @param child Frame  The canvas child frame the box is drawn in.
-- @return Frame  The box; frame:Place(x1, y1, x2, y2) shows it between two corners.
function addon:CreateWorkbenchSelectionBox(child)
    local frame = CreateFrame('Frame', nil, child)
    frame:EnableMouse(false)
    frame:Hide()
    frame.fill = frame:CreateTexture(nil, 'OVERLAY')
    frame.fill:SetAllPoints(frame)
    frame.fill:SetColorTexture(.9, .75, .3, .12)

    for _, side in ipairs({
        { 'TOPLEFT', 'TOPRIGHT', 'h' },
        { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'h' },
        { 'TOPLEFT', 'BOTTOMLEFT', 'v' },
        { 'TOPRIGHT', 'BOTTOMRIGHT', 'v' },
    }) do
        local edge = frame:CreateTexture(nil, 'OVERLAY')
        edge:SetColorTexture(.9, .75, .3, .9)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])

        if side[3] == 'h' then
            edge:SetHeight(1)
        else
            edge:SetWidth(1)
        end
    end

    -- Shows the box between two corners given in child coordinates (any corner order).
    -- @param x1 number  The first corner's x.
    -- @param y1 number  The first corner's y.
    -- @param x2 number  The opposite corner's x.
    -- @param y2 number  The opposite corner's y.
    function frame:Place(x1, y1, x2, y2)
        self:ClearAllPoints()
        self:SetPoint('TOPLEFT', child, 'TOPLEFT', math.min(x1, x2), -math.min(y1, y2))
        self:SetSize(math.max(1, math.abs(x2 - x1)), math.max(1, math.abs(y2 - y1)))
        self:SetFrameLevel(child:GetFrameLevel() + 200)
        self:Show()
    end

    return frame
end

-- Creates the 3x3 nudge pad (up, down, left, right, center), one tightly packed position pad for profile and per-card
-- highlight settings. A click calls change(dx, dy, center, step), where Shift makes the step 10.
-- @param parent Frame  The parent frame.
-- @return Frame  The pad; pad.buttons holds its buttons and pad:Bind(change, valid, readOnly) wires it.
function addon:CreateWorkbenchPositionPad(parent)
    local pad = CreateFrame('Frame', nil, parent)
    pad:SetSize(48, 48)
    pad.buttons = {}

    for _, entry in ipairs({
        { 'Up', 'up', 1, 0, 0, 1 },
        { 'Down', 'down', 1, 2, 0, -1 },
        { 'Left', 'up', 0, 1, -1, 0 },
        { 'Right', 'down', 2, 1, 1, 0 },
        { 'Center', 'center', 1, 1, 0, 0 },
    }) do
        local button = self:CreateWorkbenchIconButton(pad, entry[2])
        button:SetPoint('TOPLEFT', entry[3] * 16, -entry[4] * 16)
        button:SetSize(16, 16)
        button.icon:SetSize(18, 18)
        button.icon:SetTexCoord(.125, .875, .125, .875)
        button.icon:SetRotation((entry[1] == 'Left' or entry[1] == 'Right') and math.pi / 2 or 0)
        pad.buttons[entry[1]] = button

        self:SetUIScript(button, 'OnClick', function()
            if pad.valid and pad.valid() then
                pad.change(entry[5], entry[6], entry[1] == 'Center', IsShiftKeyDown and IsShiftKeyDown() and 10 or 1)
            end
        end)
    end

    -- Sets the click callback and its validity check; disables every button when `readOnly`.
    -- @param change function|nil  Called as change(dx, dy, center, step) on a click.
    -- @param valid function|nil  Returns true while a click may act.
    -- @param readOnly boolean|nil  True disables every button.
    function pad:Bind(change, valid, readOnly)
        self.change = change
        self.valid = valid

        for _, button in pairs(self.buttons) do
            if readOnly then
                button:Disable()
            else
                button:Enable()
            end
        end
    end

    return pad
end

-- Returns the range of rows to lease for a flat result list, which retains complete data while leasing nearby native
-- rows.
-- @param count number  The number of rows.
-- @param pitch number  The height of one row.
-- @param offset number  The scroll offset.
-- @param height number  The viewport height.
-- @param margin number  Extra pixels leased above and below the viewport.
-- @return number  The first row index, at least 1.
-- @return number  The last row index, at most `count`.
function addon:GetWorkbenchVisibleRowRange(count, pitch, offset, height, margin)
    return math.max(1, math.floor((offset - margin) / pitch) + 1), math.min(
        count,
        math.floor((offset + height + margin) / pitch) + 1
    )
end

-- ============================================================================
-- Layout constants and geometry
-- ============================================================================

-- Shared workbench sizing. The window minimum is the smallest width at which
-- every page keeps its controls inside the pane; list/detail pages share one
-- divider position, which each page clamps to its own width.
addon.WorkbenchLayout = {
    windowMinWidth = 800,
    windowMinHeight = 500,
    sidebarMin = 200,
    detailMin = 440,
    splitGap = 18,
    scrollReserve = 14,
    helpReserve = 22,
}

-- A workbench page's gold "?" sits in the top-right corner of the page
-- content, on the page's first row. The content frame carries the reserve;
-- panes reaching that corner leave it free on their first row.
-- One section-header style for every page, the one the Rotations editor
-- uses for its "Switch condition" header: GameFontNormal in its gold.
addon.WorkbenchHeaderFont = 'GameFontNormal'
addon.WorkbenchHeaderColor = { 1, .82, 0 }

-- Applies the shared section-header font and gold color to `label`.
-- @param label FontString|nil  The label; nil is returned unchanged.
-- @return FontString|nil  The same label.
function addon:StyleWorkbenchHeader(label)
    if not label then
        return label
    end

    local color = self.WorkbenchHeaderColor

    if label.SetFontObject then
        label:SetFontObject(self.WorkbenchHeaderFont)
    end
    if label.SetTextColor then
        label:SetTextColor(color[1], color[2], color[3])
    end

    label.rmHeaderFont = self.WorkbenchHeaderFont
    return label
end

-- Returns the width the parent content frame reserves for the help "?" in its corner.
-- @param frame Frame|nil  A frame inside the content frame.
-- @return number  The reserve; 0 when it reserves none.
function addon:GetWorkbenchHelpReserve(frame)
    local parent = frame and frame.GetParent and frame:GetParent()
    return parent and parent.rmHelpReserve or 0
end

-- Anchors a detail scroll bar in the help corner (with its 10 px arrow above the track) below the "?".
-- @param owner Frame  The frame whose parent carries the help reserve.
-- @param scroll ScrollFrame|nil  The scroll frame with a workbenchBar; nil does nothing.
-- @param scrollTop number|nil  The scroll frame's top offset inside the content; defaults to 0.
function addon:ReserveWorkbenchHelpCorner(owner, scroll, scrollTop)
    local reserve = self:GetWorkbenchHelpReserve(owner)
    local bar = scroll and scroll.workbenchBar

    if not bar then
        return
    end

    bar:ClearAllPoints()
    bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 4, -math.max(10, reserve > 0 and reserve + 12 - (scrollTop or 0) or 10))
    bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 4, 10)
end

-- Returns the smallest and largest allowed list-column width for a pane of `width`: at most half the pane, and always
-- leaving the detail pane its minimum.
-- @param width number  The pane width.
-- @return number  The smallest allowed list width.
-- @return number  The largest allowed list width.
function addon:GetWorkbenchSidebarBounds(width)
    local layout = self.WorkbenchLayout
    local maximum = math.min(math.floor(width * .5), width - layout.splitGap - layout.detailMin)
    return layout.sidebarMin, math.max(layout.sidebarMin, maximum)
end

-- Returns the saved divider position (db.global.workbenchSidebarWidth) when it is a sane number.
-- @return number|nil  The saved width; nil (automatic) when none is saved or it is not a sane number.
function addon:GetWorkbenchSidebarPreference()
    local global = self.db and self.db.global
    local value = global and global.workbenchSidebarWidth

    if type(value) == 'number' and value == value and value > 0 and value < 100000 then
        return value
    end
end

-- Saves the divider position; nil returns the divider to its automatic position.
-- @param value number|nil  The width to save (rounded); nil clears it. Anything else is ignored.
function addon:SetWorkbenchSidebarPreference(value)
    local global = self.db and self.db.global

    if not global then
        return
    end

    if value == nil then
        global.workbenchSidebarWidth = nil
    elseif type(value) == 'number' and value == value and value > 0 and value < 100000 then
        global.workbenchSidebarWidth = math.floor(value + .5)
    end
end

-- Returns the list-column width to use for a pane of `width`: the saved preference or an automatic 210 to 270, clamped
-- to bounds.
-- @param width number  The pane width.
-- @return number  The list-column width.
function addon:GetWorkbenchSidebarWidth(width)
    local minimum, maximum = self:GetWorkbenchSidebarBounds(width)
    local value = self:GetWorkbenchSidebarPreference() or math.max(210, math.min(270, width * .26))
    return math.max(minimum, math.min(maximum, value))
end

-- Returns the list column's height below `top` (at least 1).
-- @param height number  The pane height.
-- @param top number|nil  The space above the column; defaults to 0.
-- @return number  The column height.
function addon:GetWorkbenchSidebarHeight(height, top)
    return math.max(1, height - (top or 0))
end

-- Returns the shared list/detail geometry every roster page uses.
-- @param width number  The pane width.
-- @param height number  The pane height.
-- @param top number|nil  The space above the list; defaults to 0.
-- @return table  { width, top, sidebarWidth, sidebarHeight, detailX, detailWidth }.
function addon:GetWorkbenchRosterGeometry(width, height, top)
    local side = self:GetWorkbenchSidebarWidth(width)
    local gap = self.WorkbenchLayout.splitGap

    return {
        width = width,
        top = top or 0,
        sidebarWidth = side,
        sidebarHeight = self:GetWorkbenchSidebarHeight(height, top),
        detailX = side + gap,
        detailWidth = math.max(1, width - side - gap),
    }
end

-- ============================================================================
-- Splitter and row layout
-- ============================================================================

-- Creates the draggable divider between a list column and its detail pane. It lives in the gap between them; dragging
-- stores the shared preference and asks the owner to lay out again. Double-click restores the automatic position.
-- @param parent Frame  The parent frame.
-- @param changed function  Called as changed(previous) after the preference changes, passing the previous preference so
--   an owner that cannot follow may restore it.
-- @return Button  The splitter { Place(geometry), Resize(value), Reset(), Stop() }.
function addon:CreateWorkbenchSplitter(parent, changed)
    local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local splitter = CreateFrame('Button', nil, parent)
    splitter:SetSize(10, 1)
    splitter:EnableMouse(true)
    local line = splitter:CreateTexture(nil, 'ARTWORK')
    line:SetPoint('TOP', splitter, 'TOP', 0, 0)
    line:SetPoint('BOTTOM', splitter, 'BOTTOM', 0, 0)
    splitter.line = line

    -- Repaints the divider line for the idle, hover and dragging states.
    local function paint()
        if splitter.drag then
            line:SetColorTexture(.9, .75, .3, 1)
            line:SetWidth(2)
        elseif splitter.hover then
            line:SetColorTexture(.62, .66, .69, 1)
            line:SetWidth(2)
        else
            line:SetColorTexture(.33, .35, .37, .8)
            line:SetWidth(1)
        end
    end

    -- Positions the divider in the gap of the given roster geometry and remembers that geometry.
    -- @param geometry table  The roster geometry from addon:GetWorkbenchRosterGeometry.
    function splitter:Place(geometry)
        self.geometry = geometry
        self:ClearAllPoints()

        self:SetPoint(
            'TOPLEFT',
            parent,
            'TOPLEFT',
            geometry.sidebarWidth + (addon.WorkbenchLayout.splitGap - 10) / 2,
            -(geometry.top or 0)
        )

        self:SetSize(10, math.max(1, geometry.sidebarHeight))
        self:Show()
    end

    -- Moves the divider to a list-column width, clamped to the bounds, and stores the preference.
    -- @param value number  The wanted list-column width.
    -- @return boolean  True when the divider moved.
    function splitter:Resize(value)
        local geometry = self.geometry

        if not geometry or type(value) ~= 'number' or value ~= value then
            return false
        end

        local minimum, maximum = addon:GetWorkbenchSidebarBounds(geometry.width)
        value = math.floor(math.max(minimum, math.min(maximum, value)) + .5)

        if value == addon:GetWorkbenchSidebarWidth(geometry.width) then
            return false
        end

        local previous = addon:GetWorkbenchSidebarPreference()
        addon:SetWorkbenchSidebarPreference(value)
        changed(previous)
        return true
    end

    -- Returns the divider to its automatic position and notifies the owner.
    function splitter:Reset()
        local previous = addon:GetWorkbenchSidebarPreference()
        addon:SetWorkbenchSidebarPreference(nil)
        changed(previous)
    end

    -- Ends a divider drag and restores the resting look.
    local function stop()
        if not splitter.drag then
            return
        end

        splitter.drag = nil
        addon:SetUIScript(splitter, 'OnUpdate', nil)
        paint()
    end

    splitter.Stop = stop

    -- Starts a divider drag on a left press, polling the cursor every frame until the button is released.
    -- @param _ any  Unused.
    -- @param button string  The mouse button.
    addon:SetUIScript(splitter, 'OnMouseDown', function(_, button)
        if button ~= 'LeftButton' or not splitter.geometry or not GetCursorPosition then
            return
        end

        local x = GetCursorPosition()
        splitter.drag = { x = x, width = splitter.geometry.sidebarWidth }
        paint()

        -- Per-frame drag poll: resizes the list column to follow the cursor, and ends the drag when the left button is
        -- released.
        addon:SetUIScript(splitter, 'OnUpdate', function()
            local drag = splitter.drag

            if not drag then
                return
            end

            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
                stop()
                return
            end

            local current = GetCursorPosition()
            local scale = splitter:GetEffectiveScale() or 1
            splitter:Resize(drag.width + (current - drag.x) / (scale > 0 and scale or 1))
        end)
    end)

    addon:SetUIScript(splitter, 'OnMouseUp', stop)
    addon:SetUIScript(splitter, 'OnHide', stop)

    addon:SetUIScript(splitter, 'OnDoubleClick', function()
        stop()
        splitter:Reset()
    end)

    addon:SetUIScript(splitter, 'OnEnter', function()
        splitter.hover = true
        paint()

        if GameTooltip then
            GameTooltip:SetOwner(splitter, 'ANCHOR_RIGHT')
            GameTooltip:SetText(L['Drag to resize the list. Double-click to reset.'], 1, 1, 1, 1, true)
        end
    end)

    addon:SetUIScript(splitter, 'OnLeave', function()
        splitter.hover = nil
        paint()

        if GameTooltip and GameTooltip:IsOwned(splitter) then
            GameTooltip:Hide()
        end
    end)

    paint()
    return splitter
end

-- Places same-row controls left to right within their parent, sharing the row width evenly. A control never shrinks
-- below `minimum`; when the row cannot hold them all, it wraps onto further lines.
-- @param controls Frame[]  The controls to place.
-- @param x number  The left offset.
-- @param y number  The top offset.
-- @param width number  The row width.
-- @param options table|nil  gap (default 4), pitch (line height, default 28), minimum (least control width, default 1),
--   columns (most per line) and text (pixels to take off each caption's width).
-- @return number  The height used; 0 with no controls.
-- @return number|nil  The width given to each control.
-- @return number|nil  The number of controls per line.
function addon:LayoutWorkbenchRow(controls, x, y, width, options)
    options = options or {}
    local gap = options.gap or 4
    local pitch = options.pitch or 28
    local count = #controls

    if count == 0 then
        return 0
    end

    local minimum = options.minimum or 1
    local columns = math.max(1, math.min(count, math.floor((width + gap) / (minimum + gap))))

    if options.columns then
        columns = math.max(1, math.min(columns, options.columns))
    end

    local each = math.max(1, (width - (columns - 1) * gap) / columns)

    for index, control in ipairs(controls) do
        local column = (index - 1) % columns
        local line = math.floor((index - 1) / columns)
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', x + column * (each + gap), -(y + line * pitch))
        control:SetWidth(each)

        if options.text then
            local label = control.GetFontString and control:GetFontString()

            if label then
                label:SetWidth(math.max(1, each - options.text))
            end
        end
    end

    return math.ceil(count / columns) * pitch, each, columns
end

-- Fits an in-pane confirmation prompt: it keeps its designed width but never exceeds the pane it covers.
-- @param frame Frame  The prompt frame.
-- @param owner Frame|nil  The pane it covers.
-- @param preferred number  The designed width.
-- @return number  The width used.
function addon:FitWorkbenchPrompt(frame, owner, preferred)
    local available = owner and owner.GetWidth and owner:GetWidth() or preferred
    local width = math.max(1, math.min(preferred, (available or preferred) - 16))
    frame:SetWidth(width)
    return width
end

-- Places a value `field` and its check box `option` on one line when `width` allows, otherwise stacks the option under
-- the field. This is the shared value-field/checkbox geometry for cards and settings. Labels remain outside this
-- region; a wrapped option starts exactly under the value field.
-- @param field Frame  The value field.
-- @param option Button  The check box.
-- @param parent Frame  The frame both are placed in.
-- @param x number  The left offset.
-- @param y number  The top offset.
-- @param width number  The width available.
-- @param minimum number|nil  The least field width for the inline layout; defaults to 200.
-- @return number  The height used.
-- @return number  The field width.
-- @return boolean  True when the option went inline.
function addon:LayoutWorkbenchFieldOption(field, option, parent, x, y, width, minimum)
    local label = option:GetFontString()
    local desired = math.ceil(label:GetStringWidth()) + 26
    local optionWidth = math.min(width, desired)
    local inline = width >= desired + (minimum or 200) + 8
    local inputWidth = inline and width - desired - 8 or width
    field:SetParent(parent)
    field:ClearAllPoints()
    field:SetPoint('TOPLEFT', x, -y)
    field:SetWidth(inputWidth)
    option:SetParent(parent)
    option:ClearAllPoints()
    option:SetPoint('TOPLEFT', inline and x + inputWidth + 8 or x, inline and -y or -y - 28)
    option:SetWidth(optionWidth)
    label:SetWidth(math.max(1, optionWidth - 22))
    label:SetWordWrap(true)
    local optionHeight = math.max(24, label:GetStringHeight())
    option:SetHeight(optionHeight)
    return inline and math.max(24, optionHeight) or 28 + optionHeight, inputWidth, inline
end

-- Lays out a spell condition field group (icon, spell input and optional rank) inside `content`. The old condition
-- declaration adapter retains widget ownership, while all sizing uses the same native rule as action cards and settings
-- fields.
-- @param content Frame  The group's content frame.
-- @param children table[]  { icon, spell, rank } widgets; rank is optional.
-- @return number  The height used; 0 when the icon or the spell input is missing.
function addon:LayoutWorkbenchSpellGroup(content, children)
    local icon, spell, rank = children[1], children[2], children[3]

    if not icon or not spell then
        return 0
    end

    local width = math.max(1, content:GetWidth() - 44)
    local height, inputWidth
    icon.frame:SetParent(content)
    icon.frame:ClearAllPoints()
    icon.frame:SetPoint('TOPLEFT', 0, 0)
    icon.frame:SetSize(40, 40)

    if rank then
        height, inputWidth = self:LayoutWorkbenchFieldOption(spell.frame, rank.frame, content, 44, 6, width)
    else
        spell.frame:SetParent(content)
        spell.frame:ClearAllPoints()
        spell.frame:SetPoint('TOPLEFT', 44, -6)
        spell.frame:SetWidth(width)
        height, inputWidth = 24, width
    end

    spell:SetWidth(inputWidth)
    height = math.max(44, height + 6)

    if content.obj and content.obj.LayoutFinished then
        content.obj:LayoutFinished(nil, height)
    end

    return height
end

-- Attaches editable combobox suggestions to an edit box, using the flat selector shared with tags. The edit retains its
-- ordinary parser/commit handlers, so typed new values work.
-- @param form table  The settings form; the menu is released through form.cleanups, and form.edits records are marked
--   clean on a pick.
-- @param input EditBox  The edit box.
-- @param entries table[]|function  The suggestions ({ text, ... }), or a function returning them.
-- @param changed function  Called with the picked value.
-- @param valid function|nil  Returns false once the owner withdrew the menu; nil means always valid.
-- @return table  The suggestion menu.
function addon:AttachWorkbenchEditSuggestions(form, input, entries, changed, valid)
    local menu = input.suggestions or self:CreateWorkbenchSelector()
    input.suggestions = menu

    -- True while the owner has not withdrawn the menu (no validity check means always).
    -- @return boolean  True when the menu may act.
    local function alive()
        return not valid or valid()
    end

    -- Opens the suggestion menu with the entries that contain the typed text; hides it when none match.
    -- @param all boolean|nil  True lists every entry regardless of the typed text.
    local function suggest(all)
        if not alive() or not input:IsEnabled() then
            menu:Hide()
            return
        end

        local query = all and '' or (input:GetText() or ''):lower()
        local matches = {}
        local values = type(entries) == 'function' and entries() or entries

        for _, entry in ipairs(values or {}) do
            if tostring(entry.text):lower():find(query, 1, true) then
                matches[#matches + 1] = entry
            end
        end

        if #matches == 0 then
            menu:Hide()
            return
        end

        menu:Open(
            input,
            matches,
            input:GetText(),
            -- Picks a suggestion: writes it into the edit box, marks its record clean, reports it and drops focus.
            -- @param value string  The chosen suggestion's value.
            function(value)
                if not alive() then
                    return
                end

                input:SetText(value)
                input:SetTextColor(1, 1, 1)

                for _, record in ipairs(form.edits or {}) do
                    if record.control == input then
                        record.dirty = false
                        record.baseline = tostring(value)
                    end
                end

                changed(value)
                input:ClearFocus()
            end,
            alive,
            true
        )
    end

    for _, event in ipairs({ 'OnTextChanged', 'OnEditFocusGained' }) do
        local previous = input:GetScript(event)

        self:SetUIScript(input, event, function(control, user, ...)
            if previous then
                previous(control, user, ...)
            end
            if event == 'OnEditFocusGained' or user then
                suggest(event == 'OnEditFocusGained')
            end
        end)
    end

    for _, event in ipairs({ 'OnEscapePressed', 'OnEnterPressed' }) do
        local previous = input:GetScript(event)

        self:SetUIScript(input, event, function(...)
            menu:Hide()

            if previous then
                return previous(...)
            end
        end)
    end

    form.cleanups[#form.cleanups + 1] = function()
        menu:Release()
    end

    return menu
end
