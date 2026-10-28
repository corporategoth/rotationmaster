local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/acquisition_proof_consolidation.lua'):match('^(.-)\ntest%('))
local acquired, find, calls = assert(loadstring(prefix .. '\nreturn acquired,find,calls', '@active-snapshot-fixture'))()

local function lateFixture(target)
    local loader = loadfile
    local environment = getfenv
    local state = {}

    _G.loadfile = function(path)
        local chunk = loader(path)

        if path ~= 'Data/rotation_store.lua' then
            return chunk
        end

        return function(name, addon)
            local inherited = environment(1)
            local separate = {}

            separate.getfenv = function(value)
                if value == addon.RotationData.IsRotationClassToken and state.onProbe then
                    local fn = state.onProbe
                    state.onProbe = nil
                    fn()
                end

                -- Store's numeric probe is getfenv(1), its own source environment. Do not
                -- model that through VM-dependent tail-call stack levels in this wrapper.
                if type(value) == 'number' then
                    assert(value == 1)
                    return separate
                end

                return environment(value)
            end

            setmetatable(separate, { __index = inherited })
            setfenv(chunk, separate)
            return chunk(name, addon)
        end
    end

    local ok, c, a, get, body, full, token, notified = pcall(acquired, target)
    _G.loadfile = loader
    assert(ok, c)
    return c, a, get, body, full, token, notified, state
end

test('one returned full proof takes one shared active snapshot', function()
    for _, target in ipairs({ false, true }) do
        local _, _, _, _, full = acquired(target)
        local active = assert(find(full, 'readActiveRuntime'))
        local guard = assert(find(full, 'guard'))

        assert(
            calls(active, function()
                for i = 1, 7 do
                    assert(full())
                end
            end) == 7,
            'full proof repeated active snapshot'
        )

        assert(
            calls(guard, function()
                for i = 1, 7 do
                    assert(full())
                end
            end) == 7,
            'full Store publication proof was removed'
        )
    end
end)

test('late optional environment probe cannot retain an old same-key operation', function()
    local _, a, _, body, full, _, notified, s = lateFixture(true)

    s.onProbe = function()
        local op = assert(a:BeginActiveRotationTransition())
        assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation, body))
    end

    assert(not full() and not notified(), 'late same-key operation survived final snapshot')
end)

test('late optional probe nested acquisition retires old guard and preserves newer guard', function()
    local _, a, get, _, full, _, notified, s = lateFixture(true)
    local nextFull, nextNotified

    s.onProbe = function()
        local b, f, _, h, _, _, n = get(a, 0, a.currentRotation)
        assert(h and b and f() and n())
        nextFull, nextNotified = f, n
    end

    assert(not full() and not notified(), 'old returned proof survived nested acquisition')
    assert(nextFull() and nextNotified(), 'old guard revoked newer nested authority')
end)

test('late dependency notification rejects a proof even when active handle is unchanged', function()
    local _, a, _, _, full, _, notified, s = lateFixture(false)

    s.onProbe = function()
        assert(a:InvalidateRotationDependencies('effect', 'late'))
    end

    assert(not full() and not notified(), 'late managed dependency publication survived')
end)

test('late raw db profile spec key changes reject before publication', function()
    for _, change in ipairs({ 'db', 'profile', 'spec', 'key' }) do
        local _, a, _, _, full, _, _, s = lateFixture(true)

        s.onProbe = function()
            if change == 'db' then
                a.db = {}
            elseif change == 'profile' then
                a.db.profile = {}
            elseif change == 'spec' then
                a.currentSpec = 1
            else
                a.currentRotation = 'other'
            end
        end

        assert(not full(), 'late raw ' .. change .. ' mutation survived')
    end
end)

test('stale raw selection rejects before invoking optional proof callbacks', function()
    local _, a, _, _, full, _, _, s = lateFixture(true)
    local n = 0

    s.onProbe = function()
        n = n + 1
    end

    a.currentSpec = 1
    assert(not full() and n == 0, 'stale owner invoked optional proof callback')
end)

test('consumer pointer or environment changes decline the full publication proof', function()
    for _, change in ipairs({ 'pointer', 'environment' }) do
        local _, a, _, _, full = acquired(true)
        local original = a.GetSpellIds

        if change == 'pointer' then
            a.GetSpellIds = function()
                error('unknown consumer invoked')
            end
        else
            setfenv(original, setmetatable({}, { __index = getfenv(original) }))
        end

        assert(not full(), change .. ' consumer change survived')
    end
end)

finish()
