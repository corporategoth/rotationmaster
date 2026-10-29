-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The main Rotation Master window ("config window"): title bar with version and client, UI scale control, one tab per
-- settings section, the page area that hosts the active pane, a footer with links, the page help, and the resize grip.
-- Owns the window shell only; each page is built elsewhere (addon:CreateRotationBrowser for Rotations,
-- addon:OpenNativeSettings for the rest) and is released whenever the section changes. Persists only
-- db.global.uiScale. addon:ShowConfig is the entry point (slash command, minimap, settings launcher). Loaded from
-- RotationMaster.toc after UI/function_bundle_transfer.lua and before UI/rotation_browser.lua.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Small helpers
-- ============================================================================

-- The settings tabs in display order; `value` is the section key every page lookup uses.
local sections = {
    { value = "Rotations", text = L["Rotations"] },
    { value = "General", text = L["General"] },
    { value = "Conditions", text = L["Conditions"] },
    { value = "Functions", text = L["Functions"] },
    { value = "Effects", text = L["Effects"] },
    { value = "ItemSets", text = L["Item Sets"] },
    { value = "Announces", text = L["Announces"] },
    { value = "Profiles", text = L["Profiles"] },
    { value = "Integrations", text = L["Integrations"] },
}

-- Normalizes a saved UI scale to 0.70 to 1.30 in 0.01 steps; anything else (nil, NaN, out of range) becomes 1.
-- @param value any  The saved scale.
-- @return number  The normalized scale.
local function scale(value)
    if type(value) ~= "number" or value ~= value or value < .7 or value > 1.3 then
        return 1
    end

    return math.floor(value * 100 + .5) / 100
end

-- Paints the whole frame with a solid color texture on the background layer.
-- @param frame Frame  The frame to paint.
-- @param r number  The red channel, 0 to 1.
-- @param g number  The green channel, 0 to 1.
-- @param b number  The blue channel, 0 to 1.
-- @param a number|nil  The alpha, 0 to 1; nil means 1.
-- @return Texture  The new texture.
local function fill(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(frame)
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

-- Creates a left-justified font string on `parent`.
-- @param parent Frame  The frame that owns the font string.
-- @param font string|nil  The font object name; nil means GameFontHighlightSmall.
-- @return FontString  The new font string.
local function text(parent, font)
    local result = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    result:SetJustifyH("LEFT")
    return result
end

-- A workbench button; the name keeps call sites short.
-- @param parent Frame  The parent frame.
-- @param label string  The button text.
-- @param width number  The button width.
-- @return Button  The new button.
local function flatButton(parent, label, width)
    return addon:CreateWorkbenchButton(parent, label, width)
end

-- True when the pointer is over `content` itself (or a descendant of it) rather than a window stacked above it.
-- @param content Frame  The page area frame.
-- @return boolean|nil  True when the pointer is over the content; false when it is over a window above it or over a
--   control flagged `rmOwnsRightClick` (a reference field, the spell icon); nil on a client with no focus or mouse-over
--   API.
--
-- Geometry alone includes windows underneath other addons. Only a focused descendant can originate a content click when
-- the client exposes focus. Uses the mouse-focus API of whichever client generation is running, falling back to a plain
-- geometry test. The rmOwnsRightClick control gives the right click its own meaning, and UI/window.lua's dialog close
-- honors the same flag.
local function contentHasFocus(content)
    local focus

    if type(GetMouseFoci) == "function" then
        focus = GetMouseFoci()[1]
    elseif type(GetMouseFocus) == "function" then
        focus = GetMouseFocus()
    else
        local over = InputUtil and InputUtil.IsMouseOver or MouseIsOver
        return over and over(content)
    end

    for _ = 1, 100 do
        if focus == content then
            return true
        end
        if not focus or type(focus.GetParent) ~= "function" then
            return false
        end
        if focus.rmOwnsRightClick then
            return false
        end

        focus = focus:GetParent()
    end

    return false
end

-- Reads a field from the addon's TOC (Version, Author, X-Website, ...).
-- @param key string  The TOC field name.
-- @return string|nil  The value; nil when missing or empty.
local function metadata(key)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

    if type(getter) == "function" then
        local ok, value = pcall(getter, addon_name, key)

        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
end

-- Draws a one-pixel gray border over `button` (the selected-tab outline).
-- @param button Button  The button to outline.
-- @return Frame  The border frame.
local function outline(button)
    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints(button)
    border:EnableMouse(false)

    for _, edge in ipairs({
        { first = "TOPLEFT", last = "TOPRIGHT", horizontal = true },
        { first = "BOTTOMLEFT", last = "BOTTOMRIGHT", horizontal = true },
        { first = "TOPLEFT", last = "BOTTOMLEFT" },
        { first = "TOPRIGHT", last = "BOTTOMRIGHT" },
    }) do
        local line = border:CreateTexture(nil, "OVERLAY")
        line:SetPoint(edge.first, border, edge.first, 0, 0)
        line:SetPoint(edge.last, border, edge.last, 0, 0)
        line:SetColorTexture(.62, .66, .69, 1)

        if edge.horizontal then
            line:SetHeight(1)
        else
            line:SetWidth(1)
        end
    end

    return border
end

-- The one-line description of each section, shown beside the tab title and as the tab's help tooltip.
local descriptions = {
    Rotations = L["Browse, view and edit rotations."],
    General = L["Configure recommendations and display."],
    Conditions = L["Organize condition types and custom conditions."],
    Functions = L['Browse packaged helpers and edit reusable custom Lua functions.'],
    Effects = L["Configure highlight effects."],
    ItemSets = L["Manage interchangeable items and consumables."],
    Announces = L["Configure optional announcements."],
    Profiles = L["Manage saved configuration profiles."],
    Integrations = L['Choose optional addon integrations.'],
    About = L["Rotation Master information and credits."],
}

-- ============================================================================
-- The window shell
-- ============================================================================

-- Builds the window, its controls and every shell method once; addon:ShowConfig keeps the result in addon.configWindow.
-- The window is a peer window in the shared layering.
-- @return table  The shell table ({ frame, tabs, pane, ... }).
local function newShell()
    local window = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, UIParent))
    window:SetSize(1120, 760)
    window:SetPoint("CENTER")
    window:SetClampedToScreen(true)

    -- The window keeps itself inside the screen by resizing (ApplySizeBounds), so its scale is never reduced to fit.
    window.rmFitsOwnSize = true
    window:SetMovable(true)
    window:SetResizable(true)
    window:EnableMouse(true)
    local layout = addon.WorkbenchLayout
    local minimumWidth, minimumHeight = layout.windowMinWidth, layout.windowMinHeight
    local shell = { frame = window, tabs = {}, buttons = {}, settingsPanes = {} }

    -- Sets the resize limits (minimum from the layout table, maximum the visible screen) and clamps the current size.
    -- @return boolean  True when the size had to change.
    --
    -- Sizing stays within the supported minimum and the visible screen. Older clients only provide SetMinResize, and a
    -- size restored or set by another addon is corrected on the next layout as well.
    function shell:ApplySizeBounds()
        local scale = window:GetScale() or 1

        if scale <= 0 then
            scale = 1
        end

        local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()

        -- A screen smaller than the minimum cannot bound the window usefully.
        local maximumWidth = type(screenWidth) == 'number' and screenWidth / scale >= minimumWidth and math.floor(
            screenWidth / scale
        )
            or nil

        local maximumHeight = type(screenHeight) == 'number' and screenHeight / scale >= minimumHeight and math.floor(
            screenHeight / scale
        )
            or nil

        self.maximumWidth, self.maximumHeight = maximumWidth, maximumHeight

        if window.SetResizeBounds then
            window:SetResizeBounds(minimumWidth, minimumHeight, maximumWidth or 100000, maximumHeight or 100000)
        else
            if window.SetMinResize then
                window:SetMinResize(minimumWidth, minimumHeight)
            end
            if window.SetMaxResize then
                window:SetMaxResize(maximumWidth or 100000, maximumHeight or 100000)
            end
        end

        return self:ClampSize()
    end

    -- Resizes the window into the current bounds.
    -- @return boolean  True when the size had to be corrected.
    function shell:ClampSize()
        local width, height = window:GetWidth(), window:GetHeight()
        local wantedWidth = math.max(minimumWidth, self.maximumWidth and math.min(width, self.maximumWidth) or width)

        local wantedHeight = math.max(
            minimumHeight,
            self.maximumHeight and math.min(height, self.maximumHeight) or height
        )

        if wantedWidth == width and wantedHeight == height then
            return false
        end

        window:SetSize(wantedWidth, wantedHeight)
        return true
    end

    -- The main window is a peer window: opening it (or opening it again) brings it, and anything it opened, to the
    -- front.
    shell.rmLayerKind = "window"

    -- Shows the window and raises it above other peer windows.
    function shell:Show()
        self.frame:Show()
        addon:RaiseWindow(self)
    end

    -- Hides the window. A settings form with unsaved changes is asked first (RequestLeave).
    -- @param approved boolean|nil  True skips the ask.
    -- @return any  What the pane's RequestLeave returns when it deferred to the ask; nil otherwise.
    function shell:Hide(approved)
        local pane = self.pane

        if not approved and pane and pane.isSettingsForm then
            return pane:RequestLeave(function()
                if self.pane == pane then
                    self:Hide(true)
                end
            end)
        end

        self.frame:Hide()
    end

    fill(window, .075, .08, .085)
    local titleArt = window:CreateTexture(nil, "BACKGROUND")
    titleArt:SetPoint("TOPLEFT", 1, -1)
    titleArt:SetPoint("TOPRIGHT", -1, -1)
    titleArt:SetHeight(38)
    titleArt:SetColorTexture(.12, .125, .13, 1)

    for _, edge in ipairs({
        { first = "TOPLEFT", last = "TOPRIGHT", horizontal = true },
        { first = "BOTTOMLEFT", last = "BOTTOMRIGHT", horizontal = true },
        { first = "TOPLEFT", last = "BOTTOMLEFT" },
        { first = "TOPRIGHT", last = "BOTTOMRIGHT" },
    }) do
        local border = window:CreateTexture(nil, "BORDER")
        border:SetColorTexture(.33, .35, .37, 1)
        border:SetPoint(edge.first, window, edge.first, 0, 0)
        border:SetPoint(edge.last, window, edge.last, 0, 0)

        if edge.horizontal then
            border:SetHeight(1)
        else
            border:SetWidth(1)
        end
    end

    local title = text(window, "GameFontNormal")
    shell.title = title
    title:SetPoint("TOPLEFT", 184, -6)
    title:SetText(addon.pretty_name)
    title:SetTextColor(.94, .95, .96)
    shell.activeTitle = text(window)
    shell.activeTitle:SetPoint("TOPLEFT", 184, -23)
    shell.activeTitle:SetTextColor(.65, .69, .72)
    shell.icon = window:CreateTexture(nil, "ARTWORK")
    shell.icon:SetSize(26, 26)
    shell.icon:SetPoint("TOPLEFT", 150, -6)
    shell.icon:SetTexture(addon.logoTexture)
    local drag = CreateFrame("Frame", nil, window)
    shell.header = drag
    drag:SetPoint("TOPLEFT", window, "TOPLEFT", 140, 0)
    drag:SetPoint("TOPRIGHT", window, "TOPRIGHT", -300, 0)
    drag:SetHeight(38)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")

    addon:SetUIScript(drag, "OnDragStart", function()
        window:StartMoving()
    end)

    addon:SetUIScript(drag, "OnDragStop", function()
        window:StopMovingOrSizing()
    end)

    local close = addon:CreateWorkbenchIconButton(window, "close", L["Close"])
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)

    addon:SetUIScript(close, "OnClick", function()
        shell:Hide()
    end)

    shell.close = close
    shell.help = addon:CreateWorkbenchHelpButton(window, L["Help"])
    shell.help:SetPoint("TOPRIGHT", -31, -5)
    shell.help:SetSize(20, 20)
    shell.help.icon:SetSize(18, 18)
    shell.version = text(window)
    shell.version:SetPoint("TOPRIGHT", -62, -8)
    shell.version:SetJustifyH("RIGHT")
    shell.version:SetWordWrap(false)
    shell.version:SetWidth(230)
    local client = addon.Platform and addon.Platform:GetClientInfo() or {}

    local edition = ({
        tbc = L["TBC"],
        era = L["Classic Era"],
        progression = L["Classic Progression"],
        retail = L["Retail"],
        forever = L["Forever"],
    })[client.family] or L["Unknown"]

    local version = metadata("Version") or L["Unknown"]

    if version:find("@", 1, true) then
        version = L["Development"]
    end

    shell.version:SetText(version)
    shell.edition = text(window)
    shell.edition:SetPoint("TOPRIGHT", -62, -23)
    shell.edition:SetJustifyH("RIGHT")
    shell.edition:SetWordWrap(false)
    shell.edition:SetWidth(230)
    shell.edition:SetText(edition .. (client.version and " " .. client.version or ""))
    local content = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, window))
    shell.content = content
    content:EnableMouse(true)
    -- The page "?" sits in the top-right corner of the content, on the page's
    -- first row; panes leave that corner free (content.rmHelpReserve).
    content.rmHelpReserve = addon.WorkbenchLayout.helpReserve
    local paneHeader = addon:TrackWorkbenchSize(CreateFrame('Frame', nil, window))
    shell.paneHeader = paneHeader
    shell.pageHelp = addon:CreateWorkbenchHelpButton(paneHeader, L['Help'])
    shell.pageHelp:SetPoint('TOPRIGHT', 0, 0)
    shell.pageHelp:SetSize(20, 20)
    shell.pageHelp.icon:SetSize(18, 18)

    addon:SetUIScript(content, "OnMouseDown", function(_, button)
        if button == "RightButton" and not shell.rightDown and contentHasFocus(content) then
            shell:Hide()
        end
    end)

    addon:SetUIScript(content, "OnUpdate", function()
        local down = IsMouseButtonDown and IsMouseButtonDown("RightButton")
        local frontmost = _G.RotationMasterFrontmostDialog

        if frontmost and frontmost ~= window then
            shell.rightDown = down
            return
        end

        if down and not shell.rightDown and contentHasFocus(content) then
            shell:Hide()
        end

        shell.rightDown = down
    end)

    local footer = CreateFrame("Frame", nil, window)
    shell.footer = footer
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(20)
    fill(footer, .09, .10, .11)
    shell.author = text(footer)
    shell.author:SetPoint("LEFT", 8, 0)
    shell.author:SetText(string.format(L["Created by %s"], metadata("Author") or L["Unknown"]))
    shell.author:SetWidth(160)
    shell.closeHint = text(footer)
    shell.closeHint:SetPoint("RIGHT", -24, 0)
    shell.closeHint:SetText(L["Right-click to close"])
    shell.status = text(footer)
    shell.status:SetPoint("LEFT", 174, 0)
    shell.status:SetTextColor(.65, .69, .72)
    shell.scaleLabel = text(window)
    shell.scaleLabel:SetPoint("TOPLEFT", 12, -5)
    shell.scaleValue = addon:CreateWorkbenchEditBox(window)
    shell.scaleValue:SetPoint('TOPLEFT', 94, -2)
    shell.scaleValue:SetSize(38, 18)
    shell.scaleValue:SetMaxLetters(3)
    shell.scaleSlider = addon:CreateWorkbenchSlider(window, 70, 130, 1, 116)
    shell.scaleSlider:SetPoint("TOPLEFT", 12, -22)

    -- Applies a UI scale to this window and all other workbench windows.
    -- @param value number  The scale, normalized to 0.70 to 1.30.
    -- @param persist boolean|nil  True also saves it to db.global.uiScale.
    function shell:ApplyScale(value, persist)
        local selected = scale(value)
        window:SetScale(selected)
        self:ApplySizeBounds()

        if persist then
            addon.db.global.uiScale = selected
        end

        addon:ScaleWorkbenchWindows(selected)
        self.settingScale = true
        self.scaleSlider:SetValue(math.floor(selected * 100 + .5))
        self.settingScale = false
        self.scaleLabel:SetText(L["Scale"] .. ":")
        self.scaleValue:SetText(tostring(math.floor(selected * 100 + .5)))
        self.scaleValue:SetTextColor(1, 1, 1)
    end

    addon:SetUIScript(shell.scaleValue, 'OnEnterPressed', function(c)
        local n = tonumber(c:GetText())

        if n and n >= 70 and n <= 130 and n % 1 == 0 then
            shell:ApplyScale(n / 100, true)
            c:ClearFocus()
        else
            c:SetTextColor(1, .35, .35)
        end
    end)

    addon:SetUIScript(shell.scaleValue, 'OnEscapePressed', function(c)
        c:SetText(tostring(math.floor(scale(addon.db.global.uiScale) * 100 + .5)))
        c:SetTextColor(1, 1, 1)
        c:ClearFocus()
    end)

    addon:SetUIScript(shell.scaleSlider, "OnMouseDown", function(_, button)
        if button == "LeftButton" then
            shell.scaleDragging = true
        end
    end)

    -- Applies the scale chosen while dragging the slider; during the drag only the number box is updated.
    local function finishScale()
        local selected = shell.pendingScale
        shell.pendingScale = nil
        shell.scaleDragging = false

        if selected then
            shell:ApplyScale(selected, true)
        end
    end

    addon:SetUIScript(shell.scaleSlider, "OnMouseUp", function(_, button)
        if button == "LeftButton" then
            finishScale()
        end
    end)

    addon:SetUIScript(shell.scaleSlider, "OnUpdate", function()
        if shell.scaleDragging and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            finishScale()
        end
    end)

    addon:SetUIScript(shell.scaleSlider, "OnValueChanged", function(_, value)
        if shell.settingScale then
            return
        end

        local selected = math.max(.7, math.min(1.3, value / 100))

        if shell.scaleDragging then
            shell.pendingScale = selected
            shell.scaleValue:SetText(tostring(math.floor(selected * 100 + .5)))
        else
            shell:ApplyScale(selected, true)
        end
    end)

    shell.banner = addon.CreateLegacyArchiveBanner and addon:CreateLegacyArchiveBanner(shell, window) or nil
    local linkPane = CreateFrame("Frame", nil, window)
    shell.linkPane = linkPane
    linkPane:SetSize(520, 72)
    linkPane:SetPoint("BOTTOM", 0, 28)
    fill(linkPane, .07, .08, .09)
    shell.linkInput = addon:CreateWorkbenchEditBox(linkPane)
    shell.linkInput:SetPoint("TOPLEFT", 12, -12)
    shell.linkInput:SetSize(496, 24)

    addon:SetUIScript(shell.linkInput, "OnEscapePressed", function()
        linkPane:Hide()
    end)

    local linkClose = flatButton(linkPane, L["Close"], 70)
    linkClose:SetPoint("BOTTOMRIGHT", -12, 4)

    addon:SetUIScript(linkClose, "OnClick", function()
        linkPane:Hide()
    end)

    addon:SetUIScript(linkPane, "OnHide", function()
        shell.linkInput:ClearFocus()
    end)

    linkPane:Hide()
    addon:OpenPopup({ frame = linkPane }, window)

    -- Opens the copy box with `url` selected, because an addon cannot open a browser.
    -- @param url string  The address to show.
    function shell:ShowLink(url)
        linkPane:Show()
        self.linkInput:SetText(url)
        self.linkInput:SetFocus()
        self.linkInput:SetCursorPosition(0)
        self.linkInput:HighlightText(0, -1)
    end

    local links = {}

    for _, entry in ipairs({
        { key = "website", label = L["Website"], url = metadata("X-Website") },
        { key = "discord", label = "Discord", url = metadata("X-Discord") },
    }) do
        if entry.url and entry.url:match("^https?://") then
            local link = flatButton(footer, entry.label, 90)
            link:SetSize(link:GetFontString():GetStringWidth() + 12, 18)
            link.tooltip = entry.url

            addon:SetUIScript(link, "OnClick", function()
                shell:ShowLink(entry.url)
            end)

            shell[entry.key] = link
            links[#links + 1] = link
        end
    end

    local linksWidth = 0

    for _, link in ipairs(links) do
        linksWidth = linksWidth + link:GetWidth() + 6
    end

    shell.footerLinksWidth = linksWidth
    local linkX = -linksWidth / 2

    for _, link in ipairs(links) do
        link:SetPoint("LEFT", footer, "CENTER", linkX, 0)
        linkX = linkX + link:GetWidth() + 6
    end

    -- Closes the help dialog and invalidates any help request still in flight.
    function shell:CloseHelp()
        self.helpRequest = nil
        local dialog = self.helpDialog
        self.helpDialog = nil

        if dialog then
            dialog:Hide()
        end
    end

    -- Opens the help dialog for a page `topic`; the request is dropped if a newer one starts first.
    -- @param topic string|nil  The section key; nil for the window help.
    -- @param valid function|nil  Returns false to withdraw the request, for example when its pane was replaced.
    function shell:ShowHelp(topic, valid)
        local request = {}
        self.helpRequest = request
        local heading = topic and (topic == 'ItemSets' and L['Item Sets'] or L[topic]) or L['Workbench Help']

        local dialog = addon:OpenWorkbenchHelp({
            heading = heading,
            owner = addon.pretty_name,
            -- True while this help request is still the newest, the window is shown and the page has not withdrawn it.
            -- @return boolean  True when the help should stay open.
            valid = function()
                return self.helpRequest == request and self.frame:IsShown() and (not valid or valid())
            end,
            sections = function() return topic and addon:WorkbenchPageHelp(topic) or addon:WorkbenchWindowHelp() end,
        })

        if self.helpRequest ~= request then
            return
        end

        self.helpDialog = dialog

        if dialog then
            self.helpPane = dialog.frame
        end
    end

    addon:SetUIScript(shell.help, 'OnClick', function()
        shell:ShowHelp()
    end)

    addon:BindWorkbenchHelp(shell.help, {
        brief = L["Explain window navigation, scaling, closing and drafts."],
        valid = function() return window:IsShown() end,
    })

    for _, control in ipairs({ shell.scaleSlider, shell.scaleValue }) do
        addon:BindWorkbenchHelp(control, {
            brief = L["Set the workbench and child-window scale from 70% to 130%; enter a whole percentage or drag the slider."],
            valid = function() return window:IsShown() end,
        })
    end

    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 0)
    local texture = grip:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(grip)
    texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    addon:SetUIScript(grip, "OnMouseDown", function(_, button)
        if button == "LeftButton" then
            window:StartSizing("BOTTOMRIGHT")
        end
    end)

    addon:SetUIScript(grip, "OnMouseUp", function()
        window:StopMovingOrSizing()
    end)

    shell.grip = grip

    -- Wires the page "?" button to the pane that was just opened. The captured profile, pane and generation make a
    -- stale click (profile switched, section changed) do nothing.
    function shell:BindPaneHelp()
        local pane, key, generation = self.pane, self.section, addon.configPaneGeneration
        local profile, global, char = addon.db.profile, addon.db.global, addon.db.char

        -- True while the pane, section, generation and profile this button was bound for are still the live ones.
        -- @return boolean  True when nothing has changed since the button was bound.
        local function current()
            return self.frame:IsShown()
                and self.pane == pane
                and self.section == key
                and addon.configPaneGeneration == generation
                and addon.db.profile == profile
                and addon.db.global == global
                and addon.db.char == char
        end

        addon:SetUIScript(self.pageHelp, 'OnClick', addon:GuardWorkbenchHelp(current, function()
            self:ShowHelp(key, current)
        end))

        addon:BindWorkbenchHelp(self.pageHelp, {
            brief = L["Open full Help for this page without switching tabs or applying edits."],
            valid = current,
        })

        local existing = pane.fields and pane.fields.announce_help
        -- The page "?" shares the first row; it never adds header height.
        self.paneHeaderHeight = 0

        if existing and existing:IsShown() then
            self.pageHelp:Hide()
            self.paneHeader:Hide()
        else
            self.pageHelp:Show()
            self.paneHeader:Show()
        end

        self:Layout()
    end

    -- Retires the current page: bumps the pane generation (invalidating its callbacks) and releases it.
    function shell:ReleasePane()
        self.pageHelp:Hide()
        addon.configPaneGeneration = (addon.configPaneGeneration or 0) + 1
        addon.currentConditionEval = nil
        addon.specTab = nil
        -- Clear pending native focus before retiring the current pane.
        addon:ClearConditionWidgetFocus()

        if self.pane then
            local pane = self.pane
            self.pane = nil

            if self.nativePane then
                pane:Release()
            end

            self.nativePane = nil
        end
    end

    -- Wraps the tabs onto rows, then sizes the page area, header, status text and the pane to the window.
    function shell:Layout()
        local width, height = window:GetWidth(), window:GetHeight()
        local x, y = 12, -42

        for _, tab in ipairs(self.tabs) do
            local tabWidth = tab:GetWidth()

            if x + tabWidth > width - 12 then
                x = 12
                y = y - 24
            end

            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
            x = x + tabWidth + 2
        end

        local top = -y + 28

        if self.banner then
            top = top + self.banner:Place(12, y - 28, width - 24)
        end

        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -top)
        local contentWidth, contentHeight = math.max(1, width - 24), math.max(1, height - top - 28)
        paneHeader:ClearAllPoints()
        paneHeader:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0)
        paneHeader:SetSize(20, 20)
        paneHeader:SetFrameLevel(content:GetFrameLevel() + 50)
        content:SetSize(contentWidth, contentHeight)
        -- Status text ends before the centred footer links.
        self.status:SetWidth(math.max(1, width / 2 - (self.footerLinksWidth or 0) / 2 - 174 - 8))
        self.title:SetWidth(math.max(1, width - 490))
        self.activeTitle:SetWidth(math.max(1, width - 490))
        self.activeTitle:SetWordWrap(false)

        if self.pane then
            self.pane:SetWidth(contentWidth)
            self.pane:SetHeight(contentHeight)
        end
    end

    -- Rebuilds the tab buttons from `sections`, reusing pooled buttons, and lays them out.
    function shell:RefreshTabs()
        self.tabGeneration = (self.tabGeneration or 0) + 1
        local generation = self.tabGeneration
        local entries = {}

        for _, entry in ipairs(sections) do
            entries[#entries + 1] = entry
        end

        self.tabs = {}

        for index, entry in ipairs(entries) do
            local tab = self.buttons[index]

            if not tab then
                tab = flatButton(window, "", 88)
                self.buttons[index] = tab
                tab.border = outline(tab)
            end

            tab.section = entry.value
            tab:SetText(entry.text)
            tab:SetSize(math.min(180, math.max(64, tab:GetFontString():GetStringWidth() + 18)), 22)
            local key = entry.value
            local text = tab:GetFontString()
            text:ClearAllPoints()
            text:SetPoint('LEFT', 8, 0)

            -- True while the tab strip is the one that built this tab (a rebuild invalidates old help requests).
            -- @return boolean  True when the window is shown and the tabs were not rebuilt since.
            local function current()
                return self.frame:IsShown() and self.tabGeneration == generation
            end

            addon:BindWorkbenchHelp(tab, { brief = descriptions[key], valid = current })

            addon:SetUIScript(tab, "OnClick", function()
                self:SelectSection(key)
            end)

            tab:Show()
            self.tabs[#self.tabs + 1] = tab
        end

        for index = #entries + 1, #self.buttons do
            self.buttons[index]:Hide()
        end

        self:Layout()
    end

    -- Switches to section `key`. A page with unsaved changes is asked first. Shows a placeholder pane when the page
    -- cannot be built.
    -- @param key string  The section key; unknown keys fall back to Rotations.
    -- @param approved boolean|nil  True means the unsaved-changes ask was already answered.
    -- @param after function|nil  Called with the new pane once the switch has happened, which is later than this call
    --   when a prompt is answered first, and never when the player keeps the unsaved page.
    -- @return any  What the pane's RequestLeave returns when the switch was deferred to the ask; nil otherwise.
    function shell:SelectSection(key, approved, after)
        if not approved and self.pane and self.nativePane and self.pane.RequestLeave then
            -- Native editors preserve their pending changes at this boundary.
            ---@type any
            local current = self.pane

            return current:RequestLeave(function()
                if self.pane == current and self.frame:IsShown() then
                    self:SelectSection(key, true, after)
                end
            end)
        end

        self:CloseHelp()
        self.linkPane:Hide()
        local found = false

        for _, tab in ipairs(self.tabs) do
            if tab.section == key then
                found = true
                break
            end
        end

        if not found then
            key = "Rotations"
        end

        self:ReleasePane()
        self.section = key

        for _, tab in ipairs(self.tabs) do
            local selected = tab.section == key
            tab:SetSelected(selected)

            if selected then
                tab.border:Show()
                tab:GetFontString():SetTextColor(.94, .95, .96)
            else
                tab.border:Hide()
                tab:GetFontString():SetTextColor(.72, .75, .78)
            end

            if selected then
                self.activeTitle:SetText(tab:GetText() .. " · " .. (descriptions[key] or L["Optional addon settings."]))
                self.status:SetText("")
            end
        end

        if key == "Rotations" and addon.CreateRotationBrowser then
            self.nativePane = true
            self.pane = addon:CreateRotationBrowser(content, addon.configRotationSelection)
            self:BindPaneHelp()

            if after then
                after(self.pane)
            end

            return
        end

        if addon.OpenNativeSettings then
            local pane = addon:OpenNativeSettings(content, key, self.settingsPanes[key])

            if pane then
                self.nativePane = true
                self.pane = pane
                self.settingsPanes[key] = pane
                self:BindPaneHelp()

                if after then
                    after(self.pane)
                end

                return
            end
        end

        local pane = self.unavailablePane

        if not pane then
            pane = { frame = CreateFrame('Frame', nil, content) }
            self.unavailablePane = pane
            pane.frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
            pane.message = text(pane.frame)
            pane.message:SetPoint('TOPLEFT', 8, -8)
            pane.message:SetWordWrap(true)

            -- Sets the placeholder's width and wraps its message to fit.
            -- @param width number  The width.
            function pane:SetWidth(width)
                self.frame:SetWidth(width)
                self.message:SetWidth(math.max(1, width - 16))
            end

            -- Sets the placeholder frame's height.
            -- @param height number  The height.
            function pane:SetHeight(height)
                self.frame:SetHeight(height)
            end

            -- Hides the placeholder when the section changes.
            function pane:Release()
                self.frame:Hide()
            end
        end

        pane.message:SetText(string.format(L['Native settings page unavailable: %s'], key))
        pane:SetWidth(content:GetWidth())
        pane:SetHeight(content:GetHeight())
        pane.frame:Show()
        self.nativePane = true
        self.pane = pane
        self:BindPaneHelp()

        if after then
            after(self.pane)
        end
    end

    -- The client reports a sizing drag here; lay out with the reported size.
    addon:SetUIScript(window, "OnSizeChanged", function()
        if not shell:ClampSize() then
            shell:Layout()
        end
    end)

    addon:SetUIScript(window, "OnHide", function()
        shell.scaleDragging = false
        shell.pendingScale = nil
        addon:SetUIScript(window, "OnUpdate", nil)
        shell:CloseHelp()
        shell.linkPane:Hide()
        shell.linkInput:ClearFocus()
        shell:ReleasePane()
    end)

    addon.HideOnEscape(shell)
    return shell
end

-- ============================================================================
-- Public entry points
-- ============================================================================

-- Opens the window on `section`, built from native settings forms and owned editor panes.
-- @param section string|nil  The section key; defaults to Rotations.
-- @param selection table|nil  { spec, id } to preselect a rotation.
-- @return table  The shell.
function addon:ShowConfig(section, selection)
    self.configRotationSelection = selection
    self:SetupOptions()

    if not self.configWindow then
        self.configWindow = newShell()
    end

    local shell = self.configWindow
    shell:ApplyScale(self.db.global.uiScale, false)
    shell.rightDown = IsMouseButtonDown and IsMouseButtonDown("RightButton")

    if shell.banner then
        shell.banner:Refresh()
    end

    shell:RefreshTabs()
    shell:Show()
    shell:SelectSection(section or "Rotations")
    return shell
end

-- Redraws the open window (tabs and current page) on the next UI update; does nothing when it is closed.
function addon:RefreshConfiguration()
    local shell = self.configWindow

    if not shell or not shell.frame:IsShown() then
        return
    end

    -- Native controls still use their owner after invoking a field callback.
    -- Rebuild on the next UI update, after that callback has returned.
    addon:SetUIScript(shell.frame, "OnUpdate", function(frame)
        addon:SetUIScript(frame, "OnUpdate", nil)

        if frame:IsShown() then
            shell:RefreshTabs()
            shell:SelectSection(shell.section)
        end
    end)
end

local showConfig = addon.ShowConfig

-- Re-declares ShowConfig so the call runs under the diagnostics wrapper when it exists: an error opening the window is
-- recorded instead of propagating to the caller (a slash command or button).
-- @param ... any  The arguments of the original ShowConfig (section, selection).
-- @return table|nil  The shell; nil when the protected call failed (the error is already reported).
function addon:ShowConfig(...)
    if not self.Diagnostics then
        return showConfig(self, ...)
    end

    -- Returns the call's results on success and nothing when the protected call failed (the error is already reported).
    -- @param ok boolean  Whether the protected call succeeded.
    -- @param ... any  The call's results.
    -- @return any  The call's results when ok; nothing otherwise.
    local function result(ok, ...)
        if ok then
            return ...
        end
    end

    return result(self.Diagnostics:Call({ module = 'ui', operation = 'open-config' }, showConfig, self, ...))
end
