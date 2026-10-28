-- Detached-draft transaction for the settings workbench pages: while a page declares `transactionKeys`, edits go to a
-- deep copy of the affected saved-variable keys and reach `addon.db` only when Apply passes validation; Cancel discards
-- them. Owns the draft, its baseline (to detect dirtiness and a concurrent change) and the queued runtime effects. It
-- must not write `addon.db` before Apply, and Apply must refuse in combat. The methods are installed on each settings
-- form by `addon:InstallSettingsDraft` (called from UI/settings_form.lua, which loads after this file); the key lists
-- per tab are set in UI/settings_collections.lua. The saved-data shape is untouched: the copies have the same tables as
-- `addon.db`.
local addon_name, addon = ...
local invalidateDependencies = addon.InvalidateRotationDependencies

if type(invalidateDependencies) ~= 'function' then
    invalidateDependencies = nil
end

local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Compares two values by deep structure for plain saved-data tables (no metatables, no cycles); used to compare a draft
-- with its baseline.
-- @param a any  The first value.
-- @param b any  The second value.
-- @return boolean  True when both have the same type and contents.
local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

-- Compares two saved-data values by deep structure; the public wrapper over the comparison, for code outside this file.
-- @param a any  The first value.
-- @param b any  The second value.
-- @return boolean  True when both have the same type and contents.
function addon:SettingsDataEqual(a, b)
    return equal(a, b)
end

-- Deep-copies saved data. Shared and cyclic references survive; scalar values are returned as is.
-- @param value any  The value to copy.
-- @param seen table|nil  Maps source tables to their copies; leave nil on the first call.
-- @return any  The copy.
function addon:CopySettingsData(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, child in pairs(value) do
        copy[key] = self:CopySettingsData(child, seen)
    end

    return copy
end

-- ============================================================================
-- Draft methods on the settings form
-- ============================================================================

-- Adds the draft methods below to a settings form. A form whose `transactionKeys` is nil (no transaction) reads and
-- writes `addon.db` directly and these methods become pass-throughs.
-- @param p table  The settings form pane.
function addon:InstallSettingsDraft(p)
    -- Tells whether an empty collection may open its creation form by itself: it was not dismissed and the baseline
    -- holds no entries for the scope and key.
    -- @param scope string  'profile', 'global' or 'char'.
    -- @param key string  The saved-variable key of the collection.
    -- @return boolean  True when the creation form may open automatically.
    function p:CanAutoCreateCollection(scope, key)
        return not self.emptyDismissed
            and not (self.draftBaseline and self.draftBaseline[scope] and next(self.draftBaseline[scope][key] or {}))
    end

    -- Snapshots the creation-form fields so a later comparison can tell whether the user typed anything.
    -- @return table  The current creation-form fields.
    function p:CreationState()
        return {
            effect = self.newEffect,
            announcement = self.newAnnounce,
            profileName = self.newProfileName,
            profileSource = self.profileSource,
            importProfile = self.importProfile,
            itemSetName = self.newItemSetName,
            categoryName = self.newGroupName,
        }
    end

    -- Tells whether the creation form was used for a new entry and differs from its baseline, or any open text edit is
    -- dirty.
    -- @return boolean  True when there is unsaved creation input.
    function p:IsCreationDirty()
        if not self.creationUsedForNew then
            return false
        end

        for _, record in ipairs(self.edits) do
            if record.dirty then
                return true
            end
        end

        return not equal(self:CreationState(), self.creationBaseline or {})
    end

    -- Drops the draft, its baseline, queued effects and every creation field without touching `addon.db`. Marks the
    -- empty state as dismissed so the page does not reopen the creation form on the next draw.
    function p:DiscardSettingsDraft()
        if self.ClearSettingsHistory then
            self:ClearSettingsHistory()
        end

        self.draft = nil
        self.draftBaseline = nil
        self.draftEffects = nil
        self.newEffect = nil
        self.newAnnounce = nil
        self.newProfileName = nil
        self.importProfile = nil
        self.profileSource = nil
        self.newItemSetName = nil
        self.newGroupName = nil
        self.creating = false
        self.creatingCategory = false
        self.creationBaseline = nil
        self.creationApply = nil
        self.emptyDismissed = true
    end

    -- Runs the pending creation action after flushing text edits. When the form was opened for a new entry it stops
    -- right after the action, without saving or redrawing; otherwise it saves the draft and redraws the page.
    -- @return boolean  True when the creation was saved and the page redrawn; false when nothing ran, the form was for
    --   a new entry, or the save failed.
    function p:ApplyCreation()
        if not self:FlushEdits() or not self.creationApply then
            return false
        end

        local apply = self.creationApply
        apply()

        if self.creationUsedForNew then
            return false
        end
        if self.transactionKeys and not self:SaveSettingsDraft() then
            return false
        end

        self.creationBaseline = nil
        self:Draw()
        return true
    end

    -- Returns the table the page should read and write: `addon.db` for pages without a transaction, otherwise the
    -- draft, created lazily as a copy of the profile, global and char scopes with a baseline of the declared keys.
    -- @return table  The settings data table.
    function p:SettingsData()
        if not self.transactionKeys then
            return addon.db
        end

        if not self.draft then
            self.draft = {
                profile = addon:CopySettingsData(addon.db.profile),
                global = addon:CopySettingsData(addon.db.global),
                char = addon:CopySettingsData(addon.db.char or {}),
            }

            self.draftBaseline = {}
            self.draftEffects = {}

            for scope, keys in pairs(self.transactionKeys) do
                self.draftBaseline[scope] = {}

                for _, key in ipairs(keys) do
                    self.draftBaseline[scope][key] = addon:CopySettingsData(addon.db[scope] and addon.db[scope][key])
                end
            end
        end

        return self.draft
    end

    -- Runs a runtime side effect now, or, inside a transaction, queues it to run after a successful Apply so Cancel
    -- leaves the runtime untouched.
    -- @param key string  The name the effect is queued under; the last one queued under a key wins.
    -- @param callback function  The effect, called with no arguments.
    function p:RunSettingsEffect(key, callback)
        if self.transactionKeys then
            self.draftEffects[key] = callback
        else
            callback()
        end
    end

    -- Tells whether a text edit is dirty or any declared key of the draft differs from its baseline.
    -- @return boolean  True when there is something to apply.
    function p:IsSettingsDraftDirty()
        if not self.draft then
            return false
        end

        for _, record in ipairs(self.edits) do
            if record.dirty then
                return true
            end
        end

        for scope, keys in pairs(self.transactionKeys) do
            for _, key in ipairs(keys) do
                if not equal(self.draft[scope][key], self.draftBaseline[scope][key]) then
                    return true
                end
            end
        end

        return false
    end

    -- Validates and applies the draft. Refuses, with a message, when saved data changed elsewhere since the baseline,
    -- effects or announcements are incomplete or duplicated, or the client is in combat. On success it copies the
    -- changed keys into `addon.db`, bumps the lean-engine dependency revision for item sets and effects, runs the
    -- queued effects and refreshes glows and buttons.
    -- @return boolean  True on success, or when there is nothing to save; false when it was refused.
    function p:SaveSettingsDraft()
        if not self.draft then
            return true
        end
        if not self:Valid(self.generation) then
            return false
        end

        for scope, keys in pairs(self.transactionKeys) do
            for _, key in ipairs(keys) do
                if not equal(addon.db[scope] and addon.db[scope][key], self.draftBaseline[scope][key]) then
                    self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.'])
                    return false
                end
            end
        end

        local ownsEffects = false

        for _, key in ipairs(self.transactionKeys.global or {}) do
            if key == 'effects' then
                ownsEffects = true
            end
        end

        if ownsEffects and self.draft.global.effects then
            local names = {}

            for id, effect in pairs(self.draft.global.effects) do
                if
                    not equal(effect, self.draftBaseline.global.effects and self.draftBaseline.global.effects[id])
                    and addon.IsValidEffectDefinition
                    and not addon:IsValidEffectDefinition(effect)
                then
                    self:Message(L['Complete the effect settings before applying.'])
                    return false
                end

                if effect.name and names[effect.name] then
                    self:Message(L['This name is already in use.'])
                    return false
                end

                if effect.name then
                    names[effect.name] = true
                end
            end
        end

        if self.transactionKeys.profile then
            for _, key in ipairs(self.transactionKeys.profile) do
                if key == 'announces' then
                    if not addon:AreMacroAnnouncementIdentifiersUnique(self.draft.profile.announces or {}) then
                        self:Message(L['Use a unique Via Script/Macro identifier.'])
                        return false
                    end

                    for index, entry in ipairs(self.draft.profile.announces or {}) do
                        if
                            not equal(entry, (self.draftBaseline.profile.announces or {})[index])
                            and not addon:IsValidAnnouncement(entry)
                        then
                            self:Message(L['Choose an action and complete the announcement before applying.'])
                            return false
                        end
                    end
                end
            end
        end

        if InCombatLockdown and InCombatLockdown() then
            self:Message(L['Leave combat before applying these settings.'])
            return false
        end

        for scope, keys in pairs(self.transactionKeys) do
            for _, key in ipairs(keys) do
                if not equal(self.draft[scope][key], self.draftBaseline[scope][key]) then
                    addon.db[scope][key] = addon:CopySettingsData(self.draft[scope][key])

                    if key == 'itemsets' and (scope == 'profile' or scope == 'global') then
                        if invalidateDependencies then
                            invalidateDependencies(addon, 'itemset', nil)
                        end
                    elseif key == 'effects' and scope == 'global' then
                        if invalidateDependencies then
                            invalidateDependencies(addon, 'effect', nil)
                        end
                    end
                end
            end
        end

        local effects = self.draftEffects

        if self.ClearSettingsHistory then
            self:ClearSettingsHistory()
        end

        self.draft = nil
        self.draftBaseline = nil
        self.draftEffects = nil

        for _, callback in pairs(effects) do
            callback()
        end

        if addon.RemoveAllCurrentGlows then
            addon:RemoveAllCurrentGlows()
        end
        if addon.ButtonFetch then
            addon:ButtonFetch()
        end

        return true
    end

    -- Shows the Apply and Cancel actions for a transactional page and enables Apply only while the draft is dirty.
    -- Skipped when a sub-form already owns the action row.
    function p:DraftActions()
        if not self.transactionKeys or self.creationUsed then
            return
        end

        self:CreationActions(
            function()
                if self:SaveSettingsDraft() then
                    self:Draw()
                end
            end,
            function()
                self:DiscardSettingsDraft()
                self:Draw()
            end,
            true
        )

        if self:IsSettingsDraftDirty() then
            self.fields.apply:Enable()
        else
            self.fields.apply:Disable()
        end

        self.creationUsedForNew = false
    end
end
