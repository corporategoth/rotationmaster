-- Lifetime owner for the custom condition editor dialog and the child dialogs opened from it (transfer, source pane,
-- function bundle). One owner record is shared by the whole tree: it says whether the editor is still live, and closing
-- or releasing the root hides every child and releases the root. Draws nothing and stores nothing; the dialogs and
-- their widgets come from UI/. Loaded from the Core group of RotationMaster.toc, and only called once a window is open.
local _, addon = ...

-- Registers a dialog widget with an owner and returns the owner. With no parent, or a parent that has no owner, the
-- widget becomes the root of a new owner; `valid` (optional) reports whether the editor session is still current.
-- Wraps the widget's OnRelease so releasing the root closes the whole tree, then restores the original handler.
function addon:OwnCustomConditionDialog(widget, parent, valid)
    local owner = parent and parent.rmConditionOwner or { active = true, valid = valid, root = widget, widgets = {} }
    if not owner then return end
    widget.rmConditionOwner = owner
    owner.widgets[widget] = true
    local release = widget.OnRelease

    widget.OnRelease = function(control, ...)
        if control == owner.root and owner.active then addon:CloseCustomConditionEditor(control, owner) end
        owner.widgets[control] = nil
        if control.rmConditionOwner == owner then control.rmConditionOwner = nil end
        control.OnRelease = release
        if release then return release(control, ...) end
    end

    return owner
end

-- True when a child dialog may reopen its parent: the owner is still active, still belongs to that parent and the
-- session check, when there is one, still passes.
function addon:CanResumeCustomConditionDialog(parent, owner)
    return owner and owner.active and parent.rmConditionOwner == owner and (not owner.valid or owner.valid())
end

-- Closes an editor tree once: marks the owner inactive, hides every child, then hides and releases the root. `expected`
-- names the owner to close; without it the widget's own owner is used. A second call, or a stale owner, does nothing.
function addon:CloseCustomConditionEditor(widget, expected)
    local owner = expected or widget.rmConditionOwner
    if not owner or not owner.active then return end
    -- Clearing active first makes the OnRelease wrapper above a no-op for the root, so Release() below cannot recurse.
    owner.active = false
    local widgets = {}

    for child in pairs(owner.widgets) do
        widgets[#widgets + 1] = child
    end

    for _, child in ipairs(widgets) do
        if child ~= owner.root and child.rmConditionOwner == owner then child:Hide() end
    end

    local root = owner.root

    if root.rmConditionOwner == owner then
        root:Hide()

        if root.rmConditionOwner == owner and not root.isQueuedForRelease and type(root.Release) == 'function' then
            root:Release()
        end
    end
end
