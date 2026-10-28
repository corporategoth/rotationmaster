-- Legacy archive banner: the strip under the settings window's tabs that tells the user rotations from before version 2
-- are waiting in the archive. It owns only its own frame and the dismiss click; the archive itself lives in
-- Core/legacy_archive.lua, and dismissing hides the banner without touching the archive.
-- Loaded last among the settings UI files (see RotationMaster.toc); UI/config.lua creates it with the shell, and
-- UI/rotation_browser.lua refreshes it after an adoption through addon:RefreshLegacyArchiveBanner.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- A banner under the settings window's tabs while rotations from before
-- version 2 wait in the archive (Core/legacy_archive.lua). It points at
-- Recover unassigned rotations and can be dismissed; dismissing hides the
-- banner only. The count is read when the window opens and after an
-- adoption, never in layout.
local HEIGHT, GAP = 32, 4

-- Builds the banner for the settings shell, hidden at first. The caller (UI/config.lua) owns the shell and must call
-- banner:Refresh when the window opens.
-- @param shell table  The settings shell.
-- @param window Frame  The settings window frame.
-- @return table  The banner { frame, Refresh(), Place(x, y, width) }.
function addon:CreateLegacyArchiveBanner(shell, window)
    local banner = { frame = CreateFrame('Frame', nil, window), count = nil }
    local frame = banner.frame
    local fill = frame:CreateTexture(nil, 'BACKGROUND')
    fill:SetAllPoints(frame)
    fill:SetColorTexture(.30, .23, .06, .95)
    banner.text = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    banner.text:SetJustifyH('LEFT')
    banner.text:SetPoint('LEFT', frame, 'LEFT', 8, 0)
    banner.dismiss = self:CreateWorkbenchButton(frame, L['Dismiss'], 80)
    banner.dismiss:SetPoint('RIGHT', frame, 'RIGHT', -6, 0)
    banner.open = self:CreateWorkbenchButton(frame, L['Recover unassigned rotations'], 220)
    banner.open:SetPoint('RIGHT', banner.dismiss, 'LEFT', -6, 0)
    frame:Hide()

    -- Opens Recover on the Rotations page. Leaving a page with unsaved edits asks first, so the window opens when the
    -- switch completes (never when the player keeps the edits).
    -- @param pane table|nil  The Rotations pane.
    local function openRecovery(pane)
        if pane and pane.OpenRecovery then
            pane:OpenRecovery()
        end
    end

    self:SetUIScript(banner.open, 'OnClick', function()
        if shell.section ~= 'Rotations' then
            shell:SelectSection('Rotations', nil, openRecovery)
        else
            openRecovery(shell.pane)
        end
    end)

    self:SetUIScript(banner.dismiss, 'OnClick', function()
        addon:DismissLegacyArchiveBanner()
        banner:Refresh()
        shell:Layout()
    end)

    -- Reads the archive and shows or hides the banner; layout only asks Place.
    function banner:Refresh()
        self.count = addon.GetLegacyArchiveBanner and addon:GetLegacyArchiveBanner() or nil

        if self.count then
            self.text:SetText(string.format(
                L['%d rotations from before version 2 are waiting in an archive and do not run until you adopt them.'],
                self.count
            ))

            self.frame:Show()
        else
            self.frame:Hide()
        end
    end

    -- Anchors the banner under the tabs.
    -- @param x number  The left offset.
    -- @param y number  The offset from the window's top (negative).
    -- @param width number  The width.
    -- @return number  The vertical space it takes; 0 when hidden.
    function banner:Place(x, y, width)
        if not self.count then
            return 0
        end

        self.frame:ClearAllPoints()
        self.frame:SetPoint('TOPLEFT', window, 'TOPLEFT', x, y)
        self.frame:SetSize(math.max(1, width), HEIGHT)
        self.text:SetWidth(math.max(1, width - 8 - 220 - 80 - 24))
        return HEIGHT + GAP
    end

    return banner
end

-- Re-reads the archive count and re-lays out the settings window; a no-op while no settings window exists.
function addon:RefreshLegacyArchiveBanner()
    local shell = self.configWindow

    if shell and shell.banner then
        shell.banner:Refresh()
        shell:Layout()
    end
end
