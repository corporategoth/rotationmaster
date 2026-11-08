-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Plan-invariant folding (Core/condition_folding.lua): known spells, talents, specialization and your level fold into
-- constants; anything else, and any invariant leaf that is unavailable now, stays; the folded tree evaluates exactly as
-- the original does, including where the evaluator stops at an unavailable child.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

-- Answers per leaf: known[spell] for SPELL_KNOWN ('?' = unavailable); every other leaf by its `answer` field.
local known = {}
local reads = 0
local addon = {}

function addon:evaluateConditionResult(node)
    reads = reads + 1
    local answer = known[node.spell]

    if answer == '?' then
        return { status = 'unavailable', reason = 'restricted-value' }
    end

    return { status = answer and 'match' or 'no-match' }
end

assert(loadfile('Core/condition_folding.lua'))('RotationMaster', addon)

-- Evaluates a tree the way Core/conditions.lua does: in order, stopping at the first unavailable child; NOT keeps
-- unavailable. Leaves: SPELL_KNOWN by `known`, others by their `answer` ('match', 'no-match' or 'unavailable').
local function evaluate(node)
    if node == true then
        return 'match'
    end
    if node == false then
        return 'no-match'
    end

    if node.type == 'AND' or node.type == 'OR' then
        local matched = node.type == 'AND'

        for _, child in ipairs(node.value) do
            local status = evaluate(child)

            if status == 'unavailable' then
                return status
            end
            if node.type == 'AND' and status == 'no-match' then
                return 'no-match'
            end
            if node.type == 'OR' and status == 'match' then
                return 'match'
            end
        end

        return matched and 'match' or 'no-match'
    end

    if node.type == 'NOT' then
        local status = evaluate(node.value)
        return status == 'unavailable' and status or (status == 'match' and 'no-match' or 'match')
    end

    if node.type == 'SPELL_KNOWN' then
        return addon:evaluateConditionResult(node).status
    end

    return node.answer
end

local function k(spell)
    return { type = 'SPELL_KNOWN', spell = spell }
end

local function buff(answer)
    return { type = 'BUFF', unit = 'player', spell = 324, answer = answer }
end

local function NOT(node)
    return { type = 'NOT', value = node }
end

local function AND(...)
    return { type = 'AND', value = { ... } }
end

local function OR(...)
    return { type = 'OR', value = { ... } }
end

test('the shaman shields: a known Water Shield leaves only the buff checks, Lightning Shield never matches', function()
    known = { [408510] = true }
    local water = NOT(OR(buff('no-match'), buff('no-match')))
    local lightning = AND(NOT(k(408510)), NOT(buff('no-match')))
    assert(addon:FoldInvariantConditions(water) == water, 'nothing to fold')
    assert(addon:FoldInvariantConditions(lightning) == false, 'Lightning Shield step cannot match')
    known = { [408510] = false }
    local folded = addon:FoldInvariantConditions(lightning)
    assert(type(folded) == 'table' and folded.type == 'NOT' and folded.value.type == 'BUFF', 'only the buff check left')
end)

test('non-invariant leaves, disabled leaves and unavailable invariants stay', function()
    known = { [1] = '?' }
    local tree = AND(k(1), buff('match'))
    assert(addon:FoldInvariantConditions(tree) == tree)
    local disabled = { type = 'SPELL_KNOWN', spell = 2, disabled = true }
    assert(addon:FoldInvariantConditions(disabled) == disabled)
    assert(next(addon:FoldInvariantConditions({})) == nil)
end)

test('an absorbing constant after an undecided child keeps the evaluator stopping where it did', function()
    known = { [1] = false, [2] = true }
    local tree = AND(buff('unavailable'), k(1), buff('match'))
    local folded = addon:FoldInvariantConditions(tree)
    assert(evaluate(folded) == 'unavailable' and evaluate(NOT(folded)) == 'unavailable', 'still unavailable')

    assert(
        #folded.value == 2 and folded.value[2].type == 'SPELL_KNOWN',
        'the later children are dropped, the leaf kept'
    )

    local first = addon:FoldInvariantConditions(AND(k(1), buff('unavailable')))
    assert(first == false, 'a false first child decides the AND')
end)

test('every combination folds to a tree that evaluates as the original', function()
    local answers = { 'match', 'no-match', 'unavailable' }
    local spells = { true, false, '?' }
    local count = 0

    for _, a in ipairs(answers) do
        for _, s1 in ipairs(spells) do
            for _, s2 in ipairs(spells) do
                known = { [1] = s1, [2] = s2 }

                for _, tree in ipairs({
                    AND(buff(a), k(1), k(2)),
                    OR(k(1), buff(a), NOT(k(2))),
                    NOT(AND(k(1), OR(buff(a), k(2)))),
                    AND(OR(k(2), buff(a)), NOT(k(1)), buff(a)),
                    OR(AND(k(1), buff(a)), AND(NOT(k(1)), k(2))),
                }) do
                    local folded = addon:FoldInvariantConditions(tree)
                    assert(evaluate(folded) == evaluate(tree), 'mismatch')
                    count = count + 1
                end
            end
        end
    end

    assert(count == 135)
end)

test('folding counts the leaves it replaced', function()
    known = { [1] = true, [2] = false }
    local stats = { folded = 0 }
    addon:FoldInvariantConditions(AND(k(1), NOT(k(2)), buff('match')), stats)
    assert(stats.folded == 2, stats.folded)
end)

test('a lone health or power threshold, or NOT of one, is a display gate; anything else is not', function()
    local gate = addon:GetConditionDisplayGate({
        type = 'HEALTHPCT',
        unit = 'target',
        operator = 'LESSTHAN',
        value = .2,
    })

    assert(gate.unit == 'target' and gate.kind == 'health' and gate.operator == 'LESSTHAN' and gate.value == 20)

    gate = addon:GetConditionDisplayGate(NOT({
        type = 'POWERPCT',
        unit = 'player',
        operator = 'LESSTHANOREQUALS',
        value = .5,
    }))

    assert(gate.kind == 'power' and gate.operator == 'GREATERTHAN' and gate.value == 50)
    assert(not addon:GetConditionDisplayGate({ type = 'HEALTHPCT', unit = 'target', operator = 'EQUALS', value = .2 }))

    gate = addon:GetConditionDisplayGate(AND(NOT(NOT({
        type = 'HEALTHPCT',
        unit = 'target',
        operator = 'LESSTHAN',
        value = .2,
    }))))

    assert(gate.operator == 'LESSTHAN', 'a one-child group and a double NOT')

    assert(
        not addon:GetConditionDisplayGate(AND(buff('match'), {
            type = 'HEALTHPCT',
            unit = 'target',
            operator = 'LESSTHAN',
            value = .2,
        }))
    )

    assert(not addon:GetConditionDisplayGate(buff('match')))

    assert(
        not addon:GetConditionDisplayGate({
            type = 'HEALTHPCT',
            unit = 'target',
            operator = 'LESSTHAN',
            value = .2,
            disabled = true,
        })
    )
end)

print(('%d passed, %d failed'):format(pass, fail))

if fail > 0 then
    os.exit(1)
end
