-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Pure trusted-receipt model only. No native collector/presentation proof.
local passed, failed = 0, 0

local function test(name, fn)
    local ok, why = pcall(fn)

    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(why))
    end
end

local function engine()
    local addon = {}
    local env = {}

    for _, key in ipairs({
        'type', 'pairs', 'ipairs', 'next', 'rawget', 'rawset', 'rawequal', 'getmetatable', 'setmetatable', 'assert',
        'error', 'pcall', 'select', 'unpack', 'tonumber', 'tostring'
    }) do
        env[key] = _G[key]
    end

    env.math = { huge = math.huge, min = math.min, max = math.max, floor = math.floor }
    env.string = { len = string.len }
    env.table = {}

    setmetatable(env, {
        __index = function(_, key)
            error('unexpected native/global access ' .. key)
        end,
    })

    for _, path in ipairs({ 'Analytics/replay.lua', 'Analytics/capture.lua' }) do
        local f = assert(loadfile(path), 'pure capture module missing')
        setfenv(f, env)
        f('rotationmaster', addon)
    end

    return assert(addon.Analytics.NewCapture, 'pure capture API missing'), addon
end

local trusted = {
    family = 'tbc',
    actor = 'player',
    ordinaryEvidence = 'trusted-receipt',
    presentationEvidence = 'trusted-receipt',
}

local function fresh(context, options)
    local factory = engine()
    local c = assert(factory(options))
    local lease = assert(c:Start(context or trusted))
    return c, lease
end

local function push(c, l, t, r)
    local seq, why = c:Push(l, t, r)
    assert(seq, why)
    return seq
end

local function advice(c, l, t, spell, epoch)
    return push(c, l, t, { type = 'advice', epoch = epoch or 1, action = 'spell', spell = spell or 10 })
end

local function ack(c, l, t, seq, state)
    return push(c, l, t, { type = 'presentation', adviceSeq = seq, state = state or 'visible' })
end

local function attempt(c, l, t, key, spell, kind, actor, epoch, phase)
    return push(c, l, t, {
        type = 'attempt',
        key = key,
        spell = spell or 10,
        castKind = kind,
        actor = actor or 'player',
        epoch = epoch or 1,
        phase = phase or 'sent',
    })
end

local function result(c, l, t, key, spell, kind, status, actor)
    return push(c, l, t, {
        type = 'result',
        key = key,
        spell = spell or 10,
        castKind = kind,
        actor = actor or 'player',
        status = status or 'success',
    })
end

local function stop(c, l, t)
    local v, why = c:Stop(l, t or 1)
    assert(v, why)
    return v
end

local function score(s, m, d, u)
    local a = s.report and s.report.agreement
    assert(s.status == 'complete' and a, 'not complete')
    assert(a.matched == m and a.different == d and a.unobservable == u, 'wrong scores')
    assert(a.scorable == m + d)

    if m + d > 0 then
        assert(a.percentage == 100 * m / (m + d))
    else
        assert(a.percentage == nil and a.status == 'unavailable')
    end

    assert(s.nativeCertified == false and s.evidence.collection == 'not-wired')
end

local function unavailable(c, why)
    local s = c:GetSnapshot()
    assert(s and s.status == 'unavailable' and s.reason == why, tostring(s and s.reason))
    assert(s.trace == nil and s.report == nil and s.percentage == nil)
    return s
end

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local x = {}

    for k, z in pairs(v) do
        x[k] = copy(z)
    end

    return x
end

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

test('factory is pure and idle; invalid options and contexts leave no session', function()
    local factory = engine()
    local c = assert(factory())
    local s, why = c:GetSnapshot()
    assert(s == nil and why == 'no-session')

    for _, age in ipairs({ 0, -1, 0 / 0, math.huge, 0.50001 }) do
        assert(factory({ adviceMaxAge = age }) == nil)
    end

    assert(
        factory({
            callback = function()
                error('executed')
            end,
        }) == nil
    )

    for _, ctx in ipairs({
        { family = 'unknown', actor = 'player' },
        { family = 'retail', actor = 'player' },
        { family = 'tbc', actor = 'pet' },
        { family = 'tbc', actor = 'player', ordinaryEvidence = 'assumed' },
    }) do
        assert(c:Start(ctx) == nil)
    end

    assert(c:GetSnapshot() == nil)
end)

test('false optional values are malformed rather than silently defaulted', function()
    local factory = engine()

    for _, value in ipairs({
        false,
        '0.5',
        {},
        function()
            error('executed')
        end,
    }) do
        assert(factory({ adviceMaxAge = value }) == nil)
    end

    local c = assert(factory())

    for _, key in ipairs({ 'ordinaryEvidence', 'presentationEvidence' }) do
        local ctx = { family = 'tbc', actor = 'player' }
        ctx[key] = false
        assert(c:Start(ctx) == nil)
    end
end)

test('default evidence never assumes ordinary kind or actual visibility', function()
    local c, l = fresh({ family = 'tbc', actor = 'player' })
    local n = advice(c, l, 0)
    ack(c, l, 0, n)
    attempt(c, l, 0.1, 'x', 10, 'ordinary')
    result(c, l, 0.2, 'x', 10, 'ordinary')
    local s = stop(c, l)
    score(s, 0, 0, 0)
    assert(s.evidence.ordinary == 'unavailable' and s.evidence.presentation == 'unavailable')
    assert(s.trace.records[2].state == 'unknown')
end)

test('explicit receipt evidence yields model score while outcome/native remain unavailable', function()
    local c, l = fresh()
    local n = advice(c, l, 0)
    ack(c, l, 0, n)
    attempt(c, l, 0.1, 'x', 10, 'ordinary')
    result(c, l, 0.2, 'x', 10, 'ordinary')
    local s = stop(c, l)
    score(s, 1, 0, 0)
    assert(s.kind == 'trusted-receipt-builder')
    assert(s.report.outcome.raw.status == 'unavailable' and s.report.outcome.rate.value == nil)
end)

test('active snapshots have no provisional score, including apparent success before late channel proof', function()
    local c, l = fresh()
    local n = advice(c, l, 0)
    ack(c, l, 0, n)
    attempt(c, l, 0.1, 'x', 10, 'ordinary')
    result(c, l, 0.2, 'x', 10, 'ordinary')
    local s, why = c:GetSnapshot()
    assert(s == nil and why == 'running')
    attempt(c, l, 0.3, 'x', 10, 'channel', nil, nil, 'start')
    score(stop(c, l), 0, 0, 0)
end)

test('late ordinary proof preserves earliest SENT time and original advice anchor', function()
    local c, l = fresh()
    local a = advice(c, l, 0, 10)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, 'x', 20)
    local b = advice(c, l, 0.2, 20)
    ack(c, l, 0.2, b)
    attempt(c, l, 0.25, 'x', 20, 'ordinary', nil, nil, 'start')
    result(c, l, 0.3, 'x', 20)
    local s = stop(c, l)
    score(s, 0, 1, 0)
    assert(s.trace.records[3].time == 0.1 and s.trace.records[3].seq == 3 and s.trace.records[3].castKind == 'ordinary')
end)

test('SENT plus success without positive ordinary proof stays unmodeled', function()
    local c, l = fresh()
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, 'x')
    result(c, l, 0.2, 'x')
    local s = stop(c, l)
    score(s, 0, 0, 0)
    assert(s.trace.records[3].castKind == 'unmodeled')
end)

test('late channel after success classifies the entire alias without moving records', function()
    local c, l = fresh()
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, 'x')
    result(c, l, 0.2, 'x')
    attempt(c, l, 0.3, 'x', 10, 'channel', nil, nil, 'start')
    local s = stop(c, l)
    score(s, 0, 0, 0)

    for i = 3, 5 do
        assert(s.trace.records[i].castKind == 'channel')
    end

    assert(s.trace.records[3].time == 0.1)
end)

test('autorepeat and conflicting excluded classifications never become ordinary opportunities', function()
    for _, both in ipairs({ false, true }) do
        local c, l = fresh()
        local a = advice(c, l, 0)
        ack(c, l, 0, a)
        attempt(c, l, 0.1, 'x', 10, 'ordinary')
        result(c, l, 0.2, 'x', 10, 'autorepeat')

        if both then
            attempt(c, l, 0.3, 'x', 10, 'channel', nil, nil, 'start')
        end

        local s = stop(c, l)
        score(s, 0, 0, 0)
        assert(s.trace.records[3].castKind == (both and 'unmodeled' or 'autorepeat'))
    end
end)

test('actor and spell conflicts remain per-row rather than overwritten by normalization', function()
    for _, change in ipairs({ 'actor', 'spell' }) do
        local c, l = fresh()
        local a = advice(c, l, 0)
        ack(c, l, 0, a)
        attempt(c, l, 0.1, 'x', 10, 'ordinary')
        result(c, l, 0.2, 'x', change == 'spell' and 20 or 10, 'ordinary', nil, change == 'actor' and 'pet' or 'player')
        local s = stop(c, l)
        score(s, 0, 0, 1)
        assert(s.trace.records[3].spell == 10 and s.trace.records[3].actor == 'player')
    end
end)

test('result-only success cannot be rescued by later advice and attempt', function()
    local c, l = fresh()
    result(c, l, 0.1, 'x', 10, 'ordinary')
    local a = advice(c, l, 0.2)
    ack(c, l, 0.2, a)
    attempt(c, l, 0.3, 'x', 10, 'ordinary')
    local s = stop(c, l)
    score(s, 0, 0, 1)
    assert(s.report.agreement.reasons['missing-attempt'] == 1)
end)

test('equal timestamps preserve receipt order and late acknowledgement cannot rescue', function()
    for _, before in ipairs({ true, false }) do
        local c, l = fresh()
        local a = advice(c, l, 0)

        if before then
            ack(c, l, 0, a)
        end

        attempt(c, l, 0, 'x', 10, 'ordinary')

        if not before then
            ack(c, l, 0, a)
        end

        result(c, l, 0, 'x', 10, 'ordinary')
        local s = stop(c, l)

        if before then
            score(s, 1, 0, 0)
        else
            score(s, 0, 0, 1)
        end

        for i, r in ipairs(s.trace.records) do
            assert(r.seq == i and r.time == 0)
        end
    end
end)

test('advice expiry is strict at analytical ceiling and configurable downward', function()
    for _, t in ipairs({ 0.249, 0.25 }) do
        local c, l = fresh(nil, { adviceMaxAge = 0.25 })
        local a = advice(c, l, 0)
        ack(c, l, 0, a)
        attempt(c, l, t, 'x', 10, 'ordinary')
        result(c, l, 0.3, 'x', 10, 'ordinary')
        local s = stop(c, l)

        if t < 0.25 then
            score(s, 1, 0, 0)
        else
            score(s, 0, 0, 1)
        end

        assert(s.trace.records[1].validUntil == 0.25)
    end
end)

test('final duration clamps only expiry downward and exact-stop attempt is conservatively stale', function()
    local c, l = fresh()
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.2, 'x', 10, 'ordinary')
    result(c, l, 0.2, 'x', 10, 'ordinary')
    local s = stop(c, l, 0.2)
    score(s, 0, 0, 1)
    assert(s.trace.duration == 0.2 and s.trace.records[1].validUntil == 0.2 and s.trace.records[3].time == 0.2)
end)

test('retirement and epoch changes never migrate pending old attempts', function()
    for _, retire in ipairs({ true, false }) do
        local c, l = fresh()
        local a = advice(c, l, 0)
        ack(c, l, 0, a)
        attempt(c, l, 0.1, 'x', 10, 'ordinary')

        if retire then
            push(c, l, 0.2, { type = 'retire', reason = 'context' })
        end

        local b = advice(c, l, 0.3, 10, 2)
        ack(c, l, 0.3, b)
        result(c, l, 0.4, 'x', 10, 'ordinary')
        score(stop(c, l), 0, 0, 1)
    end
end)

test('duplicate attempt/result aliases produce one opportunity and retain tombstones', function()
    local c, l = fresh()
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, 'x', 10, 'ordinary')
    attempt(c, l, 0.2, 'x', 10, 'ordinary', nil, nil, 'start')
    result(c, l, 0.3, 'x', 10, 'ordinary')
    result(c, l, 0.4, 'x', 10, 'ordinary')
    local s = stop(c, l)
    score(s, 1, 0, 0)

    assert(
        s.report.counts.duplicateAttempts == 1
            and s.report.counts.duplicateResults == 1
            and s.report.counts.distinctCasts == 1
    )
end)

test('missing cast key remains alias zero and never gains borrowed identity', function()
    local c, l = fresh()
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, nil, 10, 'ordinary')
    result(c, l, 0.2, nil, 10, 'ordinary')
    local s = stop(c, l)
    score(s, 0, 0, 1)
    assert(s.trace.records[3].cast == 0 and s.report.counts.distinctCasts == 0)
end)

test('retired leases cannot append, stop or corrupt newer capture even with malformed payload', function()
    local c, old = fresh()
    stop(c, old, 0)
    local l = assert(c:Start(trusted))
    assert(c:Push(old, 0 / 0, { type = 'damage' }) == nil)
    assert(c:Stop(old, 999) == nil)
    push(c, l, 0, { type = 'retire', reason = 'stop' })
    local s = stop(c, l)
    assert(#s.trace.records == 1)
end)

test('opaque lease identity ignores caller equality metamethods and foreign receiver', function()
    local c, l = fresh()
    local calls = 0

    setmetatable(l, {
        __eq = function()
            calls = calls + 1
            error('executed')
        end,
    })

    assert(c.Push({}, l, 0, { type = 'retire', reason = 'stop' }) == nil)
    assert(c:Push({}, 0, { type = 'retire', reason = 'stop' }) == nil)
    push(c, l, 0, { type = 'retire', reason = 'stop' })
    assert(stop(c, l).status == 'complete' and calls == 0)
end)

test('already-running and failed starts preserve current lease or previous completed snapshot', function()
    local c, l = fresh()
    assert(c:Start(trusted) == nil)
    local first = stop(c, l, 0)
    assert(c:Start({ family = 'retail', actor = 'player' }) == nil)
    assert(equal(c:GetSnapshot(), first))
    local freshLease = assert(c:Start(trusted))
    assert(c:GetSnapshot() == nil)
    stop(c, freshLease, 0)
end)

test('Clear releases only builder session and makes old receipts inert', function()
    local c, l = fresh()
    advice(c, l, 0)
    c:Clear()
    c:Clear()
    assert(c:GetSnapshot() == nil)
    assert(c:Push(l, 0, { type = 'retire', reason = 'stop' }) == nil)
    local n = assert(c:Start(trusted))
    assert(#stop(c, n, 0).trace.records == 0)
end)

test('unknown fields/metatables/executable values refuse without callbacks or error echo', function()
    for _, receipt in ipairs({
        { type = 'advice', epoch = 1, action = 'spell', spell = 10, source = 'PRIVATE' },
        {
            type = 'retire',
            reason = function()
                error('executed')
            end,
        },
        setmetatable({}, {
            __index = function()
                error('executed')
            end,
            __pairs = function()
                error('executed')
            end,
        }),
    }) do
        local c, l = fresh()
        assert(c:Push(l, 0, receipt) == nil)
        unavailable(c, 'invalid-receipt')
    end
end)

test('damage and damageCoverage cannot create outcome data', function()
    for _, kind in ipairs({ 'damage', 'damageCoverage' }) do
        local c, l = fresh()
        assert(c:Push(l, 0, { type = kind }) == nil)
        unavailable(c, 'invalid-receipt')
    end
end)

test('invalid and decreasing relative clocks terminate coverage without fabricated clamping', function()
    for _, t in ipairs({ 0 / 0, math.huge, -math.huge, -1, 601 }) do
        local c, l = fresh()
        assert(c:Push(l, t, { type = 'retire', reason = 'stop' }) == nil)
        unavailable(c, 'invalid-time')
    end

    local c, l = fresh()
    push(c, l, 1, { type = 'retire', reason = 'stop' })
    assert(c:Push(l, 0.9, { type = 'retire', reason = 'stop' }) == nil)
    unavailable(c, 'decreasing-time')
end)

test('duration six-hundred boundary works, invalid Stop cannot expose prefix percentage', function()
    local c, l = fresh()
    assert(stop(c, l, 600).trace.duration == 600)
    c, l = fresh()
    advice(c, l, 0)
    c:Stop(l, 601)
    unavailable(c, 'invalid-time')
end)

test('record limit is exact and never ring overwrites or exposes partial score', function()
    local c, l = fresh()

    for i = 1, 4096 do
        assert(push(c, l, 0, { type = 'retire', reason = 'stop' }) == i)
    end

    assert(#stop(c, l, 0).trace.records == 4096)
    c, l = fresh()

    for _ = 1, 4096 do
        push(c, l, 0, { type = 'retire', reason = 'stop' })
    end

    assert(c:Push(l, 0, { type = 'retire', reason = 'stop' }) == nil)
    unavailable(c, 'record-limit')
end)

test('all1024 completed/result-only alias tombstones count toward exact bound', function()
    local c, l = fresh()

    for i = 1, 1024 do
        result(c, l, 0, 'key-' .. i, 10, nil, 'failed')
    end

    assert(stop(c, l, 0).report.counts.distinctCasts == 1024)
    c, l = fresh()

    for i = 1, 1024 do
        result(c, l, 0, 'key-' .. i, 10, nil, 'failed')
    end

    assert(c:Push(l, 0, { type = 'result', key = 'new', actor = 'player', spell = 10, status = 'failed' }) == nil)
    unavailable(c, 'alias-limit')
end)

test('pending128 bound counts every kind and repeated alias does not add a slot', function()
    local c, l = fresh()

    for i = 1, 128 do
        attempt(c, l, 0, 'key-' .. i)
    end

    attempt(c, l, 0, 'key-1')
    result(c, l, 0, 'key-1', 10, nil, 'failed')
    attempt(c, l, 0, 'new')
    assert(stop(c, l, 0).report.counts.pending == 128)
    c, l = fresh()

    for i = 1, 128 do
        attempt(c, l, 0, 'key-' .. i)
    end

    assert(
        c:Push(l, 0, { type = 'attempt', key = 'overflow', actor = 'player', spell = 10, epoch = 1, phase = 'sent' })
            == nil
    )

    unavailable(c, 'pending-limit')
end)

test('pending expires strictly after30seconds and expired aliases are not recycled', function()
    local c, l = fresh()

    for i = 1, 128 do
        attempt(c, l, 0, 'key-' .. i)
    end

    attempt(c, l, 30.001, 'new')
    assert(stop(c, l, 31).report.counts.expired == 128)
    c, l = fresh()

    for i = 1, 128 do
        attempt(c, l, 0, 'key-' .. i)
    end

    assert(
        c:Push(l, 30, { type = 'attempt', key = 'overflow', actor = 'player', spell = 10, epoch = 1, phase = 'sent' })
            == nil
    )

    unavailable(c, 'pending-limit')
end)

test('private key bytes are charged, length capped and handcounted fixed receipt charge matches', function()
    local c, l = fresh()
    push(c, l, 0, { type = 'retire', reason = 'stop' })
    local s = stop(c, l, 0)
    assert(s.chargedBytes == 155 and s.report.bytes == 155)
    c, l = fresh()
    result(c, l, 0, 'k', 10, nil, 'failed')
    local a = stop(c, l, 0)
    assert(a.chargedBytes == 242)
    c, l = fresh()
    result(c, l, 0, string.rep('k', 128), 10, nil, 'failed')
    assert(stop(c, l, 0).chargedBytes - a.chargedBytes == 127)
    c, l = fresh()

    assert(
        c:Push(l, 0, { type = 'result', key = string.rep('x', 129), actor = 'player', spell = 10, status = 'failed' })
            == nil
    )

    unavailable(c, 'invalid-receipt')
end)

test('payload cap is independent of alias/record/pending caps', function()
    local c, l = fresh()
    local why

    for _ = 1, 4096 do
        local _, issue = c:Push(l, 0, {
            type = 'attempt',
            key = 'same',
            actor = 'player',
            spell = 10,
            epoch = 1,
            phase = 'sent',
        })

        if issue then
            why = issue
            break
        end
    end

    assert(why == 'payload-limit', tostring(why))
    unavailable(c, 'payload-limit')
end)

test('receipt input and detached snapshots cannot mutate builder state or another session', function()
    local c, l = fresh()
    local r = { type = 'advice', epoch = 1, action = 'spell', spell = 10 }
    local before = copy(r)
    push(c, l, 0, r)
    assert(equal(r, before))
    local s = stop(c, l, 0.1)
    local expected = copy(s)
    s.trace.records[1].spell = 999
    s.report.agreement.matched = 999
    s.evidence.ordinary = 'poison'
    assert(equal(c:GetSnapshot(), expected))
    local c2, l2 = fresh()
    assert(#stop(c2, l2, 0).trace.records == 0)
end)

test('private GUID/name-like key never appears in trace/report/wrapper and owned Replay is fixed', function()
    local factory, addon = engine()
    local c = assert(factory())
    local l = assert(c:Start(trusted))
    local called = 0

    addon.Analytics.Replay = function()
        called = called + 1
        error('replaced')
    end

    local secret = 'Player-PRIVATE-NAME-TARGET'
    local a = advice(c, l, 0)
    ack(c, l, 0, a)
    attempt(c, l, 0.1, secret, 10, 'ordinary')
    result(c, l, 0.2, secret, 10, 'ordinary')
    local s = stop(c, l)
    score(s, 1, 0, 0)
    assert(called == 0)

    local function scan(v)
        if type(v) == 'table' then
            for k, x in pairs(v) do
                assert(
                    k ~= 'key' and k ~= 'GUID' and k ~= 'name' and k ~= 'target' and k ~= 'source' and k ~= 'profile'
                )

                scan(x)
            end
        elseif type(v) == 'string' then
            assert(not v:find(secret, 1, true))
        end
    end

    scan(s)
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed > 0 and 1 or 0)
