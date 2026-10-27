-- Bounded JSON for text a person pasted, and a deterministic encoder for what Rotation Master writes.
-- Pure: no game API, no files, no network, nothing evaluated.
--
-- What the reader guarantees, whatever the text says (the same limits the website's wowsims/json.mjs applies):
--  * the text is at most limits.text characters, nested at most limits.depth deep (counted on the characters
--    before parsing), with at most limits.nodes values, strings of at most limits.string characters, arrays of
--    at most limits.array entries and objects of at most limits.keys keys;
--  * objects and arrays are fresh tables; the keys __proto__, constructor and prototype are refused, not skipped
--    (a file that carries them is not a WowSims file); numbers are finite;
--  * a JSON null inside an object is the same as an absent key; inside an array it is json.null.
-- Failures are {ok=false, error={code=..., ...}}; the codes are the website's (wowsims.error.<code>).
local _, ns = ...
local json = {}
ns.json = json

local ARRAY, OBJECT = {}, {}
-- Key order of parsed objects (the first appearance of each key), so a converted snippet reads like its source.
local ORDER = setmetatable({}, {__mode = 'k'})
json.null = setmetatable({}, {__tostring = function() return 'null' end})

local FORBIDDEN = {__proto__ = true, constructor = true, prototype = true}
local function fail(code, params)
    local error_ = {code = code}
    if params then for k, v in pairs(params) do error_[k] = v end end
    return {ok = false, error = error_}
end

function json.isArray(v) return type(v) == 'table' and getmetatable(v) == ARRAY end
function json.isObject(v) return type(v) == 'table' and getmetatable(v) == OBJECT end
--- A list that encodes as a JSON array even when empty.
function json.array(t) return setmetatable(t or {}, ARRAY) end
--- A table that encodes as a JSON object even when empty.
function json.object(t) return setmetatable(t or {}, OBJECT) end
--- The keys of an object: parsed objects keep their file order, built ones are sorted canonically.
local KEY_ORDER = {}
for index, key in ipairs({'type', 'prepullActions', 'priorityList', 'notes', 'hide', 'action', 'doAtValue', 'condition',
    'castSpell', 'op', 'lhs', 'rhs', 'cmp', 'and', 'or', 'not', 'vals', 'val', 'spellId', 'rank', 'itemId', 'otherId',
    'sourceUnit', 'targetUnit', 'auraId', 'owner', 'index', 'const'}) do KEY_ORDER[key] = index end
function json.keys(obj)
    local order = ORDER[obj]
    if order then return order end
    local keys = {}
    for key in pairs(obj) do if type(key) == 'string' then keys[#keys + 1] = key end end
    table.sort(keys, function(a, b)
        local x, y = KEY_ORDER[a], KEY_ORDER[b]
        if x and y then return x < y end
        if x then return true end
        if y then return false end
        return a < b
    end)
    return keys
end

local function trimText(text)
    text = text:gsub('^\239\187\191', '')
    -- Linear: a '%s+$' pattern is quadratic on a long run of spaces.
    local a = text:find('%S')
    if not a then return '' end
    return text:sub(a, text:match('^.*()%S'))
end
json.trimText = trimText

-- Nesting depth counted on the characters and aware of strings, so the parser never sees a document deeper
-- than the limit. Returns true when too deep.
local function tooDeep(text, max)
    local depth, inString, i, n = 0, false, 1, #text
    while i <= n do
        local c = text:byte(i)
        if inString then
            if c == 92 then i = i + 1 elseif c == 34 then inString = false end
        elseif c == 34 then inString = true
        elseif c == 123 or c == 91 then
            depth = depth + 1
            if depth > max then return true end
        elseif c == 125 or c == 93 then depth = depth - 1 end
        i = i + 1
    end
    return false
end

local function utf8char(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64) end
    if code < 0x10000 then
        return string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
    end
    return string.char(0xF0 + math.floor(code / 262144), 0x80 + math.floor(code / 4096) % 64,
        0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
end

local ESCAPES = {['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}

--- Parses JSON text within the limits: {ok=true, value=..., nodes=n} or {ok=false, error=...}.
function json.parse(text, limits)
    if type(text) ~= 'string' then return fail('not-text') end
    text = trimText(text)
    if text == '' then return fail('empty') end
    if #text > limits.text then return fail('too-large', {limit = limits.text}) end
    if tooDeep(text, limits.depth) then return fail('too-deep', {limit = limits.depth}) end
    local pos, nodes, problem = 1, 0, nil
    local len = #text
    local function bad(detail)
        problem = problem or fail('invalid-json', {detail = detail .. ' at position ' .. pos})
        return nil
    end
    local function skip()
        local _, e = text:find('^[ \t\r\n]*', pos)
        pos = e + 1
    end
    local parseValue
    local function parseString()
        -- pos is on the opening quote
        local out, start = {}, pos + 1
        local i = start
        while true do
            local s, e = text:find('^[^"\\%c]+', i)
            if s then out[#out + 1] = text:sub(s, e); i = e + 1 end
            local c = text:sub(i, i)
            if c == '"' then pos = i + 1; break
            elseif c == '\\' then
                local esc = text:sub(i + 1, i + 1)
                if ESCAPES[esc] then out[#out + 1] = ESCAPES[esc]; i = i + 2
                elseif esc == 'u' then
                    local hex = text:match('^%x%x%x%x', i + 2)
                    if not hex then pos = i; return bad('invalid unicode escape') end
                    local code = tonumber(hex, 16)
                    i = i + 6
                    if code >= 0xD800 and code <= 0xDBFF then
                        local low = text:match('^\\u(%x%x%x%x)', i)
                        local lowCode = low and tonumber(low, 16)
                        if lowCode and lowCode >= 0xDC00 and lowCode <= 0xDFFF then
                            code = 0x10000 + (code - 0xD800) * 1024 + (lowCode - 0xDC00)
                            i = i + 6
                        else code = 0xFFFD end
                    elseif code >= 0xDC00 and code <= 0xDFFF then code = 0xFFFD end
                    out[#out + 1] = utf8char(code)
                else pos = i; return bad('invalid escape') end
            else pos = i; return bad(c == '' and 'unterminated string' or 'control character in string') end
            if problem then return nil end
        end
        local value = table.concat(out)
        if #value > limits.string then problem = fail('string-too-long', {limit = limits.string}); return nil end
        return value
    end
    function parseValue()
        if problem then return nil end
        skip()
        nodes = nodes + 1
        if nodes > limits.nodes then problem = fail('too-many-values', {limit = limits.nodes}); return nil end
        local c = text:sub(pos, pos)
        if c == '{' then
            pos = pos + 1
            local obj, order, seen, count = setmetatable({}, OBJECT), {}, {}, 0
            skip()
            if text:sub(pos, pos) == '}' then ORDER[obj] = order; pos = pos + 1; return obj end
            while true do
                skip()
                if text:sub(pos, pos) ~= '"' then return bad('expected a key') end
                local key = parseString()
                if problem then return nil end
                if FORBIDDEN[key] then problem = fail('forbidden-key', {key = key}); return nil end
                skip()
                if text:sub(pos, pos) ~= ':' then return bad('expected a colon') end
                pos = pos + 1
                local value = parseValue()
                if problem then return nil end
                if not seen[key] then
                    seen[key] = true
                    count = count + 1
                    if count > limits.keys then problem = fail('too-many-keys', {limit = limits.keys}); return nil end
                    order[#order + 1] = key
                end
                obj[key] = value
                skip()
                local d = text:sub(pos, pos)
                if d == ',' then pos = pos + 1
                elseif d == '}' then pos = pos + 1; break
                else return bad('expected a comma or a closing brace') end
            end
            -- a null value is an absent key
            local kept = {}
            for _, key in ipairs(order) do if obj[key] ~= nil then kept[#kept + 1] = key end end
            ORDER[obj] = kept
            return obj
        elseif c == '[' then
            pos = pos + 1
            local arr, n = setmetatable({}, ARRAY), 0
            skip()
            if text:sub(pos, pos) == ']' then pos = pos + 1; return arr end
            while true do
                local value = parseValue()
                if problem then return nil end
                n = n + 1
                if n > limits.array then problem = fail('array-too-long', {limit = limits.array}); return nil end
                if value == nil then value = json.null end
                arr[n] = value
                skip()
                local d = text:sub(pos, pos)
                if d == ',' then pos = pos + 1
                elseif d == ']' then pos = pos + 1; break
                else return bad('expected a comma or a closing bracket') end
            end
            return arr
        elseif c == '"' then
            return parseString()
        elseif c == 't' and text:sub(pos, pos + 3) == 'true' then pos = pos + 4; return true
        elseif c == 'f' and text:sub(pos, pos + 4) == 'false' then pos = pos + 5; return false
        elseif c == 'n' and text:sub(pos, pos + 3) == 'null' then pos = pos + 4; return nil
        else
            local _, e = text:find('^-?%d+', pos)
            if not e then return bad('unexpected character') end
            local int = text:match('^-?(%d+)', pos)
            if #int > 1 and int:sub(1, 1) == '0' then return bad('invalid number') end
            local i = e + 1
            if text:sub(i, i) == '.' then
                local fraction = text:match('^%.%d+', i)
                if not fraction then return bad('invalid number') end
                i = i + #fraction
            end
            local exponent = text:match('^[eE][+-]?%d+', i)
            if exponent then i = i + #exponent end
            local value = tonumber(text:sub(pos, i - 1))
            pos = i
            if not value then return bad('invalid number') end
            if value ~= value or value == math.huge or value == -math.huge then problem = fail('not-finite'); return nil end
            return value
        end
    end
    local value = parseValue()
    if problem then return problem end
    skip()
    if pos <= len then return fail('invalid-json', {detail = 'unexpected data after the value at position ' .. pos}) end
    if value == nil then value = json.null end
    return {ok = true, value = value, nodes = nodes}
end

-- ---- pasted text: JSON as is, base64 of JSON, or a share link ----------------------------------------------
local B64 = {}
do
    local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    for i = 1, #alphabet do B64[alphabet:sub(i, i)] = i - 1 end
    B64['-'] = 62; B64['_'] = 63
end
local function decodeBase64(text)
    local out, bits, nbits = {}, 0, 0
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == '=' then break end
        local v = B64[c]
        if not v then return nil end
        bits = bits * 64 + v; nbits = nbits + 6
        if nbits >= 8 then
            nbits = nbits - 8
            local shift = 2 ^ nbits
            out[#out + 1] = string.char(math.floor(bits / shift))
            bits = bits % shift
        end
    end
    return table.concat(out)
end
-- A strict UTF-8 check, as a fatal decoder would do.
---@param text string
local function validUtf8(text)
    local i, n = 1, #text
    while i <= n do
        local c = text:byte(i)
        if c < 0x80 then i = i + 1
        elseif c >= 0xC2 and c <= 0xDF then
            local b = text:byte(i + 1); if not b or b < 0x80 or b > 0xBF then return false end
            i = i + 2
        elseif c >= 0xE0 and c <= 0xEF then
            local b1, b2 = text:byte(i + 1, i + 2)
            if not b2 or b1 < 0x80 or b1 > 0xBF or b2 < 0x80 or b2 > 0xBF then return false end
            if c == 0xE0 and b1 < 0xA0 then return false end
            if c == 0xED and b1 > 0x9F then return false end
            i = i + 3
        elseif c >= 0xF0 and c <= 0xF4 then
            local b1, b2, b3 = text:byte(i + 1, i + 3)
            if not b3 or b1 < 0x80 or b1 > 0xBF or b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF then return false end
            if c == 0xF0 and b1 < 0x90 then return false end
            if c == 0xF4 and b1 > 0x8F then return false end
            i = i + 4
        else return false end
    end
    return true
end

--- Pasted text as JSON text: {ok=true, text=, via='json'|'base64'} or a failure ('empty', 'too-large', 'not-json',
--- 'share-link' with link={era=, spec=}).
function json.pastedText(input, limits)
    if type(input) ~= 'string' then return fail('not-text') end
    local body = trimText(input)
    if body == '' then return fail('empty') end
    if #body > limits.text * 1.5 then return fail('too-large', {limit = limits.text}) end
    local first = body:sub(1, 1)
    if first == '{' or first == '[' then return {ok = true, text = body, via = 'json'} end
    if not body:find('%s') then
        local lower = body:lower()
        local rest = lower:match('^https?://www%.wowsims%.com/(.*)$') or lower:match('^https?://wowsims%.com/(.*)$')
        if rest then
            local era = rest:match('^([%w_-]+)')
            if era then
                local spec = rest:match('^[%w_-]+/([%w_-]+)')
                local result = fail('share-link')
                result.link = {era = era, spec = spec}
                return result
            end
        end
    end
    local squeezed = body:gsub('%s', ''):gsub('\226\128[\139-\143]', ''):gsub('\226\129\160', ''):gsub('\239\187\191', ''):gsub('\194\173', '')
    if #squeezed > limits.base64 then return fail('too-large', {limit = limits.text}) end
    if squeezed == '' or not squeezed:match('^[A-Za-z0-9+/_-]+=?=?$') then return fail('not-json') end
    local bytes = decodeBase64(squeezed)
    if not bytes then return fail('not-json') end
    local b1, b2 = bytes:byte(1, 2)
    if b1 == 0x78 and (b2 == 0x01 or b2 == 0x5E or b2 == 0x9C or b2 == 0xDA) then return fail('share-link') end
    if not validUtf8(bytes) then return fail('not-json') end
    local decoded = trimText(bytes)
    local lead = decoded:sub(1, 1)
    if lead ~= '{' and lead ~= '[' then return fail('not-json') end
    return {ok = true, text = decoded, via = 'base64'}
end

-- ---- encoding ---------------------------------------------------------------------------------------------
local function quote(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
        elseif c == '\n' then return '\\n' elseif c == '\r' then return '\\r' elseif c == '\t' then return '\\t'
        elseif c == '\b' then return '\\b' elseif c == '\f' then return '\\f' end
        return string.format('\\u%04x', c:byte())
    end) .. '"'
end
local function number(v)
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', v) end
    local s = string.format('%.14g', v)
    if tonumber(s) ~= v then s = string.format('%.17g', v) end
    return s
end
local function isList(v)
    local mt = getmetatable(v)
    if mt == ARRAY then return true end
    if mt == OBJECT then return false end
    return #v > 0 and next(v, #v) == nil
end

--- JSON text of a value. indent: spaces per level for the pretty form (JSON.stringify(value, null, 2) layout),
--- nil for the minified form. limit: stop with '...' marks after that many characters (reports).
function json.encode(value, indent, limit)
    local parts, size = {}, 0
    local function put(s)
        size = size + #s
        parts[#parts + 1] = s
    end
    local function write(v, level)
        if limit and size > limit then return end
        local kind = type(v)
        if v == nil or v == json.null then put('null')
        elseif kind == 'boolean' then put(v and 'true' or 'false')
        elseif kind == 'number' then put(number(v))
        elseif kind == 'string' then put(quote(v))
        elseif kind == 'table' then
            local nl = indent and ('\n' .. string.rep(' ', indent * (level + 1))) or ''
            local close = indent and ('\n' .. string.rep(' ', indent * level)) or ''
            if isList(v) then
                if #v == 0 then put('[]'); return end
                put('[')
                for i = 1, #v do
                    if i > 1 then put(',') end
                    put(nl); write(v[i], level + 1)
                end
                put(close .. ']')
            else
                local keys, any = json.keys(v), false
                put('{')
                for _, key in ipairs(keys) do
                    local item = v[key]
                    if item ~= nil then
                        if any then put(',') end
                        any = true
                        put(nl .. quote(key) .. (indent and ': ' or ':')); write(item, level + 1)
                    end
                end
                if not any then put('}') else put(close .. '}') end
            end
        else put('null') end
    end
    write(value, 0)
    local text = table.concat(parts)
    if limit and #text > limit then return text:sub(1, limit - 1) .. '...' end
    return text
end
