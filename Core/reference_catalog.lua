-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Reference providers for item, glyph and spell pickers: what a typed value resolves to, how a search matches, and what
-- name and icon to show. It owns the item metadata caches and nothing else; spell answers come from addon.SpellCatalog
-- (Core/spell_catalog.lua). Every game value is read through addon.Platform and checked with CanReadValue first.
-- Loaded from RotationMaster.toc after Core/spell_search.lua. The CPU ACTIVITY HANDOFF block at the end lets a CPU
-- capture count the caches and is verified by tests/cpu_retained_activity.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- ============================================================================
-- Value checks and presentation records
-- ============================================================================

-- Caches for item metadata. `items` holds the latest readable record per item id, `indexed` the last readable record
-- ever seen (it survives a transient miss), and `blocked` marks ids whose latest observation was a real failure.
local items, indexed, blocked = {}, {}, {}

-- True when the value may be inspected on this client (restricted-client rule); every game value is checked first.
local function readable(value)
    return addon.Platform:CanReadValue(value)
end

-- Normalizes a number or numeric string to a positive whole number id, or returns nil.
local function id(value)
    if not readable(value) or (type(value) ~= 'number' and type(value) ~= 'string') then
        return
    end

    local n = tonumber(value)

    if n and n > 0 and n < math.huge and n % 1 == 0 then
        return n
    end
end

-- Strips color escapes from a string so names and queries compare as plain text.
local function plain(value)
    return value:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
end

-- Returns the search text for a typed value: '' for nil, the digits of a valid id, or the plain text of a short string;
-- nil for anything else or unreadable input.
local function queryText(value)
    if not readable(value) then
        return
    end
    if value == nil then
        return ''
    end
    if type(value) == 'number' and id(value) then
        return tostring(value)
    end
    if type(value) == 'string' and #value <= 256 then
        return plain(value)
    end
end

-- True when the optional icon (texture id or path) and link are readable and well formed.
local function optionalFields(icon, link)
    if not readable(icon) or not readable(link) then
        return false
    end
    if
        icon ~= nil
        and not (type(icon) == 'string' and icon ~= ''
            or type(icon) == 'number' and icon >= 0 and icon < math.huge and icon % 1 == 0)
    then
        return false
    end
    if link ~= nil and (type(link) ~= 'string' or link == '') then
        return false
    end

    return true
end

-- Builds the row the pickers show for an item, or returns nil when the name or optional fields are not usable.
local function presentation(key, name, icon, link)
    if not readable(name) or not optionalFields(icon, link) then
        return
    end
    if type(name) ~= 'string' or name == '' then
        return
    end

    return { id = key, name = name, display = name, icon = icon, link = link }
end

-- ============================================================================
-- Item records and the inventory
-- ============================================================================

-- Returns a set of the item ids the player has: carried bags (addon.bagContents, kept by Core/inventory.lua) and the
-- equipped slots.
local function inventory()
    local result = {}
    local bags = addon.bagContents

    if readable(bags) and type(bags) == 'table' then
        for key, entry in pairs(bags) do
            local item = id(key)

            if item and readable(entry) then
                local count = type(entry) == 'table' and entry.count or entry

                if
                    readable(count) and type(count) == 'number' and count > 0 and count < math.huge and count % 1 == 0
                then
                    result[item] = true
                end
            end
        end
    end

    if type(GetInventoryItemID) == 'function' then
        for slot = 1, 19 do
            local ok, value = pcall(GetInventoryItemID, 'player', slot)
            local item = ok and id(value)

            if item then
                result[item] = true
            end
        end
    end

    return result
end

-- Looks one item up through the platform and updates the caches. Returns its presentation row, or nil when the value is
-- not an item id or the item is not (yet) known. A real failure blocks the id until a later observation succeeds; an
-- item whose data has not loaded keeps any earlier readable index entry.
local function itemInfo(value)
    local key = id(value)

    if not key then
        return
    end

    local info, reason = addon.Platform:GetItemDisplayInfo(key)
    local record = info and presentation(key, info.name, info.iconID, info.link)
    local invalid = info and not record or not info and reason ~= 'item-data-unavailable' and reason ~= 'missing-api'

    -- A failed/restricted observation cannot revive the old cached record or a
    -- same-ID indexed row. Unloaded metadata may use a prior readable index.
    if record then
        indexed[key] = record
    end

    items[key] = record
    blocked[key] = invalid or nil
    return record and presentation(key, record.name, record.icon, record.link)
end

-- Returns the id-to-row map the search matches against: everything indexed so far plus a fresh look at the owned and
-- blocked ids. Blocked ids are left out. `owned` is the inventory set, computed when not given.
local function indexedItems(owned)
    local result = {}

    for key, value in pairs(indexed) do
        result[key] = presentation(key, value.name, value.icon, value.link)
    end

    owned = owned or inventory()

    for key in pairs(owned) do
        itemInfo(key)
    end

    -- Nonowned indexed candidates need a fresh opportunity after transient
    -- native failures too; do not leave them hidden until an exact-ID lookup.
    for key in pairs(blocked) do
        if not owned[key] then
            itemInfo(key)
        end
    end

    for key, value in pairs(items) do
        result[key] = presentation(key, value.name, value.icon, value.link)
    end

    for key in pairs(blocked) do
        result[key] = nil
    end

    return result
end

-- Public entry that records an item's metadata in the caches (used when an item is first seen); returns its row or nil.
function addon:UpdateReferenceItem(value)
    return itemInfo(value)
end

-- Returns the settings table (an empty one for nil), or nil when it is unreadable or not a table.
local function options(settings)
    if settings == nil then
        return {}
    end
    if readable(settings) and type(settings) == 'table' then
        return settings
    end
end

-- Resolves typed text (id, item link, item: string, or exact name) to an item id. `accept` may veto an id by returning
-- false and a reason. Returns the id, or nil with a reason such as item-not-in-inventory, or nil alone when no item
-- matches.
local function itemResolve(input, settings, accept)
    settings = options(settings)
    local text = queryText(input)

    if not settings or not text then
        return
    end

    local key = id(text) or id(text:match('|Hitem:(%d+)')) or id(text:match('^item:(%d+)'))

    if not key then
        local value, reason = addon.Platform:GetItemID(input)

        if reason and reason ~= 'missing-api' and reason ~= 'item-data-unavailable' then
            return
        end

        key = id(value)
    end

    if not key then
        for item, record in pairs(indexedItems()) do
            if record.name:lower() == text:lower() and (not accept or accept(item)) then
                key = item
                break
            end
        end
    end

    if key and settings.inventory and not inventory()[key] then
        return nil, 'item-not-in-inventory'
    end

    if key then
        if accept then
            local allowed, reason = accept(key)

            if not allowed then
                return nil, reason
            end
        end

        itemInfo(key)
        return key
    end
end

-- Searches the indexed item names for a picker. Returns up to settings.limit (default 30, at most 100) rows sorted by
-- name, plus { coverage, more }; or nil and invalid-search-options / invalid-search-query. Only names the client has
-- already loaded can match, hence the coverage tag.
local function itemSearch(input, settings, accept)
    settings = options(settings)

    if not settings then
        return nil, 'invalid-search-options'
    end

    local limit = settings.limit or 30

    if not readable(limit) or type(limit) ~= 'number' or limit < 1 or limit > 100 or limit % 1 ~= 0 then
        return nil, 'invalid-search-options'
    end

    local query = queryText(input)

    if not query then
        return nil, 'invalid-search-query'
    end

    query = query:lower()
    local exact = id(query) or id(query:match('|Hitem:(%d+)'))

    if exact then
        itemInfo(exact)
    end

    local owned = settings.inventory and inventory()
    local matches = {}

    for key, record in pairs(indexedItems(owned)) do
        if
            (not owned or owned[key])
            and (exact and exact == key or not exact and record.name:lower():find(query, 1, true))
            and (not accept or accept(key))
        then
            matches[#matches + 1] = record
        end
    end

    table.sort(matches, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end

        return a.name:lower() < b.name:lower()
    end)

    local result = {}

    for i = 1, math.min(limit, #matches) do
        local row = matches[i]
        result[i] = presentation(row.id, row.name, row.icon, row.link)
    end

    return result, { coverage = 'indexed-metadata', more = #matches > limit }
end

-- Asks the platform whether the id is a glyph item (an acceptance test for the glyph provider).
local function glyphItem(value)
    return addon.Platform:GetGlyphItemInfo(value)
end

-- Like itemInfo, but only for glyph items; returns the row, or nil and the platform's reason.
local function glyphInfo(value)
    local key = id(value)

    if not key then
        return
    end

    local accepted, reason = glyphItem(key)

    if not accepted then
        return nil, reason
    end

    return itemInfo(key)
end

-- ============================================================================
-- Providers
-- ============================================================================

-- Returns the provider table the reference editboxes use for an edit box kind: functions index, info, resolve, search
-- and name plus the missing-data text. Glyph and item kinds use the item caches above; anything else falls through to
-- the spell catalog provider. Providers are built fresh on every call.
function addon:GetReferenceProvider(kind)
    if kind == 'Glyph_EditBox' then
        return {
            kind = 'item',
            index = glyphInfo,
            info = glyphInfo,
            resolve = function(value, settings) return itemResolve(value, settings, glyphItem) end,
            search = function(value, settings) return itemSearch(value, settings, glyphItem) end,
            name = function(value)
                local record = glyphInfo(value)
                return record and record.name
            end,
            missing = L['Item data loading'],
        }
    end
    if kind == 'Item_EditBox' or kind == 'Inventory_EditBox' or kind == 'item' then
        return {
            kind = 'item',
            index = itemInfo,
            info = itemInfo,
            resolve = itemResolve,
            search = itemSearch,
            name = function(value)
                local record = itemInfo(value)
                return record and record.name
            end,
            missing = L['Item data loading'],
            inventory = kind == 'Inventory_EditBox',
        }
    end

    local catalog = self.SpellCatalog

    return {
        kind = 'spell',
        index = function(value) return catalog:UpdateSpell(value) end,
        resolve = function(value, options) return catalog:ResolveSelection(value, options) end,
        name = function(value, norank) return catalog:SpellName(value, norank) end,
        search = function(value, options) return catalog:Search(value, options) end,
        info = function(value)
            local info = self.Platform:GetSpellInfo(value)
            return info and { id = value, name = info.name, display = info.name, icon = info.iconID }
        end,
        missing = L['Unknown spell'],
    }
end

-- BEGIN CPU ACTIVITY HANDOFF
-- Count retained keys directly only when an explicit CPU capture asks.
do
    local raw, nextKey, kind, equal = rawget, next, type, rawequal
    local ownedUpdate, ownedProvider = addon.UpdateReferenceItem, addon.GetReferenceProvider

    -- Counts the keys of a map, stopping at 4096 so a capture never walks a huge table.
    local function count(map)
        local n, key = 0, nil

        repeat
            key = nextKey(map, key)

            if key ~= nil then
                n = n + 1
            end
        until key == nil or n > 4096

        return { n = n > 4096 and 4096 or n, capped = n > 4096 }
    end

    local bind = raw(addon, 'BindCPUActivityDiagnostic')

    if kind(bind) == 'function' then
        bind(addon, 'item', function()
            if
                not equal(raw(addon, 'UpdateReferenceItem'), ownedUpdate)
                or not equal(raw(addon, 'GetReferenceProvider'), ownedProvider)
            then
                return
            end

            return { itemRecords = count(items), itemIndex = count(indexed), itemBlocked = count(blocked) }
        end)
    end
end
-- END CPU ACTIVITY HANDOFF
