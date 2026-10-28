-- Configuration window spell, pet action and item icon control: an icon with a tooltip that accepts a drag from the
-- cursor and fires OnEnterPressed with the dropped id (or "" on a right click). It wraps the pooled condition icon
-- (UI/condition_icon.lua) and must undo every override on release. It only displays and relays ids; saving them is the
-- caller's job. Every value is read through `Platform:CanReadValue` and the Platform spell and item adapters. Loaded
-- from RotationMaster.toc after UI/window.lua.
local _, addon = ...

-- Tells whether a value is a positive whole number, the only shape a spell or item id may take.
-- @param value any  The value to test.
-- @return boolean  True for a positive whole number.
local function spellID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

-- Builds the icon widget for a spell, pet action or item: shows the icon for the id it is given, accepts a spell, pet
-- action or item dragged from the cursor, and clears on a right click. OnRelease restores every script and method it
-- replaced, because the underlying icon widget is pooled.
-- @param kind string  'spell', 'pet' or 'item'.
-- @param initialSpell any  The id (or text) to show first.
-- @param accept function|nil  accept(id) may veto a dropped id by returning false.
-- @return RMActionIcon  The widget.
--
-- Configuration-only spell/item display and drop control. Both its image primitive and action identity belong to RM's
-- lifecycle and adapters.
---@class RMActionIcon: RMConditionIcon
---@field SetText fun(self: RMActionIcon, value: any)
---@return RMActionIcon
local function actionIcon(kind, initialSpell, accept)
    local widget = addon:CreateConditionIcon()
    ---@type Button
    local frame = widget.frame
    local item = kind == "item"
    local key = item and "item" or "spell"
    local activeKey = item and "rmItemIconActive" or "rmSpellIconActive"
    local alive = true
    local originalText, originalRelease = widget.SetText, widget.OnRelease

    local originalClick, originalDrag, originalHide =
        frame:GetScript("OnClick"), frame:GetScript("OnReceiveDrag"), frame:GetScript("OnHide")

    widget[activeKey] = true
    widget:SetImageSize(36, 36)

    -- Hides the game tooltip if this icon owns it.
    local function hideTooltip()
        if GameTooltip and GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end

    -- Shows the icon for an id: a readable number, numeric string or (for items) an item the platform can resolve;
    -- anything else clears the id and shows the question mark icon.
    -- @param value any  The id, or text that resolves to one.
    widget.SetText = function(self, value)
        local id

        if addon.Platform:CanReadValue(value) then
            if type(value) == "string" then
                id = tonumber(value)
            elseif type(value) == "number" then
                id = value
            end
        end

        if not addon.Platform:CanReadValue(value) then
            id = nil
        elseif item then
            id = addon.Platform:GetItemID(value)
        end

        if not spellID(id) then
            id = nil
        end

        self:SetUserData(key, id)
        local info

        if id then
            if item then
                info = addon.Platform:GetItemDisplayInfo(id)
            else
                info = addon.Platform:GetSpellInfo(id)
            end
        end

        self:SetUserData(key .. "Metadata", info ~= nil)
        self.rmActionIconRevision = (self.rmActionIconRevision or 0) + 1
        self:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    widget:SetCallback("OnEnter", function()
        local id = widget:GetUserData(key)

        if alive and id and widget:GetUserData(key .. "Metadata") and GameTooltip then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(key .. ":" .. id)
        end
    end)

    widget:SetCallback("OnLeave", hideTooltip)

    -- Accepts what the cursor carries when it is the right kind (spell, pet action or item), has a readable and valid
    -- id and passes `accept`; clears the cursor and fires OnEnterPressed with the id. Ignored once the widget is
    -- released.
    local function drop()
        if not alive or widget.disabled or widget:IsReleasing() or type(GetCursorInfo) ~= "function" then
            return
        end

        local cursor = { pcall(GetCursorInfo) }

        if not cursor[1] or not addon.Platform:CanReadValue(cursor[2]) then
            return
        end

        local action = cursor[2]

        if
            item and action ~= "item"
            or not item and (kind == "pet" and action ~= "petaction" or kind ~= "pet" and action ~= "spell")
        then
            return
        end

        local id = (item or action == "petaction") and cursor[3] or cursor[5]

        if not addon.Platform:CanReadValue(id) or not spellID(id) then
            return
        end
        if not item and not addon.Platform:GetSpellInfo(id) then
            return
        end
        if accept and not accept(id) then
            return
        end

        -- The cursor has been validated before any data callback can rebuild
        -- this field. Never touch a newly acquired owner after that callback.
        if type(ClearCursor) == "function" then
            ClearCursor()
        end

        widget:Fire("OnEnterPressed", tostring(id))
    end

    -- Handles a click on the icon: right click clears the id; left click is a drop attempt.
    -- @param _ any  Unused (the clicked frame).
    -- @param button string  The mouse button.
    local function click(_, button)
        if not alive or widget.disabled or widget:IsReleasing() then
            return
        end

        if button == "RightButton" then
            widget:Fire("OnEnterPressed", "")
        elseif button == "LeftButton" then
            drop()
        end
    end

    -- Wraps OnHide: hides the tooltip, then runs the original script while the widget is still live.
    -- @param self table  The frame being hidden.
    -- @param ... any  The arguments passed on to the original script.
    -- @return any  What the original script returns.
    local function hide(self, ...)
        if not alive then
            return
        end

        hideTooltip()

        if originalHide then
            return originalHide(self, ...)
        end
    end

    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- A right click clears the id; it must not also close the window (UI/window.lua, UI/config.lua).
    frame.rmOwnsRightClick = true
    local installedClick = addon:SetUIScript(frame, "OnClick", click)
    local installedDrop = addon:SetUIScript(frame, "OnReceiveDrag", drop)
    local installedHide = addon:SetUIScript(frame, "OnHide", hide)

    -- Releases the widget: marks it dead, restores every script and method it replaced, clears its ids and then runs
    -- the original release.
    -- @param ... any  The arguments passed on to the original release.
    -- @return any  What the original release returns.
    widget.OnRelease = function(self, ...)
        alive = false
        hideTooltip()
        self[activeKey] = nil

        if frame:GetScript("OnClick") == installedClick then
            frame:SetScript("OnClick", originalClick)
        end
        if frame:GetScript("OnReceiveDrag") == installedDrop then
            frame:SetScript("OnReceiveDrag", originalDrag)
        end
        if frame:GetScript("OnHide") == installedHide then
            frame:SetScript("OnHide", originalHide)
        end

        frame:RegisterForClicks("LeftButtonUp")
        frame.rmOwnsRightClick = nil
        self.SetText, self.OnRelease = originalText, originalRelease
        self:SetUserData(key, nil)
        self:SetUserData(key .. "Metadata", nil)
        self.rmActionIconRevision = nil

        if originalRelease then
            return originalRelease(self, ...)
        end
    end

    widget:SetText(initialSpell)
    ---@cast widget RMActionIcon
    return widget
end

-- Creates a spell (kind "spell") or pet action (kind "pet") icon control showing `initialSpell`.
-- @param kind string  'spell' or 'pet'.
-- @param initialSpell any  The id (or text) to show first.
-- @param accept function|nil  accept(id) may veto a dropped id by returning false.
-- @return RMActionIcon  The widget.
---@return RMActionIcon
function addon:CreateSpellActionIcon(kind, initialSpell, accept)
    return actionIcon(kind, initialSpell, accept)
end

-- Creates an item icon control showing `initialItem` (an item id, link or name the platform can resolve).
-- @param initialItem any  The item id, link or name to show first.
-- @param accept function|nil  accept(id) may veto a dropped id by returning false.
-- @return RMActionIcon  The widget.
---@return RMActionIcon
function addon:CreateItemActionIcon(initialItem, accept)
    return actionIcon('item', initialItem, accept)
end
