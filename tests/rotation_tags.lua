local make = dofile('tests/fixtures/rotation_data.lua')
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local data, envelope, validation = make()
    local addon = { RotationData = data }
    local env = setmetatable({}, { __index = _G })
    local h = io.open('Data/tags.lua')

    if h then
        h:close()
        local f = assert(loadfile('Data/tags.lua'))
        setfenv(f, env)
        f('rotationmaster', addon)
    end

    return data, envelope, validation
end

test('tags parse custom labels quotes and commas while normalizing duplicates', function()
    local d = fixture()
    assert(d.ParseRotationTags, 'tag parser missing')
    local tags = assert(d.ParseRotationTags(' AOE, PVP, MyLittlePony, aoe, "Dungeon, heroic", "say ""yes"""'))

    assert(
        #tags == 5
            and tags[1] == 'AOE'
            and tags[3] == 'MyLittlePony'
            and tags[4] == 'Dungeon, heroic'
            and tags[5] == 'say "yes"'
    )

    assert(d.ParseRotationTags(d.FormatRotationTags(tags))[5] == tags[5])
    assert(#d.ParseRotationTags('') == 0)
end)

test('tag shape bounds and malformed input fail without altering the input', function()
    local d = fixture()
    assert(not d.NormalizeRotationTags({ [1] = 'AOE', [3] = 'PVP' }))
    assert(not d.NormalizeRotationTags({ false }))
    assert(not d.NormalizeRotationTags({ string.rep('x', 65) }))
    assert(not d.ParseRotationTags('"unclosed'))
    assert(not d.ParseRotationTags('one' .. string.char(0) .. 'two'))
    local many = {}

    for i = 1, 65 do
        many[i] = 'Tag' .. i
    end

    assert(not d.NormalizeRotationTags(many))
    local original = { '  AOE  ', 'aoe' }
    assert(#d.NormalizeRotationTags(original) == 1 and original[1] == '  AOE  ')
end)

test('body tags are validated and override inherited manifest tags including explicit empty lists', function()
    local d, envelope, options = fixture()
    local value = envelope()
    value.body.tags = { 'AOE', 'MyLittlePony' }
    assert(d.ValidateEnvelope(value, options).valid)
    assert(d.GetRotationTags(value)[2] == 'MyLittlePony')
    value.body.tags = {}
    assert(#d.GetRotationTags(value) == 0)
    value.body.tags = nil
    assert(d.GetRotationTags(value)[1] == 'leveling')
    value.body.tags = { false }
    assert(not d.ValidateEnvelope(value, options).valid)
end)

test(
    'roster tags and unified search include inherited labels and supplied metadata without changing saved bodies',
    function()
        local f = F.new()
        local a = f.addon
        local data = fixture()
        a.RotationData = data
        local h = io.open('Core/rotation_tags.lua')

        if h then
            h:close()
            f.load('Core/rotation_tags.lua')
        end

        assert(a.GetRotationTagView, 'tag view missing')
        a.GetDefaultIdForRuntime = function() end

        a.db.profile.rotations = {
            [0] = {
                mine = {
                    name = 'Name',
                    description = 'Healing uptime',
                    metadata = { author = 'PreZ', realm = 'Realm', email = 'supplied@example.test' },
                },
            },
        }

        a.db.profile.rotationLibrary = {
            origins = {
                [0] = {
                    mine = {
                        manifest = {
                            tags = { 'Raid', 'MyLittlePony' },
                            sources = { { title = 'Guide', url = 'https://example.test/guide' } },
                        },
                    },
                },
            },
        }

        local view = a:GetRotationTagView(0, 'mine')
        assert(data.GetRotationTags(view)[2] == 'MyLittlePony')
        local text = data.RotationSearchText(view)

        for _, query in ipairs({ 'healing', 'prez', 'realm', 'supplied@example.test', 'mylittlepony', 'guide' }) do
            assert(text:find(query, 1, true), query .. ' missing from search')
        end

        assert(a.db.profile.rotations[0].mine.tags == nil)
        a.db.profile.rotations[0].mine.tags = {}
        assert(#data.GetRotationTags(a:GetRotationTagView(0, 'mine')) == 0)
    end
)

test('tag length counts UTF-8 characters and rejects malformed encodings', function()
    local d = fixture()
    local unicode = string.rep('界', 64)
    assert(d.NormalizeRotationTags({ unicode }))
    assert(not d.NormalizeRotationTags({ unicode .. '界' }))
    assert(not d.NormalizeRotationTags({ string.char(192, 128) }))
    assert(not d.NormalizeRotationTags({ string.char(237, 160, 128) }))
end)

test('envelope tags obey the same bounds as editable body tags', function()
    local d, envelope, options = fixture()
    local source = envelope()
    source.tags = { string.rep('x', 65) }
    assert(not d.ValidateEnvelope(source, options).valid)
end)

test('search presentation tolerates malformed optional metadata so invalid rotations stay discoverable', function()
    local d = fixture()

    local text = d.RotationSearchText({
        body = { name = 'Repair me', description = {}, metadata = false, tags = false },
    })

    assert(text:find('repair me', 1, true))
end)

test('Unicode control codepoints are refused by normalization and import validation', function()
    local d, envelope, options = fixture()

    for _, byte in ipairs({ 128, 133, 159 }) do
        local control = 'A' .. string.char(194, byte) .. 'B'
        assert(not d.NormalizeRotationTags({ control }), 'Unicode control accepted')
        local value = envelope()
        value.body.tags = { control }
        assert(not d.ValidateEnvelope(value, options).valid)
    end
end)

test('tag filters accept multiple labels with explicit Any or All semantics', function()
    local d = fixture()
    local tags = { 'PVP', 'Frost', 'Solo' }
    assert(d.RotationTagMatches(tags, { 'pvp', 'Raid' }, 'any'))
    assert(not d.RotationTagMatches(tags, { 'pvp', 'Raid' }, 'all'))
    assert(d.RotationTagMatches(tags, { 'pvp', 'FROST' }, 'all') and d.RotationTagMatches(tags, {}, 'all'))
end)

finish()
