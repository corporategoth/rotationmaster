local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Data/plain.lua')
    f.load('Data/tags.lua')
    f.load('Core/conditions.lua')
    local file = io.open('Core/condition_description.lua', 'r')

    if file then
        file:close()
        f.load('Core/condition_description.lua')
    end

    f.addon:RegisterCondition('NUMBER', {
        description = 'Number check',
        fields = { number = 'number' },
        print = function(_, value)
            assert(type(value.number) == 'number')
            return 'number equals ' .. value.number
        end,
        valid = function()
            error('description called semantic validator')
        end,
        evaluate = function()
            error('description evaluated live data')
        end,
    })

    return f.addon
end

test('complete Boolean descriptions retain every leaf and update after edits without evaluating conditions', function()
    local a = fixture()

    local root = {
        type = 'AND',
        value = { { type = 'NUMBER', number = 1 }, { type = 'NOT', value = { type = 'NUMBER', number = 2 } } },
    }

    local description = a:DescribeCondition(root, 0)
    assert(description:find('number equals 1', 1, true) and description:find('number equals 2', 1, true))
    root.value[1].number = 7
    description = a:DescribeCondition(root, 0)
    assert(description:find('number equals 7', 1, true))
end)

test('nested custom code forces a bounded data-only description without running any printer', function()
    local a = fixture()
    local called = false

    a:RegisterCondition('CUSTOM', {
        description = 'Custom condition',
        customCode = true,
        fields = { code = 'string' },
        print = function()
            called = true
            error('ran custom code')
        end,
    })

    local root = {
        type = 'AND',
        value = { { type = 'NUMBER', number = 1 }, { type = 'CUSTOM', code = 'print("hello")' } },
    }

    local description = a:DescribeCondition(root, 0)
    assert(not called and description:find('Custom condition', 1, true) and description:find('hello', 1, true))
end)

test('incomplete printer failures and unknown conditions remain readable without side effects', function()
    local a = fixture()
    local text = a:DescribeCondition({ type = 'NUMBER' }, 0)
    assert(text:find('Number check', 1, true))
    text = a:DescribeCondition({ type = 'FUTURE', setting = 42 }, 0)
    assert(text:find('FUTURE', 1, true) and text:find('42', 1, true))
    local root = { type = 'NUMBER', number = 3 }
    root.loop = root
    text = a:DescribeCondition(root, 0)
    assert(type(text) == 'string' and #text < 10000)
end)

test('oversized builtin descriptions explicitly report truncation instead of overflowing native text', function()
    local a = fixture()
    a:RegisterCondition('LONG', { description = 'Long', print = function() return string.rep('x', 70000) end })
    local text = a:DescribeCondition({ type = 'LONG' }, 0)
    assert(#text <= 65000 and text:find('truncated', 1, true))
end)

test('empty Boolean operands remain explicit so the full expression agrees with engine truth', function()
    local a = fixture()

    a:RegisterCondition('FALSE', {
        description = 'Never',
        valid = function() return true end,
        evaluate = function() return false end,
        print = function() return 'never' end,
    })

    local root = { type = 'OR', value = { {}, { type = 'FALSE' } } }
    assert(a:evaluateConditionResult(root).status == 'match')
    local text = a:DescribeCondition(root, 0)

    assert(
        text:find('Always', 1, true) and text:find('Never', 1, true),
        'empty true operand disappeared from expression'
    )

    text = a:DescribeCondition({ type = 'NOT' }, 0)
    assert(text:find('Incomplete', 1, true), 'missing NOT operand looked like a complete expression')
    text = a:DescribeCondition({ type = 'OR', value = {} }, 0)
    assert(text:find('Never', 1, true), 'empty Any group was described as Always')
end)

test('card summaries ignore disabled presentation flags recursively without running custom printers', function()
    local a = fixture()
    local root = { type = 'AND', value = { { type = 'NUMBER', number = 3, disabled = true } } }
    local text = a:DescribeCardCondition(root, 0)
    assert(text:find('number equals 3', 1, true) and not text:find('reference', 1, true))
    assert(root.value[1].disabled)
    local called = false

    a:RegisterCondition('CUSTOM', {
        customCode = true,
        description = 'Custom',
        print = function()
            called = true
        end,
    })

    a:DescribeCardCondition({ type = 'CUSTOM', disabled = true, code = 'hidden' }, 0)
    assert(not called)
end)

test('an unrestricted empty condition is Always without a diagnostic prefix', function()
    local a = fixture()
    a.printCondition = function() return '' end
    assert(a:DescribeCondition({}, 0) == 'Always')
end)

test('real combat weapon known spell aura and comparison leaves use readable negation', function()
    local f = F.new()
    f.load('Data/plain.lua')
    f.load('Data/tags.lua')
    f.load('Core/conditions.lua')

    for _, file in ipairs({
        'Platform/spells.lua',
        'Conditions/combat.lua',
        'Conditions/weapon.lua',
        'Conditions/known_spell.lua',
        'Conditions/buffs.lua',
        'Conditions/misc.lua',
    }) do
        f.load(file)
    end

    local a = f.addon

    for _, sample in ipairs({
        { { type = 'COMBAT', unit = 'target' }, 'your target is not in combat' },
        { { type = 'COMBAT', unit = 'player' }, 'you are not in combat' },
        { { type = 'WEAPON' }, 'Your main hand weapon is not enchanted' },
        { { type = 'SPELL_KNOWN', spell = 403 }, 'You do not know' },
        { { type = 'SELF_LEVEL', operator = 'LESSTHAN', value = 20 }, 'your level is not less than 20' },
        { { type = 'BUFF', unit = 'target', spell = 324 }, 'your target does not have' },
    }) do
        local text = a:DescribeCardCondition({ type = 'NOT', value = sample[1] }, 0)
        assert(text:find(sample[2], 1, true), text)
        assert(not text:find('{{', 1, true), 'unresolved phrase marker')
    end
end)

test('translated predicate alternatives and compound aura comparisons retain their scope', function()
    local f = F.new()
    f.translations['%s {{!is|is not}} in combat'] = '%s {{!est|ne reste pas}} en combat'

    for _, file in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Platform/spells.lua',
        'Core/conditions.lua',
        'Conditions/combat.lua',
        'Conditions/buffs.lua',
    }) do
        f.load(file)
    end

    assert(
        f.addon:printCondition({ type = 'NOT', value = { type = 'COMBAT', unit = 'target' } }, 0)
            == 'your target ne reste pas en combat'
    )

    local node = { type = 'BUFF_REMAIN', unit = 'target', spell = 324, operator = 'LESSTHAN', value = 5 }
    local positive = f.addon:printCondition(node, 0)
    local negative = f.addon:printCondition({ type = 'NOT', value = node }, 0)
    assert(positive:find('is less than 5', 1, true), positive)

    assert(
        negative:find('your target does not have', 1, true)
            and negative:find('is less than 5', 1, true)
            and not negative:find('is not less', 1, true),
        negative
    )
end)

test('negated proximity counts reverse the outer count and preserve the member qualifier', function()
    local f = F.new()

    for _, file in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Core/conditions.lua',
        'Conditions/spatial_stats.lua',
    }) do
        f.load(file)
    end

    for _, kind in ipairs({ 'HEALTH', 'HEALTHPCT', 'MANA', 'MANAPCT' }) do
        local node = {
            type = 'PROXIMITY_' .. kind .. '_COUNT',
            unit = 'player',
            distance = 10,
            operator = 'GREATERTHAN',
            value = 2,
            healthoperator = 'LESSTHAN',
            manaoperator = 'LESSTHAN',
            health = .5,
            mana = .5,
        }

        local text = f.addon:printCondition({ type = 'NOT', value = node }, 0)

        assert(
            text:find('is not greater than 2', 1, true)
                and text:find('is less than', 1, true)
                and not text:find('is not less', 1, true),
            text
        )
    end
end)

finish()
