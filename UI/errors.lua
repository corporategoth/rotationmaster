-- The standalone "Rotation Master errors" window: a read-only, copyable view of the captured diagnostics reports
-- (addon.Diagnostics), one per page with previous/next, a redacted or original-text toggle and a clear button. Built
-- from raw frames on purpose, with none of the editor widgets, so it still opens when the main editor is what failed.
-- Owns no saved data; the reports belong to Diagnostics/. Loaded from RotationMaster.toc after UI/talent_popup.lua.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Errors in the main editor must not hide this independent native report.
-- Opens the window (building it on first use), always at the newest report with the redacted text selected.
function addon:ShowErrors()
    local window = self.errorsWindow

    if not window then
        window = CreateFrame("Frame", addon_name .. "Errors", UIParent)
        self.errorsWindow = window
        window:SetSize(760, 520)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:SetResizable(true)

        if window.SetResizeBounds then
            window:SetResizeBounds(600, 300)
        elseif window.SetMinResize then
            window:SetMinResize(600, 300)
        end

        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        local background = window:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.04, 1)
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText(L["Rotation Master errors"])
        local instructions = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", 16, -42)

        instructions:SetText(
            L["Review the report, then select Copy and press Ctrl+C. Reload after fixing a paused callback."]
        )

        -- Creates one bottom-row push button at horizontal offset `x`.
        local function button(label, width, x)
            local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
            b:SetSize(width, 24)
            b:SetPoint("BOTTOMLEFT", x, 12)
            b:SetText(label)
            return b
        end

        window.previous = button(L["Previous error"], 110, 16)
        window.next = button(L["Next error"], 100, 132)
        window.copy = button(L["Copy report"], 100, 238)
        window.clear = button(L["Clear RM errors"], 120, 344)
        window.original = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        window.original:SetSize(460, 24)
        window.original:SetPoint("BOTTOMLEFT", 16, 42)
        local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        close:SetSize(70, 24)
        close:SetPoint("TOPRIGHT", -12, -10)
        close:SetText(L["Close"])

        close:SetScript("OnClick", function()
            window:Hide()
        end)

        local resize = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        resize:SetSize(60, 24)
        resize:SetPoint("BOTTOMRIGHT", -12, 12)
        resize:SetText(L["Resize"])

        resize:SetScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                window:StartSizing("BOTTOMRIGHT")
            end
        end)

        resize:SetScript("OnMouseUp", function()
            window:StopMovingOrSizing()
        end)

        window:SetScript("OnHide", window.StopMovingOrSizing)

        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -66)
        scroll:SetPoint("BOTTOMRIGHT", -36, 80)
        local edit = CreateFrame("EditBox", nil, scroll)
        window.report = edit
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
        edit:SetFontObject(ChatFontNormal)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetWidth(696)
        scroll:SetScrollChild(edit)
        local setting = false

        -- Fits the edit box height to its wrapped lines so the scroll frame can scroll the whole report.
        local function sizeText()
            local _, fontHeight = edit:GetFont()
            edit:SetHeight(math.max(24, edit:GetNumLines() * (fontHeight or 12) + 16))
            scroll:UpdateScrollChildRect()
        end

        edit:SetScript("OnTextChanged", function()
            -- Replacing unchanged text resets the native selection/cursor.
            if not setting and edit:GetText() ~= (edit.reportText or "") then
                setting = true
                edit:SetText(edit.reportText or "")
                setting = false
            end

            sizeText()
        end)

        edit:SetScript("OnEscapePressed", function()
            edit:ClearFocus()
            window:Hide()
        end)

        window:SetScript("OnSizeChanged", function()
            edit:SetWidth(math.max(100, window:GetWidth() - 64))
            sizeText()
            instructions:SetWidth(math.max(100, window:GetWidth() - 32))
        end)

        -- Re-reads the report list and redraws the current page; clamps the index, so a cleared or shorter list is
        -- safe.
        window.Refresh = function()
            local reports = addon.Diagnostics:GetReports()
            local index = window.reportIndex or #reports
            index = math.max(1, math.min(index, #reports))
            window.reportIndex = index

            edit.reportText = reports[index] and addon.Diagnostics:FormatReport(
                reports[index].id,
                window.includeOriginal
            )
                or L["No Rotation Master errors have been captured this session."]

            window.original:SetText(
                window.includeOriginal and L["Use redacted error text"]
                    or L["Include original text (may contain names or code)"]
            )

            setting = true
            edit:SetText(edit.reportText)
            setting = false
            sizeText()
        end

        window.previous:SetScript("OnClick", function()
            window.reportIndex = window.reportIndex - 1
            window.Refresh()
        end)

        window.next:SetScript("OnClick", function()
            window.reportIndex = window.reportIndex + 1
            window.Refresh()
        end)

        window.copy:SetScript("OnClick", function()
            edit:SetFocus()
            edit:SetCursorPosition(0)
            edit:HighlightText(0, -1)
            scroll:SetVerticalScroll(0)
        end)

        window.clear:SetScript("OnClick", function()
            addon.Diagnostics:Clear()
            window.Refresh()
        end)

        window.original:SetScript("OnClick", function()
            window.includeOriginal = not window.includeOriginal
            window.Refresh()
        end)

        if UISpecialFrames then
            table.insert(UISpecialFrames, addon_name .. "Errors")
        end
    end

    window.reportIndex = nil
    window.includeOriginal = false
    window.Refresh()

    if self.ApplyWorkbenchScale then
        self:ApplyWorkbenchScale(window)
    end

    window:Show()

    -- An independent report: a peer window in the shared layering (Escape is its own UISpecialFrames entry).
    if self.OpenPopup then
        self:OpenPopup(window, nil, { escape = false, kind = "window" })
    end
end
