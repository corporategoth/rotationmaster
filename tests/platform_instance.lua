local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local e = f.env
    local s = { inside = true, kind = 'party', calls = 0 }

    e.IsInInstance = function(...)
        assert(select('#', ...) == 0, 'instance native received a receiver or arguments')
        s.calls = s.calls + 1

        if s.throw then
            error('native instance failure')
        end

        return s.inside, s.kind
    end

    for _, name in ipairs({ 'IsOutdoors', 'GetZonePVPInfo', 'UnitExists', 'UnitGUID' }) do
        e[name] = function()
            error('unexpected instance inference')
        end
    end

    local file = io.open('Platform/instance.lua')

    if file then
        file:close()
        f.load('Platform/instance.lua')
    end

    return f, f.addon.Platform, s
end

local function observe(p)
    assert(type(p.GetInstanceObservation) == 'function', 'owned instance observer missing')
    return p:GetInstanceObservation()
end

local function unavailable(p, reason)
    local record, why = observe(p)
    assert(record == nil and why == reason, tostring(why) .. ' expected ' .. reason)
end

test('all identified families observe exactly one native tuple with empty and future strings preserved', function()
    for _, project in ipairs({ 1, 18, 2, 5, 11, 14, 19 }) do
        local f, p, s = fixture(project)
        assert(s.calls == 0)

        for _, kind in ipairs({ 'none', 'party', 'raid', 'pvp', 'arena', 'scenario', '', 'future-kind' }) do
            s.kind = kind
            local record, why = observe(p)

            assert(
                record.inInstance == true
                    and record.instanceType == kind
                    and record.instanceTypeReason == nil
                    and why == nil
            )

            local nextRecord = observe(p)
            assert(nextRecord ~= record, 'direct observations reused a mutable record')
        end

        assert(s.calls == 16 and next(f.addon.longtermCache) == nil)
    end
end)

test('unknown families stop before querying even when the native exists', function()
    local _, p, s = fixture(999)
    unavailable(p, 'unsupported-policy')
    assert(s.calls == 0)
    p.GetClientInfo = function() return { family = 'future' } end
    unavailable(p, 'unsupported-policy')
    assert(s.calls == 0)
end)

test('primary Boolean is required readable and strict before any interpretation', function()
    local f, p, s = fixture()
    s.inside = nil
    unavailable(p, 'instance-data-unavailable')

    for _, bad in ipairs({ 0, 1, 'true', {} }) do
        s.inside = bad
        unavailable(p, 'invalid-api-result')
    end

    s.inside = true
    s.throw = true
    unavailable(p, 'api-error')
    s.throw = nil
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.inside = opaque
    unavailable(p, 'restricted-value')
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    unavailable(p, 'restricted-value')
    f.env.IsInInstance = nil
    unavailable(p, 'missing-api')
    f.env.IsInInstance = function() return end
    f.env.issecretvalue = nil
    unavailable(p, 'instance-data-unavailable')
end)

test('outside status ignores and never retains an unreadable secondary value', function()
    local f, p, s = fixture()
    local opaque = {}
    s.inside = false
    s.kind = opaque

    f.env.canaccessvalue = function(v)
        assert(not rawequal(v, opaque), 'ignored instance type was inspected')
        return true
    end

    local record, why = observe(p)
    assert(record.inInstance == false and why == nil)
    local count = 0

    for key in pairs(record) do
        count = count + 1
        assert(key == 'inInstance')
    end

    assert(count == 1)
end)

test('inside status retains partial type reasons without leaking native values', function()
    local f, p, s = fixture()
    s.kind = nil
    local record, why = observe(p)

    assert(
        record.inInstance == true
            and record.instanceType == nil
            and record.instanceTypeReason == 'instance-type-unavailable'
            and why == nil
    )

    for _, bad in ipairs({ false, true, 0, {} }) do
        s.kind = bad
        record, why = observe(p)

        assert(
            record.inInstance == true
                and record.instanceType == nil
                and record.instanceTypeReason == 'invalid-api-result'
                and why == nil
        )
    end

    local opaque = {}
    s.kind = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    record = observe(p)
    assert(record.inInstance == true and record.instanceType == nil and record.instanceTypeReason == 'restricted-value')
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    record = observe(p)
    assert(record.instanceTypeReason == 'restricted-value')
end)

test('readability precedes nil false and type tests and current native replacement recovers', function()
    local f, p, s = fixture()
    f.env.canaccessvalue = function(v) return v ~= nil end
    s.inside = nil
    unavailable(p, 'restricted-value')
    f.env.canaccessvalue = function(v) return v ~= false end
    s.inside = false
    unavailable(p, 'restricted-value')
    f.env.canaccessvalue = nil

    f.env.IsInInstance = function(...)
        assert(select('#', ...) == 0)
        return true, 'future'
    end

    assert(observe(p).instanceType == 'future')
    f.env.IsInInstance = function() return false end
    assert(observe(p).inInstance == false)
end)

finish()
