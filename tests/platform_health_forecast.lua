-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project or 11, 2, 'MAGE')
    local p = f.addon.Platform
    local s = { exists = true, guid = 'GUID-target', current = 90, maximum = 100, now = 100, calls = {} }
    local opaque = {}

    local function query(key, ...)
        s.calls[#s.calls + 1] = key

        if key == 'time' then
            assert(select('#', ...) == 0)
        else
            assert(select('#', ...) == 1 and (...) == 'target', 'changed actor/native arity')
        end

        if s.throw == key then
            error('native failure')
        end

        return s[key]
    end

    f.env.UnitExists = function(...) return query('exists', ...) end
    f.env.UnitGUID = function(...) return query('guid', ...), opaque end
    f.env.UnitHealth = function(...) return query('current', ...) end
    f.env.UnitHealthMax = function(...) return query('maximum', ...) end

    f.env.GetTime = function(...)
        query('time', ...)
        return s.now
    end

    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    local h = io.open('Platform/health_forecast.lua')

    if h then
        h:close()
        f.load('Platform/health_forecast.lua')
    end

    return f, p, s, opaque
end

local function identity(p)
    assert(p.GetHealthForecastIdentityObservation, 'forecast observer missing')
    return p:GetHealthForecastIdentityObservation('target')
end

local function value(p, kind)
    assert(p.GetHealthForecastValueObservation, 'forecast scalar observer missing')
    return p:GetHealthForecastValueObservation('target', kind)
end

local function provider(p)
    assert(p.GetHealthForecastProviderObservation, 'forecast provider observer missing')
    return p:GetHealthForecastProviderObservation('target')
end

local function unknown(fn)
    local r, why = fn()
    assert(r == nil and type(why) == 'string', 'observation became known')
end

test('identity is exact present GUID or known absence without unrequested native work', function()
    local f, p, s = fixture()
    assert(#s.calls == 0 and identity(p) == 'GUID-target' and table.concat(s.calls, ',') == 'exists,guid')
    s.calls = {}
    s.exists = false

    f.env.UnitGUID = function()
        error('absent unit queried GUID')
    end

    assert(identity(p) == false and table.concat(s.calls, ',') == 'exists')
end)

test('missing failed nil malformed and restricted required identity facts remain unavailable', function()
    for _, key in ipairs({ 'exists', 'guid' }) do
        for _, mode in ipairs({ 'nil', 'false', 'empty', 'number', 'opaque', 'throw', 'missing' }) do
            local f, p, s, opaque = fixture()

            if key ~= 'exists' or mode ~= 'false' then
                if mode == 'nil' then
                    s[key] = nil
                elseif mode == 'false' then
                    s[key] = false
                elseif mode == 'empty' then
                    s[key] = ''
                elseif mode == 'number' then
                    s[key] = 1
                elseif mode == 'opaque' then
                    s[key] = opaque
                elseif mode == 'throw' then
                    s.throw = key
                else
                    f.env[key == 'exists' and 'UnitExists' or 'UnitGUID'] = nil
                end

                unknown(function() return identity(p) end)
            end
        end
    end
end)

test('scalar kinds are lazy fresh exact one-argument health queries and include zero', function()
    local _, p, s = fixture()
    assert(value(p, 'current') == 90 and value(p, 'maximum') == 100 and table.concat(s.calls, ',') == 'current,maximum')
    s.current = 0
    s.maximum = 0
    assert(value(p, 'current') == 0 and value(p, 'maximum') == 0)
    unknown(function() return value(p, 'other') end)
end)

test('current and maximum unavailable numeric domains do not coerce or hide zero', function()
    for _, key in ipairs({ 'current', 'maximum' }) do
        for _, mode in ipairs({
            'nil', 'false', 'string', 'negative', 'nan', 'infinite', 'opaque', 'throw', 'missing'
        }) do
            local f, p, s, opaque = fixture()

            if mode == 'nil' then
                s[key] = nil
            elseif mode == 'false' then
                s[key] = false
            elseif mode == 'string' then
                s[key] = '90'
            elseif mode == 'negative' then
                s[key] = -1
            elseif mode == 'nan' then
                s[key] = 0 / 0
            elseif mode == 'infinite' then
                s[key] = math.huge
            elseif mode == 'opaque' then
                s[key] = opaque
            elseif mode == 'throw' then
                s.throw = key
            else
                f.env[key == 'current' and 'UnitHealth' or 'UnitHealthMax'] = nil
            end

            unknown(function() return value(p, key) end)
        end
    end
end)

test('optional provider uses independent partial dot tuples and keeps zero while ignoring tails', function()
    local f, p, s, opaque = fixture()
    assert(next(provider(p)) == nil)
    f.env.RealMobHealth = false
    assert(next(provider(p)) == nil)
    local current, maximum = nil, 100

    f.env.RealMobHealth = {
        GetUnitHealth = function(...)
            assert(select('#', ...) == 1 and (...) == 'target')
            return current, maximum, opaque
        end,
    }

    local r = provider(p)
    assert(r.current == nil and r.maximum == 100 and #s.calls == 0)
    current = 80
    maximum = false
    r = provider(p)
    assert(r.current == 80 and r.maximum == nil)
    current = 0
    maximum = 0
    r = provider(p)
    assert(r.current == 0 and r.maximum == 0)
    current = 50
    assert(provider(p).current == 50, 'provider was cached')
end)

test('provider failures remain unavailable instead of silently falling back', function()
    for _, mode in ipairs({
        'namespace',
        'opaque-namespace',
        'method',
        'throw',
        'current',
        'maximum',
        'nan',
        'negative',
    }) do
        local f, p, _, opaque = fixture()

        if mode == 'namespace' then
            f.env.RealMobHealth = 1
        elseif mode == 'opaque-namespace' then
            f.env.RealMobHealth = opaque
        elseif mode == 'method' then
            f.env.RealMobHealth = {}
        elseif mode == 'throw' then
            f.env.RealMobHealth = {
                GetUnitHealth = function()
                    error('provider failed')
                end,
            }
        else
            f.env.RealMobHealth = {
                GetUnitHealth = function()
                    return mode == 'current' and opaque or mode == 'nan' and 0 / 0 or mode == 'negative' and -1 or 90,
                        mode == 'maximum' and opaque or 100
                end,
            }
        end

        unknown(function() return provider(p) end)
    end
end)

test('forecast clock is fresh zero-argument finite signed fractional data and is separate from policy', function()
    local f, p, s, opaque = fixture()
    assert(p.GetHealthForecastTimeObservation, 'forecast clock missing')

    for _, now in ipairs({ 0, -1.5, 100.25 }) do
        s.now = now
        assert(p:GetHealthForecastTimeObservation() == now)
    end

    for _, bad in ipairs({ false, {}, opaque, 0 / 0, math.huge, '100' }) do
        s.now = bad
        unknown(function() return p:GetHealthForecastTimeObservation() end)
    end

    s.now = nil
    unknown(function() return p:GetHealthForecastTimeObservation() end)
    s.now = 100
    s.throw = 'time'
    unknown(function() return p:GetHealthForecastTimeObservation() end)
    s.throw = nil
    f.env.GetTime = nil
    unknown(function() return p:GetHealthForecastTimeObservation() end)
end)

test('policy and unreadable queries stop before selected-unit native calls', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        unknown(function() return identity(p) end)
        unknown(function() return value(p, 'current') end)
        unknown(function() return provider(p) end)
        assert(#s.calls == 0)
    end

    local _, p, s, opaque = fixture()
    assert(p.GetHealthForecastIdentityObservation, 'forecast observer missing')
    unknown(function() return p:GetHealthForecastIdentityObservation(opaque) end)
    unknown(function() return p:GetHealthForecastValueObservation('target', opaque) end)
    assert(#s.calls == 0)
end)

finish()
