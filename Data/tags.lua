-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation tags as pure data: normalizing and validating a tag list, parsing and formatting the comma-separated text
-- box, resolving a body's effective tags, matching a tag filter and building the search text for a rotation.
-- It owns the tag limits (64 tags, 64 characters each, 32 KiB of CSV text) and must never write saved data or
-- evaluate anything; tags are labels only.
-- Loaded from RotationMaster.toc after Data/rotation_revision.lua; extends addon.RotationData from Data/plain.lua and
-- uses data.CopyData. Used by the rotation list filter, the editor and import/export
-- (docs/quality/rotation-transport.md).
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Tag validation
-- ============================================================================

-- Linear trim. A '^%s*(.-)%s*$' (or '%s+$') pattern is quadratic on a long run of spaces inside pasted text.
local function trim(s)
    local a = s:find('%S')

    if not a then
        return ''
    end

    return s:sub(a, s:match('^.*()%S'))
end

-- Returns the number of UTF-8 characters in the text, or nil when it is not well-formed UTF-8 (overlong forms,
-- surrogates, code points above U+10FFFF and C1 control characters are rejected).
local function characters(text)
    local i, n = 1, 0

    while i <= #text do
        local a = text:byte(i)

        local width = a < 128 and 1
            or a >= 194 and a <= 223 and 2
            or a >= 224 and a <= 239 and 3
            or a >= 240 and a <= 244 and 4

        if not width or i + width - 1 > #text then
            return
        end

        for j = i + 1, i + width - 1 do
            local byte = text:byte(j)

            if byte < 128 or byte > 191 then
                return
            end
        end

        local b = text:byte(i + 1)

        if a == 194 and b >= 128 and b <= 159 then
            return
        end
        if
            width == 3 and (a == 224 and b < 160 or a == 237 and b >= 160)
            or width == 4 and (a == 240 and b < 144 or a == 244 and b >= 144)
        then
            return
        end

        n = n + 1
        i = i + width
    end

    return n
end

-- Validates a dense list of tag strings and returns a trimmed copy with case-insensitive duplicates dropped (first
-- spelling wins), or nil and 'invalid-tags', 'tag-limit', 'invalid-tag' or 'tag-length'. Rejects tables with a
-- metatable, holes or extra keys.
function data.NormalizeRotationTags(tags)
    if type(tags) ~= 'table' or getmetatable(tags) then
        return nil, 'invalid-tags'
    end

    local count = 0

    for key in pairs(tags) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or key > #tags then
            return nil, 'invalid-tags'
        end

        count = count + 1
    end

    if count ~= #tags or count > 64 then
        return nil, 'tag-limit'
    end

    local normalized, seen = {}, {}

    for _, tag in ipairs(tags) do
        if type(tag) ~= 'string' or tag:find('%c') then
            return nil, 'invalid-tag'
        end
        if #tag > 1024 then
            return nil, 'tag-length'
        end

        local text = trim(tag)
        local length = characters(text)

        if not length or length == 0 or length > 64 then
            return nil, 'tag-length'
        end

        local key = text:lower()

        if not seen[key] then
            normalized[#normalized + 1] = text
            seen[key] = true
        end
    end

    return normalized
end

-- ============================================================================
-- Tag text and lookup
-- ============================================================================

-- Parses the tag text box (comma or newline separated, with double-quoted entries that may hold commas and escaped
-- quotes) into a normalized list. Returns the list, or nil and 'tag-limit', 'invalid-tag-quotes' or a normalize reason.
-- Input is bounded to 32 KiB and is only ever read as data.
function data.ParseRotationTags(text)
    if type(text) ~= 'string' or #text > 32768 then
        return nil, 'tag-limit'
    end

    local tags, parts = {}, {}
    local quoted, closed = false, false
    local i = 1

    -- Ends the current entry: trims it, keeps it when non-empty and resets the scanner for the next one.
    local function finish()
        local value = trim(table.concat(parts))

        if value ~= '' then
            tags[#tags + 1] = value
        end

        parts = {}
        closed = false
    end

    while i <= #text do
        local ch = text:sub(i, i)

        if quoted then
            if ch == '"' then
                if text:sub(i + 1, i + 1) == '"' then
                    parts[#parts + 1] = '"'
                    i = i + 1
                else
                    quoted = false
                    closed = true
                end
            else
                parts[#parts + 1] = ch
            end
        elseif ch == ',' or ch == '\n' or ch == '\r' then
            finish()
        elseif ch == '"' then
            if closed or table.concat(parts):find('%S') then
                return nil, 'invalid-tag-quotes'
            end

            parts = {}
            quoted = true
        elseif closed and ch:find('%S') then
            return nil, 'invalid-tag-quotes'
        else
            parts[#parts + 1] = ch
        end

        i = i + 1
    end

    if quoted then
        return nil, 'invalid-tag-quotes'
    end

    finish()
    return data.NormalizeRotationTags(tags)
end

-- Formats a tag list as the text ParseRotationTags reads back: ", " separated, quoting any tag with a comma or quote.
-- Returns nil and the reason when the list is not valid.
function data.FormatRotationTags(tags)
    local normalized, why = data.NormalizeRotationTags(tags)

    if not normalized then
        return nil, why
    end

    local parts = {}

    for _, tag in ipairs(normalized) do
        parts[#parts + 1] = tag:find('[,"]') and '"' .. tag:gsub('"', '""') .. '"' or tag
    end

    return table.concat(parts, ', ')
end

-- Returns the effective tags of an envelope or bare body: the body's own list when present (even if empty), otherwise
-- the envelope's. Always a list; invalid stored tags give nil and the reason from the normalizer.
function data.GetRotationTags(value)
    if type(value) ~= 'table' then
        return {}
    end

    local body = type(value.body) == 'table' and value.body or value
    local tags = body.tags

    if tags == nil then
        tags = value.tags
    end

    if tags == nil then
        return {}
    end

    return data.NormalizeRotationTags(tags)
end

-- Tests a tag list against a filter (one tag or a list), ignoring case. mode 'all' needs every filtered tag; anything
-- else needs at least one. A missing or empty filter matches everything.
function data.RotationTagMatches(tags, filter, mode)
    if filter == nil then
        return true
    end

    if type(filter) == 'string' then
        filter = { filter }
    end

    if type(filter) ~= 'table' then
        return false
    end
    if #filter == 0 then
        return true
    end

    local present = {}

    for _, value in ipairs(tags or {}) do
        present[value:lower()] = true
    end

    for _, tag in ipairs(filter) do
        local match = present[tag:lower()] == true

        if mode == 'all' and not match then
            return false
        elseif mode ~= 'all' and match then
            return true
        end
    end

    return mode == 'all'
end

-- Compare effective labels once, regardless of whether they are inherited or
-- explicitly stored. This detached view never materializes tags in saved data.
function data.RotationComparisonValue(body, inheritedTags)
    local copy, why = data.CopyData(body)

    if not copy then
        return nil, why
    end

    local tags = data.GetRotationTags({ body = copy, tags = inheritedTags }) or {}
    copy.tags = nil
    return { body = copy, tags = tags }
end

-- Builds the lowercase text the rotation list searches: display name and description (falling back to the body's),
-- tags, metadata fields and the title, url, publisher and author of each source.
function data.RotationSearchText(value, displayName, displayDescription)
    local body = type(value) == 'table' and (type(value.body) == 'table' and value.body or value) or {}

    local text = {
        type(displayName) == 'string' and displayName or type(body.name) == 'string' and body.name or '',
        type(displayDescription) == 'string' and displayDescription
            or type(body.description) == 'string' and body.description
            or '',
    }

    for _, tag in ipairs(data.GetRotationTags(value) or {}) do
        text[#text + 1] = tag
    end

    if type(body.metadata) == 'table' then
        for _, field in ipairs({ 'author', 'realm', 'email', 'website', 'version' }) do
            if type(body.metadata[field]) == 'string' then
                text[#text + 1] = body.metadata[field]
            end
        end
    end

    if type(value) == 'table' and type(value.sources) == 'table' then
        for _, source in ipairs(value.sources) do
            if type(source) == 'table' then
                for _, field in ipairs({ 'title', 'url', 'publisher', 'author' }) do
                    if type(source[field]) == 'string' then
                        text[#text + 1] = source[field]
                    end
                end
            end
        end
    end

    return table.concat(text, ' '):lower()
end
