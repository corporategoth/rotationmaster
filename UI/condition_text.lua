-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Read-only text window for a full condition expression or a copyable report. It owns one lazily created dialog
-- (addon.conditionTextWindow) and never edits the text it shows: edits are reverted so the box stays selectable and
-- copyable only. Loaded from RotationMaster.toc after UI/condition_editor.lua; depends on the workbench chrome, button
-- and scroll helpers and on addon:OpenPopup and addon.HideOnEscape from the window layer.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Shows or hides a region.
-- @param region table  The region.
-- @param flag any  Truthy shows it.
local function visible(region, flag)
    if flag then
        region:Show()
    else
        region:Hide()
    end
end

-- A report longer than this many characters is shown a page at a time: one text box holding all of a long report can show
-- nothing at all, and a page that does not show also says which part to look at.
local PAGE_CHARACTERS = 5000

-- Splits a report into pages at line breaks.
-- @param text string  The report.
-- @return string[]  The pages, each at most PAGE_CHARACTERS long unless one line is longer.
local function paginate(text)
    local pages, current, size = {}, {}, 0

    for line in (text .. '\n'):gmatch('(.-)\n') do
        if size > 0 and size + #line + 1 > PAGE_CHARACTERS then
            pages[#pages + 1] = table.concat(current, '\n')
            current, size = {}, 0
        end

        current[#current + 1] = line
        size = size + #line + 1
    end

    pages[#pages + 1] = table.concat(current, '\n')
    return pages
end

-- Shows a full condition expression or a copyable report in the read-only text window.
-- @param value string  The text to show; anything else is ignored.
-- @param heading string|nil  The window heading; nil uses the default condition title. A heading switches the button to
--   "Copy report".
-- @return table|nil  The dialog table; nil when value is not a string.
--
-- Oversized expressions remain fully inspectable/copyable without letting a footer displace the condition tree or
-- adding a scrollbar to that footer.
function addon:ShowConditionText(value, heading)
    if type(value) ~= 'string' then
        return
    end

    local dialog = self.conditionTextWindow

    if not dialog then
        dialog = { frame = CreateFrame('Frame', nil, UIParent) }
        self.conditionTextWindow = dialog
        local frame = dialog.frame
        frame:SetSize(700, 400)
        frame:SetPoint('CENTER')
        frame:EnableMouse(true)
        local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        title:SetPoint('TOPLEFT', 12, -8)
        dialog.title = title
        dialog.chrome = self:CreateWorkbenchDialogChrome(frame, title)
        local scroll = addon:CreateWorkbenchScrollFrame(frame)
        scroll:SetPoint('TOPLEFT', 12, -36)
        scroll:SetSize(660, 300)
        dialog.scroll = scroll
        local edit = CreateFrame('EditBox', nil, scroll)
        dialog.edit = edit
        edit:SetMultiLine(true)

        -- A report is long: the box's default limit would cut it at a few hundred characters.
        if edit.SetMaxLetters then
            edit:SetMaxLetters(0)
        end
        if edit.SetMaxBytes then
            edit:SetMaxBytes(0)
        end

        edit:SetAutoFocus(false)
        edit:SetFontObject('GameFontHighlightSmall')
        edit:SetPoint('TOPLEFT')
        edit:SetWidth(650)
        edit:SetTextInsets(4, 4, 4, 4)
        scroll:SetScrollChild(edit)
        local setting = false

        -- Grows the edit box to fit its text so the scroll frame, not the box, provides scrolling. The game's own line
        -- count is not up to date until the box has been drawn once, so the height is never less than an estimate of the
        -- wrapped lines (about 95 characters to a line); a box left too short shows nothing of a page.
        local function resize()
            local text = edit:GetText() or ''
            local estimate = 0

            for line in (text .. '\n'):gmatch('(.-)\n') do
                estimate = estimate + math.max(1, math.ceil(#line / 95))
            end

            local lines = math.max(estimate, edit.GetNumLines and edit:GetNumLines() or 0)
            edit:SetHeight(math.max(24, lines * 14 + 16))
            scroll:UpdateScrollChildRect()
        end

        -- The box is a viewer: any typed or pasted change is undone by restoring the stored text.
        addon:SetUIScript(edit, 'OnTextChanged', function()
            if not setting and edit:GetText() ~= dialog.text then
                setting = true
                edit:SetText(dialog.text or '')
                setting = false
            end

            resize()
        end)

        -- Selects the whole text and scrolls to the top so the player can press Ctrl+C immediately.
        local function copy()
            edit:SetFocus()
            edit:SetCursorPosition(0)
            edit:HighlightText(0, -1)
            scroll:SetVerticalScroll(0)
        end

        dialog.copy = addon:CreateWorkbenchButton(frame, L['Copy full condition'], 150)
        dialog.copy:SetPoint('BOTTOMLEFT', 12, 26)
        addon:SetUIScript(dialog.copy, 'OnClick', copy)

        -- Page controls, shown only for a report that needed more than one page.
        dialog.prev = addon:CreateWorkbenchButton(frame, '<', 28)
        dialog.prev:SetPoint('LEFT', dialog.copy, 'RIGHT', 8, 0)
        dialog.next = addon:CreateWorkbenchButton(frame, '>', 28)
        dialog.next:SetPoint('LEFT', dialog.prev, 'RIGHT', 4, 0)
        dialog.pageLabel = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        dialog.pageLabel:SetPoint('LEFT', dialog.next, 'RIGHT', 8, 0)

        -- Shows one page of the report.
        -- @param page number  The page number, 1 to the number of pages.
        function dialog:ShowPage(page)
            page = math.max(1, math.min(#self.pages, page))
            self.page = page
            -- An empty line is held open by a space, so no page is only blank lines to the text box.
            self.text = self.pages[page]:gsub('\n\n', '\n \n'):gsub('\n\n', '\n \n')
            setting = true
            edit:SetText(self.text)
            setting = false
            resize()
            copy()

            -- Measured again once the box has been drawn.
            if C_Timer and type(C_Timer.After) == 'function' then
                C_Timer.After(0, resize)
            end

            self.pageLabel:SetText(string.format('%d / %d', page, #self.pages))
        end

        addon:SetUIScript(dialog.prev, 'OnClick', function()
            dialog:ShowPage(dialog.page - 1)
        end)

        addon:SetUIScript(dialog.next, 'OnClick', function()
            dialog:ShowPage(dialog.page + 1)
        end)

        dialog.close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        dialog.close:SetPoint('TOPRIGHT', -6, -6)

        addon:SetUIScript(dialog.close, 'OnClick', function()
            frame:Hide()
        end)

        addon:SetUIScript(edit, 'OnEscapePressed', function()
            frame:Hide()
        end)

        addon:SetUIScript(frame, 'OnHide', function()
            edit:ClearFocus()
        end)

        -- Window-registry interface: addon:OpenPopup and addon.HideOnEscape call Show and Hide on the dialog table.
        function dialog:Show()
            frame:Show()
        end

        -- Hides the dialog frame; the OnHide script drops edit focus.
        function dialog:Hide()
            frame:Hide()
        end

        -- Replaces the stored text and selects it for copying; the programmatic SetText is guarded by the setting flag.
        -- @param text string  The text to show.
        -- @param paged boolean|nil  True for a report: one that is long is shown a page at a time.
        function dialog:SetText(text, paged)
            self.pages = paged and #text > PAGE_CHARACTERS and paginate(text) or { text }
            local several = #self.pages > 1
            visible(self.prev, several)
            visible(self.next, several)
            visible(self.pageLabel, several)
            self:ShowPage(1)
        end

        addon.HideOnEscape(dialog)
    end

    dialog.chrome:SetContext(heading or L['Full condition text'], L['Report'], '')
    dialog.copy:SetText(heading and L['Copy report'] or L['Copy full condition'])
    dialog:Show()
    addon:OpenPopup(dialog)
    dialog:SetText(value, heading ~= nil)
    return dialog
end
