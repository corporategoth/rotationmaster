-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Spell search and selection for the reference catalog: turns what the user typed or pasted (a spell ID, a spell
-- link, a name or "Name (Rank 2)") into a spell ID, and lists matching indexed spells for pickers. It reads only the
-- spell index of addon.SpellCatalog and the spellbook status that Core/spell_catalog.lua records; it never writes
-- either and reports an unreadable spellbook as a reason instead of guessing. Loaded straight after
-- Core/spell_catalog.lua and wired into the reference catalog by Core/reference_catalog.lua.

local _, addon = ...
local catalog = addon.SpellCatalog

-- ============================================================================
-- Query and filter helpers
-- ============================================================================

-- Strips color codes and surrounding whitespace so pasted link text compares like a typed name.
-- @param text string  The text to clean.
-- @return string  The cleaned text.
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$"))
end

-- Validates the caller's search settings and returns a normalized copy.
-- @param value table|nil  The settings (spec, norank, limit, nameContains); nil means the defaults (limit 30).
-- @return table|nil  { spec, norank, limit, nameContains } copy; nil when anything is out of range.
--
-- The checks are strict because settings can come from saved or imported data.
local function options(value)
    if value == nil then
        return { limit = 30 }
    end
    if type(value) ~= "table" then
        return nil
    end

    local spec = value.spec

    if
        spec ~= nil
        and spec ~= (BOOKTYPE_PET or "pet")
        and (type(spec) ~= "number" or spec < 0 or spec == math.huge or spec % 1 ~= 0)
    then
        return nil
    end
    if value.norank ~= nil and type(value.norank) ~= "boolean" then
        return nil
    end
    if
        value.nameContains ~= nil
        and (type(value.nameContains) ~= "string" or #value.nameContains == 0 or #value.nameContains > 128)
    then
        return nil
    end

    local limit = value.limit or 30

    if type(limit) ~= "number" or limit < 1 or limit > 100 or limit % 1 ~= 0 then
        return nil
    end

    return { spec = spec, norank = value.norank, limit = limit, nameContains = value.nameContains }
end

-- Returns the set of spell IDs in a spellbook.
-- @param spec number|string|nil  A specialization number, or the pet book (BOOKTYPE_PET); nil means no book filter.
-- @return table|nil  The set of spell IDs keyed by id; nil when spec is nil or the book is not available.
-- @return string|nil  The reason when that book has not finished loading, so callers never treat a partial book as
--   complete; nil otherwise.
local function book(spec)
    if spec == nil then
        return nil
    end

    local state = addon.spellBookStatus and addon.spellBookStatus[spec == (BOOKTYPE_PET or "pet") and "pet" or "player"]

    if not state or not state.complete then
        return nil, state and state.reason or "spellbook-unavailable"
    end

    return addon.specSpells and addon.specSpells[spec] or {}
end

-- Reports whether the optional case-insensitive nameContains filter accepts a name.
-- @param name any  The spell name.
-- @param opts table  The normalized options; opts.nameContains is a plain substring, not a pattern.
-- @return boolean  True when there is no filter or the name contains the filter text.
local function nameAllowed(name, opts)
    return not opts.nameContains
        or type(name) == "string" and string.find(string.lower(name), string.lower(opts.nameContains), 1, true) ~= nil
end

-- Returns the numeric rank of an index entry.
-- @param entry table  The index entry.
-- @return number  The rank number, or 0 when it has none.
local function rank(entry)
    return tonumber((entry.rank or ""):match("%d+")) or 0
end

-- Sort order for index entries: by name ignoring case, then higher rank first, then higher spell ID first.
-- @param a table  The first index entry.
-- @param b table  The second index entry.
-- @return boolean  True when `a` sorts before `b`.
local function ordered(a, b)
    local left, right = string.lower(a.name), string.lower(b.name)

    if left ~= right then
        return left < right
    end
    if rank(a) ~= rank(b) then
        return rank(a) > rank(b)
    end

    return a.id > b.id
end

-- Returns an index entry's name with its rank in parentheses when it has one.
-- @param entry table  The index entry.
-- @return string  The label.
local function label(entry)
    return entry.name .. (entry.rank and entry.rank ~= "" and " (" .. entry.rank .. ")" or "")
end

-- ============================================================================
-- Resolving and searching
-- ============================================================================

-- Resolves typed text, a spell ID or a spell link to one spell ID under the optional spellbook and name filters.
-- @param input string|number  The typed text, spell ID, or spell link.
-- @param settings table|nil  Search settings (spec, norank, limit, nameContains).
-- @return number|nil  The spell ID; nil when it cannot be resolved.
-- @return string|nil  The reason code, such as "spell-not-in-book" or "spell-data-unavailable"; nil on success.
--
-- A name that several spells share resolves to the highest rank (or the first by sort order) rather than failing.
function catalog:ResolveSelection(input, settings)
    local opts = options(settings)

    if not opts then
        return nil, "invalid-search-options"
    end
    if type(input) ~= "string" and type(input) ~= "number" then
        return nil, "invalid-search-query"
    end

    local raw = tostring(input)

    if #raw > 1024 then
        return nil, "invalid-search-query"
    end

    local text = plain(raw)

    if #text == 0 or #text > 256 then
        return nil, "invalid-search-query"
    end

    local spells, why = book(opts.spec)

    if opts.spec ~= nil and not spells then
        return nil, why
    end

    local id = tonumber(text) or tonumber(text:match("|Hspell:(%d+)"))

    if id then
        local indexed, problem = self:UpdateSpell(id)

        if not indexed then
            return nil, problem or "spell-data-unavailable"
        end
        if spells and not spells[id] then
            return nil, "spell-not-in-book"
        end
        if not nameAllowed(self:SpellName(id, true), opts) then
            return nil, "spell-filter-mismatch"
        end

        return id
    end

    local wanted = string.lower(text)
    local matches = {}

    for _, entry in ipairs(self:GetIndexedSpells()) do
        if
            (not spells or spells[entry.id])
            and nameAllowed(entry.name, opts)
            and (string.lower(label(entry)) == wanted or string.lower(entry.name) == wanted)
        then
            matches[#matches + 1] = entry
        end
    end

    table.sort(matches, ordered)

    -- Scoped name choices come from that book, not a canonical name override
    -- belonging to another rank/spec/pet. Explicit rank labels retain identity.
    if #matches > 0 and (spells or string.lower(matches[1].name) ~= wanted) then
        return matches[1].id
    end

    id, why = self:GetSpellId(text)

    if id then
        if spells and not spells[id] then
            return nil, "spell-not-in-book"
        end
        if not nameAllowed(self:SpellName(id, true), opts) then
            return nil, "spell-filter-mismatch"
        end

        return id
    end

    return nil, why or "spell-data-unavailable"
end

-- Lists indexed spells matching the text (or the exact spell that an ID or link names).
-- @param input string  The typed text, spell ID, or spell link (at most 256 bytes).
-- @param settings table|nil  Search settings: spec, norank, limit (at most settings.limit rows) and nameContains.
-- @return table[]|nil  The rows: the shared index entries with `display` set; empty when the spellbook is incomplete or
--   an exact spell cannot be resolved; nil for invalid options or query.
-- @return table|string|nil  The status table { coverage, scope, bookComplete, reason, more } when rows are returned, or
--   the reason code (invalid-search-options / invalid-search-query) when the first return is nil.
function catalog:Search(input, settings)
    local opts = options(settings)

    if not opts then
        return nil, "invalid-search-options"
    end
    if type(input) ~= "string" or #input > 256 then
        return nil, "invalid-search-query"
    end

    local text = plain(input)
    local wanted = string.lower(text)
    local spells, why = book(opts.spec)

    local status = {
        coverage = "indexed-metadata",
        scope = opts.spec ~= nil and "spellbook" or "reference",
        bookComplete = opts.spec ~= nil and spells ~= nil or nil,
        reason = why,
        more = false,
    }

    if opts.spec ~= nil and not spells then
        status.bookComplete = false
        return {}, status
    end

    local exact = tonumber(text) or tonumber(text:match("|Hspell:(%d+)"))

    if exact then
        local id, problem = self:ResolveSelection(text, opts)

        if not id then
            status.reason = problem
            return {}, status
        end

        exact = id
    end

    local rows = {}

    for _, entry in ipairs(self:GetIndexedSpells()) do
        if
            (not spells or spells[entry.id])
            and nameAllowed(entry.name, opts)
            and (exact and entry.id == exact or not exact and string.find(string.lower(entry.name), wanted, 1, true))
        then
            rows[#rows + 1] = entry
        end
    end

    table.sort(rows, ordered)
    local result, seen = {}, {}

    for _, entry in ipairs(rows) do
        local key = string.lower(entry.name)

        if not opts.norank or not seen[key] then
            if #result == opts.limit then
                status.more = true
                break
            end

            seen[key] = true
            entry.display = opts.norank and entry.name or label(entry)
            result[#result + 1] = entry
        end
    end

    return result, status
end
