-- Lifetime owner for the custom condition editor dialog and the child dialogs opened from it (transfer, source pane,
-- function bundle). One owner record is shared by the whole tree: it says whether the editor is still live, and closing
-- or releasing the root hides every child and releases the root. Draws nothing and stores nothing; the dialogs and
-- their widgets come from UI/. Loaded from the Core group of RotationMaster.toc, and only called once a window is open.
local _, addon = ...

-- Registers a dialog widget with an owner, creating the owner when the widget is the root of a new tree.
-- @param widget table  The dialog widget to register.
-- @param parent table|nil  The parent dialog; nil, or a parent with no owner, makes the widget the root of a new owner.
-- @param valid function|nil  Reports whether the editor session is still current; only used when a new owner is made.
-- @return table  The owner record shared by the whole dialog tree.
--
-- Wraps the widget's OnRelease so releasing the root closes the whole tree, then restores the original handler.
function addon:OwnCustomConditionDialog(widget, parent, valid)
    local owner = parent and parent.rmConditionOwner or { active = true, valid = valid, root = widget, widgets = {} }

    if not owner then
        return
    end

    widget.rmConditionOwner = owner
    owner.widgets[widget] = true
    local release = widget.OnRelease

    -- OnRelease wrapper: releasing the root closes the whole dialog tree, then the original handler is restored and
    -- called.
    -- @param control table  The widget being released.
    -- @param ... any  Passed to the original OnRelease handler.
    -- @return any  The original handler's result, when there is one.
    widget.OnRelease = function(control, ...)
        if control == owner.root and owner.active then
            addon:CloseCustomConditionEditor(control, owner)
        end

        owner.widgets[control] = nil

        if control.rmConditionOwner == owner then
            control.rmConditionOwner = nil
        end

        control.OnRelease = release

        if release then
            return release(control, ...)
        end
    end

    return owner
end

-- Reports whether a child dialog may reopen its parent.
-- @param parent table  The parent dialog widget.
-- @param owner table|nil  The owner record the child was registered with.
-- @return boolean|nil  True when the owner is still active, still belongs to that parent and the session check, when
--   there is one, still passes; false or nil otherwise.
function addon:CanResumeCustomConditionDialog(parent, owner)
    return owner and owner.active and parent.rmConditionOwner == owner and (not owner.valid or owner.valid())
end

-- Closes an editor tree once: marks the owner inactive, hides every child, then hides and releases the root.
-- @param widget table  A dialog widget of the tree; its own owner is used when `expected` is nil.
-- @param expected table|nil  The owner record to close.
--
-- A second call, or a stale owner, does nothing.
function addon:CloseCustomConditionEditor(widget, expected)
    local owner = expected or widget.rmConditionOwner

    if not owner or not owner.active then
        return
    end

    -- Clearing active first makes the OnRelease wrapper above a no-op for the root, so Release() below cannot recurse.
    owner.active = false
    local widgets = {}

    for child in pairs(owner.widgets) do
        widgets[#widgets + 1] = child
    end

    for _, child in ipairs(widgets) do
        if child ~= owner.root and child.rmConditionOwner == owner then
            child:Hide()
        end
    end

    local root = owner.root

    if root.rmConditionOwner == owner then
        root:Hide()

        if root.rmConditionOwner == owner and not root.isQueuedForRelease and type(root.Release) == 'function' then
            root:Release()
        end
    end
end
