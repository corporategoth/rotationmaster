local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

-- Register this condition as existing.
-- Params:
--    category - The group this condition belongs to.  May be nil.
--    name - The unique name of this condition (used by the addon, not seen by the user).
addon:RegisterCondition("MYCONDITON", {
    -- The description should be brief, it is used both in the on-hover display when
    -- selecting a condition, and as the 'title' of the bounding box for the condition.
    description = L["My Condition"],
    -- The icon can be an ID number or asset name (eg. "Interface\\Icons\\foo-bar")
    icon = 12345,
    -- Call this when the condition is registered (could initialize some data or something).
    -- Params:
    --    tag - The tag (aka. type) this condition is registered as
    on_register = function(tag)
    end,
    -- Call this when the condition is unregistered (could destroy some data or something).
    -- Params:
    --    tag - The tag (aka. type) this condition was registered as
    on_unregister = function(tag)
    end,
    -- Validate that the condition has all required values set and they are in
    -- acceptable bounds.  This does not indicate if the condition is true or not.
    -- Params:
    --    spec - The talent specialization in use (as a number).
    --    value - The storage for this condition (ie. where it's parameters are stored).
    -- Return: true if the condition is valid
    valid = function(spec, value)
        return true
    end,
    -- Evaluate the condition at runtime, and let us know if the current situation
    -- makes this condition pass.
    -- Params:
    --    value - The storage for this condition (ie. where it's parameters are stored).
    --    cache - A cache for this evaluation run (it is reset every evaluation cycle).
    --            You can also use addon.combatCache (only reset when going out of combat)
    --            or addon.longtermCache (only reset when your skills are updated).
    --    evalStart - The timestamp (GetTime()) of when this evaluation cycle started.
    -- Return: true if the condition passes
    evaluate = function(value, cache, evalStart)
        return true
    end,
    -- Create a printable string that describes this condition in words.
    -- Params:
    --    spec - The talent specialization in use (as a number).
    --    value - The storage for this condition (ie. where it's parameters are stored).
    -- Return: A string that describes this condition
    print = function(spec, value)
        return ""
    end,
    -- Create the widgets required to configure this condition.
    -- Params:
    --    parent - A bounding box that will contain this condition's widgets.
    --    spec - The talent specialization in use (as a number).
    --    value - The storage for this condition (ie. where it's parameters are stored).
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
    end,
    -- Create the required help information for this condition
    -- Params:
    --    frame - The frame the help widgets will be layed out in.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})
