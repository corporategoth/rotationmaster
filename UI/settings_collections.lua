-- Shared helpers for the settings tabs that manage collections (Effects, Item Sets, Announces, Conditions, Functions)
-- and the entry point that opens any native settings tab. Owns the map from each tab to the saved-variable keys its
-- draft covers (`transactionKeys`, see UI/settings_draft.lua), the roster footer, the confirmed-deletion flow and
-- deletion of a saved custom condition. Tab builders live in the settings_*.lua files and are looked up by
-- `addon:OpenNativeSettings`; this file loads from RotationMaster.toc after UI/settings_form.lua. Writes go to
-- `addon.db` only through the draft or the explicit delete paths here, never while in combat.
local addon_name, addon = ...
local invalidateDependencies = addon.InvalidateRotationDependencies

if type(invalidateDependencies) ~= 'function' then
    invalidateDependencies = nil
end

local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Turns a collection keyed by id into a list of `{ value = id, text = name }` entries sorted by name (then id), for
-- rosters and selectors. Non-table values are skipped; an unnamed entry shows its id.
function addon:SettingsEntries(values)
    local entries = {}

    for id, value in pairs(values or {}) do
        if type(value) == 'table' then
            entries[#entries + 1] = { value = id, text = type(value.name) == 'string' and value.name or tostring(id) }
        end
    end

    table.sort(entries, function(a, b)
        if a.text == b.text then
            return tostring(a.value) < tostring(b.value)
        end

        return a.text < b.text
    end)

    return entries
end

-- Returns `text` when it holds a non-blank string, otherwise nil.
function addon:SettingsNonempty(text)
    if type(text) == 'string' and text:find('%S') then
        return text
    end
end

-- Parses a positive whole number from user text, or returns nil.
function addon:SettingsPositiveID(text)
    local n = tonumber(text)

    if n and n > 0 and n == math.floor(n) then
        return n
    end
end

-- Makes `value` present exactly once (enabled) or absent (disabled) in an array, in place.
function addon:SettingsFlag(list, value, enabled)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end

    if enabled then
        list[#list + 1] = value
    end
end

-- True when the array holds `value`; a nil list counts as empty.
function addon:SettingsContains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end

    return false
end

-- Adds the Move to Top/Up/Down/Bottom/Delete action row for entry `i` of the ordered array `list`. Each action edits
-- the array in place, calls `changed()` so the caller can mark the draft, and redraws the page `p`.
function addon:SettingsOrderControls(p, prefix, list, i, changed)
    -- Moves entry `i` to position `destination`, tells the caller the list changed and redraws.
    local function move(destination)
        local value = table.remove(list, i)
        table.insert(list, destination, value)
        changed()
        p:Draw()
    end

    p:Actions({
        {
            key = prefix .. 'top',
            text = L['Move to Top'],
            icon = 'chevron-double-down',
            enabled = i > 1,
            action = function()
                move(1)
            end,
        },
        {
            key = prefix .. 'up',
            text = L['Move Up'],
            icon = 'up',
            enabled = i > 1,
            action = function()
                move(i - 1)
            end,
        },
        {
            key = prefix .. 'down',
            text = L['Move Down'],
            icon = 'down',
            enabled = i < #list,
            action = function()
                move(i + 1)
            end,
        },
        {
            key = prefix .. 'bottom',
            text = L['Move to Bottom'],
            icon = 'chevron-double-down',
            enabled = i < #list,
            action = function()
                move(#list)
            end,
        },
        {
            key = prefix .. 'remove',
            text = L['Delete'],
            icon = 'trash',
            action = function()
                table.remove(list, i)
                changed()
                p:Draw()
            end,
        },
    })
end

-- Opens (or reuses, via `cached`) the settings form for tab `key` inside `parent`, declares which saved keys its draft
-- covers and builds the page. Returns the form, or nil for an unknown tab. The key lists below are the transaction
-- boundary: Apply compares and copies back only the keys named for the tab, so a key a page edits must be listed.
function addon:OpenNativeSettings(parent, key, cached)
    local builders = {
        General = self.BuildGeneralSettings,
        Profiles = self.BuildProfileSettings,
        About = self.BuildAboutSettings,
        Announces = self.BuildAnnounceSettings,
        Effects = self.BuildEffectSettings,
        ItemSets = self.BuildItemSettings,
        Conditions = self.BuildConditionSettings,
        Functions = self.BuildFunctionSettings,
        Integrations = self.BuildIntegrationSettings,
    }

    local build = builders[key]

    if not build then
        return
    end

    local p = cached or self:CreateSettingsForm(parent)

    local scopes = {
        Integrations = {
            profile = {
                'lua_editor',
                'lua_editor_disabled',
                'lua_native_highlighting',
                'lua_line_numbers',
                'questie_enabled',
                'encounter_provider',
                'preview_masque',
            },
        },
        Effects = { global = { 'effects' } },
        ItemSets = { profile = { 'itemsets' }, global = { 'itemsets' } },
        Announces = { profile = { 'announces' } },
        Conditions = {
            profile = {
                'condition_groups',
                'switch_conditions',
                'announcement_conditions',
                'other_conditions_order',
                'disabled_conditions',
            },
            global = { 'custom_conditions' },
        },
        General = {
            profile = {
                'enable', 'poll', 'idle_poll', 'autoswitch_poll', 'ignore_mana', 'ignore_range', 'effect', 'color',
                'magnification', 'setpoint', 'xoffs', 'yoffs', 'loglevel', 'detailed_profiling', 'disable_autoswitch',
                'live_config_update', 'spell_history', 'combat_history', 'damage_history', 'disable_buttons',
                'assisted_highlight', 'tooltips', 'tooltip_itemsets', 'tooltip_rotations', 'tooltip_conditions',
                'tooltip_limit', 'rotation_view', 'preview_spells', 'preview_vertical', 'preview_locked',
                'preview_opacity', 'preview_icon_size', 'preview_window', 'minimap'
            },
            char = { 'specs' },
        },
    }

    scopes.Functions = { global = { 'custom_functions' } }
    p.settingsKey = key
    p.historyEnabled = key == 'ItemSets'
    p.transactionKeys = scopes[key]
    p:SetWidth(parent:GetWidth())
    p:SetHeight(parent:GetHeight())

    p:Open(function(form)
        build(self, form)
    end)

    return p
end

-- Fills the roster footer with New, the caller's Duplicate and Import/Export actions, and a Compare chooser listing
-- every other entry of `values`. `compare(a, b)` overrides the default comparison window for `kind`.
function addon:CollectionFooter(p, kind, values, current, duplicate, transfer, compare)
    local candidates = {}

    for _, entry in ipairs(self:SettingsEntries(values)) do
        if entry.value ~= current then
            candidates[#candidates + 1] = entry
        end
    end

    p:SetRosterActions({
        { key = 'new_collection', text = L['New'], icon = 'plus', action = p.roster.options.new },
        duplicate,
        transfer,
        {
            key = 'compare',
            text = L['Compare'],
            icon = 'compare',
            enabled = values[current] ~= nil and #candidates > 0,
            action = function()
                p:ShowChoices(p.fields.compare, candidates, function(id)
                    p.fields.compare:SetText(L['Compare'])

                    if id ~= current and values[id] and values[current] then
                        if compare then
                            compare(values[current], values[id])
                        else
                            self:ShowCollectionComparison(p, kind, values[current], values[id])
                        end
                    end
                end)
            end,
        },
    })
end

-- Places the red Delete icon at the top right of the detail pane; `action` runs guarded so it is ignored once the page
-- is stale. Returns the button.
function addon:SettingsTopDelete(p, action)
    local c = p:Acquire('rootDelete', function()
        return self:CreateWorkbenchIconButton(p.child, 'trash', L['Delete'])
    end)

    c:ClearAllPoints()
    c:SetPoint('TOPRIGHT', 0, -4)
    c.icon:SetVertexColor(1, .25, .25, 1)
    c:Enable()
    p.fields.delete = c
    self:SetUIScript(c, 'OnClick', p:Guard(action))
    return c
end

-- Deletion is a separate confirmed operation. Resolve existing edits first,
-- then rebuild and read saved data so Apply/Discard cannot leave stale drafts.
function addon:ConfirmSettingsDeletion(p, warning, remove)
    local profile, global, char = self.db.profile, self.db.global, self.db.char

    p:RequestLeave(function()
        if not p.active or self.db.profile ~= profile or self.db.global ~= global or self.db.char ~= char then
            return
        end

        p:DiscardSettingsDraft()
        p:Draw()
        local expected = {}

        for scope, keys in pairs(p.transactionKeys or {}) do
            expected[scope] = {}

            for _, key in ipairs(keys) do
                expected[scope][key] = self:CopySettingsData(self.db[scope] and self.db[scope][key])
            end
        end

        local conditionRevision, functionRevision = self.conditionRegistryVersion, self.functionRegistryVersion

        p:Confirm(warning .. ' ' .. L['This cannot be undone.'], function()
            if InCombatLockdown and InCombatLockdown() then
                p:Message(L['Leave combat before applying these settings.'])
                return
            end

            for scope, keys in pairs(p.transactionKeys or {}) do
                for _, key in ipairs(keys) do
                    if not self:SettingsDataEqual(self.db[scope] and self.db[scope][key], expected[scope][key]) then
                        p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.'])
                        return
                    end
                end
            end

            if
                self.conditionRegistryVersion ~= conditionRevision or self.functionRegistryVersion ~= functionRevision
            then
                p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.'])
                return
            end

            local called, ok, why = pcall(remove)

            if not called or not ok then
                p:Message(tostring(called and why or ok))
                return
            end

            p:DiscardSettingsDraft()
            p.emptyDismissed = true
            p:Draw()

            if self.RemoveAllCurrentGlows then
                self:RemoveAllCurrentGlows()
            end
            if self.ButtonFetch then
                self:ButtonFetch()
            end
        end)
    end)
end

-- Unregisters a custom condition and removes its saved source. Returns true, or false and a reason. If unregistering
-- fails the saved source and the previous registered definition are kept (and dependents invalidated when the registry
-- entry had changed), so a failed cleanup hook cannot leave a runtime without its source.
function addon:DeleteSavedCustomCondition(key)
    local source = (self.db.global.custom_conditions or {})[key]

    if not source then
        return false, 'definition-changed'
    end

    -- Unregister can run trusted cleanup hooks. A failure must retain its saved
    -- source and registered definition, rather than leaving an orphaned runtime.
    local definition = self.conditionDefinitions and self.conditionDefinitions[key]
    local ok, why = pcall(self.UnregisterCondition, self, key)

    if not ok then
        if self.conditionDefinitions then
            local changed = not rawequal(self.conditionDefinitions[key], definition)
            self.conditionDefinitions[key] = definition

            if changed and invalidateDependencies then
                invalidateDependencies(addon, 'condition', key)
            end
        end

        return false, why
    end

    self.db.global.custom_conditions[key] = nil

    if self.RefreshConditionConsumers then
        self:RefreshConditionConsumers()
    end

    return true
end
