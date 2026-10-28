local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()
local data, envelope, validation = make()
local addon = { RotationData = data }
assert(loadfile('Data/catalog.lua'))('rotationmaster', addon)
assert(loadfile('Data/diff.lua'))('rotationmaster', addon)

local function copy(v)
    return assert(data.CopyData(v))
end

local function find(result, kind, path)
    for _, change in ipairs(result.changes) do
        if change.kind == kind and (not path or change.path == path) then
            return change
        end
    end
end

local function addStep(v, id, action)
    v.body.rotation[#v.body.rotation + 1] = { id = id, type = 'spell', action = action, conditions = {} }
end

test('equal rotations produce an empty complete diff and preserve both inputs', function()
    local left, right = envelope(), envelope()
    local result = data.DiffRotations(left, right)
    assert(result.valid and result.complete and #result.changes == 0)
    assert(left.body.rotation[1].id == 'step-1' and right.body.rotation[1].action == 403)
end)

test('field and nested condition edits include independent before/after values', function()
    local left, right = envelope(), envelope()

    left.body.rotation[1].conditions = {
        type = 'NOT',
        value = { type = 'BUFF', unit = 'player', spell = 324, ownbuff = false },
    }

    right.body.rotation[1].conditions = copy(left.body.rotation[1].conditions)
    right.body.rotation[1].conditions.value.ownbuff = true
    right.body.rotation[1].extraFutureGate = { value = 42 }
    local result = data.DiffRotations(left, right)
    local change = find(result, 'changed', '$.body.rotation[step-1].conditions.value.ownbuff')
    assert(change and change.before == false and change.after == true)
    local added = find(result, 'added', '$.body.rotation[step-1].extraFutureGate')
    assert(added.after.value == 42)
    added.after.value = 99
    assert(right.body.rotation[1].extraFutureGate.value == 42)
end)

test('insertion and removal do not report every shifted priority as a move', function()
    local left = envelope()
    addStep(left, 'step-2', 529)
    addStep(left, 'step-3', 974)
    local right = copy(left)
    table.remove(right.body.rotation, 2)
    table.insert(right.body.rotation, 1, { id = 'step-new', type = 'spell', action = 324 })
    local result = data.DiffRotations(left, right)
    assert(find(result, 'removed', '$.body.rotation[step-2]'))
    assert(find(result, 'added', '$.body.rotation[step-new]'))
    assert(not find(result, 'moved'))
end)

test('a real priority move is distinguished from editing that step', function()
    local left = envelope()
    addStep(left, 'step-2', 529)
    addStep(left, 'step-3', 974)
    local right = copy(left)

    right.body.rotation[1], right.body.rotation[2], right.body.rotation[3] =
        right.body.rotation[2], right.body.rotation[3], right.body.rotation[1]

    right.body.rotation[3].action = 324
    local result = data.DiffRotations(left, right)
    local move = find(result, 'moved', '$.body.rotation[step-1]')
    assert(move and move.fromIndex == 1 and move.toIndex == 3)
    assert(find(result, 'changed', '$.body.rotation[step-1].action'))
end)

test('origin mappings compare clone steps without reporting regenerated IDs as edits', function()
    local left, right = envelope(), envelope()
    right.id = 'clone-id'
    right.revision = 8
    right.body.rotation[1].id = 'clone-step'

    local result = data.DiffRotations(left, right, {
        rightOrigins = { ['clone-step'] = 'step-1' },
        ignoreIdentity = true,
    })

    assert(result.valid and result.complete and #result.changes == 0)
    right.body.rotation[1].action = 974
    result = data.DiffRotations(left, right, { rightOrigins = { ['clone-step'] = 'step-1' }, ignoreIdentity = true })
    assert(#result.changes == 1 and result.changes[1].path == '$.body.rotation[step-1].action')
end)

test('ambiguous step identities and nonportable input fail without misleading changes', function()
    local left, right = envelope(), envelope()
    addStep(right, 'step-1', 974)
    local result = data.DiffRotations(left, right)
    assert(not result.valid and not result.complete and #result.changes == 0)
    assert(result.diagnostics[1].code == 'ambiguous-step-identity')
    right = envelope()
    right.body.self = right.body
    result = data.DiffRotations(left, right)
    assert(not result.valid and result.diagnostics[1].code == 'data-cycle')
end)

test('large ordered comparisons stay bounded and explicitly report truncated output', function()
    local left = envelope()
    left.body.rotation = {}

    for i = 1, 1000 do
        addStep(left, 'step-' .. i, 403)
    end

    local right = copy(left)
    table.insert(right.body.rotation, table.remove(right.body.rotation, 1))
    local ticks = 0

    debug.sethook(function()
        ticks = ticks + 1
        assert(ticks < 20000, 'unbounded priority comparison')
    end, '', 1000)

    local ok, result = pcall(data.DiffRotations, left, right)
    debug.sethook()
    assert(ok and result.valid and result.complete and #result.changes == 1 and result.changes[1].kind == 'moved')
    right = copy(left)

    for _, step in ipairs(right.body.rotation) do
        step.action = 974
    end

    result = data.DiffRotations(left, right)
    assert(result.valid and not result.complete and #result.changes <= 500)
    assert(result.diagnostics[#result.diagnostics].code == 'diff-change-limit')
end)

test('oversized diagnostic paths make the comparison explicitly incomplete', function()
    local left, right = envelope(), envelope()
    local key = string.rep('k', 5000)
    left[key] = 'before'
    right[key] = 'after'
    local result = data.DiffRotations(left, right)
    assert(result.valid and not result.complete)
    assert(result.diagnostics[#result.diagnostics].code == 'diff-path-limit')
end)

test('clone comparison separates source updates, custom changes and actual conflicts', function()
    local n = 0

    local store = assert(data.NewCatalog({
        state = {},
        validation = validation,
        newId = function()
            n = n + 1
            return 'clone-' .. n
        end,
    }))

    local original = envelope()
    assert(store:RegisterBuiltin(original))
    local id = assert(store:Clone(original.id))
    local edited = store:Get(id).envelope
    edited.body.rotation[1].action = 974
    assert(store:Save(id, edited))
    local newer = envelope()
    newer.revision = 2
    newer.body.rotation[1].action = 529
    assert(store:RegisterBuiltin(newer))
    local result = data.CompareClone(store:Get(id), store:Get(original.id))
    assert(result.valid and result.complete)
    assert(find(result.sourceChanges, 'changed', '$.body.rotation[step-1].action'))
    assert(find(result.customChanges, 'changed', '$.body.rotation[step-1].action'))
    assert(#result.conflicts == 1 and result.conflicts[1].path == '$.body.rotation[step-1].action')
    assert(store:Get(id).envelope.body.rotation[1].action == 974, 'comparison merged source changes')
end)

test('clone comparison rejects nonportable views before inspecting their fields', function()
    local base = envelope()

    local clone = {
        envelope = copy(base),
        lineage = {
            sourceId = base.id,
            sourceKind = 'builtin',
            sourceRevision = 1,
            baseline = copy(base),
            stepOrigins = {},
        },
    }

    local source = {
        envelope = setmetatable({}, {
            __index = function()
                error('view callback executed')
            end,
        }),
    }

    local result = data.CompareClone(clone, source)
    assert(not result.valid and result.diagnostics[1].code == 'data-metatable')
end)

test('clone source ownership and baseline identity must agree with lineage', function()
    local base = envelope()

    local clone = {
        envelope = copy(base),
        lineage = {
            sourceId = base.id,
            sourceKind = 'builtin',
            sourceRevision = 1,
            baseline = copy(base),
            stepOrigins = {},
        },
    }

    local source = { envelope = copy(base), reference = { kind = 'custom', id = base.id } }
    assert(not data.CompareClone(clone, source).valid)
    source.reference.kind = 'builtin'
    clone.lineage.baseline.id = 'different'
    assert(not data.CompareClone(clone, source).valid)
end)

test('literal dotted keys remain distinct from structural priority paths', function()
    local left, right = envelope(), envelope()
    left['body.rotation'] = { flag = false }
    right['body.rotation'] = { flag = true }
    left.extra = { ['a.b'] = 1, a = { b = 1 }, ['x[1]'] = false }
    right.extra = { ['a.b'] = 2, a = { b = 2 }, ['x[1]'] = true }
    local result = data.DiffRotations(left, right)
    assert(result.valid and result.complete and #result.changes == 4)
    assert(find(result, 'changed', '$["body.rotation"].flag'))
    assert(find(result, 'changed', '$.extra["a.b"]'))
    assert(find(result, 'changed', '$.extra.a.b'))
    assert(find(result, 'changed', '$.extra["x[1]"]'))
end)

test('ancestor replacements and removed numeric parents conflict with descendant edits', function()
    for _, mode in ipairs({ 'replace', 'remove' }) do
        local n = 0

        local store = assert(data.NewCatalog({
            state = {},
            validation = validation,
            newId = function()
                n = n + 1
                return 'clone-' .. n
            end,
        }))

        local original = envelope()
        original.body.rotation[1].type = 'item'
        original.body.rotation[1].action = { 123, 456 }
        assert(store:RegisterBuiltin(original))
        local id = assert(store:Clone(original.id))
        local edited = store:Get(id).envelope
        edited.body.rotation[1].action[1] = 789
        assert(store:Save(id, edited))
        local newer = copy(original)
        newer.revision = 2

        if mode == 'replace' then
            newer.body.rotation[1].action = 'healing-potions'
        else
            newer.body.rotation[1].action = nil
            newer.body.rotation[1].type = 'stop'
        end

        assert(store:RegisterBuiltin(newer))
        local result = data.CompareClone(store:Get(id), store:Get(original.id))
        assert(result.valid and result.complete and #result.conflicts == 1, mode .. ' missed conflict')
    end
end)

local function treeEnvelope()
    local v = envelope()

    v.body.rotation = {
        {
            id = 'branch',
            type = 'branch',
            mode = 'evaluate',
            conditions = {},
            onTrue = { { id = 'yes1', type = 'spell', action = 403 }, { id = 'yes2', type = 'spell', action = 324 } },
            onFalse = { { id = 'no', type = 'spell', action = 8042 } },
        },
    }

    return v
end

test('nested priority edits and moves use stable identities within each typed branch arm', function()
    local left = treeEnvelope()
    local right = copy(left)

    right.body.rotation[1].onTrue[1], right.body.rotation[1].onTrue[2] =
        right.body.rotation[1].onTrue[2], right.body.rotation[1].onTrue[1]

    right.body.rotation[1].onTrue[2].action = 529
    local diff = data.DiffRotations(left, right)
    assert(diff.valid and diff.complete and #diff.changes == 2)

    assert(
        find(diff, 'moved', '$.body.rotation[branch].onTrue[yes1]') or find(
            diff,
            'moved',
            '$.body.rotation[branch].onTrue[yes2]'
        )
    )

    assert(find(diff, 'changed', '$.body.rotation[branch].onTrue[yes1].action'))
end)

test('nested clone correspondence hides regenerated IDs and cross-arm transfer remains explicit', function()
    local left = treeEnvelope()
    local right = copy(left)
    local origins = {}

    for _, row in ipairs(assert(data.IndexRotationSteps(right.body)).rows) do
        origins['copy-' .. row.step.id] = row.step.id
        row.step.id = 'copy-' .. row.step.id
    end

    local diff = data.DiffRotations(left, right, { rightOrigins = origins })
    assert(diff.valid and #diff.changes == 0)
    local moved = table.remove(right.body.rotation[1].onTrue, 1)
    table.insert(right.body.rotation[1].onFalse, moved)
    diff = data.DiffRotations(left, right, { rightOrigins = origins })

    assert(
        diff.valid and #diff.changes == 2 and find(diff, 'removed', '$.body.rotation[branch].onTrue[yes1]') and find(
            diff,
            'added',
            '$.body.rotation[branch].onFalse[yes1]'
        )
    )
end)

test('custom payload arm-like keys remain ordinary fields and nested ambiguity refuses all changes', function()
    local left = treeEnvelope()
    local right = copy(left)
    left.body.rotation[1].conditions = { type = 'CUSTOM', onTrue = { { id = 'opaque', value = 1 } } }
    right.body.rotation[1].conditions = { type = 'CUSTOM', onTrue = { { id = 'opaque', value = 2 } } }
    local diff = data.DiffRotations(left, right)

    assert(
        diff.valid and #diff.changes == 1 and find(
            diff,
            'changed',
            '$.body.rotation[branch].conditions.onTrue[1].value'
        )
    )

    right.body.rotation[1].onFalse[1].id = 'yes1'
    diff = data.DiffRotations(left, right)
    assert(not diff.valid and #diff.changes == 0)
end)

finish()
