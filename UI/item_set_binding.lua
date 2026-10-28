-- Drag-to-bind flow for item sets: lets the player put an item of a set on an action slot so RM can find and light that
-- button. Owns the pending-bind state (`addon.bindingItemSet`) and the per-character slot list under
-- `db.char.bindings`; it must not touch secure attributes, replace scripts, or run any of this in combat. Callers are
-- the settings item-set pages and the ACTIONBAR_SLOT_CHANGED handler in main.lua. Loaded from RotationMaster.toc after
-- UI/settings_items.lua; it depends on `addon:FindItemInItemSet` and, optionally, `ForEachActionButton` and
-- `ResolveActionButtonSlot` from buttons.lua.
local _, addon = ...

-- Item-set binding. Starting a bind puts the set's first available item on
-- the cursor and remembers the set (addon.bindingItemSet); placing it on an
-- action slot records that slot. A slot change normally reports the
-- placement (ACTIONBAR_SLOT_CHANGED in main.lua), but dropping or clicking an
-- item onto a slot that already holds that same item changes nothing and
-- reports nothing, so the indexed action buttons are also observed through
-- non-secure post hooks. A pending bind lasts only while its item rides the
-- cursor; nothing here touches secure attributes or replaces a script.

-- Returns the item the cursor is carrying.
-- @return number|string|nil  The item (id or link as the client reports it); nil when the cursor carries anything else.
local function cursorItem()
    if type(GetCursorInfo) ~= 'function' then
        return
    end

    local kind, item = GetCursorInfo()

    if kind == 'item' then
        return item
    end
end

-- True while the client is in combat lockdown, when action slots must not be read or hooked.
-- @return boolean|nil  Truthy in combat.
local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Records slot for set id once.
-- @param id string|number  The item set ID.
-- @param slot number  The action slot.
-- @return boolean  True when the slot was new.
function addon:RecordItemSetBinding(id, slot)
    local bindings = self.db.char.bindings
    local slots = bindings[id] or {}
    bindings[id] = slots

    for _, value in ipairs(slots) do
        if value == slot then
            return false
        end
    end

    slots[#slots + 1] = slot
    return true
end

-- Completes a pending bind on slot when that slot now holds a member of the pending set; the same bookkeeping as a
-- reported slot change.
-- @param slot number  The action slot that changed.
-- @return boolean  True when the bind completed; false when nothing was pending, the call came in combat or the slot
--   holds something else.
function addon:CompletePendingItemSetBind(slot)
    local pending = self.bindingItemSet

    if not pending or type(slot) ~= 'number' or inCombat() or type(GetActionInfo) ~= 'function' then
        return false
    end

    local kind, action = GetActionInfo(slot)

    if kind ~= 'item' or not self:FindItemInItemSet(pending, action) then
        return false
    end

    self.bindingItemSet = nil
    self:RecordItemSetBinding(pending, slot)

    if self.ButtonFetch then
        self:ButtonFetch()
    end
    if self.UpdateBoundButton then
        self:UpdateBoundButton(pending)
    end
    if self.itemSetCallback then
        self.itemSetCallback(pending)
    end

    return true
end

-- Hooks one action button (once) so dropping or clicking the pending item onto a slot that already holds it still
-- completes the bind.
-- @param button Button|nil  The action button.
-- @param slot number|nil  The fallback slot when the button cannot be resolved to a slot at event time.
local function observe(button, slot)
    if not button or button.rmItemSetBindHooked or type(button.HookScript) ~= 'function' then
        return
    end

    button.rmItemSetBindHooked = true

    -- Hook body: resolves which slot `frame` is now (falling back to the slot captured when hooked) and completes the
    -- pending bind if that slot holds a member of the set.
    -- @param frame Button  The action button the hook ran for.
    local function placed(frame)
        if not addon.bindingItemSet then
            return
        end

        local current = addon.ResolveActionButtonSlot and addon:ResolveActionButtonSlot(frame) or slot
        addon:CompletePendingItemSetBind(current)
    end

    -- Post hooks: they run after the bar's own handlers have placed (or not
    -- placed) the cursor item.
    if not button.HasScript or button:HasScript('OnReceiveDrag') then
        button:HookScript('OnReceiveDrag', placed)
    end
    if not button.HasScript or button:HasScript('PostClick') then
        button:HookScript('PostClick', placed)
    end
end

-- Keeps the pending bind only while its item is still on the cursor. Two
-- frames' grace lets the slot-change path or a button hook finish first.
local watcher

-- Hooks the action buttons for the pending bind (outside combat) and starts a per-frame watcher that cancels it once
-- the item leaves the cursor; a no-op when no bind is pending. Calling it again restarts the watcher's miss counter.
--
-- Keeps the pending bind only while its item is still on the cursor. Two frames' grace lets the slot-change path or a
-- button hook finish first.
function addon:WatchItemSetBind()
    if not self.bindingItemSet then
        return
    end

    if self.ForEachActionButton and not inCombat() then
        self:ForEachActionButton(observe)
    end

    if type(CreateFrame) ~= 'function' then
        return
    end

    watcher = watcher or CreateFrame('Frame')
    local misses = 0

    -- Per-frame watcher: counts the frames in which the cursor no longer carries a member of the set and cancels the
    -- pending bind after two.
    -- @param frame Frame  The watcher frame.
    watcher:SetScript('OnUpdate', function(frame)
        local pending = addon.bindingItemSet

        if not pending then
            frame:SetScript('OnUpdate', nil)
            return
        end

        local item = cursorItem()

        if item and addon:FindItemInItemSet(pending, item) then
            misses = 0
            return
        end

        misses = misses + 1

        if misses >= 2 then
            addon.bindingItemSet = nil
            frame:SetScript('OnUpdate', nil)
        end
    end)
end

-- Starts a bind for set id: same preconditions for click and drag.
-- @param id string|number  The item set ID.
-- @param first number|string  The item to pick up (the set's first available item).
-- @return boolean  True when the bind started.
-- @return string|nil  The reason key when false: 'combat' or 'unavailable'.
function addon:BeginItemSetBind(id, first)
    if inCombat() then
        return false, 'combat'
    end

    -- Retail/Forever have only C_Item.PickupItem; Classic's global is a
    -- loadDeprecationFallbacks alias of it.
    local pickup = type(C_Item) == 'table' and C_Item.PickupItem or nil

    if type(pickup) ~= 'function' then
        pickup = PickupItem
    end

    if not first or type(pickup) ~= 'function' then
        return false, 'unavailable'
    end

    self.bindingItemSet = id
    pickup(first)
    self:WatchItemSetBind()
    return true
end

-- Clears the cursor only when it still holds a member of set id: after a swap the cursor holds the user's previous
-- action, which must survive.
-- @param id string|number  The item set ID.
-- @return boolean  True when the cursor was cleared.
function addon:ClearItemSetBindCursor(id)
    local item = cursorItem()

    if item and self:FindItemInItemSet(id, item) and type(ClearCursor) == 'function' then
        ClearCursor()
        return true
    end

    return false
end
