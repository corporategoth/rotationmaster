-- The Integrations page of the settings window: Lua editor choices (Native, LuaWorkbench, registered providers) and the
-- read-only or toggleable inventory of supported addons (Questie, boss mods, Masque, action bars, ...).
-- addon:BuildIntegrationSettings(p) draws it into the page object `p`; the page registry in UI/settings_collections.lua
-- calls it.
-- Rows come from Integrations/catalog.lua (ListIntegrationStatus, GetIntegrationClientSupport) and UI/lua_editor.lua
-- (ListLuaEditorProviders); this file only edits the draft profile keys lua_editor, lua_editor_disabled,
-- lua_native_highlighting, lua_line_numbers, questie_enabled, encounter_provider and preview_masque.
-- It must stay a cold page: no addon discovery, no provider construction, and every callback re-checks `current()`
-- because the page can be redrawn or its draft replaced while a call is in flight. Loaded with the other settings_*.lua
-- pages.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Draft profile helpers
-- ============================================================================

-- Tells whether the user switched editor provider `id` off in this draft profile.
-- @param profile table  The draft profile.
-- @param id string  The editor provider id.
-- @return boolean  True when the provider is switched off.
local function disabled(profile, id)
    return type(profile.lua_editor_disabled) == 'table' and profile.lua_editor_disabled[id] == true
end

-- Returns the draft's syntax-highlighting setting; when it was never saved, highlighting is on unless the editor choice
-- is plain text.
-- @param profile table  The draft profile.
-- @return boolean  True when highlighting is on.
local function highlighting(profile)
    if profile.lua_native_highlighting ~= nil then
        return profile.lua_native_highlighting == true
    end

    return profile.lua_editor ~= 'plain'
end

-- Escapes pipes and replaces control characters so a provider-supplied name cannot inject color codes or break the row.
-- @param value string  The name.
-- @return string  The safe name.
-- @return number  The number of control characters replaced (the result of the last gsub).
local function safeName(value)
    return value:gsub('|', '||'):gsub('[%z\1-\31\127]', '?')
end

-- Connection states for which an addon is known to be loaded, so its version is worth showing.
local versionStates = { loaded = true, connected = true, disabled = true, incompatible = true }

-- Returns the version string for a catalog row, or an empty string unless there is evidence the addon is loaded (an
-- installed but not loaded addon shows no version).
-- @param entry table|nil  The catalog row.
-- @return string  The version, or ''.
local function versionFor(entry)
    if entry then
        local loaded = entry.loaded

        if loaded == true or loaded == nil and versionStates[entry.state] then
            return entry.version or ''
        end
    end

    return ''
end

-- Accent color of the status pill for each row state.
local colors = {
    missing = { .48, .48, .48 },
    supported = { .25, .55, .9 },
    disabled = { .85, .25, .25 },
    enabled = { .25, .7, .35 },
    selected = { 1, .8, .2 },
}

-- ============================================================================
-- Page builder
-- ============================================================================

-- Draws the Integrations page into the settings page object: builds the editor rows and the addon groups from the
-- catalog, measures shared columns once, then draws one card per row inside collapsible sections. Returns without
-- drawing when the page generation or draft changed mid-build.
-- @param p table  The settings page object.
function addon:BuildIntegrationSettings(p)
    local profile = p:SettingsData().profile
    local token = p.generation

    -- Tells whether this drawing is still the live one: the page generation is unchanged and, in a transaction, the
    -- draft profile is the one captured at the start.
    -- @return boolean  True while the page may be updated.
    local function current()
        return p:Valid(token) and (not p.transactionKeys or p.draft and p.draft.profile == profile)
    end

    -- Compatibility is a cold page snapshot; failures retain the unknown entry.
    local client

    local ok, value = pcall(function()
        local platform = self.Platform

        if not current() then
            return
        end

        local get = platform and platform.GetClientInfo

        if not current() then
            return
        end
        if type(get) == 'function' then
            return get(platform)
        end
    end)

    if not current() then
        return
    end

    if ok then
        client = value
    end

    -- Tells whether the catalog allows an addon on this client; an unknown or failed lookup keeps the row visible.
    -- @param id string  The addon id ('!!!LuaWorkbench' for LuaWorkbench).
    -- @return boolean|nil  False only when the catalog says the addon is explicitly unsupported on this client; nil
    --   when the page went stale.
    local function supported(id)
        local success, state = pcall(function()
            local check = self.GetIntegrationClientSupport

            if not current() then
                return
            end
            if type(check) == 'function' then
                return check(self, id, client)
            end
        end)

        if not current() then
            return
        end

        return not (success and state == 'unsupported')
    end

    -- Returns the editor rows sorted by id, a lookup by id, and the Native row. Providers unsupported on this client
    -- are left out; LuaWorkbench is listed as unavailable when the addon is not present.
    -- @return table[]|nil  The rows { id, name, available }; nil when the page went stale or the provider list is
    --   missing.
    -- @return table  The rows by id.
    -- @return table  The Native row.
    local function editors()
        local list = self.ListLuaEditorProviders

        if not current() or type(list) ~= 'function' then
            return
        end

        local entries = list(self)

        if not current() then
            return
        end

        local rows, byID = {}, {}

        for _, entry in ipairs(entries) do
            local id = entry.value
            local allowed = supported(id == 'LuaWorkbench' and '!!!LuaWorkbench' or id)

            if not current() then
                return
            end

            if allowed and id ~= 'auto' and id ~= 'plain' and id ~= 'native' then
                local available = true

                if id == 'LuaWorkbench' then
                    local check = self.IsLuaWorkbenchIntegrationAvailable

                    if not current() then
                        return
                    end

                    available = type(check) == 'function' and check(self) == true
                end

                if not current() then
                    return
                end

                if not byID[id] then
                    local row = { id = id, name = safeName(entry.text), available = available == true }
                    rows[#rows + 1] = row
                    byID[id] = row
                end
            end
        end

        table.sort(rows, function(a, b) return a.id < b.id end)
        local workbenchAllowed = supported('!!!LuaWorkbench')

        if not current() then
            return
        end

        if workbenchAllowed and not byID.LuaWorkbench then
            local row = { id = 'LuaWorkbench', name = L['LuaWorkbench'], available = false }
            rows[#rows + 1] = row
            byID.LuaWorkbench = row
        end

        local native = { id = 'native', name = L['Native'], available = true }
        byID.native = native
        return rows, byID, native
    end

    -- Returns the editor that would actually open, following the draft: the first available enabled provider for
    -- "auto", the chosen provider if usable, else native.
    -- @param rows table[]  The editor rows.
    -- @param byID table  The editor rows by id.
    -- @return string|nil  The editor id; nil when nothing is usable.
    local function effective(rows, byID)
        local selected = profile.lua_editor or 'auto'

        if selected == 'auto' then
            for _, row in ipairs(rows) do
                if row.available and not disabled(profile, row.id) then
                    return row.id
                end
            end
        elseif selected ~= 'native' and selected ~= 'plain' then
            local row = byID[selected]

            if row and row.available and not disabled(profile, selected) then
                return selected
            end
        end

        if not disabled(profile, 'native') then
            return 'native'
        end
    end

    -- Stores the current highlighting choice the first time an editor change is made, so switching to a provider and
    -- back does not lose it.
    -- @param value boolean  The current highlighting setting.
    local function rememberHighlight(value)
        if profile.lua_native_highlighting == nil then
            profile.lua_native_highlighting = value
        end
    end

    -- Returns the lua_editor value for choosing an editor: Native stands for "native" or "plain" depending on the
    -- highlighting setting.
    -- @param id string  The editor id.
    -- @param value boolean  The highlighting setting.
    -- @return string  The lua_editor value.
    local function selection(id, value)
        return id == 'native' and (value and 'native' or 'plain') or id
    end

    -- Returns a copy of the disabled-provider map with a provider set or cleared.
    -- @param id string  The editor provider id.
    -- @param value boolean  True to mark it disabled, false to clear it.
    -- @return table|nil  The new map; nil (after a message) when it would exceed 64 entries.
    local function mapWith(id, value)
        local map, n = {}, 0

        for key, on in pairs(profile.lua_editor_disabled or {}) do
            if on == true then
                map[key] = true
                n = n + 1
            end
        end

        if value and not map[id] then
            n = n + 1
        end

        if n > 64 then
            p:Message(L['Unavailable'])
            return
        end

        map[id] = value or nil
        return map
    end

    -- Selects an available, enabled provider as the Lua editor and redraws.
    -- @param id string  The editor provider id.
    local function choose(id)
        local rows, byID = editors()

        if not rows or not current() then
            return
        end

        local row = byID[id]

        if not row or not row.available or disabled(profile, id) then
            return
        end

        local value = highlighting(profile)
        rememberHighlight(value)
        profile.lua_editor = selection(id, value)
        p:Draw()
    end

    -- Re-enables a disabled provider; if no editor was usable, it also becomes the selected one.
    -- @param id string  The editor provider id.
    local function enable(id)
        local rows, byID = editors()

        if not rows or not current() then
            return
        end

        local row = byID[id]

        if not row or not row.available or not disabled(profile, id) then
            return
        end

        local selected = effective(rows, byID)
        local value = highlighting(profile)
        local map = mapWith(id, false)

        if not map then
            return
        end

        profile.lua_editor_disabled = next(map) and map or nil

        if not selected then
            rememberHighlight(value)
            profile.lua_editor = selection(id, value)
        end

        p:Draw()
    end

    -- Disables a provider. If it is the selected editor it needs a replacement chosen by the user (or none when no
    -- other editor is available, which falls back to plain text); refuses when the state no longer matches what the
    -- card showed.
    -- @param id string  The editor provider id.
    -- @param replacement string|nil  The editor that takes over when this one was selected.
    -- @param wasSelected boolean  True when the card showed this provider as the selected editor.
    local function disable(id, replacement, wasSelected)
        local rows, byID = editors()

        if not rows or not current() then
            return
        end

        local row = byID[id]

        if not row or not row.available or disabled(profile, id) then
            return
        end

        local selected = effective(rows, byID)

        if wasSelected and selected ~= id or not wasSelected and selected == id then
            return
        end

        if replacement then
            local target = byID[replacement]

            if not target or replacement == id or not target.available or disabled(profile, replacement) then
                return
            end
        elseif wasSelected then
            -- A new enabled alternative requires a fresh explicit handoff choice.
            for other, target in pairs(byID) do
                if other ~= id and target.available and not disabled(profile, other) then
                    return
                end
            end
        end

        local value = highlighting(profile)
        local map = mapWith(id, true)

        if not map then
            return
        end

        rememberHighlight(value)
        profile.lua_editor_disabled = map

        if wasSelected then
            profile.lua_editor = replacement and selection(replacement, value) or 'plain'
        end

        p:Draw()
    end

    -- Handles a click on an editor card pill: re-enables a disabled provider; for an unselected one asks Disable or
    -- Select; for the selected one asks which alternative takes over before disabling it.
    -- @param id string  The editor provider id.
    -- @param anchor table  The frame the choice menu opens under.
    local function editorAction(id, anchor)
        local rows, byID = editors()

        if not rows or not current() then
            return
        end

        local row = byID[id]

        if not row or not row.available then
            return
        end

        if disabled(profile, id) then
            enable(id)
            return
        end

        local selected = effective(rows, byID)

        if selected ~= id then
            p:ShowChoices(
                anchor,
                { { value = 'disable', text = L['Disable'] }, { value = 'select', text = L['Select'] } },
                function(value)
                    if value == 'disable' then
                        disable(id, nil, false)
                    elseif value == 'select' then
                        choose(id)
                    end
                end,
                true
            )

            return
        end

        local alternatives = {}

        for other, target in pairs(byID) do
            if other ~= id and target.available and not disabled(profile, other) then
                alternatives[#alternatives + 1] = { value = other, text = target.name }
            end
        end

        table.sort(alternatives, function(a, b) return a.value < b.value end)

        if #alternatives == 0 then
            disable(id, nil, true)
        elseif #alternatives == 1 then
            disable(id, alternatives[1].value, true)
        else
            p:ShowChoices(
                anchor,
                alternatives,
                function(other)
                    disable(id, other, true)
                end,
                true
            )
        end
    end

    -- Fetches the catalog status rows once for this drawing.
    -- @return table[]|nil  The rows; nil if the drawing went stale.
    local function inventoryRows()
        local list = self.ListIntegrationStatus

        if not current() then
            return
        end

        local result = type(list) == 'function' and list(self) or {}

        if current() then
            return result
        end
    end

    local rows, byID, native = editors()

    if not rows or not current() then
        return
    end

    local inventory = inventoryRows()

    if not inventory then
        return
    end

    local metadata = {}

    for _, entry in ipairs(inventory) do
        local allowed = supported(entry.id)

        if not current() then
            return
        end

        if allowed then
            metadata[entry.id] = entry
        end
    end

    local selected = effective(rows, byID)

    -- Builds the card model for an editor row (Native or a provider): description, version and state (missing,
    -- disabled, selected or enabled) and the click action.
    -- @param row table  The editor row { id, name, available }.
    -- @return table  The card model.
    local function editorRow(row)
        local entry = metadata[row.id == 'LuaWorkbench' and '!!!LuaWorkbench' or row.id]

        return {
            id = 'editor_' .. row.id,
            name = row.name,
            version = row.id == 'native' and '' or versionFor(entry),
            description = row.id == 'native' and L['Built-in Lua editor.']
                or entry and entry.detail
                or L['Registered Lua editor provider.'],
            state = not row.available and 'missing'
                or disabled(profile, row.id) and 'disabled'
                or selected == row.id and 'selected'
                or 'enabled',
            action = row.available and function(anchor)
                editorAction(row.id, anchor)
            end or nil,
            entry = entry,
            help = row.id == 'native' and 'Help.Integrations.native_highlighting' or nil,
            native = row.id == 'native',
        }
    end

    local editorRows = { editorRow(native) }

    for _, row in ipairs(rows) do
        editorRows[#editorRows + 1] = editorRow(row)
    end

    -- Builds the card model for a catalog addon: a not-loaded or unknown addon shows "Not loaded", everything else
    -- "Supported", with no action.
    -- @param entry table  The catalog row.
    -- @return table  The card model.
    local function readonly(entry)
        return {
            id = entry.id,
            name = entry.name,
            version = versionFor(entry),
            description = entry.detail or '',
            state = (entry.state == 'missing' or entry.state == 'unknown') and 'missing' or 'supported',
            entry = entry,
        }
    end

    local groups = {
        {
            key = 'integrations_editors',
            title = L['Lua editor integrations'],
            rows = editorRows,
            editorSettings = true,
        },
    }

    -- Appends a section containing the cards of the listed addon ids that the catalog has for this client.
    -- @param key string  The section key.
    -- @param title string  The section title.
    -- @param ids string[]  The addon ids.
    local function group(key, title, ids)
        local list = {}

        for _, id in ipairs(ids) do
            if metadata[id] then
                list[#list + 1] = readonly(metadata[id])
            end
        end

        groups[#groups + 1] = { key = key, title = title, rows = list }
    end

    group('integrations_conditions', L['Condition data'], { 'ExtendedCharacterStats', 'MobInfo2' })
    group('integrations_notifications', L['Recommendation notifications'], { 'WeakAuras', 'ForeverAuras' })
    local questieAllowed = supported('Questie')

    if not current() then
        return
    end

    if questieAllowed then
        local questie = metadata.Questie or { id = 'Questie', name = L['Questie'], state = 'missing' }
        local questieRow = readonly(questie)

        if questieRow.state ~= 'missing' then
            questieRow.state = profile.questie_enabled == true and 'enabled' or 'disabled'

            -- Toggles the Questie integration if Questie is still loaded (re-checked against fresh catalog rows) and
            -- queues syncing it.
            questieRow.action = function()
                if not supported('Questie') or not current() then
                    return
                end

                local fresh = inventoryRows()

                if not fresh then
                    return
                end

                local loaded = false

                for _, entry in ipairs(fresh) do
                    if entry.id == 'Questie' then
                        loaded = entry.state ~= 'missing' and entry.state ~= 'unknown'
                    end
                end

                if not loaded then
                    return
                end

                profile.questie_enabled = not (profile.questie_enabled == true)

                p:RunSettingsEffect('questie', function()
                    self:SyncQuestieIntegration()
                end)

                p:Draw()
            end
        end

        groups[#groups + 1] = { key = 'integrations_quests', title = L['Quest callbacks'], rows = { questieRow } }
    end

    -- Boss mods: at most one is enabled; enabling one switches the other off.
    local encounterRows = {}

    for _, id in ipairs({ 'DBM-Core', 'BigWigs' }) do
        local allowed = supported(id)

        if not current() then
            return
        end

        if allowed then
            local entry = metadata[id] or { id = id, name = L[id == 'DBM-Core' and 'DBM' or id], state = 'missing' }
            local row = readonly(entry)
            local chosen = profile.encounter_provider == id

            local loaded = entry.loaded == true
                or entry.loaded == nil and entry.state ~= 'missing' and entry.state ~= 'unknown'

            row.state = not loaded and 'missing' or chosen and 'enabled' or 'disabled'

            if row.state ~= 'missing' or chosen then
                row.action = function()
                    if not supported(id) or not current() then
                        return
                    end

                    profile.encounter_provider = profile.encounter_provider ~= id and id or nil

                    p:RunSettingsEffect('encounter_provider', function()
                        self:SyncEncounterIntegration()
                    end)

                    p:Draw()
                end
            end

            encounterRows[#encounterRows + 1] = row
        end
    end

    if #encounterRows > 0 then
        groups[#groups + 1] = { key = 'integrations_encounters', title = L['Boss mods'], rows = encounterRows }
    end

    local masqueAllowed = supported('Masque')

    if not current() then
        return
    end

    if masqueAllowed then
        local entry = metadata.Masque or { id = 'Masque', name = L['Masque'], state = 'missing' }
        local row = readonly(entry)
        local enabled = profile.preview_masque == true

        local loaded = entry.loaded == true
            or entry.loaded == nil and entry.state ~= 'missing' and entry.state ~= 'unknown'

        row.state = not loaded and 'missing' or enabled and 'enabled' or 'disabled'

        if row.state ~= 'missing' or enabled then
            row.action = function()
                if not supported('Masque') or not current() then
                    return
                end

                profile.preview_masque = not (profile.preview_masque == true)

                p:RunSettingsEffect('preview_masque', function()
                    self:RefreshPreviewWindow()
                end)

                p:Draw()
            end
        end

        groups[#groups + 1] = { key = 'integrations_themes', title = L['Button skins'], rows = { row } }
    end

    group('integrations_panels', L['Top panels'], { 'Titan' })

    group('integrations_actionbars', L['Action bars'], {
        'ElvUI', 'Bartender4', 'ButtonForge', 'LUI', 'Dominos', 'AzeriteUI', 'AzeriteUI6', 'EllesmereUIActionBars',
        'FarmingBar', 'TotemTimers'
    })

    -- Measure shared columns once per drawing; description receives the remainder.
    p.width = math.max(340, p.frame:GetWidth() - 40)
    p.child:SetWidth(p.width)

    local measure = p:Acquire('integrationMeasure', function()
        return p.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    end)

    measure:SetWordWrap(false)
    measure:SetWidth(0)

    -- Measures the pixel width of a text in the page font, using the hidden measuring string.
    -- @param text string|nil  The text.
    -- @return number  The width in pixels.
    local function width(text)
        measure:SetText(text or '')
        return measure:GetStringWidth()
    end

    local labels = {
        missing = L['Not loaded'],
        supported = L['Supported'],
        disabled = L['Disabled'],
        enabled = L['Enabled'],
        selected = L['Selected'],
    }

    local nameWidth, versionWidth, statusWidth = width(L['Addon']) + 24, width(L['Version']), width(L['Status']) + 16

    for _, label in pairs(labels) do
        statusWidth = math.max(statusWidth, width(label) + 18)
    end

    for _, section in ipairs(groups) do
        for _, row in ipairs(section.rows) do
            nameWidth = math.max(nameWidth, width(row.name) + 24)
            versionWidth = math.max(versionWidth, width(row.version))
        end
    end

    measure:SetText('')
    measure:Hide()
    local usable = p.width - 20
    local gap = 8
    statusWidth = math.min(statusWidth, usable * .28)
    nameWidth = math.min(nameWidth, usable * .30)
    versionWidth = math.min(versionWidth, usable * .16)
    local descWidth = usable - nameWidth - versionWidth - statusWidth - gap * 3
    local positions = { 10, 10 + nameWidth + gap, 10 + nameWidth + versionWidth + gap * 2, p.width - 10 - statusWidth }
    local widths = { nameWidth, versionWidth, descWidth, statusWidth }

    -- Positions a pooled wrapped text label at x, y with width w inside a parent, sized to its text.
    -- @param kind string  The pool name.
    -- @param parent table  The frame the label is parented to.
    -- @param text string|nil  The text.
    -- @param x number  The left offset.
    -- @param y number  The top offset (positive down).
    -- @param w number  The width.
    -- @return table  The font string.
    local function label(kind, parent, text, x, y, w)
        local c = p:Acquire(kind, function()
            local f = p.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            f:SetJustifyH('LEFT')
            f:SetJustifyV('TOP')
            return f
        end)

        c:SetParent(parent)
        c:ClearAllPoints()
        c:SetPoint('TOPLEFT', x, -y)
        c:SetWidth(math.max(1, w))
        c:SetWordWrap(true)

        if c.SetNonSpaceWrap then
            c:SetNonSpaceWrap(true)
        end
        if c.SetMaxLines then
            c:SetMaxLines(0)
        end

        c:SetText(text or '')
        c:SetTextColor(.9, .92, .94)
        c:SetHeight(0)
        c:SetHeight(math.max(18, c:GetStringHeight()))
        return c
    end

    -- Draws one card: a name (a link button when the catalog has a project URL), version, description, status pill (a
    -- button when the row has an action) and, for the Native row, its help button and Syntax highlighting checkbox.
    -- Advances p.y past the card.
    -- @param row table  The card model.
    local function draw(row)
        local top = p.y

        local frame = p:Acquire('integrationCards', function()
            local c = CreateFrame('Frame', nil, p.child)
            c:EnableMouse(false)
            c.decoration = addon:CreateRoundedCardDecoration(c)
            c.decoration:SetColors(.35, .4, .44, .65, .08)
            return c
        end)

        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', 0, -top)
        frame:SetWidth(p.width)
        p.fields['integration_card_' .. row.id] = frame

        local name = p:Acquire('integrationNames', function()
            return addon:CreateWorkbenchButton(p.child, '', nameWidth - 24)
        end)

        name:SetParent(frame)
        name:ClearAllPoints()
        name:SetPoint('TOPLEFT', positions[1], -10)
        name:SetWidth(math.max(1, nameWidth - 24))
        name.art:Hide()
        name:SetText(row.name)
        local caption = name:GetFontString()
        caption:ClearAllPoints()
        caption:SetPoint('TOPLEFT')
        caption:SetWidth(math.max(1, nameWidth - 24))
        caption:SetJustifyH('LEFT')
        caption:SetJustifyV('TOP')
        caption:SetWordWrap(true)
        name:SetHeight(math.max(18, caption:GetStringHeight()))
        name:Disable()
        name:SetAlpha(1)
        caption:SetTextColor(.9, .92, .94)
        addon:SetUIScript(name, 'OnClick', nil)
        p.fields['integration_name_' .. row.id] = name

        if row.entry and type(row.entry.projectURL) == 'string' and row.entry.projectURL ~= '' then
            local id = row.entry.id
            name:Enable()
            caption:SetTextColor(.35, .7, 1)

            addon:SetUIScript(name, 'OnClick', p:Guard(function()
                local show = self.ShowIntegrationProjectLink

                if current() and type(show) == 'function' then
                    show(self, id)
                end
            end))
        end

        local version = label('integrationLabels', frame, row.version or '', positions[2], 10, versionWidth)
        local description = label('integrationLabels', frame, row.description, positions[3], 10, descWidth)

        local pill = p:Acquire('integrationPills', function()
            return addon:CreateWorkbenchPill(p.child, '', statusWidth)
        end)

        pill:SetParent(frame)
        pill:ClearAllPoints()
        pill:SetPoint('TOPLEFT', positions[4], -10)
        pill:SetWidth(statusWidth)
        pill:SetText(labels[row.state])
        pill:Enable()
        local color = colors[row.state]
        pill:SetAccent(color[1], color[2], color[3])
        pill:SetSelected(true)
        p.fields['integration_status_' .. row.id] = pill

        addon:SetUIScript(
            pill,
            'OnClick',
            row.action and p:Guard(function()
                if p:FlushEdits() and current() then
                    row.action(pill)
                end
            end) or nil
        )

        if not row.action then
            pill:Disable()
            pill:SetAlpha(1)
        end

        local height = math.max(38, name:GetHeight() + 20, version:GetHeight() + 20, description:GetHeight() + 20)
        local contentTop = height

        if row.help then
            local help = p:Acquire('integrationHelp', function()
                return addon:CreateWorkbenchHelpButton(p.child, L['Help'])
            end)

            help:SetParent(frame)
            help:ClearAllPoints()
            help:SetSize(20, 20)
            help.icon:SetSize(18, 18)

            help:SetPoint(
                'TOPLEFT',
                positions[4] + statusWidth - 20,
                -(row.native and contentTop or 10 + pill:GetHeight() + 6)
            )

            help:Enable()
            p.fields['integration_help_' .. row.id] = help

            addon:SetUIScript(help, 'OnClick', p:Guard(function()
                local show = self.ShowWorkbenchHelp

                if current() and type(show) == 'function' then
                    show(self, row.name, { { title = row.name, text = L[row.help] } }, p.frame)
                end
            end))

            height = math.max(height, (row.native and contentTop or 10 + pill:GetHeight() + 6) + 20 + 6)
        end

        if row.native then
            local surface, available = p.surface, p.width
            p.surface = frame
            p.width = available - 20 - (row.help and 28 or 0)
            p.y = contentTop

            -- Stores the Syntax highlighting choice and, when Native is the active editor, switches between native and
            -- plain, then redraws.
            -- @param value boolean  The new state.
            local syntax = p:Check('lua_native_highlighting', L['Syntax highlighting'], highlighting(profile), function(
                value
            )
                local liveRows, liveByID = editors()

                if not liveRows or not current() then
                    return
                end

                local active = effective(liveRows, liveByID)
                profile.lua_native_highlighting = value == true

                if active == 'native' then
                    profile.lua_editor = value and 'native' or 'plain'
                end

                p:Draw()
            end)

            syntax:ClearAllPoints()
            syntax:SetPoint('TOPLEFT', 10, -contentTop)
            height = math.max(height, contentTop + 34)
            p.surface = surface
            p.width = available
        end

        frame:SetHeight(height)
        p.y = top + height + 10
    end

    for _, section in ipairs(groups) do
        if #section.rows > 0 then
            -- Draws a section's body: the line numbers check box for the editor section, the column headings and one
            -- card per row.
            p:Section(section.key, section.title, function()
                if section.editorSettings then
                    p:Check('lua_line_numbers', L['Show line numbers'], profile.lua_line_numbers ~= false, function(
                        value
                    )
                        profile.lua_line_numbers = value
                    end)
                end

                local height = 22

                for i, text in ipairs({ L['Addon'], L['Version'], L['Description'], L['Status'] }) do
                    local c = label('integrationHeadings', p.child, text, positions[i], p.y, widths[i])
                    height = math.max(height, c:GetHeight() + 6)
                end

                p.y = p.y + height

                for _, row in ipairs(section.rows) do
                    draw(row)
                end
            end)
        end
    end
end
