local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local a = {}
assert(loadfile('Data/plain.lua'))('rotationmaster', a)
local file = io.open('Data/rotation_tree.lua', 'r')

if file then
    file:close()
    assert(loadfile('Data/rotation_tree.lua'))('rotationmaster', a)
end

local data = a.RotationData

local function leaf(id)
    return { id = id, type = 'spell', action = 403 }
end

local function branch(id, mode, yes, no)
    return { id = id, type = 'branch', mode = mode, onTrue = yes or {}, onFalse = no or {}, conditions = {} }
end

local function body(rotation, cooldowns)
    return { rotation = rotation or {}, cooldowns = cooldowns or {} }
end

local function rejected(value, code, options)
    local index, why = data.IndexRotationSteps(value, options)
    assert(not index and why.code == code, tostring(why and why.code))
end

test('nested preorder and typed owner paths retain every arm and optional identity', function()
    local v = body({
        branch('b', 'evaluate', { leaf('t'), branch('n', nil, { leaf('nt') }, { leaf('nf') }) }, { leaf('f') }),
        leaf('tail'),
    }, { leaf('upkeep') })

    local index = assert(data.IndexRotationSteps(v))
    local want = { 'b', 't', 'n', 'nt', 'nf', 'f', 'tail', 'upkeep' }
    assert(#index.rows == 8 and #index.lists == 6)

    for i, id in ipairs(want) do
        assert(index.rows[i].step.id == id and index.byId[id] == index.rows[i] and index.rows[i].ordinal == i)
    end

    local nested = index.byId.nf

    assert(
        nested.section == 'rotation'
            and nested.depth == 2
            and nested.parentId == 'n'
            and nested.arm == 'false'
            and nested.index == 1
    )

    assert(table.concat(nested.path, '/') == 'rotation/1/onTrue/2/onFalse/1')
    nested.path[1] = 'corrupted'
    assert(v.rotation[1].onTrue[2].onFalse[1].id == 'nf')
    assert(index.byId.upkeep.depth == 0 and index.byId.upkeep.arm == nil)
end)

test('duplicate identities across any arm and optional cards are refused atomically', function()
    rejected(body({ branch('b', nil, { leaf('same') }, { leaf('same') }) }), 'duplicate-step-id')
    rejected(body({ branch('b', nil, { leaf('same') }) }, { leaf('same') }), 'duplicate-step-id')
    rejected(body({ branch('same', nil, { leaf('same') }) }), 'duplicate-step-id')
end)

test('unreachable state propagates through forced branches without modifying saved flags', function()
    local v = body({
        branch('b', 'true', { leaf('yes') }, { branch('nested', 'false', { leaf('n1') }, { leaf('n2') }) }),
        branch('auto', nil, { leaf('a1') }, { leaf('a2') }),
    }, { leaf('optional') })

    local index = assert(data.IndexRotationSteps(v))

    assert(
        not index.byId.yes.unreachable
            and index.byId.nested.unreachable
            and index.byId.n1.unreachable
            and index.byId.n2.unreachable
    )

    assert(not index.byId.a1.unreachable and not index.byId.a2.unreachable and not index.byId.optional.unreachable)
    assert(v.rotation[1].onFalse[1].disabled == nil and v.rotation[1].onFalse[1].onFalse[1].disabled == nil)
    v.rotation[1].mode = 'false'
    index = assert(data.IndexRotationSteps(v))
    assert(index.byId.yes.unreachable and not index.byId.n2.unreachable and index.byId.n1.unreachable)
end)

test('only declared branch edges are traversed and condition payloads remain opaque', function()
    local v = body({ leaf('a') })
    v.rotation[1].conditions = { type = 'CUSTOM', onTrue = { leaf('a') }, evaluate = 'error("must not run")' }
    v.rotation[1].extra = { id = 'a', type = 'branch', onTrue = {}, onFalse = {} }
    local index = assert(data.IndexRotationSteps(v))
    assert(#index.rows == 1 and #index.lists == 2)
end)

test('malformed branches and sparse lists never produce a partial index', function()
    rejected(body({ branch('b', 'maybe') }), 'invalid-branch-mode')
    rejected(body({ branch('b', false) }), 'invalid-branch-mode')
    rejected({ rotation = false, cooldowns = {} }, 'invalid-priority-list')
    local b = branch('b')
    b.onTrue = nil
    rejected(body({ b }), 'missing-branch-arm')
    b = branch('b')
    b.onFalse = { [2] = leaf('x') }
    rejected(body({ b }), 'invalid-priority-list')

    for _, field in ipairs({ 'action', 'disabled', 'effect', 'suppress_attack', 'announce' }) do
        b = branch('b')
        b[field] = false
        rejected(body({ b }), 'unexpected-branch-field')
    end

    rejected(body({}, { branch('b') }), 'branch-in-optional-list')
    rejected(body({ [2] = leaf('x') }), 'invalid-priority-list')
    rejected(body({ 'bad' }), 'expected-step-object')
end)

test('legacy missing IDs are an explicit inspection mode and never relax bad IDs or duplicates', function()
    local v = body({ { type = 'spell', action = 403 } })
    rejected(v, 'invalid-step-id')
    local index = assert(data.IndexRotationSteps(v, { allowMissingIds = true }))
    assert(#index.rows == 1 and next(index.byId) == nil)
    v.rotation[1].id = 'bad/id'
    rejected(v, 'invalid-step-id', { allowMissingIds = true })
    assert(data.IndexRotationSteps({}, { allowMissingIds = true }))
end)

test('cycles and nonportable payloads are refused before traversal', function()
    local v = body({ leaf('x') })
    v.rotation[1].conditions = v
    rejected(v, 'data-cycle')
    v = body({ leaf('x') })

    v.rotation[1].conditions = {
        evaluate = function()
            error('ran')
        end,
    }

    rejected(v, 'non-portable-type')
end)

test('card and branch-depth bounds accept the edge and reject the next node', function()
    local steps = {}

    for i = 1, 2000 do
        steps[i] = { id = 's' .. i, type = 'stop' }
    end

    assert(#assert(data.IndexRotationSteps(body(steps))).rows == 2000)
    steps[2001] = { id = 'extra', type = 'stop' }
    rejected(body(steps), 'rotation-node-limit')
    local node = leaf('leaf')

    for i = 1, 16 do
        node = branch('b' .. i, 'evaluate', { node })
    end

    assert(data.IndexRotationSteps(body({ node })))
    node = branch('too-deep', nil, { node })
    rejected(body({ node }), 'rotation-depth-limit')
end)

finish()
