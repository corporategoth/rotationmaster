local _, addon = ...

local function find(list, id)
    for _, value in ipairs(list or {}) do
        if value.id == id then return value end
    end
end

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end

    return false
end

local function context(p, store, id)
    store = store or {}
    local profile, global = store.profile or {}, store.global or {}

    id = id
        or (p.mode == 'categories' and p.categorySelection
            or p.settingsKey == 'Conditions' and p.condition
            or p.selection)

    -- General reads single keys: a view over the profile, not a deep copy of
    -- it (every rotation included) for each bound control on every draw.
    if p.settingsKey == 'General' then
        local result = { minimap = not (profile.minimap or {}).hide }

        for i, v in ipairs((store.char or {}).specs or {}) do
            result['spec' .. i] = v
        end

        return setmetatable(result, { __index = profile })
    end

    if p.settingsKey == 'Integrations' then return profile end
    if p.settingsKey == 'Effects' then return (global.effects or {})[id] end

    if p.settingsKey == 'ItemSets' then
        local entry = (profile.itemsets or {})[id] or (global.itemsets or {})[id]

        if entry then
            local copy = addon:CopySettingsData(entry)
            copy.global = (global.itemsets or {})[id] ~= nil
            return copy
        end
    end

    if p.settingsKey == 'Announces' then
        local current = (p.draft and p.draft.profile.announces or addon.db.profile.announces or {})[id]
        return current and current.id and find(profile.announces, current.id) or (profile.announces or {})[id]
    end

    if p.settingsKey == 'Conditions' then
        if p.mode == 'categories' then
            local group = find(profile.condition_groups, id or p.categorySelection)
            return group and { group_name = group.name, category_icon = group.icon, conditions = group.conditions }
        end

        local tag = id or p.condition
        local category = 'DEFAULT'

        for _, group in ipairs(profile.condition_groups or {}) do
            if contains(group.conditions, tag) then category = group.id end
        end

        return {
            hidden = contains(profile.disabled_conditions, tag),
            switch = contains(profile.switch_conditions, tag),
            move_to = category,
            custom = (global.custom_conditions or {})[tag],
        }
    end
end

-- Build membership/order lookups once when draft markers change. Viewport
-- binding reads these retained maps without rescanning the complete roster.
local function rosterLookup(p, store)
    store = store or {}
    local profile = store.profile or {}

    local result = {
        profile = profile,
        global = store.global or {},
        groups = {},
        categories = {},
        hidden = {},
        switch = {},
        positions = {},
        announces = {},
    }

    for _, tag in ipairs(profile.disabled_conditions or {}) do
        result.hidden[tag] = true
    end

    for _, tag in ipairs(profile.switch_conditions or {}) do
        result.switch[tag] = true
    end

    for _, group in ipairs(profile.condition_groups or {}) do
        result.groups[group.id] = group

        for _, tag in ipairs(group.conditions or {}) do
            result.categories[tag] = group.id
        end
    end

    for _, entry in ipairs(profile.announces or {}) do
        if entry.id then result.announces[entry.id] = entry end
    end

    local ordered

    if p.mode == 'categories' then
        ordered = profile.condition_groups
    elseif p.category == 'SWITCH' then
        ordered = profile.switch_conditions
    elseif p.category == 'DEFAULT' then
        ordered = profile.other_conditions_order
    else
        local group = result.groups[p.category]
        ordered = group and group.conditions
    end

    for index, entry in ipairs(ordered or {}) do
        local id = type(entry) == 'table' and entry.id or entry
        if result.positions[id] == nil then result.positions[id] = index end
    end

    return result
end

local function rosterContext(p, store, id, lookup, currentAnnounces)
    if p.settingsKey == 'Conditions' then
        if p.mode == 'categories' then
            local group = lookup.groups[id]
            return group and { group_name = group.name, category_icon = group.icon, conditions = group.conditions }
        end

        return {
            hidden = lookup.hidden[id] == true,
            switch = lookup.switch[id] == true,
            move_to = lookup.categories[id] or 'DEFAULT',
            custom = (lookup.global.custom_conditions or {})[id],
        }
    end

    if p.settingsKey == 'Announces' then
        local entry = currentAnnounces[id]
        return entry and entry.id and lookup.announces[entry.id] or (lookup.profile.announces or {})[id]
    end

    return context(p, store, id)
end

local function field(object, key)
    if type(object) ~= 'table' then return nil end
    key = key:gsub('^entry%d+', ''):gsub('^new_', '')
    local n, property = key:match('^seq(%d+)(.*)$')

    if n then
        local entry = (object.sequence or {})[tonumber(n)]
        if property == '' then return entry end
        property = property == 'mag' and 'magnification' or property
        return type(entry) == 'table' and entry[property]
    end

    n = key:match('^item(%d+)$')
    if n then return (object.items or {})[tonumber(n)] end
    if key:match('^enabled%d+$') then return not object.disabled end
    if key == 'definition_enabled' then return not (object.custom or {}).disabled end
    if key == 'action' then return object.spell or object.item end
    return object[key]
end

-- Every native form uses the same saved baseline, including entries first
-- opened after an import. Pending text is compared before it is committed.
function addon:InstallSettingsUnsaved(p)
    p.unsavedDefaults = {}
    p.unsavedBindings = {}

    function p:UnsavedIdentity()
        return table.concat({
            self.settingsKey or '',
            self.mode or '',
            tostring(
                self.mode == 'categories' and self.categorySelection
                    or self.settingsKey == 'Conditions' and self.condition
                    or self.selection
                    or 'general'
            ),
            self.creating and 'new' or '',
        }, ':')
    end

    function p:BindUnsaved(key, control, value, kind)
        local identity = self:UnsavedIdentity()
        local defaults = self.unsavedDefaults[identity] or {}
        self.unsavedDefaults[identity] = defaults

        local before = context(
            self,
            self.draftBaseline,
            self.mode == 'categories' and self.categorySelection
                or self.settingsKey == 'Conditions' and self.condition
                or nil
        )

        local current = context(
            self,
            self.draft,
            self.mode == 'categories' and self.categorySelection
                or self.settingsKey == 'Conditions' and self.condition
                or nil
        )

        local baseline = field(before, key)
        local missing = false

        if baseline == nil then
            local collection = self.settingsKey == 'Effects'
                or self.settingsKey == 'ItemSets'
                or self.settingsKey == 'Announces'
                or self.settingsKey == 'Conditions' and self.mode == 'categories'

            if collection and before == nil and current ~= nil or field(current, key) ~= nil and not defaults[key] then
                missing = true
            else
                if not defaults[key] then defaults[key] = { value = addon:CopySettingsData(value) } end
                baseline = defaults[key].value
            end
        end

        if kind == 'Check' or kind == 'Toggle' then
            baseline = baseline == true
            value = value == true
        end

        self.unsavedBindings[key] = {
            control = control,
            value = addon:CopySettingsData(value),
            baseline = addon:CopySettingsData(baseline),
            kind = kind,
            missing = missing,
        }

        return self.unsavedBindings[key]
    end

    function p:RosterEntryUnsaved(entry)
        local r = self.roster
        local state = r and r.unsavedState
        if not state then return false end
        local cached = r.unsavedByValue[entry.value]
        if cached ~= nil then return cached end
        local id = entry.value
        local moved = self.settingsKey == 'Conditions' and state.before.positions[id] ~= state.current.positions[id]
        local before = rosterContext(self, self.draftBaseline, id, state.before, state.announces)
        local current = rosterContext(self, self.draft, id, state.current, state.announces)
        local changed = moved or id == state.selected and state.pending or not addon:UnsavedDataEqual(before, current)
        r.unsavedByValue[id] = changed == true
        return changed == true
    end

    function p:RefreshRosterMarkers()
        if not self.roster then return end

        for _, row in ipairs(self.roster.rows) do
            if row.rosterLease then addon:SetWorkbenchUnsaved(row, self:RosterEntryUnsaved(row.rosterEntry)) end
        end
    end

    function p:RefreshUnsaved()
        if not self.active then return end
        local changedRows = {}
        local pending = false

        for key, binding in pairs(self.unsavedBindings) do
            local value = binding.value
            local dirty = binding.missing

            if binding.kind == 'Color' then
                value = addon:CopySettingsData(type(value) == 'table' and value or { r = 1, g = 1, b = 1, a = 1 })
                local channels = type(binding.baseline) == 'table' and binding.baseline or {}

                for _, channel in ipairs({ 'r', 'g', 'b', 'a' }) do
                    local input = self.fields[key .. '_' .. channel]
                    local changed = false

                    for _, record in ipairs(self.edits) do
                        if record.control == input and record.dirty then
                            local number = record.parse(input:GetText())
                            changed = number == nil or number ~= channels[channel]

                            if number then
                                value[channel] = number
                            else
                                dirty = true
                            end
                        end
                    end

                    addon:SetWorkbenchUnsaved(input, changed or value[channel] ~= channels[channel])
                end
            end

            for _, record in ipairs(self.edits) do
                if record.control == binding.control or self.fields[key .. '_value'] == record.control then
                    if record.dirty then
                        value = record.parse(record.control:GetText())
                        dirty = dirty or value == nil
                    end

                    addon:SetWorkbenchUnsaved(
                        record.control,
                        dirty or not addon:UnsavedDataEqual(value, binding.baseline)
                    )
                end
            end

            dirty = dirty or not addon:UnsavedDataEqual(value, binding.baseline)
            addon:SetWorkbenchUnsaved(binding.control, dirty)
            pending = pending or dirty

            if dirty then
                local parent = binding.control:GetParent()

                while parent do
                    changedRows[parent] = true
                    if parent == self.frame then break end
                    parent = parent:GetParent()
                end
            end
        end

        local before = context(self, self.draftBaseline)
        local current = context(self, self.draft)

        if self.settingsKey == 'Announces' then
            addon:SetWorkbenchUnsaved(
                self.fields['enabled' .. tostring(self.selection)],
                not addon:UnsavedDataEqual(before and before.disabled, current and current.disabled)
            )
        end

        if self.settingsKey == 'Conditions' and self.mode == 'categories' then
            addon:SetWorkbenchUnsaved(
                self.fields.category_icon,
                not addon:UnsavedDataEqual(before and before.category_icon, current and current.category_icon)
            )
        end

        for _, view in pairs(self.ordered or {}) do
            for i, row in ipairs(view.rows or {}) do
                local key = view.unsavedKey
                local old = before and before[key]
                local now = current and current[key]

                addon:SetWorkbenchUnsaved(
                    row,
                    changedRows[row] or key and not addon:UnsavedDataEqual(old and old[i], now and now[i])
                )
            end
        end

        if self.roster then
            self.roster.unsavedByValue = {}
            self.roster.unsavedState = nil

            if self.draftBaseline then
                self.roster.unsavedState = {
                    before = rosterLookup(self, self.draftBaseline),
                    current = rosterLookup(self, self.draft),
                    pending = pending,
                    selected = self.mode == 'categories' and self.categorySelection
                        or self.settingsKey == 'Conditions' and self.condition
                        or self.selection,
                    announces = self.draft and self.draft.profile.announces or addon.db.profile.announces or {},
                }
            end

            self:RefreshRosterMarkers()
        end

        if self.fields.apply and self.fields.apply.IsEnabled then
            addon:SetWorkbenchUnsaved(
                self.fields.apply,
                self.fields.apply:IsEnabled() and (pending or self:IsSettingsDraftDirty() or self:IsCreationDirty())
            )
        end
    end

    for _, definition in ipairs({
        { 'Edit', 5 },
        { 'Check', 4 },
        { 'Slider', 7 },
        { 'Choice', 5 },
        { 'Color', 4 },
        { 'Reference', 6 },
        { 'Toggle', 6 },
    }) do
        local method, index = definition[1], definition[2]
        local original = p[method]

        p[method] = function(self, ...)
            local args = { ... }
            local count = select("#", ...)
            local callback = args[index]
            local binding

            if type(callback) == 'function' then
                args[index] = function(value, ...)
                    if binding then binding.value = addon:CopySettingsData(value) end
                    return callback(value, ...)
                end
            end

            local control = original(self, unpack(args, 1, count))
            local value = args[3]
            if method == 'Color' and value == nil then value = { r = 1, g = 1, b = 1, a = 1 } end
            binding = self:BindUnsaved(args[1], control, value, method)
            binding.caption = args[2]
            return control
        end
    end

    local draw = p.Draw

    function p:Draw()
        self.unsavedBindings = {}
        draw(self)
        self:RefreshUnsaved()
    end

    local guard = p.Guard

    function p:Guard(callback)
        return guard(self, function(...)
            local result = callback(...)
            self:RefreshUnsaved()
            return result
        end)
    end

    local discard = p.DiscardSettingsDraft

    function p:DiscardSettingsDraft()
        self.unsavedDefaults = {}
        return discard(self)
    end

    local save = p.SaveSettingsDraft

    function p:SaveSettingsDraft()
        local ok = save(self)
        if ok then self.unsavedDefaults = {} end
        return ok
    end
end
