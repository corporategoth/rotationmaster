local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.addon.RotationData = make()
    f.load('Data/diff.lua')
    f.load('Data/visual_comparison.lua')
    return f.addon.RotationData
end

test('graph rows pair cloned identities and show additions removals moves and field changes', function()
    local d = fixture()

    local left = {
        body = {
            rotation = {
                { id = 'a', type = 'spell', action = 403 },
                { id = 'b', type = 'spell', action = 8042 },
                { id = 'c', type = 'spell', action = 324 },
            },
            cooldowns = { { id = 'optional', type = 'spell', action = 8017 } },
        },
    }

    local right = {
        body = {
            rotation = {
                { id = 'copy-b', type = 'spell', action = 8044 },
                { id = 'copy-a', type = 'spell', action = 403 },
                { id = 'new', type = 'spell', action = 974 },
            },
            cooldowns = { { id = 'copy-optional', type = 'spell', action = 8017 } },
        },
    }

    local origins = { ['copy-b'] = 'b', ['copy-a'] = 'a', ['copy-optional'] = 'optional' }
    local diff = d.DiffRotations(left, right, { rightOrigins = origins })
    local model = assert(d.BuildVisualComparison({ left = left, right = right, rightOrigins = origins, diff = diff }))
    assert(model.complete and #model.groups.rotation == 4 and #model.groups.cooldowns == 1)
    local rows = {}

    for _, row in ipairs(model.groups.rotation) do
        rows[row.id] = row
    end

    assert(rows.b.changed and rows.b.left.index == 2 and rows.b.right.index == 1)
    assert(rows.b.left.step.action == 8042 and rows.b.right.step.action == 8044)
    assert(rows.a.moved or rows.b.moved, 'priority move absent')
    assert(rows.c.removed and not rows.c.right and rows.new.added and not rows.new.left)
    assert(not model.groups.cooldowns[1].changed, 'optional unchanged step was marked changed')
    rows.b.right.step.action = 999
    assert(right.body.rotation[1].action == 8044, 'model leaked source references')
end)

test('settings changes and truncated diffs stay visible without claiming a complete picture', function()
    local d = fixture()
    local left = { body = { rotation = {}, switch = { type = 'COMBAT' }, future = { a = 1 } } }
    local right = { body = { rotation = {}, switch = { type = 'LEVEL' }, future = { a = 2 } } }
    local diff = d.DiffRotations(left, right)
    diff.complete = false
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = diff }))
    assert(not model.complete and model.settingsChanged and model.additionalChanges > 0)
    assert(model.leftSwitch.type == 'COMBAT' and model.rightSwitch.type == 'LEVEL')
    diff.valid = false
    local value, why = d.BuildVisualComparison({ left = left, right = right, diff = diff })
    assert(not value and why == 'invalid-comparison')
end)

test('display limits do not mark matched steps removed when additions precede them', function()
    local d = fixture()
    local left = { body = { rotation = { { id = 'last', action = 403, type = 'spell' } } } }
    local right = { body = { rotation = {} } }

    for i = 1, 205 do
        right.body.rotation[i] = { id = 'new-' .. i, action = 403, type = 'spell' }
    end

    right.body.rotation[206] = { id = 'last', action = 403, type = 'spell' }
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(not model.complete and #model.groups.rotation <= 200)
    assert(model.groups.rotation[1].right and not model.groups.rotation[1].removed, 'display cap invented a removal')
end)

test('valid large snapshots are not rejected by counting duplicated diff data again', function()
    local d = fixture()
    local left = { body = { rotation = {} } }
    local right = { body = { rotation = {} } }

    for i = 1, 200 do
        left.body.rotation[i] = {
            id = 'step-' .. i,
            type = 'spell',
            action = 403,
            conditions = { type = 'SPELL_KNOWN', spell = 403 },
        }

        right.body.rotation[i] = {
            id = 'step-' .. i,
            type = 'spell',
            action = 8042,
            conditions = { type = 'SPELL_KNOWN', spell = 8042 },
        }
    end

    local diff = d.DiffRotations(left, right)
    assert(diff.valid and diff.complete and #diff.changes == 400)
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = diff }))
    assert(model.complete and #model.groups.rotation == 200)
end)

test('whole added steps warn about fields that cards do not render', function()
    local d = fixture()
    local left = { body = { rotation = {} } }

    local right = {
        body = {
            rotation = {
                { id = 'new', type = 'spell', action = 403, effect = 'Button Glow', unknownSetting = { foo = 42 } },
            },
        },
    }

    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(model.complete and model.additionalChanges > 0, 'hidden fields were presented as fully visualized')
end)

test('editor-added false defaults do not mark every cloned step changed but raw diff remains exact', function()
    local d = fixture()

    local left = {
        nameKey = 'Default.Name',
        body = {
            rotation = {
                { id = 'a', type = 'spell', action = 403 },
                { id = 'b', type = 'spell', action = 8042 },
            },
            cooldowns = { { id = 'buff', type = 'spell', action = 324 } },
        },
    }

    local right = assert(d.CopyData(left))
    right.nameKey = 'My clone'
    right.body.name = 'My clone'

    for _, kind in ipairs({ 'rotation', 'cooldowns' }) do
        for _, step in ipairs(right.body[kind]) do
            step.use_name = false
            step.disabled = false
            step.ranked = false
        end
    end

    local diff = d.DiffRotations(left, right)
    assert(#diff.changes == 11, 'raw structural details were discarded')
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = diff }))

    for _, rows in pairs(model.groups) do
        for _, row in ipairs(rows) do
            assert(not row.changed, 'default false became a graphical step edit')
        end
    end

    assert(model.namesChanged and not model.switchChanged and model.additionalChanges == 0)
    assert(right.body.rotation[1].use_name == false and left.body.rotation[1].use_name == nil)
    right.body.rotation[1].ranked = true
    right.body.cooldowns[1].conditions = { type = 'CUSTOM', falseFlag = false }
    model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))

    assert(
        model.groups.rotation[1].changed and model.groups.cooldowns[1].changed,
        'real/custom condition edits were hidden'
    )
end)

test('omitted use_name with a custom label means true and differs from explicit false', function()
    local d = fixture()
    local left = { body = { rotation = { { id = 'a', type = 'spell', action = 403, name = 'Pull' } } } }
    local right = assert(d.CopyData(left))
    right.body.rotation[1].use_name = false
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(model.groups.rotation[1].changed, 'disabled custom step name was hidden')
    right.body.rotation[1].use_name = true
    model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(not model.groups.rotation[1].changed, 'equivalent inferred custom name became an edit')
end)

test('a nested field change marks its own card and preserves arm ancestry without marking the branch edited', function()
    local d = fixture()

    local left = {
        body = {
            rotation = {
                {
                    id = 'b',
                    type = 'branch',
                    name = 'Combat',
                    conditions = {},
                    onTrue = { { id = 'yes', type = 'spell', action = 403 } },
                    onFalse = { { id = 'no', type = 'spell', action = 324 } },
                },
            },
        },
    }

    local right = d.CopyData(left)
    right.body.rotation[1].onTrue[1].action = 8042
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    local rows = {}

    for _, row in ipairs(model.groups.rotation) do
        rows[row.id] = row
    end

    assert(#model.groups.rotation == 3 and rows.yes.changed and not rows.b.changed and not rows.no.changed)
    assert(rows.yes.left.depth == 1 and rows.yes.left.arm == 'true' and rows.yes.left.branchPath[1].name == 'Combat')
    assert(rows.yes.left.step.action == 403 and rows.yes.right.step.action == 8042 and model.additionalChanges == 0)
    right.body.rotation[1].onTrue[1].disabled = false
    right.body.rotation[1].onTrue[1].action = 403
    model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(model.displayChangeCount == 0, 'nested inferred false default became a user edit')
end)

test('cross-arm transfers remain separate removed and added cards with their original arm labels', function()
    local d = fixture()

    local left = {
        body = {
            rotation = {
                {
                    id = 'b',
                    type = 'branch',
                    conditions = {},
                    onTrue = { { id = 'leaf', type = 'spell', action = 403 } },
                    onFalse = {},
                },
            },
        },
    }

    local right = d.CopyData(left)
    right.body.rotation[1].onFalse = { table.remove(right.body.rotation[1].onTrue, 1) }
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    local added, removed = 0, 0

    for _, row in ipairs(model.groups.rotation) do
        if row.id == 'leaf' then
            assert(not row.changed, 'cross-arm transfer was collapsed into a paired field edit')

            if row.added then
                added = added + 1
                assert(row.right.arm == 'false' and not row.left)
            end

            if row.removed then
                removed = removed + 1
                assert(row.left.arm == 'true' and not row.right)
            end
        end
    end

    assert(added == 1 and removed == 1 and model.displayChangeCount == 2)
end)

test('tags have a graphical comparison row instead of only a raw-field warning', function()
    local d = fixture()
    local left = { tags = { 'leveling' }, body = { rotation = {}, cooldowns = {} } }
    local right = d.CopyData(left)
    right.body.tags = { 'PVP', 'MyLittlePony' }
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))

    assert(
        model.tagsChanged
            and model.leftTags[1] == 'leveling'
            and model.rightTags[2] == 'MyLittlePony'
            and model.additionalChanges == 0
    )
end)

test('switch priority has a human graphical comparison field', function()
    local d = fixture()
    local left = { body = { rotation = {} } }
    local right = { body = { rotation = {}, priority = 50 } }
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = d.DiffRotations(left, right) }))
    assert(model.priorityChanged and model.leftPriority == 0 and model.rightPriority == 50)
end)

test('an explicit zero priority keeps the exact raw diff but has no graphical difference', function()
    local d = fixture()
    local left = { body = { rotation = {} } }
    local right = { body = { rotation = {}, priority = 0 } }
    local diff = d.DiffRotations(left, right)
    assert(#diff.changes == 1)
    local model = assert(d.BuildVisualComparison({ left = left, right = right, diff = diff }))
    assert(not model.priorityChanged and model.displayChangeCount == 0 and #diff.changes == 1)
end)

finish()
