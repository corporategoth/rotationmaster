local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local a = {}

for _, file in ipairs({ 'Data/plain.lua', 'Data/condition_draft.lua', 'Core/condition_canvas.lua' }) do
    assert(loadfile(file))('rotationmaster', a)
end

local function scene(root, view)
    local draft = assert(a.RotationData.NewConditionDraft(root))
    return a:BuildConditionCanvas(draft:Snapshot(), draft:Rows(4096), view or {})
end

test('named groups contain their descendants while inline field heights drive later cards', function()
    local s = scene({
        type = 'AND',
        name = 'Opening',
        value = { { type = 'A' }, { type = 'OR', name = 'Either', value = { { type = 'B' } } } },
    }, {
        width = 900,
        expanded = { ['string:value/number:1'] = true },
        detailsHeights = { ['string:value/number:1'] = 140 },
    })

    assert(#s.cards == 4 and s.cards[1].name == 'Opening' and s.cards[3].name == 'Either')
    assert(s.cards[2].height >= s.cards[2].headerHeight + 140 and s.cards[3].y > s.cards[2].y + s.cards[2].height)
    assert(s.cards[1].height > s.cards[4].y - s.cards[1].y and #s.connectors >= 3)
    assert(s.height >= s.cards[1].y + s.cards[1].height)
end)

test('collapsed descendants do not consume the visible budget or hide following siblings', function()
    local many = { type = 'AND', value = {} }

    for i = 1, 250 do
        many.value[i] = { type = 'A' }
    end

    local s = scene({ type = 'AND', value = { many, { type = 'B' } } }, {
        collapsed = { ['string:value/number:1'] = true },
    })

    assert(s.complete and #s.cards == 3 and s.cards[3].type == 'B')
    s = scene(many)
    assert(s.complete and #s.cards == 251, 'valid condition scene was truncated')
end)

test('scene paths and drop destinations are detached and deep indentation preserves usable width', function()
    local root = { type = 'A' }

    for i = 1, 18 do
        root = { type = 'AND', value = { root } }
    end

    local draft = assert(a.RotationData.NewConditionDraft(root))
    local rows = draft:Rows(4096)
    local s = a:BuildConditionCanvas(draft:Snapshot(), rows, { width = 400 })
    assert(#s.cards == 19 and s.cards[19].width >= 300 and s.cards[19].depth == 18)
    s.cards[2].path[1] = 'bad'
    assert(rows[2].path[1] == 'value')
    local list = scene({ type = 'AND', value = { { type = 'A' }, { type = 'B' } } })
    local found = false

    for _, target in ipairs(list.dropTargets) do
        if target.kind == 'after' and target.destination.index == 3 then
            found = true
            assert(#target.destination.path == 0)
        end
    end

    assert(found)
end)

test('narrow canvases keep every card within the viewport and expose declared empty custom slots', function()
    local root = { type = 'A' }

    for i = 1, 18 do
        root = { type = 'AND', value = { root } }
    end

    local s = scene(root, { width = 760 })

    for _, card in ipairs(s.cards) do
        assert(card.x + card.width <= s.width and card.width >= 300)
    end

    local definitions = { CUSTOM = { fields = { checks = 'condition[]', gate = 'condition' } } }
    local aRoot = { type = 'CUSTOM', checks = { { type = 'A' } }, opaque = {} }
    local draft = assert(a.RotationData.NewConditionDraft(aRoot, definitions))
    s = a:BuildConditionCanvas(draft:Snapshot(), draft:Rows(4096), { definitions = definitions })
    local checks, gate = false, false

    for _, target in ipairs(s.dropTargets) do
        if #target.destination.path == 0 then
            checks = checks or target.destination.field == 'checks' and target.destination.index == 2
            gate = gate or target.kind == 'inside' and target.destination.field == 'gate'
            assert(target.destination.field ~= 'opaque')
        end
    end

    assert(checks and gate)
end)

test('declared custom child edges connect to their immediate custom parent', function()
    local definitions = { CUSTOM = { fields = { gate = 'condition' } } }
    local root = { type = 'AND', value = { { type = 'CUSTOM', gate = { type = 'A' }, opaque = { type = 'B' } } } }
    local draft = assert(a.RotationData.NewConditionDraft(root, definitions))
    local s = a:BuildConditionCanvas(draft:Snapshot(), draft:Rows(4096), { definitions = definitions })
    assert(#s.cards == 3 and #s.connectors == 4)
    assert(s.connectors[3].x == s.cards[2].x + 10 and s.connectors[3].y == s.cards[2].y + 66)
    assert(s.cards[2].height > s.cards[3].y - s.cards[2].y)
end)

test('compact nodes size to content rather than filling a wide viewport and groups bound their children', function()
    local s = scene({ type = 'AND', value = { { type = 'A' }, { type = 'OR', value = { { type = 'B' } } } } }, {
        width = 1400,
    })

    assert(s.cards[1].width < 700 and s.cards[2].width == 340)
    assert(s.cards[1].x + s.cards[1].width >= s.cards[4].x + s.cards[4].width)
    assert(s.cards[3].x + s.cards[3].width >= s.cards[4].x + s.cards[4].width)
    local before, after = false, false

    for _, target in ipairs(s.dropTargets) do
        before = before or (target.destination.relation == 'before' and #target.destination.path == 0)
        after = after or (target.destination.relation == 'after' and #target.destination.path == 0)
    end

    assert(before and after)
    local empty = scene({})
    local inside = false

    for _, target in ipairs(empty.dropTargets) do
        inside = inside or target.kind == 'inside'
    end

    assert(inside, 'empty condition has no palette insertion target')
end)

test('NOT is a red condition property with preserved semantic paths rather than a separate group', function()
    local s = scene({
        type = 'NOT',
        value = {
            type = 'AND',
            name = 'Combat',
            value = { { type = 'A' }, { type = 'NOT', value = { type = 'B', disabled = true } } },
        },
    })

    assert(
        #s.cards == 3
            and s.cards[1].type == 'AND'
            and s.cards[1].group
            and s.cards[1].negated
            and s.cards[1].name == 'Combat'
    )

    assert(#s.cards[1].path == 0 and #s.cards[1].fieldPath == 1 and s.cards[1].fieldPath[1] == 'value')
    assert(s.cards[2].type == 'A' and not s.cards[2].negated)
    assert(s.cards[3].type == 'B' and s.cards[3].negated and s.cards[3].disabled and not s.cards[3].group)
    local twice = scene({ type = 'NOT', value = { type = 'NOT', value = { type = 'A' } } })
    assert(#twice.cards == 1 and not twice.cards[1].negated and #twice.cards[1].fieldPath == 2)
end)

test('descendants of a disabled group are unreachable presentation without changing their saved flags', function()
    local root = {
        type = 'AND',
        disabled = true,
        value = { { type = 'A' }, { type = 'OR', value = { { type = 'B' } } } },
    }

    local s = scene(root)
    assert(s.cards[1].disabled and not s.cards[1].unreachable)
    assert(s.cards[2].unreachable and not s.cards[2].disabled and s.cards[4].unreachable)
    assert(root.value[1].disabled == nil and root.value[2].value[1].disabled == nil)
end)

test('sibling destinations have one marker centered in the gap and groups leave an external gap', function()
    local s = scene({
        type = 'AND',
        value = {
            { type = 'NUMBER', number = 1 },
            { type = 'AND', value = { { type = 'NUMBER', number = 2 } } },
            { type = 'NUMBER', number = 3 },
        },
    })

    local count, target = 0

    for _, drop in ipairs(s.dropTargets) do
        if #drop.destination.path == 0 and drop.destination.field == 'value' and drop.destination.index == 2 then
            count = count + 1
            target = drop
        end
    end

    assert(count == 1, 'one sibling destination has duplicate before/after markers')
    assert(target.y + target.height / 2 == (s.cards[2].y + s.cards[2].height + s.cards[3].y) / 2)
    assert(s.cards[5].y > s.cards[3].y + s.cards[3].height, 'group border touches following sibling without a drop gap')
end)

test('compact empty condition insertion targets remain inside its visible card', function()
    local s = scene({}, { cardStates = { [''] = 'compact' } })
    local card = s.cards[1]
    assert(card.compact and card.ownHeight == 28)

    for _, target in ipairs(s.dropTargets) do
        if target.kind == 'inside' then
            assert(target.y >= card.y and target.y + target.height <= card.y + card.height)
        end
    end
end)

test('every group connector reaches its horizontal child arm', function()
    local s = scene({ type = 'AND', value = { { type = 'A' }, { type = 'NOT', value = { type = 'B' } } } })

    for i = 1, #s.connectors, 2 do
        local stem, arm = s.connectors[i], s.connectors[i + 1]
        assert(stem.y + stem.height >= arm.y, 'disconnected group arm')
    end
end)

test(
    'complete condition geometry indexes every accepted node and final destination without changing model limits',
    function()
        local root = { type = 'AND', value = {} }

        for i = 1, 4095 do
            root.value[i] = { type = 'A' }
        end

        local s = scene(root)
        assert(s.complete and #s.cards == 4096, 'largest valid condition scene was truncated')
        local last = s.cards[4096]
        assert(last.path[2] == 4095 and s.cardsByKey[last.key] == last and last.parentKey == s.cards[1].key)
        local found = false

        for _, target in ipairs(s.dropTargets) do
            if target.destination.index == 4096 then
                found = true
                assert(target.y >= last.y)
            end
        end

        assert(found)
        local visible = assert(a:GetConditionCanvasViewport(s, 0, last.y, 800, last.y + 200))
        assert(#visible < 10 and visible[#visible] == last, 'viewport did not retain the final row and its ancestor')
        root.value[4096] = { type = 'A' }
        local draft, why = a.RotationData.NewConditionDraft(root)
        assert(not draft and why == 'condition-limit', 'model condition bound changed')
    end
)

test('incomplete draft rows fail explicitly rather than publishing a partial scene', function()
    local d = assert(a.RotationData.NewConditionDraft({ type = 'AND', value = { { type = 'A' }, { type = 'B' } } }))
    local rows, complete = d:Rows(2)
    local s, why = a:BuildConditionCanvas(d:Snapshot(), rows, {}, complete)
    assert(not s and why.code == 'condition-limit', 'partial rows published an editable scene')
end)

test('indexed scene geometry work grows linearly with flat node count', function()
    if jit then  -- Lua VM instruction counts are not a JIT benchmark.
        return
    end

    local function work(count)
        local root = { type = 'AND', value = {} }

        for i = 1, count do
            root.value[i] = { type = 'A' }
        end

        local d = assert(a.RotationData.NewConditionDraft(root))
        local snapshot, rows = d:Snapshot(), d:Rows(4096)
        local instructions = 0

        debug.sethook(function()
            instructions = instructions + 1000
        end, '', 1000)

        local ok, result = pcall(a.BuildConditionCanvas, a, snapshot, rows, {})
        debug.sethook()
        assert(ok, result)
        return instructions
    end

    local small, large = work(250), work(1000)
    assert(large < small * 6, 'scene still has quadratic per-target card scans: ' .. small .. ' -> ' .. large)
end)

finish()
