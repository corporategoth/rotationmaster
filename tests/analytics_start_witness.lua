-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Real adapter, builder, reducer and copy-report; only native boundaries doubled.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(p)
    local h = assert(io.open(p))
    local v = h:read('*a')
    h:close()
    return v
end

local native = assert(loadstring(
    assert(read('tests/platform_analytics_casts.lua'):match('^(.-)\ntest%(')) .. '\nreturn fixture'
))()

local function fixture()
    local f = native()
    local env = getfenv(f.service.Start)
    f.env = env
    f.queries = {}
    f.cast = { name = 'PRIVATE_NAME', trade = false, key = 'PRIVATE_GUID', spell = 547 }

    env.UnitCastingInfo = function(unit)
        assert(unit == 'player')
        f.queries[#f.queries + 1] = 'cast'

        if f.onCast then
            f.onCast()
        end

        local c = f.cast

        if not c then
            return
        end

        return c.name, f.secret, f.secret, f.secret, f.secret, c.trade, c.key, f.secret, c.spell
    end

    env.C_Spell = {
        IsAutoRepeatSpell = function(spell)
            assert(spell == 547)
            f.queries[#f.queries + 1] = 'repeat'

            if f.onRepeat then
                f.onRepeat()
            end

            if f.repeatValue == nil then
                return false
            end

            return f.repeatValue
        end,
    }

    return f
end

local function start(f)
    return f:start()
end

local function emit(f, key, spell)
    f:emit('UNIT_SPELLCAST_START', 'player', key or 'PRIVATE_GUID', spell or 547)
end

local function witness(s, a, b, c, d)
    local w = assert(s.startWitness, 'missing START witness diagnostics')

    assert(
        w.observed == a + b + c + d and w.matched == a and w.mismatch == b and w.excluded == c and w.unknown == d,
        'wrong START witness counts'
    )

    assert(
        s.ordinary == 'unavailable'
            and s.capture.evidence.ordinary == 'unavailable'
            and s.capture.report.agreement.scorable == 0
            and s.capture.report.agreement.percentage == nil
    )

    for _, r in ipairs(s.capture.trace.records) do
        assert(r.castKind ~= 'ordinary')
    end

    return w
end

test('matching current cast and nonrepeat proof produce diagnostic only with original SENT association', function()
    local f = fixture()
    local l = start(f)
    f:emit('UNIT_SPELLCAST_SENT', 'player', 'PRIVATE_TARGET', 'PRIVATE_GUID', 547)
    emit(f)
    f.now = 102
    f:emit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'PRIVATE_GUID', 547)
    local s = f:stop(l)
    witness(s, 1, 0, 0, 0)

    assert(
        #s.capture.trace.records == 3
            and s.capture.trace.records[1].phase == 'sent'
            and s.capture.trace.records[1].time == 0
    )

    local w = s.startWitness
    w.matched = 999
    assert(f.service:GetSnapshot().startWitness.matched == 1)
    assert(f.created == 1 and #f.timers == 1)
end)

test('off capture status and nonSTART or nonplayer receipts never query witness APIs', function()
    local f = fixture()
    assert(#f.queries == 0)
    f.service:GetStatus()
    f.service:GetSnapshot()
    assert(#f.queries == 0)
    local l = start(f)
    assert(#f.queries == 0)

    for _, e in ipairs({
        'UNIT_SPELLCAST_SUCCEEDED',
        'UNIT_SPELLCAST_STOP',
        'UNIT_SPELLCAST_CHANNEL_START',
        'UNIT_SPELLCAST_CHANNEL_STOP',
    }) do
        f:emit(e, 'player', 'PRIVATE_GUID', 547)
    end

    f:emit('UNIT_SPELLCAST_SENT', 'player', 'PRIVATE_TARGET', 'PRIVATE_GUID', 547)
    f:emit('UNIT_SPELLCAST_START', 'pet', f.secret, f.secret)
    witness(f:stop(l), 0, 0, 0, 0)
    assert(#f.queries == 0)
end)

test('wrong cast or spell identity is mismatch not positive evidence', function()
    for _, key in ipairs({ 'key', 'spell' }) do
        local f = fixture()
        f.cast[key] = key == 'key' and 'PRIVATE_OTHER' or 324
        local l = start(f)
        emit(f)
        witness(f:stop(l), 0, 1, 0, 0)
    end
end)

test('missing or partial APIs and nil current cast leave accepted receipts unknown', function()
    for _, kind in ipairs({ 'cast-api', 'namespace', 'repeat-api', 'nilcast' }) do
        local f = fixture()

        if kind == 'cast-api' then
            f.env.UnitCastingInfo = false
        elseif kind == 'namespace' then
            f.env.C_Spell = false
        elseif kind == 'repeat-api' then
            f.env.C_Spell = {}
        else
            f.cast = nil
        end

        local l = start(f)
        emit(f)
        local s = f:stop(l)
        witness(s, 0, 0, 0, 1)
        assert(#s.capture.trace.records == 1)
    end
end)

test('restricted or malformed current cast fields are never compared or promoted', function()
    for _, key in ipairs({ 'name', 'trade', 'key', 'spell' }) do
        for _, bad in ipairs({ 'secret', 'wrong' }) do
            local f = fixture()
            f.cast[key] = bad == 'secret' and f.secret or {}
            local l = start(f)
            emit(f)
            witness(f:stop(l), 0, 0, 0, 1)
        end
    end
end)

test('tradeskill and positive autorepeat are excluded while unknown repeat remains unknown', function()
    local f = fixture()
    f.cast.trade = true
    local l = start(f)
    emit(f)
    witness(f:stop(l), 0, 0, 1, 0)

    for _, v in ipairs({ true, 'wrong', {}, 'secret' }) do
        f = fixture()
        f.repeatValue = v == 'secret' and f.secret or v
        l = start(f)
        emit(f)
        witness(f:stop(l), 0, 0, v == true and 1 or 0, v == true and 0 or 1)
    end

    f = fixture()
    f.env.C_Spell.IsAutoRepeatSpell = function() return nil end
    l = start(f)
    emit(f)
    witness(f:stop(l), 0, 0, 0, 1)
end)

test('throwing optional query or readable-value callback keeps receipt unknown without raw errors', function()
    for _, where in ipairs({ 'cast', 'repeat', 'read' }) do
        local f = fixture()

        if where == 'cast' then
            f.onCast = function()
                error('PRIVATE_ERROR')
            end
        elseif where == 'repeat' then
            f.onRepeat = function()
                error('PRIVATE_ERROR')
            end
        else
            f.hooks.read = function(v)
                if v == f.cast.name then
                    error('PRIVATE_ERROR')
                end
            end
        end

        local l = start(f)
        emit(f)
        witness(f:stop(l), 0, 0, 0, 1)
    end
end)

test('changed tuple or replaced query during nonrepeat observation cannot retain a match', function()
    for _, change in ipairs({ 'tuple', 'cast-method', 'repeat-method', 'namespace' }) do
        local f = fixture()

        f.onRepeat = function()
            if change == 'tuple' then
                f.cast.key = 'PRIVATE_REPLACED'
            elseif change == 'cast-method' then
                f.env.UnitCastingInfo = function()
                    return 'PRIVATE_NAME', nil, nil, nil, nil, false, 'PRIVATE_GUID', nil, 547
                end
            elseif change == 'repeat-method' then
                f.env.C_Spell.IsAutoRepeatSpell = function() return false end
            else
                f.env.C_Spell = {}
            end
        end

        local l = start(f)
        emit(f)
        witness(f:stop(l), 0, change == 'tuple' and 1 or 0, 0, change == 'tuple' and 0 or 1)
    end
end)

test('late supported APIs can yield a witness without changing prior unknown receipts', function()
    local f = fixture()
    local api = f.env.C_Spell
    f.env.C_Spell = {}
    local l = start(f)
    emit(f)
    f.env.C_Spell = api
    emit(f)
    local s = f:stop(l)
    witness(s, 1, 0, 0, 1)
    assert(#s.capture.trace.records == 2)
end)

test('channel exclusion still wins on the entire alias after a matching START witness', function()
    local f = fixture()
    local l = start(f)
    emit(f)
    f:emit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'PRIVATE_GUID', 547)
    f:emit('UNIT_SPELLCAST_CHANNEL_START', 'player', 'PRIVATE_GUID', 547)
    local s = f:stop(l)
    witness(s, 1, 0, 0, 0)

    for _, r in ipairs(s.capture.trace.records) do
        assert(r.castKind == 'channel')
    end
end)

test('Stop and Clear inside either native observation retire before diagnostic publication', function()
    for _, where in ipairs({ 'cast', 'repeat' }) do
        for _, how in ipairs({ 'stop', 'clear' }) do
            local f = fixture()
            local l = start(f)
            local once = false

            f[where == 'cast' and 'onCast' or 'onRepeat'] = function()
                if once then
                    return
                end

                once = true

                if how == 'stop' then
                    f:stop(l)
                else
                    f.service:Clear()
                end
            end

            emit(f)
            local s = f.service:GetSnapshot()

            if how == 'stop' then
                witness(s, 0, 0, 0, 0)
                assert(#s.capture.trace.records == 0)
            else
                assert(s == nil)
            end
        end
    end
end)

test('Clear then newer capture from native observation cannot receive old counters or rows', function()
    for _, where in ipairs({ 'cast', 'repeat' }) do
        local f = fixture()
        start(f)
        local newer
        local once = false

        f[where == 'cast' and 'onCast' or 'onRepeat'] = function()
            if once then
                return
            end

            once = true
            f.service:Clear()
            newer = f:start()
        end

        emit(f)
        assert(newer and f.service:GetStatus().phase == 'running')
        local s = f:stop(newer)
        witness(s, 0, 0, 0, 0)
        assert(#s.capture.trace.records == 0)
    end
end)

test('retained old handler never queries or counts after stop and restart', function()
    local f = fixture()
    local l = start(f)
    local old = f.scripts.OnEvent
    f:stop(l)
    l = start(f)
    old(nil, 'UNIT_SPELLCAST_START', f.secret, f.secret, f.secret)
    assert(#f.queries == 0)
    witness(f:stop(l), 0, 0, 0, 0)
end)

test('copy report preserves old receipt details and appends only bounded anonymous witness counters', function()
    local f = fixture()
    local L = setmetatable({}, { __index = function(_, k) return k end })
    f.env.LibStub = function() return { GetLocale = function() return L end } end
    local shown

    function f.addon:ShowConditionText(text)
        shown = text
    end

    local chunk = assert(loadfile('UI/analytics_capture.lua'))
    setfenv(chunk, f.env)
    chunk('rotationmaster', f.addon)
    assert(f.addon:RunCastCaptureAction('start'))
    emit(f)
    assert(f.addon:RunCastCaptureAction('stop'))
    assert(f.addon:RunCastCaptureAction('report'))

    assert(
        shown:find('START witness rows: observed=1 matched=1 mismatch=0 excluded=0 unknown=0', 1, true),
        'witness summary absent'
    )

    assert(shown:find('seq=1 time=0 attempt actor=player cast=1 spell=547 kind=unmodeled signal=start', 1, true))
    assert(shown:find('Scoring: unavailable', 1, true))
    assert(not shown:find('PRIVATE', 1, true))
    assert(#shown < 40000)
end)

test('second cast read and optional readability reentry cannot publish a retired witness', function()
    for _, where in ipairs({ 'second', 'read' }) do
        local f = fixture()
        local l = start(f)
        local seen = 0

        if where == 'second' then
            f.onCast = function()
                seen = seen + 1

                if seen == 2 then
                    f:stop(l)
                end
            end
        else
            f.hooks.read = function(v)
                if v == 'PRIVATE_NAME' then
                    f.hooks.read = nil
                    f:stop(l)
                end
            end
        end

        emit(f)
        local s = f.service:GetSnapshot()
        witness(s, 0, 0, 0, 0)
        assert(#s.capture.trace.records == 0)
    end
end)

test('replacement namespace cannot impersonate the captured API table with equality callbacks', function()
    local f = fixture()
    local mt = { __eq = function() return true end }
    setmetatable(f.env.C_Spell, mt)
    local original = f.env.C_Spell.IsAutoRepeatSpell

    f.onRepeat = function()
        f.env.C_Spell = setmetatable({ IsAutoRepeatSpell = original }, mt)
    end

    local l = start(f)
    emit(f)
    witness(f:stop(l), 0, 0, 0, 1)
end)

test('retiring namespace lookup cannot invoke a later provider field callback', function()
    local f = fixture()
    local l = start(f)
    local spells = f.env.C_Spell
    local repeatSpell = spells.IsAutoRepeatSpell
    local stale = false

    f.onRepeat = function()
        f.onRepeat = nil
        spells.IsAutoRepeatSpell = nil

        setmetatable(spells, {
            __index = function()
                stale = true
                return repeatSpell
            end,
        })

        f.env.C_Spell = nil

        setmetatable(f.env, {
            __index = function(_, key)
                if key == 'C_Spell' then
                    f:stop(l)
                    return spells
                end

                return _G[key]
            end,
        })
    end

    emit(f)
    assert(not stale, 'provider callback invoked after capture retirement')
    local s = f.service:GetSnapshot()
    witness(s, 0, 0, 0, 0)
end)

finish()
