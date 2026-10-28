-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local fixture = dofile('tests/fixtures/codec.lua')
local test, finish = F.suite()

test('new envelopes and legacy bodies roundtrip with Unicode, false and priority order', function()
    local data, deps = fixture()
    local codec = assert(data.NewCodec(deps))
    local _, envelope = make()
    local value = envelope()
    value.body.name = 'Shaman 雪'
    value.body.disabled = false
    value.body.description = 'Shield upkeep 雪'
    value.body.metadata = { author = 'PreZ', version = '2' }
    local encoded = assert(codec:Encode(value))
    assert(encoded:sub(1, 4) == 'RM1:')
    local decoded = assert(codec:Decode(' \r\n' .. encoded .. '\n'))
    assert(decoded.kind == 'envelope' and decoded.value.body.name == 'Shaman 雪')
    assert(decoded.value.body.disabled == false and decoded.value.body.rotation[1].action == 403)
    assert(decoded.value.body.description == 'Shield upkeep 雪' and decoded.value.body.metadata.author == 'PreZ')
    local legacy = assert(codec:Encode(value.body))
    assert(legacy:sub(1, 4) ~= 'RM1:')
    decoded = assert(codec:Decode(legacy))
    assert(decoded.kind == 'legacy' and decoded.original == legacy)
    assert(decoded.value.description == 'Shield upkeep 雪' and decoded.value.metadata.version == '2')
end)

test('strict Base64 accepts ordinary wrapping but rejects junk, padding and noncanonical tail bits', function()
    local data, deps, calls = fixture()
    local codec = assert(data.NewCodec(deps))
    local encoded = assert(codec:Encode({ name = 'x', rotation = {}, cooldowns = {} }))
    local wrapped = encoded:sub(1, 8) .. '\r\n' .. encoded:sub(9)
    assert(codec:Decode(wrapped))

    for _, text in ipairs({ '!', 'A===', 'AAAA=', 'AA=A', 'AB==', 'AAB=', 'RM9:' .. encoded, encoded .. '!' }) do
        local before = calls.decompress
        local decoded, why = codec:Decode(text)
        assert(not decoded and why, 'invalid input accepted: ' .. text)
        assert(calls.decompress == before, 'bad transport reached decompressor')
    end
end)

test('compressed expansion and future transport are rejected before invoking decompressor', function()
    local data, deps, calls, lib = fixture()
    local codec = assert(data.NewCodec(deps))

    for _, stream in ipairs({
        string.char(3, 0, 255, 255, 255),
        string.char(4) .. 'native',
        string.char(130) .. 'filtered',
        assert(lib:CompressLZW(string.rep('a', 1048577))),
    }) do
        local decoded, why = codec:Decode(data.EncodeBase64(stream))
        assert(not decoded and why)
        assert(calls.decompress == 0, 'unbounded stream reached decompressor')
    end
end)

test('serializer depth, tuple and token limits stop the recursive parser before entry', function()
    local data, deps, calls = fixture()
    local codec = assert(data.NewCodec(deps))

    local cases = {
        '^1' .. string.rep('^T^Sa', 70) .. '^N1' .. string.rep('^t', 70) .. '^^',
        '^1^T^t^N2^^',
        '^1^T' .. string.rep('^Sa^N1', 21000) .. '^t^^',
    }

    for _, raw in ipairs(cases) do
        local decoded, why = codec:Decode(data.EncodeBase64(string.char(1) .. raw))
        assert(not decoded and why)
        assert(calls.deserialize == 0, 'unbounded serializer reached recursive parser')
    end
end)

test('malformed compressed data and nonportable decoded values fail explicitly', function()
    local data, deps = fixture()
    local codec = assert(data.NewCodec(deps))

    for _, stream in ipairs({
        string.char(2),
        string.char(2, 255),
        string.char(3),
        string.char(1) .. '^1^T^Skey^Ninf^t^^',
    }) do
        local decoded, why = codec:Decode(data.EncodeBase64(stream))
        assert(not decoded and why)
    end

    assert(not codec:Encode({ callback = function() end }))
end)

test('golden exports from original bundled 90083 decode in all three legacy codecs', function()
    local data, deps = fixture()
    local codec = assert(data.NewCodec(deps))
    local count = 0

    for _, golden in ipairs(dofile('tests/fixtures/legacy_rotation_exports.lua')) do
        local decoded, why = codec:Decode(golden.text)
        assert(decoded, why)
        assert(decoded.kind == 'legacy' and decoded.value.name == 'Legacy Shaman 雪' and decoded.value.disabled == false)

        assert(
            #decoded.value.rotation == 12
                and decoded.value.rotation[1].action == 404
                and decoded.value.rotation[12].action == 415
        )

        assert(decoded.value.rotation[3].conditions.value[2].value.spell == 'Lightning Shield')
        count = count + 1
    end

    assert(count == 3)
end)

test('export refuses serializer structures that the matching importer cannot accept', function()
    local data, deps = fixture()
    local codec = assert(data.NewCodec(deps))
    local wide = {}

    for i = 1, 9999 do
        wide[i] = false
    end

    local nested = {}
    local cursor = nested

    for _ = 1, 64 do
        cursor.a = {}
        cursor = cursor.a
    end

    for _, value in ipairs({ wide, nested }) do
        assert(data.CheckPortable(value), 'fixture must reach the codec-specific bound')
        local encoded, why = codec:Encode(value)

        assert(
            not encoded and (why == 'serializer-token-limit' or why == 'serializer-depth-limit'),
            'export produced a string that its matching importer refuses'
        )
    end
end)

test('unterminated Huffman codebooks are refused before the quadratic library map scanner', function()
    local data, deps, calls = fixture()
    local codec = assert(data.NewCodec(deps))
    local stream = string.char(3, 0, 1, 0, 0, 0) .. string.rep('\0', 2048)
    local encoded = assert(data.EncodeBase64(stream))
    jit.off()
    local ticks = 0

    debug.sethook(function()
        ticks = ticks + 1

        if ticks > 2000 then
            error('Huffman preflight exceeded budget')
        end
    end, '', 1000)

    local ok, decoded, why = pcall(codec.Decode, codec, encoded)
    debug.sethook()
    jit.on()
    assert(ok and not decoded and why == 'invalid-huffman-codebook')
    assert(calls.decompress == 0, 'malformed codebook reached the unbounded library scanner')
end)

test('actual legacy transports enter the session preview without rewriting their contents', function()
    local data, deps = fixture()
    local session = data.NewImportSession(assert(data.NewCodec(deps)), {})

    for _, golden in ipairs(dofile('tests/fixtures/legacy_rotation_exports.lua')) do
        local candidate = assert(session:Stage(golden.text))
        assert(candidate.original == golden.text and candidate.scopeStatus == 'unknown')
        assert(candidate.value.name == 'Legacy Shaman 雪' and #candidate.value.rotation == 12)
        assert(candidate.value.rotation[1].action == 404 and candidate.value.rotation[12].action == 415)
        assert(not session:GetReady(candidate.token), 'unresolved condition schemas must not be applied')
    end
end)

test('actual transport roundtrips branch modes, arm ordering, guards and nested stable IDs', function()
    local data, deps = fixture()
    local codec = assert(data.NewCodec(deps))
    local _, envelope = make()
    local v = envelope()

    v.body.rotation = {
        {
            id = 'branch',
            type = 'branch',
            mode = 'false',
            conditions = { type = 'NOT', value = {} },
            onTrue = { { id = 'yes', type = 'spell', action = 403 } },
            onFalse = {
                {
                    id = 'nested',
                    type = 'branch',
                    mode = 'true',
                    conditions = {},
                    onTrue = { { id = 'no', type = 'stop', suppress_attack = true } },
                    onFalse = {},
                },
            },
        },
    }

    for _, value in ipairs({ v, v.body }) do
        local decoded = assert(codec:Decode(assert(codec:Encode(value)))).value
        local b = decoded.body or decoded
        local branch = b.rotation[1]
        assert(branch.mode == 'false' and branch.onTrue[1].id == 'yes' and branch.conditions.type == 'NOT')
        assert(branch.onFalse[1].mode == 'true' and branch.onFalse[1].onTrue[1].suppress_attack == true)
        local result = decoded.body and data.ValidateEnvelope(decoded) or data.ValidateBody(decoded)
        assert(result.valid and result.supported and result.resolved)
    end
end)

finish()
