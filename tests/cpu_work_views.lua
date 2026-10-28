local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function replace(s, old, new)
    local a, b = assert(s:find(old, 1, true))
    assert(not s:find(old, b + 1, true))
    return s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

local source = assert(read('tests/cpu.lua'):match('^(.-)\ntest%('))
local make = assert(loadstring(source .. '\nreturn fixture', '@work-cpu-real-fixture'))()
local heading = 'Runtime work views (native counters; shared functions overlap):'

local names = {
    'Store.plain',
    'Store.fields',
    'Store.validAddress',
    'Main.UpdateUnitInfo',
    'Diagnostics.Call',
    'EvaluationProfile.child',
}

local function has(s, x)
    assert(type(s) == 'string' and s:find(x, 1, true), 'missing ' .. x)
end

local function privacy(s)
    for _, x in ipairs({ 'SECRET_SOURCE_TEXT', 'PRIVATE_WORK', 'Player-1234', 'function:', 'table:', '0x' }) do
        assert(not s:find(x, 1, true), 'private value ' .. x)
    end
end

local function split(text)
    local at = text:find('\n' .. heading, 1, true) or text:find('\nRuntime work views omitted', 1, true)
    return at and text:sub(1, at - 1) or text, at and text:sub(at + 1)
end

local function fixture(options)
    options = options or {}
    local prior = loadfile

    if options.old then
        loadfile = function(path)
            if path == 'Diagnostics/cpu.lua' then
                local s = read(path)

                if s:find('-- BEGIN RUNTIME WORK VIEWS', 1, true) then
                    s = dofile('tests/fixtures/restore_cpu_work_views.lua')(s, path)
                end

                return assert(loadstring(s, '@' .. path))
            end

            return prior(path)
        end
    end

    local ok, f, a, s = pcall(make)
    loadfile = prior
    assert(ok, f)
    local bind = a.BindCPURuntimeWorkDiagnostic
    s.bind = bind
    s.groups = {}
    s.fns = {}

    a.BindCPURuntimeWorkDiagnostic = function(owner, name, anchor, reader)
        local fns = { reader() }
        s.groups[name] = { anchor = anchor, reader = reader, fns = fns }

        if options.reader then
            reader = options.reader(name, reader, f, a, s)
        end

        if bind then
            return bind(owner, name, anchor, reader)
        end
    end

    for _, p in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Data/validation.lua',
        'Data/rotation_store.lua',
    }) do
        f.load(p)
    end

    if options.groups ~= 1 then
        -- Exact actual helper body and source footer; no gameplay helper is substituted.
        local main = read('main.lua')
        local first = assert(main:find('local function UpdateUnitInfo(cache, record)', 1, true))
        local last = assert(main:find('\nfunction addon:StopAdviceForError', first, true))
        local footer = main:match('(\n%-%- BEGIN CPU RUNTIME WORK HANDOFF.-%-%- END CPU RUNTIME WORK HANDOFF\n)') or ''

        local chunk = assert(loadstring(
            'local _,addon=...\nlocal getCached=addon.Functions.cache.getCached\n'
                .. main:sub(first, last - 1)
                .. footer,
            '@main.lua'
        ))

        setfenv(chunk, f.env)
        chunk('rotationmaster', a)
    end

    a.BindCPURuntimeWorkDiagnostic = nil  -- retire only the test interceptor
    f.load('Diagnostics/errors.lua')
    f.load('profiler.lua')
    a.evaluationProfile = a:ProfiledCode()

    for _, key in ipairs({ 'store', 'main' }) do
        local g = s.groups[key]

        if g then
            for _, fn in ipairs(g.fns) do
                s.fns[#s.fns + 1] = fn
            end
        end
    end

    s.fns[#s.fns + 1] = a.Diagnostics.Call
    s.fns[#s.fns + 1] = a.evaluationProfile.child
    return f, a, s
end

local function count(s, fn)
    local n = 0

    for _, q in ipairs(s.queries) do
        if q[1] == fn then
            n = n + 1
        end
    end

    return n
end

local function cost(s)
    for i, fn in ipairs(s.fns) do
        s.rows[fn] = { { i, 2 * i, 10 * i }, { i + 3, 2 * i + 5, 10 * i + 2 } }
    end
end

local function complete(a, s)
    assert(a:StartCPUProfile())
    s:complete()
    return assert(a:GetCPUProfileReport())
end

test('collection invokes no measured helper or profiler child and idle access remains inert', function()
    local _, a, s = fixture()
    cost(s)
    local calls = {}

    for _, fn in ipairs(s.fns) do
        calls[fn] = 0
    end

    local prior, mask, n = debug.gethook()
    local j = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(ev)
        if ev == 'call' then
            local fn = debug.getinfo(2, 'f').func

            if calls[fn] then
                calls[fn] = calls[fn] + 1
            end
        end
    end, 'c')

    local ok, why = pcall(function()
        assert(#s.queries == 0)
        a:GetCPUProfileReport()
        a:IsCPUProfileRunning()
        complete(a, s)
        local n = #s.queries

        for i = 1, 5 do
            a:GetCPUProfileReport()
            a:IsCPUProfileRunning()
            s.timers[1].callback()
        end

        assert(#s.queries == n)

        for _, v in pairs(calls) do
            assert(v == 0, 'sampled function executed')
        end
    end)

    if prior then
        debug.sethook(prior, mask, n)
    else
        debug.sethook()
    end

    if j then
        jit.on()
    end

    assert(ok, why)
end)

test('first attempted capture retires missing and partial registrations including refusals', function()
    for _, groups in ipairs({ 0, 1 }) do
        local f, a, s = fixture({ groups = groups == 1 and 1 or nil })
        local bind = assert(s.bind, 'startup work installer absent')

        -- Use a separately fresh zero-group module for the zero case.
        if groups == 0 then
            f, a, s = make()
            bind = assert(a.BindCPURuntimeWorkDiagnostic)
        end

        s.enabled = '0'
        assert(not a:StartCPUProfile())
        assert(not bind(a, 'store', function() end, function() end))
        assert(not bind({}, 'main', function() end, function() end))
        s.enabled = '1'
        local text = complete(a, s)
        has(text, 'unavailable: unbound')
    end
end)

test('actual complete main and store source register only the captured owner and retire the installer', function()
    local startup = assert(read('tests/startup.lua'):match('^(.-)\ntest%('))
    local makeStartup = assert(loadstring(startup .. '\nreturn fixture', '@work-whole-startup'))()
    local _, a, load = makeStartup(true, true)
    load('Diagnostics/cpu.lua')
    local bind = assert(a.BindCPURuntimeWorkDiagnostic)
    assert(not bind({}, 'main', function() end, function() end))
    load('main.lua')

    for _, p in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Data/validation.lua',
        'Data/rotation_store.lua',
    }) do
        load(p)
    end

    assert(a.BindCPURuntimeWorkDiagnostic == nil and not bind(a, 'main', a.EvaluateNextActionInternal, function() end))
end)

test('source anchors and raw selected object identity cannot be replaced or getter-spoofed', function()
    for _, mode in ipairs({ 'store', 'main', 'diagnostics', 'profile' }) do
        local f, a, s = fixture()
        cost(s)
        assert(a:StartCPUProfile())
        local getters = 0

        if mode == 'store' then
            a.RotationData.NewRotationStore = nil

            setmetatable(a.RotationData, {
                __index = function()
                    getters = getters + 1
                    error('PRIVATE_WORK')
                end,
            })
        elseif mode == 'main' then
            a.EvaluateNextActionInternal = function() end
        elseif mode == 'diagnostics' then
            a.Diagnostics = { Call = a.Diagnostics.Call }
        else
            a.evaluationProfile = { child = a.evaluationProfile.child }
        end

        s:complete()
        local text = a:GetCPUProfileReport()
        has(text, 'unavailable: owner-changed')
        assert(getters == 0)
        privacy(text)
    end
end)

test('replaced work function or unreadable provider result becomes unavailable without executing it', function()
    for _, mode in ipairs({ 'throw', 'arity', 'restricted' }) do
        local f, a, s = fixture({
            reader = function(name, reader, f)
                if name ~= 'store' then
                    return reader
                end

                if mode == 'throw' then
                    return function()
                        error('PRIVATE_WORK')
                    end
                elseif mode == 'arity' then
                    return function() return function() end end
                end

                local opaque = {}
                f.env.canaccessvalue = function(v) return v ~= opaque end
                return function() return opaque, opaque, opaque end
            end,
        })

        local text = complete(a, s)
        has(text, 'Work.Store.plain | unavailable:')
        privacy(text)
    end

    local _, a, s = fixture()
    cost(s)
    assert(a:StartCPUProfile())

    a.evaluationProfile.child = function()
        error('PRIVATE_WORK')
    end

    s:complete()
    has(a:GetCPUProfileReport(), 'Work.EvaluationProfile.child | unavailable: function-replaced')
end)

test('aliases share native snapshots across old rows and all new views', function()
    local _, a, s = fixture()
    cost(s)
    a.EvaluateNextAction = s.fns[1]
    a.EvaluateNextActionInternal = s.fns[4]
    -- Main's declared anchor must match the actual source anchor at baseline.
    a.EvaluateNextActionInternal = s.groups.main.anchor
    a.GetRotationContext = s.fns[1]
    a.Diagnostics.Call = s.fns[1]
    a.evaluationProfile.child = s.fns[1]
    local text = complete(a, s)
    has(text, 'Work.Store.plain | exclusive=3.000 ms')
    assert(count(s, s.fns[1]) == 4, 'shared pointer resampled')
end)

test('query failure negative invalid counters and API replacement are bounded and sourcefree', function()
    for _, mode in ipairs({ 'throw', 'negative', 'api' }) do
        local f, a, s = fixture()
        cost(s)

        if mode == 'throw' then
            s.throwFunction = s.fns[1]
        elseif mode == 'negative' then
            s.rows[s.fns[1]] = { { -1, 0, 0 }, { 3, 5, 2 } }
        end

        assert(a:StartCPUProfile())

        if mode == 'api' then
            f.env.GetFunctionCPUUsage = function() return 0, 0 end
        end

        s:complete()
        local text = a:GetCPUProfileReport()
        privacy(text)
        has(text, mode == 'api' and 'profiling-api-changed' or 'Work.Store.plain | unavailable:')
    end
end)

test('cancel stale timer and restart keep samples and report ownership separate', function()
    local _, a, s = fixture()
    cost(s)
    assert(a:StartCPUProfile())
    local n = #s.queries
    local stale = s.timers[1]
    assert(a:CancelCPUProfile())
    local text = a:GetCPUProfileReport()
    stale.callback()
    assert(#s.queries == n and a:GetCPUProfileReport() == text)
    assert(a:StartCPUProfile())
    s:complete()
    has(a:GetCPUProfileReport(), heading)
end)

test('cancellation during new start query schedules no old timer and retains its report', function()
    local f, a, s = fixture()
    cost(s)
    local query = f.env.GetFunctionCPUUsage
    local cancelled = false

    f.env.GetFunctionCPUUsage = function(fn, mode)
        if fn == s.fns[1] and not cancelled then
            cancelled = true
            assert(a:CancelCPUProfile())
        end

        return query(fn, mode)
    end

    assert(a:StartCPUProfile())
    assert(cancelled and not a:IsCPUProfileRunning() and #s.timers == 0)
    has(a:GetCPUProfileReport(), 'cancelled')
end)

test('newer completed capture during old end query retains its report and callback', function()
    local f, a, s = fixture()
    cost(s)
    local query = f.env.GetFunctionCPUUsage
    local entered = false
    local last

    a.OnCPUProfileFinished = function(_, text)
        last = text
    end

    f.env.GetFunctionCPUUsage = function(fn, mode)
        if s.phase == 'finish' and fn == s.fns[1] and not entered then
            entered = true
            assert(a:StartCPUProfile(1))
            local timer = s.timers[#s.timers]
            s.now = s.now + 1
            timer.callback()
            last = a:GetCPUProfileReport()
        end

        return query(fn, mode)
    end

    assert(a:StartCPUProfile(10))
    s:complete()
    assert(entered and a:GetCPUProfileReport() == last)
    has(last, 'duration=1.000 s')
end)

test('synchronous scheduling and nil error tokens preserve prior ownership behavior without extra samples', function()
    for _, mode in ipairs({ 'sync', 'nil', 'error' }) do
        local _, a, s = fixture()
        cost(s)

        if mode == 'sync' then
            a.ScheduleTimer = function(_, callback)
                s.now = 110
                s.phase = 'finish'
                callback()
                return {}
            end
        elseif mode == 'nil' then
            a.ScheduleTimer = function() return nil end
        else
            s.scheduleError = true
        end

        local ok, why = a:StartCPUProfile()

        if mode == 'sync' then
            assert(ok)
        else
            assert(not ok and why == 'timer-error')
        end

        assert(not a:IsCPUProfileRunning())

        for _, fn in ipairs(s.fns) do
            assert(count(s, fn) <= (mode == 'sync' and 4 or 2))
        end
    end
end)

test('foreign capture and missing raw selected services report unavailable without new helper queries', function()
    local _, a, s = fixture()
    cost(s)
    local foreign = {}

    for k, v in pairs(a) do
        foreign[k] = v
    end

    assert(a.StartCPUProfile(foreign))
    s:complete()
    has(a:GetCPUProfileReport(), 'Work.Store.plain | unavailable: owner-changed')
    local _, b, t = fixture()
    b.Diagnostics = nil
    b.evaluationProfile = nil
    local text = complete(b, t)
    has(text, 'Work.Diagnostics.Call | unavailable:')
    has(text, 'Work.EvaluationProfile.child | unavailable:')
end)

test('literal source reentry and readability callbacks cannot adopt a newer owner', function()
    local f, a, s = fixture({
        reader = function(name, reader, f, a)
            if name ~= 'store' then
                return reader
            end

            return function()
                a.RotationData = { NewRotationStore = a.RotationData.NewRotationStore }
                return reader()
            end
        end,
    })

    has(complete(a, s), 'Work.Store.plain | unavailable: owner-changed')
    local f, a, s = fixture()
    cost(s)
    local armed = false
    local fn = a.Diagnostics.Call

    f.env.canaccessvalue = function(value)
        if armed and value == fn then
            a.Diagnostics = { Call = fn }
        end

        return true
    end

    assert(a:StartCPUProfile())
    armed = true
    s:complete()
    has(a:GetCPUProfileReport(), 'Work.Diagnostics.Call | unavailable: owner-changed')
end)

test('duplicate source slots share both snapshots and readers cannot outlive capture entry', function()
    local f, a, s = fixture({
        reader = function(name, reader)
            if name ~= 'store' then
                return reader
            end

            return function()
                local fn = reader()
                return fn, fn, fn
            end
        end,
    })

    cost(s)
    local text = complete(a, s)
    assert(count(s, s.fns[1]) == 4)
    has(text, 'Work.Store.fields | exclusive=3.000 ms')
    has(text, 'Work.Store.validAddress | exclusive=3.000 ms')

    local f, a, s = fixture({
        reader = function(name, reader, f, a)
            if name ~= 'store' then
                return reader
            end

            return function()
                a:CancelCPUProfile()
                return reader()
            end
        end,
    })

    assert(a:StartCPUProfile())
    assert(#s.timers == 0 and not a:IsCPUProfileRunning())
    has(a:GetCPUProfileReport(), 'cancelled')
end)

test('missing and false service namespaces never select addon method decoys', function()
    for _, absent in ipairs({ 'nil', 'false' }) do
        local _, a, s = fixture()
        cost(s)
        local call, child = a.Diagnostics.Call, a.evaluationProfile.child
        a.Call = call
        a.child = child

        if absent == 'nil' then
            a.Diagnostics = nil
            a.evaluationProfile = nil
        else
            a.Diagnostics = false
            a.evaluationProfile = false
        end

        local text = complete(a, s)
        has(text, 'Work.Diagnostics.Call | unavailable: owner-changed')
        has(text, 'Work.EvaluationProfile.child | unavailable: owner-changed')
        assert(count(s, call) == 0 and count(s, child) == 0, 'addon decoy sampled for missing namespace')
    end
end)

test('clearing an addon-identical selected namespace during readability cannot retain it', function()
    for _, service in ipairs({ 'Diagnostics', 'evaluationProfile' }) do
        for _, phase in ipairs({ 'start', 'finish' }) do
            local f, a, s = fixture()
            cost(s)
            local member = service == 'Diagnostics' and 'Call' or 'child'
            local fn = a[service][member]
            a[member] = fn
            a[service] = a
            local cleared = false

            f.env.canaccessvalue = function(value)
                if not cleared and s.phase == phase and value == fn then
                    cleared = true
                    a[service] = nil
                end

                return true
            end

            local text = complete(a, s)
            assert(cleared)

            has(
                text,
                'Work.'
                    .. (service == 'Diagnostics' and 'Diagnostics.Call' or 'EvaluationProfile.child')
                    .. ' | unavailable: owner-changed'
            )

            assert(count(s, fn) == (phase == 'start' and 0 or 2), 'retired namespace sampled')
        end
    end
end)

test('actual current main fixture initializes after historical preparation for both target states', function()
    local make = dofile('tests/fixtures/rotation_execution.lua')

    for _, target in ipairs({ false, true }) do
        local c = make({ target = target })
        c.tick()
        assert(not c.a.adviceErrorReport, 'actual main failed')
        assert(#c.a.Diagnostics:GetReports() == 0)
    end
end)

finish()
