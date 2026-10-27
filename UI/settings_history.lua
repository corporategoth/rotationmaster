-- Undo and redo for the draft-based settings form (item sets and effects): snapshots the draft before and after each
-- wrapped edit, keeps bounded undo/redo stacks (100 entries or 8 MiB) and draws the Undo/Redo buttons. Edits reach it
-- through p:WithSettingsHistory, called from the form's Guard (UI/settings_form.lua). Works on the draft only, never on
-- saved data; nothing is written until the form saves. Loaded from RotationMaster.toc after UI/settings_draft.lua;
-- settings_form.lua calls addon:InstallSettingsHistory(p) to add these methods to the form class.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Deep structural equality of two plain data values (no metatables, no cycles); decides whether an edit changed
-- anything.
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end

    for key, value in pairs(a) do
        if not equal(value, b[key]) then return false end
    end

    for key in pairs(b) do
        if a[key] == nil then return false end
    end

    return true
end

-- Rough byte cost of a value (strings by length, tables recursively), used only to cap the undo stack's memory.
local function size(value)
    if type(value) == 'string' then return #value + 32 end
    if type(value) ~= 'table' then return 16 end
    local n = 64

    for key, child in pairs(value) do
        n = n + size(key) + size(child)
    end

    return n
end

-- Adds the history methods to the settings form class `p`; called once when the form class is built.
function addon:InstallSettingsHistory(p)
    -- Drops both stacks and bumps the epoch, so an edit still in flight is not recorded against the old draft.
    function p:ClearSettingsHistory()
        self.historyEpoch = (self.historyEpoch or 0) + 1
        self.historyUndo = {}
        self.historyRedo = {}
        self.historyBytes = 0
    end

    -- Returns a deep copy of the undoable state (item-set drafts, effects, selection), or nil when history is off.
    function p:HistorySnapshot()
        if not self.historyEnabled or not self.draft then return end

        return addon:CopySettingsData({
            profile = self.draft.profile.itemsets,
            global = self.draft.global.itemsets,
            effects = self.draftEffects,
            selection = self.selection,
        })
    end

    -- Enables each button only while its stack has an entry.
    function p:UpdateHistoryActions()
        if self.fields.undo then
            if #(self.historyUndo or {}) > 0 then
                self.fields.undo:Enable()
            else
                self.fields.undo:Disable()
            end
        end

        if self.fields.redo then
            if #(self.historyRedo or {}) > 0 then
                self.fields.redo:Enable()
            else
                self.fields.redo:Disable()
            end
        end
    end

    -- Runs `callback(...)` and records a pre-edit snapshot when it changed the draft; returns the callback's result.
    -- Nested calls run unrecorded (one user action is one undo step), and an epoch change during the call (draft
    -- replaced or cleared) discards the snapshot instead of recording it. Errors are rethrown after the depth flag
    -- clears.
    function p:WithSettingsHistory(callback, ...)
        if not self.historyEnabled or self.historyDepth then return callback(...) end
        local before = self:HistorySnapshot()
        local epoch = self.historyEpoch
        self.historyDepth = true
        local ok, result = pcall(callback, ...)
        self.historyDepth = nil
        if not ok then error(result, 0) end
        local after = self:HistorySnapshot()

        if before and after and epoch == self.historyEpoch and not equal(before, after) then
            self.historyUndo = self.historyUndo or {}
            self.historyRedo = {}
            self.historyUndo[#self.historyUndo + 1] = before
            local bytes = 0

            for _, entry in ipairs(self.historyUndo) do
                bytes = bytes + size(entry)
            end

            while #self.historyUndo > 100 or bytes > 8388608 do
                bytes = bytes - size(table.remove(self.historyUndo, 1))
            end

            self.historyBytes = bytes
        end

        self:UpdateHistoryActions()
        return result
    end

    -- Moves one step back (or forward when `redo`): pushes the current state on the opposite stack, restores the
    -- popped snapshot into the draft and redraws. Pending field edits are flushed first; does nothing if that fails.
    function p:TravelSettingsHistory(redo)
        if not self:FlushEdits() then return end
        local from = redo and self.historyRedo or self.historyUndo
        local to = redo and self.historyUndo or self.historyRedo
        if not from or #from == 0 then return end
        to[#to + 1] = self:HistorySnapshot()
        local value = table.remove(from)
        self.draft.profile.itemsets = addon:CopySettingsData(value.profile)
        self.draft.global.itemsets = addon:CopySettingsData(value.global)
        self.draftEffects = addon:CopySettingsData(value.effects)
        self.selection = value.selection
        self.historyEpoch = (self.historyEpoch or 0) + 1
        self:Draw()
    end

    -- Lays out the Undo and Redo buttons on a new row of the form.
    function p:HistoryActions()
        local y = self:Row(nil, 28)

        for i, entry in ipairs({ { 'undo', 'undo', L['Undo'] }, { 'redo', 'redo', L['Redo'] } }) do
            local button = self:Acquire('historyActions', function()
                return addon:CreateWorkbenchHistoryButton(self.child, entry[2], entry[3])
            end)

            button:ClearAllPoints()
            button:SetPoint('TOPLEFT', (i - 1) * 74, -y)
            button:SetWidth(68)
            button:SetText(entry[3])
            button.icon:SetTexture(addon:ControlTexture(entry[2]))
            self.fields[entry[1]] = button

            addon:SetUIScript(
                button,
                'OnClick',
                self:Guard(function() self:TravelSettingsHistory(entry[1] == 'redo') end)
            )
        end

        self:UpdateHistoryActions()
    end
end
