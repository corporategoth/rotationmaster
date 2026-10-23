local _,addon=...
-- Item-set binding. Starting a bind puts the set's first available item on
-- the cursor and remembers the set (addon.bindingItemSet); placing it on an
-- action slot records that slot. A slot change normally reports the
-- placement (ACTIONBAR_SLOT_CHANGED in main.lua), but dropping or clicking an
-- item onto a slot that already holds that same item changes nothing and
-- reports nothing, so the indexed action buttons are also observed through
-- non-secure post hooks. A pending bind lasts only while its item rides the
-- cursor; nothing here touches secure attributes or replaces a script.

local function cursorItem()
    if type(GetCursorInfo)~='function' then return end
    local kind,item=GetCursorInfo()
    if kind=='item' then return item end
end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

-- Records slot for set id once. Returns true when the slot was new.
function addon:RecordItemSetBinding(id,slot)
    local bindings=self.db.char.bindings;local slots=bindings[id] or {};bindings[id]=slots
    for _,value in ipairs(slots) do if value==slot then return false end end
    slots[#slots+1]=slot;return true
end

-- Completes a pending bind on slot when that slot now holds a member of the
-- pending set; the same bookkeeping as a reported slot change.
function addon:CompletePendingItemSetBind(slot)
    local pending=self.bindingItemSet
    if not pending or type(slot)~='number' or inCombat() or type(GetActionInfo)~='function' then return false end
    local kind,action=GetActionInfo(slot)
    if kind~='item' or not self:FindItemInItemSet(pending,action) then return false end
    self.bindingItemSet=nil;self:RecordItemSetBinding(pending,slot)
    if self.ButtonFetch then self:ButtonFetch() end
    if self.UpdateBoundButton then self:UpdateBoundButton(pending) end
    if self.itemSetCallback then self.itemSetCallback(pending) end
    return true
end

local function observe(button,slot)
    if not button or button.rmItemSetBindHooked or type(button.HookScript)~='function' then return end
    button.rmItemSetBindHooked=true
    local function placed(frame)
        if not addon.bindingItemSet then return end
        local current=addon.ResolveActionButtonSlot and addon:ResolveActionButtonSlot(frame) or slot
        addon:CompletePendingItemSetBind(current)
    end
    -- Post hooks: they run after the bar's own handlers have placed (or not
    -- placed) the cursor item.
    if not button.HasScript or button:HasScript('OnReceiveDrag') then button:HookScript('OnReceiveDrag',placed) end
    if not button.HasScript or button:HasScript('PostClick') then button:HookScript('PostClick',placed) end
end

-- Keeps the pending bind only while its item is still on the cursor. Two
-- frames' grace lets the slot-change path or a button hook finish first.
local watcher
function addon:WatchItemSetBind()
    if not self.bindingItemSet then return end
    if self.ForEachActionButton and not inCombat() then self:ForEachActionButton(observe) end
    if type(CreateFrame)~='function' then return end
    watcher=watcher or CreateFrame('Frame')
    local misses=0
    watcher:SetScript('OnUpdate',function(frame)
        local pending=addon.bindingItemSet
        if not pending then frame:SetScript('OnUpdate',nil);return end
        local item=cursorItem()
        if item and addon:FindItemInItemSet(pending,item) then misses=0;return end
        misses=misses+1
        if misses>=2 then addon.bindingItemSet=nil;frame:SetScript('OnUpdate',nil) end
    end)
end

-- Starts a bind for set id: same preconditions for click and drag. Returns
-- true, or false and a reason key: 'combat', 'unavailable'.
function addon:BeginItemSetBind(id,first)
    if inCombat() then return false,'combat' end
    if not first or type(PickupItem)~='function' then return false,'unavailable' end
    self.bindingItemSet=id;PickupItem(first);self:WatchItemSetBind();return true
end

-- Clears the cursor only when it still holds a member of set id: after a
-- swap the cursor holds the user's previous action, which must survive.
function addon:ClearItemSetBindCursor(id)
    local item=cursorItem()
    if item and self:FindItemInItemSet(id,item) and type(ClearCursor)=='function' then ClearCursor();return true end
    return false
end
