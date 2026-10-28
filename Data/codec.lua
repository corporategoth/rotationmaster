-- Rotation transport codec: turns a table into an export string (AceSerializer protocol 1 payload, LibCompress stream,
-- Base64, "RM1:" marker for envelopes) and back, with every size and shape bound checked BEFORE the expensive library
-- steps run. The contract is docs/quality/rotation-transport.md.
-- It is a data-only boundary: serialize/deserialize/compress/decompress are injected trusted functions, and nothing
-- here may execute predicates, compile Lua, register definitions or write SavedVariables.
-- Loaded from RotationMaster.toc after Data/export_text.lua (addon:NormalizeImportText) and Data/plain.lua
-- (CheckPortable); the UI builds a codec through addon:NewRotationCodec and the import session decodes with it.
local _, addon = ...
local data = addon.RotationData
local maxSerialized, maxCompressed, maxInput = 1048576, 1048577, 2097152
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local symbols, values = {}, {}

for i = 1, #alphabet do
    local c = alphabet:sub(i, i)
    symbols[i - 1] = c
    values[c] = i - 1
end

-- ============================================================================
-- Base64
-- ============================================================================

-- Encodes a byte string as standard padded Base64. Returns nil and 'encoded-size-limit' for a non-string or one over
-- the compressed-stream limit.
function data.EncodeBase64(raw)
    if type(raw) ~= "string" or #raw > maxCompressed then
        return nil, "encoded-size-limit"
    end

    local chunks = {}

    for i = 1, #raw, 3 do
        local a, b, c = raw:byte(i, i + 2)
        local code = a * 65536 + (b or 0) * 256 + (c or 0)

        chunks[#chunks + 1] = symbols[math.floor(code / 262144)]
            .. symbols[math.floor(code / 4096) % 64]
            .. (b and symbols[math.floor(code / 64) % 64] or "=")
            .. (c and symbols[code % 64] or "=")
    end

    return table.concat(chunks)
end

-- Strictly decodes Base64 to bytes. Rejects a bad alphabet, length, misplaced padding and nonzero unused tail bits, and
-- a result over the compressed-stream limit. Returns the bytes, or nil and the reason code.
local function base64(text)
    local clean = text:gsub("[ \t\r\n]", "")

    if #clean == 0 or #clean % 4 ~= 0 or clean:find("[^A-Za-z0-9+/=]") then
        return nil, "invalid-base64"
    end

    local chunks = {}

    for i = 1, #clean, 4 do
        local a, b, c, d = clean:sub(i, i), clean:sub(i + 1, i + 1), clean:sub(i + 2, i + 2), clean:sub(i + 3, i + 3)

        if not values[a] or not values[b] or c == "=" and d ~= "=" or (c == "=" or d == "=") and i ~= #clean - 3 then
            return nil, "invalid-base64-padding"
        end

        local x, y = values[a], values[b]
        local z, w = c == "=" and 0 or values[c], d == "=" and 0 or values[d]

        if z == nil or w == nil or c == "=" and y % 16 ~= 0 or d == "=" and c ~= "=" and z % 4 ~= 0 then
            return nil, "invalid-base64-padding"
        end

        local code = x * 262144 + y * 4096 + z * 64 + w
        local piece = string.char(math.floor(code / 65536))

        if c ~= "=" then
            piece = piece .. string.char(math.floor(code / 256) % 256)
        end
        if d ~= "=" then
            piece = piece .. string.char(code % 256)
        end

        chunks[#chunks + 1] = piece
    end

    local raw = table.concat(chunks)

    if #raw > maxCompressed then
        return nil, "compressed-size-limit"
    end

    return raw
end

-- ============================================================================
-- Compressed stream size checks
-- ============================================================================

-- Length-only analysis of the legacy LZW wire format. No decoded strings or
-- dictionary phrases are allocated here. LibCompress does actual decompression.
-- Returns the decompressed length, or nil and a reason code for an invalid code, an empty stream or a result over the
-- serialized limit.
local function lzwSize(stream)
    local lengths = {}

    for i = 0, 255 do
        lengths[i] = 1
    end

    local position, nextCode, total, previous = 2, 256, 0, nil

    while position <= #stream do
        local marker = stream:byte(position)
        local code = marker
        position = position + 1

        if marker > 249 then
            local digits = 256 - marker

            if position + digits - 1 > #stream then
                return nil, "invalid-lzw-code"
            end

            code = 0

            for index = position + digits - 1, position, -1 do
                local digit = stream:byte(index)

                if digit == 0 then
                    return nil, "invalid-lzw-code"
                end

                code = code * 255 + digit - 1
            end

            position = position + digits
        end

        local length = lengths[code]

        if not previous then
            if code > 255 or code < 0 then
                return nil, "invalid-lzw-code"
            end
        elseif code == nextCode then
            length = previous + 1
        elseif not length then
            return nil, "invalid-lzw-code"
        end

        if not length then
            return nil, "invalid-lzw-code"
        end

        total = total + length

        if total > maxSerialized then
            return nil, "decompressed-size-limit"
        end

        if previous then
            lengths[nextCode] = previous + 1
            nextCode = nextCode + 1
        end

        previous = length
    end

    if not previous then
        return nil, "empty-lzw-stream"
    end

    return total
end

-- A size header does not bound malformed codebook parsing in LibCompress.
-- Walk the map once in wire bit order; each escaped code is at most 32 bits
-- followed by its two stop bits. This prevents unbounded stop-bit searches.
-- Returns true when the codebook is well formed within the stream, false otherwise.
local function huffmanMap(stream)
    local position = 40

    -- Reads the next bit in wire order (least significant first), or nil past the end of the stream.
    local function bit()
        local byte = stream:byte(math.floor(position / 8) + 1)

        if not byte then
            return nil
        end

        local value = math.floor(byte / 2 ^ (position % 8)) % 2
        position = position + 1
        return value
    end

    for _ = 1, stream:byte(2) + 1 do
        for _ = 1, 8 do
            if bit() == nil then
                return false
            end
        end

        local escaped = 0

        while true do
            local first = bit()

            if first == nil then
                return false
            end

            if first == 1 then
                local second = bit()

                if second == nil then
                    return false
                end

                if second == 1 then
                    if escaped == 0 then
                        return false
                    end

                    break
                end

                escaped = escaped + 2
            else
                escaped = escaped + 1
            end

            if escaped > 32 then
                return false
            end
        end
    end

    return true
end

-- Returns the length a compressed stream will expand to, read from its header (stored), counted (LZW) or declared
-- (Huffman), or nil and a reason code. Only methods 1, 2 and 3 are accepted. The caller compares the real
-- decompressor output with this number.
local function decompressedSize(stream)
    local codec = stream:byte(1)

    if codec == 1 then
        if #stream - 1 > maxSerialized then
            return nil, "decompressed-size-limit"
        end

        return #stream - 1
    elseif codec == 2 then
        return lzwSize(stream)
    elseif codec == 3 then
        if #stream < 5 then
            return nil, "invalid-huffman-header"
        end

        local a, b, c = stream:byte(3, 5)
        local size = a + b * 256 + c * 65536

        if size > maxSerialized then
            return nil, "decompressed-size-limit"
        end
        if size > 0 and not huffmanMap(stream) then
            return nil, "invalid-huffman-codebook"
        end

        return size
    end

    return nil, "unsupported-compression"
end

-- ============================================================================
-- Serializer preflight and codec
-- ============================================================================

-- Scans the AceSerializer control tokens of a payload before the recursive parser sees it: exactly one root table,
-- depth at most 64, at most 20,000 tokens and a terminator. Returns true, or false and a reason code.
local function serializerShape(raw)
    -- Match the bundled parser's whitespace normalization before inspecting its
    -- structural control tokens, then bound its recursive table construction.
    local clean = raw:gsub("[%c ]", "")

    if clean:sub(1, 2) ~= "^1" then
        return false, "unsupported-serializer"
    end

    local depth, tokens, root, closed, terminated = 0, 0, false, false, false

    for control in clean:gmatch("(^.)([^^]*)") do
        tokens = tokens + 1

        if tokens > 20000 then
            return false, "serializer-token-limit"
        end

        if tokens == 1 then
            if control ~= "^1" then
                return false, "unsupported-serializer"
            end
        elseif terminated then
            return false, "serializer-trailing-data"
        elseif not root then
            if control ~= "^T" then
                return false, "expected-root-table"
            end

            root = true
            depth = 1
        elseif closed then
            if control ~= "^^" then
                return false, "serializer-multiple-values"
            end

            terminated = true
        elseif control == "^T" then
            depth = depth + 1

            if depth > 64 then
                return false, "serializer-depth-limit"
            end
        elseif control == "^t" then
            depth = depth - 1

            if depth == 0 then
                closed = true
            end
        elseif control == "^^" then
            return false, "serializer-unclosed-table"
        elseif
            control ~= "^S"
            and control ~= "^N"
            and control ~= "^F"
            and control ~= "^f"
            and control ~= "^B"
            and control ~= "^b"
            and control ~= "^Z"
        then
            return false, "invalid-serializer-token"
        end
    end

    if not terminated then
        return false, "serializer-missing-terminator"
    end

    return true
end

-- Dependencies are trusted application functions. Parsing never calls predicates,
-- compiles Lua, registers definitions or writes to SavedVariables.
-- Returns a codec with Encode and Decode methods bound to the injected serialize, deserialize, compress and decompress
-- functions, or nil and a reason when one is missing.
function data.NewCodec(dependencies)
    if type(dependencies) ~= "table" then
        return nil, "missing-codec-dependencies"
    end

    for _, key in ipairs({ "serialize", "deserialize", "compress", "decompress" }) do
        if type(dependencies[key]) ~= "function" then
            return nil, "missing-codec-dependency"
        end
    end

    local codec = {}

    -- Encodes a portable table as an export string; an envelope (format "RotationMaster") gets the "RM1:" marker and a
    -- legacy body is unmarked. Returns the string, or nil and a reason code (size limits, shape, compression mismatch).
    function codec:Encode(value)
        local portable, why = data.CheckPortable(value)

        if not portable then
            return nil, why.code
        end
        if type(value) ~= "table" then
            return nil, "expected-root-table"
        end

        local ok, raw = pcall(dependencies.serialize, value)

        if not ok or type(raw) ~= "string" then
            return nil, "serialize-error"
        end
        if #raw > maxSerialized then
            return nil, "serialized-size-limit"
        end

        local shape, shapeError = serializerShape(raw)

        if not shape then
            return nil, shapeError
        end

        local compressedOk, stream = pcall(dependencies.compress, raw)

        if not compressedOk or type(stream) ~= "string" then
            return nil, "compress-error"
        end
        if #stream > maxCompressed then
            return nil, "compressed-size-limit"
        end

        local expected, errorCode = decompressedSize(stream)

        if not expected then
            return nil, errorCode
        end
        if expected ~= #raw then
            return nil, "compression-size-mismatch"
        end

        local encoded = data.EncodeBase64(stream)
        return (value.format == "RotationMaster" and "RM1:" or "") .. encoded
    end

    -- Decodes pasted text without trusting it: normalizes wrapping, checks the marker, Base64, the declared size, then
    -- the serializer shape, and only then deserializes. Returns { value, kind = "envelope" | "legacy", original,
    -- transportVersion }, or nil and a reason code. Nothing is executed or saved.
    function codec:Decode(text)
        if type(text) ~= "string" then
            return nil, "expected-import-string"
        end
        if #text > maxInput then
            return nil, "import-size-limit"
        end

        local payload = addon:NormalizeImportText(text)
        local transport = payload:match("^RM%d+:")

        if transport and transport ~= "RM1:" then
            return nil, "unsupported-transport-version"
        end

        local stream, errorCode = base64(transport and payload:sub(#transport + 1) or payload)

        if not stream then
            return nil, errorCode
        end

        local expected, why = decompressedSize(stream)

        if not expected then
            return nil, why
        end

        local ok, raw = pcall(dependencies.decompress, stream)

        if not ok or type(raw) ~= "string" then
            return nil, "decompress-error"
        end
        if #raw ~= expected then
            return nil, "decompression-size-mismatch"
        end

        local shape, shapeError = serializerShape(raw)

        if not shape then
            return nil, shapeError
        end

        local parsed, success, value = pcall(dependencies.deserialize, raw)

        if not parsed or not success or type(value) ~= "table" then
            return nil, "deserialize-error"
        end

        local portable, problem = data.CheckPortable(value)

        if not portable then
            return nil, problem.code
        end
        if transport and value.format ~= "RotationMaster" then
            return nil, "envelope-marker-mismatch"
        end

        return {
            value = value,
            kind = value.format == "RotationMaster" and "envelope" or "legacy",
            original = text,
            transportVersion = transport and 1 or nil,
        }
    end

    return codec
end
