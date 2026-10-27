-- The Format choice of a rotation transfer window: Rotation Master (the default) or WowSims. Everything pasted into
-- the window is read as the chosen format, and what the window shows for export is written in it. The conversion
-- happens before the usual Preview / Compare / Check flow, which then runs on an ordinary rotation: nothing in the
-- import path is weakened. Item sets, announcements and the other kinds of transfer have no WowSims form and show
-- no such choice. The converter itself is the load-on-demand add-on RotationMaster_WowSims (Core/transfer_formats.lua),
-- not loaded until this window needs it.
-- Loaded from RotationMaster.toc right after UI/transfer.lua, whose rotation transfer window attaches these controls.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Per-window state
-- ============================================================================

-- Per-window state: the chosen format, the codec the import session reads through, and the conversions made.
-- codec is the Rotation Master codec; source is the rotation being exported; spec is the list the window belongs to.
function addon:NewTransferFormatState(codec, source, spec, exported)
    local state = {
        format = self:GetTransferFormat(),
        spec = spec,
        source = source,
        exportText = { rm = exported },
        conversions = {},
        failure = nil,
        lastImport = nil,
    }

    -- True when the text starts like a JSON object or array, used to hint that WowSims JSON was pasted as Rotation
    -- Master.
    local function looksLikeJson(text)
        local first = type(text) == 'string' and text:match('^%s*(.)') or nil
        return first == '{' or first == '['
    end

    local cache

    state.codec = {
        Encode = function(_, value) return codec:Encode(value) end,
        Decode = function(_, text)
            if state.format == 'wowsims' then
                if cache and cache.text == text then
                    state.lastImport = cache.converted
                    state.failure = cache.failure
                    if cache.converted then return cache.decoded end
                    return nil, cache.message
                end

                state.lastImport = nil
                state.failure = nil

                if type(text) == 'string' and text:match('^%s*RM%d+:') then
                    return nil,
                        L['This looks like a Rotation Master export. Set Format to Rotation Master to import it.']
                end

                local converted, message, failure = addon:ConvertRotationFromFormat('wowsims', text, spec)

                if not converted then
                    state.failure = failure
                    cache = { text = text, message = message, failure = failure }
                    return nil, message
                end

                local portable, problem = addon.RotationData.CheckPortable(converted.body)

                if not portable then
                    local message = string.format(
                        L['The converted rotation is too large to import (%s).'],
                        type(problem) == 'table' and tostring(problem.code) or '?'
                    )

                    cache = { text = text, message = message }
                    return nil, message
                end

                state.lastImport = converted
                local decoded = { value = converted.body, kind = 'legacy', original = text }
                cache = { text = text, converted = converted, decoded = decoded }
                return decoded
            end

            local decoded, why = codec:Decode(text)

            if not decoded and looksLikeJson(text) and addon:IsTransferFormatAvailable('wowsims') then
                return nil, L['This looks like WowSims JSON. Set Format to WowSims to import it.']
            end

            return decoded, why
        end,
    }

    -- The text the window shows for export in the chosen format, and the report on how it was made. limit: how many
    -- characters the box takes. The pretty JSON is shown when it fits, the compact form when only that does.
    function state:ExportFor(format, limit)
        if format == 'rm' then return self.exportText.rm end
        local conversion = self.conversions[format]

        if conversion == nil then
            local result, message = addon:ConvertRotationToFormat(format, self.source, self.spec)
            conversion = result or { failed = message }
            self.conversions[format] = conversion
        end

        if conversion.failed then return nil, conversion.failed end
        local text = conversion.text

        if limit and limit > 0 and #text > limit then
            if conversion.compactText and #conversion.compactText <= limit then
                text = conversion.compactText
            else
                return nil,
                    string.format(
                        L['The WowSims export is too long for this box (%d characters), so it cannot be shown here.'],
                        #text
                    ),
                    conversion
            end
        end

        return text, nil, conversion
    end

    -- Drops the cached import conversion and its report; called when the format changes or the text is cleared.
    function state:Forget()
        cache = nil
        self.lastImport = nil
        self.failure = nil
    end

    -- The window closed: nothing of what was converted for it is kept.
    function state:Release()
        self:Forget()
        self.conversions = {}
        self.exportText = {}
        self.source = nil
    end

    return state
end

-- ============================================================================
-- Report window and Format row
-- ============================================================================

-- The window that shows a conversion report: the same themed, copyable text surface the other reports use.
function addon:ShowTransferReport(title, text)
    local d = self.transferFormatReport

    if not d then
        d = self:CreateWorkbenchTextReport(820, 500)
        self.transferFormatReport = d
    end

    d:SetReport(title, text)
    return d
end

local WARNING_COLOR = { 1, .82, 0 }

-- Adds the Format row to a rotation transfer window (a dialog from ShowSettingsTextTransfer): the menu, the warning
-- line and the "Check export" button. options is the window's option table (for invalidate); state comes from
-- NewTransferFormatState. Returns the control table, which also lives on the dialog as dialog.formatControls.
function addon:AttachTransferFormatControls(dialog, state, options)
    local frame = dialog.frame
    local controls = dialog.formatControls

    if not controls then
        controls = {}
        controls.label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        controls.label:SetPoint('TOPLEFT', 12, -130)
        controls.label:SetSize(54, 24)
        controls.label:SetJustifyH('LEFT')
        controls.label:SetText(L['Format'])
        controls.button = self:CreateWorkbenchLabeledIconButton(frame, 'chevron-down', '', 190)
        controls.button:SetPoint('TOPLEFT', 70, -130)
        controls.button:SetSize(190, 24)
        controls.check = self:CreateWorkbenchButton(frame, L['Check export'], 100)
        controls.check:SetPoint('TOPLEFT', 268, -130)
        controls.note = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        controls.note:SetPoint('TOPLEFT', 12, -158)
        controls.note:SetSize(546, 28)
        controls.note:SetWordWrap(true)
        controls.note:SetJustifyH('LEFT')
        controls.note:SetJustifyV('TOP')
        controls.note:SetTextColor(WARNING_COLOR[1], WARNING_COLOR[2], WARNING_COLOR[3])
        controls.menu = self:CreateWorkbenchSelector()
        dialog.formatControls = controls
    end

    controls.state = state
    controls.options = options

    -- True while these controls still belong to the visible dialog, state and option table (guards late callbacks).
    local function live()
        return dialog.formatControls == controls
            and controls.state == state
            and dialog.options == options
            and frame:IsShown()
    end

    -- True when the text box still holds exactly what this window last wrote into it (so it is safe to replace).
    local function shownIsExport()
        local text = dialog.input:GetText()
        return text == dialog.formatShown
    end

    -- What the box holds is an export when it is exactly what this window last put there.
    local function showExport(text, wrapped)
        local value = wrapped and self:FormatExportText(text) or text
        dialog.formatShown = value
        dialog.input:SetText(value)
        dialog.scroll.workbenchBar:SetValue(0)
    end

    -- The menu label for the current format.
    local function labelText()
        return self:GetTransferFormatLabel(state.format)
    end

    -- The edit box's character limit, or nil when it reports none; bounds how long an export can be shown.
    local function boxLimit()
        local input = dialog.input

        if type(input.GetMaxLetters) == 'function' then
            local value = input:GetMaxLetters()
            if type(value) == 'number' and value > 0 then return value end
        end
    end

    -- Updates the menu label, the lossy-conversion note and the Check export button to match the current format and
    -- box.
    local function refresh()
        if not live() then return end
        local wowsims = state.format == 'wowsims'
        local label = labelText()
        controls.button:SetText(label)
        self:AlignWorkbenchTextLeft(controls.button, 26)
        local caption = controls.check:GetFontString()

        if caption and caption.GetStringWidth then
            controls.check:SetWidth(math.max(100, math.ceil(caption:GetStringWidth() or 0) + 16))
        end

        local reason = self:GetTransferFormatUnavailableReason()

        if reason then
            controls.button:Disable()
            controls.button.tooltip = reason
        else
            controls.button:Enable()
            controls.button.tooltip = L['Choose the format of the text this window shows and reads. Rotation Master is the default; WowSims is the simulator\'s Action Priority List (JSON).']
        end

        if wowsims then
            controls.note:SetText(
                shownIsExport() and L['Some detail may be lost converting to WowSims.']
                    or L['Some detail may be lost converting from WowSims.']
            )

            controls.note:Show()
            controls.check:Show()
            local result = state:ExportFor('wowsims')

            if result and shownIsExport() then
                controls.check:Enable()
            else
                controls.check:Disable()
            end
        else
            controls.note:SetText('')
            controls.note:Hide()
            controls.check:Hide()
        end
    end

    controls.refresh = refresh

    -- Switches format when allowed. An export in the box is rewritten in the new format; pasted text is kept and read
    -- in the new format from the next Preview on.
    local function choose(format)
        if not live() or format == state.format or not self:IsTransferFormatAvailable(format) then return end
        -- The box holds an export when it is exactly what this window put there (or nothing): that is rewritten in
        -- the new format. Anything pasted stays, and is read in the new format from the next Preview on.
        local replace = shownIsExport() or dialog.input:GetText() == ''
        local text, message

        if format == 'wowsims' then
            -- Loading the converter happens here, the first time it is wanted.
            text, message = state:ExportFor('wowsims', boxLimit())

            if not text and replace then
                dialog.status:SetText(
                    message or string.format(L['The rotation could not be converted to WowSims: %s'], 'unknown')
                )

                return
            end
        end

        state.format = format
        self:SetTransferFormat(format)
        state:Forget()

        if replace then
            if format == 'rm' then
                showExport(state:ExportFor('rm') or '', true)
            else
                showExport(text, false)
            end

            if options.invalidate then options.invalidate(dialog) end

            dialog.status:SetText(
                format == 'wowsims'
                    and L['Copy this text to use it in WowSims, or paste WowSims JSON here to import it.']
                    or L['Choose a new named copy or replace the selected editable entry. Review the destination before importing.']
            )
        else
            -- Reads the name again and drops the staged import, as a paste would.
            local run = dialog.input:GetScript('OnTextChanged')
            if run then run(dialog.input, true) end
            dialog.status:SetText(L['Format changed. Preview the pasted text again before importing.'])
        end

        refresh()
    end

    controls.Choose = choose

    self:SetUIScript(controls.button, 'OnClick', function()
        if not live() or self:GetTransferFormatUnavailableReason() then return end
        local entries = {}

        for _, choice in ipairs(self:GetTransferFormatChoices()) do
            entries[#entries + 1] = { value = choice.value, text = choice.text, disabled = choice.disabled }
        end

        controls.menu:Open(controls.button, entries, state.format, function(value) choose(value) end, live)
    end)

    self:SetUIScript(controls.check, 'OnClick', function()
        if not live() or state.format ~= 'wowsims' then return end
        local text, message, conversion = state:ExportFor('wowsims')

        if not text then
            dialog.status:SetText(message or '')
            return
        end

        self:ShowTransferReport(L['WowSims export report'], conversion.reportText)
    end)

    -- The first text in the box: the export in the remembered format.
    if state.format == 'wowsims' then
        local text, message = state:ExportFor('wowsims', boxLimit())

        if text then
            showExport(text, false)
        else
            -- The converter cannot be used (not loadable, nothing to convert): fall back to Rotation Master and say
            -- why.
            state.format = 'rm'
            showExport(state:ExportFor('rm') or '', true)
            dialog.status:SetText(message or '')
        end

        if state.format == 'wowsims' then
            dialog.status:SetText(L['Copy this text to use it in WowSims, or paste WowSims JSON here to import it.'])
        end
    else
        dialog.formatShown = dialog.input:GetText()
    end

    local typed = dialog.input:GetScript('OnTextChanged')

    self:SetUIScript(dialog.input, 'OnTextChanged', function(...)
        if typed then typed(...) end
        if live() then refresh() end
    end)

    local clear = dialog.clear:GetScript('OnClick')

    self:SetUIScript(dialog.clear, 'OnClick', function(...)
        if clear then clear(...) end
        if live() then refresh() end
    end)

    refresh()
    return controls
end
