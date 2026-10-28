-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Tooltip integration (details below): adds Rotation Master lines to spell and item tooltips. It only appends lines,
-- never reads or changes anything else on the tooltip, and builds its indexes lazily and never in combat. Loaded last
-- of the Core files, after Core/assisted_highlight.lua; it installs itself at the first PLAYER_ENTERING_WORLD.
-- Reads settings from the profile (tooltip_* keys) and the rotation roster through addon:ListRotationHeaders.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Tooltip integration: item tooltips name the Rotation Master item sets that
-- contain the item, and spell and item tooltips name the rotations that use
-- it. Lines are only ever appended (never read), so the Midnight secret-value
-- and taint rules are not in play; the spell or item ID comes from the
-- structured tooltip data (or, where the client has only the older script
-- handlers, from GetItem/GetSpell) and is checked readable before use.
--
-- Settings (profile): tooltips (master, on), tooltip_itemsets (on),
-- tooltip_rotations (on), tooltip_disabled_rotations (on: list rotations that
-- are switched off, grayed and marked; off hides them),
-- tooltip_conditions (off: also count spells and items a condition refers
-- to), tooltip_exclude_disabled_conditions (off: when on, a condition that is
-- switched off in the editor - a node with disabled == true, with everything
-- under it - is not counted), tooltip_limit (names listed, default 3).
--
-- Two registration paths, chosen by the tooltip object and not by the client
-- name, because the processor global exists on every client but only the
-- mainline GameTooltip is built on it (Blizzard_GameTooltip Mainline mixes in
-- TooltipDataHandlerMixin; the Classic one still fires OnTooltipSetItem and
-- OnTooltipSetSpell and never calls the processor):
--   * GameTooltip.ProcessInfo exists  -> TooltipDataProcessor.AddTooltipPostCall
--   * otherwise                       -> GameTooltip:HookScript on the scripts
--
-- Cost: nothing is registered while the master switch is off at login. After
-- that a hook is one settings read. The indexes are built lazily, out of
-- combat only, on the first relevant tooltip after something changed; in
-- combat the previous index (or nothing) is served and nothing is rebuilt.
-- A failure in the callback is reported through the error collector and
-- retires the feature for the session.

local manager = { installed = false, mode = nil, failed = false, itemData = 0, spellData = 0 }
addon.TooltipIntegration = manager

-- ============================================================================
-- Settings and helpers
-- ============================================================================

local DEFAULT_LIMIT, MIN_LIMIT, MAX_LIMIT = 3, 1, 20
-- A rotation edit does not move the dependency stamp, so the rotation roster
-- stamp is re-read at most this often (seconds) while tooltips keep coming.
local ROSTER_RECHECK = 1
-- Item names that are not cached yet are retried at most this often.
local INCOMPLETE_RETRY = 5
local MAX_CONDITION_DEPTH, MAX_CONDITION_NODES = 32, 4096
local CYAN, GREY, RESET = '|cff33ccff', '|cff8c8c8c', '|r'
local CONTEXT = { module = 'tooltips', operation = 'append' }

-- Why a Built In is left out: it is not for this client, class or
-- specialization at all (the Rotations list shows the same packs for the
-- class, minus the other specializations' when filtered to yours).
local HIDDEN_BUILTIN = {
    ['edition-mismatch'] = true,
    ['expansion-mismatch'] = true,
    ['build-mismatch'] = true,
    ['class-mismatch'] = true,
    ['invalid-or-unsupported'] = true,
    ['specialization-mismatch'] = true,
}

-- Conditions whose spell/item field is not something a player hovers.
local SKIP_CONDITION = { GLYPH = true, TALENT = true, RUNE_ENGRAVED = true, BOSSMOD_TIMER = true }

-- Returns the active profile table, or nil before the database exists.
local function profile()
    local db = addon.db
    return type(db) == 'table' and type(db.profile) == 'table' and db.profile or nil
end

-- True when the value may be used: a secret value (restricted clients) is refused, through Platform:CanReadValue when
-- it exists.
local function readable(value)
    local platform = addon.Platform

    if type(platform) ~= 'table' or type(platform.CanReadValue) ~= 'function' then
        return type(issecretvalue) ~= 'function' or not issecretvalue(value)
    end

    return platform:CanReadValue(value) == true
end

-- True in combat lockdown; an unreadable answer counts as combat so nothing is rebuilt then.
local function inCombat()
    if type(InCombatLockdown) ~= 'function' then
        return false
    end

    local ok, locked = pcall(InCombatLockdown)
    return not ok or (locked ~= false and locked ~= nil)
end

-- Returns the game time in seconds, or 0 where GetTime is missing.
local function now()
    return type(GetTime) == 'function' and GetTime() or 0
end

-- Reads the tooltip settings from the profile (or `source`), without building a table: this runs per tooltip.
-- @param source table|nil  a profile-shaped table to read instead of the active profile
-- @return boolean  master switch
-- @return boolean  list item sets (always false when the master is off)
-- @return boolean  list rotations (always false when the master is off)
-- @return boolean  also count spells and items named only inside conditions
-- @return number  names listed per line (1 to 20)
-- @return boolean  list rotations that are switched off (default true)
-- @return boolean  leave disabled conditions out of the condition counts (default false)
local function readSettings(source)
    local p = source or profile()

    if type(p) ~= 'table' then
        return false, false, false, false, DEFAULT_LIMIT, true, false
    end

    local master = p.tooltips ~= false
    local limit = tonumber(p.tooltip_limit)

    if not limit or limit ~= limit then
        limit = DEFAULT_LIMIT
    end

    limit = math.max(MIN_LIMIT, math.min(MAX_LIMIT, math.floor(limit)))

    return master,
        master and p.tooltip_itemsets ~= false,
        master and p.tooltip_rotations ~= false,
        p.tooltip_conditions == true,
        limit,
        p.tooltip_disabled_rotations ~= false,
        p.tooltip_exclude_disabled_conditions == true
end

-- Returns the tooltip settings for the settings page.
-- @param source table|nil  a profile-shaped table to read instead of the active profile
-- @return table  { enabled, itemsets, rotations, conditions, limit, disabledRotations, excludeDisabledConditions }
function addon:GetTooltipSettings(source)
    local master, itemsets, rotations, conditions, limit, disabledRotations, excludeDisabled = readSettings(source)

    return {
        enabled = master,
        itemsets = itemsets,
        rotations = rotations,
        conditions = conditions,
        limit = limit,
        disabledRotations = disabledRotations,
        excludeDisabledConditions = excludeDisabled,
    }
end

-- Returns the value as a positive whole number (a numeric string is accepted), or nil.
local function wholeNumber(value)
    if type(value) == 'string' then
        value = tonumber(value)
    end

    if type(value) == 'number' and value == value and value > 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end

-- Returns the rotation validation stamp that tells when indexes are stale, or nil when it cannot be read.
local function validationStamp()
    local read = addon.GetRotationValidationStamp

    if type(read) ~= 'function' then
        return nil
    end

    local ok, stamp = pcall(read, addon)
    return ok and stamp or nil
end

-- ============================================================================
-- Item set index
-- ============================================================================

-- An item set or condition lists item IDs, links, "item:N" strings and, when
-- the player typed one, names. Names resolve only once the client has the
-- item cached; until then the index is marked incomplete and retried.
-- Returns the item ID for one entry, or nil (and marks state.incomplete when a name is not cached yet).
local function entryItemId(entry, state)
    if type(entry) == 'number' then
        return wholeNumber(entry)
    end
    if type(entry) ~= 'string' or entry == '' then
        return nil
    end

    local text = entry:match('item:(%d+)')

    if text then
        return wholeNumber(text)
    end

    local id = wholeNumber(entry)

    if id then
        return id
    end

    local platform = addon.Platform

    if type(platform) == 'table' and type(platform.GetItemID) == 'function' then
        local ok, resolved = pcall(platform.GetItemID, platform, entry)

        if ok and wholeNumber(resolved) then
            return resolved
        end
    end

    state.incomplete = true
end

-- Returns the per-profile and the shared item set tables (either may be nil).
local function setMaps()
    local db = addon.db

    if type(db) ~= 'table' then
        return nil, nil
    end

    local profileSets = type(db.profile) == 'table' and db.profile.itemsets or nil
    local globalSets = type(db.global) == 'table' and db.global.itemsets or nil
    return type(profileSets) == 'table' and profileSets or nil, type(globalSets) == 'table' and globalSets or nil
end

-- Calls callback(key, set) for every item set. Personal sets shadow shared sets with the same key.
local function eachSet(callback)
    local personal, shared = setMaps()

    if personal then
        for key, set in pairs(personal) do
            callback(key, set)
        end
    end

    if shared then
        for key, set in pairs(shared) do
            if not personal or rawget(personal, key) == nil then
                callback(key, set)
            end
        end
    end
end

-- Returns the item set stored under key, personal first, then shared.
local function resolveSet(key)
    local personal, shared = setMaps()
    local set = personal and rawget(personal, key)

    if set == nil and shared then
        set = rawget(shared, key)
    end

    return set
end

-- True for a usable item set: a table with a non-empty name and an item list.
local function validSet(set)
    return type(set) == 'table' and type(set.name) == 'string' and set.name ~= '' and type(set.items) == 'table'
end

-- item ID -> sorted list of set names.
-- Returns { byItem, incomplete, text }; text is a cache of the formatted lines, filled by manager:Lines.
local function buildSets()
    local byItem, state = {}, { incomplete = false }
    local seen = {}

    eachSet(function(_, set)
        if not validSet(set) then
            return
        end

        for _, entry in ipairs(set.items) do
            local id = entryItemId(entry, state)

            if id then
                local names = byItem[id]

                if not names then
                    names = {}
                    byItem[id] = names
                    seen[id] = {}
                end

                if not seen[id][set.name] then
                    seen[id][set.name] = true
                    names[#names + 1] = set.name
                end
            end
        end
    end)

    for _, names in pairs(byItem) do
        table.sort(names, function(a, b)
            local x, y = a:lower(), b:lower()

            if x == y then
                return a < b
            end

            return x < y
        end)
    end

    return { byItem = byItem, incomplete = state.incomplete, text = {} }
end

-- ============================================================================
-- Rotation use index
-- ============================================================================

-- Appends an entry to the list stored under id, creating the list when needed.
local function addEntry(map, id, entry)
    local list = map[id]

    if not list then
        list = {}
        map[id] = list
    end

    list[#list + 1] = entry
end

-- The item IDs an item reference stands for: an item set key or a list. Returns a list, or nil when there are none.
local function referenceItems(reference, state)
    local list = reference

    if type(reference) == 'string' then
        local set = resolveSet(reference)
        list = validSet(set) and set.items or nil
    end

    local ids

    if type(list) == 'table' then
        for _, entry in ipairs(list) do
            local id = entryItemId(entry, state)

            if id then
                ids = ids or {}
                ids[#ids + 1] = id
            end
        end
    elseif type(list) == 'number' then
        local id = wholeNumber(list)

        if id then
            ids = { id }
        end
    end

    return ids
end

-- Add the rotation's references. includeConditions: also those inside conditions; excludeDisabled: not those under a
-- condition node that is switched off (`disabled == true`, which the evaluator treats as always true and the
-- description prints as nothing, so its subtree never runs).
-- Only steps that can run (reachable and enabled) count. The condition walk is bounded in depth and node count.
local function indexBody(body, ref, index, includeConditions, state, excludeDisabled)
    local data = addon.RotationData

    if type(data) ~= 'table' or type(data.IndexRotationSteps) ~= 'function' or type(body) ~= 'table' then
        return
    end

    local ok, tree = pcall(data.IndexRotationSteps, body, { allowMissingIds = true, allowUnknownBranchFields = true })

    if not ok or type(tree) ~= 'table' or type(tree.rows) ~= 'table' then
        return
    end

    local budget = MAX_CONDITION_NODES
    local walk

    -- Collects the spells and items a condition tree names, skipping condition types whose field is not hoverable.
    walk = function(node, depth)
        if type(node) ~= 'table' or depth > MAX_CONDITION_DEPTH or budget <= 0 then
            return
        end

        budget = budget - 1

        if excludeDisabled and node.disabled == true then
            return
        end

        local kind = node.type

        if kind == 'AND' or kind == 'OR' then
            if type(node.value) == 'table' then
                for _, child in ipairs(node.value) do
                    walk(child, depth + 1)
                end
            end
        elseif kind == 'NOT' then
            walk(node.value, depth + 1)
        elseif not SKIP_CONDITION[kind] then
            local spell = wholeNumber(node.spell)

            if spell then
                addEntry(index.spells, spell, { rotation = ref, condition = true })
            end

            if node.item ~= nil then
                local ids = referenceItems(node.item, state)

                if ids then
                    for _, id in ipairs(ids) do
                        addEntry(index.items, id, { rotation = ref, condition = true })
                    end
                end
            end
        end
    end

    for _, row in ipairs(tree.rows) do
        local step = row.step

        if type(step) == 'table' and not row.unreachable and not step.disabled then
            local kind = step.type

            if kind == 'spell' or kind == 'pet' or kind == 'any' then
                local spell = wholeNumber(step.action)

                if spell then
                    addEntry(index.spells, spell, { rotation = ref, ranked = step.ranked == true })
                end
            elseif kind == 'item' then
                local ids = referenceItems(step.action, state)

                if ids then
                    for _, id in ipairs(ids) do
                        addEntry(index.items, id, { rotation = ref })
                    end
                end
            end

            if includeConditions then
                walk(step.conditions, 0)
            end
        end
    end
end

-- Returns the rotation name as shown elsewhere (Built In names are localized); never empty.
local function displayName(name)
    local shown = type(addon.RotationDisplayName) == 'function' and addon:RotationDisplayName(name) or name

    if type(shown) ~= 'string' or shown == '' then
        shown = name
    end

    return type(shown) == 'string' and shown ~= '' and shown or L['Unnamed rotation']
end

-- spell ID / item ID -> list of {rotation={name,enabled,priority},ranked,condition}.
-- `options` is { conditions, disabledRotations, excludeDisabledConditions }; a rotation that is switched off is left
-- out entirely when disabledRotations is false.
local function buildUses(rows, options, spec)
    local includeConditions = options.conditions
    local index = { spells = {}, items = {}, spellText = {}, itemText = {}, incomplete = false }
    local state = { incomplete = false }
    local seen = {}

    -- Adds one rotation body to the index under a reference carrying its name, enabled state and priority.
    local function refer(name, enabled, priority, body)
        if type(body) ~= 'table' or not enabled and not options.disabledRotations then
            return
        end

        local ref = {
            name = displayName(name),
            enabled = enabled,
            priority = type(priority) == 'number' and priority or 0,
        }

        indexBody(body, ref, index, includeConditions, state, options.excludeDisabledConditions)
    end

    for _, row in ipairs(rows or {}) do
        if
            type(row) == 'table'
            and row.kind == 'custom'
            and not row.pending
            and not row.virtual
            and row.validationState ~= 'pending'
            and not seen[row.key]
        then
            seen[row.key] = true

            local specsOk = row.fallback or type(addon.RotationSpecsApply) ~= 'function' or addon:RotationSpecsApply(
                row.specs,
                spec
            )

            if specsOk then
                local ok, record = pcall(addon.GetRotationRecordSnapshot, addon, spec, row.key)

                if ok and type(record) == 'table' then
                    refer(row.name, row.enabled ~= false, row.priority, record.body)
                end
            end
        end
    end

    if type(addon.GetBuiltinStates) == 'function' then
        local ok, builtins = pcall(addon.GetBuiltinStates, addon, spec)

        if ok and type(builtins) == 'table' then
            for _, entry in ipairs(builtins) do
                if type(entry) == 'table' and not HIDDEN_BUILTIN[entry.reason] and entry.state ~= 'invalid' then
                    local priority = type(entry.body) == 'table' and entry.body.priority or 0
                    refer(entry.name, entry.state == 'enabled', priority, entry.body)
                end
            end
        end
    end

    index.incomplete = state.incomplete
    return index
end

-- ============================================================================
-- Index lifetime
-- ============================================================================

-- Sets: rebuilt when the dependency stamp (the existing item set / condition
-- invalidation) or the profile changes.
function manager:Sets()
    local db = addon.db
    local current = self.sets
    local stamp = validationStamp()
    local profileTable = type(db) == 'table' and db.profile or nil
    local fresh = current and current.stamp == stamp and current.profile == profileTable

    if
        fresh and current.incomplete and self.itemData ~= current.itemData and now() - current.built >= INCOMPLETE_RETRY
    then
        fresh = false
    end

    if fresh or inCombat() then
        return current
    end

    local built = buildSets()
    built.stamp, built.profile, built.itemData, built.built = stamp, profileTable, self.itemData, now()
    self.sets = built
    return built
end

-- Uses: the same, plus the current specialization, the condition and disabled
-- settings and the rotation roster stamp (a rotation edit moves neither of the
-- others).
-- @param includeConditions boolean  also index what conditions name
-- @param disabledRotations boolean|nil  index rotations that are switched off (nil counts as true, today's output)
-- @param excludeDisabled boolean|nil  leave disabled conditions out (nil counts as false)
-- @return table|nil  the current index, rebuilt when stale, or the previous one (possibly nil) in combat or when the
--   rotation list is not ready
function manager:Uses(includeConditions, disabledRotations, excludeDisabled)
    disabledRotations = disabledRotations ~= false
    excludeDisabled = excludeDisabled == true
    local current = self.uses
    local spec = addon.currentSpec
    local stamp = validationStamp()
    local profileTable = type(addon.db) == 'table' and addon.db.profile or nil

    local fresh = current
        and current.stamp == stamp
        and current.profile == profileTable
        and current.spec == spec
        and current.conditions == includeConditions
        and current.disabledRotations == disabledRotations
        and current.excludeDisabled == excludeDisabled

    if
        fresh and current.incomplete and self.itemData ~= current.itemData and now() - current.built >= INCOMPLETE_RETRY
    then
        fresh = false
    end

    if inCombat() then
        return current
    end
    if spec == nil or type(addon.ListRotationHeaders) ~= 'function' then
        return current
    end

    local rows, roster
    local time = now()

    if fresh and time - current.checked < ROSTER_RECHECK then
        return current
    end

    local ok
    ok, rows, roster = pcall(addon.ListRotationHeaders, addon, spec)

    if not ok or type(rows) ~= 'table' then
        -- Not ready (profile not bound yet): keep what we have, ask again soon.
        if current then
            current.checked = time
        end

        return current
    end

    if fresh and current.roster == roster then
        current.checked = time
        return current
    end

    local built = buildUses(
        rows,
        {
            conditions = includeConditions,
            disabledRotations = disabledRotations,
            excludeDisabledConditions = excludeDisabled,
        },
        spec
    )

    built.stamp, built.profile, built.spec, built.conditions, built.roster =
        stamp, profileTable, spec, includeConditions, roster

    built.disabledRotations, built.excludeDisabled = disabledRotations, excludeDisabled

    built.itemData, built.built, built.checked = self.itemData, time, time
    self.uses = built
    return built
end

-- ============================================================================
-- Lookups and lines
-- ============================================================================

-- Sort order for the rotations listed on a tooltip: enabled first, then higher priority, then name.
local function byWeight(a, b)
    if a.enabled ~= b.enabled then
        return a.enabled
    end
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end

    local x, y = a.name:lower(), b.name:lower()

    if x ~= y then
        return x < y
    end

    return a.name < b.name
end

-- Returns the rotations (each once, in tooltip order) that use any candidate ID, or nil when none do. Condition-only
-- uses count only when includeConditions is set, and a ranked step is not matched through another rank.
local function collect(index, candidates, includeConditions)
    local found, seen

    for _, candidate in ipairs(candidates) do
        local list = index[candidate.id]

        if list then
            for _, entry in ipairs(list) do
                if (includeConditions or not entry.condition) and not (candidate.rank and entry.ranked) then
                    seen = seen or {}
                    found = found or {}

                    if not seen[entry.rotation] then
                        seen[entry.rotation] = true
                        found[#found + 1] = entry.rotation
                    end
                end
            end
        end
    end

    if found then
        table.sort(found, byWeight)
    end

    return found
end

-- The IDs a hovered spell stands for: itself, the spells the client relates
-- it to (base and override: a talent can swap one for the other), and on
-- clients with spell ranks every rank of it (a step that asks for an exact
-- rank is not matched through a rank).
local function spellCandidates(id)
    local list, seen = { { id = id } }, { [id] = true }
    local relatives = addon.GetSpellIdRelatives

    if type(relatives) == 'function' then
        local ok, ids = pcall(relatives, addon, id)

        if ok and type(ids) == 'table' then
            for _, related in ipairs(ids) do
                if wholeNumber(related) and not seen[related] then
                    seen[related] = true
                    list[#list + 1] = { id = related }
                end
            end
        end
    end

    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
        local catalog = addon.SpellCatalog

        if type(catalog) == 'table' and type(catalog.GetAllSpellIds) == 'function' then
            local ok, ids = pcall(catalog.GetAllSpellIds, catalog, id)

            if ok and type(ids) == 'table' then
                for _, rank in ipairs(ids) do
                    if wholeNumber(rank) and not seen[rank] then
                        seen[rank] = true
                        list[#list + 1] = { id = rank, rank = true }
                    end
                end
            end
        end
    end

    return list
end

-- Doubles pipe characters so a rotation or set name cannot inject a color code or hyperlink into the tooltip.
local function escape(name)
    return (name:gsub('|', '||'))
end

-- "Label: A, B, C (+2 more)"; names already formatted, total counts them all.
local function line(label, names, total)
    local text = table.concat(names, ', ')

    if total > #names then
        text = text .. ' ' .. string.format(L['(+%d more)'], total - #names)
    end

    return CYAN .. label .. ':' .. RESET .. ' ' .. text
end

-- Formats the "Rotation Master rotations" line; disabled rotations are grayed and marked.
local function rotationLine(found, limit)
    local names = {}

    for i = 1, math.min(#found, limit) do
        local rotation = found[i]
        local name = escape(rotation.name)
        names[i] = rotation.enabled and name or GREY .. string.format(L['%s (disabled)'], name) .. RESET
    end

    return line(L['Rotation Master rotations'], names, #found)
end

-- Formats the "Rotation Master item sets" line.
local function setLine(found, limit)
    local names = {}

    for i = 1, math.min(#found, limit) do
        names[i] = escape(found[i])
    end

    return line(L['Rotation Master item sets'], names, #found)
end

-- The lines for one hovered spell or item (cached per index until it is replaced).
-- `kind` is 'item' or 'spell'. Returns a list of lines, or nil when there is nothing to add.
function manager:Lines(kind, id)
    local master, wantSets, wantRotations, includeConditions, limit, disabledRotations, excludeDisabled = readSettings()

    if not master or not (wantSets or wantRotations) then
        return nil
    end

    local lines

    if kind == 'item' and wantSets then
        local sets = self:Sets()

        if sets then
            local text = sets.text[id]

            if text == nil then
                local names = sets.byItem[id]
                text = names and setLine(names, limit) or false
                sets.text[id] = text
            end

            if text then
                lines = { text }
            end
        end
    end

    if wantRotations then
        local uses = self:Uses(includeConditions, disabledRotations, excludeDisabled)

        if uses then
            local cache = kind == 'item' and uses.itemText or uses.spellText
            local text = cache[id]

            if text == nil then
                local found

                if kind == 'item' then
                    found = collect(uses.items, { { id = id } }, includeConditions)
                else
                    found = collect(uses.spells, spellCandidates(id), includeConditions)
                end

                text = found and rotationLine(found, limit) or false
                cache[id] = text
            end

            if text then
                lines = lines or {}
                lines[#lines + 1] = text
            end
        end
    end

    return lines
end

-- ============================================================================
-- Appending to tooltips
-- ============================================================================

-- Adds this module's lines for the hovered thing to the tooltip. Returns how many lines were added.
local function append(tooltip, kind, id)
    local lines = manager:Lines(kind, id)

    if not lines then
        return 0
    end

    for _, text in ipairs(lines) do
        tooltip:AddLine(text, 1, 1, 1, true)
    end

    return #lines
end

-- Runs fn through the diagnostics collector (else pcall). An error retires the feature for the session so a broken
-- tooltip hook cannot repeat. Returns the number of lines fn added.
local function guarded(fn, ...)
    if manager.failed then
        return 0
    end

    local diagnostics = addon.Diagnostics
    local ok, added

    if type(diagnostics) == 'table' and type(diagnostics.Call) == 'function' then
        ok, added = diagnostics:Call(CONTEXT, fn, ...)
    else
        ok, added = pcall(fn, ...)
    end

    if not ok then
        manager.failed = true
        return 0
    end

    return added or 0
end

-- True for the two tooltips this module decorates (GameTooltip and ItemRefTooltip).
local function watched(tooltip)
    return tooltip ~= nil and (tooltip == GameTooltip or tooltip == ItemRefTooltip)
end

-- True when the tooltip is forbidden to addons (or the check fails); such a tooltip must not be touched.
local function forbidden(tooltip)
    if type(tooltip) ~= 'table' or type(tooltip.IsForbidden) ~= 'function' then
        return false
    end

    local ok, value = pcall(tooltip.IsForbidden, tooltip)
    return not ok or value == true
end

-- Structured path (mainline GameTooltip): the processor hands over the data.
-- `data.id` is a game value, so it is checked readable before use.
function manager:OnProcessed(tooltip, kind, data)
    local master, wantSets, wantRotations = readSettings()

    if not master or not (wantSets or wantRotations) or self.failed then
        return
    end
    if not watched(tooltip) or type(data) ~= 'table' or not readable(data) then
        return
    end

    local id = data.id

    if type(id) ~= 'number' or not readable(id) or id ~= id or id <= 0 or id % 1 ~= 0 then
        return
    end
    if forbidden(tooltip) then
        return
    end

    guarded(append, tooltip, kind, id)
end

-- Script path (Classic): the tooltip knows what it shows.
-- Tooltips already decorated since they were last cleared; weak keys so a discarded tooltip is not retained.
local shown = setmetatable({}, { __mode = 'k' })

-- Handler for the Classic OnTooltipSetItem/Spell scripts. Reads the ID from the tooltip itself, appends once per
-- display (the shown flag), and re-shows the tooltip so it resizes to fit the new line.
function manager:OnScript(tooltip, kind)
    local master, wantSets, wantRotations = readSettings()

    if not master or not (wantSets or wantRotations) or self.failed then
        return
    end
    if not watched(tooltip) or shown[tooltip] or forbidden(tooltip) then
        return
    end

    local id

    if kind == 'item' then
        local getter = tooltip.GetItem

        if type(getter) ~= 'function' then
            return
        end

        local _, link = getter(tooltip)

        if type(link) ~= 'string' or not readable(link) then
            return
        end

        id = wholeNumber(link:match('item:(%d+)'))
    else
        local getter = tooltip.GetSpell

        if type(getter) ~= 'function' then
            return
        end

        local _, spell = getter(tooltip)

        if not readable(spell) then
            return
        end

        id = wholeNumber(spell)
    end

    if not id then
        return
    end

    shown[tooltip] = true

    if guarded(append, tooltip, kind, id) > 0 and type(tooltip.Show) == 'function' then
        tooltip:Show()
    end
end

-- ============================================================================
-- Installation
-- ============================================================================

-- Chooses how to hook tooltips: 'processor' (with the processor and tooltip type tables) when GameTooltip is built on
-- the data processor, 'scripts' when it only has HookScript, or nil when neither exists.
local function processorMode()
    local processor = TooltipDataProcessor
    local types = type(Enum) == 'table' and Enum.TooltipDataType or nil

    if
        type(processor) == 'table'
        and type(processor.AddTooltipPostCall) == 'function'
        and type(types) == 'table'
        and type(types.Item) == 'number'
        and type(types.Spell) == 'number'
        and type(GameTooltip) == 'table'
        and type(GameTooltip.ProcessInfo) == 'function'
    then
        return 'processor', processor, types
    end
    if type(GameTooltip) == 'table' and type(GameTooltip.HookScript) == 'function' then
        return 'scripts'
    end
end

-- Registers the hooks once for the mode processorMode chose. Returns true, or false and a reason.
function manager:Install()
    if self.installed then
        return true
    end

    local mode, processor, types = processorMode()

    if not mode then
        return false, 'no-tooltip-api'
    end

    if mode == 'processor' then
        local ok1 = pcall(processor.AddTooltipPostCall, types.Item, function(tooltip, data)
            manager:OnProcessed(tooltip, 'item', data)
        end)

        local ok2 = pcall(processor.AddTooltipPostCall, types.Spell, function(tooltip, data)
            manager:OnProcessed(tooltip, 'spell', data)
        end)

        if not (ok1 and ok2) then
            return false, 'registration-failed'
        end
    else
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if type(tooltip) == 'table' and type(tooltip.HookScript) == 'function' then
                pcall(tooltip.HookScript, tooltip, 'OnTooltipSetItem', function(self)
                    manager:OnScript(self, 'item')
                end)

                pcall(tooltip.HookScript, tooltip, 'OnTooltipSetSpell', function(self)
                    manager:OnScript(self, 'spell')
                end)

                pcall(tooltip.HookScript, tooltip, 'OnTooltipCleared', function(self)
                    shown[self] = nil
                end)
            end
        end
    end

    self.installed, self.mode = true, mode
    return true
end

-- ============================================================================
-- Settings and events
-- ============================================================================

local eventNames = { 'SPELLS_CHANGED', 'GET_ITEM_INFO_RECEIVED' }

-- Registers or unregisters the events that invalidate the indexes, only when the state changes.
function manager:SetEvents(active)
    local frame = self.frame

    if not frame or self.eventsActive == active then
        return
    end

    for _, event in ipairs(eventNames) do
        pcall(active and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
    end

    self.eventsActive = active
end

-- Drops both indexes; they are rebuilt on the next relevant tooltip.
function manager:Invalidate()
    self.sets, self.uses = nil, nil
end

-- Called at login, on a profile change and after a settings Apply.
function manager:Refresh()
    local master, wantSets, wantRotations = readSettings()
    local active = master and (wantSets or wantRotations)

    if active then
        if not self.installed then
            self:Install()
        end

        self:SetEvents(true)
    else
        self:SetEvents(false)
    end

    -- Settings the cached lines depend on may have changed (limit, conditions).
    self:Invalidate()
    return active == true
end

-- Public entry for the settings page: re-applies the settings. Returns true when the feature is active.
function addon:RefreshTooltipIntegration()
    return manager:Refresh()
end

local profileEvents = { 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }

-- Event handler: the first PLAYER_ENTERING_WORLD registers the profile callbacks and applies the settings; the
-- other events only mark cached data stale.
function manager:OnEvent(event)
    if event == 'PLAYER_ENTERING_WORLD' then
        if not self.ready then
            self.ready = true
            local db = addon.db

            if type(db) == 'table' and type(db.RegisterCallback) == 'function' then
                for _, name in ipairs(profileEvents) do
                    db.RegisterCallback(manager, name, function()
                        manager:Refresh()
                    end)
                end
            end
        end

        return self:Refresh()
    end

    if event == 'GET_ITEM_INFO_RECEIVED' then
        self.itemData = self.itemData + 1
    elseif event == 'SPELLS_CHANGED' then
        -- Base and override spells move with talents; the lines depend on them.
        local uses = self.uses

        if uses then
            uses.spellText = {}
        end
    end
end

if type(CreateFrame) == 'function' then
    local ok, frame = pcall(CreateFrame, 'Frame')

    if
        ok
        and type(frame) == 'table'
        and type(frame.RegisterEvent) == 'function'
        and type(frame.SetScript) == 'function'
    then
        manager.frame = frame

        frame:SetScript('OnEvent', function(_, event)
            manager:OnEvent(event)
        end)

        pcall(frame.RegisterEvent, frame, 'PLAYER_ENTERING_WORLD')
    end
end
