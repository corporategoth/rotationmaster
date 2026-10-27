-- Reordering for the settings form's roster (the scrolling, searchable list of entries such as item sets): which rows
-- show Move Up/Down buttons and a drag handle, the drag ghost and the gap drop zones between rows, and the commit of a
-- move into `roster.options.order`, followed by options.orderChanged. Changes only the draft order list the owner
-- passes in; saving is the form's job. Rows are 34 px apart, which every gap calculation here assumes.
-- settings_form.lua installs these methods on the form class; UI/settings_layout.lua calls them while it builds the
-- roster. Loaded from RotationMaster.toc after UI/settings_setup.lua and before UI/settings_layout.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Helpers
-- ============================================================================

-- The id of an order entry, which may be a bare id or a table with an `id` field.
local function identity(value)
    return type(value) == 'table' and value.id or value
end

-- Maps each entry id of an order list to its first index; later duplicates are ignored.
local function indices(items)
    local result = {}

    for index, value in ipairs(items or {}) do
        local id = identity(value)
        if id ~= nil and result[id] == nil then result[id] = index end
    end

    return result
end

-- ============================================================================
-- Row binding
-- ============================================================================

-- Adds the roster-order methods to the settings form class `p`; called once when the form class is built.
function addon:InstallSettingsRosterOrder(p)
    -- Wires one roster row after it is drawn: ordered entries get Move Up/Down buttons and drag-to-reorder; unordered
    -- rows may drag out of the page (options.dragOut). Handlers capture the row lease and `revision`, so a reused row
    -- or a rebuilt roster ignores late clicks.
    function p:BindRosterOrderRow(row, entry, revision)
        local r = self.roster
        local items = r.options.order
        local index = r.orderIndex[entry.value]
        local lease = row.rosterLease
        row.icon:ClearAllPoints()
        row.icon:SetPoint('LEFT', index and 24 or 4, 0)
        addon:AlignWorkbenchTextLeft(row, entry.icon and (index and 54 or 34) or 6)

        if row.up then
            row.up:Hide()
            row.down:Hide()
        end

        addon:SetUIScript(row, 'OnDragStart', nil)
        addon:SetUIScript(row, 'OnDragStop', nil)

        -- An unordered roster may let its rows be dragged out of the page
        -- (Item Sets: drag a set onto an action bar slot).
        if not index and r.options.dragOut then
            -- Drag-out variant of valid(): the row must still show this entry in this roster build.
        local function current()
                return r.active and r.revision == revision and row.rosterLease == lease and p:Valid(r.generation)
            end

            addon:BindWorkbenchDragSource(
                row,
                function()
                    if current() then r.options.dragOut(entry.value) end
                end,
                function() end
            )

            for _, event in ipairs({ 'OnClick', 'OnMouseDown', 'OnDragStart', 'OnDragStop' }) do
                local handler = row:GetScript(event)

                if handler then
                    addon:SetUIScript(row, event, function(...)
                        if current() then return handler(...) end
                    end)
                end
            end

            return
        end

        if not index then return end

        if not row.up then
            row.up = addon:CreateWorkbenchIconButton(row, 'up', L['Move Up'])
            row.down = addon:CreateWorkbenchIconButton(row, 'down', L['Move Down'])
            row.up:SetPoint('TOPLEFT', 1, -2)
            row.down:SetPoint('TOPLEFT', 1, -16)
            row.up:SetSize(18, 14)
            row.down:SetSize(18, 14)
        end

        row.up:Show()
        row.down:Show()

        if index == 1 then
            row.up:Disable()
        else
            row.up:Enable()
        end

        if index == #items then
            row.down:Disable()
        else
            row.down:Enable()
        end

        -- True while the row still belongs to this roster build and entry.
        local function valid()
            return r.active and r.revision == revision and row.rosterLease == lease and p:Valid(r.generation)
        end

        addon:SetUIScript(
            row.up,
            'OnClick',
            self:Guard(function()
                if valid() then
                    r.orderView.drag = entry.value
                    r.orderView.tail = false
                    r.orderView:Drop(index - 1)
                end
            end)
        )

        addon:SetUIScript(
            row.down,
            'OnClick',
            self:Guard(function()
                if valid() then
                    r.orderView.drag = entry.value
                    r.orderView.tail = false
                    r.orderView:Drop(index + 2)
                end
            end)
        )

        addon:BindWorkbenchDragSource(
            row,
            function()
                if valid() then r.orderView:Begin(entry.value, entry.text) end
            end,
            function()
                if valid() then r.orderView:EndDrag() end
            end
        )

        -- The shared source wrapper changes rmDragged before calling start or
        -- the captured click. Guard that outer layer as well as its callback.
        for _, event in ipairs({ 'OnClick', 'OnMouseDown', 'OnDragStart', 'OnDragStop' }) do
            local handler = row:GetScript(event)

            if handler then
                addon:SetUIScript(row, event, function(...)
                    if valid() then return handler(...) end
                end)
            end
        end
    end


    -- ============================================================================
    -- Order view
    -- ============================================================================

    -- Builds the per-roster order view (`r.orderView`: ghost, zones, drag state) and the table of gap positions between
    -- ordered rows; clears the view when the roster has no order. Called on every roster rebuild, so it first cancels
    -- any drag still in flight.
    function p:PrepareRosterOrder(revision)
        local r = self.roster
        if r.orderView then r.orderView:Cancel() end
        r.orderIndex = indices(r.options.order)
        r.logicalGaps = {}

        if not r.options.order then
            r.orderView = nil
            return
        end

        local items = r.options.order
        local token = self.generation
        r.orderGhost = r.orderGhost or addon:CreateWorkbenchDragCard()
        r.orderZones = r.orderZones or {}
        local view = { zones = r.orderZones, ghost = r.orderGhost }
        r.orderView = view
        local last

        for position, entry in ipairs(r.matches) do
            local index = r.orderIndex[entry.value]

            if index then
                r.logicalGaps[#r.logicalGaps + 1] = { y = (position - 1) * 34, gap = index }
                last = { y = position * 34, gap = index + 1 }
            end
        end

        if last then r.logicalGaps[#r.logicalGaps + 1] = last end

        -- True while this view still belongs to the live roster build.
        local function valid()
            return r.active and p:Valid(token) and r.revision == revision
        end

        -- The current index of the dragged entry in the order list.
        function view:Index()
            return r.orderIndex[self.drag]
        end

        -- Ends a drag without moving anything; hides the ghost and zones and redraws the rows the drag had hidden.
        function view:Cancel()
            local moving = self.drag
            self.drag = nil
            self.tail = nil
            self.carried = nil
            self.from = nil

            if r.orderView == self then
                self.ghost:Hide()
                addon:SetUIScript(self.ghost, 'OnUpdate', nil)

                for _, zone in ipairs(self.zones) do
                    zone:Hide()
                    zone.marker:Hide()
                end

                if moving and valid() and not r.rebuilding then p:RefreshRosterViewport() end
            end
        end

        -- True when `entry` moves with the current drag (itself, or it and every later entry in tail mode).
        function view:Carries(entry)
            local index = r.orderIndex[entry.value]

            return self.drag
                and index
                and (self.tail and index >= self.from or not self.tail and entry.value == self.drag)
        end

        -- True when the dragged range may be dropped before order index `gap`.
        function view:CanDrop(gap)
            return valid() and addon:CanReorderWorkbenchRange(items, self:Index(), gap, self.tail)
        end

        -- Moves the dragged range before order index `gap` and redraws. Returns true when the order changed. Pending
        -- field edits are flushed first, and identities are resolved again afterward because that flush can rebuild
        -- the roster.
        function view:Drop(gap)
            local id, tail = self.drag, self.tail
            local before = items[gap] and identity(items[gap])
            local allowed = self:CanDrop(gap)
            self:Cancel()
            if not allowed or not p:FlushEdits() or not p:Valid(token) or r.options.order ~= items then return false end
            -- A pending rename can refresh the roster while preserving this
            -- command. Resolve both identities again after that flush.
            local current = indices(items)
            local from = current[id]
            gap = before and current[before] or #items + 1
            if not addon:ReorderWorkbenchRange(items, from, gap, tail) then return false end
            if r.options.orderChanged then r.options.orderChanged(items) end
            p:Draw()
            return true
        end

        -- Highlights the valid drop zone under the pointer and returns it, or nil.
        function view:Hover()
            local selected

            for _, zone in ipairs(self.zones) do
                if
                    zone.gap
                    and zone:IsShown()
                    and addon:IsWorkbenchDropZoneUnderPointer(zone, r.scroll)
                    and self:CanDrop(zone.gap)
                then
                    selected = zone
                    break
                end
            end

            for _, zone in ipairs(self.zones) do
                if zone == selected then
                    zone.marker:Show()
                else
                    zone.marker:Hide()
                end
            end

            return selected
        end

        -- Mouse released: drops on the hovered zone, else cancels.
        function view:EndDrag()
            local zone = self:Hover()

            if zone then
                self:Drop(zone.gap)
            else
                self:Cancel()
            end
        end

        -- Starts dragging entry `id` (with every later entry when `tail`, which defaults to the Ctrl key). Shows the
        -- ghost and the zones that would be legal drops, and polls the pointer until the button is released.
        function view:Begin(id, title, tail)
            if tail == nil then tail = IsControlKeyDown and IsControlKeyDown() or false end
            self:Cancel()
            if not valid() or not p:FlushEdits() or not p:Valid(token) or r.options.order ~= items then return end
            if r.orderView ~= self then return r.orderView:Begin(id, title, tail) end
            local from = r.orderIndex[id]
            if not from then return end
            self.drag = id
            self.tail = tail
            self.from = from
            self.carried = {}

            self.ghost:Present(
                (tail and L['Move this and following entries'] .. ': ' or '') .. title,
                L['Drop in a highlighted gap.'],
                p.frame,
                tail and #items - from + 1 or 1
            )

            local entries = {}

            for _, row in ipairs(r.rows) do
                if row.rosterLease then
                    local index = r.orderIndex[row.rosterEntry.value]

                    if index and (tail and index >= from or not tail and row.rosterEntry.value == id) then
                        self.carried[row] = true

                        entries[#entries + 1] = {
                            frame = row,
                            x = 0,
                            y = (row.rosterIndex - 1) * 34,
                            width = row:GetWidth(),
                            height = row:GetHeight(),
                        }
                    end
                end
            end

            self.ghost:PresentCards(entries, r.child)

            self.ghost:CaptureCancel(function()
                if r.orderView == self then self:Cancel() end
            end)

            for _, zone in ipairs(self.zones) do
                if zone.gap and self:CanDrop(zone.gap) then
                    zone:Show()
                else
                    zone:Hide()
                end
            end

            addon:SetUIScript(self.ghost, 'OnUpdate', function()
                if not valid() then
                    self:Cancel()
                    return
                end

                self.ghost:FollowPointer()
                self:Hover()
                if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
            end)
        end

        self.cleanups[#self.cleanups + 1] = function() view:Cancel() end
    end


    -- ============================================================================
    -- Drop zones
    -- ============================================================================

    -- Creates and positions the 12 px drop zones for the gaps near the visible part of the roster (binary search over
    -- the sorted gap positions), and recycles zones that scrolled away. Runs on every scroll.
    function p:BuildRosterOrderZones()
        local r = self.roster
        local view = r.orderView
        if not view then return end
        local top = r.scroll.workbenchBar:GetValue() - 102
        local bottom = top + r.scroll:GetHeight() + 204
        local gaps = r.logicalGaps
        local low, high = 1, #gaps

        while low <= high do
            local mid = math.floor((low + high) / 2)

            if gaps[mid].y + 6 < top then
                low = mid + 1
            else
                high = mid - 1
            end
        end

        local used = 0

        for i = low, #gaps do
            local target = gaps[i]
            if target.y - 6 > bottom then break end
            used = used + 1
            local zone = r.orderZones[used]

            if not zone then
                zone = CreateFrame('Frame', nil, r.child)
                zone.marker = zone:CreateTexture(nil, 'OVERLAY')
                zone.marker:SetColorTexture(.9, .75, .3, 1)
                zone.marker:SetPoint('LEFT')
                zone.marker:SetPoint('RIGHT')
                zone.marker:SetHeight(3)
                zone:EnableMouse(false)
                r.orderZones[used] = zone
            end

            local lease = {}
            zone.rosterLease = lease
            zone.target = target
            zone.gap = target.gap
            zone:ClearAllPoints()
            zone:SetPoint('TOPLEFT', 0, -target.y + 6)
            zone:SetSize(r.child:GetWidth(), 12)
            zone:SetFrameLevel(r.child:GetFrameLevel() + 50)

            addon:SetUIScript(
                zone,
                'OnReceiveDrag',
                self:Guard(function()
                    if r.orderView == view and zone.rosterLease == lease and zone.target == target then
                        view:Drop(target.gap)
                    end
                end)
            )

            if view.drag and view:CanDrop(target.gap) then
                zone:Show()
            else
                zone:Hide()
            end

            zone.marker:Hide()
        end

        for i = used + 1, #r.orderZones do
            local zone = r.orderZones[i]
            zone.rosterLease = nil
            zone.target = nil
            zone.gap = nil
            addon:SetUIScript(zone, 'OnReceiveDrag', nil)
            zone:Hide()
            zone.marker:Hide()
        end
    end
end
