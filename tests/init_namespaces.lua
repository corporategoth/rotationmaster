local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local restore = dofile('tests/fixtures/restore_init_qualifiers.lua')
local mana = '6079c534-5f69-430e-b1bd-b487a31dcdd3'
local food = 'e8d1525c-0412-40c1-95a4-00da22bc169e'
local character = 'b8136123-2bda-4230-a77a-89ea2aed3a1a'
local spells = '8034819e-26f5-4f4e-9153-d8cab5e65f31'

local function pack(...)
    return { n = select('#', ...), ... }
end

local function instrument(a, replaceDuringLoad)
    local calls = { inserts = 0, copies = {}, isin = {} }
    local copy = a.Functions.collections.deepcopy
    local insert = a.Functions.collections.multiinsert
    local isin = a.Functions.values.isin

    for _, name in ipairs({ 'multiinsert', 'deepcopy', 'isin' }) do
        local leaf = a[name]

        a[name] = function(...)
            local caller = debug.getinfo(2, 'S')
            assert(not caller or caller.source ~= '@init.lua', 'LEGACY_INIT_ALIAS_' .. name)
            return leaf(...)
        end
    end

    a.Functions.collections.multiinsert = function(...)
        assert(select('#', ...) == 2, 'insert gained a receiver')
        local target, values = ...
        local old = {}

        for i, v in ipairs(target) do
            old[i] = v
        end

        calls.inserts = calls.inserts + 1

        if replaceDuringLoad then
            a.Functions.collections.multiinsert = function()
                error('REBOUND_INSERT_MUST_NOT_REPLACE_CAPTURE')
            end

            a.Functions.collections.deepcopy = function()
                error('REBOUND_COPY_MUST_NOT_REPLACE_CAPTURE')
            end
        end

        local result = pack(insert(...))
        assert(result.n == 0)

        for i, v in ipairs(values) do
            assert(target[i] == v, 'insert prefix order changed')
        end

        for i, v in ipairs(old) do
            assert(target[#values + i] == v, 'existing suffix reordered')
        end
    end

    a.Functions.collections.deepcopy = function(...)
        assert(select('#', ...) == 1, 'copy gained arguments')
        local input = (...)
        local result = copy(...)

        assert(
            type(input) == 'table' and result ~= input and getmetatable(result) == nil,
            'default copy lost fresh plain top-level table'
        )

        for k, v in pairs(input) do
            assert(rawequal(result[k], v), 'default copy lost shallow identity')
        end

        calls.copies[#calls.copies + 1] = { input = input, result = result }
        return result
    end

    a.Functions.values.isin = function(...)
        assert(select('#', ...) == 2, 'membership gained a receiver')
        local list, tag = ...
        calls.isin[#calls.isin + 1] = { list = list, tag = tag }
        return isin(...)
    end

    return calls
end

local function fixture(product, expansion, replaceDuringLoad)
    local f = F.new(product, expansion, 'SHAMAN')
    local calls = instrument(f.addon, replaceDuringLoad)
    f.load('init.lua')
    return f, f.addon, calls
end

local function defaults(a)
    local value = { global = {}, char = {}, profile = {} }
    a:augmentDefaults(value)
    return value
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end

    return false
end

local function group(profile, id)
    for _, item in ipairs(profile.condition_groups) do
        if item.id == id then
            return item.conditions
        end
    end

    error('missing group')
end

-- Reuse the real main/AceDB fixture without executing the startup suite. Hook
-- the init loader boundary only, before its actual load-time helper captures.
local function persistent(scoped)
    local h = assert(io.open('tests/startup.lua'))
    local source = h:read('*a')
    h:close()
    local first = assert(source:find('\nlocal function initialize', 1, true))
    local prefix = source:sub(1, first - 1)
    local begin = assert(source:find('\nlocal function persistentFixture(', 1, true))
    local stop = assert(source:find('\n-- WoW SavedVariables', begin, true))
    local calls

    local env = setmetatable({
        loadfile = function(path)
            local chunk, why = loadfile(path)

            if not chunk or path ~= 'init.lua' then
                return chunk, why
            end

            return function(name, a)
                calls = instrument(a)
                setfenv(chunk, getfenv(1))
                return chunk(name, a)
            end
        end,
    }, { __index = _G })

    local chunk = assert(loadstring(
        prefix .. source:sub(begin, stop - 1) .. '\nreturn persistentFixture',
        '@init-real-startup-fixture'
    ))

    setfenv(chunk, env)
    local make = chunk()
    local native, a, scripts, load = make(nil, nil, scoped)
    assert(not a.initializationErrorReport, 'real startup failed')
    return native, a, calls, scripts, load
end

test('real client default construction uses canonical insert order and shallow default records', function()
    for _, case in ipairs({
        { 2, 0, 0, 6, 13444, 0 },
        { 5, 1, 7, 13, 31677, 1 },
        { 11, 2, 13, 17, 33448, 3 },
        { 1, 12, 4, 16, 152495, 10 },
    }) do
        local _, a, calls = fixture(case[1], case[2])
        local one = defaults(a)
        local two = defaults(a)
        local items = a:getDefaultItemset(mana)

        assert(
            calls.inserts == case[3] and #items == case[4] and items[1] == case[5] and items[#items] == 2455,
            'client mana defaults changed'
        )

        assert(#a:getDefaultItemset(food) == case[6] and a:getDefaultItemset('missing') == nil)

        assert(
            one.global.itemsets ~= two.global.itemsets
                and one.global.itemsets[mana] == two.global.itemsets[mana]
                and one.global.itemsets[mana].items == items,
            'default nested records were deepened'
        )

        assert(
            one.global.effects ~= two.global.effects
                and one.profile.condition_groups ~= two.profile.condition_groups
                and one.profile.condition_groups[1] == two.profile.condition_groups[1],
            'default shallow identity changed'
        )

        assert(one.char.version == 1 and one.global.version == 1 and one.profile.version == 2 and #calls.copies == 12)
    end
end)

test('canonical insert and copy origins retain load-time captures through member rebinding', function()
    local _, a, calls = fixture(5, 1, true)
    assert(calls.inserts == 7, 'insert was looked up again during construction')
    local first = defaults(a)

    a.Functions.collections.deepcopy = function()
        error('late canonical copy lookup')
    end

    a.deepcopy = function()
        error('late legacy copy lookup')
    end

    local second = defaults(a)

    assert(
        #calls.copies == 12 and first.global.itemsets[mana] == second.global.itemsets[mana],
        'augmentDefaults lost captured copy'
    )
end)

test('talent seeding retains indexed false presence and existing duplicate append behavior', function()
    local _, a, calls = fixture(2, 0)
    local switch = { 'TALENT_TREE_POINTS', TALENT_TREE_POINTS = false, PRIMARY_TALENT_TREE = false }
    local char = { 'PRIMARY_TALENT_TREE', TALENT_TREE_POINTS = false, PRIMARY_TALENT_TREE = false }
    local spell = { 'SPELL_AUTOREPEAT', SPELL_AUTOREPEAT = false }

    local profile = {
        switch_conditions = switch,
        condition_groups = { { id = character, conditions = char }, { id = spells, conditions = spell } },
    }

    local db = { profile = profile }
    a:InitializeTalentTreeConditions('unused', db)
    assert(#switch == 1 and #char == 1 and #spell == 1 and #calls.isin == 5, 'false indexed presence began appending')

    for _, entry in ipairs(calls.isin) do
        assert(entry.list == switch or entry.list == char or entry.list == spell, 'membership copied a profile list')
    end

    switch.TALENT_TREE_POINTS = nil
    switch.PRIMARY_TALENT_TREE = nil
    char.TALENT_TREE_POINTS = nil
    char.PRIMARY_TALENT_TREE = nil
    spell.SPELL_AUTOREPEAT = nil
    a:InitializeTalentTreeConditions(nil, db)

    assert(
        #switch == 3
            and switch[2] == 'TALENT_TREE_POINTS'
            and switch[3] == 'PRIMARY_TALENT_TREE'
            and #char == 3
            and #spell == 2,
        'index-presence quirk changed to value membership'
    )

    a:InitializeTalentTreeConditions(nil, db)
    assert(#switch == 5 and #char == 5 and #spell == 3, 'existing repeat-append behavior changed')
end)

test('both seed sites dispatch to live canonical replacements with exact list and tag arguments', function()
    local _, a = fixture(2, 0)

    local profile = {
        switch_conditions = {},
        condition_groups = { { id = character, conditions = {} }, { id = spells, conditions = {} } },
    }

    local db = { profile = profile }
    local seen = {}

    a.Functions.values.isin = function(...)
        assert(select('#', ...) == 2)
        local list, tag = ...
        seen[#seen + 1] = { list, tag }
        return true
    end

    a:InitializeTalentTreeConditions(nil, db)
    assert(#seen == 5 and #profile.switch_conditions == 0 and #profile.condition_groups[2].conditions == 0)

    assert(
        seen[1][1] == profile.switch_conditions
            and seen[1][2] == 'TALENT_TREE_POINTS'
            and seen[2][2] == 'PRIMARY_TALENT_TREE'
            and seen[3][1] == profile.condition_groups[1].conditions
            and seen[5][1] == profile.condition_groups[2].conditions
            and seen[5][2] == 'SPELL_AUTOREPEAT'
    )

    a.Functions.values.isin = function() return false end
    a:InitializeTalentTreeConditions(nil, db)

    assert(
        #profile.switch_conditions == 2
            and #profile.condition_groups[1].conditions == 2
            and profile.condition_groups[2].conditions[1] == 'SPELL_AUTOREPEAT'
    )
end)

test('actual AceDB startup new reset and copy callbacks preserve saved profile policy', function()
    for _, scoped in ipairs({ false, true }) do
        local _, a, calls = persistent(scoped)
        a.db:SetProfile('Namespace source')

        assert(
            contains(a.db.profile.switch_conditions, 'PRIMARY_TALENT_TREE')
                and contains(group(a.db.profile, character), 'TALENT_TREE_POINTS')
                and contains(group(a.db.profile, spells), 'SPELL_AUTOREPEAT'),
            'new-profile seed callbacks missing'
        )

        local customized = {}

        for _, tag in ipairs(a.db.profile.switch_conditions) do
            if tag ~= 'TALENT_TREE_POINTS' and tag ~= 'PRIMARY_TALENT_TREE' then
                customized[#customized + 1] = tag
            end
        end

        customized[1], customized[2] = customized[2], customized[1]
        a.db.profile.switch_conditions = customized
        local expected = table.concat(customized, ',')
        a.db:SetProfile('Namespace target')
        a.db:CopyProfile('Namespace source')

        assert(
            table.concat(a.db.profile.switch_conditions, ',') == expected,
            'copy seeded or reordered customized array'
        )

        local before = #calls.isin
        a.db:ResetProfile()

        assert(
            #calls.isin >= before + 5 and contains(a.db.profile.switch_conditions, 'PRIMARY_TALENT_TREE') and contains(
                group(a.db.profile, spells),
                'SPELL_AUTOREPEAT'
            ),
            'reset lost actual seed callback'
        )
    end
end)

test('canonical capture and live seed errors propagate without later default or list writes', function()
    local f = F.new(5, 1)
    local marker = {}
    instrument(f.addon)

    f.addon.Functions.collections.multiinsert = function()
        error(marker)
    end

    local ok, why = pcall(f.load, 'init.lua')
    assert(not ok and why == marker, 'construction insert error changed')
    local f = F.new(2, 0)
    instrument(f.addon)

    f.addon.Functions.collections.deepcopy = function()
        error(marker)
    end

    f.load('init.lua')
    local value = { char = {}, global = {}, profile = {} }
    ok, why = pcall(f.addon.augmentDefaults, f.addon, value)

    assert(
        not ok
            and why == marker
            and value.char.version == 1
            and next(value.global) == nil
            and next(value.profile) == nil,
        'copy error/default mutation order changed'
    )

    local _, a = fixture(2, 0)

    a.Functions.values.isin = function()
        error(marker)
    end

    local list = {}

    ok, why = pcall(a.InitializeTalentTreeConditions, a, nil, {
        profile = { switch_conditions = list, condition_groups = {} },
    })

    assert(not ok and why == marker and #list == 0, 'live membership error appended source')
end)

test('new unit-state Switch migration survives profile switches copies and reset without readding removals', function()
    local _, a = persistent(true)

    assert(
        a.db.profile.unitStateSwitchSeeded and contains(a.db.profile.switch_conditions, 'DEAD') and contains(
            a.db.profile.switch_conditions,
            'FRIENDLY'
        )
    )

    a.db:SetProfile('Resurrection rules')
    assert(contains(a.db.profile.switch_conditions, 'DEAD'))
    local custom = {}

    for _, tag in ipairs(a.db.profile.switch_conditions) do
        if tag ~= 'DEAD' then
            custom[#custom + 1] = tag
        end
    end

    a.db.profile.switch_conditions = custom
    a.db:SetProfile('Other rules')
    a.db:SetProfile('Resurrection rules')
    assert(not contains(a.db.profile.switch_conditions, 'DEAD'), 'returning to profile readded removed condition')
    a.db:SetProfile('Copied rules')
    a.db:CopyProfile('Resurrection rules')

    assert(
        a.db.profile.unitStateSwitchSeeded and not contains(a.db.profile.switch_conditions, 'DEAD'),
        'copy readded removed condition'
    )

    a.db:ResetProfile()
    assert(contains(a.db.profile.switch_conditions, 'DEAD') and contains(a.db.profile.switch_conditions, 'FRIENDLY'))
end)

finish()
