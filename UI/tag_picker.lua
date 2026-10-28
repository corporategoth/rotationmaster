-- Tag picker widget for rotations: a search box over the known tags, removable tag chips below it and an optional per-
-- tag color chooser. It stores nothing itself; the owner supplies the tag source, colors and change callback through
-- options and gets a normalized copy back. Used by the rotation browser filter and the rotation metadata window. Loaded
-- from RotationMaster.toc after UI/color_picker.lua; tag normalization lives in addon.RotationData.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Builds a picker inside parent and returns the picker table (frame, SetTags, SetWidth, Hide, Release, ...). options:
-- available() -> list of known tags, valid() -> whether the owner is still current, color(tag) -> {r,g,b,a},
-- setColor(tag, rgba), changed(tags) after any edit, layout(height) when the height changes, allowCustom (type new
-- tags), readOnly, inputInset. Every callback is skipped once valid() is false or the picker is released.
function addon:CreateRotationTagPicker(parent, options)
    local picker = {
        frame = CreateFrame('Frame', nil, parent),
        tags = {},
        chips = {},
        width = 300,
        options = options,
        serial = 0,
    }

    local frame = picker.frame
    picker.input = addon:CreateWorkbenchEditBox(frame)
    picker.input:SetPoint('TOPLEFT', options.inputInset or 0, 0)
    picker.input:SetHeight(24)
    picker.input:SetMaxLetters(256)
    picker.input:SetText('')

    picker.placeholder = addon:AttachWorkbenchSearchHint(
        picker.input,
        options.allowCustom and L['Add or search tags'] or L['Search tags']
    )

    picker.input.art:SetColorTexture(.12, .13, .15, 1)

    -- Shows or hides the search hint to match the box's current text.
    function picker:UpdatePlaceholder()
        self.input:RefreshWorkbenchSearchHint()
    end

    picker.input.tooltip = options.allowCustom
        and L['Type a tag and press Enter, or choose an existing tag. Click a tag to remove it; use the search results to change tag colors.']
        or L['Search existing tags and select any number of them. Click a selected tag to remove it; use the search results to change tag colors.']

    picker.menu = addon:CreateWorkbenchSelector()

    -- True while the picker is live and the owner (when it supplied valid) still wants input.
    local function valid()
        return not picker.released and (not options.valid or options.valid())
    end

    -- Returns the owner's color for tag, or opaque white when the owner has no color source.
    local function color(tag)
        return options.color and options.color(tag) or { r = 1, g = 1, b = 1, a = 1 }
    end

    -- Re-flows the chips under the input in rows, reusing chip buttons, and reports the new height through
    -- options.layout only when it changed.
    function picker:Layout()
        local inputWidth = math.max(40, self.width - (options.inputInset or 0))
        self.input:SetWidth(inputWidth)
        self.placeholder:SetWidth(inputWidth - 12)
        local x, y = 0, 28

        for i, tag in ipairs(self.tags) do
            local chip = self.chips[i]

            if not chip then
                chip = addon:CreateWorkbenchPill(frame, '', 72)
                chip:RegisterForClicks('LeftButtonUp')
                self.chips[i] = chip
            end

            local width = math.min(self.width, math.max(40, #tag * 7 + 20))

            if x > 0 and x + width > self.width then
                x = 0
                y = y + 22
            end

            chip:ClearAllPoints()
            chip:SetPoint('TOPLEFT', x, -y)
            chip:SetWidth(width)
            chip:SetText(tag .. ' ×')
            chip.tooltip = L['Click to remove this tag. Use the search results to change tag colors.']

            addon:SetUIScript(chip, 'OnEnter', function()
                if valid() and GameTooltip then
                    GameTooltip:SetOwner(chip, 'ANCHOR_RIGHT')
                    GameTooltip:SetText(chip.tooltip, 1, 1, 1, 1, true)
                end
            end)

            addon:SetUIScript(chip, 'OnLeave', function()
                if GameTooltip and GameTooltip:IsOwned(chip) then
                    GameTooltip:Hide()
                end
            end)

            local rgba = color(tag)
            chip:GetFontString():SetTextColor(rgba.r, rgba.g, rgba.b, rgba.a or 1)
            chip:SetAccent(rgba.r, rgba.g, rgba.b, rgba.a or 1)
            chip:SetSelected(true)
            chip:Show()

            if options.readOnly then
                chip:Disable()
            else
                chip:Enable()
            end

            addon:SetUIScript(chip, 'OnClick', function()
                if not valid() or options.readOnly then
                    return
                end

                local tags = addon.RotationData.CopyData(self.tags)
                table.remove(tags, i)
                self:Change(tags)
            end)

            x = x + width + 4
        end

        for i = #self.tags + 1, #self.chips do
            self.chips[i]:Hide()
        end

        local height = #self.tags > 0 and y + 20 or 24
        local changed = height ~= self.height
        self.height = height
        frame:SetHeight(height)

        if changed and options.layout then
            options.layout(height)
        end
    end

    -- Sets the picker width (minimum 80) and re-flows.
    function picker:SetWidth(width)
        self.width = math.max(80, width)
        frame:SetWidth(self.width)
        self:Layout()
    end

    -- Replaces the shown tags with the normalized form of tags without calling options.changed (programmatic load).
    function picker:SetTags(tags)
        self.tags = addon.RotationData.NormalizeRotationTags(tags or {}) or {}
        self:Layout()
    end

    -- Applies a user edit: normalizes tags, shows them, clears the box and menu and reports a copy through
    -- options.changed. Returns false when tags do not normalize.
    function picker:Change(tags)
        local normalized = addon.RotationData.NormalizeRotationTags(tags)

        if not normalized then
            return false
        end

        self:SetTags(normalized)
        self.input:SetText('')
        self:UpdatePlaceholder()
        self.menu:Hide()
        self.input:ClearFocus()

        if options.changed then
            options.changed(addon.RotationData.CopyData(normalized))
        end

        return true
    end

    -- Adds one tag typed or chosen by the user. Without allowCustom the tag must match a known tag (case-insensitive)
    -- and takes that tag's spelling. Returns whether the tag list changed.
    function picker:Add(tag)
        if not valid() or options.readOnly then
            return false
        end

        local normalized = addon.RotationData.NormalizeRotationTags({ tag })

        if not normalized then
            return false
        end

        tag = normalized[1]

        if not options.allowCustom then
            local found

            for _, known in ipairs(options.available() or {}) do
                if known:lower() == tag:lower() then
                    tag = known
                    found = true
                    break
                end
            end

            if not found then
                return false
            end
        end

        local tags = addon.RotationData.CopyData(self.tags)
        tags[#tags + 1] = tag
        return self:Change(tags)
    end

    -- Opens the dropdown of known tags that contain the typed text, marking those already selected. Entries get a color
    -- swatch when the owner can set colors; the color dialog is created once and its callbacks re-check validity.
    function picker:Suggest()
        if not valid() or options.readOnly then
            return
        end

        local query = (self.input:GetText() or ''):lower()
        local entries = {}
        local selected = {}

        for _, tag in ipairs(self.tags) do
            selected[tag:lower()] = true
        end

        for _, tag in ipairs(options.available() or {}) do
            if tag:lower():find(query, 1, true) then
                local entry = { value = tag, text = tag, selected = selected[tag:lower()], color = color(tag) }

                if options.setColor and addon.CreateWorkbenchColorPicker then
                    entry.chooseColor = function(swatch, repaint, leaseValid)
                        -- True while the picker is current and the dropdown's color lease has not been retired.
                        local function colorValid()
                            return valid() and (not leaseValid or leaseValid())
                        end

                        if not colorValid() then
                            return
                        end

                        self.colorPicker = self.colorPicker or addon:CreateWorkbenchColorPicker(frame)

                        self.colorPicker:Open(
                            color(tag),
                            function(r, g, b, a)
                                if colorValid() then
                                    local rgba = { r = r, g = g, b = b, a = a }
                                    options.setColor(tag, rgba)
                                    self:Layout()
                                    repaint(rgba)
                                end
                            end,
                            colorValid,
                            swatch
                        )

                        return self.colorPicker
                    end
                end

                entries[#entries + 1] = entry
            end
        end

        if #entries == 0 then
            self.menu:Hide()
            return
        end

        self.menu:Open(
            self.input,
            entries,
            nil,
            function(tag)
                if valid() then
                    self:Add(tag)
                end
            end,
            valid,
            true
        )
    end

    addon:SetUIScript(picker.input, 'OnTextChanged', function(_, user)
        picker:UpdatePlaceholder()

        if user then
            picker:Suggest()
        end
    end)

    addon:SetUIScript(picker.input, 'OnEditFocusGained', function()
        picker:Suggest()
    end)

    addon:SetUIScript(picker.input, 'OnEnterPressed', function()
        if picker:Add(picker.input:GetText()) then
            picker.input:ClearFocus()
        end
    end)

    addon:SetUIScript(picker.input, 'OnEscapePressed', function()
        picker.menu:Hide()
        picker.input:SetText('')
        picker:UpdatePlaceholder()
        picker.input:ClearFocus()
    end)

    addon:SetUIScript(picker.input, 'OnEnter', function()
        if valid() and GameTooltip then
            GameTooltip:SetOwner(picker.input, 'ANCHOR_RIGHT')
            GameTooltip:SetText(picker.input.tooltip, 1, 1, 1, 1, true)
        end
    end)

    addon:SetUIScript(picker.input, 'OnLeave', function()
        if GameTooltip and GameTooltip:IsOwned(picker.input) then
            GameTooltip:Hide()
        end
    end)

    -- Closes the menu and any color dialog, drops edit focus and hides the frame.
    function picker:Hide()
        self.menu:Hide()
        self.input:ClearFocus()

        if self.colorPicker then
            self.colorPicker:Close(true)
        end

        frame:Hide()
    end

    -- Permanently retires the picker: later callbacks become no-ops and the menu is released.
    function picker:Release()
        self.released = true
        self.menu:Release()
        self:Hide()
    end

    addon:SetUIScript(frame, 'OnHide', function()
        picker.menu:Hide()
        picker.input:ClearFocus()

        if picker.colorPicker then
            picker.colorPicker:Close(true)
        end
    end)

    picker:Layout()
    return picker
end
