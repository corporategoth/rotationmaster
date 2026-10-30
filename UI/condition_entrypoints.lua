-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Stable public entry points for the condition editor: addon.LayoutConditionFrame and addon:EditCondition.
-- Callers (Built In condition widgets in Conditions/, the rotation editor) use these names so they do not depend on
-- whether the native editor in UI/condition_editor.lua is present; each returns nil and a localized reason when it is
-- not. Owns no state and draws nothing. Loaded from the UI/ block of RotationMaster.toc.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Asks a condition editor frame to re-measure itself after its content changed.
-- @param frame table|nil  A condition editor frame (one with an rmCompactRefresh function).
-- @return any  What the frame's rmCompactRefresh returns; nil when the frame is not a native editor frame.
-- @return string|nil  The localized reason when the first value is nil.
--
-- Public condition entry points accept native editors and compact refresh hosts.
function addon.LayoutConditionFrame(frame)
    if frame and type(frame.rmCompactRefresh) == 'function' then
        return frame.rmCompactRefresh()
    end

    return nil, L['Unsupported condition editor frame.']
end

-- Opens the native condition editor for one condition.
-- @param index number|nil  The step number shown in the title; 0 or nil for a switch condition.
-- @param spec string  The class spec the condition belongs to.
-- @param value table  The current condition tree.
-- @param callback function  Called as callback(applied) when the edit ends.
-- @param targetValid function|nil  Returns true while the rotation or step being edited still exists.
-- @return table|nil  What addon:ShowConditionEditor returns (the editor shell); nil when the editor is not loaded.
-- @return string|nil  The reason when the first value is nil.
function addon:EditCondition(index, spec, value, callback, targetValid)
    if type(self.ShowConditionEditor) == 'function' then
        return self:ShowConditionEditor(index, spec, value, callback, targetValid)
    end

    return nil, L['The native condition editor is unavailable.']
end
