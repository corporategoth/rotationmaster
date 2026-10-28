local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local apis = { stealthed = 'IsStealthed', control = 'HasFullControl', outdoors = 'IsOutdoors' }

local function fixture(project)
    local f = F.new(project)
    local e = f.env
    local s = { stealthed = true, control = true, outdoors = true, calls = {} }

    for kind, api in pairs(apis) do
        local selected = kind

        e[api] = function(...)
            assert(select('#', ...) == 0, 'player flag received extra native arguments')
            s.calls[#s.calls + 1] = selected

            if s.throw == selected then
                error('native flag failed')
            end

            return s[selected]
        end
    end

    e.UnitExists = function()
        error('self flag added an existence query')
    end

    e.IsInInstance = function()
        error('outdoors inferred instance state')
    end

    local file = io.open('Platform/player_flags.lua')

    if file then
        file:close()
        f.load('Platform/player_flags.lua')
    end

    return f, f.addon.Platform, s
end

local function observe(p, kind)
    assert(type(p.GetPlayerFlagObservation) == 'function', 'owned player flag observer missing')
    return p:GetPlayerFlagObservation(kind)
end

test('each closed player flag observes only its zero-argument native and preserves false', function()
    for kind in pairs(apis) do
        local _, p, s = fixture()
        assert(observe(p, kind) == true and #s.calls == 1 and s.calls[1] == kind)
        s[kind] = false
        local value, why = observe(p, kind)
        assert(value == false and why == nil and #s.calls == 2)
    end
end)

test('all probe families work and blocked policies perform no native queries', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local _, p, s = fixture(project)

        for kind in pairs(apis) do
            assert(observe(p, kind) == true)
        end

        assert(#s.calls == 3)
    end

    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)

        for kind in pairs(apis) do
            local value, why = observe(p, kind)
            assert(value == nil and why == 'unsupported-policy')
        end

        assert(#s.calls == 0)
    end
end)

test('invalid and restricted kind selection cannot call arbitrary functions', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, kind in ipairs({ '', false, 0, {}, opaque, 'combat', 'STEALTHED' }) do
        local value, why = observe(p, kind)
        assert(value == nil and why == (rawequal(kind, opaque) and 'restricted-value' or 'invalid-player-flag-query'))
    end

    assert(observe(p, nil) == nil and #s.calls == 0)
end)

test('required results reject missing failed nil malformed and unreadable data', function()
    for kind, api in pairs(apis) do
        local f, p, s = fixture()
        s[kind] = nil
        local value, why = observe(p, kind)
        assert(value == nil and why == 'player-flag-unavailable')

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s[kind] = bad
            value, why = observe(p, kind)
            assert(value == nil and why == 'invalid-api-result')
        end

        s[kind] = true
        s.throw = kind
        value, why = observe(p, kind)
        assert(value == nil and why == 'api-error')
        s.throw = nil
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s[kind] = opaque
        value, why = observe(p, kind)
        assert(value == nil and why == 'restricted-value')
        f.env[api] = nil
        value, why = observe(p, kind)
        assert(value == nil and why == 'missing-api')
    end
end)

test('load is query free and fresh observations use only the current selected API', function()
    for kind, api in pairs(apis) do
        local f, p, s = fixture()
        assert(#s.calls == 0)

        for other, name in pairs(apis) do
            if other ~= kind then
                f.env[name] = nil
            end
        end

        assert(observe(p, kind) == true)

        f.env[api] = function(...)
            assert(select('#', ...) == 0)
            return false
        end

        assert(observe(p, kind) == false)

        f.env[api] = function()
            error('module load queried native')
        end

        f.load('Platform/player_flags.lua')
        assert(#s.calls == 1)
    end
end)

test('secret and inaccessible false results are guarded before comparison', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    s.control = opaque
    local value, why = observe(p, 'control')
    assert(value == nil and why == 'restricted-value')
    f.env.issecretvalue = nil
    s.control = false
    f.env.canaccessvalue = function(v) return v ~= false end
    value, why = observe(p, 'control')
    assert(value == nil and why == 'restricted-value')
end)

finish()
