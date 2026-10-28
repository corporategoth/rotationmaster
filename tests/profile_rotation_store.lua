-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    local data, deps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = data
    f.load('Data/catalog.lua')
    f.load('Data/rotation_store.lua')
    return a, assert(data.NewCodec(deps))
end

local function body(name)
    return { name = name or 'Step', rotation = {}, cooldowns = {} }
end

local function profile()
    return {
        version = 2,
        rotationStore = {
            version = 1,
            classes = {
                SHAMAN = { [0] = { same = { body = body('Class') } }, [2] = { same = { body = body('Spec') } } },
                MAGE = { [0] = { same = { body = body('Mage') } } },
            },
            characters = {
                ['A - Realm'] = { class = 'SHAMAN', specs = { [0] = { same = { body = body('Character') } } } },
                ['B - Realm'] = { class = 'MAGE', specs = { [3] = { same = { body = body('Other') } } } },
            },
            legacy = {
                rotations = { [0] = { unknown = body('Unknown') } },
                origins = { [0] = { orphan = { future = 'preserved' } } },
                imports = { [2] = { orphan = { future = 2 } } },
                comparisons = { [3] = { orphan = { future = 3 } } },
                evidence = { profileName = 'SHAMAN', spec = 0 },
            },
        },
    }
end

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

test('scoped profiles round trip through actual wire codec with all owners and numeric specs', function()
    local a, codec = fixture()
    local p = profile()
    local before = a:CopySettingsData(p)
    assert(a:ValidateProfileTransfer(p), 'scoped root rejected')
    local wire = assert(a:ProfileToPortable(p))
    assert(wire.rotationStore.classes.SHAMAN['0'] and not wire.rotationStore.classes.SHAMAN[0])
    assert(wire.rotationStore.characters['A - Realm'].specs['0'])
    assert(wire.rotationStore.legacy.rotations['0'])
    local text = assert(codec:Encode({ format = 'RM-Profile', version = 1, profile = wire }))
    local result = assert(a:ProfileFromPortable(assert(codec:Decode(text)).value.profile))
    assert(a:ValidateProfileTransfer(result) and equal(result, p) and equal(p, before))
    result.rotationStore.classes.SHAMAN[0].same.body.name = 'Changed'
    assert(p.rotationStore.classes.SHAMAN[0].same.body.name == 'Class')
end)

test('all source lineage comparison and imported sidecars survive unchanged', function()
    local a = fixture()
    local data = a.RotationData
    local _, make = dofile('tests/fixtures/rotation_data.lua')()
    local pack = make()

    local catalog = assert(data.NewCatalog({
        newId = (function()
            local n = 0

            return function()
                n = n + 1
                return n == 1 and 'clone' or 'clone-step-' .. n
            end
        end)(),
    }))

    assert(catalog:RegisterBuiltin(pack))
    assert(catalog:Clone({ kind = 'builtin', id = pack.id }, 'Copy'))
    local view = catalog:Get({ kind = 'custom', id = 'clone' })
    local manifest = a:CopySettingsData(view.envelope)
    manifest.body = nil
    local p = profile()

    p.rotationStore.classes.SHAMAN[0].clone = {
        body = view.envelope.body,
        origin = { manifest = manifest, lineage = view.lineage },
        comparison = { kind = 'builtin', id = pack.id, origins = { ['step-1'] = 'source-step' } },
    }

    local imported = a:CopySettingsData(manifest)
    imported.id = 'imported'

    p.rotationStore.classes.SHAMAN[0].imported = {
        body = body(),
        imported = { manifest = imported, sourceId = 'source', sourceRevision = 1, stepOrigins = {} },
    }

    assert(a:ValidateProfileTransfer(p))
    assert(equal(p, assert(a:ProfileFromPortable(assert(a:ProfileToPortable(p))))))
end)

test('safe incomplete scoped bodies remain available for later repair', function()
    local a = fixture()
    local p = profile()
    p.rotationStore.classes.SHAMAN[0].same.body.rotation = false
    assert(a:ValidateProfileTransfer(p))
    local result = assert(a:ProfileFromPortable(assert(a:ProfileToPortable(p))))
    assert(result.rotationStore.classes.SHAMAN[0].same.body.rotation == false)
end)

test('missing scoped root does not appear during old profile conversion', function()
    local a = fixture()

    local p = {
        version = 2,
        rotations = { [0] = { old = body() } },
        rotationLibrary = {
            preferences = {},
            origins = { [0] = {} },
            imports = { [0] = {} },
            comparisons = { [0] = {} },
        },
    }

    assert(a:ValidateProfileTransfer(p))
    local wire = assert(a:ProfileToPortable(p))
    assert(wire.rotationStore == nil)
    assert(equal(p, a:ProfileFromPortable(wire)))
end)

test('new store validation rejects malformed owner provenance metadata without writes', function()
    local a = fixture()

    for _, change in ipairs({
        function(s)
            s.version = 2
        end,
        function(s)
            s.classes.UNKNOWN = {}
        end,
        function(s)
            s.characters['A - Realm'].class = nil
        end,
        function(s)
            s.legacy.extra = true
        end,
        function(s)
            s.classes.SHAMAN[0].same.origin = {}
        end,
    }) do
        local p = profile()
        change(p.rotationStore)
        local before = a:CopySettingsData(p)
        assert(not a:ValidateProfileTransfer(p), 'malformed root accepted')
        assert(equal(p, before))
    end
end)

test('store structural aliases cannot cross owners in profile transfer validation', function()
    local a = fixture()
    local p = profile()
    p.rotationStore.classes.MAGE = p.rotationStore.classes.SHAMAN
    assert(not a:ValidateProfileTransfer(p), 'cross-class map alias accepted')
    p = profile()
    p.rotationStore.characters['A - Realm'].specs = p.rotationStore.classes.SHAMAN
    assert(not a:ValidateProfileTransfer(p), 'cross-owner map alias accepted')
end)

test('decode rejects noncanonical scoped spec keys and duplicate numeric string keys', function()
    local a = fixture()

    for _, key in ipairs({ '00', '01', '-1', '1.5', '1e0', 'inf', -1, .5 }) do
        local wire = a:CopySettingsData(profile())
        wire.rotationStore.classes.SHAMAN = { [key] = {} }
        assert(not a:ProfileFromPortable(wire), 'bad class spec accepted: ' .. tostring(key))
        wire = a:CopySettingsData(profile())
        wire.rotationStore.characters['A - Realm'].specs = { [key] = {} }
        assert(not a:ProfileFromPortable(wire), 'bad character spec accepted: ' .. tostring(key))
        wire = a:CopySettingsData(profile())
        wire.rotationStore.legacy.origins = { [key] = {} }
        assert(not a:ProfileFromPortable(wire), 'bad legacy spec accepted: ' .. tostring(key))
    end

    local wire = profile()
    wire.rotationStore.classes.SHAMAN['0'] = {}
    assert(not a:ProfileFromPortable(wire), 'colliding specs overwritten')
end)

test('encode rejects collisions and invalid native spec keys instead of overwriting', function()
    local a = fixture()

    for _, key in ipairs({ '0', '00', -1, .5 }) do
        local p = profile()
        p.rotationStore.classes.SHAMAN[key] = {}
        assert(not a:ProfileToPortable(p), 'invalid native key accepted')
    end

    local p = { rotations = { [0] = { a = body() }, ['0'] = { b = body() } } }
    assert(not a:ProfileToPortable(p), 'legacy collision overwritten')
end)

test('decoding preserves structural alias and metatable rejection before normalization', function()
    local a = fixture()
    local wire = assert(a:ProfileToPortable(profile()))
    wire.rotationStore.classes.MAGE = wire.rotationStore.classes.SHAMAN
    assert(not a:ProfileFromPortable(wire), 'decode hid shared owner map')
    wire = assert(a:ProfileToPortable(profile()))
    wire.rotationStore.classes.SHAMAN['0'].same.body.payload = wire.rotationStore.classes.SHAMAN
    assert(not a:ProfileFromPortable(wire), 'decode hid payload alias to structural map')
    wire = assert(a:ProfileToPortable(profile()))
    setmetatable(wire.rotationStore.classes.SHAMAN['0'].same.body, {})
    assert(not a:ProfileFromPortable(wire), 'decode erased an unsafe payload metatable')
end)

test('schema metadata is never decoded as specialization maps', function()
    local a = fixture()
    local p = profile()
    p.rotationStore.legacy.evidence = { ['0'] = 'literal', nested = { ['00'] = 'literal' }, array = { 0, 2 } }
    local result = assert(a:ProfileFromPortable(assert(a:ProfileToPortable(p))))
    assert(equal(p, result) and result.rotationStore.legacy.evidence['0'] == 'literal')
end)

test('profile aggregate limits and no executable values remain enforced', function()
    local a = fixture()
    local p = profile()
    p.rotationStore.classes.SHAMAN[0].same.body.run = function() end
    assert(not a:ValidateProfileTransfer(p))
    p = profile()
    p.rotationStore.legacy.evidence = {}

    for i = 1, 8 do
        p.rotationStore.legacy.evidence['part' .. i] = string.rep('x', 150000)
    end

    assert(not a:ValidateProfileTransfer(p), 'whole profile size limit bypassed')
end)

finish()
