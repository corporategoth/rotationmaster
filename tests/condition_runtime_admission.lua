-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Source-owned graph admission after the caller's full acquisition.
if jit then
    jit.off()
    jit.flush()
end

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(p)
    local h = assert(io.open(p))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/condition_runtime.lua'):match('^(.-)\ntest%('))

local fixture, body, level = assert(loadstring(
    prefix .. '\nreturn fixture,body,level',
    '@condition-admission-fixture'
))()

test('managed Prepare final admission uses resume while retaining explicit full authority', function()
    local f, _, prepare = fixture()
    local full, gate = 0, 0
    local root = level(40)

    local session = assert(prepare(
        f.addon,
        body(root),
        {},
        function() return true end,
        function()
            full = full + 1
            return false
        end,
        function(kind)
            assert(kind == 'resume')
            gate = gate + 1
            return true
        end
    ))

    assert(full == 0 and gate == 1, 'managed admission repeated full acquisition')
    assert(not session:CheckFull() and full == 1 and not session:IsCurrent(), 'explicit full authority was discarded')
end)

test('five argument Prepare and AfterOpaque keep full rejection and errors', function()
    local f, _, prepare = fixture()
    local root = level(40)
    local allowed = false
    local full = 0

    assert(
        prepare(f.addon, body(root), {}, function() return true end, function()
            full = full + 1
            return allowed
        end) == nil and full == 1
    )

    allowed = true

    local session = assert(prepare(f.addon, body(root), {}, function() return true end, function()
        full = full + 1
        return allowed
    end))

    allowed = false
    assert(not session:AfterOpaque() and not session:IsCurrent() and full == 3)

    local ok, why = pcall(prepare, f.addon, body(root), {}, function() return true end, function()
        error('legacy-full-sentinel', 0)
    end)

    assert(not ok and tostring(why):find('legacy-full-sentinel', 1, true), 'legacy full error changed')
end)

test('event registration retirement refuses final admission and cleans only its owned frame', function()
    local allowed = true
    local f, s, prepare = fixture()

    s.onRegister = function()
        allowed = false
    end

    local session = prepare(
        f.addon,
        body(level(40)),
        {},
        function() return true end,
        function() return true end,
        function() return allowed end
    )

    assert(session == nil, 'retired capability/registration callback published a session')
    assert(not f.addon:GetConditionRuntimeDiagnostic().active)

    for _, frame in ipairs(s.frames) do
        assert(next(frame.events) == nil, 'rejected admission left subscription active')
    end
end)

test('reentrant final resume cannot retire or overwrite a newer session', function()
    local f, _, prepare, retire = fixture()
    local root = level(40)
    local b = body(root)
    local token = {}
    local nested
    local once = false

    local outer = prepare(f.addon, b, token, function() return true end, function() return true end, function(kind)
        assert(kind == 'resume')

        if not once then
            once = true

            nested = assert(prepare(
                f.addon,
                b,
                token,
                function() return true end,
                function() return true end,
                function() return true end
            ))
        end

        return false
    end)

    assert(outer == nil and nested and nested:IsCurrent(), 'old Prepare overwrote nested session')
    assert(not retire(f.addon, false) and nested:EvaluateBool(root))
end)

test('postenvironment resume retains actual provider authority rejection', function()
    local f, _, prepare = fixture()
    local root = level(40)
    local full = 0

    local session = assert(prepare(
        f.addon,
        body(root),
        {},
        function() return true end,
        function()
            full = full + 1
            return true
        end,
        function() return true end
    ))

    f.addon.GetConditionUnitLevel = function()
        error('unknown helper must not run')
    end

    assert(not session:AfterOpaque() and not session:IsCurrent(), 'postenvironment source certificate lost')
    assert(full == 0, 'postenvironment repeated Store/dependency proof')
end)

test('postenvironment denied continuation latches even after the owner guard recovers', function()
    local f, _, prepare = fixture()
    local allowed = true
    local root = level(40)

    local session = assert(prepare(
        f.addon,
        body(root),
        {},
        function() return true end,
        function() return true end,
        function() return allowed end
    ))

    allowed = false
    assert(not session:AfterOpaque(), 'retired admitted owner survived environment')
    allowed = true

    assert(
        not session:IsCurrent() and session:EvaluateResult(root).status == 'unavailable',
        'denied continuation revived'
    )
end)

test('admitted environment preserves fact event epochs and quarantine retirement', function()
    local f, s, prepare = fixture(function(f)
        f.load('Diagnostics/errors.lua')
    end)

    local root = level(40)

    local session = assert(prepare(
        f.addon,
        body(root),
        {},
        function() return true end,
        function() return true end,
        function() return true end
    ))

    assert(session:EvaluateBool(root))
    local reads = s.levelReads
    s.level = 20
    s.fire('UNIT_LEVEL', 'player')
    assert(session:AfterOpaque())
    assert(not session:EvaluateBool(root) and s.levelReads > reads, 'event reused old fact')
    local bad = level('not numeric')
    assert(f.addon:evaluateConditionResult(bad).status == 'unavailable')
    assert(f.addon:evaluateConditionResult(root).status == 'unavailable')
    assert(not session:AfterOpaque() and not session:IsCurrent(), 'quarantine epoch did not retire admitted graph')
end)

test('cold capability callback replacing next never receives a private condition node', function()
    local root = level(40)
    local escaped = false

    local f, s, prepare = fixture(function(f, state)
        local original = f.addon.Platform.CanReadValue
        local originalNext = f.env.next

        f.addon.Platform.CanReadValue = function(self, value)
            if state.arm then
                state.arm = false

                f.env.next = function(object, key)
                    if object == root then
                        escaped = true
                    end

                    return originalNext(object, key)
                end
            end

            return original(self, value)
        end
    end)

    s.arm = true

    local session = assert(prepare(
        f.addon,
        body(root),
        {},
        function() return true end,
        function() return true end,
        function() return true end
    ))

    assert(not escaped, 'late public next received private compiler node')
    assert(session:EvaluateBool(root))
end)

finish()
