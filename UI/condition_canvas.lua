-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The condition canvas: the scrolling surface of the condition editor that shows a condition tree as cards joined by
-- connector lines. Owns card pooling and virtualization (past 200 cards only the visible viewport is bound), click,
-- shift/ctrl and box selection, and drag-and-drop with its drop zones. It owns no condition data: every change goes
-- through owner:Command(...) on the editor session, and layout comes from owner:Scene(). Cards are built by
-- UI/condition_cards.lua. Loaded from RotationMaster.toc after UI/condition_cards.lua and before
-- UI/condition_editor.lua.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Path helpers
-- ============================================================================

-- Returns a shallow copy of a condition path (a list of keys and indexes) so callers can keep it across edits.
local function pathCopy(path)
    local result = {}

    for i, p in ipairs(path) do
        result[i] = p
    end

    return result
end

-- True when path `a` is `b` itself or an ancestor of it.
local function prefix(a, b)
    if #a > #b then
        return false
    end

    for i, p in ipairs(a) do
        if b[i] ~= p then
            return false
        end
    end

    return true
end

-- True when two paths are numbered entries of the same parent list (the only case a range selection spans).
local function sibling(a, b)
    if #a ~= #b or type(a[#a]) ~= "number" or type(b[#b]) ~= "number" then
        return false
    end

    for i = 1, #a - 1 do
        if a[i] ~= b[i] then
            return false
        end
    end

    return true
end

-- True when a field widget (or any child) holds typed-but-uncommitted input or keyboard focus. Such a card must not be
-- recycled, or the typing would be lost.
local function pendingOrFocused(widget)
    if not widget then
        return false
    end
    if widget.IsPending and widget:IsPending() then
        return true
    end

    for _, input in pairs({ widget.frame, widget.editbox, widget.edit }) do
        if input.HasFocus and input:HasFocus() then
            return true
        end
    end

    for _, child in ipairs(widget.children or {}) do
        if pendingOrFocused(child) then
            return true
        end
    end

    return false
end

-- Builds a canvas inside `parent` for the condition editor `owner` (which supplies .active, .view, :Scene(), :Command()
-- and the other hooks used below) and returns it. Call canvas:Render() to draw and canvas:Release() when the editor
-- closes. Only valid while a window is open: the canvas keeps no state of its own beyond the pooled frames.
function addon:CreateConditionCanvas(parent, owner)
    local canvas = {
        frame = addon:CreateWorkbenchScrollFrame(parent),
        cards = {},
        lines = {},
        zones = {},
        generation = 0,
        owner = owner,
    }

    canvas.child = CreateFrame("Frame", nil, canvas.frame)
    canvas.frame:SetScrollChild(canvas.child)

    -- ============================================================================
    -- Selection
    -- ============================================================================

    -- Returns the selected condition paths in tree order; empty when no condition is open.
    function canvas:Selection()
        local result = {}

        if not owner.active then
            return result
        end

        for _, row in ipairs(owner.active.session:Rows(4096)) do
            if owner.view.selection[addon.ConditionPathKey(row.path)] then
                result[#result + 1] = pathCopy(row.path)
            end
        end

        return result
    end

    -- Applies a click to the selection: shift extends a range among siblings (with ctrl, adds to it), ctrl toggles one
    -- entry (an entry and its ancestors or descendants are never selected together), a plain click replaces it.
    function canvas:Select(path, control, shift)
        if not owner.active or not owner:SyncWorking() then
            return
        end

        local key = addon.ConditionPathKey(path)
        local selection = owner.view.selection
        local rows = owner.active.session:Rows(4096)

        if shift and self.anchor and sibling(path, self.anchor) then
            if not control then
                selection = {}
            end

            local low, high = math.min(path[#path], self.anchor[#path]), math.max(path[#path], self.anchor[#path])
            local parent = pathCopy(path)
            table.remove(parent)
            local added = {}

            for _, row in ipairs(rows) do
                local key = addon.ConditionPathKey(row.path)
                local index = row.path[#path]
                local within = prefix(parent, row.path) and type(index) == 'number' and index >= low and index <= high

                if prefix(row.path, parent) or within then
                    selection[key] = nil
                end
                if sibling(path, row.path) and within then
                    added[key] = true
                end
            end

            for key in pairs(added) do
                selection[key] = true
            end
        elseif control then
            if selection[key] then
                selection[key] = nil
            else
                for _, row in ipairs(rows) do
                    if prefix(row.path, path) or prefix(path, row.path) then
                        selection[addon.ConditionPathKey(row.path)] = nil
                    end
                end

                selection[key] = true
            end
        else
            selection = { [key] = true }
        end

        owner.view.selection = selection
        owner.active.selected = pathCopy(path)
        self.anchor = pathCopy(path)

        if (#self:Selection() > 1) ~= owner.selectionStrip then
            owner:Layout()
        else
            self:Reflow()
        end
    end

    -- ============================================================================
    -- Drag and drop
    -- ============================================================================

    local ghost = addon:CreateWorkbenchDragCard()
    canvas.ghost = ghost

    -- Ends any drag or box selection without dropping: hides the ghost and zones, then redraws the cards a drag had
    -- hidden. Safe to call when nothing is dragging, and re-entrantly from Render and Release.
    function canvas:CancelDrag()
        local moving = self.drag
        self.drag = nil
        self.box = nil

        if self.boxFrame then
            self.boxFrame:Hide()
        end

        ghost:Hide()
        addon:SetUIScript(self.frame, "OnUpdate", nil)

        for _, zone in ipairs(self.zones) do
            zone.marker:Hide()
            zone:Hide()
        end

        if moving and self.RefreshVisibleCards and not self.rendering and not self.releasing then
            if self.deferredMeasure then
                self.deferredMeasure = nil
                self.needsMeasure = nil
                self:Reflow()
            else
                self:RefreshVisibleCards()
            end
        end
    end

    -- True when the dragged paths (or inserted node) can legally land on `target`, proven on a draft copy of the
    -- session; results are cached per destination for the life of the drag. A drop that changes nothing is refused.
    function canvas:CanDrop(target)
        local drag = self.drag

        if
            not drag or not owner.active or drag.generation ~= self.generation or drag.session ~= owner.active.session
        then
            return false
        end

        local destination = target.destination

        local key = addon.ConditionPathKey(destination.path)
            .. "/field:"
            .. addon.ConditionPathKey({ destination.field or "value" })
            .. "/index:"
            .. tostring(destination.index)
            .. "/relation:"
            .. tostring(destination.relation)

        drag.valid = drag.valid or {}

        if drag.valid[key] ~= nil then
            return drag.valid[key]
        end

        local draft = addon.RotationData.NewConditionDraft(owner.active.session:Snapshot(), addon.conditionDefinitions)
        local ok, locations

        if draft then
            if drag.insert then
                ok = draft:Insert(destination, drag.insert)
            else
                ok, locations = draft:Transfer(drag.paths, destination)

                if ok and #locations == #drag.paths then
                    local same = true

                    for index, path in ipairs(locations) do
                        if not prefix(path, drag.paths[index]) or not prefix(drag.paths[index], path) then
                            same = false
                            break
                        end
                    end

                    if same then
                        ok = false
                    end
                end
            end
        end

        drag.valid[key] = ok == true
        return ok == true
    end

    -- Highlights the valid drop zone under the pointer and returns it, or nil. Runs every frame while dragging.
    function canvas:HoverTarget()
        local selected

        do
            for _, zone in ipairs(self.zones) do
                if zone:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(zone, self.frame) then
                    if self:CanDrop(zone.target) then
                        selected = zone
                        break
                    end
                end
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

    -- Starts a drag. `state` is { paths, tail } to move conditions, or { insert, source } to insert a new node. Shows
    -- the ghost, reveals the drop zones and polls the pointer, ending the drag when the mouse button is released.
    function canvas:BeginDrag(state)
        if owner.active and owner.active.readOnly then
            return
        end

        self:CancelDrag()
        self.drag = state
        local preview = state.insert or owner.active.session:Snapshot()

        if not state.insert and state.paths[1] then
            for _, part in ipairs(state.paths[1]) do
                preview = preview[part]
            end
        end

        ghost:Present(
            (state.tail and L["Move this and following entries"] .. ": " or "")
                .. (state.insert and L["Insert condition"] or string.format(L["Move %d conditions"], #state.paths)),
            addon:DescribeCondition(preview, owner.active.spec) .. "\n" .. L["Drop in a highlighted gap."],
            self.frame,
            state.insert and 1 or #state.paths
        )

        if not state.insert then
            local selected, entries, edges, lines = {}, {}, {}, {}

            for _, card in ipairs(self.cards) do
                local model = card.model
                local carried = false

                if model and card.frame:IsShown() then
                    for _, path in ipairs(state.paths) do
                        if prefix(path, model.path) then
                            carried = true
                            break
                        end
                    end
                end

                if carried then
                    selected[model.key] = true

                    entries[#entries + 1] = {
                        frame = card.frame,
                        x = model.x,
                        y = model.y,
                        width = model.width,
                        height = model.height,
                    }
                end
            end

            state.carriedKeys = selected

            for _, edge in ipairs(self.scene.connectors) do
                if selected[edge.from] and selected[edge.to] then
                    edges[#edges + 1] = {
                        points = {
                            { x = edge.x, y = edge.y },
                            { x = edge.x + edge.width - 2, y = edge.y + edge.height - 2 },
                        },
                        tone = 'neutral',
                    }

                    local texture = self.linesByEdge and self.linesByEdge[edge]

                    if texture then
                        lines[#lines + 1] = texture
                    end
                end
            end

            ghost:PresentCards(entries, self.child, edges, lines)
        elseif state.source then
            ghost:PresentSource(state.source)
        end

        ghost:CaptureCancel(function()
            self:CancelDrag()
        end)

        for _, zone in ipairs(self.zones) do
            zone:Show()
            zone.marker:Hide()
        end

        addon:SetUIScript(self.frame, "OnUpdate", function()
            if not self.drag then
                return
            end

            if
                self.drag.generation ~= self.generation or not owner.active or self.drag.session ~= owner.active.session
            then
                self:CancelDrag()
                return
            end

            ghost:FollowPointer()
            self:HoverTarget()

            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                self:EndDrag()
            end
        end)
    end

    -- Drag-source callback for a card. `token` is the generation the card was bound under; a stale token (the canvas
    -- rendered since) is ignored. Ctrl drags this entry and every later sibling ("tail"), else the selection.
    function canvas:StartDrag(path, token)
        if token ~= self.generation or not owner.active then
            return
        end

        local paths
        local tail = IsControlKeyDown and IsControlKeyDown() or false

        if tail then
            if not owner:SyncWorking() then
                return
            end

            paths = {}

            for _, row in ipairs(owner.active.session:Rows(4096)) do
                if sibling(path, row.path) and row.path[#path] >= path[#path] then
                    paths[#paths + 1] = pathCopy(row.path)
                end
            end

            if #paths == 0 then
                paths = { pathCopy(path) }
            end
        else
            local key = addon.ConditionPathKey(path)

            if not owner.view.selection[key] then
                self:Select(path, false, false)
            end

            paths = self:Selection()
        end

        self:BeginDrag({ generation = self.generation, session = owner.active.session, paths = paths, tail = tail })
    end

    -- Starts a drag that inserts a copy of `node` (from the condition picker) instead of moving existing entries.
    function canvas:StartInsert(node, source)
        if not owner.active or not owner:SyncWorking() then
            return
        end

        self:BeginDrag({
            generation = self.generation,
            session = owner.active.session,
            insert = addon.RotationData.CopyData(node),
            source = source,
        })
    end

    -- Ends the drag on `target`: runs the Insert or Transfer command when the drop is valid, else just cancels.
    function canvas:Drop(target)
        local drag = self.drag
        local valid = self:CanDrop(target)
        self:CancelDrag()

        if
            not valid
            or not drag
            or drag.generation ~= self.generation
            or not owner.active
            or drag.session ~= owner.active.session
        then
            return
        end
        if drag.insert then
            return owner:Command("Insert", target.destination, drag.insert)
        end

        return owner:Command("Transfer", drag.paths, target.destination)
    end

    -- Mouse released: drops on the hovered zone if there is one, otherwise cancels.
    function canvas:EndDrag()
        if not self.drag then
            return
        end

        local selected = self:HoverTarget()

        if selected then
            return self:Drop(selected.target)
        end

        self:CancelDrag()
    end

    -- ============================================================================
    -- Box selection
    -- ============================================================================

    -- Shift-drag on empty canvas draws a box selecting the cards it touches
    -- (Ctrl+Shift adds to the selection); a card inside another touched card
    -- travels with it, as with Ctrl-click. Coordinates are in canvas child space.
    function canvas:SelectBox(left, top, right, bottom, additive)
        if not owner.active or not self.scene or not owner:SyncWorking() then
            return
        end

        local touched = {}

        for _, model in ipairs(self.scene.cards) do
            -- A group's frame encloses its children; only its own header counts.
            local height = model.group and model.ownHeight or model.height

            if
                model.path
                and model.x <= right
                and model.x + model.width >= left
                and model.y <= bottom
                and model.y + height >= top
            then
                touched[#touched + 1] = model
            end
        end

        local selection = additive and owner.view.selection or {}
        local rows = owner.active.session:Rows(4096)

        for _, model in ipairs(touched) do
            local inside = false

            for _, other in ipairs(touched) do
                if other ~= model and #other.path < #model.path and prefix(other.path, model.path) then
                    inside = true
                    break
                end
            end

            if not inside then
                for _, row in ipairs(rows) do
                    if prefix(row.path, model.path) or prefix(model.path, row.path) then
                        selection[addon.ConditionPathKey(row.path)] = nil
                    end
                end

                selection[addon.ConditionPathKey(model.path)] = true
            end
        end

        owner.view.selection = selection

        if (#self:Selection() > 1) ~= owner.selectionStrip then
            owner:Layout()
        else
            self:Reflow()
        end
    end

    -- Starts a rubber-band selection at the pointer; returns false when a drag is active or the pointer is off the
    -- canvas.
    function canvas:BeginBoxSelect()
        if not owner.active or self.drag then
            return false
        end

        local x, y = addon:WorkbenchPointerIn(self.child)

        if not x then
            return false
        end

        self:CancelDrag()

        local box = {
            x = x,
            y = y,
            additive = IsControlKeyDown and IsControlKeyDown() or false,
            generation = self.generation,
        }

        self.box = box
        self.boxFrame = self.boxFrame or addon:CreateWorkbenchSelectionBox(self.child)
        self.boxFrame:Place(x, y, x, y)

        addon:SetUIScript(self.frame, "OnUpdate", function()
            if self.box ~= box then
                return
            end

            if not owner.active or box.generation ~= self.generation then
                self:CancelDrag()
                return
            end

            local cx, cy = addon:WorkbenchPointerIn(self.child)

            if cx then
                box.cx, box.cy = cx, cy
                self.boxFrame:Place(box.x, box.y, cx, cy)
            end

            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                self:EndBoxSelect()
            end
        end)

        return true
    end

    -- Finishes the rubber band and applies it as a selection.
    function canvas:EndBoxSelect()
        local box = self.box

        if not box then
            return
        end

        local cx, cy = box.cx or box.x, box.cy or box.y
        self:CancelDrag()
        self:SelectBox(math.min(box.x, cx), math.min(box.y, cy), math.max(box.x, cx), math.max(box.y, cy), box.additive)
    end

    for _, surface in ipairs({ canvas.frame, canvas.child }) do
        surface:EnableMouse(true)

        addon:SetUIScript(surface, "OnMouseDown", function(_, button)
            if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
                canvas:BeginBoxSelect()
            end
        end)

        addon:SetUIScript(surface, "OnMouseUp", function(_, button)
            if button == "LeftButton" and canvas.box then
                canvas:EndBoxSelect()
            end
        end)
    end

    local horizontal = addon:CreateWorkbenchScrollBar(parent, 'HORIZONTAL')
    addon:TrackWorkbenchSize(horizontal)
    canvas.horizontal = horizontal

    addon:SetUIScript(horizontal, "OnValueChanged", function(_, value)
        canvas.scrollX = value
        canvas.frame:SetHorizontalScroll(value)
    end)

    -- Anchors the horizontal scroll bar under the scroll frame at the frame's current width.
    function canvas:LayoutScrollBar()
        horizontal:ClearAllPoints()
        horizontal:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, -4)
        horizontal:SetWidth(self.frame:GetWidth())
    end

    -- ============================================================================
    -- Card binding and rendering
    -- ============================================================================

    -- Fills a pooled card from a scene `model`: measures label and summary widths, places it and wires every script.
    -- Each handler checks alive() first, so a card that was released or re-rendered since cannot act on its old
    -- condition. Returns true when a measured size changed, meaning the layout must be recomputed.
    function canvas:BindCard(card, model)
        local beforeWidth = (owner.view.labelWidths or {})[model.key]
        local beforeSummary = (owner.view.summaryHeights or {})[model.key]
        local beforeDetails = (owner.view.detailsHeights or {})[model.key]
        local token = { generation = self.generation }
        card.token = token

        -- True while this binding is the card's current one (same canvas generation, card not rebound).
        local function alive()
            return owner.active and token.generation == self.generation and card.token == token
        end

        self.measure = self.measure or self.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        self.measure:SetWordWrap(false)
        self.measure:SetText(model.compact and not model.name and owner:Summary(model) or owner:Caption(model))
        owner.view.labelWidths = owner.view.labelWidths or {}
        owner.view.labelWidths[model.key] = self.measure:GetStringWidth()
        self.measure:Hide()
        card:Place(model, owner:Caption(model), owner:Summary(model))
        owner.view.summaryHeights = owner.view.summaryHeights or {}

        if card.summary.GetStringHeight then
            owner.view.summaryHeights[model.key] = card.summary:GetStringHeight() + 4
        end

        addon:SetUIScript(card.header, "OnClick", function()
            if not alive() then
                return
            end

            local control, shift = IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown()

            if control or shift then
                self:Select(model.path, control, shift)
            else
                owner.view.help[model.key] = nil
                owner.view.cardStates[model.key] = 'expanded'
                self:Render()
            end
        end)

        addon:SetUIScript(card.frame, "OnMouseDown", function(_, button)
            if alive() and button == "LeftButton" then
                self:Select(model.path, IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown())
            end
        end)

        addon:SetUIScript(card.header, "OnDragStart", function()
            if alive() then
                self:StartDrag(model.path, token.generation)
            end
        end)

        addon:SetUIScript(card.header, "OnDragStop", function()
            if alive() then
                self:EndDrag()
            end
        end)

        addon:SetUIScript(card.expand, "OnClick", function()
            if not alive() or not owner:SyncWorking() then
                return
            end

            owner.view.cardStates = owner.view.cardStates or {}
            owner.view.help[model.key] = nil
            owner.view.cardStates[model.key] = model.compact and 'normal' or model.expanded and 'normal' or 'compact'
            self:Render()
        end)

        addon:SetUIScript(card.typeButton, "OnClick", function()
            if not alive() or model.compact then
                return
            end

            if IsControlKeyDown and IsControlKeyDown() or IsShiftKeyDown and IsShiftKeyDown() then
                self:Select(model.path, IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown())
            else
                owner:OpenTypePicker(card, model, alive)
            end
        end)

        addon:SetUIScript(card.typeButton, "OnDragStart", function()
            if alive() then
                self:StartDrag(model.path, token.generation)
            end
        end)

        addon:SetUIScript(card.typeButton, "OnDragStop", function()
            if alive() then
                self:EndDrag()
            end
        end)

        card.name:SetText(addon:PlainWorkbenchName(model.name or ""))

        addon:BindWorkbenchInlineName(card.name, function()
            if alive() then
                card.name:Hide()
                card.nameButton:Show()
                local name = card.name:GetText()

                card.nameButton:SetText(addon:PlainWorkbenchName(
                    name ~= '' and name or model.group and L['Click to add group name'] or owner:Caption(model)
                ))
            end
        end)

        addon:SetUIScript(card.nameButton, "OnClick", function()
            if not alive() then
                return
            end

            if model.compact then
                owner.view.cardStates[model.key] = 'normal'
                self:Render()
                return
            end

            local control, shift = IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown()

            if control or shift then
                self:Select(model.path, control, shift)
            elseif model.group or model.name then
                card.nameButton:Hide()
                card.name:Show()
                card.name:SetFocus()
            end
        end)

        addon:SetUIScript(card.nameButton, "OnDragStart", function()
            if alive() then
                self:StartDrag(model.path, token.generation)
            end
        end)

        addon:SetUIScript(card.nameButton, "OnDragStop", function()
            if alive() then
                self:EndDrag()
            end
        end)

        addon:SetUIScript(card.name, 'OnTextChanged', function(input, userInput)
            if not alive() or owner.active.readOnly or not userInput then
                return
            end

            local node = owner.active.working

            for _, part in ipairs(model.namePath) do
                node = node[part]
            end

            node.name = input:GetText()
            owner:SyncWorking()
            owner:UpdateHistoryButtons()
        end)

        addon:SetUIScript(card.name, "OnEnterPressed", function(input)
            if alive() then
                input:ClearFocus()
                owner:Command("SetName", model.namePath, input:GetText())
            end
        end)

        addon:SetUIScript(card.name, "OnEscapePressed", function()
            if alive() then
                card.name:ClearFocus()
                card.name:Hide()
                card.nameButton:Show()
            end
        end)

        addon:SetUIScript(card.fold, 'OnClick', function()
            if alive() then
                owner.view.hiddenChildren[model.key] = not owner.view.hiddenChildren[model.key]
                self:Render()
            end
        end)

        addon:SetUIScript(card.controls.up, "OnClick", function()
            if alive() then
                owner:Command("Move", model.path, -1)
            end
        end)

        addon:SetUIScript(card.controls.down, "OnClick", function()
            if alive() then
                owner:Command("Move", model.path, 1)
            end
        end)

        addon:SetUIScript(card.controls.remove, "OnClick", function()
            if alive() then
                owner:Command("RemoveSelection", { model.path })
            end
        end)

        addon:SetUIScript(card.controls.duplicate, "OnClick", function()
            if alive() then
                owner:Command("Duplicate", model.path)
            end
        end)

        addon:SetUIScript(card.controls.negate, "OnClick", function()
            if alive() then
                owner:Command("NegateSelection", { model.path })
            end
        end)

        addon:SetUIScript(card.controls.disable, "OnClick", function()
            if alive() then
                owner:Command("SetProjectedDisabled", model.path, not model.disabled)
            end
        end)

        addon:SetUIScript(card.controls.operator, "OnClick", function()
            if alive() then
                owner:Command("SetGroupType", model.fieldPath, model.type == "AND" and "OR" or "AND")
            end
        end)

        addon:SetUIScript(card.controls.ungroup, "OnClick", function()
            if alive() then
                owner:Command("Unwrap", model.fieldPath)
            end
        end)

        card.controls.help.tooltip = L['Help.Conditions.subject_brief']

        if addon.BindWorkbenchHelp then
            addon:BindWorkbenchHelp(card.controls.help, { brief = L['Help.Conditions.subject_brief'], valid = alive })
        end

        addon:SetUIScript(card.controls.help, "OnClick", function()
            if alive() then
                owner:ShowSubjectHelp(model, alive)
            end
        end)

        if model.expanded then
            owner:BuildFields(card, model, alive)
        end

        for _, source in ipairs({ card.header, card.typeButton, card.nameButton, card.frame }) do
            addon:BindWorkbenchDragSource(
                source,
                function()
                    if alive() then
                        self:StartDrag(model.path, token.generation)
                    end
                end,
                function()
                    if alive() then
                        self:EndDrag()
                    end
                end
            )
        end

        local readOnly = owner.active.readOnly

        for key, control in pairs(card.controls) do
            if
                (readOnly and key ~= 'help')
                or (key == 'up' and not model.canMoveUp)
                or (key == 'down' and not model.canMoveDown)
            then
                control:Disable()
            else
                control:Enable()
            end
        end

        if readOnly then
            card.typeButton:Disable()

            if model.compact then
                card.nameButton:Enable()
            else
                card.nameButton:Disable()
            end
        else
            card.typeButton:Enable()
            card.nameButton:Enable()
        end

        return beforeWidth ~= (owner.view.labelWidths or {})[model.key]
            or beforeSummary ~= (owner.view.summaryHeights or {})[model.key]
            or beforeDetails ~= (owner.view.detailsHeights or {})[model.key]
    end

    -- True when a card must stay bound even though it scrolled out of view: a name or field being edited, a card being
    -- dragged, an open picker, keyboard focus inside it, or the editor closing with unsaved input.
    function canvas:IsPinned(card)
        if card.name:HasFocus() or pendingOrFocused(card.pane) or card.frame:GetParent() == ghost then
            return true
        end
        if owner.closeOverride and not owner.frame:IsShown() then
            return true
        end
        if card.picker and card.picker.frame:IsShown() then
            return true
        end

        local keyboard = type(GetCurrentKeyBoardFocus) == 'function' and GetCurrentKeyBoardFocus()

        for _ = 1, 128 do
            if not keyboard then
                break
            end

            if keyboard == card.frame then
                return true
            end

            keyboard = keyboard.GetParent and keyboard:GetParent()
        end

        return false
    end

    -- Redraws the connector lines and drop zones. With more than 200 cards only the lines of the bound cards and the
    -- zones near the viewport are materialized, found by binary search over the Y-sorted drop targets.
    function canvas:RefreshDecorations(models)
        local scene = self.scene
        local lines = {}
        self.linesByEdge = {}

        if #scene.cards <= 200 then
            lines = scene.connectors
        else
            for _, model in ipairs(models) do
                for _, line in ipairs(scene.connectorsByTo[model.key] or {}) do
                    lines[#lines + 1] = line
                end
            end
        end

        for index, line in ipairs(lines) do
            local texture = self.lines[index]

            if not texture then
                texture = self.child:CreateTexture(nil, "BACKGROUND")
                self.lines[index] = texture
                texture:SetColorTexture(.38, .37, .28, 1)
            end

            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", self.child, "TOPLEFT", line.x, -line.y)
            texture:SetSize(line.width, line.height)
            self.linesByEdge[line] = texture
            local carried = self.drag and self.drag.carriedKeys

            if carried and carried[line.from] and carried[line.to] then
                texture:Hide()
            else
                texture:Show()
            end
        end

        for index = #lines + 1, #self.lines do
            self.lines[index]:Hide()
        end

        local targets = scene.dropTargets

        if #scene.cards > 200 then
            targets = {}
            local sorted = scene.dropTargetsByY
            local top = self.frame.workbenchBar:GetValue() - 180
            local bottom = top + self.frame:GetHeight() + 360
            local low, high = 1, #sorted

            while low <= high do
                local mid = math.floor((low + high) / 2)

                if sorted[mid].y < top - scene.maxDropHeight then
                    low = mid + 1
                else
                    high = mid - 1
                end
            end

            for index = low, #sorted do
                local target = sorted[index]

                if target.y > bottom then
                    break
                end

                targets[#targets + 1] = target
            end
        end

        for index, target in ipairs(targets) do
            local zone = self.zones[index]

            if not zone then
                zone = CreateFrame("Frame", nil, self.child)
                self.zones[index] = zone
                zone:EnableMouse(false)
                local marker = CreateFrame("Frame", nil, zone)
                zone.marker = marker

                for _, edge in ipairs({
                    { first = "TOPLEFT", last = "TOPRIGHT", horizontal = true },
                    { first = "BOTTOMLEFT", last = "BOTTOMRIGHT", horizontal = true },
                    { first = "TOPLEFT", last = "BOTTOMLEFT" },
                    { first = "TOPRIGHT", last = "BOTTOMRIGHT" },
                }) do
                    local line = marker:CreateTexture(nil, "OVERLAY")
                    line:SetColorTexture(.45, .8, .5, .9)
                    line:SetPoint(edge.first, marker, edge.first, 0, 0)
                    line:SetPoint(edge.last, marker, edge.last, 0, 0)

                    if edge.horizontal then
                        line:SetHeight(1)
                    else
                        line:SetWidth(1)
                    end
                end
            end

            zone.target = target
            zone:ClearAllPoints()
            zone:SetPoint("TOPLEFT", self.child, "TOPLEFT", target.x, -target.y)
            zone:SetSize(target.width, target.height)
            zone.marker:ClearAllPoints()
            zone.marker:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, target.kind == "inside" and 0 or -target.height / 2 + 1)
            zone.marker:SetSize(target.width, target.kind == "inside" and (target.boxHeight or target.height) or 2)
            zone:SetFrameLevel(self.child:GetFrameLevel() + 80)
            local token = self.generation

            addon:SetUIScript(zone, "OnReceiveDrag", function()
                if token == self.generation and zone.target == target then
                    self:Drop(target)
                end
            end)

            zone.marker:Hide()

            if self.drag then
                zone:Show()
            else
                zone:Hide()
            end
        end

        for index = #targets + 1, #self.zones do
            self.zones[index].target = nil
            self.zones[index]:Hide()
            self.zones[index].marker:Hide()
        end
    end

    -- Binds the cards that should exist (all of them, or just the viewport plus margin past 200) and releases the rest,
    -- then draws decorations. Runs on every scroll; re-entrancy guarded by self.refreshing and self.reflowing. If a
    -- bind changed a measured size it schedules a Reflow (deferred until a drag ends).
    function canvas:RefreshVisibleCards()
        if not owner.active or not self.scene or self.refreshing or self.reflowing then
            return
        end

        self.refreshing = true
        self.building = true
        local measured = false
        local constructing

        local ok, why = pcall(function()
            local scene = self.scene
            local models = scene.cards

            if #models > 200 then
                local left = (self.scrollX or 0) - 340
                local top = self.frame.workbenchBar:GetValue() - 180

                models = addon:GetConditionCanvasViewport(
                    scene,
                    left,
                    top,
                    left + self.frame:GetWidth() + 680,
                    top + self.frame:GetHeight() + 360
                )
            end

            local wanted, bound = {}, {}

            for _, model in ipairs(models) do
                wanted[model.key] = model
            end

            for _, card in ipairs(self.cards) do
                if card.token and card.model then
                    local model = scene.cardsByKey[card.model.key]

                    if model and (wanted[model.key] or self:IsPinned(card)) then
                        bound[model.key] = card

                        if card.frame:GetParent() ~= ghost then
                            card:Place(model, owner:Caption(model), owner:Summary(model))
                        end
                    else
                        card:Release()
                    end
                end
            end

            local free = 1

            for _, model in ipairs(models) do
                if not bound[model.key] then
                    while self.cards[free] and self.cards[free].token do
                        free = free + 1
                    end

                    local card = self.cards[free]

                    if not card then
                        card = addon:CreateConditionCard(self.child)
                        self.cards[free] = card
                    end

                    constructing = card
                    measured = self:BindCard(card, model) or measured
                    bound[model.key] = card
                    constructing = nil
                end
            end

            self:RefreshDecorations(models)
        end)

        self.building = false
        self.refreshing = nil

        if not ok then
            if constructing then
                pcall(constructing.Release, constructing)
            end

            error(why, 0)
        end

        if measured or self.needsMeasure then
            if self.drag then
                self.deferredMeasure = true
            else
                self.needsMeasure = nil
                self:Reflow()
            end
        else
            owner:UpdateHistoryButtons()
        end
    end

    -- Recomputes the scene layout and scroll extents, keeping the card at the top of the viewport in place, then
    -- rebinds cards. A call made while a refresh is running only flags needsMeasure, so layout never nests inside
    -- binding.
    function canvas:Reflow()
        if not owner.active then
            return
        end

        if self.reflowing or self.refreshing then
            self.needsMeasure = true
            return
        end

        self.reflowing = true

        local ok, why = pcall(function()
            local anchor, offset
            local top = self.frame.workbenchBar:GetValue()

            if self.scene then
                for _, model in ipairs(addon:GetConditionCanvasViewport(
                    self.scene,
                    0,
                    top,
                    self.scene.width,
                    top + self.frame:GetHeight()
                )) do
                    if model.y + model.ownHeight >= top then
                        anchor = model.key
                        offset = top - model.y
                        break
                    end
                end
            end

            local scene = owner:Scene()
            self.scene = scene

            if not scene then
                for _, card in ipairs(self.cards) do
                    card:Release()
                end

                for _, line in ipairs(self.lines) do
                    line:Hide()
                end

                for _, zone in ipairs(self.zones) do
                    zone:Hide()
                end

                return
            end

            self.child:SetSize(scene.width, scene.height)
            horizontal:UpdateExtent(scene.width, self.frame:GetWidth())
            horizontal:SetValue(math.min(self.scrollX or 0, math.max(0, scene.width - self.frame:GetWidth())))

            if horizontal.scrollRange > 0 then
                horizontal:Show()
            else
                horizontal:Hide()
                self.frame:SetHorizontalScroll(0)
            end

            self.frame:UpdateScrollChildRect()
            self.frame:UpdateWorkbenchScroll()

            if anchor and scene.cardsByKey[anchor] then
                self.frame.workbenchBar:SetValue(scene.cardsByKey[anchor].y + offset)
            end

            owner:UpdateHistoryButtons()
            owner:UpdateDescription()
        end)

        self.reflowing = nil

        if not ok then
            error(why, 0)
        end

        self:RefreshVisibleCards()
    end

    -- Full redraw: invalidates every bound card (new generation, so old handlers die) and lays out again.
    function canvas:Render()
        if owner.active and not owner:SyncWorking() then
            return
        end

        self.rendering = true
        self:CancelDrag()
        self.generation = self.generation + 1

        for _, card in ipairs(self.cards) do
            card:Release()
        end

        self.rendering = nil
        self.needsMeasure = nil
        self.deferredMeasure = nil

        if owner.active then
            self:Reflow()
        end
    end

    -- Tears the canvas down when the editor closes: cancels drags, releases every card and drops the scene.
    function canvas:Release()
        self.releasing = true
        self:CancelDrag()
        self.generation = self.generation + 1

        for _, card in ipairs(self.cards) do
            card:Release()
        end

        self.scene = nil
        self.linesByEdge = nil
        self.needsMeasure = nil
        self.deferredMeasure = nil
        horizontal:Hide()
        self.releasing = nil
    end

    for _, bar in ipairs({ horizontal, canvas.frame.workbenchBar }) do
        bar:HookScript('OnValueChanged', function()
            if canvas.reflowing then
                return
            end

            if addon.Diagnostics then
                addon.Diagnostics:Call({
                    module = 'ui',
                    operation = 'conditionViewport',
                }, canvas.RefreshVisibleCards, canvas)
            else
                canvas:RefreshVisibleCards()
            end
        end)
    end

    return canvas
end
