local _, addon = ...

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

function addon:CanResumeCustomConditionDialog(parent, owner)
    return owner and owner.active and parent.rmConditionOwner == owner and (not owner.valid or owner.valid())
end

function addon:CloseCustomConditionEditor(widget, expected)
    local owner = expected or widget.rmConditionOwner
    if not owner or not owner.active then return end
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
