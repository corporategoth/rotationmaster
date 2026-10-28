-- Stable public entry points for the condition editor: addon.LayoutConditionFrame and addon:EditCondition.
-- Callers (Built In condition widgets in Conditions/, the rotation editor) use these names so they do not depend on
-- whether the native editor in UI/condition_editor.lua is present; each returns nil and a localized reason when it is
-- not. Owns no state and draws nothing. Loaded from the UI/ block of RotationMaster.toc.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Public condition entry points accept native editors and compact refresh hosts.
-- Asks a condition editor frame to re-measure itself after its content changed. Returns what the frame's
-- rmCompactRefresh returns, or nil and a reason when the frame is not a native editor frame.
function addon.LayoutConditionFrame(frame)
    if frame and type(frame.rmCompactRefresh) == 'function' then
        return frame.rmCompactRefresh()
    end

    return nil, L['Unsupported condition editor frame.']
end

-- Opens the native condition editor for one condition (index, spec, current value, save callback, target validity).
-- Returns what addon:ShowConditionEditor returns, or nil and a reason when the editor is not loaded.
function addon:EditCondition(index, spec, value, callback, targetValid)
    if type(self.ShowConditionEditor) == 'function' then
        return self:ShowConditionEditor(index, spec, value, callback, targetValid)
    end

    return nil, L['The native condition editor is unavailable.']
end
