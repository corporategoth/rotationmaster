-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local tags = { 'EQUIPPED', 'CARRYING', 'ITEM', 'ITEM_RANGE', 'ITEM_COOLDOWN' }

local expected = {
    EQUIPPED = { valid = {}, print = { nullable = 1 } },
    CARRYING = { valid = { isin = 1 }, print = { nullable = 2 } },
    ITEM = { valid = {}, print = { nullable = 1 } },
    ITEM_RANGE = { valid = {}, print = { nullable = 1 } },
    ITEM_COOLDOWN = { valid = { isin = 2 }, print = { nullable = 4, compareString = 1 } },
}

local groups = { isin = 'values', nullable = 'presentation', compareString = 'presentation' }

local function fixture(native)
    -- The native shape is Retail's (C_Item with boolean cooldowns, C_Container); no current
    -- client still has the legacy container globals, so that route runs unguarded.
    local f = native and F.new(1, 12) or F.new(nil, nil, nil, { clientApi = false })
    local a, e = f.addon, f.env
    a.db.profile.itemsets = { personal = { name = 'Personal', items = { 10, 11 } }, collision = false }

    a.db.global.itemsets = {
        global = { name = 'Global', items = { 11 } },
        collision = { name = 'Ignored', items = { 11 } },
    }

    a.combatCache = {}
    a.bagContents = {}

    local state = {
        count = { [10] = 2, [11] = 5 },
        equipped = {},
        start = 0,
        duration = 0,
        enabled = true,
        range = true,
        minimum = 1,
        metadata = true,
        calls = {},
    }

    local function call(name)
        state.calls[name] = (state.calls[name] or 0) + 1

        if state.throw == name then
            error('native ' .. name .. ' failed')
        end
    end

    local api = {
        GetItemInfoInstant = function(value) return value == 'Potion' and 10 or tonumber(value) end,
        GetItemInfo = function(id)
            call('metadata')

            if state.metadata then
                return 'Potion ' .. id,
                    '|Hitem:' .. id .. '|h[Potion ' .. id .. ']|h',
                    1,
                    1,
                    state.minimum,
                    'Consumable',
                    'Potion',
                    20,
                    '',
                    123
            end
        end,
        GetItemCount = function(id)
            call('count')
            return (state.count[id] or 0) + (state.equipped[id] and 1 or 0)
        end,
        IsEquippedItem = function(id)
            call('equipped')
            return state.equipped[id] == true
        end,
        GetItemCooldown = function()
            call('cooldown')

            if native then
                return state.start, state.duration, state.enabled
            end

            return state.start, state.duration, state.enabled and 1 or 0
        end,
        ItemHasRange = function() return true end,
        IsItemInRange = function()
            call('range')

            if native or state.range == nil then
                return state.range
            end

            return state.range and 1 or 0
        end,
    }

    if native then
        e.C_Item = api
    else
        for name, callback in pairs(api) do
            e[name] = callback
        end
    end

    local function slots(bag)
        call('slots')
        return bag == 0 and 2 or 0
    end

    local function entry(_, slot)
        call('bag')
        local id = slot == 1 and 10 or 11
        local count = state.count[id] or 0

        if count == 0 then
            return
        end
        if native then
            return { itemID = id, stackCount = count }
        end

        return 123, count, false, 1, false, false, 'item:' .. id, false, false, id
    end

    e.NUM_BAG_SLOTS = 4

    if native then
        e.C_Container = { GetContainerNumSlots = slots, GetContainerItemInfo = entry }
    else
        e.GetContainerNumSlots = slots
        e.GetContainerItemInfo = entry
    end

    e.UnitLevel = function() return 20 end

    e.C_Spell = {
        GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
    }

    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/items.lua', 'Platform/inventory.lua', 'Core/conditions.lua',
        'Conditions/item.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua',
        'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, state, api
end

local function value(tag, item, operator, amount)
    return { type = tag, item = item, operator = operator or 'EQUALS', value = amount or 2 }
end

local function copies(a)
    local result = {}

    for _, tag in ipairs(tags) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        local copy = assert(a:CompileCustomCondition('COPY_' .. tag, source))
        a:RegisterCondition('COPY_' .. tag, copy)
        result[tag] = copy
    end

    return result
end

local function count(text, pattern)
    local _, number = text:gsub(pattern, '')
    return number
end

test('item callbacks select twenty pure helper calls across their explicit owning roots', function()
    local f, a = fixture(true)

    local declared = assert(
        a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/item.lua'],
        'item canonical leaf metadata missing'
    )

    local total = 0

    for name, group in pairs(groups) do
        local path = 'Functions.' .. group .. '.' .. name

        assert(
            declared[path] == 'builtin:utils.lua:' .. name
                and a:ResolveFunctionBinding(declared[path]) == a.Functions[group][name]
        )
    end

    for _, tag in ipairs(tags) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        assert(not source.bindings.Functions, 'opaque namespace table captured')

        for callback, counts in pairs(expected[tag]) do
            for name, group in pairs(groups) do
                local path = 'Functions.' .. group .. '.' .. name
                local number = count(source[callback], path:gsub('%.', '%%.') .. '%(')
                assert(number == (counts[name] or 0), tag .. '.' .. callback .. ' ' .. path .. ' count changed')
                total = total + number
                assert(not source[callback]:find('addon.' .. name .. '(', 1, true), 'legacy pure call remained')
            end
        end

        if tag == 'CARRYING' or tag == 'ITEM_COOLDOWN' then
            for _, name in ipairs({ 'phrase', 'predicate' }) do
                local path = 'Summary.' .. name
                local id = 'builtin:Functions/presentation.lua:' .. name

                assert(
                    source.bindings[path] == id
                        and declared[path] == id
                        and a:ResolveFunctionBinding(id) == a.Functions.presentation[name]
                )

                local calls = count(source.print, path:gsub('%.', '%%.') .. '%(')
                assert(calls == 1)
                total = total + calls
            end
        end

        if tag == 'EQUIPPED' or tag == 'ITEM' or tag == 'ITEM_RANGE' then
            local path = 'Literal.phrase'
            local id = 'builtin:Functions/presentation.lua:phrase'

            assert(
                source.bindings[path] == id
                    and declared[path] == id
                    and a:ResolveFunctionBinding(id) == a.Functions.presentation.phrase
            )

            local calls = count(source.print, 'Literal%.phrase%(')
            assert(calls == 1)
            total = total + calls
        end

        assert(source.widget:find('"Inventory_EditBox"', 1, true), 'item reference scope changed')

        assert(
            source.evaluate == '\n        return addon:EvaluateItemCondition("' .. tag .. '",value,cache,now)\n    ',
            'evaluation body changed'
        )
    end

    assert(total == 20 and not f.env.Functions)
end)

test('private item descriptor Help bodies captures and source getter identities remain exact', function()
    local _, a = fixture(true)

    for name, hash in pairs({
        get_item_desc = 'fd63ea61',
        itemHelp = '0f2e90aa',
        color = 'a59312f4',
        helpers = '57c6fe6a',
    }) do
        local id = 'builtin:Conditions/item.lua:' .. name
        local record = assert(a.builtinFunctions[id])
        assert(a:FunctionSourceHash(record.source) == hash, 'unchanged private source contract drifted: ' .. name)
        assert(a:ResolveFunctionBinding(id) == a.builtinSourceModules['Conditions/item.lua'](name))
    end
end)

test('real registered item clones preserve validation and summaries for references operators and flags', function()
    for _, native in ipairs({ true, false }) do
        local f, a, state = fixture(native)
        local clones = copies(a)

        for _, tag in ipairs(tags) do
            for _, reference in ipairs({
                'personal',
                'global',
                'collision',
                'missing',
                { 10, 11 },
                { 10 },
                {},
                { [2] = 10 },
                { false },
            }) do
                for _, operator in ipairs({
                    'LESSTHAN',
                    'LESSTHANOREQUALS',
                    'GREATERTHAN',
                    'GREATERTHANOREQUALS',
                    'EQUALS',
                    'NOTEQUALS',
                    'DIVISIBLE',
                    'UNKNOWN',
                }) do
                    local node = value(tag, reference, operator)

                    for _, flag in ipairs({ false, true, 'invalid' }) do
                        node.notcarrying = flag
                        assert(a.conditionDefinitions[tag].valid(0, node) == clones[tag].valid(0, node))

                        for _, negated in ipairs({ false, true }) do
                            assert(
                                a.conditionDefinitions[tag].print(0, node, negated) == clones[tag].print(
                                    0,
                                    node,
                                    negated
                                ),
                                tag .. ' wording changed'
                            )
                        end
                    end
                end
            end
        end

        state.metadata = false

        for _, tag in ipairs(tags) do
            local node = value(tag, { 10 })
            assert(a.conditionDefinitions[tag].print(0, node) == clones[tag].print(0, node))
        end

        local node = value('EQUIPPED', { 10 })
        state.metadata = true
        assert(a.conditionDefinitions.EQUIPPED.print(0, node) == 'you have |Hitem:10|h[Potion 10]|h equipped')
        assert(clones.EQUIPPED.print(0, node, true) == 'you do not have |Hitem:10|h[Potion 10]|h equipped')
        assert(not f.env.Functions)
    end
end)

test(
    'original and compiled item evaluators retain native and legacy ownership priority and exact cache reuse',
    function()
        for _, native in ipairs({ true, false }) do
            local _, a, state = fixture(native)
            local clones = copies(a)

            for _, tag in ipairs(tags) do
                for _, reference in ipairs({ 'personal', 'global', { 10, 11 }, {} }) do
                    for _, flag in ipairs({ false, true }) do
                        local node = value(tag, reference)
                        node.notcarrying = flag
                        local cache = {}
                        local original, why = a.conditionDefinitions[tag].evaluate(node, cache, 100)
                        local before = a:CopySettingsData(state.calls)
                        local actual, reason = clones[tag].evaluate(node, cache, 100)

                        assert(
                            original == actual and why == reason and a:SettingsDataEqual(before, state.calls),
                            'clone changed observation/cache behavior for ' .. tag
                        )
                    end
                end
            end

            state.count[10] = 0
            local node = value('CARRYING', 'personal', 'EQUALS', 5)
            assert(clones.CARRYING.evaluate(node, {}, 100) == true)
            state.equipped[10] = true
            assert(clones.EQUIPPED.evaluate(value('EQUIPPED', 'personal'), {}, 100) == true)
        end
    end
)

test('unavailable item observations remain unavailable beneath NOT for original and compiled conditions', function()
    for _, native in ipairs({ true, false }) do
        local _, a, state = fixture(native)
        copies(a)

        for _, tag in ipairs(tags) do
            local original = value(tag, 'missing')
            local clone = a:CopySettingsData(original)
            clone.type = 'COPY_' .. tag
            local left = a:evaluateConditionResult({ type = 'NOT', value = original })
            local right = a:evaluateConditionResult({ type = 'NOT', value = clone })
            assert(left.status == 'unavailable' and right.status == left.status and right.reason == left.reason)
        end

        for _, entry in ipairs({
            { 'ITEM_RANGE', 'range' },
            { 'ITEM', 'cooldown' },
            { 'ITEM_COOLDOWN', 'cooldown' },
        }) do
            state.throw = entry[2]
            local node = value(entry[1], 'personal')
            local clone = a:CopySettingsData(node)
            clone.type = 'COPY_' .. entry[1]
            local left = a:evaluateConditionResult({ type = 'NOT', value = node })
            local right = a:evaluateConditionResult({ type = 'NOT', value = clone })
            assert(left.status == 'unavailable' and right.status == left.status and right.reason == left.reason)
        end

        state.throw = nil
        state.range = false

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = value('ITEM_RANGE', 'personal') }).status == 'match',
            'known-false control changed'
        )

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = value('COPY_ITEM_RANGE', 'personal') }).status == 'match'
        )
    end
end)

test('restricted native item values remain unavailable in original and cloned NOT guards', function()
    for _, tag in ipairs(tags) do
        local f, a, state, api = fixture(true)
        copies(a)
        local opaque = {}
        local readable = a.Platform.CanReadValue

        a.Platform.CanReadValue = function(self, input)
            if input == opaque then
                return false
            end

            return readable(self, input)
        end

        if tag == 'EQUIPPED' then
            api.IsEquippedItem = function() return opaque end
        elseif tag == 'CARRYING' then
            state.count[10] = opaque
        elseif tag == 'ITEM_RANGE' then
            state.range = opaque
        else
            state.enabled = opaque
        end

        local node = value(tag, 'personal')
        local clone = a:CopySettingsData(node)
        clone.type = 'COPY_' .. tag
        local original = a:evaluateConditionResult({ type = 'NOT', value = node })
        local copied = a:evaluateConditionResult({ type = 'NOT', value = clone })

        assert(
            original.status == 'unavailable' and copied.status == original.status and copied.reason == original.reason,
            tag .. ' restricted observation became actionable'
        )
    end
end)

test('legacy addon pure-helper calls and original stable bindings remain callable in saved custom source', function()
    local _, a = fixture(true)

    assert(a:InstallCustomFunction('LEGACY_ITEM_HELPERS', {
        description = 'Legacy helper consumer',
        args = {},
        returns = {},
        bindings = {},
        code = 'return addon.isin({present=false},"present"),addon.nullable(false),addon.compareString("EQUALS","left","right")',
    }))

    local present, nullable, wording = a:ResolveFunctionBinding('LEGACY_ITEM_HELPERS')()
    assert(present and nullable == false and wording == a.compareString('EQUALS', 'left', 'right'))

    for name in pairs(groups) do
        assert(a:ResolveFunctionBinding('builtin:utils.lua:' .. name) == a[name])
    end
end)

finish()
