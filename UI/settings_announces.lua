-- Announces settings page: a roster of announcements (a spell, pet spell, item or macro action plus an event) each with
-- one or more outputs (channel, text, sound or emote, optional conditions), with create, duplicate, delete, import and
-- export. It edits the profile's announces list through the settings pane and never speaks anything itself; sending is
-- done by Core's announcement code. Loaded from RotationMaster.toc right after UI/settings_collections.lua, which
-- registers addon:BuildAnnounceSettings as the Announces page builder. Say, yell, whisper and channel destinations are
-- only offered for macro actions; a saved one on any other action stays visible and invalid.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Choice tables
-- ============================================================================

-- Destinations offered for every action type. Say, yell, whisper and channel are added for macro actions only, and a
-- custom emote entry appears only when an output already has one.
local channels = {
    { value = 'audible', text = L['Audible'] },
    { value = 'partyraid', text = L['Raid or Party'] },
    { value = 'party', text = L['Party Only'] },
    { value = 'raidwarn', text = L['Raid Warning'] },
    { value = 'gesture', text = L['Emote'] },
    { value = 'local', text = L['Local Only'] },
}

-- Action types an announcement can be attached to.
local types = {
    { value = 'spell', text = L['Spell'] },
    { value = 'pet', text = L['Pet Spell'] },
    { value = 'item', text = L['Item'] },
    { value = 'macro', text = L['Via Script/Macro'] },
}

-- ============================================================================
-- Announces page
-- ============================================================================

-- Draws the Announces page into the settings pane: roster, selected entry (name, action, event, outputs), footer
-- actions and the creation form. Every callback re-checks that the pane generation, the settings store, the announces
-- list and the entry it was built for are unchanged, and re-checks again after any call that can run foreign code (uuid
-- generation, platform queries, the condition editor); an edit that arrives for a stale draw is dropped, not applied.
-- @param p table  The settings form pane (p.selection, p.creating, p.newAnnounce and the control builders).
function addon:BuildAnnounceSettings(p)
    local store = p:SettingsData()
    local values = store.profile.announces or {}
    local listSource = store.profile.announces
    local drawing = p.generation

    -- Tells whether the pane is on the same draw and the profile announces list is the one this draw started from.
    -- @return boolean  True while edits from this draw may be applied.
    local function storeCurrent()
        return p:Valid(drawing) and p:SettingsData() == store and store.profile.announces == listSource and p:Valid(
            drawing
        )
    end

    local events = {}

    for id, text in pairs(self.events or {}) do
        events[#events + 1] = { value = id, text = text }
    end

    table.sort(events, function(a, b) return a.text < b.text end)
    local refreshRoster

    -- Tells whether a value is a valid macro announcement identifier not used by another macro announcement.
    -- @param value string  The identifier to test.
    -- @param except table|nil  An announcement that is skipped in the check (the one being edited).
    -- @return boolean  True when the identifier is valid and unused.
    local function identifierFree(value, except)
        if not self:IsValidMacroAnnouncementIdentifier(value) then
            return false
        end

        for _, entry in ipairs(values) do
            if entry ~= except and entry.type == 'macro' and entry.identifier == value then
                return false
            end
        end

        return true
    end

    -- Returns the seed, or the seed with a numeric suffix, as an unused valid macro identifier. An invalid seed becomes
    -- ANNOUNCE.
    -- @param seed string|nil  The identifier to start from.
    -- @return string|nil  The identifier; nil if none is found.
    local function nextIdentifier(seed)
        seed = self:IsValidMacroAnnouncementIdentifier(seed) and seed or 'ANNOUNCE'

        if identifierFree(seed) then
            return seed
        end

        seed = seed:sub(1, 48)

        for i = 2, #values + 2 do
            local value = seed .. '_' .. i

            if identifierFree(value) then
                return value
            end
        end
    end

    -- Stores a field on an entry and refreshes its roster label and search text.
    -- @param entry table  The announcement.
    -- @param key string  The field name.
    -- @param value any  The new value.
    local function update(entry, key, value)
        entry[key] = value

        if refreshRoster then
            refreshRoster(entry)
        end
    end

    local outputFields = {
        'announce',
        'value',
        'announce_sound',
        'emote',
        'emote_target',
        'conditions',
        'channel_name',
    }

    -- Gives every output of a copied or imported entry a fresh id so copies never share ids.
    -- @param entry table  The announcement whose outputs are renewed.
    -- @param current function  Returns whether the caller's context is still current.
    -- @return boolean  False if current() becomes false midway; otherwise the final current() result.
    local function renewOutputs(entry, current)
        for _, output in ipairs(entry.outputs or {}) do
            if not current() then
                return false
            end

            local id = self:uuid()

            if not current() then
                return false
            end

            output.id = id
        end

        return current()
    end

    -- Draws the action rows (type, spell or item or identifier, rank, event) and the Outputs list for an entry, with
    -- field names starting at the prefix. Entries saved in the legacy shape (output fields directly on the entry) are
    -- converted to an outputs list (materialize) on the first structural edit.
    -- @param prefix string  The prefix of the field names (unique per entry).
    -- @param entry table  The announcement to draw.
    -- @return boolean  False if the entry went stale while drawing.
    local function drawAction(prefix, entry)
        local generation = p.generation
        local kind = entry.type
        local identity = entry.id
        local source = entry.outputs

        -- Tells whether the pane, store and this exact entry (same type, id and outputs table) are still on screen and
        -- in the list.
        -- @return boolean  True while edits to the entry may be applied.
        local function parentCurrent()
            if
                not p:Valid(generation)
                or p:SettingsData() ~= store
                or entry.type ~= kind
                or entry.id ~= identity
                or entry.outputs ~= source
            then
                return false
            end
            if p.newAnnounce == entry then
                return p:Valid(generation)
            end

            for _, candidate in ipairs(store.profile.announces or {}) do
                if candidate == entry then
                    return p:Valid(generation)
                end
            end

            return false
        end

        local materialize

        -- Applies a field edit to the entry if it is still current.
        -- @param key string  The field name.
        -- @param value any  The new value.
        local function change(key, value)
            if parentCurrent() then
                update(entry, key, value)
            end
        end

        -- Handles a change of the action type: converts a legacy entry first when it carries a destination only macros
        -- may use, clears the action fields, sets the event or macro identifier that fits the new type and redraws.
        -- @param v string  The chosen type ('spell', 'pet', 'item' or 'macro').
        p:Choice(prefix .. 'type', L['Action Type'], entry.type, types, function(v)
            if not parentCurrent() then
                return
            end

            if
                not source
                and v ~= 'macro'
                and (entry.announce == 'say'
                    or entry.announce == 'yell'
                    or entry.announce == 'whisper'
                    or entry.announce == 'channel')
            then
                if not materialize() then
                    return
                end
            end

            entry.type = v
            entry.spell = nil
            entry.item = nil
            entry.ranked = nil

            if v == 'macro' then
                entry.event = nil
                entry.identifier = nextIdentifier(entry.identifier)
            else
                entry.identifier = nil
                entry.event = entry.event or 'SUCCEEDED'
            end

            p:Draw()
        end)

        if entry.type == 'macro' then
            p:Edit(
                prefix .. 'identifier',
                L['Identifier'],
                entry.identifier or '',
                function(value)
                    if identifierFree(value, entry) then
                        return value
                    end
                end,
                function(v)
                    change('identifier', v)
                end
            )
        elseif entry.type == 'item' then
            p:ItemSequence(prefix .. 'action', entry.item, function(v)
                change('item', v)
            end)
        else
            p:Spell(
                prefix .. 'action',
                L['Spell'],
                entry.spell,
                entry.type == 'pet' and (BOOKTYPE_PET or "pet") or addon.currentSpec,
                function(v)
                    change('spell', v)
                end
            )

            if self:ClientHasSpellRanks() then
                p:InlineCheck(
                    prefix .. 'action',
                    prefix .. 'ranked',
                    L['Use this exact spell rank'],
                    entry.ranked,
                    function(v)
                        change('ranked', v)
                    end,
                    nil,
                    L['Unticked, any rank of the spell matches. Ticked, only the rank you chose matches.']
                )
            end
        end

        if entry.type ~= 'macro' then
            p:Choice(prefix .. 'event', L['Event'], entry.event, events, function(v)
                change('event', v)
            end)
        end

        local items = source or { entry }
        local snapshot, identities = {}, {}

        for i, output in ipairs(items) do
            snapshot[i] = output
            identities[i] = output.id
        end

        -- Tells whether the outputs list still holds exactly the outputs, with the same ids, that this draw displayed.
        -- @return boolean  True while the list may be edited.
        local function collectionCurrent()
            if not parentCurrent() or #items ~= #snapshot then
                return false
            end

            for i, output in ipairs(snapshot) do
                if items[i] ~= output or output.id ~= identities[i] then
                    return false
                end
            end

            return true
        end

        -- Converts a legacy single-output entry into an outputs list (copying each output field into a new output with
        -- a fresh id).
        -- @return table|nil  The outputs list (the existing one when there is one); nil if the entry went stale.
        materialize = function()
            if source then
                return items
            end

            local outputs = {}

            for i, output in ipairs(items) do
                local copy = { id = self:uuid() }

                for _, key in ipairs(outputFields) do
                    copy[key] = self:CopySettingsData(output[key])
                end

                outputs[i] = copy
            end

            if not parentCurrent() then
                return
            end

            for _, key in ipairs(outputFields) do
                entry[key] = nil
            end

            entry.outputs = outputs
            return outputs
        end

        -- Called after a reorder or insert: converts a legacy entry to an outputs list so the new order is stored.
        local function structuralChange()
            if parentCurrent() then
                materialize()
            end
        end

        -- Inserts a new output (partyraid, empty text) into the outputs list, up to 64. The Add button sits on the
        -- Outputs header row; a click appends and a drag drops into a gap, both through this one insert.
        -- @param gap number  The position to insert at (clamped to the list).
        local function insertOutput(gap)
            if not collectionCurrent() or #items >= 64 then
                return
            end

            local output = { id = self:uuid(), announce = 'partyraid', value = '' }

            if not collectionCurrent() then
                return
            end

            local outputs = materialize()

            if not outputs then
                return
            end

            table.insert(outputs, math.max(1, math.min(gap, #outputs + 1)), output)
            p:Draw()
        end

        -- Draws the Outputs list. The row renderer (the fourth argument) draws one output's destination, text
        -- or emote or sound, conditions, duplicate, help and Enabled controls and marks the row invalid when the output
        -- is incomplete.
        -- @param _ any  Unused (the output's id).
        -- @param index number  The output's 1-based position in the list.
        -- @param output table  The output ({ id, announce, value, announce_sound, emote, emote_target, conditions,
        --   channel_name,
        -- disabled }).
        -- @param row table  The shared card row that supplies the duplicate, help and enabled controls.
        p:OrderedCollection(
            'announce_outputs_' .. prefix,
            items,
            function(i) return string.format(L['Output %d'], i) end,
            function(_, index, output, row)
                local field = index == 1 and prefix or prefix .. 'output' .. index

                -- Tells whether this output is still the one at its position in the current outputs list.
                -- @return boolean  True while edits to the output may be applied.
                local function current()
                    return collectionCurrent() and items[index] == output
                end

                -- Applies an edit to one output if the list is still current and the output is still at its position.
                -- @param key string  The output field name.
                -- @param value any  The new value.
                local function outputChange(key, value)
                    if current() then
                        output[key] = value

                        if refreshRoster then
                            refreshRoster(entry)
                        end
                    end
                end

                local choices = {}

                for _, choice in ipairs(channels) do
                    choices[#choices + 1] = choice
                end

                if kind == 'macro' then
                    for _, choice in ipairs({
                        { value = 'say', text = L['Say'] },
                        { value = 'yell', text = L['Yell'] },
                        { value = 'whisper', text = L['Whisper'] },
                        { value = 'channel', text = L['Channel'] },
                    }) do
                        choices[#choices + 1] = choice
                    end
                end

                if output.announce == 'emote' then
                    choices[#choices + 1] = { value = 'emote', text = L['Custom emote'] }
                end

                -- A prohibited saved destination remains visible until the user chooses a replacement.
                if
                    kind ~= 'macro'
                    and (output.announce == 'say'
                        or output.announce == 'yell'
                        or output.announce == 'whisper'
                        or output.announce == 'channel')
                then
                    choices[#choices + 1] = {
                        value = output.announce,
                        text = L[({
                            say = 'Say',
                            yell = 'Yell',
                            whisper = 'Whisper',
                            channel = 'Channel',
                        })[output.announce]] .. ' (' .. L['Unavailable'] .. ')',
                    }
                end

                -- Handles a change of the destination: choosing a channel on a legacy entry converts it first; then
                -- stores the value and redraws.
                -- @param v string  The chosen destination.
                local choice = p:Choice(field .. 'channel', L['Announce'], output.announce, choices, function(v)
                    if not current() then
                        return
                    end

                    if v == 'channel' and not source then
                        local outputs = materialize()

                        if not outputs then
                            return
                        end

                        outputs[index].announce = v
                    else
                        outputChange('announce', v)
                    end

                    p:Draw()
                end)

                -- The card has no title row: Announce is its first row, beside the
                -- Enabled pill and Help at the card's top right.
                choice:SetWidth(math.max(60, p.width - (p.labelX or 220) - row.firstRowReserve))

                if kind ~= 'macro' then
                    local allowed = {}

                    for _, v in ipairs(choices) do
                        if v.value ~= 'say' and v.value ~= 'yell' and v.value ~= 'whisper' and v.value ~= 'channel' then
                            allowed[#allowed + 1] = v
                        end
                    end

                    self:SetUIScript(choice, 'OnClick', p:Guard(function()
                        if current() and p:FlushEdits() and current() then
                            p:ShowChoices(choice, allowed, function(v)
                                if current() then
                                    outputChange('announce', v)
                                    p:Draw()
                                end
                            end)
                        end
                    end))
                end

                if output.announce == 'channel' then
                    local name = output.channel_name

                    local selector = p:Choice(
                        field .. 'channel_name',
                        L['Channel'],
                        name,
                        name and { { value = name, text = self:PlainWorkbenchName(name) } } or {},
                        function() end
                    )

                    -- Opens the channel-name menu: reads the joined announcement channels from the platform (validated,
                    -- at most 20 names), keeps a saved name that is no longer joined (marked unavailable), and stores
                    -- the chosen name.
                    self:SetUIScript(selector, 'OnClick', p:Guard(function()
                        if not current() or not p:FlushEdits() or not current() then
                            return
                        end

                        local platform = self.Platform
                        local query = platform and platform.GetJoinedAnnouncementChannels

                        if not current() then
                            return
                        end

                        local ok, found = false, nil

                        if type(query) == 'function' then
                            ok, found = pcall(query, platform, current)
                        end

                        if
                            not current()
                            or self.Platform ~= platform
                            or platform and platform.GetJoinedAnnouncementChannels ~= query
                            or not current()
                        then
                            return
                        end

                        local rows, seen = {}, {}

                        if ok and type(found) == 'table' and getmetatable(found) == nil then
                            for i = 1, math.min(#found, 20) do
                                local v = rawget(found, i)
                                local value = type(v) == 'table' and getmetatable(v) == nil and rawget(v, 'value')

                                if
                                    type(value) == 'string'
                                    and #value > 0
                                    and #value <= 256
                                    and not value:find('[%z\1-\31\127]')
                                    and not seen[value]
                                then
                                    seen[value] = true
                                    rows[#rows + 1] = { value = value, text = self:PlainWorkbenchName(value) }
                                end
                            end
                        end

                        if name and not seen[name] then
                            rows[#rows + 1] = {
                                value = name,
                                text = self:PlainWorkbenchName(name) .. ' (' .. L['Unavailable'] .. ')',
                            }
                        end

                        if not current() then
                            return
                        end

                        p:ShowChoices(selector, rows, function(v)
                            if current() and output.announce == 'channel' and output.channel_name == name then
                                outputChange('channel_name', v)
                                p:Draw()
                            end
                        end)
                    end))
                end

                if output.announce == 'gesture' then
                    local emotes = self.Platform:GetAnnouncementEmotes()

                    if not current() then
                        return
                    end

                    p:Choice(field .. 'emote', L['Emote'], output.emote, emotes, function(v)
                        outputChange('emote', v)
                    end)

                    p:Check(
                        field .. 'emote_target',
                        kind == 'macro' and L['Use supplied macro target ({{target}})']
                            or L['Use spell recipient ({{target}})'],
                        output.emote_target,
                        function(v)
                            outputChange('emote_target', v)
                        end
                    )
                elseif output.announce == 'audible' then
                    p:Sound(field, L['Sound'], output.announce_sound, function(v)
                        outputChange('announce_sound', v)
                    end)
                else
                    p:Edit(field .. 'text', L['Text'], output.value or '', nil, function(v)
                        outputChange('value', v)
                    end)
                end

                local summary = self:DescribeCondition(output.conditions or {}, self.currentSpec)

                if not current() then
                    return
                end

                local conditionY = p.y

                -- Opens the condition editor on a copy of the output's conditions; applying stores the copy (or clears
                -- the field when it is empty) and redraws, only if the output is unchanged since the editor opened.
                local condition = p:Button(field .. 'conditions', summary, function()
                    if not current() then
                        return
                    end

                    local conditions = output.conditions
                    local draft = self:CopySettingsData(conditions or {})
                    local baseline = self:CopySettingsData(draft)

                    -- Tells whether the output and its conditions are still exactly what the condition editor was
                    -- opened on.
                    -- @return boolean  True while the editor's result may be applied.
                    local function editing()
                        return current()
                            and output.conditions == conditions
                            and self:SettingsDataEqual(conditions or {}, baseline)
                            and current()
                    end

                    if not editing() then
                        return
                    end

                    self:ShowConditionEditor(
                        nil,
                        self.currentSpec,
                        draft,
                        function(applied)
                            if applied and editing() then
                                output.conditions = next(draft) and draft or nil
                                p:Draw()
                            end
                        end,
                        editing,
                        {
                            persistentOwner = true,
                            announcement = true,
                            announcementTarget = true,
                            title = L['Announcement conditions'],
                            contextLabel = string.format(L['Output %d'], index),
                        }
                    )
                end)

                condition:SetWidth(math.max(1, p.width))
                self:AlignWorkbenchTextLeft(condition, 6)
                condition:GetFontString():SetWordWrap(true)
                condition:SetHeight(math.max(24, condition:GetFontString():GetStringHeight() + 8))
                condition.tooltip = L['Edit announcement conditions']
                p.y = conditionY + condition:GetHeight() + 8
                -- The shared card owns the rail (Help, Duplicate, Delete) and the
                -- Enabled pill; this card wires their actions.
                local duplicate = row.duplicate
                p.fields[prefix .. 'output' .. index .. 'duplicate'] = duplicate

                -- Copies the output (with a fresh id) into the position after it, up to 64 outputs, converting a legacy
                -- entry first.
                self:SetUIScript(duplicate, 'OnClick', p:Guard(function()
                    if not current() or #items >= 64 or not p:FlushEdits() or not current() then
                        return
                    end

                    local copy

                    if source then
                        copy = self:CopySettingsData(output)
                    else
                        copy = {}

                        for _, key in ipairs(outputFields) do
                            copy[key] = self:CopySettingsData(output[key])
                        end
                    end

                    copy.id = self:uuid()

                    if not current() then
                        return
                    end

                    local outputs = materialize()

                    if not outputs then
                        return
                    end

                    table.insert(outputs, index + 1, copy)
                    p:Draw()
                end))

                local help = row.help
                p.fields[prefix .. 'output' .. index .. 'help'] = help

                self:SetUIScript(help, 'OnClick', function()
                    if current() then
                        self:OpenWorkbenchHelp({
                            heading = string.format(L['Output %d'], index),
                            owner = self.pretty_name,
                            valid = current,
                            sections = function() return self:GetAnnouncementOutputHelp(kind, output.announce) end,
                        })
                    end
                end)

                local enabled = row.enabled
                enabled:SetText(output.disabled and L['Disabled'] or L['Enabled'])
                enabled:SetSelected(not output.disabled)
                enabled:Enable()
                enabled.tooltip = L['Output state']
                p.fields[field .. 'enabled'] = enabled

                self:SetUIScript(enabled, 'OnClick', p:Guard(function()
                    if not current() or not p:FlushEdits() or not current() then
                        return
                    end

                    outputChange('disabled', not output.disabled)

                    if current() then
                        p:Draw()
                    end
                end))

                local candidate = output

                if not source then
                    candidate = { id = '00000000-0000-0000-0000-000000000000' }

                    for _, key in ipairs(outputFields) do
                        candidate[key] = output[key]
                    end
                end

                local valid = self:IsValidAnnouncementOutput(candidate, kind == 'macro')

                if not current() then
                    return
                end

                self:SetWorkbenchInvalid(
                    row,
                    not valid,
                    L['Complete this output or choose a destination available for this action type.']
                )
            end,
            structuralChange,
            {
                prefix = prefix .. 'output',
                unsavedKey = 'outputs',
                current = collectionCurrent,
                help = true,
                duplicate = true,
                canDuplicate = function() return #items < 64 end,
                enabled = true,
                heading = L['Outputs'],
                add = {
                    key = prefix .. 'add_output',
                    text = L['Add output'],
                    enabled = #items < 64,
                    insert = insertOutput,
                },
            }
        )

        if not parentCurrent() then
            return false
        end

        return true
    end

    -- Returns the name and icon for an item action: an item set (first member), an item list or a single item id.
    -- @param value string|table|number|nil  An item set id, an item list or an item id.
    -- @return table|nil  { name, icon } (an item set reports its name; items report the provider's info); nil when
    --   unknown.
    local function itemInfo(value)
        if type(value) == 'string' then
            local set = (store.profile.itemsets or {})[value] or (store.global.itemsets or {})[value]

            local info = set and set.items and self:GetReferenceProvider('item').info(
                tonumber(set.items[1]) or self:GetReferenceProvider('item').resolve(set.items[1])
            )

            return { name = set and set.name or L['Item Set'], icon = info and info.icon }
        end

        local id = type(value) == 'table' and value[1] or value
        return self:GetReferenceProvider('item').info(tonumber(id) or self:GetReferenceProvider('item').resolve(id))
    end

    -- Returns the name and icon for an announcement's action, used for the roster label.
    -- @param entry table  The announcement.
    -- @return table|nil  { name, icon or iconID }; nil when the action is unknown.
    local function entryInfo(entry)
        if entry.type == 'macro' then
            return { name = entry.identifier or L['Via Script/Macro'] }
        end

        return entry.type == 'item' and itemInfo(entry.item) or self.Platform:GetSpellInfo(entry.spell)
    end

    -- Returns the text the roster search matches: the event and every output's text, destination and channel name.
    -- @param entry table  The announcement.
    -- @return string  The words joined with spaces.
    local function searchText(entry)
        local parts = { entry.event or '' }

        for _, output in ipairs(entry.outputs or { entry }) do
            parts[#parts + 1] = output.value or ''
            parts[#parts + 1] = output.announce or ''
            parts[#parts + 1] = output.channel_name or ''
        end

        return table.concat(parts, ' ')
    end

    -- Updates one roster row's label, icon and search text after an edit, without redrawing the whole page.
    -- @param entry table  The announcement that changed.
    refreshRoster = function(entry)
        local info = entryInfo(entry)

        for i, value in ipairs(values) do
            if value == entry then
                p:UpdateRosterEntry(i, {
                    text = self:SettingsNonempty(entry.name)
                        or info and info.name
                        or entry.type == 'item' and L['Item data loading']
                        or L['Unknown spell'],
                    icon = info and (info.icon or info.iconID),
                    search = searchText(entry),
                })

                break
            end
        end
    end

    local entries = {}

    for i, entry in ipairs(values) do
        local info = entryInfo(entry)

        entries[#entries + 1] = {
            value = i,
            text = self:SettingsNonempty(entry.name)
                or info and info.name
                or entry.type == 'item' and L['Item']
                or L['Unknown spell'],
            icon = info and (info.icon or info.iconID),
            search = searchText(entry),
        }
    end

    if not values[p.selection] and not p.creating then
        p.selection = entries[1] and entries[1].value
    end

    -- Validates the creation form's draft and appends it to the profile announces list as a new entry with a fresh id.
    -- Shows a message and keeps the form open when the action or outputs are incomplete.
    local function addAnnouncement()
        local entry = p.newAnnounce
        local field = entry.type == 'item' and 'item' or 'spell'
        local valid

        if entry.type == 'macro' then
            valid = identifierFree(entry.identifier, entry)
        elseif entry.type == 'item' then
            local item = entry.item

            local set = type(item) == 'string'
                and ((store.profile.itemsets or {})[item] or (store.global.itemsets or {})[item])

            valid = type(item) == 'table' and #item > 0 or set and type(set.items) == 'table' and #set.items > 0
        else
            valid = self:SettingsPositiveID(tostring(entry[field] or ''))
        end

        if not valid or not self:IsValidAnnouncement(entry) then
            p:Message(L['Choose an action first.'])
            return
        end

        store.profile.announces = store.profile.announces or {}
        store.profile.announces[#store.profile.announces + 1] = self:CopySettingsData(entry)
        store.profile.announces[#store.profile.announces].id = self:uuid()
        p.selection = #store.profile.announces
        p.creating = false
        p.newAnnounce = nil
        p:Draw()
    end

    p:UseRoster(
        entries,
        p.selection,
        function(id)
            p.selection = id
            p.creating = false
            p:Draw()
        end,
        {
            newText = L['Add announcement'],
            new = function()
                p.previousSelection = p.selection
                p.selection = nil
                p.creating = true
                p.emptyDismissed = false
                p:Draw()
            end,
        }
    )

    local selected = not p.creating and values[p.selection] or nil
    local named = {}

    for _, row in ipairs(entries) do
        named[row.value] = self:CopySettingsData(values[row.value])
        named[row.value].name = row.text
    end

    local selection = p.selection
    local selectedID = selected and selected.id

    -- Tells whether the selected entry and pane selection are the ones this draw captured.
    -- @return boolean  True while footer actions may act.
    local function footerCurrent()
        if not storeCurrent() or p.selection ~= selection then
            return false
        end
        if selected and (values[selection] ~= selected or selected.id ~= selectedID) then
            return false
        end

        return storeCurrent() and p.selection == selection
    end

    -- Starts a footer action (duplicate, import/export): flushes pending field edits and snapshots the selected entry.
    -- Ordinary staged edits are current; values are frozen only for one footer operation.
    -- @return function|nil  A current() check that also fails if the entry changed meanwhile; nil when the page is
    --   stale.
    local function beginFooter()
        if not footerCurrent() or not p:FlushEdits() or not footerCurrent() then
            return
        end

        local baseline = selected and self:CopySettingsData(selected)

        if not footerCurrent() then
            return
        end

        -- Tells whether the page and the selected entry are unchanged since beginFooter took its snapshot.
        -- @return boolean  True while the footer action may continue.
        local function current()
            if not footerCurrent() then
                return false
            end
            if selected and not self:SettingsDataEqual(selected, baseline) then
                return false
            end

            return footerCurrent()
        end

        if current() then
            return current
        end
    end

    if not footerCurrent() then
        return
    end

    self:CollectionFooter(
        p,
        'announcement',
        named,
        selected and p.selection or nil,
        {
            key = 'duplicate',
            text = L['Duplicate'],
            icon = 'copy',
            enabled = selected ~= nil,
            -- Duplicates the selected announcement: copies it with a fresh id and fresh output ids, gives a macro a new
            -- identifier, appends it and selects it.
            action = function()
                local current = beginFooter()

                if not current then
                    return
                end

                local copy = self:CopySettingsData(selected)

                if not current() then
                    return
                end

                local id = self:uuid()

                if not current() then
                    return
                end

                copy.id = id

                if not renewOutputs(copy, current) then
                    return
                end

                if copy.type == 'macro' then
                    copy.identifier = nextIdentifier(copy.identifier)
                end

                if not current() then
                    return
                end

                values[#values + 1] = copy
                p.selection = #values
                p:Draw()
            end,
        },
        {
            key = 'transfer',
            text = L['Import/Export'],
            icon = 'transfer',
            -- Opens the import/export dialog for the selected announcement (or an empty one when none is selected),
            -- encoded as an 'RM-Announcement' wrapper. The import callback (input, settings) decodes and validates the
            -- pasted text, checks a macro identifier is unique, gives the entry a fresh id and fresh output ids and
            -- then replaces the selected announcement or appends a new one, dropping the result if the page went stale
            -- meanwhile.
            action = function()
                local current = beginFooter()

                if not current then
                    return
                end

                local codec = self:NewRotationCodec()

                if not current() then
                    return
                end

                local text, why = '', nil

                if selected then
                    text, why = codec:Encode({
                        format = 'RM-Announcement',
                        version = selected.outputs and 2 or 1,
                        announcement = selected,
                    })

                    if not current() then
                        return
                    end

                    if not text then
                        p:Message(why)
                        return
                    end
                end

                local request = {}
                p.announcementTransferRequest = request
                local dialog, transferSerial

                -- Tells whether the import/export dialog opened by this action is still the live one for this
                -- selection.
                -- @return boolean  True while the dialog's callbacks may act.
                local function transferCurrent()
                    if not current() or p.announcementTransferRequest ~= request or p.textDialog ~= dialog then
                        return false
                    end

                    return not dialog or dialog.serial == transferSerial and dialog.frame:IsShown()
                end

                self:ShowSettingsTextTransfer(
                    p,
                    L['Announces'],
                    text,
                    function(input, settings)
                        if not transferCurrent() then
                            return false
                        end

                        local decoded, errorText = codec:Decode(input)

                        if not transferCurrent() then
                            return false
                        end

                        local wrapper = decoded and decoded.value
                        local entry = type(wrapper) == 'table' and wrapper.announcement

                        if
                            type(wrapper) ~= 'table'
                            or wrapper.format ~= 'RM-Announcement'
                            or (wrapper.version ~= 1 and wrapper.version ~= 2)
                            or wrapper.version == 1 and type(entry) == 'table' and entry.outputs ~= nil
                            or wrapper.version == 2 and type(entry) == 'table' and entry.outputs == nil
                            or not self:IsValidAnnouncement(entry)
                        then
                            return false, errorText or L['Invalid announcement.']
                        end
                        if not transferCurrent() then
                            return false
                        end
                        if
                            entry.type == 'macro'
                            and not identifierFree(entry.identifier, settings.mode == 'replace' and selected or nil)
                        then
                            return false, L['Use a unique Via Script/Macro identifier.']
                        end
                        if not transferCurrent() then
                            return false
                        end

                        entry = self:CopySettingsData(entry)

                        if not transferCurrent() then
                            return false
                        end

                        local id = settings.mode == 'replace' and selected and selected.id or self:uuid()

                        if not transferCurrent() then
                            return false
                        end

                        entry.id = id

                        if not renewOutputs(entry, transferCurrent) then
                            return false
                        end

                        if not entry.outputs then
                            entry.value = entry.value or ''
                        end

                        if not transferCurrent() then
                            return false
                        end

                        store.profile.announces = store.profile.announces or {}

                        if settings.mode == 'replace' and selected then
                            entry.name = selected.name
                            store.profile.announces[p.selection] = entry
                        else
                            entry.name = settings.name
                            store.profile.announces[#store.profile.announces + 1] = entry
                            p.selection = #store.profile.announces
                        end

                        p.creating = false
                        p.newAnnounce = nil
                        return true
                    end,
                    {
                        canReplace = selected ~= nil,
                        selectedName = selected and (self:SettingsNonempty(selected.name) or named[p.selection].name),
                        fallbackName = L['Imported announcement'],
                        originalName = function(input)
                            local decoded = codec:Decode(input)
                            local entry = decoded and type(decoded.value) == 'table' and decoded.value.announcement

                            if type(entry) == 'table' then
                                if self:SettingsNonempty(entry.name) then
                                    return entry.name
                                end

                                local info = entryInfo(entry)
                                return info and info.name
                            end
                        end,
                        review = {
                            kind = 'announcement',
                            -- Decodes pasted text for the import review.
                            -- @param input string  The pasted export text.
                            -- @return table|nil  A copy of the announcement.
                            -- @return string|nil  The error text when the first value is nil.
                            parse = function(input)
                                local decoded, errorText = codec:Decode(input)
                                local wrapper = decoded and decoded.value
                                local entry = type(wrapper) == 'table' and wrapper.announcement

                                if
                                    type(wrapper) ~= 'table'
                                    or wrapper.format ~= 'RM-Announcement'
                                    or (wrapper.version ~= 1 and wrapper.version ~= 2)
                                    or wrapper.version == 1 and type(entry) == 'table' and entry.outputs ~= nil
                                    or wrapper.version == 2 and type(entry) == 'table' and entry.outputs == nil
                                    or not self:IsValidAnnouncement(entry)
                                then
                                    return nil, errorText or L['Invalid announcement.']
                                end

                                return self:CopySettingsData(entry)
                            end,
                            current = function() return selected end,
                            problems = function(entry, dialog)
                                local list = {}

                                if
                                    entry.type == 'macro'
                                    and not identifierFree(
                                        entry.identifier,
                                        dialog.mode == 'replace' and selected or nil
                                    )
                                then
                                    list[#list + 1] = L['Use a unique Via Script/Macro identifier.']
                                end

                                return list
                            end,
                        },
                    }
                )

                dialog = p.textDialog
                transferSerial = dialog and dialog.serial
            end,
        }
    )

    -- The page name is in the tab and title bar; the page "?" is the shell's.
    for i, entry in ipairs(values) do
        if i == p.selection and not p.creating then
            -- No title repeating the name: Name is the first row, narrowed to
            -- leave the Enabled pill and the trash beside it.
            local name = p:Edit('entry' .. i .. 'name', L['Name'], entry.name or '', nil, function(value)
                update(entry, 'name', value)
            end)

            name:SetWidth(math.max(60, p.width - 220 - 122))

            if not drawAction('entry' .. i, entry) then
                return
            end

            local enabled = p:Acquire('announceEnabled', function()
                return self:CreateWorkbenchPill(p.child, '', 88)
            end)

            enabled:ClearAllPoints()
            enabled:SetPoint('TOPRIGHT', -28, -4)
            enabled:SetSize(88, 18)
            enabled:SetText(entry.disabled and L['Disabled'] or L['Enabled'])
            enabled:SetSelected(not entry.disabled)
            p.fields['enabled' .. i] = enabled

            self:SetUIScript(enabled, 'OnClick', p:Guard(function()
                if p:FlushEdits() then
                    entry.disabled = not entry.disabled
                    p:Draw()
                end
            end))

            local identity = entry.id

            p.fields['delete' .. i] = self:SettingsTopDelete(p, function()
                self:ConfirmSettingsDeletion(p, L['Delete this announcement?'], function()
                    for index, current in ipairs(self.db.profile.announces or {}) do
                        if identity and current.id == identity or not identity and index == i then
                            table.remove(self.db.profile.announces, index)
                            p.selection = nil
                            return true
                        end
                    end

                    return false, 'announcement-changed'
                end)
            end)

            local trash = p.fields['delete' .. i]
            trash:ClearAllPoints()
            trash:SetPoint('TOPRIGHT', 0, -4)
        end
    end

    if p.creating or #values == 0 and p:CanAutoCreateCollection('profile', 'announces') then
        p.newAnnounce = p.newAnnounce or {
            type = 'spell',
            event = 'SUCCEEDED',
            outputs = { { id = self:uuid(), announce = 'partyraid', value = '' } },
        }

        p:Edit('new_name', L['Name'], p.newAnnounce.name or '', nil, function(value)
            p.newAnnounce.name = value
        end)

        if not drawAction('new_', p.newAnnounce) then
            return
        end

        p:CreationActions(addAnnouncement, function()
            p.newAnnounce = nil
            p.creating = false
            p.selection = p.previousSelection
            p.emptyDismissed = true
            p:Draw()
        end)
    end
end
