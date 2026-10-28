-- External frame primitives only; layout ownership and navigation stay real.
return function(env)
    local frames = {}

    local function create(kind, name, parent, template)
        local frame = {
            kind = kind,
            name = name,
            parent = parent,
            template = template,
            scripts = {},
            width = 100,
            height = 100,
            visible = true,
            alpha = 1,
        }

        if kind == 'EditBox' and os.getenv('RM_FONT_TRACE') then
            frame.createdAt = debug.traceback('', 2)
        end

        function frame:SetSize(width, height)
            self.width, self.height = width, height

            if self.scripts.OnSizeChanged then
                self.scripts.OnSizeChanged(self, width, height)
            end
        end

        function frame:SetWidth(value)
            self:SetSize(value, self.height)
        end

        function frame:SetHeight(value)
            self:SetSize(self.width, value)
        end

        function frame:GetWidth()
            return self.width
        end

        function frame:GetHeight()
            return self.height
        end

        function frame:SetScale(value)
            self.scale = value
        end

        function frame:GetScale()
            return self.scale or 1
        end

        function frame:SetFontString(value)
            self.fontString = value
        end

        function frame:SetPoint(...)
            local point = { ... }
            self.point = point
            self.points = self.points or {}

            for index, anchor in ipairs(self.points) do
                if anchor[1] == point[1] then
                    self.points[index] = point
                    return
                end
            end

            self.points[#self.points + 1] = point
        end

        function frame:ClearAllPoints()
            self.point = nil
            self.points = nil
        end

        function frame:GetNumPoints()
            return self.points and #self.points or 0
        end

        function frame:GetPoint(index)
            local point = self.points and self.points[index or 1]
            assert(point, 'Frame:GetPoint(): point index out of bounds')
            return unpack(point)
        end

        function frame:SetAllPoints(owner)
            self.allPoints = owner
        end

        function frame:SetParent(owner)
            self.parent = owner
        end

        function frame:GetParent()
            return self.parent
        end

        function frame:SetFrameStrata(value)
            self.strata = value
        end

        function frame:GetFrameStrata()
            return self.strata or 'MEDIUM'
        end

        function frame:SetFrameLevel(value)
            self.level = value
        end

        function frame:GetFrameLevel()
            return self.level or 0
        end

        function frame:Raise()
            self.raised = true
        end

        function frame:IsShown()
            return self.visible
        end

        function frame:SetMovable() end
        function frame:SetResizable() end

        function frame:SetResizeBounds(...)
            self.resizeBounds = { ... }
        end

        function frame:SetClampedToScreen() end
        function frame:SetToplevel() end

        function frame:EnableMouse(value)
            self.mouseEnabled = value
        end

        function frame:EnableKeyboard(value)
            self.keyboardEnabled = value
        end

        function frame:SetAltArrowKeyMode(value)
            self.altArrowKeyMode = value
        end

        function frame:SetCountInvisibleLetters(value)
            self.countInvisibleLetters = value
        end

        function frame:SetBlinkSpeed(value)
            self.blinkSpeed = value
        end

        function frame:HasFocus()
            return self.focused == true
        end

        function frame:SetPropagateKeyboardInput() end

        function frame:RegisterForDrag(...)
            self.drags = { ... }
        end

        function frame:RegisterForClicks(...)
            self.clicks = { ... }
        end

        function frame:HasScript(event)
            return event ~= 'OnClick' or self.kind == 'Button' or self.kind == 'CheckButton'
        end

        function frame:SetScript(event, callback)
            assert(self:HasScript(event), 'Frame:SetScript(): Does not have ' .. event)
            self.scripts[event] = callback
        end

        function frame:HookScript(event, callback)
            self.hooks = self.hooks or {}
            self.hooks[event] = self.hooks[event] or {}
            table.insert(self.hooks[event], callback)
        end

        function frame:GetScript(event)
            assert(self:HasScript(event), 'Frame:GetScript(): Does not have ' .. event)
            return self.scripts[event]
        end

        function frame:StartMoving() end
        function frame:StopMovingOrSizing() end
        function frame:StartSizing() end

        function frame:Show()
            local changed = not self.visible
            self.visible = true

            if changed and self.scripts.OnShow then
                self.scripts.OnShow(self)
            end
        end

        function frame:Hide()
            local changed = self.visible
            self.visible = false

            if changed and self.scripts.OnHide then
                self.scripts.OnHide(self)
            end
        end

        function frame:Click()
            if self.enabled ~= false and self.scripts.OnClick then
                self.scripts.OnClick(self)
            end
        end

        -- The client's rule: a FontString (and an EditBox) must have a font
        -- before it can show, measure or format text. A template or
        -- :SetFontObject(object) gives it one; :SetFont(path,size,flags) gives
        -- it one only when the path and size are usable (the client refuses
        -- a bad one with false and leaves the old font, or none).
        local fontRules = { FontString = true, EditBox = true }

        local function needFont(self, method)
            if fontRules[self.kind] and not self.fontState then
                -- RM_FONT_TRACE=1 appends the call stack, to find who built it.
                local stack = os.getenv('RM_FONT_TRACE')
                    and ('\ncreated at' .. tostring(self.createdAt) .. '\nused at' .. debug.traceback('', 3))
                    or ''

                error(self.kind .. ':' .. method .. '(): Font not set' .. stack, 3)
            end
        end

        function frame:SetText(value)
            needFont(self, 'SetText')
            self.text = value
        end

        function frame:SetFormattedText(format, ...)
            needFont(self, 'SetFormattedText')
            self.text = string.format(format, ...)
        end

        function frame:GetText()
            return self.text
        end

        function frame:SetTextColor(...)
            self.textColor = { ... }
        end

        function frame:SetFontObject(object)
            if object ~= nil then
                self.fontObject = object
                self.fontState = { path = 'Fonts\\FRIZQT__.TTF', size = 12, flags = '' }
            end
        end

        function frame:SetFont(path, size, flags)
            if type(path) == 'string' and path ~= '' and type(size) == 'number' and size > 0 then
                self.fontState = { path = path, size = size, flags = flags or '' }
                return true
            end

            return false
        end

        function frame:GetFont()
            local font = self.fontState

            if font then
                return font.path, font.size, font.flags
            end
        end

        function frame:SetAutoFocus(value)
            self.autoFocus = value
        end

        function frame:SetMultiLine(value)
            self.multiLine = value
        end

        function frame:SetMaxLetters(value)
            self.maxLetters = value
        end

        function frame:GetMaxLetters()
            return self.maxLetters or 0
        end

        function frame:SetTextInsets(...)
            self.textInsets = { ... }
        end

        function frame:SetFocus()
            self.focused = true
        end

        function frame:SetCursorPosition(value)
            self.cursor = value
        end

        function frame:GetCursorPosition()
            return self.cursor or #(self.text or "")
        end

        function frame:HighlightText(first, last)
            self.selection = { first, last }
        end

        function frame:GetEffectiveScale()
            return self.scale or 1
        end

        function frame:SetRotation(value)
            self.rotation = value
        end

        function frame:SetOrientation(value)
            self.orientation = value
        end

        function frame:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end

        function frame:GetValue()
            return self.value or 0
        end

        function frame:GetScrollChild()
            return self.scrollChild
        end

        function frame:SetValueStep(value)
            self.valueStep = value
        end

        function frame:SetValue(value)
            self.value = math.max(self.minimum or value, math.min(self.maximum or value, value))

            if self.scripts.OnValueChanged then
                self.scripts.OnValueChanged(self, self.value)
            end

            for _, callback in ipairs(self.hooks and self.hooks.OnValueChanged or {}) do
                callback(self, self.value)
            end
        end

        function frame:SetThumbTexture(value)
            self.thumb = value
        end

        function frame:SetHorizontalScroll(value)
            self.horizontalScroll = value
        end

        function frame:EnableMouseWheel() end

        function frame:ClearFocus()
            self.focused = false
        end

        function frame:Enable()
            self.enabled = true

            if self.scripts.OnEnable then
                self.scripts.OnEnable(self)
            end
        end

        function frame:IsEnabled()
            return self.enabled ~= false
        end

        function frame:Disable()
            self.enabled = false

            if self.scripts.OnDisable then
                self.scripts.OnDisable(self)
            end
        end

        function frame:SetScrollChild(child)
            self.scrollChild = child
        end

        function frame:UpdateScrollChildRect() end

        function frame:SetVerticalScroll(value)
            self.scrollOffset = value
        end

        function frame:SetWordWrap(value)
            self.wordWrap = value
        end

        function frame:SetMaxLines(value)
            self.maxLines = value
        end

        function frame:GetStringHeight()
            needFont(self, 'GetStringHeight')
            local lines = 0

            for part in ((self.text or '') .. '\n'):gmatch('(.-)\n') do
                lines = lines + math.max(1, math.ceil(#part / math.max(1, (self.width or 100) / 7)))
            end

            if self.maxLines and self.maxLines > 0 then
                lines = math.min(lines, self.maxLines)
            end

            return math.max(12, lines * 12)
        end

        function frame:SetAlpha(value)
            self.alpha = value
        end

        function frame:GetAlpha()
            return self.alpha
        end

        function frame:SetColorTexture(...)
            self.color = { ... }
        end

        function frame:SetTexture(value)
            self.texture = value
        end

        function frame:GetTexture()
            return self.texture
        end

        function frame:SetTexCoord(...)
            self.texCoord = { ... }
        end

        function frame:SetVertexColor(...)
            self.color = { ... }
        end

        function frame:SetJustifyH() end

        function frame:SetJustifyV(value)
            self.justifyV = value
        end

        function frame:GetStringWidth()
            needFont(self, 'GetStringWidth')
            return #(self.text or '') * 7
        end

        function frame:CreateTexture()
            return create('Texture', nil, self)
        end

        function frame:CreateFontString(name, layer, template)
            local fontString = create('FontString', name, self, template)

            if template ~= nil then
                fontString.fontState = { path = 'Fonts\\FRIZQT__.TTF', size = 12, flags = '' }
            elseif os.getenv('RM_FONT_TRACE') then
                fontString.createdAt = debug.traceback('', 2)
            end

            return fontString
        end

        function frame:GetFontString()
            if not self.fontString then
                self.fontString = self:CreateFontString(nil, nil, 'GameFontNormal')
            end

            self.fontString:SetText(self.text or '')
            return self.fontString
        end

        frames[#frames + 1] = frame
        return frame
    end

    -- The stock font object the editors and probes use by global.
    env.ChatFontNormal = env.ChatFontNormal or {}
    env.CreateFrame = create
    env.UIParent = create('Frame')
    return frames, create
end
