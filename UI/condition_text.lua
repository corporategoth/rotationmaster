-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Read-only text window for a full condition expression or a copyable report. It owns one lazily created dialog
-- (addon.conditionTextWindow) and never edits the text it shows: edits are reverted so the box stays selectable and
-- copyable only. Loaded from RotationMaster.toc after UI/condition_editor.lua; depends on the workbench chrome, button
-- and scroll helpers and on addon:OpenPopup and addon.HideOnEscape from the window layer.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

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
        edit:SetAutoFocus(false)
        edit:SetFontObject('GameFontHighlightSmall')
        edit:SetPoint('TOPLEFT')
        edit:SetWidth(650)
        edit:SetTextInsets(4, 4, 4, 4)
        scroll:SetScrollChild(edit)
        local setting = false

        -- Grows the edit box to fit its text so the scroll frame, not the box, provides scrolling. Falls back to an
        -- 80-column estimate on clients whose EditBox lacks GetNumLines.
        local function resize()
            local lines = edit.GetNumLines and edit:GetNumLines() or math.ceil(#(edit:GetText() or '') / 80)
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
        function dialog:SetText(text)
            self.text = text
            setting = true
            edit:SetText(text)
            setting = false
            resize()
            copy()
        end

        addon.HideOnEscape(dialog)
    end

    dialog.chrome:SetContext(heading or L['Full condition text'], L['Report'], '')
    dialog.copy:SetText(heading and L['Copy report'] or L['Copy full condition'])
    dialog:Show()
    addon:OpenPopup(dialog)
    dialog:SetText(value)
    return dialog
end
