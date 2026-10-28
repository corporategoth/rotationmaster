-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The shared text transfer windows of the settings pages: the import/export dialog (addon:ShowSettingsTextTransfer),
-- the read-only copyable report (addon:CreateWorkbenchTextReport) and the shell both are built on. It owns the window
-- widgets, the fixed-pitch export font choice and the Help button lease, and it hands the pasted text to the caller's
-- `apply` function; it never parses or executes what is pasted and never touches saved data itself. Every handler
-- re-checks that its window, form and database tables are still the ones it started with. Loaded in the UI/ block of
-- RotationMaster.toc after UI/item_list_popup.lua; the review dialog it can open is UI/transfer_review.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Help button
-- ============================================================================

-- Adds (or removes, when `metadata` is nil) the Help button on a transfer window. Each call takes a new lease and
-- cleans up the previous one, so only the newest transfer can open Help. Does nothing if the owner or the profile,
-- global or character tables changed meanwhile.
-- @param d table  The transfer window record.
-- @param metadata table|nil  { heading, owner, brief, briefs, valid, sections }; nil removes the button.
-- @param ownerValid function|nil  The caller's liveness check.
--
-- Text-only transfers never execute Lua. The caller validates the candidate and applies it only while its original form
-- and database are still alive. Optional Help belongs to one current transfer/report, not its edit actions.
function addon:BindTransferHelp(d, metadata, ownerValid)
    local previous = d.transferHelpLease
    local profile, global, char = self.db.profile, self.db.global, self.db.char

    if ownerValid then
        local ok, current = pcall(ownerValid)

        if
            not ok
            or current ~= true
            or d.transferHelpLease ~= previous
            or self.db.profile ~= profile
            or self.db.global ~= global
            or self.db.char ~= char
        then
            return
        end
    end

    local lease = { cleanups = {} }
    d.transferHelpLease = lease

    if previous then
        for _, clear in ipairs(previous.cleanups) do
            clear()
        end
    end

    if d.transferHelpLease ~= lease then
        return
    end

    if not metadata then
        if d.help then
            self:SetUIScript(d.help, 'OnClick', nil)
            d.help:Hide()
        end

        return
    end

    local extraValid = metadata.valid

    -- Tells whether this lease is the newest, the window was not hidden since, and the saved-data tables are unchanged.
    -- @return boolean  True while Help may act.
    local function base()
        return d.transferHelpLease == lease
            and not lease.hidden
            and addon.db.profile == profile
            and addon.db.global == global
            and addon.db.char == char
    end

    -- Tells whether Help is fully live: base() plus the window shown and every caller-supplied validity check passing.
    -- base() is re-tested after each callback because a callback may close the window or switch profile.
    -- @return boolean  True while Help may open.
    local function current()
        if not base() or not d.frame:IsShown() or not base() then
            return false
        end

        for _, valid in ipairs({ ownerValid or false, extraValid or false }) do
            if valid then
                local ok, value = pcall(valid)

                if not ok or value ~= true or not base() then
                    return false
                end
            end
        end

        local shown = d.frame:IsShown()
        return shown and base()
    end

    -- Wrap OnHide once: when this binding runs again the previous wrapper is unwrapped first so wrappers do not stack.
    local onHide = d.frame:GetScript('OnHide')

    if onHide == d.transferHelpHideWrapper then
        onHide = d.transferHelpHideOriginal
    end

    d.transferHelpHideOriginal = onHide

    self:SetUIScript(d.frame, 'OnHide', function(...)
        lease.hidden = true

        if onHide then
            return onHide(...)
        end
    end)

    d.transferHelpHideWrapper = d.frame:GetScript('OnHide')

    if not d.help then
        d.help = self:CreateWorkbenchHelpButton(d.frame, L['Help'])
    end

    if not base() then
        return
    end

    d.help:ClearAllPoints()
    d.help:SetPoint('TOPRIGHT', -31, -5)
    d.help:SetSize(20, 20)
    d.help.icon:SetSize(18, 18)
    d.help.tooltip = metadata.brief or L['Help']
    d.help:Show()

    if not base() then
        return
    end

    local sections, heading, owner = metadata.sections, metadata.heading or L['Help'], metadata.owner

    -- Opens the Help window for this transfer while its lease is current; the sections come from the metadata (a
    -- function of the dialog, or a list).
    self:SetUIScript(d.help, 'OnClick', function()
        if d.transferHelpLease ~= lease then
            return
        end

        local open = rawget(addon, 'OpenWorkbenchHelp')

        if type(open) == 'function' then
            return open(addon, {
                heading = heading,
                owner = owner,
                valid = current,
                sections = function()
                    if type(sections) == 'function' then
                        return sections(d)
                    end

                    return sections or {}
                end,
            })
        end
    end)

    if self.BindWorkbenchHelp then
        lease.cleanups[#lease.cleanups + 1] = self:BindWorkbenchHelp(d.help, {
            brief = d.help.tooltip,
            valid = current,
        })

        for key, brief in pairs(metadata.briefs or {}) do
            local control = d[key]

            if control then
                if type(brief) == 'function' then
                    local describe = brief
                    brief = function() return describe(d) end
                end

                lease.cleanups[#lease.cleanups + 1] = self:BindWorkbenchHelp(control, {
                    brief = brief,
                    valid = current,
                })
            end
        end
    end
end

-- Returns the tooltip briefs for the transfer window's buttons, keyed by the field name on the dialog; `preview` is a
-- function because its text depends on whether the dialog is replacing or creating.
-- @return table  The map of field name to brief (a string, or a function of the dialog that returns one).
function addon:TransferHelpBriefs()
    return {
        copy = L['Help.Transfers.copy'],
        clear = L['Help.Transfers.clear'],
        apply = L['Help.Transfers.apply'],
        cancel = L['Help.Transfers.cancel'],
        close = L['Help.Transfers.cancel'],
        destination = L['Help.Transfers.destination'],
        name = L['Help.Transfers.name'],
        preview = function(d)
            return d.mode == 'replace' and d.options and d.options.canReplace and L['Help.Transfers.compare']
                or L['Help.Transfers.preview']
        end,
        inspect = L['Help.Transfers.inspect'],
    }
end

-- ============================================================================
-- Export font
-- ============================================================================

-- Export and import strings are Base64: a fixed-pitch face keeps the 76-character
-- lines aligned and readable. Shells that show prose (reports, output) keep the
-- proportional face; the transfer windows call this on their own edit box.
local EXPORT_FONT = 'Interface\\AddOns\\' .. addon_name .. '\\Fonts\\Inconsolata-Regular.ttf'
local EXPORT_FONT_SIZES = { 12, 11, 10, 9 }
local EXPORT_BOX_MARGIN = 12

-- Returns the most letters the box accepts: the plain limit plus one newline per line.
-- @param letters number  The plain letter limit.
-- @return number  The limit including line breaks.
function addon:ExportTextLimit(letters)
    return letters + math.ceil(letters / self.ExportTextWidth)
end

-- Uses Inconsolata at the largest size whose 76-character line fits the box without wrapping, measured rather than
-- assumed. If the file is missing or the client refuses it the box keeps the default font; nothing else changes.
-- @param d table  The transfer window record (input, frame).
-- @return boolean  True when a fixed-pitch font was applied.
--
-- Export and import strings are Base64: a fixed-pitch face keeps the 76-character lines aligned and readable. Shells
-- that show prose (reports, output) keep the proportional face; the transfer windows call this on their own edit box.
function addon:UseExportFont(d)
    local input = d.input
    d.exportFont = nil
    input:SetFontObject('GameFontHighlightSmall')

    if type(input.SetFont) ~= 'function' then
        return false
    end

    d.exportProbe = d.exportProbe or d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    d.exportProbe:Hide()
    local sample = string.rep('0', self.ExportTextWidth)
    local limit = input:GetWidth() - EXPORT_BOX_MARGIN
    local chosen

    for _, size in ipairs(EXPORT_FONT_SIZES) do
        if input:SetFont(EXPORT_FONT, size, '') == false then
            break
        end

        -- A client that cannot load the file keeps the previous face; GetFont says which one is live.
        local path = type(input.GetFont) == 'function' and input:GetFont()

        if type(path) == 'string' and not path:lower():find('inconsolata', 1, true) then
            break
        end
        if d.exportProbe:SetFont(EXPORT_FONT, size, '') == false then
            break
        end

        d.exportProbe:SetText(sample)
        chosen = { size = size, width = d.exportProbe:GetStringWidth() }

        if chosen.width <= limit then
            break
        end
    end

    if not chosen then
        input:SetFontObject('GameFontHighlightSmall')
        return false
    end

    d.exportFont = chosen
    return true
end

-- ============================================================================
-- Window shell and text report
-- ============================================================================

-- Builds the bare transfer window record (frame, chrome, scrolling multi-line edit box, Copy, Clear, Import, Cancel and
-- Close buttons) without behavior; callers wire the scripts.
-- @param width number|nil  The window width; nil means 570.
-- @param height number|nil  The window height; nil means 430.
-- @return table  The window record.
function addon:CreateWorkbenchTransferShell(width, height)
    width, height = width or 570, height or 430
    local d = { frame = CreateFrame('Frame', nil, UIParent), sharedTransferShell = true }
    d.frame:SetSize(width, height)
    d.frame:SetPoint('CENTER')
    d.frame:EnableMouse(true)
    self:MakeWindowOpaque(d.frame)
    d.title = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    d.chrome = self:CreateWorkbenchDialogChrome(d.frame, d.title)
    d.chromeUpdate = d.frame:GetScript('OnUpdate')
    d.scroll = self:CreateWorkbenchScrollFrame(d.frame)
    d.scroll:SetPoint('TOPLEFT', 12, -40)
    d.scroll:SetSize(width - 50, height - 130)
    d.input = CreateFrame('EditBox', nil, d.scroll)
    d.input:SetFontObject('GameFontHighlightSmall')
    d.input:SetMultiLine(true)
    d.input:SetAutoFocus(false)
    d.input:SetMaxLetters(self:ExportTextLimit(131072))
    d.input:SetSize(width - 60, height - 130)
    d.input:SetPoint('TOPLEFT')
    d.scroll:SetScrollChild(d.input)
    d.copy = self:CreateWorkbenchButton(d.frame, L['Copy'], 64)
    d.copy:SetPoint('BOTTOMLEFT', 12, 28)
    d.clear = self:CreateWorkbenchButton(d.frame, L['Clear'], 64)
    d.clear:SetPoint('BOTTOMLEFT', 82, 28)
    d.apply = self:CreateWorkbenchButton(d.frame, L['Import'], 100)
    d.apply:SetPoint('BOTTOMRIGHT', -120, 28)
    d.cancel = self:CreateWorkbenchButton(d.frame, L['Cancel'], 100)
    d.cancel:SetPoint('BOTTOMRIGHT', -12, 28)
    d.close = self:CreateWorkbenchIconButton(d.frame, 'close', L['Close'])
    d.close:SetPoint('TOPRIGHT', -5, -5)
    return d
end

-- Returns a read-only report window; show text in it with d:SetReport(title, text, context, help). Typing into the box
-- is reverted to the report text, so it can be selected and copied but not edited.
-- @param width number|nil  The window width; nil means 820.
-- @param height number|nil  The window height; nil means 500.
-- @return table  The report window.
--
-- Shared themed, copyable report surface. It never accepts document changes.
function addon:CreateWorkbenchTextReport(width, height)
    local d = self:CreateWorkbenchTransferShell(width or 820, height or 500)
    d.apply:Hide()
    d.cancel:Hide()
    d.clear:Hide()
    d.input:SetMaxLetters(0)
    d.input:SetTextInsets(4, 4, 4, 4)
    d.content = CreateFrame('Frame', nil, d.scroll)
    d.input:SetParent(d.content)
    d.input:ClearAllPoints()
    d.input:SetPoint('TOPLEFT')
    d.scroll:SetScrollChild(d.content)
    d.measure = d.content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    d.measure:SetWordWrap(true)
    d.measure:Hide()

    -- Measures the wrapped text with a hidden font string and sizes the content and edit box to fit it.
    function d:Layout()
        local width = math.max(1, self.scroll:GetWidth() - 8)
        self.measure:SetWidth(math.max(1, width - 8))
        self.measure:SetHeight(0)
        self.measure:SetText(self.text or '')
        local height = math.max(self.scroll:GetHeight(), self.measure:GetStringHeight() + 12)
        self.content:SetSize(width, height)
        self.input:SetSize(width, height)
        self.scroll:UpdateWorkbenchScroll()
    end

    -- Hides the report and retires any request still in flight.
    function d:Hide()
        self.reportRequest = nil
        self.frame:Hide()
    end

    -- Shows a value as the report text. Each call supersedes the previous one; between every step the request is
    -- re-checked (and abandoned) because focus, layout and popup calls can run foreign scripts that close the window or
    -- switch profile.
    -- @param title string  The window title.
    -- @param value any  The report text (converted with tostring; nil is empty).
    -- @param context string|nil  The context line; nil means the addon name.
    -- @param help table|nil  Optional Help metadata for BindTransferHelp.
    function d:SetReport(title, value, context, help)
        local request = {}
        self.reportRequest = request
        local db = addon.db
        local profile, global, char = db.profile, db.global, db.char
        local displayed = false

        -- Tells whether this request is still the newest, the saved-data tables are the ones it started with, and (once
        -- displayed) the window is still shown.
        -- @return boolean  True while the request may continue.
        local function current()
            local shown = not displayed or self.frame:IsShown()

            return self.reportRequest == request
                and addon.db == db
                and db.profile == profile
                and db.global == global
                and db.char == char
                and shown
                and self.reportRequest == request
        end

        if not current() then
            return
        end

        local text = tostring(value or '')

        if not current() then
            return
        end

        self.text = text
        self.chrome:SetContext(title, L['Read-only'], context or addon.pretty_name)

        if not current() then
            return
        end

        self.setting = true
        self.input:SetText(text)

        if self.reportRequest ~= request then
            return
        end

        self.setting = false

        if not current() then
            return
        end

        self:Layout()

        if not current() then
            return
        end

        self.frame:Show()
        displayed = true

        if not current() then
            return
        end

        addon:OpenPopup(self)

        if not current() then
            return
        end

        self.input:SetFocus()

        if not current() then
            return
        end

        self.input:SetCursorPosition(0)

        if not current() then
            return
        end

        self.input:HighlightText(0, -1)

        if not current() then
            return
        end

        self.scroll.workbenchBar:SetValue(0)

        if not current() then
            return
        end

        addon:BindTransferHelp(self, help, current)
    end

    addon:SetUIScript(d.input, 'OnTextChanged', function()
        if not d.setting and d.input:GetText() ~= d.text then
            d.setting = true
            d.input:SetText(d.text or '')
            d.setting = false
        end

        d:Layout()
    end)

    addon:SetUIScript(d.input, 'OnCursorChanged', function(_, _, y, _, height)
        if d.setting or type(y) ~= 'number' then
            return
        end

        local top = -y
        local bar = d.scroll.workbenchBar
        d.scroll:UpdateWorkbenchScroll()

        if top < bar:GetValue() then
            bar:SetValue(top)
        elseif top + (height or 0) > bar:GetValue() + d.scroll:GetHeight() then
            bar:SetValue(top + (height or 0) - d.scroll:GetHeight())
        end
    end)

    addon:SetUIScript(d.copy, 'OnClick', function()
        d.input:SetFocus()
        d.input:SetCursorPosition(0)
        d.input:HighlightText(0, -1)
    end)

    addon:SetUIScript(d.close, 'OnClick', function()
        d:Hide()
    end)

    addon:SetUIScript(d.input, 'OnEscapePressed', function()
        d:Hide()
    end)

    addon:SetUIScript(d.frame, 'OnHide', function()
        d.reportRequest = nil
        d.input:ClearFocus()
    end)

    d.input:EnableMouseWheel(true)

    addon:SetUIScript(d.input, 'OnMouseWheel', function(_, delta)
        d.scroll.workbenchBar:SetValue(d.scroll.workbenchBar:GetValue() - delta * 40)
    end)

    return d
end

-- ============================================================================
-- Import/export dialog
-- ============================================================================

-- The import/export dialog's default width, and the room its bottom row keeps free: Copy and Clear (64 each) start at
-- 12 and 82, the review buttons start at 152, and the Import (100) and Cancel (100) buttons end 120 and 12 from the
-- right edge.
local TRANSFER_WIDTH = 570
local TRANSFER_REVIEW_LEFT = 152
local TRANSFER_BUTTON_GAP = 6
local TRANSFER_APPLY_RIGHT = 220

-- Sets the width of the import/export dialog and of everything sized from it (the text box, the original-name line, the
-- name box and the status line). The height never changes.
-- @param d table  The dialog record.
-- @param width number  The new width.
local function setTransferWidth(d, width)
    if d.frame:GetWidth() == width then
        return
    end

    d.frame:SetWidth(width)
    d.scroll:SetWidth(width - 50)
    d.input:SetWidth(width - 60)
    d.original:SetWidth(width - 24)
    d.name:SetWidth(width - 302)
    d.status:SetWidth(width - 24)
    d.scroll:UpdateWorkbenchScroll()
end

-- Opens the import/export dialog for a settings form, pre-filled with a text (formatted to the export line width). The
-- dialog is cached on p and each call starts a new serial, so a stale window or handler reports itself out of date.
-- With no options the window is a plain copy-or-replace box.
-- @param p table  The settings form.
-- @param title string  The window title.
-- @param text string  The text to show for export (may be empty).
-- @param apply function  Called on Import as apply(input, settings), inside p:WithSettingsHistory, with the pasted text
--   and, when `options` is given, { mode = 'new' or 'replace', name, originalName }; it returns ok and an error text.
-- @param options table|nil  canReplace, selectedName, fallbackName, originalName(input), valid(), review,
--   requirePreview and preview/inspect callbacks, onClose, invalidate and help.
-- @return table  The dialog.
function addon:ShowSettingsTextTransfer(p, title, text, apply, options)
    local d = p.textDialog

    if not d then
        d = self:CreateWorkbenchTransferShell(TRANSFER_WIDTH, 430)
        p.textDialog = d
        self:UseExportFont(d)
        d.original = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.original:SetPoint('TOPLEFT', 12, -36)
        d.original:SetSize(546, 22)
        d.original:SetJustifyH('LEFT')
        d.destination = addon:CreateWorkbenchCheckBox(d.frame, L['Replace selected entry'], 210)
        d.destination:SetPoint('TOPLEFT', 12, -62)
        d.nameLabel = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.nameLabel:SetPoint('TOPLEFT', 232, -62)
        d.nameLabel:SetSize(54, 24)
        d.nameLabel:SetText(L['Name'])
        d.name = addon:CreateWorkbenchEditBox(d.frame)
        d.name:SetPoint('TOPLEFT', 290, -62)
        d.name:SetSize(268, 24)
        d.name:SetMaxLetters(256)
        d.status = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.status:SetPoint('TOPLEFT', 12, -346)
        d.status:SetSize(546, 32)
        d.status:SetWordWrap(true)
        d.status:SetJustifyH('LEFT')
        d.preview = addon:CreateWorkbenchButton(d.frame, L['Preview import'], 90)
        d.preview:SetPoint('BOTTOMLEFT', TRANSFER_REVIEW_LEFT, 28)
        d.inspect = addon:CreateWorkbenchButton(d.frame, L['Check import'], 90)
        d.inspect:SetPoint('BOTTOMLEFT', d.preview, 'BOTTOMRIGHT', TRANSFER_BUTTON_GAP, 0)

        -- Closes the dialog; the OnHide script below does the cleanup.
        local function hide()
            d.frame:Hide()
        end

        addon:SetUIScript(d.cancel, 'OnClick', hide)
        addon:SetUIScript(d.close, 'OnClick', hide)

        addon:SetUIScript(d.frame, 'OnHide', function()
            d.input:ClearFocus()

            if d.options and d.options.review and addon.CloseTransferReview then
                addon:CloseTransferReview(p)
            end
            if d.options and d.options.onClose then
                d.options.onClose()
            end
        end)

        addon:SetUIScript(d.input, 'OnSizeChanged', function()
            d.scroll:UpdateWorkbenchScroll()
        end)

        addon:SetUIScript(d.input, 'OnCursorChanged', function(_, _, y, _, height)
            local top = -y
            local bar = d.scroll.workbenchBar
            d.scroll:UpdateWorkbenchScroll()

            if top < bar:GetValue() then
                bar:SetValue(top)
            elseif top + height > bar:GetValue() + d.scroll:GetHeight() then
                bar:SetValue(top + height - d.scroll:GetHeight())
            end
        end)

        d.input:EnableMouseWheel(true)

        addon:SetUIScript(d.input, 'OnMouseWheel', function(_, delta)
            local bar = d.scroll.workbenchBar
            bar:SetValue(bar:GetValue() - delta * 40)
        end)

        d.frame:Hide()
    end

    d.serial = (d.serial or 0) + 1
    local serial = d.serial
    local token = p.generation
    setTransferWidth(d, TRANSFER_WIDTH)

    -- Tells whether this opening is current: the settings form generation is unchanged, the dialog is still this one
    -- and shown, and the caller's own valid() agrees. The first check is repeated after options.valid() because that
    -- callback may close or replace the dialog.
    -- @return boolean  True while the dialog's handlers may act.
    local function valid()
        if not p:Valid(token) or p.textDialog ~= d or d.serial ~= serial or not d.frame:IsShown() then
            return false
        end
        if options and options.valid and not options.valid() then
            return false
        end

        return p:Valid(token) and p.textDialog == d and d.serial == serial and d.frame:IsShown()
    end

    d.chrome:SetContext(title, L['Import/Export'], addon.pretty_name or L['Rotation Master'])
    d.input:SetText(addon:FormatExportText(text))
    d.options = options
    d.mode = options and options.canReplace and 'replace' or 'new'
    d.nameDirty = false

    -- Runs a preview or inspect action safely. A button never does nothing in silence: a window that went stale says
    -- so, and an error is shown on the status line instead of vanishing.
    -- @param action function  The action to run.
    -- @param ... any  The arguments passed to the action.
    -- @return any  The action's result; nothing after writing the problem (stale window or a caught error) to the
    --   status line.
    --
    -- The first button follows the destination: replacing an entry compares the import with it, a new copy previews the
    -- import in full. The second one always checks the import for problems. A button grows with its label.
    local function run(action, ...)
        if not valid() then
            d.status:SetText(L['This import window is out of date. Close it and open it again.'])
            return
        end

        local ok, result = pcall(action, ...)

        if not ok then
            d.status:SetText(string.format(L['Import preview unavailable: %s'], tostring(result)))
            return
        end

        return result
    end

    -- Relabels the Preview and Check buttons for the destination mode (Compare when replacing), widens them to fit
    -- their text and then widens the window until both end before the Import button starts (a long label, for example
    -- Spanish "Previsualizar importación", would otherwise cover Import). Does nothing for dialogs without a preview or
    -- review.
    local function labels()
        if not (options.requirePreview or options.review) then
            return
        end

        local compare = d.mode == 'replace' and options.canReplace and true or false
        d.preview:SetText(compare and L['Compare import'] or L['Preview import'])
        d.preview.tooltip = compare and L['Help.Transfers.compare'] or L['Help.Transfers.preview']
        d.inspect:SetText(L['Check import'])
        d.inspect.tooltip = L['Help.Transfers.inspect']

        for _, button in ipairs({ d.preview, d.inspect }) do
            local label = button.GetFontString and button:GetFontString()

            if label and label.GetStringWidth then
                button:SetWidth(math.max(90, math.ceil(label:GetStringWidth() or 0) + 16))
            end
        end

        local needed = TRANSFER_REVIEW_LEFT
            + d.preview:GetWidth()
            + TRANSFER_BUTTON_GAP
            + d.inspect:GetWidth()
            + TRANSFER_BUTTON_GAP
            + TRANSFER_APPLY_RIGHT

        setTransferWidth(d, math.max(TRANSFER_WIDTH, needed))
    end

    -- Applies the current mode to the controls: checkbox state and enablement, and the name box (locked to the selected
    -- entry's name when replacing, editable with a suggested name when creating).
    local function destination()
        labels()
        d.destination:SetText(L['Replace selected entry'])
        d.destination:SetChecked(d.mode == 'replace')

        if options.canReplace then
            d.destination:Enable()
        else
            d.destination:Disable()
        end

        d.name:EnableMouse(d.mode == 'new')
        d.name:SetTextColor(d.mode == 'new' and 1 or .5, d.mode == 'new' and 1 or .5, d.mode == 'new' and 1 or .5)

        if d.mode == 'replace' then
            d.name:SetText(options.selectedName or '')
        else
            d.name:SetText(d.newName or options.fallbackName or '')
        end
    end

    -- Reads the original name out of the pasted text (without running any of it) and shows it, then suggests it as the
    -- new name unless the player has typed one.
    local function preview()
        if not valid() or not options then
            return
        end

        local ok, name = pcall(options.originalName, d.input:GetText())
        name = ok and type(name) == 'string' and name ~= '' and name or L['Name not supplied']
        d.original:SetText(L['Original name'] .. ': ' .. name)
        d.originalName = name

        if not d.nameDirty then
            d.newName = name ~= L['Name not supplied'] and name or options.fallbackName or ''
        end

        destination()
    end

    if options then
        d.original:Show()
        d.destination:Show()
        d.nameLabel:Show()
        d.name:Show()
        d.newName = options.fallbackName or ''
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint('TOPLEFT', 12, -98)
        d.scroll:SetHeight(232)
        d.input:SetHeight(232)

        addon:SetUIScript(d.destination, 'OnClick', function()
            if not valid() then
                d.status:SetText(L['This import window is out of date. Close it and open it again.'])
                return
            end

            if options.canReplace then
                d.mode = d.mode == 'replace' and 'new' or 'replace'
                destination()

                if options.review and addon.CloseTransferReview then
                    addon:CloseTransferReview(p)
                end
            end
        end)

        addon:SetUIScript(d.name, 'OnTextChanged', function(_, user)
            if user and valid() and d.mode == 'new' then
                d.nameDirty = true
                d.newName = d.name:GetText()
            end
        end)

        addon:SetUIScript(d.name, 'OnEscapePressed', function()
            d.frame:Hide()
        end)

        addon:SetUIScript(d.input, 'OnTextChanged', function(_, user)
            if user then
                preview()

                if options.review and addon.CloseTransferReview then
                    addon:CloseTransferReview(p)
                end
                if options.invalidate then
                    options.invalidate(d)
                end
            end
        end)

        d.status:SetText(
            L['Choose a new named copy or replace the selected editable entry. Review the destination before importing.']
        )
    else
        d.original:Hide()
        d.destination:Hide()
        d.nameLabel:Hide()
        d.name:Hide()
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint('TOPLEFT', 12, -40)
        d.scroll:SetHeight(300)
        d.input:SetHeight(300)
        addon:SetUIScript(d.input, 'OnTextChanged', nil)
        d.status:SetText(L['Copy this text to export. Import replaces the selected settings.'])
    end

    if options and options.requirePreview then
        d.preview:Show()
        d.inspect:Show()
        d.apply:Disable()
        d.inspect:Disable()

        addon:SetUIScript(d.preview, 'OnClick', function()
            run(options.preview, d)
        end)

        addon:SetUIScript(d.inspect, 'OnClick', function() return run(options.inspect, d) end)
    elseif options and options.review and addon.BuildTransferReview then
        -- Looking is optional here: Import is never gated, the buttons only show the import.
        local show, check = addon:BuildTransferReview(p, options.review)
        d.preview:Show()
        d.inspect:Show()
        d.apply:Enable()
        d.inspect:Enable()

        addon:SetUIScript(d.preview, 'OnClick', function()
            run(show, d)
        end)

        addon:SetUIScript(d.inspect, 'OnClick', function() return run(check, d) end)
    else
        d.preview:Hide()
        d.inspect:Hide()
        d.apply:Enable()
    end

    -- Clears the text box and its preview, and invalidates any review of the old text.
    addon:SetUIScript(d.clear, 'OnClick', function()
        if valid() then
            d.input:SetText('')
            d.input:SetFocus()
            d.input:SetCursorPosition(0)
            d.scroll.workbenchBar:SetValue(0)

            if options then
                preview()

                if options.invalidate then
                    options.invalidate(d)
                end
            end
        end
    end)

    addon:SetUIScript(d.copy, 'OnClick', function()
        if valid() then
            d.input:SetFocus()
            d.input:SetCursorPosition(0)
            d.input:HighlightText(0, -1)
        end
    end)

    -- Imports the pasted text: checks the new-entry name, calls the caller's apply inside one settings-history step,
    -- then closes the dialog and redraws the page, or shows the error on the status line.
    addon:SetUIScript(d.apply, 'OnClick', function()
        if not valid() then
            return
        end

        local settings

        if options then
            local name = d.mode == 'new' and d.name:GetText() or options.selectedName

            if d.mode == 'new' and (not name:find('%S') or #name > 256) then
                d.status:SetText(L['Enter a name first.'])
                return
            end

            settings = { mode = d.mode, name = name, originalName = d.originalName }
        end

        local result = p:WithSettingsHistory(function()
            local ok, why = apply(d.input:GetText(), settings)
            return { ok, why }
        end)

        if not valid() then
            return
        end

        local ok, why = result[1], result[2]

        if not ok then
            d.status:SetText(why or L['Invalid import.'])
            return
        end

        d.frame:Hide()
        p:Draw()
    end)

    d.frame:Show()
    d.scroll.workbenchBar:SetValue(0)
    d.scroll:UpdateWorkbenchScroll()
    addon:OpenPopup(d, p)

    if options then
        destination()
        preview()
    end

    self:BindTransferHelp(d, options and options.help, valid)
    return d
end
