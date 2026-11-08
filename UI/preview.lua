-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The on-screen recommendation preview: a small movable, resizable strip of 1 to 5 icons showing the spells or items
-- the poll currently recommends (addon.nextWindow). Owns the frame, its icons, the unlocked drag and grip, the right-
-- click menu, the sample icons mode and the saved position and size (profile.preview_window, preview_icon_size);
-- visibility follows the Preview Spells setting alone. The poll drives it through the window interface
-- (ReleaseChildren, PauseLayout, AddRecommendation, ResumeLayout). The ANALYTICS PREVIEW blocks hand delivery facts to
-- Analytics/ and are pinned by predecessor fixtures. Loaded from RotationMaster.toc after UI/rotation_editor.lua;
-- Masque skins the icons.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- BEGIN ANALYTICS PREVIEW HANDOFF
local previewCapture
local previewEnvironment = getfenv(1)
local previewType, previewRaw = type, rawget
---@type any
local previewFunctionEnvironment = getfenv

if addon.BindAnalyticsPreviewCapture then
    addon:BindAnalyticsPreviewCapture(function(sink)
        previewCapture = sink
    end)
end

-- END ANALYTICS PREVIEW HANDOFF
-- The profile the sample-icons mode is on for (nil when off). Per session and per profile; never saved.
local sampleProfile

-- Fixed placeholder icons painted in sample mode, so a player can size and place the window without a rotation.
local sampleTextures = {
    'Interface\\Icons\\Spell_Fire_FlameBolt',
    'Interface\\Icons\\Spell_Frost_FrostBolt02',
    'Interface\\Icons\\Spell_Nature_Lightning',
    'Interface\\Icons\\Spell_Holy_Heal',
    'Interface\\Icons\\INV_Misc_QuestionMark',
}

-- ============================================================================
-- Helpers and sample mode
-- ============================================================================

-- True while sample icons are on for the current profile; a profile switch silently turns them off.
-- @return boolean  True when sample mode is on.
function addon:IsPreviewSampleEnabled()
    if sampleProfile ~= self.db.profile then
        sampleProfile = nil
    end

    return sampleProfile ~= nil
end

-- `value` limited to lo..hi, or `fallback` when it is not a real number (nil, NaN, wrong type).
-- @param value any  The value.
-- @param lo number  The lowest allowed value.
-- @param hi number  The highest allowed value.
-- @param fallback any  Returned when value is not a real number.
-- @return number|any  The clamped number, or the fallback.
local function clamp(value, lo, hi, fallback)
    return type(value) == 'number' and value == value and math.max(lo, math.min(hi, value)) or fallback
end

-- True when two geometry numbers are equal within a tenth of a pixel. Native geometry can read back with small
-- floating-point differences.
-- @param a any  The first number.
-- @param b any  The second number.
-- @return boolean  True when both are numbers within .1 of each other.
local function sameGeometry(a, b)
    return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) <= .1
end

-- ============================================================================
-- The preview window
-- ============================================================================

-- Builds (once) and re-activates the preview window for the current profile, restoring its saved position. Each call
-- starts a new generation, so callbacks captured by an older showing go inert. The window is also published as
-- addon.nextWindow, where the poll finds it.
-- @return RMRecommendationPreview  The window table.
---@class RMRecommendationPreview
---@field ReleaseChildren fun(self: RMRecommendationPreview)
---@field PauseLayout fun(self: RMRecommendationPreview)
---@field ResumeLayout fun(self: RMRecommendationPreview)
---@field DoLayout fun(self: RMRecommendationPreview)
---@field AddRecommendation fun(self: RMRecommendationPreview, spellId: number, itemId?: number, confidence?: number, delay?: number)
function addon:CreateNativePreviewWindow()
    local window = self.nativePreviewWindow

    if not window then
        local frame = addon:TrackWorkbenchSize(CreateFrame('Frame', nil, UIParent))
        frame:SetFrameStrata('MEDIUM')
        frame:SetMovable(true)
        frame:SetResizable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(false)
        window = { frame = frame, icons = {}, count = 0, nativePreview = true }
        self.nativePreviewWindow = window
        -- A caption above the icons (not a title bar: it reserves no height and the window has no header).
        window.caption = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        window.caption:SetPoint('BOTTOM', frame, 'TOP', 0, 3)
        window.caption:SetText(L['Rotation Preview'])
        window.body = frame:CreateTexture(nil, 'BACKGROUND')
        window.body:SetAllPoints(frame)
        window.body:SetColorTexture(.055, .065, .075, 1)
        -- No title bar or close button: the window is only its icons and their
        -- padded background. Unlocked, the whole body is the drag handle and the
        -- lower-right grip appears on hover. Visibility is Preview Spells alone.
        frame:RegisterForDrag('LeftButton')
        window.grip = CreateFrame('Button', nil, frame)
        window.grip:SetSize(12, 12)
        window.grip:SetPoint('BOTTOMRIGHT', 0, 0)
        window.grip:SetFrameLevel(frame:GetFrameLevel() + 5)
        local grip = window.grip:CreateTexture(nil, 'OVERLAY')
        grip:SetAllPoints(window.grip)
        grip:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
        window.grip:SetAlpha(0)

        -- True while this is the live window of the active profile; every late callback checks it first.
        -- @return boolean|nil  Truthy while the window is live.
        function window:Valid()
            return self.active and addon.db.profile == self.profile and addon.nextWindow == self
        end

        local nativeValid = window.Valid

        -- Returns icon button number `index`, creating it with its drag, menu and tooltip wiring on first use.
        -- @param index number  The icon slot.
        -- @return Button  The icon button.
        function window:EnsureIcon(index)
            local icon = self.icons[index]

            if not icon then
                icon = CreateFrame('Button', nil, self.frame)
                icon.texture = icon:CreateTexture(nil, 'ARTWORK')
                icon.texture:SetAllPoints(icon)

                -- A predicted slot's timing and certainty, drawn over the icon from a frame of its own so the icon's fade does
                -- not dim them.
                local overlay = CreateFrame('Frame', nil, self.frame)
                overlay:SetAllPoints(icon)
                overlay:SetFrameLevel(icon:GetFrameLevel() + 6)
                overlay:Hide()
                icon.overlay = overlay
                icon.delayText = overlay:CreateFontString(nil, 'OVERLAY', 'NumberFontNormalLarge')
                icon.delayText:SetPoint('CENTER', overlay, 'CENTER', 0, 0)
                icon.chanceText = overlay:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
                icon.chanceText:SetPoint('BOTTOM', overlay, 'BOTTOM', 0, 2)

                -- A gated step drawn over this icon, its visibility decided by the game (AddGatedRecommendation).
                icon.gateFrame = CreateFrame('Frame', nil, icon)
                icon.gateFrame:SetAllPoints(icon)
                icon.gateFrame:SetFrameLevel(icon:GetFrameLevel() + 4)
                icon.gateTexture = icon.gateFrame:CreateTexture(nil, 'ARTWORK')
                icon.gateTexture:SetAllPoints(icon.gateFrame)
                icon.gateFrame:Hide()

                icon:Hide()
                self.icons[index] = icon
                -- Icons already take the mouse for tooltips. Left-drag moves an
                -- unlocked window; right-click opens the window menu.
                icon:RegisterForDrag('LeftButton')
                icon:RegisterForClicks('RightButtonUp')

                addon:SetUIScript(icon, 'OnDragStart', function()
                    self:BeginMove()
                end)

                addon:SetUIScript(icon, 'OnDragStop', function()
                    self:EndMove()
                end)

                addon:SetUIScript(icon, 'OnClick', function(_, button)
                    if button == 'RightButton' then
                        self:OpenMenu()
                    end
                end)
            end

            return icon
        end

        -- Clears every recommendation icon (the poll calls this before a new set); repaints samples if that mode is on.
        function window:ReleaseChildren()
            self.count = 0
            self.sampleCount = 0
            self.pendingGate = nil

            for _, icon in ipairs(self.icons) do
                if GameTooltip and GameTooltip:IsOwned(icon) then
                    GameTooltip:Hide()
                end

                icon:Hide()

                if icon.overlay then
                    icon.overlay:Hide()
                end

                addon:ClearPreviewGate(icon)
                icon.sample, icon.spellId, icon.itemId = nil, nil, nil
                addon:SetUIScript(icon, 'OnEnter', nil)
                addon:SetUIScript(icon, 'OnLeave', nil)
            end

            -- Rotation disable also clears directly, outside a publication batch.
            if sampleProfile == self.profile then
                self:PaintSamples()

                if self.sampleCount > 0 then
                    self:DoLayout()
                end
            end
        end

        -- Hides only the placeholder icons, leaving real recommendations alone.
        function window:ClearSampleIcons()
            for _, icon in ipairs(self.icons) do
                if icon.sample then
                    if GameTooltip and GameTooltip:IsOwned(icon) then
                        GameTooltip:Hide()
                    end

                    icon:Hide()
                    icon.sample = nil
                    addon:SetUIScript(icon, 'OnEnter', nil)
                    addon:SetUIScript(icon, 'OnLeave', nil)
                end
            end

            self.sampleCount = 0
        end

        -- Fills every slot with a placeholder icon when sample mode is on and no real recommendation is showing.
        function window:PaintSamples()
            if not self:Valid() or self.sampleBatch or self.count ~= 0 or not addon:IsPreviewSampleEnabled() then
                return
            end

            self:ClearSampleIcons()
            local generation = self.generation

            for i = 1, self.slots do
                ---@type any
                local icon = self:EnsureIcon(i)
                local texture = sampleTextures[i]
                icon.sample = true
                icon.spellId, icon.itemId = nil, nil
                icon.texture:SetTexture(texture)

                if icon.masqueOwner then
                    icon.masqueSurface.texture:SetTexture(texture)
                end

                addon:SetUIScript(icon, 'OnEnter', function()
                    if not self:Valid() or generation ~= self.generation or not icon.sample or not GameTooltip then
                        return
                    end

                    GameTooltip:SetOwner(icon, 'ANCHOR_BOTTOMRIGHT', 3)
                    GameTooltip:SetText(L['Sample icon'])
                end)

                addon:SetUIScript(icon, 'OnLeave', function()
                    if GameTooltip and GameTooltip:IsOwned(icon) then
                        GameTooltip:Hide()
                    end
                end)

                icon:Show()
            end

            self.sampleCount = self.slots
        end

        -- Sizes the frame to its icons and anchors each icon; writes only values that changed, to avoid resize
        -- feedback.
        function window:DoLayout()
            if not self.active then
                return
            end

            local n = self.slots or 1
            local size = self.iconSize
            local pad = self.opacity > 0 and 4 or 0

            local width, height =
                (self.vertical and 1 or n) * size + 2 * pad, (self.vertical and n or 1) * size + 2 * pad

            self.layouting = true

            if not sameGeometry(self.frame:GetWidth(), width) or not sameGeometry(self.frame:GetHeight(), height) then
                self.frame:SetSize(width, height)
            end

            self.layouting = false

            for i, icon in ipairs(self.icons) do
                local x, y = pad + (self.vertical and 0 or i - 1) * size, -pad - (self.vertical and i - 1 or 0) * size
                local pointCount = icon:GetNumPoints()
                local point, parent, relative, oldx, oldy

                if pointCount == 1 then
                    point, parent, relative, oldx, oldy = icon:GetPoint(1)
                end

                if
                    pointCount ~= 1
                    or point ~= 'TOPLEFT'
                    or parent ~= self.frame
                    or relative ~= 'TOPLEFT'
                    or not sameGeometry(oldx, x)
                    or not sameGeometry(oldy, y)
                then
                    icon:ClearAllPoints()
                    icon:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', x, y)
                end

                if not sameGeometry(icon:GetWidth(), size) or not sameGeometry(icon:GetHeight(), size) then
                    icon:SetSize(size, size)
                end
                if icon:GetAlpha() ~= 1 then
                    icon:SetAlpha(1)
                end
                if icon.masqueOwner then
                    addon:ResizeMasquePreviewIcon(self, icon)
                end
            end
        end

        -- Re-reads the profile (slot count, icon size, orientation, lock, opacity), applies it and lays out again.
        function window:Configure()
            if not self.active then
                return
            end

            local profile = self.profile

            self.slots = addon:IsPreviewSampleEnabled() and (profile.preview_spells or 0) <= 0 and 3 or math.floor(
                clamp(profile.preview_spells, 1, 5, 1)
            )

            self.iconSize = clamp(profile.preview_icon_size, 24, 160, 64)
            self.vertical = profile.preview_vertical == true
            self.locked = profile.preview_locked == true
            self.opacity = clamp(profile.preview_opacity, 0, 1, 1)
            self.body:SetAlpha(self.opacity)

            if profile.preview_title == false then
                self.caption:Hide()
            else
                self.caption:Show()
            end

            -- Locked or fully transparent, the background never intercepts
            -- the mouse; only the icons keep their own tooltips and clicks.
            self.frame:EnableMouse(not self.locked and self.opacity > 0)

            if self.locked then
                self.frame:StopMovingOrSizing()
            end

            if not self.locked and self.opacity > 0 then
                self.grip:Show()
            else
                self.grip:Hide()
                self:SetHover(false)
            end

            for i, icon in ipairs(self.icons) do
                if i > self.slots then
                    icon:Hide()
                end
            end

            if addon.ConfigureMasquePreview then
                addon:ConfigureMasquePreview(self)
            end

            self:PaintSamples()
            self:DoLayout()
        end

        -- Turns a dragged frame size into an icon size (24 to 160), saves it to the profile and reconfigures.
        -- @param width number  The new frame width.
        -- @param height number  The new frame height.
        function window:Resize(width, height)
            if not self:Valid() or self.locked then
                self:DoLayout()
                return
            end

            local pad = self.opacity > 0 and 4 or 0
            local x = (width - 2 * pad) / (self.vertical and 1 or self.slots)
            local y = (height - 2 * pad) / (self.vertical and self.slots or 1)
            local size = math.abs(x - self.iconSize) >= math.abs(y - self.iconSize) and x or y
            self.profile.preview_icon_size = math.floor(clamp(size, 24, 160, 64) + .5)
            self:Configure()
        end

        local nativeAddRecommendation

        -- Shows the next recommended spell (or item, when `itemId` is set) in the first free slot. Called by the poll
        -- for each result; ignored when the window is stale or full. The first icon also reports delivery to analytics.
        -- @param spellId number  The spell ID.
        -- @param itemId number|nil  The item ID, when the recommendation is an item.
        -- @param confidence number|nil  How sure a predicted recommendation is, 0 to 1; nil for one read from the game as
        --   it is now. The icon fades with it, and shows it as a percentage, unless profile.forecast_confidence is off.
        -- @param delay number|nil  For a predicted slot after the first, the seconds after the first spell it would be cast.
        function window:AddRecommendation(spellId, itemId, confidence, delay)
            if not self:Valid() or self.count >= self.slots then
                return
            end

            if (self.sampleCount or 0) > 0 then
                self:ClearSampleIcons()
            end

            self.count = self.count + 1
            local index = self.count
            ---@type any
            local icon = self:EnsureIcon(index)
            local captureGeneration, captureProfile, captureFrame, captureIcons, captureTexture

            if previewCapture then
                captureGeneration, captureProfile = self.generation, self.profile
                captureFrame, captureIcons, captureTexture = self.frame, self.icons, icon.texture
            end

            local info

            if itemId then
                info = addon.Platform:GetItemDisplayInfo(itemId)
            else
                info = addon.Platform:GetSpellInfo(spellId)
            end

            icon.spellId, icon.itemId = spellId, itemId
            icon.texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark')

            if icon.masqueOwner then
                icon.masqueSurface.texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark')
            end

            if self.pendingGate then
                addon:ShowPreviewGate(icon, self.pendingGate)
                self.pendingGate = nil
            end

            local generation = self.generation

            addon:SetUIScript(icon, 'OnEnter', function()
                if not self:Valid() or generation ~= self.generation or not GameTooltip then
                    return
                end

                GameTooltip:SetOwner(icon, 'ANCHOR_BOTTOMRIGHT', 3)
                GameTooltip:SetHyperlink((itemId and 'item:' .. itemId or 'spell:' .. spellId))
            end)

            addon:SetUIScript(icon, 'OnLeave', function()
                if GameTooltip and GameTooltip:IsOwned(icon) then
                    GameTooltip:Hide()
                end
            end)

            local alpha = 1

            if type(confidence) == 'number' and self.profile.forecast_confidence ~= false then
                alpha = 0.4 + 0.6 * math.max(0, math.min(1, confidence))
            end

            if icon:GetAlpha() ~= alpha then
                icon:SetAlpha(alpha)
            end

            if icon.overlay then
                local showConfidence = type(confidence) == 'number' and self.profile.forecast_confidence ~= false
                local timed = type(delay) == 'number' and delay >= 0.05

                icon.delayText:SetText(timed and string.format('+%.1fs', delay) or '')

                icon.chanceText:SetText(
                    showConfidence and string.format('%d%%', math.floor(confidence * 100 + 0.5)) or ''
                )

                if timed or showConfidence then
                    icon.overlay:Show()
                else
                    icon.overlay:Hide()
                end
            end

            icon:Show()
            self:DoLayout()

            -- BEGIN ANALYTICS PREVIEW DELIVERY
            if previewCapture and index == 1 and self.AddRecommendation == nativeAddRecommendation then
                local owner, profile, generation = self, captureProfile, captureGeneration
                local frame, icons, texture = captureFrame, captureIcons, captureTexture
                local frameVisible, iconVisible, textureGet, displayId, observed

                -- Whether the preview state captured for the delivery record is still the live state.
                -- @return boolean  True when the preview, its icon, texture and the captured natives are all unchanged.
                --
                -- Pure captured-state checks run again after every native read.
                -- Initial property reads are inside the collector's protected call.
                local function eligible()
                    return owner.Valid == nativeValid
                        and previewFunctionEnvironment(nativeAddRecommendation) == previewEnvironment
                        and nativeValid(owner)
                        and owner.profile == profile
                        and owner.generation == generation
                        and owner.AddRecommendation == nativeAddRecommendation
                        and owner.frame == frame
                        and owner.icons == icons
                        and icons[1] == icon
                        and icon.texture == texture
                        and not icon.sample
                        and icon.spellId == spellId
                        and icon.itemId == nil
                        and itemId == nil
                        and previewType(info) == 'table'
                        and previewType(displayId) == 'number'
                        and displayId == displayId
                        and displayId > 0
                        and displayId < math.huge
                        and previewRaw(info, 'iconID') == displayId
                        and frame.IsVisible == frameVisible
                        and icon.IsVisible == iconVisible
                        and previewType(frameVisible) == 'function'
                        and previewType(iconVisible) == 'function'
                        and texture.GetTexture == textureGet
                        and previewType(textureGet) == 'function'
                end

                previewCapture(
                    "delivery",
                    self,
                    function()
                        if not observed then
                            frameVisible, iconVisible, textureGet = frame.IsVisible, icon.IsVisible, texture.GetTexture

                            if previewType(info) == 'table' then
                                displayId = previewRaw(info, 'iconID')
                            end

                            observed = true
                        end

                        if not eligible() then
                            return 'retired'
                        end

                        local frameShown, iconShown = frameVisible(frame), iconVisible(icon)
                        local rendered = textureGet(texture)

                        if not eligible() or rendered ~= displayId then
                            return 'retired'
                        end
                        if frameShown == true and iconShown == true then
                            return 'visible'
                        end
                        if frameShown == false or iconShown == false then
                            return 'hidden'
                        end

                        return 'unknown'
                    end,
                    nil,
                    spellId
                )
            end
            -- END ANALYTICS PREVIEW DELIVERY
        end

        nativeAddRecommendation = window.AddRecommendation

        -- Holds a step with a display gate the client hides (main.lua, Platform/gates.lua): it is drawn over the next
        -- recommendation's icon, and the game's curve output decides which of the two shows. One with nothing after it
        -- shows on its own at ResumeLayout. Never the bar glow: such a step can only be shown here.
        -- @param spellId number  The gated step's spell.
        -- @param itemId number|nil  Its item, when the step is an item.
        -- @param gate table  The step's gate.
        function window:AddGatedRecommendation(spellId, itemId, gate)
            if not self:Valid() then
                return
            end

            self:FlushGate()
            self.pendingGate = { spellId = spellId, itemId = itemId, gate = gate }
        end

        -- Shows a held gated step in a slot of its own (nothing followed it), when there is room.
        function window:FlushGate()
            local pending = self.pendingGate
            self.pendingGate = nil

            if not pending or not self:Valid() or self.count >= self.slots then
                return
            end

            self.count = self.count + 1
            ---@type any
            local icon = self:EnsureIcon(self.count)
            icon.spellId, icon.itemId = pending.spellId, pending.itemId
            icon.texture:SetTexture(nil)

            if icon.masqueOwner then
                icon.masqueSurface.texture:SetTexture(nil)
            end

            addon:ShowPreviewGate(icon, pending)
            icon:Show()
            self:DoLayout()
        end

        -- Starts a publication batch: no sample icons are painted until ResumeLayout.
        function window:PauseLayout()
            self.sampleBatch = true

            if (self.sampleCount or 0) > 0 then
                self:ClearSampleIcons()
            end
        end

        -- Ends a publication batch and repaints samples if nothing real was shown.
        function window:ResumeLayout()
            self:FlushGate()
            addon:UpdatePreviewHealthBar(self)
            self.sampleBatch = false

            if sampleProfile == self.profile then
                self:PaintSamples()
            end
        end

        -- Shows the frame if the window is still the live one.
        function window:Show()
            if self:Valid() then
                self.frame:Show()
            end
        end

        -- Hides the frame; analytics is told the preview retired first, and a retire that replaces the window stops
        -- here.
        function window:Hide()
            if previewCapture then
                local generation, profile = self.generation, self.profile
                previewCapture("retire", self)

                if self.generation ~= generation or self.profile ~= profile then
                    return
                end
            end

            self.frame:Hide()
        end

        -- Deactivates the window: retires analytics delivery, clears icons and sample mode, hides the frame and Masque
        -- skin.
        function window:Release()
            if previewCapture then
                local generation, profile = self.generation, self.profile
                previewCapture("retire", self)

                if self.generation ~= generation or self.profile ~= profile then
                    return
                end
            end

            if sampleProfile == self.profile then
                sampleProfile = nil
            end

            self.sampleBatch = false
            self:ReleaseChildren()
            self.active = false
            self.frame:StopMovingOrSizing()
            self.frame:Hide()

            if addon.ReleaseMasquePreview then
                addon:ReleaseMasquePreview(self)
            end
        end

        -- Tracks pointer hover over the body or grip; the resize grip is visible only while hovered.
        -- @param over boolean|nil  True while the pointer is over the body.
        function window:SetHover(over)
            self.hovered = over == true
            self.grip:SetAlpha((self.hovered or self.gripHovered) and 1 or 0)
        end

        -- Starts dragging the frame; refused while locked or stale.
        function window:BeginMove()
            if self:Valid() and not self.locked then
                self.moving = true
                self.frame:StartMoving()
            end
        end

        -- Stops the drag and saves the new anchor as the profile's headerless position.
        function window:EndMove()
            local moving = self.moving
            self.moving = nil

            if not moving or not self:Valid() or self.locked then
                return
            end

            self.frame:StopMovingOrSizing()
            local point, _, relative, x, y = self.frame:GetPoint(1)
            self.profile.preview_window = { point = point, relpoint = relative, xoffs = x, yoffs = y }
            self.profile.previewHeaderlessGeometry = true
        end

        -- Builds the right-click menu entries. The menu never hides the window: it is shown exactly while Preview
        -- Spells is above zero (or samples are on) and hidden at zero.
        -- @return table[]|nil  Entries shaped { text, isTitle, checked, func }; nil when the window is stale.
        function window:MenuEntries()
            if not self:Valid() then
                return nil
            end

            local locked, generation = self.locked == true, self.generation

            -- True while the menu was built for the live window generation.
            -- @return boolean|nil  Truthy while the menu entries may act.
            local function current()
                return self:Valid() and self.generation == generation
            end

            return {
                { text = addon.pretty_name or L['Rotation Master'], isTitle = true },
                {
                    text = L['Lock position and size'],
                    checked = locked,
                    func = function()
                        if current() then
                            addon:SetPreviewLocked(not locked)
                        end
                    end,
                },
                {
                    text = L['Open General settings'],
                    func = function()
                        if current() then
                            addon:ShowConfig('General')
                        end
                    end,
                },
            }
        end

        -- Pops the right-click menu at the cursor using the shared dropdown API.
        function window:OpenMenu()
            local entries = self:MenuEntries()

            if not entries then
                return
            end

            -- The same dropdown API as the minimap menu; every client provides it natively.
            if
                UIDropDownMenu_Initialize
                and ToggleDropDownMenu
                and UIDropDownMenu_CreateInfo
                and UIDropDownMenu_AddButton
            then
                self.menu = self.menu or CreateFrame(
                    'Frame',
                    addon_name .. 'PreviewMenu',
                    UIParent,
                    'UIDropDownMenuTemplate'
                )

                UIDropDownMenu_Initialize(
                    self.menu,
                    -- Dropdown initializer: adds one menu button per entry (title, check box or plain item).
                    function()
                        for _, entry in ipairs(entries) do
                            local info = UIDropDownMenu_CreateInfo()
                            info.text = entry.text

                            if entry.isTitle then
                                info.isTitle = true
                                info.notCheckable = true
                            elseif entry.checked ~= nil then
                                info.isNotRadio = true
                                info.checked = entry.checked
                                info.func = entry.func
                            else
                                info.notCheckable = true
                                info.func = entry.func
                            end

                            UIDropDownMenu_AddButton(info)
                        end
                    end,
                    'MENU'
                )

                ToggleDropDownMenu(1, nil, self.menu, 'cursor', 5, -10)
            end
        end

        -- Container-style width request from the poll; becomes a Resize. SetWidth, SetHeight, ClearAllPoints, SetPoint
        -- and GetPoint let the poll treat this window like a layout container: sizes arrive as Resize requests, points
        -- go to the frame.
        -- @param width number  The width.
        function window:SetWidth(width)
            self:Resize(width, self.frame:GetHeight())
        end

        -- Container-style height request from the poll; becomes a Resize.
        -- @param height number  The height.
        function window:SetHeight(height)
            self:Resize(self.frame:GetWidth(), height)
        end

        -- Forwards to the frame.
        function window:ClearAllPoints()
            self.frame:ClearAllPoints()
        end

        -- Forwards to the frame.
        -- @param ... any  The arguments of Frame:SetPoint.
        function window:SetPoint(...)
            self.frame:SetPoint(...)
        end

        -- Forwards to the frame.
        -- @param ... any  The arguments of Frame:GetPoint.
        -- @return any  What Frame:GetPoint returns.
        function window:GetPoint(...)
            return self.frame:GetPoint(...)
        end

        addon:SetUIScript(frame, 'OnSizeChanged', function(_, width, height)
            if not window.layouting then
                window:Resize(width, height)
            end
        end)

        addon:SetUIScript(frame, 'OnDragStart', function()
            window:BeginMove()
        end)

        addon:SetUIScript(frame, 'OnDragStop', function()
            window:EndMove()
        end)

        addon:SetUIScript(frame, 'OnMouseUp', function(_, button)
            if button == 'RightButton' then
                window:OpenMenu()
            end
        end)

        addon:SetUIScript(frame, 'OnEnter', function()
            window:SetHover(true)
        end)

        addon:SetUIScript(frame, 'OnLeave', function()
            window:SetHover(false)
        end)

        addon:SetUIScript(window.grip, 'OnEnter', function()
            window.gripHovered = true
            window:SetHover(window.hovered)
        end)

        addon:SetUIScript(window.grip, 'OnLeave', function()
            window.gripHovered = false
            window:SetHover(window.hovered)
        end)

        addon:SetUIScript(window.grip, 'OnMouseDown', function(_, button)
            if button == 'LeftButton' and window:Valid() and not window.locked and window.opacity > 0 then
                window.frame:StartSizing('BOTTOMRIGHT')
            end
        end)

        addon:SetUIScript(window.grip, 'OnMouseUp', function()
            if window:Valid() then
                window.frame:StopMovingOrSizing()
            end
        end)
    end

    if window.active and addon.ReleaseMasquePreview then
        addon:ReleaseMasquePreview(window)
    end

    local profile = self.db.profile
    window.profile = profile
    window.active = true
    window.sampleBatch = false
    window.generation = (window.generation or 0) + 1
    window:ReleaseChildren()
    self.nextWindow = window
    window.moving = nil
    window:Configure()
    window.frame:ClearAllPoints()
    addon:MigratePreviewHeaderGeometry(profile, window.opacity)
    local position = profile.preview_window

    if type(position) == 'table' and position.point and position.relpoint then
        window.frame:SetPoint(position.point, UIParent, position.relpoint, position.xoffs or 0, position.yoffs or 0)
    else
        window.frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end

    window.frame:Show()
    return window
end

-- Draws a gated step over a preview icon. The gate's alpha pair comes from the game (Platform:GetGateAlphas, secret 0
-- or 1 values RM never reads): the gated icon takes one, the icon under it the other. Where the client cannot do this,
-- the gated icon is left hidden, so the next recommendation shows as it would without the gated step.
-- @param icon table  The preview icon.
-- @param pending table  { spellId, itemId, gate }.
function addon:ShowPreviewGate(icon, pending)
    local frame, texture = icon.gateFrame, icon.gateTexture

    if not frame then
        return
    end

    local info

    if pending.itemId then
        info = self.Platform:GetItemDisplayInfo(pending.itemId)
    else
        info = self.Platform:GetSpellInfo(pending.spellId)
    end

    local alpha, inverse = self.Platform:GetGateAlphas(pending.gate)

    if alpha == nil then
        frame:Hide()
        return
    end

    texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark')
    local shown = pcall(texture.SetAlpha, texture, alpha)
    local under = icon.masqueOwner and icon.masqueSurface and icon.masqueSurface.texture or icon.texture

    if shown and pcall(under.SetAlpha, under, inverse) then
        icon.gated = true
        frame:Show()
    else
        pcall(under.SetAlpha, under, 1)
        frame:Hide()
    end
end

-- Shows your target's health as a thin bar under the preview window when profile.preview_target_health is on. The
-- values go straight to the StatusBar (Platform:GetUnitHealthPassthrough), so the bar shows real health in combat on
-- Retail and Forever, where RM itself cannot read it. Hidden without a target or with the option off.
-- @param window table  The preview window.
function addon:UpdatePreviewHealthBar(window)
    local bar = window.healthBar
    local wanted = window.profile and window.profile.preview_target_health == true

    if not wanted then
        if bar then
            bar:Hide()
        end

        return
    end

    if not bar then
        local made, created = pcall(CreateFrame, 'StatusBar', nil, window.frame)

        if not made or not created then
            return
        end

        bar = created
        bar:SetPoint('TOPLEFT', window.frame, 'BOTTOMLEFT', 0, -2)
        bar:SetPoint('TOPRIGHT', window.frame, 'BOTTOMRIGHT', 0, -2)
        bar:SetHeight(6)

        if bar.SetStatusBarTexture then
            pcall(bar.SetStatusBarTexture, bar, 'Interface\\TargetingFrame\\UI-StatusBar')
        end
        if bar.SetStatusBarColor then
            bar:SetStatusBarColor(.2, .8, .2)
        end

        window.healthBar = bar
    end

    local current, maximum = self.Platform:GetUnitHealthPassthrough('target')

    if current ~= nil and pcall(bar.SetMinMaxValues, bar, 0, maximum) and pcall(bar.SetValue, bar, current) then
        bar:Show()
    else
        bar:Hide()
    end
end

-- Removes a gated step from a preview icon and restores the icon under it.
-- @param icon table  The preview icon.
function addon:ClearPreviewGate(icon)
    if icon.gateFrame then
        icon.gateFrame:Hide()
    end

    if not icon.gated then
        return
    end

    icon.gated = nil

    for _, texture in ipairs({ icon.texture, icon.masqueSurface and icon.masqueSurface.texture }) do
        if texture and texture.SetAlpha then
            texture:SetAlpha(1)
        end
    end
end

-- Shifts a saved preview position once per profile after the window lost its 20-pixel title bar, so the icons stay
-- where they were. The flag profile.previewHeaderlessGeometry means "the saved position is headerless"; a drag saves
-- one too.
-- @param profile table  The profile.
-- @param opacity number|nil  The window opacity; zero reserved no header.
--
-- A position saved with the title bar anchored the old outer frame: the header sat on top, so top anchors drop 20
-- pixels, middle anchors 10 and bottom anchors stay. Opacity zero reserved no header. With no saved position there is
-- nothing to shift and nothing is written.
function addon:MigratePreviewHeaderGeometry(profile, opacity)
    if type(profile) ~= 'table' or profile.previewHeaderlessGeometry == true then
        return
    end

    local position = profile.preview_window

    if type(position) ~= 'table' or type(position.point) ~= 'string' or type(position.relpoint) ~= 'string' then
        return
    end

    local point = position.point:upper()
    local shift = (opacity or 1) <= 0 and 0 or point:find('^TOP') and 20 or point:find('^BOTTOM') and 0 or 10

    if shift > 0 then
        profile.preview_window = {
            point = position.point,
            relpoint = position.relpoint,
            xoffs = position.xoffs or 0,
            yoffs = (position.yoffs or 0) - shift,
        }
    end

    profile.previewHeaderlessGeometry = true
end

-- ============================================================================
-- Settings entry points
-- ============================================================================

-- Saves the lock state, tells the settings page, and refreshes the window.
-- @param locked boolean|nil  True locks the position and size.
-- @return boolean  The stored boolean.
function addon:SetPreviewLocked(locked)
    locked = locked == true
    self.db.profile.preview_locked = locked

    if self.previewLockChanged then
        self.previewLockChanged(locked)
    end
    if self.RefreshPreviewWindow then
        self:RefreshPreviewWindow()
    end

    return locked
end

-- Brings the window in line with the profile: releases it at zero preview spells (unless in sample mode), updates it in
-- place when it is live, otherwise replaces whatever window is current with a native preview window.
function addon:RefreshPreviewWindow()
    local count = self.db.profile.preview_spells or 0

    if count <= 0 and not self:IsPreviewSampleEnabled() then
        if self.nextWindow then
            self.nextWindow:Release()
            self.nextWindow = nil
        end
    elseif
        self.nextWindow
        and self.nextWindow.nativePreview
        and self.nextWindow.active
        and self.nextWindow.profile == self.db.profile
    then
        self.nextWindow:Configure()
        self.nextWindow:Show()
    else
        if self.nextWindow and not (self.nextWindow.nativePreview and self.nextWindow.active == false) then
            self.nextWindow:Release()
        end

        self:CreateNativePreviewWindow()
    end
end

-- Turns the sample icons mode on or off. The mode belongs only to this loaded UI and current profile; no saved field.
-- @param enabled boolean|nil  True to turn it on, false to turn it off; non-Boolean input leaves it unchanged.
-- @return boolean  The resulting enabled state.
function addon:SetPreviewSampleEnabled(enabled)
    if type(enabled) ~= 'boolean' then
        return self:IsPreviewSampleEnabled()
    end

    sampleProfile = enabled and self.db.profile or nil
    local window = self.nextWindow

    if not enabled and window and window.nativePreview and window.profile == self.db.profile then
        window:ClearSampleIcons()
    end

    self:RefreshPreviewWindow()
    return self:IsPreviewSampleEnabled()
end
