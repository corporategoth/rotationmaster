local _, addon = ...
local catalog = addon.SpellCatalog

local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$"))
end

local function options(value)
    if value == nil then return { limit = 30 } end
    if type(value) ~= "table" then return nil end
    local spec = value.spec

    if
        spec ~= nil
        and spec ~= (BOOKTYPE_PET or "pet")
        and (type(spec) ~= "number" or spec < 0 or spec == math.huge or spec % 1 ~= 0)
    then
        return nil
    end

    if value.norank ~= nil and type(value.norank) ~= "boolean" then return nil end

    if
        value.nameContains ~= nil
        and (type(value.nameContains) ~= "string" or #value.nameContains == 0 or #value.nameContains > 128)
    then
        return nil
    end

    local limit = value.limit or 30
    if type(limit) ~= "number" or limit < 1 or limit > 100 or limit % 1 ~= 0 then return nil end
    return { spec = spec, norank = value.norank, limit = limit, nameContains = value.nameContains }
end

local function book(spec)
    if spec == nil then return nil end
    local state = addon.spellBookStatus and addon.spellBookStatus[spec == (BOOKTYPE_PET or "pet") and "pet" or "player"]
    if not state or not state.complete then return nil, state and state.reason or "spellbook-unavailable" end
    return addon.specSpells and addon.specSpells[spec] or {}
end

local function nameAllowed(name, opts)
    return not opts.nameContains
        or type(name) == "string" and string.find(string.lower(name), string.lower(opts.nameContains), 1, true) ~= nil
end

local function rank(entry)
    return tonumber((entry.rank or ""):match("%d+")) or 0
end

local function ordered(a, b)
    local left, right = string.lower(a.name), string.lower(b.name)
    if left ~= right then return left < right end
    if rank(a) ~= rank(b) then return rank(a) > rank(b) end
    return a.id > b.id
end

local function label(entry)
    return entry.name .. (entry.rank and entry.rank ~= "" and " (" .. entry.rank .. ")" or "")
end

function catalog:ResolveSelection(input, settings)
    local opts = options(settings)
    if not opts then return nil, "invalid-search-options" end
    if type(input) ~= "string" and type(input) ~= "number" then return nil, "invalid-search-query" end
    local raw = tostring(input)
    if #raw > 1024 then return nil, "invalid-search-query" end
    local text = plain(raw)
    if #text == 0 or #text > 256 then return nil, "invalid-search-query" end
    local spells, why = book(opts.spec)
    if opts.spec ~= nil and not spells then return nil, why end
    local id = tonumber(text) or tonumber(text:match("|Hspell:(%d+)"))

    if id then
        local indexed, problem = self:UpdateSpell(id)
        if not indexed then return nil, problem or "spell-data-unavailable" end
        if spells and not spells[id] then return nil, "spell-not-in-book" end
        if not nameAllowed(self:SpellName(id, true), opts) then return nil, "spell-filter-mismatch" end
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
    if #matches > 0 and (spells or string.lower(matches[1].name) ~= wanted) then return matches[1].id end
    id, why = self:GetSpellId(text)

    if id then
        if spells and not spells[id] then return nil, "spell-not-in-book" end
        if not nameAllowed(self:SpellName(id, true), opts) then return nil, "spell-filter-mismatch" end
        return id
    end

    return nil, why or "spell-data-unavailable"
end

function catalog:Search(input, settings)
    local opts = options(settings)
    if not opts then return nil, "invalid-search-options" end
    if type(input) ~= "string" or #input > 256 then return nil, "invalid-search-query" end
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
