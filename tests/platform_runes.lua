-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project or 11, 2, 'DEATHKNIGHT')
    local s = { kind = 1, start = 98, duration = 5, ready = true, now = 100, calls = {} }

    local function call(name, ...)
        s.calls[#s.calls + 1] = { name, n = select('#', ...), ... }

        if s.throw == name then
            error('native rune failure')
        end
    end

    f.env.GetRuneType = function(...)
        assert(select('#', ...) == 1)
        call('type', ...)
        return s.kind, s.tail
    end

    f.env.GetRuneCooldown = function(...)
        assert(select('#', ...) == 1)
        call('cooldown', ...)
        return s.start, s.duration, s.ready, s.tail
    end

    f.env.GetTime = function(...)
        assert(select('#', ...) == 0)
        call('clock', ...)
        return s.now, s.tail
    end

    local file = io.open('Platform/runes.lua')

    if file then
        file:close()
        f.load('Platform/runes.lua')
    end

    return f, f.addon.Platform, s
end

local function observe(p, name, ...)
    assert(type(p[name]) == 'function', 'owned rune observer missing: ' .. name)
    return p[name](p, ...)
end

local function unknown(p, name, why, ...)
    local value, reason = observe(p, name, ...)
    assert(value == nil and reason == why, tostring(reason) .. ' expected ' .. why)
end

test('rune types use one ordered index and accept future positive integral identities without tails', function()
    local _, p, s = fixture()

    for i = 1, 6 do
        s.kind = i
        s.tail = {}
        assert(observe(p, 'GetRuneTypeObservation', i) == i)
        assert(s.calls[i][2] == i and s.calls[i].n == 1)
    end
end)

test('invalid indices cannot call any rune API', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, index in ipairs({ 0, 7, -1, .5, '1', false, {}, math.huge, 0 / 0, opaque }) do
        for _, name in ipairs({ 'GetRuneTypeObservation', 'GetRuneCooldownObservation' }) do
            unknown(p, name, rawequal(index, opaque) and 'restricted-value' or 'invalid-rune-index', index)
        end
    end

    unknown(p, 'GetRuneTypeObservation', 'invalid-rune-index', nil)
    assert(#s.calls == 0)
end)

test('required type facts reject missing nil malformed restricted and failures', function()
    local f, p, s = fixture()
    s.kind = nil
    unknown(p, 'GetRuneTypeObservation', 'rune-type-unavailable', 1)

    for _, bad in ipairs({ false, true, 0, -1, .5, '1', {}, math.huge, 0 / 0 }) do
        s.kind = bad
        unknown(p, 'GetRuneTypeObservation', 'invalid-api-result', 1)
    end

    local opaque = {}
    s.kind = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    unknown(p, 'GetRuneTypeObservation', 'restricted-value', 1)
    s.kind = 1
    s.throw = 'type'
    unknown(p, 'GetRuneTypeObservation', 'api-error', 1)
    s.throw = nil
    f.env.GetRuneType = nil
    unknown(p, 'GetRuneTypeObservation', 'missing-api', 1)
end)

test('one partial cooldown record keeps independent finite timing and strict ready availability', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.start = opaque
    s.duration = '5'
    s.ready = false
    local row = observe(p, 'GetRuneCooldownObservation', 2)

    assert(
        row.start == nil
            and row.startReason == 'restricted-value'
            and row.duration == nil
            and row.durationReason == 'invalid-api-result'
            and row.ready == false
            and row.readyReason == nil
    )

    s.start = -1.5
    s.duration = -.25
    s.ready = opaque
    row = observe(p, 'GetRuneCooldownObservation', 2)
    assert(row.start == -1.5 and row.duration == -.25 and row.ready == nil and row.readyReason == 'restricted-value')
    s.start = nil
    s.duration = nil
    s.ready = nil
    row = observe(p, 'GetRuneCooldownObservation', 2)

    assert(
        row.startReason == 'rune-start-unavailable'
            and row.durationReason == 'rune-duration-unavailable'
            and row.readyReason == 'rune-ready-unavailable'
    )

    for _, bad in ipairs({ 0, 'false', {}, math.huge }) do
        s.ready = bad
        assert(observe(p, 'GetRuneCooldownObservation', 2).readyReason == 'invalid-api-result')
    end

    s.start = math.huge
    s.duration = 0 / 0
    row = observe(p, 'GetRuneCooldownObservation', 2)
    assert(row.startReason == 'invalid-api-result' and row.durationReason == 'invalid-api-result')
end)

test('missing or failed cooldown never invents a partial successful observation', function()
    local f, p, s = fixture()
    s.throw = 'cooldown'
    unknown(p, 'GetRuneCooldownObservation', 'api-error', 1)
    s.throw = nil
    f.env.GetRuneCooldown = nil
    unknown(p, 'GetRuneCooldownObservation', 'missing-api', 1)
end)

test('clock is fresh protected zero-argument finite data without sign constraints', function()
    local f, p, s = fixture()

    for _, n in ipairs({ 0, -1, .5, 1e308 }) do
        s.now = n
        assert(observe(p, 'GetRuneEvaluationTime') == n)
    end

    s.now = nil
    unknown(p, 'GetRuneEvaluationTime', 'rune-time-unavailable')

    for _, bad in ipairs({ false, '100', {}, math.huge, 0 / 0 }) do
        s.now = bad
        unknown(p, 'GetRuneEvaluationTime', 'invalid-api-result')
    end

    local opaque = {}
    s.now = opaque
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    unknown(p, 'GetRuneEvaluationTime', 'restricted-value')
    s.now = 100
    s.throw = 'clock'
    unknown(p, 'GetRuneEvaluationTime', 'api-error')
    s.throw = nil
    f.env.GetTime = nil
    unknown(p, 'GetRuneEvaluationTime', 'missing-api')
end)

test('policy and live API replacement avoid load-time calls across every probe family', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local f, p, s = fixture(project)
        assert(#s.calls == 0)
        f.load('Platform/runes.lua')
        assert(#s.calls == 0)
        assert(observe(p, 'GetRuneTypeObservation', 1) == 1)

        f.env.GetRuneType = function(index)
            assert(index == 1)
            return 8
        end

        assert(observe(p, 'GetRuneTypeObservation', 1) == 8)
    end

    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        unknown(p, 'GetRuneTypeObservation', 'unsupported-policy', 1)
        unknown(p, 'GetRuneCooldownObservation', 'unsupported-policy', 1)
        unknown(p, 'GetRuneEvaluationTime', 'unsupported-policy')
        assert(#s.calls == 0)
    end
end)

finish()
