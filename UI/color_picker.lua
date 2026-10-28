-- Workbench color picker: a small popup with a saturation/value square, hue and alpha sliders and exact 0 to 1 entry
-- boxes. It edits one color at a time through the callbacks given to picker:Open and never stores the color itself;
-- cancel, close and a hidden window all restore the original color through the change callback.
-- Loaded from RotationMaster.toc just before UI/tag_picker.lua; the tag picker, the settings form swatches and the
-- rotation effect fields each create their own picker with addon:CreateWorkbenchColorPicker. It uses the controls from
-- UI/controls.lua and registers with the window registry (UI/window.lua) through addon:OpenPopup.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Converts hue, saturation and value to red, green and blue.
-- @param h number  The hue, 0 to 1.
-- @param s number  The saturation, 0 to 1.
-- @param v number  The value (brightness), 0 to 1.
-- @return number  The red channel, 0 to 1.
-- @return number  The green channel, 0 to 1.
-- @return number  The blue channel, 0 to 1.
local function hsv(h, s, v)
    local sector = h * 6
    local i = math.floor(sector)
    local f = sector - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    i = i % 6

    if i == 0 then
        return v, t, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, t
    elseif i == 3 then
        return p, q, v
    elseif i == 4 then
        return t, p, v
    else
        return v, p, q
    end
end

-- Inverse of hsv: converts red, green and blue to hue, saturation and value. Hue is 0 for a gray.
-- @param r number  The red channel, 0 to 1.
-- @param g number  The green channel, 0 to 1.
-- @param b number  The blue channel, 0 to 1.
-- @return number  The hue, 0 to 1.
-- @return number  The saturation, 0 to 1.
-- @return number  The value (brightness), 0 to 1.
local function rgb(r, g, b)
    local hi, lo = math.max(r, g, b), math.min(r, g, b)
    local d = hi - lo
    local h = 0

    if d > 0 then
        if hi == r then
            h = ((g - b) / d) % 6
        elseif hi == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end

        h = h / 6
    end

    return h, hi == 0 and 0 or d / hi, hi
end

-- Builds a hidden picker popup centered on `parent`. The caller keeps one picker per owner and drives it with
-- picker:Open(color, change, valid, anchor).
-- @param parent Frame  The frame the popup is first centered on.
-- @return table  The picker { frame, Open(color, change, valid, anchor), Close(acceptChanges), Choose(h, s, v, a),
--   FlushNumbers() }.
--
-- `change(r, g, b, a, final)` is called live, and `valid()` must return false once the owner's drawing is gone so a
-- late event cannot write into a stale control.
function addon:CreateWorkbenchColorPicker(parent)
    local picker = { frame = CreateFrame('Frame', nil, UIParent), h = 0, s = 0, v = 1, a = 1 }
    local frame = picker.frame
    frame:SetSize(270, 244)
    frame:SetPoint('CENTER', parent, 'CENTER')
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    addon:MakeWindowOpaque(frame)
    local square = CreateFrame('Button', nil, frame)
    picker.square = square
    square:SetPoint('TOPLEFT', 12, -30)
    square:SetSize(180, 150)
    local base = square:CreateTexture(nil, 'ARTWORK', nil, 0)
    base:SetAllPoints(square)

    for index, name in ipairs({ 'color-saturation', 'color-value' }) do
        local texture = square:CreateTexture(nil, 'ARTWORK', nil, index)
        texture:SetAllPoints(square)
        texture:SetTexture(addon:ControlTexture(name))
    end

    local marker = square:CreateTexture(nil, 'OVERLAY')
    marker:SetTexture(addon:ControlTexture('center'))
    marker:SetSize(12, 12)
    local hue = addon:CreateWorkbenchSlider(frame, 0, 1, .001, 180)
    hue:SetPoint('TOPLEFT', 12, -190)
    local spectrum = hue:CreateTexture(nil, 'BACKGROUND')
    spectrum:SetAllPoints(hue)
    spectrum:SetTexture(addon:ControlTexture('color-hue'))
    local alpha = addon:CreateWorkbenchSlider(frame, 0, 1, .001, 180)
    alpha:SetPoint('TOPLEFT', 12, -218)
    local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    title:SetPoint('TOPLEFT', 12, -8)
    title:SetText(L['Color'])
    picker.numeric = {}

    -- Builds the numeric entry box paired with a slider.
    -- @param slider Slider  The slider this box mirrors; FlushNumbers writes the parsed value to it.
    -- @param key string  The picker field the box edits: 'h' (hue) or 'a' (alpha).
    -- @param prefix string  The short caption drawn inside the box.
    -- @param y number  The vertical offset below the top of the picker.
    -- @return EditBox  The new entry box.
    --
    -- Typing only marks the box dirty; the value is parsed and applied when Enter or the accept button runs
    -- FlushNumbers, so a half-typed number never moves the color.
    local function rawSlider(slider, key, prefix, y)
        local c = addon:CreateWorkbenchEditBox(frame)
        c:SetPoint('TOPLEFT', 210, -y)
        c:SetSize(52, 22)
        c:SetTextInsets(13, 2, 0, 0)
        local caption = c:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        caption:SetPoint('LEFT', 2, 0)
        caption:SetText(prefix)
        picker.numeric[key] = { control = c, slider = slider, dirty = false }

        addon:SetUIScript(c, 'OnTextChanged', function(_, user)
            if user and picker.valid and picker.valid() then
                picker.numeric[key].dirty = true
            end
        end)

        addon:SetUIScript(c, 'OnEnterPressed', function()
            if c:GetText() ~= string.format('%.3f', picker[key]) then
                picker.numeric[key].dirty = true
            end

            if picker:FlushNumbers() then
                c:ClearFocus()
            end
        end)

        addon:SetUIScript(c, 'OnEscapePressed', function()
            picker.numeric[key].dirty = false
            c:SetText(string.format('%.3f', picker[key]))
            c:SetTextColor(1, 1, 1)
            c:ClearFocus()
        end)

        return c
    end

    picker.hueValue = rawSlider(hue, 'h', 'H', 185)
    picker.alphaValue = rawSlider(alpha, 'a', 'A', 213)
    local close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
    close:SetPoint('TOPRIGHT', -6, -6)
    local accept = addon:CreateWorkbenchIconButton(frame, 'check', L['Use color'])
    accept:SetPoint('TOPRIGHT', -28, -6)
    local cancel = addon:CreateWorkbenchIconButton(frame, 'undo', L['Cancel'])
    cancel:SetPoint('TOPRIGHT', -6, -30)

    -- Applies every dirty entry box.
    -- @return boolean  False (and the box is reddened) when a value is not a number from 0 to 1, or when the picker is
    --   no longer valid; true when there was nothing wrong, including nothing to apply.
    function picker:FlushNumbers()
        if not self.valid or not self.valid() then
            return false
        end

        local nextValues = { h = self.h, a = self.a }
        local dirty = false

        for key, record in pairs(self.numeric) do
            if record.dirty then
                local n = tonumber(record.control:GetText())

                if not n or n ~= n or n < 0 or n > 1 then
                    record.control:SetTextColor(1, .35, .35)
                    return false
                end

                nextValues[key] = n
                dirty = true
            end
        end

        if dirty then
            self.loading = true

            for key, record in pairs(self.numeric) do
                record.slider:SetValue(nextValues[key])
            end

            self.loading = false
            self:Choose(nextValues.h, self.s, self.v, nextValues.a)
        end

        return true
    end

    -- Sets the color from hue, saturation, value and alpha, refreshes the square, marker and entry boxes, and reports
    -- the result as RGB through the owner's change callback.
    -- @param h number  The hue; clamped to 0 to 1.
    -- @param s number  The saturation; clamped to 0 to 1.
    -- @param v number  The value (brightness); clamped to 0 to 1.
    -- @param a number  The alpha; clamped to 0 to 1.
    --
    -- Does nothing when the picker is no longer valid.
    function picker:Choose(h, s, v, a)
        if not self.valid or not self.valid() then
            return
        end

        self.h, self.s, self.v, self.a =
            math.max(0, math.min(1, h)),
            math.max(0, math.min(1, s)),
            math.max(0, math.min(1, v)),
            math.max(0, math.min(1, a))

        for _, record in pairs(self.numeric) do
            record.dirty = false
        end

        self.hueValue:SetText(string.format('%.3f', self.h))
        self.alphaValue:SetText(string.format('%.3f', self.a))
        self.hueValue:SetTextColor(1, 1, 1)
        self.alphaValue:SetTextColor(1, 1, 1)
        local br, bg, bb = hsv(self.h, 1, 1)
        base:SetColorTexture(br, bg, bb, 1)
        marker:ClearAllPoints()
        marker:SetPoint('CENTER', square, 'TOPLEFT', self.s * square:GetWidth(), -(1 - self.v) * square:GetHeight())
        local r, g, b = hsv(self.h, self.s, self.v)
        self.change(r, g, b, self.a)
    end

    -- Picks the color under the mouse cursor in the square; ignored when the cursor APIs are missing or the picker is
    -- no longer valid.
    local function sample()
        if not GetCursorPosition or not square.GetLeft or not picker.valid or not picker.valid() then
            return
        end

        local x, y = GetCursorPosition()
        local scale = square:GetEffectiveScale()
        local left, top = square:GetLeft(), square:GetTop()

        if not left or not top then
            return
        end

        picker:Choose(
            picker.h,
            (x / scale - left) / square:GetWidth(),
            1 - (top - y / scale) / square:GetHeight(),
            picker.a
        )
    end

    addon:SetUIScript(square, 'OnMouseDown', function(_, button)
        if button == 'LeftButton' then
            picker.dragging = true
            sample()
        end
    end)

    addon:SetUIScript(square, 'OnMouseUp', function()
        picker.dragging = false
    end)

    addon:SetUIScript(square, 'OnUpdate', function()
        if picker.dragging then
            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
                picker.dragging = false
            else
                sample()
            end
        end
    end)

    addon:SetUIScript(hue, 'OnValueChanged', function(_, value)
        if not picker.loading then
            picker:Choose(value, picker.s, picker.v, picker.a)
        end
    end)

    addon:SetUIScript(alpha, 'OnValueChanged', function(_, value)
        if not picker.loading then
            picker:Choose(picker.h, picker.s, picker.v, value)
        end
    end)

    -- Hides the picker. Only an accepted close keeps the color; the OnHide handler restores the original otherwise.
    -- @param acceptChanges boolean|nil  True to keep the chosen color.
    function picker:Close(acceptChanges)
        self.accepted = acceptChanges == true
        frame:Hide()
    end

    addon:SetUIScript(accept, 'OnClick', function()
        if picker:FlushNumbers() then
            picker:Close(true)
        end
    end)

    addon:SetUIScript(close, 'OnClick', function()
        picker:Close(false)
    end)

    addon:SetUIScript(cancel, 'OnClick', function()
        picker:Close(false)
    end)

    -- Any hide that was not an accept (cancel, close, Escape, the window registry) puts the original color back, with
    -- the final flag set, and drops the owner's callbacks.
    addon:SetUIScript(frame, 'OnHide', function()
        if not picker.accepted and picker.valid and picker.valid() then
            picker.change(picker.original[1], picker.original[2], picker.original[3], picker.original[4], true)
        end

        picker.dragging = false
        picker.valid = nil
        picker.change = nil
    end)

    -- Shows the picker centered on `anchor` for `color`. The previous owner's callbacks are replaced.
    -- @param color table{r=number,g=number,b=number,a=number}  The starting color; it is also what cancel restores.
    -- @param change function  Receives live updates (r, g, b, a) and the restore on cancel (with a final flag); gated
    --   by `valid`.
    -- @param valid function  Returns true while the owner's drawing is current; returns false once a late event must be
    --   ignored.
    -- @param anchor Frame|nil  The frame to center on; nil means the screen.
    function picker:Open(color, change, valid, anchor)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchor or UIParent, "CENTER", 0, 0)
        self.accepted = false
        self.original = { color.r, color.g, color.b, color.a }
        self.valid = valid
        self.change = change
        self.h, self.s, self.v = rgb(color.r, color.g, color.b)
        self.a = color.a

        for _, record in pairs(self.numeric) do
            record.dirty = false
        end

        self.hueValue:SetText(string.format('%.3f', self.h))
        self.alphaValue:SetText(string.format('%.3f', self.a))
        self.loading = true
        hue:SetValue(self.h)
        alpha:SetValue(self.a)
        self.loading = false
        local r, g, b = hsv(self.h, 1, 1)
        base:SetColorTexture(r, g, b, 1)
        marker:ClearAllPoints()
        marker:SetPoint('CENTER', square, 'TOPLEFT', self.s * 180, -(1 - self.v) * 150)
        frame:Show()
        addon:OpenPopup(self, anchor or parent)
    end

    frame:Hide()
    return picker
end
