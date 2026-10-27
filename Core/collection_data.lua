-- Item set import parsing: validates pasted text for the item set importer and returns a candidate set. It only
-- parses and validates; it never writes the saved item sets (the item set settings page does that after the user
-- confirms). Loaded after Core/profile_data.lua; the codec is passed in by the caller, so this file has no codec load
-- order to respect.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Linear trim: '^%s*(.-)%s*$' is quadratic on a long run of spaces in pasted text.
local function trim(s)
    local a = s:find('%S')
    if not a then return '' end
    return s:sub(a, s:match('^.*()%S'))
end

-- Parses the text a user pasted into the item set importer. Accepts either an encoded RM-ItemSet envelope or a plain
-- list of item ids and names separated by commas or newlines. Returns { name = ..., items = ... } (name is nil for a
-- plain list), or nil and the localized "Invalid item list." message when the size, shape or any item is out of bounds.
function addon:ParseItemSetImport(text, codec)
    if type(text) ~= 'string' or #text > 131072 then return nil, L['Invalid item list.'] end
    local decoded = codec:Decode(text)
    local result

    if decoded then
        local value = decoded.value

        if
            type(value) ~= 'table'
            or value.format ~= 'RM-ItemSet'
            or value.version ~= 1
            or type(value.items) ~= 'table'
            or type(value.name) ~= 'string'
            or #value.name > 256
            or not value.name:find('%S')
        then
            return nil, L['Invalid item list.']
        end

        result = { name = value.name, items = value.items }
    else
        result = { items = {} }

        for line in (text:gsub(',', '\n') .. '\n'):gmatch('(.-)\n') do
            local value = trim(line)
            if value ~= '' then result.items[#result.items + 1] = tonumber(value) or value end
        end
    end

    local count = 0

    for key, item in pairs(result.items) do
        if
            type(key) ~= 'number'
            or key < 1
            or key % 1 ~= 0
            or key > #result.items
            or not (type(item) == 'number' and item > 0 and item % 1 == 0
                or type(item) == 'string'
                    and #item > 0
                    and #item <= 1024
                    and not tonumber(item)
                    and not item:find('[%z\1-\31\127]'))
        then
            return nil, L['Invalid item list.']
        end

        count = count + 1
    end

    if count ~= #result.items or count > 256 then return nil, L['Invalid item list.'] end
    return result
end
