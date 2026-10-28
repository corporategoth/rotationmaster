-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(profile, char)
    local a = { db = { profile = profile, char = char }, warnings = {} }
    assert(loadfile('Data/plain.lua'))('rotationmaster', a)

    a.warn = function(_, ...)
        a.warnings[#a.warnings + 1] = { ... }
    end

    a.db.SetProfile = function()
        error('scoped initialization changed profile')
    end

    local file = assert(io.open('init.lua'))
    local source = file:read('*a')
    file:close()
    local actual = assert(source:match('(local function moveProfileItems%(%).-)%s*function addon:augmentDefaults'))
    local fn = assert(loadstring('local addon,L=... ' .. actual .. '\nreturn moveProfileItems'))
    local run = fn(a, setmetatable({}, { __index = function(_, k) return k end }))
    return a, run
end

test(
    'scoped init migrates only nonempty unrelated character settings into empty profile fields without moving profiles',
    function()
        local rotations = { [0] = { old = { name = 'Unknown' } } }
        local sourceItems = { set = { name = 'Items', items = { 403 } } }
        local announcements = { { name = 'Keep' } }

        local a, run = fixture({ version = 3, rotationStore = {}, itemsets = {}, announces = {} }, {
            rotations = rotations,
            itemsets = sourceItems,
            announces = announcements,
        })

        run()
        assert(a.db.char.rotations == rotations and a.db.profile.rotations == nil)
        assert(a.db.char.itemsets == nil and a.db.char.announces == nil and a.db.profile.itemsets.set.items[1] == 403)
        assert(a.db.profile.itemsets ~= sourceItems and a.db.profile.announces ~= announcements and #a.warnings == 0)
        run()
        assert(#a.warnings == 0)
    end
)

test('scoped init preserves conflicting malformed and cyclic character settings with a recovery warning', function()
    for _, source in ipairs({ false, { old = {} }, setmetatable({}, { __index = {} }) }) do
        local a, run = fixture({ rotationStore = {}, itemsets = { current = {} } }, {
            rotations = { [0] = { unknown = {} } },
            itemsets = source,
        })

        run()
        assert(a.db.char.itemsets == source and a.db.profile.itemsets.current and #a.warnings == 1)
    end

    local cycle = {}
    cycle.self = cycle
    local a, run = fixture({ rotationStore = {}, itemsets = {} }, { itemsets = cycle })
    run()
    assert(a.db.char.itemsets == cycle and next(a.db.profile.itemsets) == nil and #a.warnings == 1)
end)

finish()
