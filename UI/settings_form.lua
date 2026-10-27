-- The native settings form: one pooled page object (created by addon:CreateSettingsForm) that every settings page,
-- popup and transfer dialog draws into. A page supplies a builder that calls row methods (Edit, Check, Choice, Slider,
-- Color, Reference, Position, ...) in order; Draw replays the builder from scratch, so controls are pooled per kind and
-- every callback is wrapped in Guard, which drops it when the drawing, the profile, global or character table it
-- belongs to has changed. Edits stay in text boxes until FlushEdits parses and commits them. Row methods place values
-- at x = 220 and register them for the label-column scope. Game items and spells are looked up through reference
-- providers and the cursor is read only through Platform:CanReadValue (restricted clients). Other UI/settings_*.lua
-- files add methods through the Install* calls at the bottom; this file is loaded after all of them. It saves nothing
-- itself.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Creates a small left-aligned, vertically centered caption font string on parent.
local function label(parent)
    local t = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    t:SetJustifyH('LEFT')
    t:SetJustifyV('MIDDLE')
    return t
end

-- Default parse function for an Edit field: the text is the value.
local function identity(text)
    return text
end

-- A private, pooled native form. Existing addon setting shapes stay outside
-- this view; every callback belongs to one drawing and one database identity.
function addon:CreateSettingsForm(parent)
    local p = {
        frame = addon:TrackWorkbenchSize(CreateFrame('Frame', nil, parent)),
        pool = {},
        counts = {},
        fields = {},
        edits = {},
        cleanups = {},
        active = false,
        generation = 0,
        isSettingsForm = true,
    }

    p.frame:SetAllPoints(parent)
    p.scroll = addon:CreateWorkbenchScrollFrame(p.frame)
    p.scroll:SetPoint('TOPLEFT', 8, -8)
    p.child = CreateFrame('Frame', nil, p.scroll)
    p.scroll:SetScrollChild(p.child)
    p.message = label(p.frame)
    p.message:SetPoint('BOTTOMLEFT', 8, 4)
    p.message:SetTextColor(1, .5, .3)
    p.message:SetHeight(20)

    -- ============================================================================
    -- Validity, help and guards
    -- ============================================================================

    -- True while the form is open for generation token and the profile, global and character tables are the ones it was
    -- opened against. Every deferred callback checks this; a redraw or a profile switch makes older callbacks inert.
    function p:Valid(token)
        return self.active
            and token == self.generation
            and self.profile == addon.db.profile
            and self.global == addon.db.global
            and self.char == addon.db.char
    end

    -- Wraps callback so it runs only while this drawing is current (through GuardWorkbenchHelp when available).
    function p:HelpGuard(callback)
        local token = self.generation

        -- True while the drawing this guard was made for is still current.
        local function valid()
            return self:Valid(token)
        end

        if addon.GuardWorkbenchHelp then return addon:GuardWorkbenchHelp(valid, callback) end

        return function(...)
            if valid() then return callback(...) end
        end
    end

    -- After a draw, gives every field a help brief: the first sentence of the page's authored help for that field key,
    -- else the control's tooltip, else a generic brief for its kind. The bindings are released by the next draw's
    -- cleanups.
    function p:BindHelpBriefs()
        if not addon.BindWorkbenchHelp then return end
        local token = self.generation
        local used = {}
        local authored = {}
        local inputs = {}

        for _, edit in ipairs(self.edits) do
            inputs[edit.control] = true
        end

        if self.settingsKey then
            for _, entry in ipairs(addon:WorkbenchPageHelp(self.settingsKey)) do
                if entry.id and type(entry.text) == 'string' then
                    authored[entry.id] = entry.text:match('^(.-[.!?])%s') or entry.text
                end
            end
        end

        for key, control in pairs(self.fields) do
            if not used[control] then
                used[control] = true
                local brief = authored[key] or control.tooltip

                if not brief then
                    brief = control.rmCheck and L['Help.Brief.check']
                        or inputs[control] and L['Help.Brief.edit']
                        or L['Help.Brief.control']
                end

                self.cleanups[#self.cleanups + 1] = addon:BindWorkbenchHelp(control, {
                    brief = brief,
                    valid = function() return self:Valid(token) end,
                })
            end
        end
    end

    -- Wraps callback for this drawing: it runs only while Valid, inside one settings-history step when history is
    -- installed, and afterwards re-enables or disables Apply from the draft's dirty state.
    function p:Guard(callback)
        local token = self.generation

        return function(...)
            if self:Valid(token) then
                local result

                if self.WithSettingsHistory then
                    result = self:WithSettingsHistory(callback, ...)
                else
                    result = callback(...)
                end

                if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then
                    if self:IsSettingsDraftDirty() then
                        self.fields.apply:Enable()
                    else
                        self.fields.apply:Disable()
                    end
                end

                return result
            end
        end
    end

    -- Returns the next pooled control of the given kind for this drawing, building it with build() on first use,
    -- reparenting it to the current surface and showing it. Draw resets the counts, so controls are reused in order.
    function p:Acquire(kind, build)
        self.counts[kind] = (self.counts[kind] or 0) + 1
        local i = self.counts[kind]
        self.pool[kind] = self.pool[kind] or {}
        local c = self.pool[kind][i]

        if not c then
            c = build()
            addon:TrackWorkbenchRegion(c)
            self.pool[kind][i] = c
        end

        if c.SetParent then c:SetParent(self.surface or self.child) end
        c:Show()
        return c
    end

    -- Shows a status line at the bottom of the form, in green when success, otherwise orange.
    function p:Message(text, success)
        self.message:SetText(text or '')
        self.message:SetTextColor(success and .35 or 1, success and .85 or .5, success and .45 or .3)
    end

    -- ============================================================================
    -- Rows and label columns
    -- ============================================================================

    -- Reserves a row of height (default 30) at the current y and returns its top; a non-empty caption gets a label in
    -- the label column and registers it with the open label scope.
    function p:Row(caption, height)
        local y = self.y
        self.y = y + (height or 30)

        if caption and caption ~= '' then
            local t = self:Acquire('labels', function() return label(self.child) end)
            t:ClearAllPoints()
            t:SetPoint('TOPLEFT', 0, -y)
            t:SetSize(212, (height or 30) - 4)
            t:SetWordWrap(true)
            t:SetText(caption)
            local scope = self.labelScope

            if scope then
                local row = { label = t, controls = 0 }
                scope.rows[#scope.rows + 1] = row
                self.labelRow = row
            end
        end

        return y
    end

    -- Label column. Builders place values at x=220 as before and register
    -- them; when a scope (the page, a column or a card) ends, its column is
    -- narrowed to its longest caption and the registered values move left and
    -- grow by the same amount. A scope with a caption row whose control the
    -- page placed itself, or with a value the page re-anchored, keeps 220 so
    -- its rows stay aligned.
    local function anchorOf(control)
        if not control.GetPoint or (control.GetNumPoints and control:GetNumPoints() < 1) then return end
        local point, a, b, c, d = control:GetPoint(1)
        if type(a) == 'number' then return point, a, b end
        return point, c, d
    end

    -- Opens a label-column scope (a page, column or card); scopes nest.
    function p:BeginLabelScope()
        self.labelScopes = self.labelScopes or {}
        self.labelScopes[#self.labelScopes + 1] = self.labelScope
        self.labelScope = { rows = {}, controls = {} }
        self.labelRow = nil
    end

    -- Registers a value control placed by a row so EndLabelScope can shift it left by dx times the saved column delta
    -- and widen it by dw times the delta. A control anchored anywhere but TOPLEFT marks the scope as custom, which
    -- keeps column 220.
    function p:LabelControl(control, dx, dw)
        local scope, row = self.labelScope, self.labelRow
        if not scope or not control then return control end
        local point, x, y = anchorOf(control)

        if point ~= 'TOPLEFT' or not x then
            scope.custom = true
            return control
        end

        -- A value laid out again (InlineCheck re-places its field) keeps one entry.
        for _, entry in ipairs(scope.controls) do
            if entry.control == control then
                entry.x, entry.y, entry.dx, entry.dw = x, y, dx or 1, dw or 0
                return control
            end
        end

        scope.controls[#scope.controls + 1] = { control = control, x = x, y = y, dx = dx or 1, dw = dw or 0 }
        if row then row.controls = row.controls + 1 end
        return control
    end

    -- Closes the innermost scope: narrows the label column to the longest caption (at most 220) and moves its
    -- registered controls to match. Does nothing, leaving the standard column, if any row has no registered control or
    -- the page moved a control itself. Returns the new column width, if changed.
    function p:EndLabelScope()
        local scope = self.labelScope
        self.labelScope = self.labelScopes and table.remove(self.labelScopes) or nil
        self.labelRow = nil
        if not scope or scope.custom or #scope.rows == 0 then return end
        local widest = 0

        for _, row in ipairs(scope.rows) do
            if row.controls == 0 then return end
            widest = math.max(widest, row.label:GetStringWidth())
        end

        for _, entry in ipairs(scope.controls) do
            local point, x, y = anchorOf(entry.control)
            if point ~= 'TOPLEFT' or x ~= entry.x or y ~= entry.y then return end
        end

        local column = math.max(60, math.min(220, math.ceil(widest) + 12))
        local delta = 220 - column
        if delta <= 0 then return end

        for _, row in ipairs(scope.rows) do
            row.label:SetWidth(column - 8)
        end

        for _, entry in ipairs(scope.controls) do
            local control = entry.control
            control:ClearAllPoints()
            control:SetPoint('TOPLEFT', entry.x - delta * entry.dx, entry.y)
            if entry.dw > 0 then control:SetWidth(control:GetWidth() + delta * entry.dw) end
        end

        scope.column = column
        return column
    end

    -- ============================================================================
    -- Text, buttons and actions
    -- ============================================================================

    -- Adds wrapped body text across the page width and returns it; advances y by its height.
    function p:Text(text)
        local t = self:Acquire('text', function() return label(self.child) end)
        t:ClearAllPoints()
        t:SetPoint('TOPLEFT', 0, -self.y)
        t:SetWidth(self.width)
        t:SetWordWrap(true)
        t:SetText(text or '')
        t:SetTextColor(.9, .92, .94)
        t:SetHeight(0)
        t:SetHeight(math.max(20, t:GetStringHeight()))
        self.y = self.y + t:GetHeight() + 8
        return t
    end

    -- Adds a header-styled text line; returns it.
    function p:Heading(text)
        local y = self.y
        local t = self:Text(text)
        addon:StyleWorkbenchHeader(t)
        t:SetHeight(0)
        t:SetHeight(math.max(20, t:GetStringHeight()))
        self.y = y + t:GetHeight() + 12
        return t
    end

    -- Adds a full-row button (optionally with icon) registered as field key. The click flushes pending edits and then
    -- calls action(), so an invalid input blocks it.
    function p:Button(key, text, action, icon)
        local y = self:Row(nil, 28)

        local c = self:Acquire(icon and 'iconButtons' or 'buttons', function()
            return icon and addon:CreateWorkbenchLabeledIconButton(self.child, icon, text, 210)
                or addon:CreateWorkbenchButton(self.child, text, 210)
        end)

        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 0, -y)
        c:SetWidth(math.max(160, math.min(self.width, 300)))
        c:SetText(text)
        if c.categoryIcon then c.categoryIcon:Hide() end
        if icon then c.icon:SetTexture(addon:ControlTexture(icon)) end
        self.fields[key] = c
        c:Enable()

        addon:SetUIScript(c, 'OnClick', self:Guard(function()
            if self:FlushEdits() then action() end
        end))

        return c
    end

    -- Adds the Apply and Cancel (Discard when pageDraft) buttons at the bottom right. Without pageDraft this is a
    -- creation form: the baseline state is captured for the unsaved check and Apply goes through ApplyCreation. With
    -- pageDraft Apply calls apply() after flushing, and Discard drops the settings draft and redraws.
    function p:CreationActions(apply, cancel, pageDraft)
        self.creationUsed = true
        self.creationUsedForNew = not pageDraft

        if not pageDraft then
            self.creationBaseline = self.creationBaseline or addon:CopySettingsData(self:CreationState())
            self.creationApply = apply
        end

        for _, entry in ipairs({
            { 'apply', L['Apply'], apply },
            { 'cancel', pageDraft and L['Discard'] or L['Cancel'], cancel },
        }) do
            local c = self:Acquire('creationButtons', function()
                return addon:CreateWorkbenchButton(self.frame, '', 92)
            end)

            c:SetParent(self.frame)
            c:ClearAllPoints()
            c:SetPoint('BOTTOMRIGHT', entry[1] == 'apply' and -108 or -8, 2)
            c:SetWidth(92)
            c:SetText(entry[2])
            c:Enable()
            self.fields[entry[1]] = c

            addon:SetUIScript(c, 'OnClick', self:Guard(function()
                if entry[1] == 'cancel' then
                    cancel()

                    if self.transactionKeys then
                        self:DiscardSettingsDraft()
                        self:Draw()
                    end
                elseif pageDraft then
                    if self:FlushEdits() then apply() end
                else
                    self:ApplyCreation()
                end
            end))
        end

        self.fields.add = self.fields.apply
        self:Layout()
    end

    -- Adds a row of small buttons from entries { key, text, icon, action, enabled }; icon entries are 20 px icon
    -- buttons, and the row wraps when it would pass the pane edge.
    function p:Actions(entries)
        local y = self:Row(nil, 28)
        local x = 0

        for _, entry in ipairs(entries) do
            local icon = entry.icon

            local c = self:Acquire(icon and 'actionIcons' or 'actionButtons', function()
                return icon and addon:CreateWorkbenchIconButton(self.child, icon, entry.text)
                    or addon:CreateWorkbenchButton(self.child, '', 110)
            end)

            c.tooltip = entry.text

            if icon then
                c.icon:SetTexture(addon:ControlTexture(icon))
                c:SetText('')
                c:SetWidth(20)
            else
                c:SetText(entry.text)
                c:SetWidth(math.min(110, self.width))
            end

            -- A row that no longer fits wraps instead of running past the pane.
            if x > 0 and x + c:GetWidth() > self.width then
                x = 0
                y = y + 28
                self.y = self.y + 28
            end

            c:ClearAllPoints()
            c:SetPoint('TOPLEFT', x, -y)
            x = x + c:GetWidth() + 4

            if entry.enabled == false then
                c:Disable()
            else
                c:Enable()
            end

            self.fields[entry.key] = c

            addon:SetUIScript(c, 'OnClick', self:Guard(function()
                if self:FlushEdits() then entry.action() end
            end))
        end
    end

    -- Adds a collapsible section header; build() draws the section body unless the player collapsed it (state is kept
    -- on the form across redraws).
    function p:Section(key, title, build)
        self.closedSections = self.closedSections or {}
        local y = self:Row(nil, 28)

        local c = self:Acquire('headings', function()
            return addon:CreateWorkbenchLabeledIconButton(self.child, 'chevron-down', '', 300)
        end)

        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 0, -y)
        c:SetWidth(self.width)
        c:SetText(title)
        addon:StyleWorkbenchHeader(c:GetFontString())
        c.icon:SetTexture(addon:ControlTexture(self.closedSections[key] and 'chevron-right' or 'chevron-down'))
        c:Enable()
        self.fields['section_' .. key] = c

        addon:SetUIScript(c, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                self.closedSections[key] = not self.closedSections[key]
                self:Draw()
            end
        end))

        if not self.closedSections[key] then build() end
    end

    -- ============================================================================
    -- Value fields
    -- ============================================================================

    -- Adds a check box registered as key. A click flushes edits, toggles and calls changed(newValue). Returns it.
    function p:Check(key, caption, value, changed, tooltip)
        local y = self:Row(nil)
        local c = self:Acquire('checks', function() return addon:CreateWorkbenchCheckBox(self.child, '', 420) end)
        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 0, -y)
        c:SetWidth(self.width)
        c:SetText(caption)
        c.tooltip = tooltip
        c:GetFontString():SetWidth(self.width - 22)
        c:SetChecked(value == true)
        c.rmCheck = true
        c:Enable()
        self.fields[key] = c

        addon:SetUIScript(c, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                c:SetChecked(not c:GetChecked())
                changed(c:GetChecked())
            end
        end))

        return c
    end

    -- Adds a check box on the same row as the existing field fieldKey when it fits beside it, otherwise on a row below.
    -- Both controls stay registered with the label scope.
    function p:InlineCheck(fieldKey, key, caption, value, changed, minimum, tooltip)
        local rowY = self.y - 30
        local option = self:Check(key, caption, value, changed, tooltip)

        local height, _, inline = addon:LayoutWorkbenchFieldOption(
            self.fields[fieldKey],
            option,
            self.surface or self.child,
            220,
            rowY,
            self.width - 220,
            minimum
        )

        self:LabelControl(self.fields[fieldKey], 1, 1)
        self:LabelControl(option, inline and 0 or 1, 0)
        self.y = rowY + height + 6
        return option
    end

    -- Adds a text field registered as key. Typing marks it dirty and colors it red while parse(text) returns nil. The
    -- value is committed only by FlushEdits (Enter, focus loss, or any other control): parse(text) -> value or nil,
    -- then changed(value). Escape restores the text from the last commit. Reused pooled boxes have their reference and
    -- texture decorations and scripts cleared first. Returns the edit box.
    function p:Edit(key, caption, value, parse, changed)
        local y = self:Row(caption)
        local c = self:Acquire('edits', function() return addon:CreateWorkbenchEditBox(self.child) end)
        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 220, -y)
        c:SetSize(math.max(1, self.width - 220), 24)
        self:LabelControl(c, 1, 1)
        c:SetMaxLetters(4096)
        c:EnableMouse(true)
        c:SetText(tostring(value or ''))
        c:SetTextColor(1, 1, 1)
        c:SetTextInsets(4, 4, 0, 0)
        if c.referenceIcon then c.referenceIcon:Hide() end
        if c.texturePreview then c.texturePreview:Hide() end
        c:ClearFocus()
        addon:SetUIScript(c, 'OnReceiveDrag', nil)
        addon:SetUIScript(c, 'OnMouseDown', nil)
        if c.dropHint then c.dropHint:Hide() end
        addon:SetUIScript(c, 'OnEditFocusGained', nil)
        addon:SetUIScript(c, 'OnEnter', nil)
        addon:SetUIScript(c, 'OnLeave', nil)

        local record = {
            control = c,
            parse = parse or identity,
            changed = changed,
            dirty = false,
            baseline = tostring(value or ''),
        }

        self.edits[#self.edits + 1] = record
        self.fields[key] = c

        addon:SetUIScript(c, 'OnTextChanged', self:Guard(function(_, user)
            if user then
                record.dirty = true
                if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
                local v = record.parse(c:GetText())
                c:SetTextColor(1, v ~= nil and 1 or .35, v ~= nil and 1 or .35)
            end
        end))

        addon:SetUIScript(c, 'OnEnterPressed', self:Guard(function()
            if self:FlushEdits() then c:ClearFocus() end
        end))

        addon:SetUIScript(c, 'OnEscapePressed', self:Guard(function()
            record.dirty = false
            c:SetText(record.baseline)
            c:SetTextColor(1, 1, 1)
            c:ClearFocus()
            self:Message('')
        end))

        addon:SetUIScript(c, 'OnEditFocusLost', self:Guard(function() self:FlushEdits() end))
        return c
    end

    -- Adds an Edit for a texture path or id with a preview and a catalog button (the shipped overlay textures);
    -- options.preview = false hides the preview.
    function p:Texture(key, caption, value, changed, options)
        options = options or {}
        local c

        c = self:Edit(key, caption, value, nil, function(v)
            local texture = tonumber(v) or v
            c.texturePreview:SetTexture(texture)
            changed(texture)
        end)

        local record = self.edits[#self.edits]
        c.texturePreview = c.texturePreview or c:CreateTexture(nil, 'ARTWORK')
        c.texturePreview:ClearAllPoints()
        c.texturePreview:SetPoint('RIGHT', c, 'LEFT', -6, 0)
        c.texturePreview:SetSize(26, 26)
        c.texturePreview:SetTexture(value)

        if options.preview == false then
            c.texturePreview:Hide()
        else
            c.texturePreview:Show()
        end

        local catalog = self:Acquire('textureCatalogs', function()
            return addon:CreateWorkbenchIconButton(self.child, 'chevron-down', L['Choose overlay'])
        end)

        -- Anchor to the input rather than storing any engine-specific geometry.
        catalog:ClearAllPoints()
        catalog:SetPoint('TOPLEFT', c, 'TOPRIGHT', 4, 0)
        catalog:SetSize(24, 24)
        catalog:Enable()
        c:SetWidth(math.max(1, c:GetWidth() - 28))
        self.fields[key .. '_catalog'] = catalog

        addon:SetUIScript(catalog, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                self:ShowChoices(
                    catalog,
                    addon.Artwork.overlays,
                    function(texture)
                        c:SetText(texture)
                        record.dirty = true
                        self:FlushEdits()
                    end,
                    true
                )
            end
        end))

        return c
    end

    -- Adds a slider with a linked number box, both registered (key and key_value). Slider moves commit at once; a typed
    -- number is range- and step-checked and committed through FlushEdits. Integer-step sliders round to the step.
    function p:Slider(key, caption, value, lo, hi, step, changed)
        local y = self:Row(caption)

        local c = self:Acquire('sliders', function()
            return addon:CreateWorkbenchSlider(self.child, lo, hi, step, 140)
        end)

        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 220, -y - 4)
        c:SetWidth(self.width - 290)
        self:LabelControl(c, 1, 1)
        addon:SetUIScript(c, 'OnValueChanged', nil)
        c:SetMinMaxValues(lo, hi)
        c:SetValueStep(step)
        c:SetValue(value or lo)
        c:EnableMouse(true)
        local number = self:Acquire('sliderNumbers', function() return addon:CreateWorkbenchEditBox(self.child) end)
        number:ClearAllPoints()
        number:SetPoint('TOPLEFT', self.width - 64, -y)
        number:SetSize(62, 24)
        number:SetText(string.format('%.4g', value or lo))
        number:SetTextColor(1, 1, 1)
        number:EnableMouse(true)
        number:ClearFocus()
        self.fields[key] = c
        self.fields[key .. '_value'] = number

        local record = {
            control = number,
            dirty = false,
            baseline = number:GetText(),
            parse = function(text)
                local n = tonumber(text)
                if n and n == n and n >= lo and n <= hi and (step < 1 or n % 1 == 0) then return n end
            end,
        }

        record.changed = function(n)
            c.setting = true
            c:SetValue(n)
            c.setting = false
            changed(n)
        end

        self.edits[#self.edits + 1] = record

        addon:SetUIScript(number, 'OnTextChanged', self:Guard(function(_, user)
            if user then
                record.dirty = true
                if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
                local ok = record.parse(number:GetText()) ~= nil
                number:SetTextColor(1, ok and 1 or .35, ok and 1 or .35)
            end
        end))

        addon:SetUIScript(number, 'OnEnterPressed', self:Guard(function()
            if self:FlushEdits() then number:ClearFocus() end
        end))

        addon:SetUIScript(number, 'OnEditFocusLost', self:Guard(function() self:FlushEdits() end))

        addon:SetUIScript(number, 'OnEscapePressed', self:Guard(function()
            record.dirty = false
            number:SetText(record.baseline)
            number:SetTextColor(1, 1, 1)
            number:ClearFocus()
            self:Message('')
        end))

        addon:SetUIScript(c, 'OnValueChanged', self:Guard(function(_, n)
            if c.setting then return end

            if step >= 1 then
                local rounded = math.max(lo, math.min(hi, lo + math.floor((n - lo) / step + .5) * step))

                if rounded ~= n then
                    c.setting = true
                    c:SetValue(rounded)
                    c.setting = false
                    n = rounded
                end
            end

            if self:FlushEdits() then
                number:SetText(string.format('%.4g', n))
                record.baseline = number:GetText()
                changed(n)
            end
        end))

        return c
    end

    -- ============================================================================
    -- Spell, item and sound fields
    -- ============================================================================

    -- Adds a spell or item field. kind names the reference provider ('Spell_EditBox' or 'Item_EditBox'); settings can
    -- carry accept(id) to veto ids, spec and norank. The player can type a name or id, pick from the suggestion menu,
    -- drag from the spellbook or bags, or right-click for what the game offers now (target cast, recent casts,
    -- trinkets). changed(id) gets the resolved numeric id ('' when allowEmpty and cleared). Returns the edit box.
    function p:Reference(key, caption, value, kind, settings, changed, allowEmpty)
        local provider = addon:GetReferenceProvider(kind)
        settings = settings or {}
        settings.limit = 12
        settings.inventory = provider.inventory
        local selected = value and (tonumber(value) or provider.resolve(value)) or nil

        -- True when the page's accept callback (if any) allows id; an erroring callback counts as a veto.
        local function accepted(id)
            if not settings.accept then return true end
            local ok, result = pcall(settings.accept, id)
            return ok and result and true or false
        end

        -- Display name for id, or the provider's missing text; empty for no id.
        local function display(id)
            return id and (provider.name(id, settings.norank) or provider.missing) or ''
        end

        local c, record, paint

        c = self:Edit(
            key,
            caption,
            selected and display(selected) or value or '',
            function(text)
                if text == '' and allowEmpty then return '' end
                local id = selected and text == display(selected) and selected or provider.resolve(text, settings)
                if id ~= nil and accepted(id) then return id end
            end,
            function(id)
                selected = id ~= '' and id or nil
                c:SetText(display(selected))
                record.baseline = c:GetText()
                if paint then paint() end
                changed(id)
            end
        )

        record = self.edits[#self.edits]
        c.referenceIcon = c.referenceIcon or c:CreateTexture(nil, 'ARTWORK')
        c.referenceIcon:SetSize(20, 20)
        c.referenceIcon:SetPoint('LEFT', 2, 0)
        c:SetTextInsets(26, 4, 0, 0)

        -- Shows the selected reference's icon, or the question mark icon when none is selected or it is unknown.
        paint = function()
            local info = selected and provider.info(selected)
            c.referenceIcon:SetTexture(info and info.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
            c.referenceIcon:Show()
        end

        paint()
        c.dropHint = c.dropHint or label(c)
        c.dropHint:ClearAllPoints()
        c.dropHint:SetPoint('LEFT', 28, 0)
        c.dropHint:SetPoint('RIGHT', -4, 0)

        c.dropHint:SetText(
            provider.kind == 'item' and L['Search or drag an item here'] or L['Search or drag a spell here']
        )

        c.dropHint:SetTextColor(.5, .5, .5)

        if c:GetText() == '' then
            c.dropHint:Show()
        else
            c.dropHint:Hide()
        end

        local textChanged = c:GetScript('OnTextChanged')
        local escape = c:GetScript('OnEscapePressed')

        -- Takes id from the suggestion menu or the context menu as if it had been typed and committed.
        local function choose(id)
            if not self:Valid(self.generation) or not accepted(id) then return end
            c:SetText(display(id))
            c.dropHint:Hide()
            selected = id
            record.dirty = true
            if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
            paint()
            if self:FlushEdits() then c:ClearFocus() end
        end

        -- Opens the suggestion menu for the text in the box, or closes it when nothing matches.
        local function query()
            local rows = {}
            local input = c:GetText()
            if input == provider.missing then input = '' end

            for _, entry in ipairs(provider.search(input, settings) or {}) do
                rows[#rows + 1] = { value = entry.id, text = entry.display or entry.name, icon = entry.icon }
            end

            if #rows == 0 then
                if self.menu then self.menu.frame:Hide() end
                return
            end

            self:ShowChoices(c, rows, choose, true)
        end

        -- Right-click: what the game offers right now (target or focus cast,
        -- recent casts, equipped trinkets), chosen like a suggestion.
        local function insertMenu()
            local rows = {}

            for _, entry in ipairs(addon:GetReferenceContextEntries(provider.kind)) do
                local id = provider.resolve(tostring(entry.id), settings)

                if id and accepted(id) then
                    local info = provider.info(id)

                    rows[#rows + 1] = {
                        value = id,
                        text = string.format(entry.context, provider.name(id, settings.norank) or tostring(id)),
                        icon = info and info.icon,
                    }
                end
            end

            if #rows == 0 then
                self:Message(
                    provider.kind == 'item' and L['No equipped trinket to insert.']
                        or L['Nothing to insert: no target or focus cast and no recent casts.']
                )

                return
            end

            self:ShowChoices(c, rows, choose, true)
        end

        addon:SetUIScript(c, 'OnTextChanged', self:Guard(function(control, user)
            textChanged(control, user)

            if c:GetText() == '' then
                c.dropHint:Show()
            else
                c.dropHint:Hide()
            end

            if user then query() end
        end))

        addon:SetUIScript(c, 'OnEditFocusGained', self:Guard(function()
            if selected and not record.dirty then
                c:SetText(display(selected))
                record.baseline = c:GetText()
                paint()
            end

            query()
        end))

        addon:SetUIScript(c, 'OnEscapePressed', self:Guard(function()
            if self.menu then self.menu.frame:Hide() end
            escape(c)
        end))

        addon:SetUIScript(c, 'OnEnter', self:HelpGuard(function()
            if selected and GameTooltip then
                GameTooltip:SetOwner(c, 'ANCHOR_RIGHT')
                GameTooltip:SetHyperlink(provider.kind .. ':' .. selected)

                GameTooltip:AddLine(
                    provider.kind == 'item' and L['Search or drag an item here'] or L['Search or drag a spell here']
                )

                GameTooltip:AddLine(
                    provider.kind == 'item' and L['Right-click to insert an equipped trinket.']
                        or L["Right-click to insert your target's cast or a recent cast."]
                )

                GameTooltip:Show()
            elseif GameTooltip then
                GameTooltip:SetOwner(c, 'ANCHOR_RIGHT')
                GameTooltip:SetText(c.dropHint:GetText())

                GameTooltip:AddLine(
                    provider.kind == 'item' and L['Right-click to insert an equipped trinket.']
                        or L["Right-click to insert your target's cast or a recent cast."]
                )

                GameTooltip:Show()
            end
        end))

        addon:SetUIScript(c, 'OnLeave', function()
            if GameTooltip and GameTooltip:IsOwned(c) then GameTooltip:Hide() end
        end)

        -- Takes the spell or item currently on the mouse cursor, if it fits this field and is accepted, and clears the
        -- cursor.
        local function drop()
            if type(GetCursorInfo) ~= 'function' then return end
            local observed = { pcall(GetCursorInfo) }
            local ok, cursor, first, third = observed[1], observed[2], observed[3], observed[5]
            -- Cursor contents are read through pcall and CanReadValue: on restricted clients they can be secret values
            -- that must not be compared or used.
            if not ok or not addon.Platform:CanReadValue(cursor) then return end
            local id

            if provider.kind == 'item' and cursor == 'item' then
                id = first
            elseif provider.kind == 'spell' and cursor == 'spell' then
                id = third
            elseif provider.kind == 'spell' and cursor == 'petaction' then
                id = first
            end

            if
                not addon.Platform:CanReadValue(id)
                or type(id) ~= 'number'
                or not provider.resolve(tostring(id), settings)
                or not accepted(id)
            then
                return
            end

            selected = id
            c:SetText(display(id))
            c.dropHint:Hide()
            record.dirty = true
            if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
            paint()

            if self:FlushEdits() then
                if self.menu then self.menu.frame:Hide() end
                if type(ClearCursor) == 'function' then ClearCursor() end
                c:ClearFocus()
            end
        end

        addon:SetUIScript(c, 'OnReceiveDrag', self:Guard(drop))

        addon:SetUIScript(c, 'OnMouseDown', self:Guard(function(_, button)
            if button == 'RightButton' then
                insertMenu()
            else
                drop()
            end
        end))

        return c
    end

    -- Reference field for a spell of spec (or the pet book); ranks are kept.
    function p:Spell(key, caption, id, spec, changed)
        return self:Reference(key, caption, id, 'Spell_EditBox', { spec = spec, norank = false }, changed)
    end

    -- Reference field for an item.
    function p:Item(key, caption, id, changed, allowEmpty)
        return self:Reference(key, caption, id, 'Item_EditBox', {}, changed, allowEmpty)
    end

    -- Adds the controls for an item action's target: a choice between a named item set and a custom list, and for a
    -- custom list one Item field per entry with delete buttons plus an add field. changed receives the set id or the
    -- new array.
    function p:ItemSequence(key, value, changed)
        local entries = { { value = '', text = L['Custom'] } }
        local sets = {}

        for _, source in ipairs({ addon.db.global.itemsets or {}, addon.db.profile.itemsets or {} }) do
            for id, set in pairs(source) do
                sets[id] = set
            end
        end

        local sorted = {}

        for id, set in pairs(sets) do
            sorted[#sorted + 1] = { value = id, text = set.name or id }
        end

        table.sort(sorted, function(a, b) return a.text < b.text end)

        for _, entry in ipairs(sorted) do
            entries[#entries + 1] = entry
        end

        self:Choice(key .. '_set', L['Item Set'], type(value) == 'string' and value or '', entries, function(id)
            changed(id ~= '' and id or {})
            self:Draw()
        end)

        if type(value) == 'string' then return end
        local items = type(value) == 'table' and value or type(value) == 'number' and { value } or {}

        -- Stores a new copy of the custom list and reports it.
        local function replace(copy)
            items = copy
            changed(copy)
        end

        for i, item in ipairs(items) do
            self:Item(key .. i, string.format(L['Item %d'], i), item, function(id)
                local copy = addon.Functions.collections.deepcopy(items)
                copy[i] = id
                replace(copy)
            end)

            self:Actions({
                {
                    key = key .. '_delete' .. i,
                    text = L['Delete'],
                    icon = 'trash',
                    action = function()
                        local copy = addon.Functions.collections.deepcopy(items)
                        table.remove(copy, i)
                        replace(copy)
                        self:Draw()
                    end,
                },
            })
        end

        self:Item(
            key .. '_new',
            L['Add item'],
            '',
            function(id)
                if id ~= '' then
                    local copy = addon.Functions.collections.deepcopy(items)
                    copy[#copy + 1] = id
                    replace(copy)
                    self:Draw()
                end
            end,
            true
        )
    end

    -- Adds a choice of the LibSharedMedia sound names (plus the saved name if it is not registered) with a preview
    -- button. changed gets the name, or nil for None.
    function p:Sound(key, caption, value, changed)
        local ok, media = pcall(LibStub, 'LibSharedMedia-3.0', true)
        local sounds = {}

        if ok and media and media.HashTable then
            local success, found = pcall(media.HashTable, media, 'sound')
            if success and type(found) == 'table' then sounds = found end
        end

        local entries = { { value = '', text = L['None'] } }
        local names = {}

        for name in pairs(sounds) do
            if type(name) == 'string' then names[#names + 1] = name end
        end

        table.sort(names)

        for _, name in ipairs(names) do
            entries[#entries + 1] = { value = name, text = name }
        end

        if value and sounds[value] == nil then entries[#entries + 1] = { value = value, text = value } end
        local selected = value

        local c = self:Choice(key .. 'sound', caption, value or '', entries, function(v)
            selected = v ~= '' and v or nil
            changed(selected)
        end)

        c:SetWidth(self.width - 250)

        local play = self:Acquire('soundPlay', function()
            return addon:CreateWorkbenchIconButton(self.child, 'play', L['Preview sound'])
        end)

        play:ClearAllPoints()
        play:SetPoint('LEFT', c, 'RIGHT', 4, 0)
        self.fields[key .. 'play'] = play

        addon:SetUIScript(play, 'OnClick', self:Guard(function()
            local path = selected and sounds[selected]

            if (type(path) == 'string' or type(path) == 'number') and type(PlaySoundFile) == 'function' then
                local played = PlaySoundFile(path, 'Master')
                if not played then self:Message(L['Sound preview is unavailable.']) end
            else
                self:Message(L['Choose an available sound to preview.'])
            end
        end))

        return c
    end

    -- ============================================================================
    -- Position, toggle, choice and color fields
    -- ============================================================================

    -- Adds a position pad with horizontal and vertical offset fields beside it. changed(x, y, centered) runs on every
    -- pad step or committed offset. With anchor set the caller owns the caption column, so the scope is marked custom.
    function p:Position(xvalue, yvalue, changed, anchor)
        local caption
        if not anchor then caption = L['Position'] end
        local y = self:Row(caption, 56)
        local ox, oy = xvalue or 0, yvalue or 0

        if anchor then
            local title = self:Acquire('labels', function() return label(self.child) end)
            title:ClearAllPoints()
            title:SetPoint('TOPLEFT', 0, -y)
            title:SetSize(154, 20)
            title:SetText(L['Anchor'])
        end

        -- The pad lines up with the swatches and values above it.
        local padX = 220
        -- The anchored variant lays out its own caption column.
        local scope = self.labelScope
        if anchor and scope then scope.custom = true end
        self.labelScope = nil
        local pad = self:Acquire('positionPad', function() return addon:CreateWorkbenchPositionPad(self.child) end)
        pad:ClearAllPoints()
        pad:SetPoint('TOPLEFT', padX, -y)
        local token = self.generation

        pad:Bind(function(dx, dy, center, amount)
            if not self:FlushEdits() then return end

            if center then
                ox, oy = 0, 0
            else
                ox = ox + dx * amount
                oy = oy + dy * amount
            end

            changed(ox, oy, center)
            self:Draw()
        end, function() return self:Valid(token) end, false)

        self.fields.positionPad = pad
        local after = self.y

        -- Parses a finite number or returns nil.
        local function numeric(text)
            local n = tonumber(text)
            if n and n == n and n > -math.huge and n < math.huge then return n end
        end

        -- H and V side by side, splitting the row beside the pad (50/50 with a small gap).
        local fromX, gap, letter = padX + 54, 6, 16
        local half = math.max(letter + 30, math.floor((self.width - fromX - gap) / 2))

        for i, key in ipairs({ 'xoffs', 'yoffs' }) do
            local caption = key == 'yoffs' and L['Vertical offset'] or L['Horizontal offset']
            local left = fromX + (i - 1) * (half + gap)

            local c = self:Edit(key, '', key == 'yoffs' and oy or ox, numeric, function(n)
                if key == 'yoffs' then
                    oy = n
                else
                    ox = n
                end

                changed(ox, oy, false)
            end)

            c:ClearAllPoints()
            c:SetPoint('TOPLEFT', left + letter, -y - 14)
            c:SetSize(half - letter, 20)
            c.tooltip = caption
            local t = self:Acquire('labels', function() return label(self.child) end)
            t:ClearAllPoints()
            t:SetPoint('TOPLEFT', left, -y - 14)
            t:SetSize(letter - 2, 20)
            t:SetText(key == 'yoffs' and L['V'] or L['H'])
            t.tooltip = caption

            if not anchor then
                self.labelScope = scope
                self:LabelControl(c, 1, 0)
                self:LabelControl(t, 1, 0)
                self.labelScope = nil
            end
        end

        self.labelScope = scope
        if not anchor then self:LabelControl(pad, 1, 0) end
        self.y = after
    end

    -- Adds a two-state pill that shows trueLabel or falseLabel; a click flips it and calls changed(newValue).
    function p:Toggle(key, caption, value, falseLabel, trueLabel, changed)
        local y = self:Row(caption)
        local c = self:Acquire('togglePills', function() return addon:CreateWorkbenchPill(self.child, '', 94) end)
        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 220, -y)
        c:SetWidth(94)
        self:LabelControl(c, 1, 0)
        c:SetText(value and trueLabel or falseLabel)
        c:Enable()
        self.fields[key] = c

        addon:SetUIScript(c, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                value = not value
                c:SetText(value and trueLabel or falseLabel)
                changed(value)
            end
        end))

        return c
    end

    -- Adds a dropdown button over entries { value, text, icon, ... } showing the entry whose value is value. Choosing a
    -- different value calls changed(value). Returns the button so callers can resize it or replace its click handler.
    function p:Choice(key, caption, value, entries, changed)
        local y = self:Row(caption)

        local c = self:Acquire('choices', function()
            return addon:CreateWorkbenchLabeledIconButton(self.child, 'chevron-down', '', 220)
        end)

        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', 220, -y)
        c:SetWidth(math.max(1, self.width - 220))
        self:LabelControl(c, 1, 1)
        c:Enable()
        self.fields[key] = c
        local selected = L['Select']
        local chosen

        for _, entry in ipairs(entries) do
            if entry.value == value then
                selected = entry.text
                chosen = entry
                break
            end
        end

        addon:PaintSelectorSelection(c, chosen, selected)

        addon:SetUIScript(c, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                self:ShowChoices(c, entries, function(nextValue)
                    if nextValue ~= value then
                        value = nextValue
                        changed(nextValue)
                    end
                end)
            end
        end))

        return c
    end

    -- Opens the form's shared selector menu under anchor (created on first use). The pick runs through Guard, so a
    -- stale menu does nothing. inline hides the menu's search box and leaves the anchor text alone.
    function p:ShowChoices(anchor, entries, changed, inline)
        self.menu = self.menu or addon:CreateWorkbenchSelector()
        local token = self.generation

        self.menu:Open(
            anchor,
            entries,
            nil,
            self:Guard(function(value, text)
                if not inline then anchor:SetText(text) end
                changed(value)
            end),
            function() return self:Valid(token) end,
            inline
        )
    end

    -- ============================================================================
    -- Edits, prompts and leaving the page
    -- ============================================================================

    -- Commits every dirty field in order: all must parse first or nothing is committed (the bad field turns red and a
    -- message shows). Returns whether the form is current and clean. Run before any action that reads or changes the
    -- data.
    function p:FlushEdits()
        if not self:Valid(self.generation) then return false end
        local changes = {}

        for _, record in ipairs(self.edits) do
            if record.dirty then
                local v = record.parse(record.control:GetText())

                if v == nil then
                    record.control:SetTextColor(1, .35, .35)
                    self:Message(L['Complete the highlighted input fields before applying.'])
                    return false
                end

                changes[#changes + 1] = { record = record, value = v }
            end
        end

        for _, entry in ipairs(changes) do
            entry.record.dirty = false
            entry.record.baseline = entry.record.control:GetText()
            entry.record.changed(entry.value)
        end

        self:Message('')

        if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then
            if self:IsSettingsDraftDirty() then
                self.fields.apply:Enable()
            else
                self.fields.apply:Disable()
            end
        end

        return true
    end

    -- Runs callback when it is safe to leave the page: at once when clean; otherwise opens the apply or discard prompt
    -- and returns false, and callback runs after the draft is applied or discarded.
    function p:RequestLeave(callback)
        if not self:Valid(self.generation) then
            callback()
            return true
        end

        if self:IsCreationDirty() or self.transactionKeys and self:IsSettingsDraftDirty() then
            self:ConfirmPending(function()
                local ok

                if self.creationUsedForNew then
                    ok = self:ApplyCreation()
                else
                    ok = self:FlushEdits() and self:SaveSettingsDraft()
                end

                if ok then callback() end
            end, function()
                self:DiscardSettingsDraft()
                callback()
            end)

            return false
        end

        if self:FlushEdits() then
            callback()
            return true
        end

        return false
    end

    -- Shows the shared confirmation prompt with message; callback runs on Confirm.
    function p:Confirm(message, callback)
        local prompt = self.prompt

        if not prompt then
            prompt = { frame = CreateFrame('Frame', nil, self.frame) }
            self.prompt = prompt
            prompt.frame:SetSize(430, 120)
            prompt.frame:SetPoint('CENTER')
            prompt.frame:EnableMouse(true)
            addon:MakeWindowOpaque(prompt.frame)
            prompt.text = label(prompt.frame)
            prompt.text:SetPoint('TOPLEFT', 12, -12)
            prompt.text:SetSize(406, 60)
            prompt.text:SetWordWrap(true)
            prompt.accept = addon:CreateWorkbenchButton(prompt.frame, L['Confirm'], 100)
            prompt.accept:SetPoint('BOTTOMRIGHT', -120, 12)
            prompt.cancel = addon:CreateWorkbenchButton(prompt.frame, L['Cancel'], 100)
            prompt.cancel:SetPoint('BOTTOMRIGHT', -12, 12)
            addon:SetUIScript(prompt.cancel, 'OnClick', function() prompt.frame:Hide() end)
            prompt.frame:Hide()
        end

        local promptWidth = addon:FitWorkbenchPrompt(prompt.frame, self.frame, 430)
        prompt.text:SetWidth(math.max(1, promptWidth - 24))
        if prompt.discard then prompt.discard:Hide() end
        prompt.accept:SetText(L['Confirm'])
        prompt.accept:ClearAllPoints()
        prompt.accept:SetPoint('BOTTOMRIGHT', -120, 12)
        prompt.text:SetText(message)

        addon:SetUIScript(prompt.accept, 'OnClick', self:Guard(function()
            prompt.frame:Hide()
            callback()
        end))

        prompt.frame:Show()
        addon:OpenPopup(prompt, self)
    end

    -- Turns the confirmation prompt into the Apply, Discard, Cancel prompt for unsaved changes.
    function p:ConfirmPending(apply, discard)
        self:Confirm(L['Apply changes before leaving this page?'], apply)
        local d = self.prompt
        d.accept:SetText(L['Apply'])
        d.accept:ClearAllPoints()
        d.accept:SetPoint('BOTTOMRIGHT', -228, 12)
        d.discard = d.discard or addon:CreateWorkbenchButton(d.frame, L['Discard'], 100)
        d.discard:ClearAllPoints()
        d.discard:SetPoint('BOTTOMRIGHT', -120, 12)
        d.discard:Show()

        addon:SetUIScript(d.discard, 'OnClick', self:Guard(function()
            d.frame:Hide()
            discard()
        end))
    end

    -- Adds a color swatch with four channel boxes (fields key_r, key_g, key_b, key_a) and a picker; changed({r,g,b,a})
    -- runs when a channel is committed or the picker moves. A missing color shows opaque white.
    function p:Color(key, caption, color, changed)
        color = color or { r = 1, g = 1, b = 1, a = 1 }
        local y = self:Row(caption, 56)
        local swatch = self:Acquire('swatches', function() return addon:CreateWorkbenchButton(self.child, '', 50) end)
        swatch:ClearAllPoints()
        swatch:SetPoint('TOPLEFT', 220, -y)
        swatch:SetSize(50, 50)
        self:LabelControl(swatch, 1, 0)
        swatch.art:SetColorTexture(color.r, color.g, color.b, color.a)
        swatch:Enable()
        self.fields[key] = swatch
        local values = { r = color.r, g = color.g, b = color.b, a = color.a }
        local controls, records = {}, {}
        -- The four channels share the row beside the swatch in two columns.
        local channelWidth = math.max(40, (self.width - 278 - 4) / 2)

        for i, channel in ipairs({ 'r', 'g', 'b', 'a' }) do
            local c = self:Acquire('colorInputs', function() return addon:CreateWorkbenchEditBox(self.child) end)
            c:ClearAllPoints()
            c:SetPoint('TOPLEFT', 278 + ((i - 1) % 2) * (channelWidth + 4), -y - math.floor((i - 1) / 2) * 26)
            c:SetSize(channelWidth, 24)
            self:LabelControl(c, (i - 1) % 2 == 0 and 1 or .5, .5)
            c:SetText(string.format('%.3f', values[channel]))
            c:SetTextColor(1, 1, 1)
            c:EnableMouse(true)
            c:ClearFocus()
            c:SetTextInsets(16, 3, 0, 0)
            c.axis = c.axis or label(c)
            c.axis:ClearAllPoints()
            c.axis:SetPoint('LEFT', 3, 0)
            c.axis:SetText(channel:upper())
            controls[channel] = c
            self.fields[key .. '_' .. channel] = c

            local record = {
                control = c,
                dirty = false,
                baseline = c:GetText(),
                parse = function(text)
                    local n = tonumber(text)
                    if n and n == n and n >= 0 and n <= 1 then return n end
                end,
                changed = function(n)
                    values[channel] = n
                    changed({ r = values.r, g = values.g, b = values.b, a = values.a })
                    swatch.art:SetColorTexture(values.r, values.g, values.b, values.a)
                end,
            }

            self.edits[#self.edits + 1] = record
            records[channel] = record

            addon:SetUIScript(c, 'OnTextChanged', self:Guard(function(_, user)
                if user then
                    record.dirty = true
                    if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
                    local valid = record.parse(c:GetText()) ~= nil
                    c:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
                end
            end))

            addon:SetUIScript(c, 'OnEnterPressed', self:Guard(function()
                if self:FlushEdits() then c:ClearFocus() end
            end))

            addon:SetUIScript(c, 'OnEditFocusLost', self:Guard(function() self:FlushEdits() end))

            addon:SetUIScript(c, 'OnEscapePressed', self:Guard(function()
                record.dirty = false
                c:SetText(record.baseline)
                c:SetTextColor(1, 1, 1)
                c:ClearFocus()
                self:Message('')
            end))
        end

        swatch.picker = swatch.picker or addon:CreateWorkbenchColorPicker(self.frame)
        local token = self.generation

        addon:SetUIScript(swatch, 'OnEnter', self:HelpGuard(function()
            swatch.art:SetColorTexture(values.r, values.g, values.b, values.a)
        end))

        addon:SetUIScript(swatch, 'OnLeave', self:HelpGuard(function()
            swatch.art:SetColorTexture(values.r, values.g, values.b, values.a)
        end))

        addon:SetUIScript(swatch, 'OnClick', self:Guard(function()
            if self:FlushEdits() then
                swatch.picker:Open(
                    values,
                    self:Guard(function(r, g, b, a)
                        values = { r = r, g = g, b = b, a = a }

                        for channel, c in pairs(controls) do
                            c:SetText(string.format('%.3f', values[channel]))
                            records[channel].baseline = c:GetText()
                            records[channel].dirty = false
                        end

                        swatch.art:SetColorTexture(r, g, b, a)
                        changed({ r = r, g = g, b = b, a = a })
                    end),
                    function() return self:Valid(token) end,
                    swatch
                )
            end
        end))

        self.cleanups[#self.cleanups + 1] = function()
            if swatch.picker.frame:IsShown() then swatch.picker:Close(true) end
        end

        return swatch
    end

    -- ============================================================================
    -- Drawing and lifecycle
    -- ============================================================================

    -- Every cleanup runs even if one fails; a failure part-way used to leave
    -- the old page's controls on screen and the page unusable.
    function p:RunCleanups()
        local cleanups = self.cleanups
        self.cleanups = {}

        for _, cleanup in ipairs(cleanups) do
            local ok, why = pcall(cleanup)

            if not ok then
                local handler = geterrorhandler and geterrorhandler()
                if handler then pcall(handler, why) end
            end
        end
    end

    -- Redraws the whole page: bumps the generation (invalidating every earlier callback), runs cleanups, hides pooled
    -- controls, resets layout state and replays the builder, then binds help and updates the scroll height. Does
    -- nothing when closed.
    function p:Draw()
        if not self.active then return end
        self.generation = self.generation + 1
        if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        self:RunCleanups()

        for _, list in pairs(self.pool) do
            for _, control in ipairs(list) do
                control:Hide()
            end
        end

        self.creationUsed = false
        self.creationUsedForNew = false
        self.counts = {}
        self.fields = {}
        self.edits = {}
        if self.ResetLayout then self:ResetLayout() end
        self.y = 4
        self.width = math.max(340, self.frame:GetWidth() - 40)
        self.child:SetWidth(self.width)
        self.labelScopes = {}
        self.labelScope = nil
        self:BeginLabelScope()
        self.builder(self)
        if self.DraftActions then self:DraftActions() end

        while self.labelScope do
            self:EndLabelScope()
        end

        self:BindHelpBriefs()

        if not self.creationUsedForNew then
            self.creationBaseline = nil
            self.creationApply = nil
        end

        self.child:SetHeight(self.y + 12)
        self.scroll:UpdateWorkbenchScroll()
        self.drawnReflowKey = self:ReflowKey()
        self.drawnColumnSingle = self.usedColumns and self.columnSingle or nil
    end

    -- Opens the form with builder (called with the form on every Draw). Per-page selection state is cleared when the
    -- profile, global or character table changed since the last open.
    function p:Open(builder)
        if self.profile ~= addon.db.profile or self.global ~= addon.db.global or self.char ~= addon.db.char then
            self.selection = nil
            self.creating = false
            self.rosterQuery = nil
            self.condition = nil
            self.category = nil
            self.conditionSource = nil
            self.newAnnounce = nil
            self.newEffectName = nil
            self.newItem = nil
            self.newItemSetName = nil
            self.newGroupName = nil
        end

        if self.profile ~= addon.db.profile or self.global ~= addon.db.global then self.draft = nil end
        self.active = true
        self.profile = addon.db.profile
        self.global = addon.db.global
        self.char = addon.db.char
        self.builder = builder
        self.frame:Show()
        self:Layout()
        self:Draw()
    end

    -- Sizes the scroll area and status line to the frame, leaving room for the creation buttons and the help corner.
    function p:Layout()
        if self.fixedViewport then
            self.scroll:Hide()
            self.child:SetParent(self.frame)
            self.child:ClearAllPoints()
            self.child:SetPoint('TOPLEFT', 0, 0)
            self.child:SetWidth(self.frame:GetWidth())
            return
        end

        addon:ReserveWorkbenchHelpCorner(self.frame, self.scroll, 8)

        self.scroll:SetSize(math.max(1, self.frame:GetWidth() - 34), math.max(
            1,
            self.frame:GetHeight() - (self.creationUsed and 66 or 38)
        ))

        self.message:SetWidth(math.max(1, self.frame:GetWidth() - (self.creationUsed and 340 or 20)))
    end

    -- Geometry alone changed: draw again at the new width, carrying every
    -- pending input across as typed (invalid text included) without
    -- committing it, so a resize never loses or silently applies an edit.
    function p:Relayout()
        if not self.active then return end

        for _, record in ipairs(self.edits) do
            if record.control.HasFocus and record.control:HasFocus() then
                -- Typing keeps its control, text and caret; draw again once
                -- the input lets go. A newer drawing supersedes this wait.
                self.relayoutWaiter = self.relayoutWaiter or CreateFrame('Frame', nil, self.frame)
                local token = self.generation

                addon:SetUIScript(self.relayoutWaiter, 'OnUpdate', function(waiter)
                    if not self.active or self.generation ~= token then
                        addon:SetUIScript(waiter, 'OnUpdate', nil)
                        return
                    end

                    for _, current in ipairs(self.edits) do
                        if current.control.HasFocus and current.control:HasFocus() then return end
                    end

                    addon:SetUIScript(waiter, 'OnUpdate', nil)
                    self:Relayout()
                end)

                return
            end
        end

        local pending = {}

        for _, record in ipairs(self.edits) do
            if record.dirty then
                for key, control in pairs(self.fields) do
                    if control == record.control then pending[key] = control:GetText() end
                end
            end
        end

        self:Draw()

        for key, text in pairs(pending) do
            local control = self.fields[key]

            for _, record in ipairs(self.edits) do
                if control and record.control == control then
                    control:SetText(text)
                    record.dirty = true
                    local valid = record.parse(text) ~= nil
                    control:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
                    if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end
                end
            end
        end
    end

    -- The widths a drawing depends on: the page and its detail viewport.
    function p:ReflowKey()
        return tostring(self.frame:GetWidth()) .. '/' .. tostring(self.scroll:GetWidth())
    end

    -- Geometry is laid out at once; drawing again waits for the shared
    -- reflow driver (once per rendered frame at most, never while hidden)
    -- and is skipped when the widths are those last drawn.
    function p:RequestRelayout()
        if not self.active then return end

        if self:ReflowKey() == self.drawnReflowKey then
            if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end
            return
        end

        if not addon.RequestWorkbenchReflow then return self:Relayout() end

        -- Crossing the one- or two-column breakpoint changes structure: draw
        -- on the next frame, whatever the previous drawing cost.
        if
            self.drawnColumnSingle ~= nil
            and (math.max(340, self.frame:GetWidth() - 40) < 960) ~= self.drawnColumnSingle
        then
            self.rmReflowAfter = nil
        end

        addon:RequestWorkbenchReflow(self, self.frame, function()
            if self.active and self:ReflowKey() ~= self.drawnReflowKey then self:Relayout() end
        end)
    end

    -- Resizes the form; geometry updates now and the redraw follows through the shared reflow driver.
    function p:SetWidth(n)
        self.frame:SetWidth(n)
        self:Layout()
        self:RequestRelayout()
    end

    -- Resizes the form's height and re-lays out without redrawing.
    function p:SetHeight(n)
        self.frame:SetHeight(n)
        self:Layout()
    end

    -- Closes the form: invalidates all callbacks, clears the draft and history, runs cleanups, releases focus and hides
    -- it.
    function p:Release()
        if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft = nil
        self.draftBaseline = nil
        self.draftEffects = nil
        self.active = false
        self.generation = self.generation + 1
        if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        self:RunCleanups()

        for _, list in pairs(self.pool) do
            for _, control in ipairs(list) do
                if control.ClearFocus then control:ClearFocus() end
            end
        end

        self.frame:Hide()
    end

    if addon.InstallSettingsHistory then addon:InstallSettingsHistory(p) end
    if addon.InstallSettingsDraft then addon:InstallSettingsDraft(p) end
    if addon.InstallSettingsOrdered then addon:InstallSettingsOrdered(p) end
    if addon.InstallSettingsRosterOrder then addon:InstallSettingsRosterOrder(p) end
    if addon.InstallSettingsLayout then addon:InstallSettingsLayout(p) end
    if addon.InstallSettingsUnsaved then addon:InstallSettingsUnsaved(p) end
    if addon.InstallSettingsChangeReview then addon:InstallSettingsChangeReview(p) end
    p.frame:SetSize(parent:GetWidth(), parent:GetHeight())
    p:Layout()
    return p
end
