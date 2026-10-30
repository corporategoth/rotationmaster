-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Drag ghost behavior for the card editors. Turns the ghost frame made in UI/controls.lua into a presenter that lifts
-- the real card frames onto itself while a drag runs, leaves a dimmed placeholder where each card was, and draws the
-- preview edges. It must give every lifted frame back (parent, anchors, level, strata) on hide, cancel or error, and
-- it moves only frames the RM editors own. Used by UI/condition_canvas.lua and UI/rotation_canvas.lua; loaded in the
-- UI/ block of RotationMaster.toc right after UI/controls.lua.
local _, addon = ...
local tones = { red = { .85, .3, .25 }, green = { .25, .7, .35 }, gray = { .4, .4, .4 }, neutral = { .55, .58, .6 } }

-- Adds the presentation methods to `ghost`, using `decoration` (its fill and border textures) for the stock look. Call
-- once per ghost frame.
-- @param ghost Frame  The drag card from addon:CreateWorkbenchDragCard.
-- @param decoration table  The ghost's rounded card decoration ({ fill, border } texture lists).
--
-- Preview only RM-owned editor frames. Restore them before a command, rerender, release or canceled drag can recycle
-- their controls or replace their model.
function addon:InstallDragPresentation(ghost, decoration)
    -- Registers a stand-in window (unlayered) with the window registry so that closing it, which Escape does, calls
    -- `callback` and cancels the drag.
    -- @param callback function  Called when the stand-in window is closed.
    function ghost:CaptureCancel(callback)
        self.cancelOwner = self.cancelOwner or { frame = self }

        -- Window-registry hook: closing the stand-in cancels the drag.
        function self.cancelOwner:Hide()
            callback()
        end

        addon:OpenPopup(self.cancelOwner, nil, { layer = false })
    end

    local nativeHide, present, follow = ghost.Hide, ghost.Present, ghost.FollowPointer
    ghost.placeholders = {}
    ghost.previewLines = {}

    -- Shows or hides the ghost's stock fill and border textures (hidden while real cards are drawn on it).
    -- @param show boolean|nil  True to show the textures.
    local function artwork(show)
        for _, layer in ipairs({ 'fill', 'border' }) do
            for _, texture in ipairs(decoration[layer]) do
                if show then
                    texture:Show()
                else
                    texture:Hide()
                end
            end
        end
    end

    -- Gives every lifted card frame back to its original parent, anchors, level and strata, and clears the placeholders
    -- and preview lines. Safe to call when nothing is lifted.
    --
    -- A failure restoring one frame does not stop the rest; the first error is re-raised after everything has been
    -- restored.
    function ghost:RestoreCards()
        local entries = self.liveEntries
        self.liveEntries = nil
        self.grabOffset = nil

        if entries then
            local firstError

            for _, entry in ipairs(entries) do
                -- Restores one lifted frame's parent, anchors, frame level and strata.
                local ok, why = pcall(function()
                    local frame = entry.frame
                    frame:SetParent(entry.parent)
                    frame:ClearAllPoints()

                    if #entry.points > 0 then
                        for _, point in ipairs(entry.points) do
                            frame:SetPoint(unpack(point))
                        end
                    else
                        frame:SetPoint('TOPLEFT', entry.parent, 'TOPLEFT', entry.x, -entry.y)
                    end

                    frame:SetFrameLevel(entry.level)
                    frame:SetFrameStrata(entry.strata)
                end)

                if not ok then
                    firstError = firstError or why
                end
            end

            for _, line in ipairs(self.sourceLines or {}) do
                line:Show()
            end

            self.sourceLines = nil

            for _, placeholder in ipairs(self.placeholders) do
                placeholder:Hide()
            end

            for _, line in ipairs(self.previewLines) do
                line:Hide()
            end

            if firstError then
                error(firstError, 0)
            end
        end
    end

    -- Hiding the ghost always restores the lifted cards first.
    function ghost:Hide()
        self:RestoreCards()
        nativeHide(self)
    end

    -- Shows the ghost as the plain summary chip (label, summary, count) instead of lifted cards.
    -- @param ... any  The arguments of the stock Present: title, summary, source and count.
    function ghost:Present(...)
        self:RestoreCards()
        self:SetClampedToScreen(true)
        self:SetSize(340, 76)
        artwork(true)
        self.label:Show()
        self.summary:Show()
        self.count:ClearAllPoints()
        self.count:SetPoint('TOPRIGHT', -10, -8)
        present(self, ...)
    end

    -- Moves the ghost with the cursor, keeping the point where the player grabbed the card under the pointer; without a
    -- grab offset (summary chip) it defers to the stock follow behavior.
    function ghost:FollowPointer()
        if self.grabOffset and GetCursorPosition then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            self:ClearAllPoints()

            self:SetPoint(
                'TOPLEFT',
                UIParent,
                'BOTTOMLEFT',
                x / scale - self.grabOffset.x,
                y / scale + self.grabOffset.y
            )
        else
            follow(self)
        end
    end

    -- Lifts a single control onto the ghost at its current position; a one-entry PresentCards.
    -- @param control Frame  The control to lift.
    -- @return boolean  What PresentCards returns.
    function ghost:PresentSource(control)
        return self:PresentCards({
            { frame = control, x = 0, y = 0, width = control:GetWidth(), height = control:GetHeight() },
        }, control:GetParent())
    end

    -- Lifts the card frames in `entries` onto the ghost, leaves a placeholder at each original spot, hides
    -- `sourceLines` and draws `edges` as preview lines. On an error it restores the cards and re-raises.
    -- @param entries table[]  Each { frame, x, y, width, height } in the source's coordinates.
    -- @param source Frame|nil  The frame that supplies the scale.
    -- @param edges table[]|nil  Preview lines: each { points = { {x, y}, ... }, tone = 'red'|'green'|'gray'|'neutral',
    --   inactive = boolean }.
    -- @param sourceLines Texture[]|nil  The source's own connector textures, hidden while the cards are lifted and
    --   restored afterwards.
    -- @return boolean  False for an empty list; true when the cards were lifted.
    function ghost:PresentCards(entries, source, edges, sourceLines)
        self:RestoreCards()

        if type(entries) ~= 'table' or #entries == 0 then
            return false
        end

        local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge

        for _, entry in ipairs(entries) do
            left = math.min(left, entry.x)
            top = math.min(top, entry.y)
            right = math.max(right, entry.x + entry.width)
            bottom = math.max(bottom, entry.y + entry.height)
        end

        if source and UIParent.GetEffectiveScale then
            self:SetScale(source:GetEffectiveScale() / UIParent:GetEffectiveScale())
        end

        self:SetSize(right - left, bottom - top)
        self:SetClampedToScreen(false)
        self.liveEntries = {}
        self.sourceLines = sourceLines or {}
        local first = entries[1]
        local frame = first.frame

        if GetCursorPosition and frame.GetLeft and frame.GetTop and frame:GetLeft() and frame:GetTop() then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()

            self.grabOffset = {
                x = x / scale - (frame:GetLeft() - first.x + left),
                y = (frame:GetTop() + first.y - top) - y / scale,
            }
        end

        local baseLevel = math.huge

        for _, entry in ipairs(entries) do
            baseLevel = math.min(baseLevel, entry.frame:GetFrameLevel())
        end

        -- Lifts the cards onto the ghost, places the placeholders, draws the preview lines and shows the ghost; runs
        -- under pcall so a failure can restore the cards.
        local ok, why = pcall(function()
            for i, entry in ipairs(entries) do
                local control = entry.frame
                local parent = control:GetParent()

                local saved = {
                    frame = control,
                    parent = parent,
                    x = entry.x,
                    y = entry.y,
                    level = control:GetFrameLevel(),
                    strata = control:GetFrameStrata(),
                    points = {},
                }

                if control.GetPoint then
                    for point = 1, (control.GetNumPoints and control:GetNumPoints() or 1) do
                        local anchor = { control:GetPoint(point) }

                        if anchor[1] then
                            saved.points[#saved.points + 1] = anchor
                        end
                    end
                end

                self.liveEntries[#self.liveEntries + 1] = saved
                local placeholder = self.placeholders[i]

                if not placeholder then
                    placeholder = CreateFrame('Frame', nil, parent)
                    placeholder:EnableMouse(false)
                    placeholder.decoration = addon:CreateRoundedCardDecoration(placeholder)
                    self.placeholders[i] = placeholder
                end

                placeholder:SetParent(parent)
                placeholder:ClearAllPoints()

                if #saved.points > 0 then
                    for _, point in ipairs(saved.points) do
                        placeholder:SetPoint(unpack(point))
                    end
                else
                    placeholder:SetPoint('TOPLEFT', parent, 'TOPLEFT', entry.x, -entry.y)
                end

                placeholder:SetSize(entry.width, entry.height)
                placeholder.decoration:SetColors(.4, .4, .4, .7, .12)
                placeholder:Show()
                control:SetParent(self)
                control:ClearAllPoints()
                control:SetPoint('TOPLEFT', self, 'TOPLEFT', entry.x - left, -entry.y + top)
                control:SetFrameLevel(self:GetFrameLevel() + 1 + saved.level - baseLevel)
                control:SetFrameStrata('TOOLTIP')
            end

            for _, line in ipairs(self.sourceLines) do
                line:Hide()
            end

            local n = 0

            for _, edge in ipairs(edges or {}) do
                local tone = tones[edge.tone] or tones.neutral

                for i = 2, #edge.points do
                    n = n + 1
                    local line = self.previewLines[n]

                    if not line then
                        line = self:CreateTexture(nil, 'BACKGROUND')
                        self.previewLines[n] = line
                    end

                    local a, b = edge.points[i - 1], edge.points[i]
                    line:ClearAllPoints()
                    line:SetPoint('TOPLEFT', self, 'TOPLEFT', math.min(a.x, b.x) - left, -math.min(a.y, b.y) + top)
                    line:SetSize(math.max(2, math.abs(a.x - b.x) + 2), math.max(2, math.abs(a.y - b.y) + 2))
                    line:SetColorTexture(tone[1], tone[2], tone[3], edge.inactive and .25 or .8)
                    line:Show()
                end
            end

            for i = n + 1, #self.previewLines do
                self.previewLines[i]:Hide()
            end

            artwork(false)
            self.label:Hide()
            self.summary:Hide()

            if self.texture then
                self.texture:Hide()
            end

            for _, layer in ipairs(self.stack) do
                layer:Hide()
            end

            self.count:ClearAllPoints()
            self.count:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, 4)
            self:FollowPointer()
            self:Show()
        end)

        if not ok then
            self:RestoreCards()
            error(why, 0)
        end

        return true
    end

    addon:SetUIScript(ghost, 'OnHide', function()
        ghost:RestoreCards()
    end)
end
