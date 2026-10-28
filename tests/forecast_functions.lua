local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new(11, 2, 'MAGE')

    f.env.GetTime = function()
        error('bounded kernel queried native clock')
    end

    local h = io.open('Functions/forecast.lua')

    if h then
        h:close()
        f.load('Functions/forecast.lua')
    end

    local function calculate(history, window, noheals, nodmg, now)
        local owner = f.addon.Functions.forecast
        assert(owner and owner.calculate, 'bounded forecast missing')
        return owner.calculate(f.addon.Platform, history, window, noheals == true, nodmg == true, now or 100)
    end

    return f, f.addon, calculate
end

local function close(x, y)
    assert(math.abs(x - y) < 1e-10, tostring(x) .. ' != ' .. tostring(y))
end

local function unknown(fn, reason)
    local r, age, why = fn()
    assert(r == nil and age == nil and type(why) == 'string' and (not reason or why == reason), tostring(why))
end

test('ordered weighting uses final visited age rather than maximum or sorted timestamps', function()
    local _, _, calc = fixture()
    local r, s = calc({ damage = { { time = 92, value = 10 }, { time = 97, value = 10 } }, heals = {} }, 10)
    close(r, -35 / 17)
    assert(s == 3)
    r, s = calc({ damage = { { time = 89.6, value = 10 } }, heals = {} }, 10, true)
    close(r, 4 / 55)
    assert(s == 10)
end)

test('fractional and negative rounded bounds retain actual keys and integer bin steps', function()
    local _, a, calc = fixture()
    a.Functions.values.round = function() return 2.5 end
    local r, s = calc({ damage = { { time = 97, value = 10 } }, heals = {} }, 10)
    assert(r == 0 and s == 2.5)
    a.Functions.values.round = function() return -.5 end
    r, s = calc({ damage = { { time = 97, value = 10 } }, heals = {} }, 10)
    assert(r == 0 and s == 0)
end)

test('round authority is looked up live each row with one argument', function()
    local _, a, calc = fixture()

    a.round = function()
        error('new kernel used legacy alias')
    end

    local calls = 0

    a.Functions.values.round = function(...)
        assert(select('#', ...) == 1 and (...) == 1)
        calls = calls + 1

        a.Functions.values.round = function(...)
            assert(select('#', ...) == 1 and (...) == 3)
            calls = calls + 1
            return 3
        end

        return 1
    end

    local r, s = calc({ damage = { { time = 99, value = 10 }, { time = 97, value = 10 } }, heals = {} }, 10, true)
    close(r, -80 / 17)
    assert(s == 3 and calls == 2)
end)

test('stale break row does not read amount and a nil array hole hides every tail', function()
    local _, _, calc = fixture()

    local row = setmetatable({ time = 89 }, {
        __index = function(_, key)
            assert(key ~= 'value', 'stale amount read')
        end,
    })

    local r, s = calc({ damage = { row }, heals = {} }, 10)
    assert(r == 0 and s == 11)
    r, s = calc({ damage = { [1] = { time = 97, value = 10 }, [3] = { time = false, value = {} } }, heals = {} }, 10)
    close(r, -35 / 17)
    assert(s == 3)
end)

test('nil false amounts and skipped streams preserve zero estimates without unused reads', function()
    local _, _, calc = fixture()

    for _, amount in ipairs({ false, 0 }) do
        local r, s = calc({ damage = { { time = 97, value = amount } } }, 10, true)
        assert(r == 0 and s == 3)
    end

    local r, s = calc({ damage = { { time = 97 } } }, 10, true)
    assert(r == 0 and s == 3)
    r, s = calc({}, 0, true, true)
    assert(r == 0 and s == 0)
    r, s = calc({ damage = { { time = 1e308 } } }, 1e308, true, false, 0)
    assert(r == 0 and s == 0, 'unused overflowing scale was consumed')
end)

test('finite signed fractional windows times and amounts preserve legacy arithmetic exactly', function()
    local f, a, calc = fixture()
    local nativeCalls = 0
    local now = 100

    f.env.GetTime = function()
        nativeCalls = nativeCalls + 1
        return now
    end

    for _, window in ipairs({ -1, 0, .5, 1, 2, 10, 100, 300 }) do
        for _, clock in ipairs({ -10.25, 0, 100.5 }) do
            now = clock

            local history = {
                damage = {
                    { time = clock + 1.25, value = -2.5 },
                    { time = clock - .75, value = .25 },
                    { time = clock - 3.4, value = 10 },
                },
                heals = { { time = clock - 2.5, value = 3.5 } },
            }

            for _, flags in ipairs({ { false, false }, { true, false }, { false, true } }) do
                local expected, seconds = a.Functions.trends.calculate(history, window, flags[1], flags[2])
                local r, s = calc(history, window, flags[1], flags[2], clock)
                assert(r == expected and s == seconds, 'finite ordered result changed')
            end
        end
    end

    assert(nativeCalls == 72)
end)

test('one shared4096 work budget includes rows bins break age and both streams', function()
    local _, _, calc = fixture()
    local h = { damage = { { time = -3994, value = {} } }, heals = {} }
    local r, s = calc(h, 10, true)
    assert(r == 0 and s == 4094)
    unknown(function() return calc(h, 10) end, 'forecast-work-budget')
    local rows = {}

    for i = 1, 4094 do
        rows[i] = { time = 100, value = 1 }
    end

    r, s = calc({ damage = rows, heals = {} }, 10)
    assert(r == -4094 and s == 0)
    rows[4095] = { time = 100, value = 1 }
    unknown(function() return calc({ damage = rows, heals = {} }, 10) end, 'forecast-work-budget')

    unknown(function()
        return calc({ damage = { { time = -1e308, value = 1 } }, heals = {} }, 10)
    end, 'forecast-work-budget')
end)

test('required malformed nonfinite facts and overflow return reasons before comparisons or loops', function()
    local f, a, calc = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ false, opaque, 0 / 0, math.huge, '10' }) do
        unknown(function() return calc({ damage = {}, heals = {} }, bad) end)
    end

    for _, row in ipairs({
        {},
        { time = opaque },
        { time = -math.huge },
        { time = 97, value = opaque },
        { time = 97, value = math.huge },
        { time = 97, value = 1e308 },
    }) do
        unknown(function() return calc({ damage = { row }, heals = {} }, 10) end)
    end

    for _, bad in ipairs({ false, opaque, 0 / 0, math.huge, '3' }) do
        a.Functions.values.round = function() return bad end
        unknown(function() return calc({ damage = { { time = 97, value = 10 } }, heals = {} }, 10) end)
    end

    a.Functions.values.round = function()
        error('round failure')
    end

    unknown(function() return calc({ damage = { { time = 97, value = 10 } }, heals = {} }, 10) end)
    unknown(function() return calc({ damage = opaque, heals = {} }, 10) end)
    unknown(function() return calc({ damage = {}, heals = {} }, 10, false, false, math.huge) end)
end)

test('finite inputs that overflow denominator or rate are unavailable before a zero estimate', function()
    local _, _, calc = fixture()
    unknown(function() return calc({ damage = { { time = 99, value = 0 } }, heals = {} }, 1e308, true) end)

    unknown(function()
        return calc({
            damage = { { time = 100, value = 1e308 }, { time = 99, value = 0 } },
            heals = {},
        }, .5000000000000001, true)
    end)
end)

test('new canonical round authority and old live legacy authority stay distinct', function()
    local f, a, calc = fixture()
    local history = { damage = { { time = 97, value = 10 } }, heals = {} }
    f.env.GetTime = function() return 100 end
    local oldCalls, newCalls = 0, 0

    a.round = function(...)
        assert(select('#', ...) == 1)
        oldCalls = oldCalls + 1
        return 1
    end

    a.Functions.values.round = function(...)
        assert(select('#', ...) == 1)
        newCalls = newCalls + 1
        return 3
    end

    local rate, seconds = calc(history, 10)
    assert(seconds == 3 and newCalls == 1 and oldCalls == 0 and rate < 0)
    local oldRate, oldSeconds = a.Functions.trends.calculate(history, 10)
    assert(oldSeconds == 1 and oldCalls == 1 and newCalls == 1 and oldRate < 0)
    a.Functions.values.round = nil
    unknown(function() return calc(history, 10) end, 'forecast-round-unavailable')
    assert(a.Functions.trends.calculate(history, 10) < 0 and oldCalls == 2)
end)

test(
    'missing malformed restricted or failing canonical containers are unavailable only when a row needs round',
    function()
        for _, key in ipairs({ 'Functions', 'values' }) do
            for _, mode in ipairs({ 'nil', 'false', 'opaque', 'throw' }) do
                local f, a = fixture()
                local fn = assert(a.Functions.forecast).calculate
                local platform = a.Platform
                local opaque = {}
                f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
                local bad

                if mode == 'false' then
                    bad = false
                elseif mode == 'opaque' then
                    bad = opaque
                elseif mode == 'throw' then
                    bad = setmetatable({}, {
                        __index = function()
                            error('canonical namespace field failed')
                        end,
                    })
                end

                if key == 'Functions' then
                    a.Functions = bad
                else
                    a.Functions.values = bad
                end

                unknown(function()
                    return fn(platform, { damage = { { time = 97, value = 10 } }, heals = {} }, 10, false, false, 100)
                end)

                local rate, seconds = fn(platform, {}, 0, true, true, 100)
                assert(rate == 0 and seconds == 0, 'skipped streams consumed canonical round namespace')
            end
        end
    end
)

finish()
