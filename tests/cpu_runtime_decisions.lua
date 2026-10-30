-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Native capture ownership plus the exact Main action-decision helper.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(p)
    local h = assert(io.open(p))
    local s = h:read('*a')
    h:close()
    return s
end

local setup = assert(loadstring(
    assert(read('tests/cpu_runtime.lua'):match('^(.-)\ntest%(')) .. '\nreturn setup',
    '@decision-capture-fixture'
))()

local function tuple(...)
    return { n = select('#', ...), ... }
end

local function has(s, v)
    assert(s:find(v, 1, true), v .. ' missing: ' .. s)
end

local function bind(a)
    local sink
    assert(type(a.BindCPURuntimeDecisionCounts) == 'function', 'private decision sink binder missing')

    a:BindCPURuntimeDecisionCounts(function(value)
        sink = value
    end)

    return function(...)
        if sink then
            sink(...)
        end
    end,
        function() return sink end
end

local function done(a, s)
    s.now = 110
    s.timers[1].fn()
    return a:GetCPURuntimeCaptureReport()
end

test('valid native samples count rotation and cooldown decisions separately and preserve return holes', function()
    local _, a, s = setup()
    local emit = bind(a)

    a.EvaluateNextAction = function(self, ...)
        assert(self == a and select('#', ...) == 3)
        emit('rotation', 'attempt')
        emit('rotation', 'matched')
        emit('rotation', 'mapped')
        emit('rotation', 'ready')

        for _, event in ipairs({
            'attempt', 'noaction', 'attempt', 'disabled', 'attempt', 'notmatched', 'attempt', 'matched', 'unmapped',
            'mapped', 'notready'
        }) do
            emit('cooldowns', event)
        end

        return 'DECISION', nil, false, nil
    end

    assert(a:StartCPURuntimeCapture())
    local r = tuple(a:EvaluateNextAction(nil, 7, nil))
    a:EvaluateNextAction(nil, 7, nil)  -- two actual dispatches
    assert(r.n == 4 and r[1] == 'DECISION' and r[3] == false)
    local text = done(a, s)
    has(text, 'Decisions: complete=2; unavailable=0')

    has(
        text,
        'rotation decisions | attempted=2; matched=2; notMatchedOrUnavailable=0; skippedDisabled=0; skippedNoAction=0; mapped=2; unmapped=0; ready=2; notReady=0'
    )

    has(
        text,
        'cooldowns decisions | attempted=8; matched=2; notMatchedOrUnavailable=2; skippedDisabled=2; skippedNoAction=2; mapped=2; unmapped=2; ready=0; notReady=2'
    )

    has(text, 'cached button index')
    has(text, 'not visibility')
    has(text, 'reached action decisions')
end)

test('invalid native result discards only its scratch and retains earlier accepted counts', function()
    local _, a, s = setup()
    local emit = bind(a)
    local calls = 0
    local invalid = false

    a.EvaluateNextAction = function()
        calls = calls + 1
        emit('cooldowns', 'attempt')
        return true
    end

    s.provider.MeasureCall = function(fn, ...)
        s.measures = s.measures + 1
        local r = tuple(fn(...))

        return invalid and {} or { elapsedMilliseconds = .25, allocatedBytes = 12, deallocatedBytes = 4 }, unpack(
            r,
            1,
            r.n
        )
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    invalid = true
    a:EvaluateNextAction()
    assert(calls == 2 and s.measures == 2)
    local text = a:GetCPURuntimeCaptureReport()
    has(text, 'invalid')
    has(text, 'Decisions: complete=1; unavailable=0')
    has(text, 'cooldowns decisions | attempted=1;')
end)

test('nested dispatch withholds that decisions sample without changing native or original dispatch', function()
    local _, a, s = setup()
    local emit = bind(a)
    local inside = false
    local calls = 0

    a.EvaluateNextAction = function()
        calls = calls + 1
        emit('rotation', 'attempt')

        if not inside then
            inside = true
            a:EvaluateNextAction()
            inside = false
        end

        return true
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    local text = done(a, s)
    assert(calls == 2 and s.measures == 1)
    has(text, 'unmeasured nested=1')
    has(text, 'measured=1')
    has(text, 'Decisions: complete=0; unavailable=1')
end)

test('cancelled dispatch never aggregates partial decisions and clears only its sink', function()
    local _, a, s = setup()
    local emit, currentSink = bind(a)

    a.EvaluateNextAction = function()
        emit('rotation', 'attempt')
        assert(a:CancelCPURuntimeCapture())
        emit('rotation', 'matched')
        return 'ok'
    end

    assert(a:StartCPURuntimeCapture())
    assert(a:EvaluateNextAction() == 'ok' and currentSink() == nil)
    local text = a:GetCPURuntimeCaptureReport()
    has(text, 'Decisions: complete=0; unavailable=0')
end)

test('retired sink cannot contaminate a replacement capture', function()
    local _, a, s = setup()
    local emit, getSink = bind(a)
    local old
    local replaced = false

    a.EvaluateNextAction = function()
        if not replaced then
            replaced = true
            old = getSink()
            emit('rotation', 'attempt')
            assert(a:CancelCPURuntimeCapture())
            assert(a:StartCPURuntimeCapture())
            old('cooldowns', 'attempt')
        else
            emit('cooldowns', 'attempt')
        end

        return true
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    a:EvaluateNextAction()
    s.now = 110
    s.timers[2].fn()
    local text = a:GetCPURuntimeCaptureReport()
    has(text, 'Decisions: complete=1; unavailable=0')
    has(text, 'rotation decisions | attempted=0;')
    has(text, 'cooldowns decisions | attempted=1;')
end)

test('events outside measured callback and unknown payloads are ignored without disclosure', function()
    local _, a, s = setup()
    local emit, getSink = bind(a)
    local payload = { private = 'PRIVATE_BODY' }

    a.EvaluateNextAction = function()
        emit('rotation', 'attempt')
        emit('PRIVATE_BODY', 'matched')
        emit('cooldowns', payload)
        return true
    end

    assert(getSink() == nil)
    emit('rotation', 'attempt')
    assert(a:StartCPURuntimeCapture())
    emit('rotation', 'attempt')
    a:EvaluateNextAction()
    emit('cooldowns', 'attempt')
    local text = done(a, s)
    has(text, 'rotation decisions | attempted=1;')
    has(text, 'cooldowns decisions | attempted=0;')
    assert(not text:find('PRIVATE_BODY', 1, true))
end)

test('no Main consumer leaves decisions unavailable while native totals remain valid', function()
    local _, a, s = setup()
    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    local text = done(a, s)
    has(text, 'measured=1')
    has(text, 'Decisions: complete=0; unavailable=1')
end)

-- Extract executable source instead of duplicating Main's implementation.
local mainSource = read('main.lua')

local helper = assert(mainSource:match(
    '(local function eval%(cond.-)\n        self%.evaluationProfile:child%("rotation"%)'
))

local makeEval = assert(loadstring(
    'return function(addon,conditionSession,actionReady,dispatchCurrent,decisionSink) ' .. helper .. ' return eval end',
    '@actual-main-decision-helper'
))()

test(
    'actual Main helper keeps ordinary and compiled condition dispatch, mapping, readiness and return tuples',
    function()
        for _, compiled in ipairs({ false, true }) do
            local _, a, s = setup()
            local emit = bind(a)
            local trace = {}
            local session = {}

            local function condition(self, tree, context)
                assert(self == (compiled and session or a))
                trace[#trace + 1] = 'condition:' .. context.stepId
                return tree.result
            end

            a.evaluateCondition = condition
            session.EvaluateBool = condition

            a.GetSpellIds = function(self, c)
                assert(self == a)
                trace[#trace + 1] = 'ids:' .. c.id
                return c.ids, c.items
            end

            a.FindSpell = function(self, ids, items)
                assert(self == a)
                trace[#trace + 1] = 'map:' .. ids[1]

                if ids[1] ~= 1 then
                    return 'button' .. ids[1]
                end
            end

            local function ready(kind, id, item)
                trace[#trace + 1] = 'ready:' .. id
                return id == 3
            end

            local function guard(kind)
                assert(kind == 'step')
                trace[#trace + 1] = 'guard'
                return true
            end

            local rows = {
                { id = 'unmapped', action = 'x', conditions = { result = 'truthy' }, ids = { 1 }, type = 'spell' },
                { id = 'false', action = 'x', conditions = { result = false }, type = 'spell' },
                { id = 'disabled', action = 'x', disabled = true, type = 'spell' },
                setmetatable({ id = 'noaction' }, {
                    __index = function(_, k)
                        if k == 'disabled' then
                            error('extra disabled read')
                        end
                    end,
                }),
                {
                    id = 'ready',
                    action = 'x',
                    conditions = { result = true },
                    ids = { 1, 2, 3 },
                    items = { 11, 12, 13 },
                    type = 'item',
                },
            }

            local ordinary = makeEval(a, compiled and session or nil, ready, guard, nil)
            local expected = {}

            for i, c in ipairs(rows) do
                expected[i] = tuple(ordinary(c, 'cooldowns'))
            end

            local want = table.concat(trace, '|')
            trace = {}
            local actual = makeEval(a, compiled and session or nil, ready, guard, emit)

            a.EvaluateNextAction = function()
                for i, c in ipairs(rows) do
                    local got = tuple(actual(c, i == 5 and 'rotation' or 'cooldowns'))
                    assert(got.n == expected[i].n)

                    for j = 1, got.n do
                        assert(got[j] == expected[i][j])
                    end
                end

                return 'UNCHANGED', nil, false, nil
            end

            assert(a:StartCPURuntimeCapture())
            local result = tuple(a:EvaluateNextAction())
            assert(result.n == 4 and result[1] == 'UNCHANGED' and result[3] == false)
            assert(table.concat(trace, '|') == want, 'capture changed actual Main call order')
            local text = done(a, s)

            has(
                text,
                'rotation decisions | attempted=1; matched=1; notMatchedOrUnavailable=0; skippedDisabled=0; skippedNoAction=0; mapped=2; unmapped=1; ready=1; notReady=1'
            )

            has(
                text,
                'cooldowns decisions | attempted=4; matched=1; notMatchedOrUnavailable=1; skippedDisabled=1; skippedNoAction=1; mapped=0; unmapped=1; ready=0; notReady=0'
            )
        end
    end
)

finish()
