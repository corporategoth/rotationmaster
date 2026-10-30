-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Text a stranger can paste must cost time in proportion to its length, and
-- an imported item string is data, never a macro line. Each case here failed
-- before the fix: a long run of spaces froze the client in a quadratic trim,
-- and an item such as "1\n/logout" became a second command in a secure macro.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function timed(label, budget, fn)
    local start = os.clock()
    local a, b, c = fn()
    local took = os.clock() - start
    assert(took < budget, string.format('%s took %.2fs (budget %.2fs)', label, took, budget))
    return a, b, c
end

test('tags: an overlong tag is refused before it is trimmed, and a padded one is trimmed in linear time', function()
    local f = F.new()

    for _, path in ipairs({ 'Data/plain.lua', 'Data/rotation_tree.lua', 'Data/tags.lua' }) do
        f.load(path)
    end

    local data = f.addon.RotationData

    for _, size in ipairs({ 16384, 65536, 262144 }) do
        local tags, why = timed('tag of ' .. size .. ' spaces', 0.25, function()
            return data.NormalizeRotationTags({ 'a' .. string.rep(' ', size) .. 'b' })
        end)

        assert(tags == nil and why == 'tag-length', 'an overlong tag was accepted: ' .. tostring(why))

        timed('blank tag of ' .. size, 0.25, function()
            return data.NormalizeRotationTags({ string.rep(' ', size) })
        end)
    end

    local ok = assert(data.NormalizeRotationTags({
        '  Mythic+  ',
        '   pvp ',
        'mythic+',
        '   ' .. string.rep('x', 64) .. '  ',
    }))

    assert(#ok == 3 and ok[1] == 'Mythic+' and ok[2] == 'pvp' and #ok[3] == 64, 'padding was not trimmed')

    assert(
        data.NormalizeRotationTags({ string.rep(' ', 900) .. 'x' .. string.rep(' ', 100) })[1] == 'x',
        'a 1000-character padded tag was refused'
    )

    assert(select(2, data.NormalizeRotationTags({ string.rep(' ', 2000) })) == 'tag-length')

    local parsed = timed('tag list', 0.25, function()
        return data.ParseRotationTags('a' .. string.rep(' ', 30000) .. 'b, c ')
    end)

    local list = assert(data.ParseRotationTags('  one , "two words" ,\n three  '))
    assert(list[1] == 'one' and list[2] == 'two words' and list[3] == 'three')
end)

test('item sets: a long run of spaces is linear, and the same list trims as before', function()
    local f = F.new()
    f.load('Core/collection_data.lua')
    local a = f.addon
    local codec = { Decode = function() return nil end }

    for _, size in ipairs({ 32768, 131000 }) do
        local text = 'Heal' .. string.rep(' ', size) .. 'stone'
        local parsed, why = timed('item list of ' .. size, 0.5, function() return a:ParseItemSetImport(text, codec) end)
        assert(parsed == nil and why or parsed and #parsed.items == 1, 'unexpected result')

        timed('blank item list of ' .. size, 0.5, function()
            return a:ParseItemSetImport(string.rep(' ', size), codec)
        end)
    end

    local parsed = assert(a:ParseItemSetImport('  5512 ,\t22829,\r\n  Healthstone  \n\n   ', codec))

    assert(
        #parsed.items == 3
            and parsed.items[1] == 5512
            and parsed.items[2] == 22829
            and parsed.items[3] == 'Healthstone',
        'list was not trimmed as before'
    )
end)

-- The real addon, as the other startup-based suites load it.
local source = assert(io.open('tests/startup.lua')):read('*a')
local prefix = assert(source:match('^(.-)\nlocal function initialize'))

local persistent = assert(source:match(
    '(local function persistentFixture%(saved,folder,scoped[,%a]*%).-)\n%-%- WoW SavedVariables'
))

local make = assert(loadstring(prefix .. '\n' .. persistent .. '\nreturn persistentFixture', '@hostile-input'))()

local HOSTILE = {
    '1\n/logout',
    '5512\r/script x()',
    'a;/cast Fireball',
    '[@focus] item:1',
    'x\0y',
    'tab\there',
    "back\\slash",
    'pipe|r',
}

test('item sets: control characters are refused on import and in a profile transfer', function()
    local f = F.new()
    f.load('Core/collection_data.lua')

    for _, item in ipairs({ '1\n/logout', '1\r/logout', 'a\0b', 'a\127b', 'a\1b', 'tab\there' }) do
        local codec = {
            Decode = function()
                return { value = { format = 'RM-ItemSet', version = 1, name = 'Hostile', items = { 5512, item } } }
            end,
        }

        local parsed = f.addon:ParseItemSetImport('RM1:x', codec)
        assert(parsed == nil, 'an item with a control character was imported: ' .. string.format('%q', item))
    end

    local codec = {
        Decode = function()
            return {
                value = {
                    format = 'RM-ItemSet',
                    version = 1,
                    name = 'Fine',
                    items = { 5512, 'Healthstone', "Major Healing Potion" },
                },
            }
        end,
    }

    assert(f.addon:ParseItemSetImport('RM1:x', codec), 'a valid item set was refused')
    local env, a, _, load = make({ RotationMasterDB = {} }, nil, true)
    load('UI/settings_draft.lua')
    load('Core/profile_data.lua')

    local function transfer(items)
        return a:ValidateProfileTransfer({
            itemsets = { ['00000000-0000-4000-8000-000000000001'] = { name = 'Set', items = items } },
        })
    end

    assert(transfer({ 5512, 'Healthstone' }) == true, 'a valid profile item set was refused')

    for _, item in ipairs({ '1\n/logout', '1\r/logout', 'a\0b', 'a\127b', 'a\1b' }) do
        assert(transfer({ item }) == false, 'a profile transfer carried ' .. string.format('%q', item))
    end
end)

test('item sets: nothing a saved or imported item says can add a macro line', function()
    local env, a, _, load = make({ RotationMasterDB = {} }, nil, true)
    local created = {}

    env.CreateFrame = function(kind, name, parent, template)
        local frame = { name = name, attributes = {} }
        function frame:Hide() end
        function frame:SetParent() end

        function frame:GetName()
            return self.name
        end

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
        end

        function frame:GetAttribute(key)
            return self.attributes[key]
        end

        created[#created + 1] = frame
        return frame
    end

    load('Core/itemset_services.lua')
    local id = '00000000-0000-4000-8000-000000000002'
    local items = { 5512, 'Healthstone' }

    for _, text in ipairs(HOSTILE) do
        items[#items + 1] = text
    end

    items[#items + 1] = {}
    items[#items + 1] = true
    a.db.profile.itemsets[id] = { name = 'Hostile', items = items }
    a:UpdateItemSetButtons(id)
    assert(#created > 0, 'no item set button was made')
    local seen

    for _, button in ipairs(created) do
        local text = button.attributes.macrotext
        assert(type(text) == 'string')
        seen = true
        local count = 0

        for line in text:gmatch('[^\n]+') do
            count = count + 1

            assert(
                line:match('^/use %[@[%w]+%] item:[^\n]*$'),
                'a line is not an item line: ' .. string.format('%q', line)
            )

            assert(
                not line:find('[%z\1-\31\127;%[%]|\\]', (line:find('item:', 1, true))),
                'a control character, separator or bracket reached the macro: ' .. string.format('%q', line)
            )
        end

        assert(
            not text:find('/logout', 1, true) or text:find('item:1/logout', 1, true),
            'an extra command line was written'
        )

        assert(count == 2 + #HOSTILE, 'unexpected number of macro lines: ' .. count)
    end

    assert(seen)

    assert(
        created[1].attributes.macrotext:find('item:5512\n', 1, true) and created[1].attributes.macrotext:find(
            'item:Healthstone\n',
            1,
            true
        )
    )
end)

finish()
