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

-- Reports whether a value may be inspected on this client (the restricted-client rule); every game value is checked
-- first.
-- @param value any  The value to check.
-- @return boolean  True when the value is readable.
local function readable(value)
    return addon.Platform:CanReadValue(value)
end

-- Normalizes a number or numeric string to a positive whole number id.
-- @param value any  The candidate id.
-- @return number|nil  The id; nil when the value is unreadable, not a number or numeric string, or not a positive whole
--   number.
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
-- @param value string  The text to clean.
-- @return string  The text without |cAARRGGBB and |r escapes.
-- @return number  The number of |r escapes removed (the count of the last substitution).
local function plain(value)
    return value:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
end

-- Returns the search text for a typed value.
-- @param value any  The typed value.
-- @return string|nil  '' for nil, the digits of a valid id, or the plain text of a short string (at most 256 bytes);
--   nil for anything else or unreadable input.
-- @return number|nil  The substitution count from plain() when the text came from a string; nil otherwise.
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

-- Checks the optional icon and link of a presentation row.
-- @param icon any  The texture id or path; nil is allowed.
-- @param link any  The hyperlink text; nil is allowed.
-- @return boolean  True when both are readable and well formed.
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

-- Builds the row the pickers show for an item.
-- @param key number  The item id.
-- @param name string  The item name; must be a non-empty string.
-- @param icon string|number|nil  The texture id or path.
-- @param link string|nil  The item hyperlink.
-- @return table|nil  { id, name, display, icon, link }; nil when the name or optional fields are not usable.
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
-- @return table  A set keyed by item id with the value true.
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

-- Looks one item up through the platform and updates the caches.
-- @param value number|string  The item id (or numeric string).
-- @return table|nil  The item's presentation row; nil when the value is not an item id or the item is not (yet) known.
--
-- A real failure blocks the id until a later observation succeeds; an item whose data has not loaded keeps any earlier
-- readable index entry.
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
-- blocked ids.
-- @param owned table|nil  The inventory set, computed when not given.
-- @return table  A map from item id to presentation row; blocked ids are left out.
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

-- Records an item's metadata in the caches (used when an item is first seen).
-- @param value number|string  The item id.
-- @return table|nil  The item's presentation row; nil when the item is not known.
function addon:UpdateReferenceItem(value)
    return itemInfo(value)
end

-- Returns the settings table to use for a provider call.
-- @param settings any  The caller's settings; nil means none.
-- @return table|nil  The settings table (an empty one for nil); nil when it is unreadable or not a table.
local function options(settings)
    if settings == nil then
        return {}
    end
    if readable(settings) and type(settings) == 'table' then
        return settings
    end
end

-- Resolves typed text (id, item link, item: string, or exact name) to an item id.
-- @param input string|number|nil  The typed value.
-- @param settings table|nil  Provider settings; settings.inventory restricts the answer to items the player has.
-- @param accept function|nil  accept(itemId) may veto an id by returning false and a reason.
-- @return number|nil  The item id; nil when no item matches or the id was refused.
-- @return string|nil  The reason for a refusal, such as item-not-in-inventory; nil otherwise.
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

-- Searches the indexed item names for a picker.
-- @param input string|number|nil  The typed text or id.
-- @param settings table|nil  Provider settings: limit (a whole number 1..100, default 30) and inventory.
-- @param accept function|nil  accept(itemId) may exclude an id.
-- @return table[]|nil  Up to settings.limit presentation rows sorted by name; nil for invalid options or query.
-- @return table|string|nil  { coverage = 'indexed-metadata', more = boolean } on success, or invalid-search-options /
--   invalid-search-query when the first return is nil.
--
-- Only names the client has already loaded can match, hence the coverage tag.
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
-- @param value number  The item id.
-- @return table|nil  The glyph item record; nil when it is not a glyph of the player's class.
-- @return string|nil  The platform's reason when the first return is nil; nil otherwise.
local function glyphItem(value)
    return addon.Platform:GetGlyphItemInfo(value)
end

-- Like itemInfo, but only for glyph items.
-- @param value number|string  The item id.
-- @return table|nil  The item's presentation row; nil when it is not a known glyph item.
-- @return string|nil  The platform's reason when the item is not a glyph; nil otherwise.
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

-- Returns the provider table the reference editboxes use for an edit box kind.
-- @param kind string  The edit box kind: 'Glyph_EditBox', 'Item_EditBox', 'Inventory_EditBox' or 'item'; anything else
--   selects the spell catalog provider.
-- @return table  The provider: kind, index, info, resolve, search and name functions plus the missing-data text (and
--   `inventory` for the inventory kind).
--
-- Glyph and item kinds use the item caches above; anything else falls through to the spell catalog provider. Providers
-- are built fresh on every call.
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
    -- @param map table  The map to count.
    -- @return table  { n = number (at most 4096), capped = boolean }.
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
