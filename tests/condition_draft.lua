local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function data()
    local a = {}

    for _, file in ipairs({ 'Data/plain.lua', 'Data/condition_draft.lua' }) do
        assert(loadfile(file))('rotationmaster', a)
    end

    return a.RotationData
end

test('group edits keep saved conditions detached and preserve unknown leaf fields', function()
    local d = data()
    local original = { type = 'SPELL_KNOWN', spell = 403, future = { x = 7 } }
    local draft = assert(d.NewConditionDraft(original))
    assert(draft:Wrap({}, 'AND'))
    assert(draft:Add({}, { type = 'COMBAT' }))
    local root = draft:Snapshot()

    assert(
        root.type == 'AND'
            and root.value[1].spell == 403
            and root.value[1].future.x == 7
            and root.value[2].type == 'COMBAT'
    )

    assert(original.type == 'SPELL_KNOWN' and original.value == nil)
    root.value[1].future.x = 99
    assert(draft:Snapshot().value[1].future.x == 7)
    assert(draft:Move({ 'value', 2 }, -1))
    assert(draft:Snapshot().value[1].type == 'COMBAT')
    assert(draft:Remove({ 'value', 2 }))
    assert(draft:Unwrap({}))
    assert(draft:Snapshot().type == 'COMBAT')
end)

test('NOT wraps and unwraps explicitly and removal leaves an editable empty operand', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'COMBAT' }))
    assert(draft:Wrap({}, 'NOT'))
    assert(draft:Snapshot().value.type == 'COMBAT')
    assert(draft:Remove({ 'value' }))
    assert(next(draft:Snapshot().value) == nil)
    assert(draft:Replace({ 'value' }, { type = 'SPELL_KNOWN', spell = 403 }))
    assert(draft:Unwrap({}))
    assert(draft:Snapshot().spell == 403)
    assert(draft:Remove({}))
    assert(next(draft:Snapshot()) == nil)
end)

test('invalid paths failed moves and invalid structures leave the entire draft unchanged', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'AND', value = { { type = 'A' }, { type = 'B' } } }))
    assert(not draft:Move({ 'value', 1 }, -1))
    assert(not draft:Replace({ 'extra' }, { type = 'C' }))
    assert(not draft:Replace({}, { type = 'AND', value = { [2] = { type = 'C' } } }))
    assert(not draft:Unwrap({}))
    assert(not draft:Wrap({}, 'X'))
    local added, why = draft:Add({}, false)
    assert(not added and why == 'invalid-condition')
    local absent, reason = d.NewConditionDraft(false)
    assert(not absent and reason == 'invalid-condition')
    local replaced, errorCode = draft:Replace({}, false)
    assert(not replaced and errorCode == 'invalid-condition')
    local root = draft:Snapshot()
    assert(#root.value == 2 and root.value[1].type == 'A' and root.value[2].type == 'B')
end)

test(
    'declared nested custom fields participate without executing definitions or reading unknown data as conditions',
    function()
        local d = data()

        local definitions = {
            CUSTOM = {
                fields = { gate = 'condition', checks = 'condition[]' },
                print = function()
                    error('must not run')
                end,
                evaluate = function()
                    error('must not run')
                end,
            },
        }

        local draft = assert(d.NewConditionDraft({
            type = 'CUSTOM',
            gate = { type = 'A' },
            checks = { { type = 'B' } },
            future = { type = 'inert' },
        }, definitions))

        local rows, complete = draft:Rows(20)
        assert(complete and #rows == 3 and rows[2].path[1] == 'checks' and rows[3].path[1] == 'gate')
        assert(draft:Replace({ 'checks', 1 }, { type = 'C' }))
        assert(draft:Snapshot().checks[1].type == 'C')
        assert(not draft:Replace({ 'future' }, { type = 'BAD' }))
        assert(draft:Snapshot().future.type == 'inert')
    end
)

test('aliases are detached into independent condition operands', function()
    local d = data()
    local shared = { type = 'SPELL_KNOWN', spell = 403 }
    local draft = assert(d.NewConditionDraft({ type = 'AND', value = { shared, shared } }))
    assert(draft:SetDisabled({ 'value', 1 }, true))
    local root = draft:Snapshot()
    assert(root.value[1].disabled and not root.value[2].disabled and not shared.disabled)
end)

test('bounded row snapshots disclose truncation and reject cycles oversized edits and executable data', function()
    local d = data()
    local root = { type = 'AND', value = {} }

    for i = 1, 12 do
        root.value[i] = { type = 'A' }
    end

    local draft = assert(d.NewConditionDraft(root))
    local rows, complete = draft:Rows(5)
    assert(#rows == 5 and complete == false)
    rows[1].path[1] = 'bad'
    assert(#draft:Rows(5)[1].path == 0)
    local cycle = {}
    cycle.value = cycle
    assert(not d.NewConditionDraft(cycle))
    assert(not draft:Replace({}, { type = 'A', code = function() end }))
    assert(not draft:Replace({}, { type = 'A', text = string.rep('x', 262145) }))
    assert(#draft:Snapshot().value == 12)
end)

test('malformed disabled fields remain in snapshots but cannot escape through row presentation', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'COMBAT', disabled = { future = true } }))
    local row = draft:Rows()[1]
    assert(row.disabled == false and row.invalidDisabled == true)
    assert(draft:Snapshot().disabled.future == true)
    assert(draft:SetDisabled({}, false))
    assert(draft:Snapshot().disabled == nil)
end)

test('multiple sibling grouping preserves visual order and refuses incompatible parents atomically', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = { { type = 'A' }, { type = 'B' }, { type = 'C' } },
    }))

    local ok, paths = draft:GroupSelection({ { 'value', 3 }, { 'value', 1 } }, 'OR')
    assert(ok and paths[1][2] == 1)
    local root = draft:Snapshot()

    assert(
        root.value[1].type == 'OR'
            and root.value[1].value[1].type == 'A'
            and root.value[1].value[2].type == 'C'
            and root.value[2].type == 'B'
    )

    assert(not draft:GroupSelection({ { 'value', 1, 'value', 1 }, { 'value', 2 } }, 'AND'))
    assert(draft:Snapshot().value[1].value[1].type == 'A')
end)

test('batch transfers adjust original insertion indices and preserve cross-parent preorder', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = { { type = 'A' }, { type = 'B' }, { type = 'C' }, { type = 'D' } },
    }))

    local ok, paths = draft:Transfer({ { 'value', 3 }, { 'value', 1 } }, { path = {}, index = 5 })
    assert(ok and paths[1][2] == 3 and paths[2][2] == 4)
    local root = draft:Snapshot()

    assert(
        root.value[1].type == 'B'
            and root.value[2].type == 'D'
            and root.value[3].type == 'A'
            and root.value[4].type == 'C'
    )

    draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = {
            { type = 'OR', value = { { type = 'A' }, { type = 'B' } } },
            { type = 'OR', value = { { type = 'C' } } },
        },
    }))

    assert(draft:Transfer({ { 'value', 2, 'value', 1 }, { 'value', 1, 'value', 2 } }, {
        path = { 'value', 1 },
        index = 1,
    }))

    root = draft:Snapshot()

    assert(
        root.value[1].value[1].type == 'B'
            and root.value[1].value[2].type == 'C'
            and root.value[1].value[3].type == 'A'
            and #root.value[2].value == 0
    )
end)

test('invalid overlapping root cyclic and stale transfers never partly remove operands', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = { { type = 'OR', value = { { type = 'A' } } }, { type = 'B' } },
    }))

    for _, case in ipairs({
        { { {} }, { path = { 'value', 1 }, index = 1 } },
        { { { 'value', 1 }, { 'value', 1, 'value', 1 } }, { path = {}, index = 3 } },
        { { { 'value', 1 } }, { path = { 'value', 1 }, index = 1 } },
        { { { 'value', 2 } }, { path = { 'value', 9 }, index = 1 } },
        { { { 'value', 2 } }, { path = {}, index = 99 } },
    }) do
        assert(not draft:Transfer(case[1], case[2]))
    end

    local root = draft:Snapshot()
    assert(#root.value == 2 and root.value[1].value[1].type == 'A' and root.value[2].type == 'B')
end)

test('typed custom list and single slots accept transfers while opaque and occupied slots refuse', function()
    local d = data()
    local definitions = { CUSTOM = { fields = { checks = 'condition[]', gate = 'condition' } } }

    local draft = assert(d.NewConditionDraft({
        type = 'CUSTOM',
        checks = { { type = 'A' }, { type = 'B' } },
        future = {},
    }, definitions))

    assert(draft:Transfer({ { 'checks', 1 } }, { path = {}, field = 'gate' }))
    assert(draft:Snapshot().gate.type == 'A' and draft:Snapshot().checks[1].type == 'B')
    assert(not draft:Transfer({ { 'checks', 1 } }, { path = {}, field = 'gate' }))
    assert(not draft:Transfer({ { 'checks', 1 } }, { path = {}, field = 'future' }))
    assert(draft:Transfer({ { 'gate' } }, { path = {}, field = 'checks', index = 1 }))
    assert(draft:Snapshot().checks[1].type == 'A' and next(draft:Snapshot().gate) == nil)
end)

test('negating each selection toggles independently and batch removal retains unselected siblings', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = { { type = 'A' }, { type = 'NOT', value = { type = 'B' } }, { type = 'C' } },
    }))

    assert(draft:NegateSelection({ { 'value', 1 }, { 'value', 2 } }))
    local root = draft:Snapshot()
    assert(root.value[1].type == 'NOT' and root.value[1].value.type == 'A' and root.value[2].type == 'B')
    assert(draft:RemoveSelection({ { 'value', 3 }, { 'value', 1 } }))
    root = draft:Snapshot()
    assert(#root.value == 1 and root.value[1].type == 'B')
    assert(draft:RemoveSelection({ {} }))
    assert(next(draft:Snapshot()) == nil)
end)

test('adding beside a root leaf or single operand creates an explicit All group', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'A' }))
    local ok, paths = draft:AddSibling({}, { type = 'B' })
    assert(ok and paths[1][2] == 2)
    assert(draft:AddSibling({ 'value', 1 }, { type = 'C' }))
    local root = draft:Snapshot()
    assert(root.type == 'AND' and root.value[1].type == 'A' and root.value[2].type == 'C' and root.value[3].type == 'B')
    draft = assert(d.NewConditionDraft({ type = 'NOT', value = { type = 'A' } }))
    assert(draft:AddSibling({ 'value' }, { type = 'B' }))
    assert(draft:Snapshot().value.type == 'AND' and draft:Snapshot().value.value[2].type == 'B')
end)

test('group names are bounded literal labels and operator changes preserve all operands', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'AND', value = { { type = 'A' } }, future = { x = 3 } }))
    assert(draft:SetName({}, '  Opening checks  '))
    assert(draft:Snapshot().name == 'Opening checks')
    assert(draft:SetGroupType({}, 'OR'))
    assert(draft:Snapshot().future.x == 3 and draft:Snapshot().value[1].type == 'A')
    assert(not draft:SetName({}, string.rep('x', 513)))
    assert(not draft:SetName({}, 'bad\nname'))
    assert(not draft:SetName({ 'value', 1 }, 'leaf'))
    assert(not draft:SetGroupType({}, 'NOT'))
    assert(draft:SetName({}, '   '))
    assert(draft:Snapshot().name == nil)
end)

test('multi-child ungrouping only flattens into the same Boolean parent', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'AND',
        value = { { type = 'AND', value = { { type = 'A' }, { type = 'B' } } }, { type = 'C' } },
    }))

    assert(draft:Unwrap({ 'value', 1 }))
    local root = draft:Snapshot()
    assert(#root.value == 3 and root.value[1].type == 'A' and root.value[2].type == 'B' and root.value[3].type == 'C')
    assert(not draft:Unwrap({}))

    draft = assert(d.NewConditionDraft({
        type = 'OR',
        value = { { type = 'AND', value = { { type = 'A' }, { type = 'B' } } } },
    }))

    assert(not draft:Unwrap({ 'value', 1 }))
    assert(draft:Snapshot().value[1].type == 'AND')
end)

test('palette insertion accepts typed lists slots and relative root placement with detached values', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'A' }))
    local node = { type = 'B', future = { x = 1 } }
    local ok, paths = draft:Insert({ path = {}, relation = 'before' }, node)
    assert(ok and paths[1][2] == 1)
    node.future.x = 9
    local root = draft:Snapshot()

    assert(
        root.type == 'AND' and root.value[1].type == 'B' and root.value[1].future.x == 1 and root.value[2].type == 'A'
    )

    assert(draft:Insert({ path = { 'value', 1 }, relation = 'after' }, { type = 'C' }))
    root = draft:Snapshot()
    assert(root.value[2].type == 'C' and root.value[3].type == 'A')
    assert(draft:Insert({ path = {}, index = 1 }, { type = 'D' }))
    assert(draft:Snapshot().value[1].type == 'D')
    local definitions = { CUSTOM = { fields = { checks = 'condition[]', gate = 'condition' } } }
    draft = assert(d.NewConditionDraft({ type = 'CUSTOM' }, definitions))
    assert(draft:Insert({ path = {}, field = 'checks' }, { type = 'A' }))
    assert(draft:Insert({ path = {}, field = 'gate' }, { type = 'B' }))
    assert(not draft:Insert({ path = {}, field = 'gate' }, { type = 'C' }))
    assert(not draft:Insert({ path = {}, field = 'opaque' }, { type = 'C' }))
    assert(draft:Snapshot().gate.type == 'B' and #draft:Snapshot().checks == 1)
end)

test('palette insertion into an empty root stays editable and invalid targets preserve the draft', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({}))
    assert(draft:Insert({ path = {} }, { type = 'OR', value = {} }))
    assert(not draft:Insert({ path = {}, index = 3 }, { type = 'A' }))
    assert(not draft:Insert({ path = {}, relation = 'sideways' }, { type = 'A' }))
    assert(not draft:Insert({ path = { 'missing' } }, { type = 'A' }))
    assert(draft:Snapshot().type == 'OR' and #draft:Snapshot().value == 0)
end)

test('duplicating a condition inserts an independent copy and duplicates a lone root inside All', function()
    local d = data()
    local draft = assert(d.NewConditionDraft({ type = 'A', future = { x = 1 } }))
    local ok, paths = draft:Duplicate({})
    assert(ok and paths[1][2] == 2)
    assert(draft:Replace(paths[1], { type = 'B', future = { x = 9 } }))
    local root = draft:Snapshot()

    assert(
        root.type == 'AND' and root.value[1].type == 'A' and root.value[1].future.x == 1 and root.value[2].type == 'B'
    )

    assert(draft:Duplicate({ 'value', 1 }))
    root = draft:Snapshot()
    assert(#root.value == 3 and root.value[1].type == 'A' and root.value[2].type == 'A' and root.value[3].type == 'B')
    assert(not draft:Duplicate({ 'bad' }))
    assert(#draft:Snapshot().value == 3)
end)

test('negation toggles preserve projected group names and disabled state without silently losing conflicts', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'NOT',
        name = 'Named guard',
        disabled = true,
        value = { type = 'AND', value = { { type = 'A' } } },
    }))

    assert(draft:NegateSelection({ {} }))
    local root = draft:Snapshot()
    assert(root.type == 'AND' and root.name == 'Named guard' and root.disabled == true)

    draft = assert(d.NewConditionDraft({
        type = 'NOT',
        name = 'Outer',
        value = { type = 'AND', name = 'Inner', value = {} },
    }))

    assert(not draft:NegateSelection({ {} }))
    assert(draft:Snapshot().name == 'Outer' and draft:Snapshot().value.name == 'Inner')
end)

test('projected disable and enable are atomic properties across hidden NOT wrappers', function()
    local d = data()

    local draft = assert(d.NewConditionDraft({
        type = 'NOT',
        disabled = true,
        value = { type = 'A', disabled = true },
    }))

    assert(draft:SetProjectedDisabled({}, false))
    assert(draft:Snapshot().disabled == nil and draft:Snapshot().value.disabled == nil)
    assert(draft:SetProjectedDisabled({}, true))
    assert(draft:Snapshot().disabled == true and draft:Snapshot().value.disabled == nil)
end)

finish()
