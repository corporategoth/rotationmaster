-- The scene surface of the rotation editor: the scrolling, zooming canvas that draws a rotation as cards, branch
-- groups, connector lines and True/False arm buttons, in diagram, list or cooldown-grid form. It turns the scene model
-- built by the editor into frames, recycles card controls so only nearby cards exist, and runs pointer gestures (pan,
-- box select, multi-select, drag and drop of cards) without ever editing the rotation itself: every change goes out as
-- owner:Command and selection and viewport live in owner.view. Every card handler checks a generation token so a
-- handler left over from an earlier render does nothing. Built by UI/rotation_editor.lua (loaded after this file in
-- the UI/ block of RotationMaster.toc); cards come from UI/rotation_cards.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

local colors = {
    green = { .25, .7, .35 },
    red = { .85, .3, .25 },
    gray = { .4, .4, .4 },
    neutral = { .55, .58, .6 },
    white = { .85, .85, .85 },
}

-- ============================================================================
-- Helpers
-- ============================================================================

-- Tells whether a value is a real, finite number (not NaN, not infinite).
-- @param value any  The value to test.
-- @return boolean  True for a finite number.
local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- Clamps a zoom factor to 25% to 200%; anything that is not a finite number becomes 1.
-- @param value any  The requested zoom factor.
-- @return number  The clamped zoom factor, between 0.25 and 2.
local function zoom(value)
    return finite(value) and math.max(.25, math.min(2, value)) or 1
end

-- Joins a step's path (list of keys and indexes) into one comparable string.
-- @param path table  The step path, e.g. { 'steps', 3, 'children', 1 }.
-- @return string  The path elements joined with '/'.
local function location(path)
    return table.concat(path, '/')
end

-- The scene builder lays cards out at their 340 px design width. A diagram
-- keeps that (it pans and zooms in two dimensions), but the vertical list and
-- the cooldown grid fill the viewport: list cards reach the right edge less
-- 8 px per nested branch, and grid columns share the row. Nothing narrows.
local listIndent, gridGap, gridCardMaximum = 24, 24, 600

-- Widens the scene's cards, groups and drop targets to fill a viewport of the given width for the list and grid layouts
-- (the diagram is left alone) and updates scene.width.
-- @param scene table  The scene model ({ layout, cards, groups, dropTargets, width }); mutated in place.
-- @param viewport number  The viewport width in pixels; a non-finite value leaves the scene unchanged.
-- @return table  The same scene (unchanged when it is invalid, the viewport is invalid or the layout is the diagram).
function addon:FitRotationSceneWidth(scene, viewport)
    if type(scene) ~= 'table' or not finite(viewport) then
        return scene
    end

    local right = math.max(0, viewport - 4)
    local widest = 0

    -- Stretches one item to the right edge, less 8 px for each level of nesting derived from its indent.
    -- @param item table  The card, group or drop target ({ x, width }); its width is widened, never narrowed.
    -- @param inset number  Extra pixels kept clear of the right edge.
    -- @param base number  The x position that counts as nesting depth zero.
    local function stretch(item, inset, base)
        local depth = math.max(0, math.floor((item.x - base) / listIndent + .5))
        item.width = math.max(item.width, right - depth * 8 - inset - item.x)
    end

    if scene.layout == 'list' then
        for _, card in ipairs(scene.cards) do
            stretch(card, 0, 0)
        end

        for _, group in ipairs(scene.groups or {}) do
            if group.kind == 'arm' then
                stretch(group, 4, 20)
            else
                stretch(group, 0, 0)
            end
        end

        for _, target in ipairs(scene.dropTargets or {}) do
            stretch(target, 0, 0)
        end
    elseif scene.layout == 'grid' and #(scene.groups or {}) == 0 then
        local design = 340
        local pitch = design + gridGap
        local columns = 0

        for _, card in ipairs(scene.cards) do
            columns = math.max(columns, math.floor(card.x / pitch + .5) + 1)
        end

        if columns == 0 then
            return scene
        end

        local each = math.max(design, math.min(gridCardMaximum, (right - (columns - 1) * gridGap) / columns))

        -- Moves an item to its column at the stretched card width.
        -- @param item table  The card or drop target ({ x, width }); both fields are rewritten.
        local function place(item)
            local column = math.floor(item.x / pitch + .5)
            item.x = column * (each + gridGap)
            item.width = each
        end

        for _, card in ipairs(scene.cards) do
            if card.width == design then
                place(card)
            end
        end

        for _, target in ipairs(scene.dropTargets or {}) do
            if target.width == design then
                place(target)
            elseif target.width > design then
                target.x = 0
                target.width = columns * each + (columns - 1) * gridGap
            end
        end
    else
        return scene
    end

    for _, card in ipairs(scene.cards) do
        widest = math.max(widest, card.x + card.width)
    end

    for _, group in ipairs(scene.groups or {}) do
        widest = math.max(widest, group.x + group.width)
    end

    scene.width = math.max(scene.width or 0, widest)
    return scene
end

-- ============================================================================
-- Canvas construction
-- ============================================================================

-- Builds the canvas inside `parent` for the editor pane `owner` (which supplies view, workspace, BuildScene, Command,
-- UpdateHistory and the other callbacks used below). The editor calls Render when the document or layout changes and
-- Release when it closes.
-- @param parent table  The frame that holds the canvas.
-- @param owner table  The editor pane that owns the canvas.
-- @return table  The canvas.
function addon:CreateRotationCanvas(parent, owner)
    local canvas = {
        frame = addon:CreateWorkbenchScrollFrame(parent),
        cards = {},
        lines = {},
        labels = {},
        zones = {},
        groups = {},
        armButtons = {},
        generation = 0,
    }

    canvas.surface = CreateFrame('Frame', nil, canvas.frame)
    canvas.frame:SetScrollChild(canvas.surface)
    canvas.cameraHost = self:TrackWorkbenchSize(CreateFrame('Frame', nil, canvas.surface))
    canvas.child = self:TrackWorkbenchSize(CreateFrame('Frame', nil, canvas.cameraHost))
    canvas.child:SetPoint('TOPLEFT')
    canvas.horizontal = addon:CreateWorkbenchScrollBar(parent, 'HORIZONTAL')
    addon:TrackWorkbenchSize(canvas.horizontal)

    addon:SetUIScript(canvas.horizontal, 'OnValueChanged', function(_, value)
        canvas.scrollX = value
        canvas.frame:SetHorizontalScroll(value)
    end)

    canvas.ghost = addon:CreateWorkbenchDragCard()

    -- ============================================================================
    -- View state
    -- ============================================================================

    -- Ends any drag, pan or box selection: hides the ghost, markers and selection box, stops the per-frame update and
    -- restores the lifted cards. Safe to call at any time. If a measurement was deferred while dragging, the canvas
    -- reflows now; otherwise it refreshes the visible cards.
    function canvas:CancelDrag()
        local moving = self.drag or self.pan
        self.drag = nil
        self.pan = nil
        self.box = nil

        if self.boxFrame then
            self.boxFrame:Hide()
        end

        self.ghost:Hide()
        addon:SetUIScript(self.frame, 'OnUpdate', nil)

        for _, zone in ipairs(self.zones) do
            zone.marker:Hide()
            zone:Hide()
        end

        if moving and self.RefreshVisibleCards then
            if self.deferredMeasure then
                self.deferredMeasure = nil
                self:Reflow()
            else
                self:RefreshVisibleCards()
            end
        end
    end

    -- Tells whether the rotation section is shown as the pannable, zoomable diagram (not the list or cooldown grid).
    -- @return boolean  True for the diagram.
    function canvas:IsDiagram()
        return owner.view.section ~= 'cooldowns' and owner.view.layout ~= 'list'
    end

    -- Names the current section and layout; viewport positions are remembered per key.
    -- @return string  'cooldowns', 'rotation:diagram' or 'rotation:list'.
    function canvas:ModeKey()
        return owner.view.section == 'cooldowns' and 'cooldowns'
            or self:IsDiagram() and 'rotation:diagram'
            or 'rotation:list'
    end

    -- Returns the current zoom factor; always 1 outside the diagram.
    -- @return number  The zoom factor.
    function canvas:GetZoom()
        return self:IsDiagram() and zoom(owner.view.zoom) or 1
    end

    -- Saves the scroll position (relative to the diagram padding) in the view under the current mode key, so switching
    -- tabs or layouts and back returns to the same spot.
    function canvas:RememberViewport()
        local view = self.viewportView

        if not view or not self.modeKey then
            return
        end

        view.viewports = view.viewports or {}

        view.viewports[self.modeKey] = {
            x = (self.scrollX or 0) - (self.paddingX or 0),
            y = self.frame.workbenchBar:GetValue() - (self.paddingY or 0),
        }
    end

    -- Sets the diagram zoom (clamped), keeping the viewport center fixed, and reflows.
    -- @param value number  The requested zoom factor.
    -- @return boolean|nil  True when applied; nil when the editor is closed, the canvas is not the diagram or the value
    --   is
    -- not finite.
    function canvas:SetZoom(value)
        if not owner.active or not self:IsDiagram() or not finite(value) then
            return nil
        end

        local previous = self:GetZoom()
        local nextZoom = zoom(value)

        self.pendingViewport = {
            x = ((self.scrollX or 0) - (self.paddingX or 0) + self.frame:GetWidth() / 2) * nextZoom / previous
                - self.frame:GetWidth() / 2,
            y = (self.frame.workbenchBar:GetValue() - (self.paddingY or 0) + self.frame:GetHeight() / 2)
                * nextZoom
                / previous
                - self.frame:GetHeight() / 2,
        }

        self:CancelDrag()
        owner.view.zoom = nextZoom
        self:Reflow()
        return true
    end

    -- ScrollFrame still clips content, but its scrollbars are private camera
    -- coordinates in diagram mode. They never participate in pointer gestures.
    local updateScroll = canvas.frame.UpdateWorkbenchScroll

    -- Runs the stock scroll update, then hides the vertical bar in diagram mode where scrolling is the camera.
    --
    -- ScrollFrame still clips content, but its scrollbars are private camera coordinates in diagram mode. They never
    -- participate in pointer gestures.
    function canvas.frame:UpdateWorkbenchScroll()
        updateScroll(self)

        if canvas:IsDiagram() then
            self.workbenchBar:Hide()
        end
    end

    -- ============================================================================
    -- Selection
    -- ============================================================================

    -- Returns the selected step ids as a set, kept in owner.view (created on first use).
    -- @return table  A set of step id to true.
    --
    -- Several cards can be selected: Ctrl-click toggles a card, Shift-click selects the sibling range from the last
    -- clicked card, a plain click on a card's body selects only it, and a plain click on empty canvas clears the
    -- selection. Shift-drag on empty canvas draws a box that selects the cards it touches (Ctrl+Shift adds to the
    -- selection). The selection is view state: it survives renders and drops cards that no longer exist.
    function canvas:SelectionSet()
        owner.view.selection = owner.view.selection or {}
        return owner.view.selection
    end

    -- Tells whether cards can be selected. Selection drives copy, delete and enable, which a Built In (read-only) has
    -- none of: clicking its cards never selects them, so they never draw the gold outline and the selection bar never
    -- appears.
    -- @return boolean  True when the editor is open and the rotation is editable.
    function canvas:CanSelect()
        return owner.active and not owner.workspace.readOnly
    end

    -- Returns the selected step ids in document order.
    -- @param topLevel boolean|nil  When true, a card inside another selected card is left out (it travels with its
    --   parent).
    -- @return string[]  The selected step ids; empty when nothing is selected or the rotation cannot be indexed.
    function canvas:SelectedIds(topLevel)
        local selection = self:SelectionSet()
        local result = {}

        if next(selection) == nil then
            return result
        end

        local index = addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot())

        if not index then
            return result
        end

        local chosen = {}

        for _, row in ipairs(index.rows) do
            if selection[row.step.id] then
                chosen[#chosen + 1] = row
            end
        end

        for _, row in ipairs(chosen) do
            local nested = false

            if topLevel then
                for _, other in ipairs(chosen) do
                    if other ~= row and #other.path < #row.path then
                        local inside = true

                        for i = 1, #other.path do
                            if other.path[i] ~= row.path[i] then
                                inside = false
                                break
                            end
                        end

                        if inside then
                            nested = true
                            break
                        end
                    end
                end
            end

            if not nested then
                result[#result + 1] = row.step.id
            end
        end

        return result
    end

    -- Repaints every bound card's selected outline from the selection and tells the editor the selection changed.
    function canvas:PaintSelection()
        local selection = self:SelectionSet()

        for _, card in ipairs(self.cards) do
            if card.token and card.model and card.SetSelected then
                card:SetSelected(selection[card.model.id] == true)
            end
        end

        if owner.SelectionChanged then
            owner:SelectionChanged()
        end
    end

    -- Empties the selection and the range anchor.
    function canvas:ClearSelection()
        if next(self:SelectionSet()) == nil then
            return
        end

        owner.view.selection = {}
        self.anchor = nil
        self:PaintSelection()
    end

    -- Applies a click on a card. A range only works between siblings of the same parent.
    -- @param id string  The step id of the clicked card.
    -- @param toggle boolean|nil  Ctrl: adds or removes the card instead of replacing the selection.
    -- @param range boolean|nil  Shift: selects the siblings between the anchor card and this one.
    --
    -- With neither flag only this card is selected and it becomes the range anchor. Does nothing when selection is
    -- unavailable or the id is not in the scene.
    function canvas:Select(id, toggle, range)
        if not self:CanSelect() or not self.scene then
            return
        end

        local selection = self:SelectionSet()
        local byId = {}

        for _, model in ipairs(self.scene.cards) do
            byId[model.id] = model
        end

        local model = byId[id]

        if not model then
            return
        end

        local anchor = self.anchor and byId[self.anchor]

        if
            range
            and anchor
            and anchor.parentId == model.parentId
            and #anchor.path == #model.path
            and anchor.path[1] == model.path[1]
        then
            if not toggle then
                selection = {}
            end

            local depth = #model.path

            local low, high = math.min(anchor.path[depth], model.path[depth]), math.max(
                anchor.path[depth],
                model.path[depth]
            )

            for _, other in ipairs(self.scene.cards) do
                if
                    other.parentId == model.parentId
                    and #other.path == depth
                    and other.path[1] == model.path[1]
                    and other.path[depth] >= low
                    and other.path[depth] <= high
                then
                    selection[other.id] = true
                end
            end
        elseif toggle then
            selection[id] = not selection[id] or nil
        else
            selection = { [id] = true }
        end

        owner.view.selection = selection

        if not range then
            self.anchor = id
        end

        self:PaintSelection()
    end

    -- Selects the cards touching a box given in canvas (child) coordinates.
    -- @param left number  The box's left edge.
    -- @param top number  The box's top edge.
    -- @param right number  The box's right edge.
    -- @param bottom number  The box's bottom edge.
    -- @param additive boolean|nil  True keeps the current selection and adds to it.
    function canvas:SelectBox(left, top, right, bottom, additive)
        if not self:CanSelect() or not self.scene then
            return
        end

        local selection = additive and self:SelectionSet() or {}

        for _, model in ipairs(self.scene.cards) do
            if
                model.x <= right
                and model.x + model.width >= left
                and model.y <= bottom
                and model.y + model.height >= top
            then
                selection[model.id] = true
            end
        end

        owner.view.selection = selection
        self:PaintSelection()
    end

    -- ============================================================================
    -- Pointer gestures
    -- ============================================================================

    -- Starts a rubber-band selection at the pointer (Ctrl makes it additive). An OnUpdate follows the pointer and ends
    -- the gesture on mouse release, on a render (generation change) or when the editor closes.
    -- @return boolean  False when selection is unavailable or the pointer is not over the canvas; otherwise true.
    function canvas:BeginBoxSelect()
        if not self:CanSelect() or self.drag then
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

        -- Per-frame follower for the rubber band: stretches the box to the pointer and ends the selection on mouse
        -- release; cancels it when the editor closed or a render invalidated the gesture.
        addon:SetUIScript(self.frame, 'OnUpdate', function()
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

            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
                self:EndBoxSelect()
            end
        end)

        return true
    end

    -- Finishes the rubber band: removes it and selects the cards inside the final box.
    function canvas:EndBoxSelect()
        local box = self.box

        if not box then
            return
        end

        local cx, cy = box.cx or box.x, box.cy or box.y
        self:CancelDrag()
        self:SelectBox(math.min(box.x, cx), math.min(box.y, cy), math.max(box.x, cx), math.max(box.y, cy), box.additive)
    end

    -- Starts dragging the diagram camera from empty space. Refused over the zoom bar or any card. The pointer is read
    -- with GetCursorPosition under pcall and validated, because the pan scrolls by the raw difference scaled by the
    -- frame's effective scale; any bad reading ends the pan.
    -- @return boolean  True when a pan started.
    function canvas:BeginPan()
        if not owner.active or not self:IsDiagram() or self.drag or type(GetCursorPosition) ~= 'function' then
            return false
        end
        if owner.zoomBar and owner.zoomBar:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(
            owner.zoomBar,
            self.frame
        ) then
            return false
        end

        for _, card in ipairs(self.cards) do
            if card.frame:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(card.frame, self.frame) then
                return false
            end
        end

        local ok, x, y = pcall(GetCursorPosition)
        local scale = self.frame:GetEffectiveScale()

        if not ok or not finite(x) or not finite(y) or not finite(scale) or scale <= 0 then
            return false
        end

        self:CancelDrag()

        local request = {
            x = x,
            y = y,
            scale = scale,
            scrollX = self.scrollX or 0,
            scrollY = self.frame.workbenchBar:GetValue(),
            generation = self.generation,
        }

        self.pan = request

        -- Per-frame follower for the pan: scrolls the camera by the pointer movement (marking the pan as moved past 3
        -- pixels) and ends the pan on mouse release, on a render or on a bad pointer reading.
        addon:SetUIScript(self.frame, 'OnUpdate', function()
            if self.pan ~= request then
                return
            end

            if
                not owner.active
                or request.generation ~= self.generation
                or IsMouseButtonDown and not IsMouseButtonDown('LeftButton')
            then
                self:CancelDrag()
                return
            end

            local valid, cx, cy = pcall(GetCursorPosition)

            if not valid or not finite(cx) or not finite(cy) then
                self:CancelDrag()
                return
            end

            if math.abs(cx - request.x) + math.abs(cy - request.y) > 3 then
                request.moved = true
            end

            self.horizontal:SetValue(request.scrollX - (cx - request.x) / request.scale)
            self.frame.workbenchBar:SetValue(request.scrollY + (cy - request.y) / request.scale)
        end)

        return true
    end

    -- Wires mouse wheel (zoom in the diagram, scroll elsewhere), middle click (reset zoom) and left click and drag
    -- gestures onto a control.
    -- @param control table  The frame that receives the input.
    -- @param pan boolean|nil  True lets dragging on the control pan or box-select.
    -- @param alive function|nil  The caller's staleness check; input is ignored when it returns false.
    -- @param click function|nil  The plain-click handler (skipped after a drag).
    function canvas:BindViewportInput(control, pan, alive, click)
        control:EnableMouse(true)
        control:EnableMouseWheel(true)

        addon:SetUIScript(control, 'OnMouseWheel', function(_, delta)
            if not owner.active or alive and not alive() then
                return
            end

            if self:IsDiagram() then
                self:SetZoom(math.floor(self:GetZoom() * 100 + .5) / 100 + delta * .1)
            else
                self.frame.workbenchBar:SetValue(self.frame.workbenchBar:GetValue() - delta * 40)
            end
        end)

        -- Handles a mouse release on the control: middle click resets the zoom, left click ends a box selection, or
        -- finishes a pan and, when nothing was dragged, runs the click handler (or clears the selection on empty
        -- canvas).
        -- @param button string  The mouse button that was released.
        addon:SetUIScript(control, 'OnMouseUp', function(_, button)
            if not owner.active or alive and not alive() then
                return
            end

            if button == 'MiddleButton' then
                self:SetZoom(1)
            elseif button == 'LeftButton' and self.box then
                self:EndBoxSelect()
            elseif button == 'LeftButton' then
                -- A click (not a pan or drag) on a card selects; on empty
                -- canvas it clears the selection.
                local request = self.pan
                local moved = request and request.moved

                if request then
                    self:CancelDrag()
                end

                if click then
                    if not control.rmDragged then
                        click()
                    end
                elseif pan and not moved then
                    self:ClearSelection()
                end
            end
        end)

        if pan then
            control:RegisterForDrag('LeftButton')

            -- Starts a box selection when Shift is held and selection is allowed, otherwise a pan.
            local function begin()
                if IsShiftKeyDown and IsShiftKeyDown() and self:CanSelect() then
                    self:BeginBoxSelect()
                else
                    self:BeginPan()
                end
            end

            addon:SetUIScript(control, 'OnMouseDown', function(_, button)
                if button == 'LeftButton' then
                    begin()
                end
            end)

            addon:SetUIScript(control, 'OnDragStart', function()
                if not self.box and not self.pan then
                    begin()
                end
            end)

            addon:SetUIScript(control, 'OnDragStop', function()
                if self.box then
                    self:EndBoxSelect()
                elseif self.pan then
                    self:CancelDrag()
                end
            end)
        end
    end

    for _, surface in ipairs({ canvas.frame, canvas.child, canvas.cameraHost, canvas.surface }) do
        canvas:BindViewportInput(surface, true)

        addon:SetUIScript(surface, 'OnHide', function()
            canvas:CancelDrag()
        end)
    end

    -- ============================================================================
    -- Drag and drop
    -- ============================================================================

    -- Names the editor command a drop performs.
    -- @param drag table  The drag record ({ insert, ids, tail, ... }).
    -- @return string  'Insert' (palette), 'MoveMany' (a selection), 'MoveTail' (Ctrl-drag) or 'Move'.
    local function dragCommand(drag)
        return drag.insert and 'Insert' or drag.ids and 'MoveMany' or (drag.tail and 'MoveTail' or 'Move')
    end

    -- Tells whether dropping the current drag into `target` (a gap) would change the rotation. Tries the command on a
    -- scratch draft and rejects drops that leave every carried card where it was; results are cached per gap for the
    -- life of the drag.
    -- @param target table  The drop target ({ destination = { path, index, parentId } }).
    -- @return boolean  True when the drop is allowed and moves something.
    function canvas:CanDrop(target)
        local drag = self.drag

        if not drag or not owner.active or owner.workspace.readOnly or drag.generation ~= self.generation then
            return false
        end

        local d = target.destination
        local key = location(d.path) .. ':' .. d.index .. ':' .. (d.parentId or '')

        if drag.valid[key] ~= nil then
            return drag.valid[key]
        end

        local draft = addon.RotationData.NewRotationDraft(owner.workspace:Snapshot(), addon.uuid)
        local command = dragCommand(drag)
        local ok = draft and draft:Command(command, drag.insert and d or drag.ids or drag.id, drag.insert or d)

        if ok and drag.ids then
            -- A gap that leaves every carried card where it was is no move.
            local before = addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId
            local after = addon.RotationData.IndexRotationSteps(draft:Snapshot()).byId
            local moved = false

            for _, id in ipairs(drag.ids) do
                if not before[id] or not after[id] or location(before[id].path) ~= location(after[id].path) then
                    moved = true
                    break
                end
            end

            ok = moved
        elseif ok and not drag.insert then
            local before = addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId[drag.id]
            local after = addon.RotationData.IndexRotationSteps(draft:Snapshot()).byId[drag.id]

            if before and after and location(before.path) == location(after.path) then
                ok = false
            end
        end

        drag.valid[key] = ok == true
        return ok == true
    end

    -- Finds the gap under the pointer that accepts the drag and shows only its marker.
    -- @return table|nil  The drop zone under the pointer, or nil.
    function canvas:HoverTarget()
        local selected

        for _, zone in ipairs(self.zones) do
            if zone:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(zone, self.frame) and self:CanDrop(
                zone.target
            ) then
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

    -- Ends the drag and, if the drop is valid and still current, sends the move or insert command to the editor.
    -- @param target table  The drop target ({ destination = ... }).
    -- @return any  What owner:Command returns for the drop; nil when the drop was not valid.
    function canvas:Drop(target)
        local drag = self.drag
        local valid = self:CanDrop(target)
        self:CancelDrag()

        if not valid or not drag or drag.generation ~= self.generation then
            return
        end

        return owner:Command(
            dragCommand(drag),
            drag.insert and target.destination or drag.ids or drag.id,
            drag.insert or target.destination
        )
    end

    -- Handles the mouse release of a drag: drops on the hovered gap if there is one, else cancels.
    -- @return any  What Drop returns when a drop happened; nil otherwise.
    function canvas:EndDrag()
        if not self.drag then
            return
        end

        local zone = self:HoverTarget()

        if zone then
            return self:Drop(zone.target)
        end

        self:CancelDrag()
    end

    -- Starts a drag of card `id` (with Ctrl, that card and the siblings after it; if it is selected, the whole
    -- selection), or of a new step from the palette. Shows the ghost with the dragged cards lifted onto it, reveals the
    -- drop gaps and starts an OnUpdate that follows the pointer and drops on release. Does nothing for a read-only
    -- rotation.
    -- @param id string|nil  The step id of the card being dragged; nil when dragging a new step.
    -- @param insert table|nil  The new step to insert from the palette; nil when moving an existing card.
    -- @param insertSource table|nil  The palette button the new step is dragged from.
    function canvas:BeginDrag(id, insert, insertSource)
        self:CancelDrag()

        if not owner.active or owner.workspace.readOnly then
            return
        end

        self.drag = {
            id = id,
            insert = insert,
            tail = id ~= nil and IsControlKeyDown and IsControlKeyDown() or false,
            generation = self.generation,
            valid = {},
        }

        local step = insert or addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId[id].step

        local title = step.name
            or (step.type == 'branch' and L['Add branch']
                or step.type == 'stop' and L['Stop']
                or step.type == 'assisted' and L["Blizzard's suggestion"]
                or addon:SpellLabel(step.action))

        if self.drag.tail then
            title = L['Move this and following entries'] .. ': ' .. title
        end

        local count = 1
        local selected = {}
        -- Dragging a selected card carries the whole selection.
        local carriedIds = id and not self.drag.tail and self:SelectionSet()[id] and self:SelectedIds(true)

        if carriedIds and #carriedIds > 1 then
            self.drag.ids = carriedIds
            title = string.format(L['Move %d selected cards'], #carriedIds)
            count = 0
            local index = addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot())

            for _, carried in ipairs(carriedIds) do
                local source = index.byId[carried]

                for _, row in ipairs(index.rows) do
                    local inside = #row.path >= #source.path

                    for i = 1, #source.path do
                        if row.path[i] ~= source.path[i] then
                            inside = false
                            break
                        end
                    end

                    if inside and not selected[row.step.id] then
                        selected[row.step.id] = true
                        count = count + 1
                    end
                end
            end
        elseif id then
            count = 0
            local index = addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot())
            local source = index.byId[id]
            local base = {}

            for i = 1, #source.path - 1 do
                base[i] = source.path[i]
            end

            for _, row in ipairs(index.rows) do
                local same = true
                local length = self.drag.tail and #base or #source.path

                for i = 1, length do
                    if row.path[i] ~= (self.drag.tail and base[i] or source.path[i]) then
                        same = false
                        break
                    end
                end

                if
                    same
                    and (not self.drag.tail
                        or type(row.path[#base + 1]) == 'number' and row.path[#base + 1] >= source.index)
                then
                    count = count + 1
                    selected[row.step.id] = true
                end
            end
        end

        self.ghost:Present(
            title,
            addon:DescribeCondition(step.conditions or {}, owner.workspace.spec)
                .. '\n'
                .. L['Drop in a highlighted gap.'],
            self.frame,
            count
        )

        if id then
            local entries, edges, lines = {}, {}, {}

            for _, card in ipairs(self.cards) do
                local model = card.model

                if card.frame:IsShown() and selected[model.id] then
                    entries[#entries + 1] = {
                        frame = card.frame,
                        x = model.x,
                        y = model.y,
                        width = model.width,
                        height = model.height,
                    }
                end
            end

            for i, model in ipairs(self.scene.groups or {}) do
                if selected[model.id] and self.groups[i] then
                    entries[#entries + 1] = {
                        frame = self.groups[i],
                        x = model.x,
                        y = model.y,
                        width = model.width,
                        height = model.height,
                    }
                end
            end

            for _, button in ipairs(self.armButtons) do
                local model = button.model

                if button:IsShown() and model and selected[model.parentId] then
                    entries[#entries + 1] = { frame = button, x = model.x, y = model.y, width = 100, height = 18 }
                end
            end

            -- Tells whether a connector belongs to the dragged cards (its owner, or both of its ends, are being
            -- carried).
            -- @param edge table|nil  The scene connector ({ owner, from, to, ... }).
            -- @return boolean|string|nil  Truthy when the connector travels with the drag.
            local function owns(edge)
                return edge
                    and (edge.owner and selected[edge.owner]
                        or edge.from and edge.to and selected[edge.from] and selected[edge.to])
            end

            for _, edge in ipairs(self.scene.connectors) do
                if owns(edge) then
                    edges[#edges + 1] = edge
                end
            end

            for _, line in ipairs(self.lines) do
                if line:IsShown() and owns(line.edge) then
                    lines[#lines + 1] = line
                end
            end

            self.ghost:PresentCards(entries, self.child, edges, lines)
        elseif insertSource then
            self.ghost:PresentSource(insertSource)
        end

        self.ghost:CaptureCancel(function()
            self:CancelDrag()
        end)

        for _, zone in ipairs(self.zones) do
            zone:Show()
        end

        addon:SetUIScript(self.frame, 'OnUpdate', function()
            if not owner.active or not self.drag or self.drag.generation ~= self.generation then
                self:CancelDrag()
                return
            end

            self.ghost:FollowPointer()
            self:HoverTarget()

            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
                self:EndDrag()
            end
        end)
    end

    -- ============================================================================
    -- Scene drawing
    -- ============================================================================

    -- Places the horizontal scroll bar under the canvas frame at the frame's width.
    function canvas:LayoutScrollBar()
        self.horizontal:ClearAllPoints()
        self.horizontal:SetPoint('TOPLEFT', self.frame, 'BOTTOMLEFT', 0, -4)
        self.horizontal:SetWidth(self.frame:GetWidth())
    end

    -- Rebuilds the scene from the editor and redraws everything that is not a card control: scroll extents and zoom,
    -- group frames, connector lines, True/False labels and arm buttons, drop gaps; already bound cards are only
    -- re-placed. Restores the remembered viewport for the mode, then refreshes which cards exist. Frames and textures
    -- are pooled and reused. A failure inside is re-raised after the reflowing flag is cleared. Does nothing while the
    -- editor is closed.
    function canvas:Reflow()
        if not owner.active then
            return
        end

        local scene = owner:BuildScene()
        self.scene = scene

        if not scene then
            return
        end

        -- The viewport this layout was made for (see the editor's resize).
        self.reflowedWidth, self.reflowedHeight = self.frame:GetWidth(), self.frame:GetHeight()
        self.reflowing = true

        -- Does the drawing work of Reflow under pcall: viewport and zoom, scroll extents, group frames, connector
        -- lines, labels, arm buttons and drop gaps; cards that left the scene also leave the selection.
        local ok, problem = pcall(function()
            local key = self:ModeKey()
            self:RememberViewport()
            local position = self.pendingViewport or (owner.view.viewports or {})[key] or { x = 0, y = 0 }
            self.pendingViewport = nil
            self.viewportView = owner.view
            self.modeKey = key
            local factor = self:GetZoom()
            local diagram = self:IsDiagram()
            self.paddingX = diagram and self.frame:GetWidth() / 2 or 0
            self.paddingY = diagram and self.frame:GetHeight() / 2 or 0
            self.cameraHost:ClearAllPoints()
            self.cameraHost:SetPoint('TOPLEFT', self.surface, 'TOPLEFT', self.paddingX, -self.paddingY)
            self.cameraHost:SetSize(scene.width * factor, scene.height * factor)
            self.child:SetSize(scene.width, scene.height)
            self.child:SetScale(factor)
            local width = math.max(self.frame:GetWidth(), scene.width * factor + 2 * self.paddingX)
            local height = math.max(self.frame:GetHeight(), scene.height * factor + 2 * self.paddingY)
            self.surface:SetSize(width, height)
            self.horizontal:UpdateExtent(width, self.frame:GetWidth())
            self.horizontal:SetValue(position.x + self.paddingX)
            self.frame:UpdateScrollChildRect()
            self.frame:UpdateWorkbenchScroll()
            self.frame.workbenchBar:SetValue(position.y + self.paddingY)

            if diagram then
                self.horizontal:Hide()
                self.frame.workbenchBar:Hide()
            end

            for i, model in ipairs(scene.groups or {}) do
                local group = self.groups[i]

                if not group then
                    group = CreateFrame('Frame', nil, self.child)
                    group:EnableMouse(false)
                    group.decoration = addon:CreateRoundedCardDecoration(group)
                    self.groups[i] = group
                end

                group:SetFrameLevel(self.child:GetFrameLevel())
                group:ClearAllPoints()
                group:SetPoint('TOPLEFT', self.child, 'TOPLEFT', model.x, -model.y)
                group:SetSize(model.width, model.height)
                local tone = colors[model.inactive and 'gray' or model.tone] or colors.neutral
                group.decoration:SetColors(tone[1], tone[2], tone[3], .65, .025)
                group:Show()
            end

            for i = #(scene.groups or {}) + 1, #self.groups do
                self.groups[i]:Hide()
            end

            local byId = {}

            for _, model in ipairs(scene.cards) do
                byId[model.id] = model
            end

            for _, card in ipairs(self.cards) do
                if card.token and card.model and byId[card.model.id] then
                    card:Place(byId[card.model.id], owner.workspace.readOnly)
                end
            end

            -- Cards that left the scene (removed, or under a folded branch) leave
            -- the selection.
            local selection = self:SelectionSet()

            for selected in pairs(selection) do
                if not byId[selected] then
                    selection[selected] = nil
                end
            end

            if owner.SelectionChanged then
                owner:SelectionChanged()
            end

            local n = 0

            for _, edge in ipairs(scene.connectors) do
                local tone = colors[edge.tone] or colors.neutral

                for i = 2, #edge.points do
                    n = n + 1
                    local line = self.lines[n]

                    if not line then
                        line = self.child:CreateTexture(nil, 'BACKGROUND')
                        self.lines[n] = line
                    end

                    local a, b = edge.points[i - 1], edge.points[i]
                    line.edge = edge
                    line:ClearAllPoints()
                    line:SetPoint('TOPLEFT', self.child, 'TOPLEFT', math.min(a.x, b.x), -math.min(a.y, b.y))
                    line:SetSize(math.max(2, math.abs(a.x - b.x) + 2), math.max(2, math.abs(a.y - b.y) + 2))
                    line:SetColorTexture(tone[1], tone[2], tone[3], edge.inactive and .25 or .8)
                    line:Show()
                end
            end

            for i = n + 1, #self.lines do
                self.lines[i]:Hide()
            end

            local labels = 0

            for _, edge in ipairs(scene.connectors) do
                if edge.label and #(scene.armLabels or {}) == 0 then
                    labels = labels + 1
                    local label = self.labels[labels]

                    if not label then
                        label = self.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                        self.labels[labels] = label
                    end

                    local point = edge.points[2]
                    local tone = colors[edge.tone] or colors.neutral
                    label:ClearAllPoints()

                    label:SetPoint(
                        'TOPLEFT',
                        self.child,
                        'TOPLEFT',
                        point.x + (edge.arm == 'false' and -40 or 8),
                        -point.y + 14
                    )

                    label:SetText(edge.arm == 'true' and L['True'] or L['False'])
                    label:SetTextColor(tone[1], tone[2], tone[3])
                    label:Show()
                end
            end

            for i, arm in ipairs(scene.armLabels or {}) do
                local button = self.armButtons[i]

                if not button then
                    button = addon:CreateWorkbenchButton(self.child, '', 100)
                    button.art:SetAlpha(.2)
                    self.armButtons[i] = button
                end

                button.model = arm
                local token = self.generation
                local tone = arm.arm == 'false' and colors.red or colors.green
                button:ClearAllPoints()
                button:SetPoint('TOPLEFT', self.child, 'TOPLEFT', arm.x, -arm.y)
                button:SetSize(100, 18)
                local text = arm.arm == 'true' and L['True'] or L['False']
                button:SetText(text .. (arm.folded and string.format(L[' (%d hidden)'], arm.count or 0) or ''))
                button:GetFontString():SetTextColor(tone[1], tone[2], tone[3], arm.inactive and .4 or 1)
                button.tooltip = L['Click to fold or unfold this branch arm. Other cards and conditions are unchanged.']

                addon:SetUIScript(button, 'OnClick', function()
                    if not owner.active or self.generation ~= token then
                        return
                    end

                    owner.view.hiddenArms = owner.view.hiddenArms or {}
                    local state = owner.view.hiddenArms[arm.parentId] or {}
                    owner.view.hiddenArms[arm.parentId] = state
                    state[arm.arm] = not state[arm.arm]
                    self:Render()
                end)

                button:Show()
            end

            for i = #(scene.armLabels or {}) + 1, #self.armButtons do
                self.armButtons[i]:Hide()
            end

            for i = labels + 1, #self.labels do
                self.labels[i]:Hide()
            end

            for i, target in ipairs(scene.dropTargets) do
                local zone = self.zones[i]

                if not zone then
                    zone = CreateFrame('Frame', nil, self.child)
                    zone:EnableMouse(false)
                    zone.marker = zone:CreateTexture(nil, 'OVERLAY')
                    zone.marker:SetColorTexture(.9, .75, .3, .95)
                    zone.marker:SetPoint('LEFT')
                    zone.marker:SetPoint('RIGHT')
                    zone.marker:SetHeight(3)
                    self.zones[i] = zone
                end

                zone.target = target
                zone:ClearAllPoints()
                zone:SetPoint('TOPLEFT', self.child, 'TOPLEFT', target.x, -target.y)
                zone:SetSize(target.width, target.height)
                zone.marker:Hide()

                if self.drag then
                    zone:Show()
                else
                    zone:Hide()
                end
            end

            for i = #scene.dropTargets + 1, #self.zones do
                self.zones[i]:Hide()
            end

            self.frame:UpdateScrollChildRect()
            self.frame:UpdateWorkbenchScroll()
            owner:UpdateHistory()

            if owner.UpdateCanvasNavigation then
                owner:UpdateCanvasNavigation()
            end
        end)

        self.reflowing = nil

        if not ok then
            error(problem, 0)
        end

        self:RefreshVisibleCards()
    end

    -- ============================================================================
    -- Cards
    -- ============================================================================

    -- Binds a pooled card to a scene model and wires all of its controls (title, name edit, action, condition, remove,
    -- duplicate, enable, move, help, fold, selection and drag). Every handler is guarded by a token that is invalidated
    -- on render or release.
    -- @param card table  The pooled card control from addon:CreateRotationCard.
    -- @param model table  The scene card model (id, step, path, parentId, x, y, width, height, compact, expanded, ...).
    -- @return boolean  True when the card's measured summary or details height changed, which means the scene must
    --   reflow.
    function canvas:BindCard(card, model)
        local priorSummary = math.max(0, ((owner.view.summaryHeights or {})[model.id] or 0) - 28)
        local priorDetails = (owner.view.detailsHeights or {})[model.id]
        local token = { generation = self.generation }
        card.token = token
        card.spec = owner.workspace.spec

        -- Tells whether the editor is open and this card is still bound by this render.
        -- @return boolean  True while handlers of this card may act.
        local function alive()
            return owner.active and token.generation == self.generation and card.token == token
        end

        -- Tells whether the card is alive and the rotation is editable (not a Built In).
        -- @return boolean  True when a handler may change the rotation.
        local function writable()
            return alive() and not owner.workspace.readOnly
        end

        card:Place(model, owner.workspace.readOnly)
        owner.view.summaryHeights = owner.view.summaryHeights or {}
        local summary = card.condition:GetFontString()

        if summary.GetStringHeight then
            owner.view.summaryHeights[model.id] = summary:GetStringHeight() + 4
        end

        local step = model.step

        addon:SetUIScript(card.expand, 'OnClick', function()
            if not alive() then
                return
            end

            owner.view.cardStates = owner.view.cardStates or {}
            owner.view.cardStates[model.id] = model.compact and 'normal' or model.expanded and 'normal' or 'compact'
            self:Render()
        end)

        addon:SetUIScript(card.title, 'OnClick', function()
            if alive() and model.compact then
                owner.view.cardStates[model.id] = 'normal'
                owner:Render()
                return
            end

            if writable() then
                card.name:SetText(addon:PlainWorkbenchName(owner:FieldText(model.id, 'name', step.name or '')))
                card.title:Hide()
                card.name:Show()
                card.name:SetFocus()
            end
        end)

        addon:BindWorkbenchInlineName(card.name, function()
            if alive() then
                card.name:Hide()
                card.title:Show()
                local name = owner:FieldText(model.id, 'name', step.name or '')

                if name == '' then
                    name = card.defaultTitle
                end

                card.title:SetText(addon:PlainWorkbenchName(name))
            end
        end)

        addon:SetUIScript(card.name, 'OnTextChanged', function(input, userInput)
            if writable() and userInput then
                owner:StageField(model.id, 'name', input:GetText(), step.name or '', L['Name'])
            end
        end)

        addon:SetUIScript(card.name, 'OnEnterPressed', function(input)
            if not writable() then
                return
            end

            owner:StageField(model.id, 'name', input:GetText(), step.name or '', L['Name'])
            local ok, why = owner:FlushFieldEdits()

            if ok then
                owner:Render()
            else
                owner:Message(why)
            end
        end)

        local pendingName = owner:FieldText(model.id, 'name', step.name or '')

        if pendingName ~= '' then
            card.title:SetText(addon:PlainWorkbenchName(pendingName))
        end

        addon:SetUIScript(card.name, 'OnEscapePressed', function()
            card.name:ClearFocus()
            card.name:Hide()
            card.title:Show()
        end)

        addon:SetUIScript(card.title, 'OnDragStart', function()
            if writable() then
                self:BeginDrag(model.id)
            end
        end)

        addon:SetUIScript(card.title, 'OnDragStop', function()
            if alive() then
                self:EndDrag()
            end
        end)

        -- Returns the spell hyperlink for a spell, pet or any step.
        -- @return string|nil  'spell:<id>' for the step's action; nil for items and other kinds, or an unknown spell.
        local function actionLink()
            if step.type ~= 'spell' and step.type ~= 'pet' and step.type ~= 'any' then
                return
            end

            local info = addon.Platform and addon.Platform:GetSpellInfo(step.action)

            if info and info.spellID then
                return 'spell:' .. info.spellID
            end
        end

        addon:SetUIScript(card.action, 'OnEnter', function(control)
            if not alive() then
                return
            end

            local link = actionLink()

            if link and GameTooltip then
                GameTooltip:SetOwner(control, 'ANCHOR_RIGHT')
                GameTooltip:SetHyperlink(link)
            end
        end)

        addon:SetUIScript(card.action, 'OnLeave', function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        addon:SetUIScript(card.action, 'OnClick', function(_, button)
            if not alive() then
                return
            end

            local link = actionLink()

            if IsShiftKeyDown and IsShiftKeyDown() and link and type(SetItemRef) == 'function' then
                SetItemRef(link, addon:SpellLabel(step.action), button or 'LeftButton')
            else
                owner.view.cardStates[model.id] = 'expanded'
                self:Render()
            end
        end)

        addon:SetUIScript(card.condition, 'OnClick', function()
            if alive() then
                owner:EditCondition(model.id)
            end
        end)

        addon:SetUIScript(card.condition, 'OnEnter', function(control)
            if alive() and GameTooltip then
                addon:ShowConditionFieldTooltip(control, control.tooltip, card.liveBar and card.liveBar.state)
            end
        end)

        addon:SetUIScript(card.condition, 'OnLeave', function(control)
            if alive() and GameTooltip and GameTooltip:IsOwned(control) then
                GameTooltip:Hide()
            end
        end)

        addon:SetUIScript(card.controls.remove, 'OnClick', function()
            if writable() then
                owner:Command('Remove', model.id)
            end
        end)

        addon:SetUIScript(card.controls.duplicate, 'OnClick', function()
            if writable() then
                owner:Command('Duplicate', model.id)
            end
        end)

        addon:SetUIScript(card.controls.enable, 'OnClick', function()
            if not writable() then
                return
            end

            if step.type == 'branch' then
                owner:Command('UpdateStep', model.id, {
                    mode = (step.mode or 'evaluate') == 'evaluate' and 'true'
                        or step.mode == 'true' and 'false'
                        or 'evaluate',
                })
            else
                owner:Command('UpdateStep', model.id, { disabled = not step.disabled })
            end
        end)

        for _, direction in ipairs({ { 'up', -1 }, { 'down', 1 } }) do
            local delta = direction[2]

            addon:SetUIScript(card.controls[direction[1]], 'OnClick', function()
                if not writable() then
                    return
                end

                local path = {}

                for j = 1, #model.path - 1 do
                    path[j] = model.path[j]
                end

                local at = model.path[#model.path] + (delta > 0 and 2 or -1)
                owner:Command('Move', model.id, { path = path, index = at, parentId = model.parentId })
            end)
        end

        addon:SetUIScript(card.controls.help, 'OnClick', function()
            if alive() then
                owner:ShowCardHelp(model)
            end
        end)

        addon:SetUIScript(card.armToggle, 'OnClick', function()
            if alive() then
                owner.view.hiddenChildren[model.id] = not owner.view.hiddenChildren[model.id]
                self:Render()
            end
        end)

        -- Reads the current Ctrl and Shift key states, tolerating clients without those functions.
        -- @return boolean  True while Ctrl is held.
        -- @return boolean  True while Shift is held.
        local function modifiers()
            return IsControlKeyDown and IsControlKeyDown() or false, IsShiftKeyDown and IsShiftKeyDown() or false
        end

        -- Handles a plain click on the card's body: selects it (with Ctrl or Shift for toggle and range).
        local function clickBody()
            if not alive() then
                return
            end

            local ctrl, shift = modifiers()
            self:Select(model.id, ctrl, shift)
        end

        for _, source in ipairs({ card.title, card.action, card.condition, card.frame }) do
            self:BindViewportInput(source, false, alive, source == card.frame and clickBody or nil)

            addon:BindWorkbenchDragSource(
                source,
                function()
                    if writable() then
                        self:BeginDrag(model.id)
                    end
                end,
                function()
                    if alive() then
                        self:EndDrag()
                    end
                end
            )
        end

        -- Ctrl-click anywhere on a card toggles it; Shift-click on its title
        -- or condition extends the range (Shift-click on the action still
        -- links the spell). Other clicks keep their own meaning.
        for _, source in ipairs({ card.title, card.action, card.condition }) do
            local original = source:GetScript('OnClick')

            -- Wraps the control's own click handler: Ctrl-click (and Shift-click, except on the action) selects the
            -- card instead of running the handler, unless the click ends a drag.
            -- @param ... any  The click arguments, passed on to the original handler.
            -- @return any  Whatever the original handler returns, when it ran.
            --
            -- Ctrl-click anywhere on a card toggles it; Shift-click on its title or condition extends the range
            -- (Shift-click on the action still links the spell). Other clicks keep their own meaning.
            addon:SetUIScript(source, 'OnClick', function(...)
                local ctrl, shift = modifiers()

                if alive() and (ctrl or shift and source ~= card.action) then
                    if not source.rmDragged then
                        self:Select(model.id, ctrl, shift)
                    end

                    source.rmDragged = false
                    return
                end

                if original then
                    return original(...)
                end
            end)
        end

        if card.SetSelected then
            card:SetSelected(self:SelectionSet()[model.id] == true)
        end
        if model.expanded and owner.BuildFields then
            owner:BuildFields(card, model, alive)
        end

        return math.abs(priorSummary - math.max(0, (owner.view.summaryHeights[model.id] or 0) - 28)) > .5
            or priorDetails ~= (owner.view.detailsHeights or {})[model.id]
    end

    -- Tells whether the card's name box or one of its field inputs has keyboard focus; such a card is never released,
    -- so typing is not interrupted by a refresh.
    -- @param card table  The card control.
    -- @return boolean  True when the card has keyboard focus.
    local function focused(card)
        if card.name:HasFocus() then
            return true
        end

        for _, input in ipairs(card.fieldPool and card.fieldPool.inputs or {}) do
            if input.HasFocus and input:HasFocus() then
                return true
            end
        end

        return false
    end

    -- Releases the expanded cards (unless one holds focus or is being dragged) so the next reflow binds them at the new
    -- width; every other card is only re-placed.
    --
    -- Expanded cards lay their fields out for the card width when bound.
    function canvas:ReleaseExpandedCards()
        for _, card in ipairs(self.cards) do
            if
                card.token
                and card.model
                and card.model.expanded
                and not focused(card)
                and card.frame:GetParent() ~= self.ghost
            then
                card:Release()
                card.model = nil
            end
        end
    end

    -- Makes sure exactly the cards near the viewport have controls: releases cards that scrolled away (never one that
    -- is focused or being dragged) and binds pooled cards to the models that came into range. Scenes of up to 200 cards
    -- bind them all. If binding changed a measured height the scene reflows (deferred while a drag runs); a failure
    -- while binding releases the half-bound card before the error is re-raised.
    function canvas:RefreshVisibleCards()
        if not owner.active or not self.scene or self.refreshing then
            return
        end

        self.refreshing = true
        local measured, created = false, false
        local constructing

        -- Works out the models within 340 by 180 pixels of the viewport, releases bound cards outside it and binds
        -- pooled (or new) cards for the rest.
        local ok, problem = pcall(function()
            local factor = self:GetZoom()
            local left = ((self.scrollX or 0) - (self.paddingX or 0)) / factor
            local top = (self.frame.workbenchBar:GetValue() - (self.paddingY or 0)) / factor
            local right = left + self.frame:GetWidth() / factor
            local bottom = top + self.frame:GetHeight() / factor
            local models, wanted = {}, {}

            -- Short scenes preserve the established all-card behavior. Larger
            -- scenes keep complete geometry and only materialize nearby controls.
            for _, model in ipairs(self.scene.cards) do
                if
                    #self.scene.cards <= 200
                    or model.x + model.width >= left - 340
                        and model.x <= right + 340
                        and model.y + model.height >= top - 180
                        and model.y <= bottom + 180
                then
                    models[#models + 1] = model
                    wanted[model.id] = model
                end
            end

            local bound = {}

            for _, card in ipairs(self.cards) do
                if card.token and card.model then
                    if wanted[card.model.id] or focused(card) or card.frame:GetParent() == self.ghost then
                        bound[card.model.id] = card
                    else
                        card:Release()
                        card.model = nil
                    end
                end
            end

            local free = 1

            for _, model in ipairs(models) do
                if not bound[model.id] then
                    while self.cards[free] and self.cards[free].token do
                        free = free + 1
                    end

                    local card = self.cards[free]

                    if not card then
                        card = addon:CreateRotationCard(self.child)
                        self.cards[free] = card
                    end

                    constructing = card
                    measured = self:BindCard(card, model) or measured
                    bound[model.id] = card
                    created = true
                    constructing = nil
                end
            end
        end)

        self.refreshing = nil

        if not ok then
            if constructing then
                constructing.token = nil
                pcall(constructing.Release, constructing)
                constructing.model = nil
            end

            error(problem, 0)
        end

        if measured then
            if self.drag then
                self.deferredMeasure = true
            else
                self:Reflow()
            end
        elseif created then
            owner:UpdateHistory()
        end
    end

    -- Redraws everything: invalidates every card handler (new generation), releases all cards and reflows the scene.
    function canvas:Render()
        self:CancelDrag()
        self.generation = self.generation + 1

        for _, card in ipairs(self.cards) do
            card:Release()
            card.model = nil
        end

        if not owner.active then
            return
        end

        self.scene = owner:BuildScene()

        if not self.scene then
            return
        end

        self.renderedWidth = self.frame:GetWidth()
        self:Reflow()
    end

    -- Closes the canvas: saves the viewport, cancels gestures, releases cards and hides the frames.
    function canvas:Release()
        self:RememberViewport()
        self:CancelDrag()
        self.generation = self.generation + 1

        for _, card in ipairs(self.cards) do
            card:Release()
        end

        self.horizontal:Hide()
        self.frame:Hide()
    end

    for _, bar in ipairs({ canvas.horizontal, canvas.frame.workbenchBar }) do
        bar:HookScript('OnValueChanged', function()
            if canvas.reflowing then
                return
            end

            if addon.Diagnostics then
                addon.Diagnostics:Call({
                    module = 'ui',
                    operation = 'rotationViewport',
                }, canvas.RefreshVisibleCards, canvas)
            else
                canvas:RefreshVisibleCards()
            end
        end)
    end

    return canvas
end
