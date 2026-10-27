local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

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
            if user and picker.valid and picker.valid() then picker.numeric[key].dirty = true end
        end)

        addon:SetUIScript(c, 'OnEnterPressed', function()
            if c:GetText() ~= string.format('%.3f', picker[key]) then picker.numeric[key].dirty = true end
            if picker:FlushNumbers() then c:ClearFocus() end
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

    function picker:FlushNumbers()
        if not self.valid or not self.valid() then return false end
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

    function picker:Choose(h, s, v, a)
        if not self.valid or not self.valid() then return end

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

    local function sample()
        if not GetCursorPosition or not square.GetLeft or not picker.valid or not picker.valid() then return end
        local x, y = GetCursorPosition()
        local scale = square:GetEffectiveScale()
        local left, top = square:GetLeft(), square:GetTop()
        if not left or not top then return end

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

    addon:SetUIScript(square, 'OnMouseUp', function() picker.dragging = false end)

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
        if not picker.loading then picker:Choose(value, picker.s, picker.v, picker.a) end
    end)

    addon:SetUIScript(alpha, 'OnValueChanged', function(_, value)
        if not picker.loading then picker:Choose(picker.h, picker.s, picker.v, value) end
    end)

    function picker:Close(acceptChanges)
        self.accepted = acceptChanges == true
        frame:Hide()
    end

    addon:SetUIScript(accept, 'OnClick', function()
        if picker:FlushNumbers() then picker:Close(true) end
    end)

    addon:SetUIScript(close, 'OnClick', function() picker:Close(false) end)
    addon:SetUIScript(cancel, 'OnClick', function() picker:Close(false) end)

    addon:SetUIScript(frame, 'OnHide', function()
        if not picker.accepted and picker.valid and picker.valid() then
            picker.change(picker.original[1], picker.original[2], picker.original[3], picker.original[4], true)
        end

        picker.dragging = false
        picker.valid = nil
        picker.change = nil
    end)

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
