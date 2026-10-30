-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Card view of a custom condition's field schema inside the schema editor (UI/schema_editor.lua): one card per field
-- with name, type, Required flag and move, duplicate, delete and fold controls, plus drag-and-drop to reorder or
-- re-nest. It draws the scene computed by Core/schema_canvas.lua and routes every change through the draft model
-- (`model:Transfer`, `SetKind`, `Add`, ...); it never edits the saved condition. Cards are virtualized: only rows near
-- the viewport are bound, and a row with focus, unsaved text, an open menu or an active drag stays bound. Loaded from
-- RotationMaster.toc after Core/schema_canvas.lua, just before UI/schema_editor.lua, which calls
-- `addon:BuildFieldSchemaCards`.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Helpers
-- ============================================================================

local types = {
    { value = 'string', text = L['Text'] },
    { value = 'number', text = L['Number'] },
    { value = 'boolean', text = L['Boolean'] },
    { value = 'condition', text = L['Condition'] },
    { value = 'condition[]', text = L['Condition list'] },
    { value = 'record', text = L['Record / map'] },
    { value = 'union', text = L['Allowed types / list alternatives'] },
}

-- Joins a field path (a list of child positions from the root) into the string that keys cards, rows and scene entries.
-- @param path table  The field path (a list of child positions).
-- @return string  The positions joined with '/'.
local function key(path)
    return table.concat(path, '/')
end

-- Returns a copy of a path without its last step, the path of the containing field.
-- @param path table  The field path; it is not modified.
-- @return table  The parent's path (empty for a root field).
local function parentPath(path)
    local result = addon:CopySettingsData(path)
    table.remove(result)
    return result
end

-- Tells whether path `a` is `b` or an ancestor of it.
-- @param a table  The candidate ancestor path.
-- @param b table  The path to test.
-- @return boolean  True when `a` is a prefix of `b`.
local function prefix(a, b)
    if #a > #b then
        return false
    end

    for i, v in ipairs(a) do
        if b[i] ~= v then
            return false
        end
    end

    return true
end

-- ============================================================================
-- The card view
-- ============================================================================

-- Builds the card view for the editor `owner` on `form`: computes the scene and creates the drag ghost. It returns
-- nothing but leaves `owner.cardView` and `form.schemaViewport` set. Redraws on scroll through `view:Refresh`, and
-- releases every card and drag when the form is torn down.
-- @param form table  The settings form that hosts the cards.
-- @param owner table  The schema editor window (model, folded, baseline, UpdateActions, ...).
function addon:BuildFieldSchemaCards(form, owner)
    local model = owner.model
    local token = form.generation
    owner.cards = {}
    owner.folded = owner.folded or {}
    local ghost = form:Acquire('schemaGhost', function() return addon:CreateWorkbenchDragCard() end)
    ghost:SetParent(UIParent)
    ghost:Hide()

    local view = {
        zones = {},
        rows = {},
        ghost = ghost,
        scene = addon:BuildFieldSchemaScene(model, owner.folded, form.width, owner.baseline),
    }

    owner.cardView = view
    form.y = view.scene.height - 12

    -- Tells whether the editor is open and this draw of the form is still the current one.
    -- @return boolean  True while the view's callbacks may act.
    local function valid()
        return owner.active and form:Valid(token)
    end

    -- Runs a model change after flushing pending text; when it reports success the form is redrawn.
    -- @param fn function  Performs the change on the model and returns true when it was accepted.
    -- @return boolean|nil  True on success; nil when stale, blocked by invalid text, or refused by the model.
    local function command(fn)
        if valid() and form:FlushEdits() and fn() then
            form:Draw()
            return true
        end
    end

    -- Ends any drag: hides the ghost and the drop zones and redraws, unless the view is being torn down.
    function view:CancelDrag()
        local moving = self.drag
        self.drag = nil
        ghost:Hide()
        addon:SetUIScript(ghost, 'OnUpdate', nil)

        for _, zone in ipairs(self.zones) do
            zone:Hide()
            zone.marker:Hide()
        end

        if moving and not self.releasing and valid() then
            self:Refresh()
        end
    end

    -- Tells whether the dragged field may be dropped into a gap of a container. Answers are cached for the drag, since
    -- the pointer asks every frame.
    -- @param path table  The path of the container.
    -- @param gap number  The gap (insert position) within the container.
    -- @return boolean  True when the model accepts the move.
    function view:CanDrop(path, gap)
        if not valid() or not self.drag then
            return false
        end

        local id = key(path) .. ':' .. gap
        local cache = self.drag.allowed

        if cache[id] == nil then
            cache[id] = model:CanTransfer(self.drag.path, path, gap, self.drag.tail) == true
        end

        return cache[id]
    end

    -- Drops the dragged field at the target and ends the drag.
    -- @param path table  The path of the target container.
    -- @param gap number  The gap within the container.
    -- @return boolean  True only when the model accepted the move.
    function view:Drop(path, gap)
        local drag = self.drag
        local allowed = self:CanDrop(path, gap)
        self:CancelDrag()

        if allowed then
            return command(function() return model:Transfer(drag.path, path, gap, drag.tail) end) or false
        end

        return false
    end

    -- Finds the deepest allowed drop zone under the pointer, shows its marker (hiding the others).
    -- @return table|nil  The drop zone; nil when none is under the pointer.
    function view:Hover()
        local target

        for _, zone in ipairs(self.zones) do
            if
                zone.target
                and zone:IsShown()
                and addon:IsWorkbenchDropZoneUnderPointer(zone, form.scroll)
                and self:CanDrop(zone.path, zone.gap)
                and (not target or #zone.path > #target.path)
            then
                target = zone
            end
        end

        for _, zone in ipairs(self.zones) do
            if zone == target then
                zone.marker:Show()
            else
                zone.marker:Hide()
            end
        end

        return target
    end

    -- Called on mouse release: drops on the hovered zone if there is one, otherwise cancels.
    function view:EndDrag()
        local target = self:Hover()

        if target then
            self:Drop(target.path, target.gap)
        else
            self:CancelDrag()
        end
    end

    -- Starts dragging the field at a path (with Ctrl, it and all following siblings): lifts the cards being carried
    -- into the ghost, offers only the gaps that would move them, and polls the pointer until release. Does nothing
    -- while pending text is invalid.
    -- @param path table  The path of the field to drag.
    function view:BeginDrag(path)
        self:CancelDrag()

        if not valid() or not form:FlushEdits() then
            return
        end

        local node = model:Node(path)
        local parent = model:Node(parentPath(path))

        if not node or not parent then
            return
        end

        local tail = IsControlKeyDown and IsControlKeyDown() or false
        self.drag = { path = addon:CopySettingsData(path), tail = tail, allowed = {}, carried = {} }
        local entries = {}
        local last = tail and #parent.children or path[#path]
        local sourceParent = parentPath(path)

        for _, row in ipairs(self.rows) do
            if row.lease then
                local location = row.path
                local index = location[#path]

                if
                    prefix(sourceParent, location)
                    and type(index) == 'number'
                    and index >= path[#path]
                    and index <= last
                then
                    self.drag.carried[row] = true

                    entries[#entries + 1] = {
                        frame = row.frame,
                        x = row.geometry.x,
                        y = row.geometry.y,
                        width = row.geometry.width,
                        height = row.geometry.height,
                    }
                end
            end
        end

        local count = 0

        for _, entry in ipairs(self.scene.index.nodes) do
            local index = entry.path[#path]

            if
                prefix(sourceParent, entry.path) and type(index) == 'number' and index >= path[#path] and index <= last
            then
                count = count + 1
            end
        end

        ghost:Present(
            tostring(node.name),
            L['Drag one entry; Ctrl-drag moves it and all following siblings.'],
            form.frame,
            count
        )

        ghost:PresentCards(entries, form.child)

        ghost:CaptureCancel(function()
            self:CancelDrag()
        end)

        -- Gaps that would leave the carried field where it is are not offered.
        for _, zone in ipairs(self.zones) do
            if zone.target and self:CanDrop(zone.path, zone.gap) then
                zone:Show()
            else
                zone:Hide()
            end
        end

        addon:SetUIScript(ghost, 'OnUpdate', function()
            if not valid() then
                self:CancelDrag()
                return
            end

            ghost:FollowPointer()
            self:Hover()

            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
                self:EndDrag()
            end
        end)
    end

    -- Builds one reusable card with its controls and a private form (`c.form`) that inherits from the editor form, so
    -- the card's own fields keep separate pools and edit lists.
    -- @return table  The card ({ frame, decoration, fold, up, down, duplicate, remove, help, line, form }).
    local function createRow()
        local c = {}
        c.frame = CreateFrame('Frame', nil, form.child)
        c.frame:EnableMouse(true)
        c.decoration = addon:CreateRoundedCardDecoration(c.frame)

        -- Shows the card frame.
        function c:Show()
            self.frame:Show()
        end

        -- Hides the card frame.
        function c:Hide()
            self.frame:Hide()
        end

        -- Reparents the card frame.
        -- @param value table  The new parent frame.
        function c:SetParent(value)
            self.frame:SetParent(value)
        end

        c.fold = addon:CreateConditionChevron(c.frame)
        c.fold:SetPoint('TOPLEFT', 3, -3)
        c.fold:SetSize(18, 18)

        for _, entry in ipairs({
            { 'up', 'up', L['Move Up'] },
            { 'down', 'down', L['Move Down'] },
            { 'duplicate', 'copy', L['Duplicate'] },
            { 'remove', 'trash', L['Delete'] },
        }) do
            c[entry[1]] = addon:CreateWorkbenchIconButton(c.frame, entry[2], entry[3])
            c[entry[1]]:SetSize(18, 18)
        end

        c.help = addon:CreateWorkbenchHelpButton(c.frame, L['Help'])
        c.help:SetSize(20, 20)
        c.help:SetPoint('TOPRIGHT', -4, -3)
        c.duplicate:SetPoint('TOPRIGHT', -4, -25)
        c.remove:SetPoint('TOPRIGHT', -4, -47)
        c.remove.icon:SetVertexColor(1, .25, .25, 1)
        c.up:SetPoint('TOPLEFT', 4, -23)
        c.down:SetPoint('TOPLEFT', c.up, 'BOTTOMLEFT', 0, 0)
        c.line = c.frame:CreateTexture(nil, 'BACKGROUND')
        c.line:SetColorTexture(.5, .48, .34, .6)

        c.form = setmetatable(
            { frame = c.frame, child = c.frame, pool = {}, counts = {}, fields = {}, edits = {}, generation = 0 },
            { __index = form }
        )

        return c
    end

    -- Unbinds a card from its field: bumps the generation so queued callbacks go stale, clears focus, hides its
    -- controls and forgets its path.
    -- @param row table  The card to release.
    function view:ReleaseRow(row)
        row.lease = nil
        row.form.generation = row.form.generation + 1

        if self.menuRow == row and form.menu then
            form.menu.frame:Hide()
            self.menuRow = nil
        end

        for _, record in ipairs(row.form.edits) do
            record.control:ClearFocus()
        end

        for _, list in pairs(row.form.pool) do
            for _, control in ipairs(list) do
                control:Hide()
            end
        end

        row.form.edits = {}
        row.form.fields = {}
        row.path = nil
        row.geometry = nil
        row.frame:Hide()
    end

    -- Fills a card for the field described by `geometry` (name box, type choice, Required, movement buttons, help,
    -- fold, Add field) and attaches the callbacks, all guarded by this binding's lease. Restores any pending text typed
    -- before a redraw.
    -- @param row table  The card to bind.
    -- @param geometry table  The scene entry for the field (path, key, node, parent, x, y, width, height, index, addX,
    --   addY).
    function view:Bind(row, geometry)
        local path = geometry.path
        local id = geometry.key
        local child = geometry.node
        local parent = geometry.parent
        local width = geometry.width
        local lease = {}
        row.lease = lease
        row.path = path
        row.geometry = geometry
        row.y = geometry.y
        local p = row.form
        p.generation = p.generation + 1
        p.counts = {}
        p.fields = {}
        p.edits = {}
        p.width = width
        p.y = 0
        p.surface = row.frame

        -- Tells whether the editor, this card's binding and the given form generation are all still current.
        -- @param generation number  The form generation the caller was created under.
        -- @return boolean  True while the caller may act.
        function p:Valid(generation)
            return valid() and row.lease == lease and self.generation == generation
        end

        -- Wraps a callback so it only runs if the form generation has not changed since it was created.
        -- @param callback function  The function to guard.
        -- @return function  The guarded function; it returns what the callback returns, or nothing when stale.
        function p:Guard(callback)
            local generation = self.generation

            return function(...)
                if self:Valid(generation) then
                    return callback(...)
                end
            end
        end

        -- Forwards to the editor form, so a card commits the whole editor's pending text.
        -- @return boolean  What the editor form's FlushEdits returns (true when all pending text was committed).
        function p:FlushEdits()
            return form:FlushEdits()
        end

        -- Forwards to the editor form's message line.
        -- @param ... any  The arguments of the editor form's Message.
        -- @return any  Whatever the editor form's Message returns.
        function p:Message(...)
            return form:Message(...)
        end

        -- Opens a choice menu on the editor form and remembers which card owns it, so that card stays bound while the
        -- menu is open.
        -- @param anchor table  The frame the menu opens under.
        -- @param entries table[]  The menu entries.
        -- @param changed function  Called with the chosen value (guarded by the card's generation).
        -- @param inline boolean|nil  True hides the search box.
        function p:ShowChoices(anchor, entries, changed, inline)
            view.menuRow = row
            form:ShowChoices(anchor, entries, self:Guard(changed), inline)
        end

        row.frame:SetParent(form.child)
        row.frame:ClearAllPoints()
        row.frame:SetPoint('TOPLEFT', geometry.x, -geometry.y)
        row.frame:SetSize(width, geometry.height)
        row.frame:SetFrameLevel(form.child:GetFrameLevel() + #path * 3)
        row.frame:Show()
        local nameWidth = math.max(84, (width - 112) * .43)

        local name = p:Edit(
            'field_' .. id,
            nil,
            parent.kind == 'record' and child.name or tostring(geometry.index),
            function(text)
                if parent.kind ~= 'record' or text:match('^[%a_][%w_]*$') then
                    return text
                end
            end,
            function(text)
                model:Change(function()
                    child.name = text
                end)

                owner:UpdateActions()
            end
        )

        row.name = name
        name:SetMaxLetters(math.max(4096, #tostring(child.name or '')))
        name:SetText(parent.kind == 'record' and child.name or tostring(geometry.index))
        name:ClearAllPoints()
        name:SetPoint('TOPLEFT', 28, -23)
        name:SetWidth(nameWidth)
        name:EnableMouse(parent.kind == 'record')
        name:EnableKeyboard(parent.kind == 'record')
        local textChanged = name:GetScript('OnTextChanged')

        addon:SetUIScript(name, 'OnTextChanged', p:Guard(function(input, user)
            textChanged(input, user)

            if user then
                owner:UpdateActions()
            end
        end))

        local kind = p:Choice('type_' .. id, nil, child.kind, types, function(value)
            command(function() return model:SetKind(path, value) end)
        end)

        row.type = kind
        kind:ClearAllPoints()
        kind:SetPoint('TOPLEFT', 34 + nameWidth, -23)
        kind:SetWidth(width - nameWidth - 64)

        if geometry.index == 1 then
            row.up:Disable()
        else
            row.up:Enable()
        end

        if geometry.index == #parent.children then
            row.down:Disable()
        else
            row.down:Enable()
        end

        row.required = nil

        if #path == 1 then
            local required = p:Check('required_' .. id, L['Required'], child.required == true, function(value)
                command(function() return model:SetRequired(path, value) end)
            end)

            row.required = required
            required:ClearAllPoints()
            required:SetPoint('TOPRIGHT', -30, -2)
            required:SetWidth(106)
            required:GetFontString():SetWidth(82)
        end

        local parentHere = parentPath(path)

        addon:SetUIScript(row.up, 'OnClick', p:Guard(function()
            command(function() return model:Transfer(path, parentHere, geometry.index - 1) end)
        end))

        addon:SetUIScript(row.down, 'OnClick', p:Guard(function()
            command(function() return model:Transfer(path, parentHere, geometry.index + 2) end)
        end))

        addon:SetUIScript(row.duplicate, 'OnClick', p:Guard(function()
            command(function() return model:Duplicate(path) end)
        end))

        addon:SetUIScript(row.remove, 'OnClick', p:Guard(function()
            command(function() return model:Remove(path) end)
        end))

        -- Opens the Help window for the field schema (fields, moving and copying, Required, saving).
        addon:SetUIScript(row.help, 'OnClick', p:Guard(function()
            addon:ShowWorkbenchHelp(
                tostring(child.name),
                {
                    {
                        title = L['Fields'],
                        text = L['Field names are Lua identifiers. Choose a field type from its dropdown. Records contain named fields; allowed types contain alternatives, including nested records.'],
                    },
                    {
                        title = L['Move, copy and remove'],
                        text = L['Drag one entry; Ctrl-drag moves it and all following siblings.']
                            .. ' '
                            .. L['A container carries its nested fields. Drop into a highlighted gap. Up / Down moves within the current container; Duplicate copies the complete field; the red trash can deletes it.'],
                    },
                    {
                        title = L['Required'],
                        text = L['Required root fields must have a value before this condition can run. Rename, reorder and duplicate keep this flag; removing the field removes its requirement. Moving it into a nested structure makes it optional. Undo restores both. Callback code is unchanged.'],
                    },
                    {
                        title = L['Help and saving'],
                        text = L['The chevron hides or shows nested fields. Add field appends to that container. Undo / Redo affect the draft. Apply validates and stages the schema; Cancel leaves the condition unchanged. Red borders mark invalid names or incomplete types.'],
                    },
                },
                owner.chrome and owner.chrome.owner or L['Field schema']
            )
        end))

        row.fold:PointState(owner.folded[id] and 'compact' or 'normal')

        if child.children then
            row.fold:Show()
        else
            row.fold:Hide()
        end

        addon:SetUIScript(row.fold, 'OnClick', p:Guard(function()
            if form:FlushEdits() then
                owner.folded[id] = not owner.folded[id]
                form:Draw()
            end
        end))

        addon:BindWorkbenchDragSource(
            row.frame,
            p:Guard(function()
                view:BeginDrag(path)
            end),
            p:Guard(function()
                view:EndDrag()
            end)
        )

        if geometry.addY then
            local add = p:Button(
                'add_' .. id,
                L['Add field'],
                function()
                    command(function() return model:Add(path) end)
                end,
                'plus'
            )

            add:ClearAllPoints()
            add:SetPoint('TOPLEFT', geometry.addX - geometry.x, -geometry.addY + geometry.y)
            add:SetWidth(math.min(150, width - 48))
            row.line:ClearAllPoints()
            row.line:SetPoint('TOPLEFT', 14, -68)
            row.line:SetSize(2, math.max(1, geometry.height - 76))
            row.line:Show()
        else
            row.line:Hide()
        end

        local pending = owner.pendingRaw and owner.pendingRaw['field_' .. id]

        if pending then
            name:SetText(pending)
            p.edits[1].dirty = true
            local parsed = p.edits[1].parse(pending)
            name:SetTextColor(1, parsed ~= nil and 1 or .35, parsed ~= nil and 1 or .35)
        end
    end

    -- Repaints each bound card's border (red when its field is invalid) and its unsaved marker against the baseline.
    function view:UpdateMarkers()
        local index = addon:GetFieldSchemaIndex(model, owner.baseline)

        for _, row in ipairs(self.rows) do
            if row.lease then
                local entry = index.byKey[key(row.path)]
                local bad = entry.invalid
                row.decoration:SetColors(bad and .8 or .3, bad and .25 or .55, bad and .2 or .35, .7, .035)
                addon:SetWorkbenchInvalid(row.frame, bad, string.format(L['Invalid field schema: %s'], entry.key))
                addon:SetWorkbenchUnsaved(row.frame, entry.changed or row.form.edits[1] and row.form.edits[1].dirty)
            end
        end
    end

    -- Tells whether a card must stay bound even if scrolled out of view: focus, unsaved text, an open menu or a drag in
    -- progress.
    -- @param row table  The card.
    -- @return boolean  True when the card is pinned.
    function view:IsPinned(row)
        if
            row.name:HasFocus()
            or self.drag and self.drag.carried[row]
            or self.menuRow == row and form.menu and form.menu.frame:IsShown()
        then
            return true
        end

        for _, record in ipairs(row.form.edits) do
            if record.dirty then
                return true
            end
        end

        return false
    end

    -- Rebuilds the editor form's edit and field tables from the bound cards, so flush, validation and focus see every
    -- visible card.
    function view:CollectRecords()
        owner.cards = {}
        form.edits = {}
        form.fields = { add = owner.add }

        for _, row in ipairs(self.rows) do
            if row.lease then
                owner.cards[key(row.path)] = row

                for _, record in ipairs(row.form.edits) do
                    form.edits[#form.edits + 1] = record
                end

                for id, control in pairs(row.form.fields) do
                    form.fields[id] = control
                end
            end
        end
    end

    -- Binds cards for the rows in or near the viewport and releases the rest (pinned cards excepted), places the drop
    -- zones for visible gaps and restores pending focus. Runs on every scroll change; re-entry is blocked and a failure
    -- releases the half-bound card before rethrowing.
    function view:Refresh()
        if not valid() or self.refreshing then
            return
        end

        self.refreshing = true
        local binding

        -- Does the work of Refresh under pcall: releases cards that left the viewport, binds free cards to the visible
        -- fields, collects their records, places the drop zones for the visible gaps (found by binary search) and
        -- restores the pending focus and text.
        local ok, why = pcall(function()
            local top = form.scroll.workbenchBar:GetValue() - 152
            local bottom = top + form.scroll:GetHeight() + 304
            local visible = addon:GetFieldSchemaViewport(self.scene, top, bottom)
            local wanted = {}

            for _, row in ipairs(visible) do
                wanted[row.key] = row
            end

            -- Keeps a card bound that holds pending text or the pending focus even when it is outside the viewport.
            -- @param id string  The control id of the pending field ('field_<key>').
            local function retain(id)
                local row = self.scene.byKey[id:match('^field_(.+)$') or '']

                if row and not wanted[row.key] then
                    visible[#visible + 1] = row
                    wanted[row.key] = row
                end
            end

            for id in pairs(owner.pendingRaw or {}) do
                retain(id)
            end

            if owner.pendingFocus then
                retain(owner.pendingFocus.key)
            end

            for _, row in ipairs(self.rows) do
                if row.lease and not wanted[key(row.path)] and not self:IsPinned(row) then
                    self:ReleaseRow(row)
                end
            end

            local bound = {}

            for _, row in ipairs(self.rows) do
                if row.lease then
                    bound[key(row.path)] = true
                end
            end

            local free = 1

            for _, geometry in ipairs(visible) do
                if not bound[geometry.key] then
                    while self.rows[free] and self.rows[free].lease do
                        free = free + 1
                    end

                    local row = self.rows[free]

                    if not row then
                        row = form:Acquire('schemaCards', createRow)
                        self.rows[free] = row
                    end

                    binding = row
                    self:Bind(row, geometry)
                    binding = nil
                end
            end

            self:CollectRecords()
            local gaps = self.scene.gaps
            local low, high = 1, #gaps

            while low <= high do
                local mid = math.floor((low + high) / 2)

                if gaps[mid].y + 10 < top then
                    low = mid + 1
                else
                    high = mid - 1
                end
            end

            local count = 0

            for i = low, #gaps do
                local target = gaps[i]

                if target.y > bottom then
                    break
                end

                count = count + 1
                local zone = self.zones[count]

                if not zone then
                    zone = form:Acquire('schemaGaps', function()
                        local z = CreateFrame('Frame', nil, form.child)
                        z.marker = z:CreateTexture(nil, 'OVERLAY')
                        z.marker:SetColorTexture(.9, .75, .3, 1)
                        z.marker:SetPoint('LEFT')
                        z.marker:SetPoint('RIGHT')
                        z.marker:SetHeight(3)
                        return z
                    end)

                    self.zones[count] = zone
                end

                zone.target = target
                zone.path = target.path
                zone.gap = target.gap
                zone:SetParent(form.child)
                zone:ClearAllPoints()
                zone:SetPoint('TOPLEFT', target.x, -target.y)
                zone:SetSize(target.width, 10)
                zone:SetFrameLevel(form.child:GetFrameLevel() + 256)
                zone:EnableMouse(false)
                zone.marker:Hide()

                if self.drag and self:CanDrop(zone.path, zone.gap) then
                    zone:Show()
                else
                    zone:Hide()
                end
            end

            for i = count + 1, #self.zones do
                self.zones[i].target = nil
                self.zones[i]:Hide()
                self.zones[i].marker:Hide()
            end

            self:UpdateMarkers()
            local focus = owner.pendingFocus
            local input = focus and form.fields[focus.key]

            if input then
                input:SetFocus()

                if focus.cursor and input.SetCursorPosition then
                    input:SetCursorPosition(focus.cursor)
                end
            end

            owner.pendingRaw = nil
            owner.pendingFocus = nil
        end)

        self.refreshing = nil

        if not ok then
            if binding then
                pcall(self.ReleaseRow, self, binding)
            end

            self:CollectRecords()
            error(why, 0)
        end
    end

    form.cleanups[#form.cleanups + 1] = function()
        view.releasing = true
        view:CancelDrag()

        for _, row in ipairs(view.rows) do
            view:ReleaseRow(row)
        end

        if form.schemaViewport == view then
            form.schemaViewport = nil
        end
    end

    form.schemaViewport = view

    if not form.schemaViewportHook then
        form.schemaViewportHook = true

        form.scroll.workbenchBar:HookScript('OnValueChanged', function()
            if form.schemaViewport then
                form.schemaViewport:Refresh()
            end
        end)
    end

    view:Refresh()
    owner:UpdateActions()
end
