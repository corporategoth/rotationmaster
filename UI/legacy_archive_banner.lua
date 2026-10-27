local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- A banner under the settings window's tabs while rotations from before
-- version 2 wait in the archive (Core/legacy_archive.lua). It points at
-- Recover unassigned rotations and can be dismissed; dismissing hides the
-- banner only. The count is read when the window opens and after an
-- adoption, never in layout.
local HEIGHT, GAP = 32, 4

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

    self:SetUIScript(banner.open, 'OnClick', function()
        if shell.section ~= 'Rotations' then shell:SelectSection('Rotations') end
        local pane = shell.pane
        if pane and pane.OpenRecovery then pane:OpenRecovery() end
    end)

    self:SetUIScript(banner.dismiss, 'OnClick', function()
        addon:DismissLegacyArchiveBanner()
        banner:Refresh()
        shell:Layout()
    end)

    -- Reads the archive; layout only asks Place.
    function banner:Refresh()
        self.count = addon.GetLegacyArchiveBanner and addon:GetLegacyArchiveBanner() or nil

        if self.count then
            self.text:SetText(
                string.format(
                    L['%d rotations from before version 2 are waiting in an archive and do not run until you adopt them.'],
                    self.count
                )
            )

            self.frame:Show()
        else
            self.frame:Hide()
        end
    end

    -- Anchor under the tabs at `y` (negative, from the window's top) and
    -- return the vertical space it takes, 0 when hidden.
    function banner:Place(x, y, width)
        if not self.count then return 0 end
        self.frame:ClearAllPoints()
        self.frame:SetPoint('TOPLEFT', window, 'TOPLEFT', x, y)
        self.frame:SetSize(math.max(1, width), HEIGHT)
        self.text:SetWidth(math.max(1, width - 8 - 220 - 80 - 24))
        return HEIGHT + GAP
    end

    return banner
end

function addon:RefreshLegacyArchiveBanner()
    local shell = self.configWindow

    if shell and shell.banner then
        shell.banner:Refresh()
        shell:Layout()
    end
end
