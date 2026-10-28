local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project, expansion, version, interface)
    local f = F.new(project or 11, expansion or 2)
    local a, e = f.addon, f.env

    local s = {
        class = 7,
        item = 123,
        classID = 16,
        subClassID = 7,
        count = 2,
        slots = { { true, 1, 9001, 1 }, { true, 2, nil, 1 } },
        calls = {},
    }

    e.GetBuildInfo = function() return version or '3.4.0', '1', '', interface or 30400 end

    local function call(key)
        s.calls[key] = (s.calls[key] or 0) + 1

        if s.throw == key then
            error('native ' .. key .. ' failed')
        end
    end

    e.UnitClass = function()
        call('class')
        return 'Shaman', 'SHAMAN', s.class
    end

    local instant = function()
        call('item')
        return s.item, 'Glyph', 'Shaman', '', 1, s.classID, s.subClassID
    end

    e.GetItemInfoInstant = instant
    e.C_Item = { GetItemInfoInstant = instant }

    e.GetNumGlyphSockets = function()
        call('count')
        return s.count
    end

    e.GetGlyphSocketInfo = function(slot)
        call('slot' .. slot)
        local tuple = s.slots[slot]

        if tuple then
            return unpack(tuple, 1, tuple.n or 6)
        end
    end

    f.load('Platform/glyphs.lua')
    return f, a.Platform, s
end

test(
    'owned instant metadata facade selects authoritative API and normalizes only readable item classification',
    function()
        local f, p, s = fixture()
        local record = assert(p:GetItemInfoInstant(123))
        assert(record.itemID == 123 and record.classID == 16 and record.subClassID == 7)
        record.classID = 1
        assert(p:GetItemInfoInstant(123).classID == 16)

        f.env.GetItemInfoInstant = function()
            error('modern failure must not fall back')
        end

        s.throw = 'item'
        local value, why = p:GetItemInfoInstant(123)
        assert(not value and why == 'api-error')
        f.env.C_Item = nil
        f.env.GetItemInfoInstant = function() return 123, 'Glyph', 'Shaman', '', 1, 16, 7 end
        assert(p:GetItemInfoInstant(123).subClassID == 7)
    end
)

test(
    'item and class guard rejects absent restricted malformed and mismatched metadata without guessing identity',
    function()
        local f, p, s = fixture()
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        for _, input in ipairs({ 0, -1, 1.5, math.huge, false, {}, opaque }) do
            assert(p:GetItemInfoInstant(input) == nil)
        end

        assert(p:GetItemInfoInstant(nil) == nil and not s.calls.item)
        s.item = 124
        assert(p:GetItemInfoInstant(123) == nil)
        s.item = 123

        for _, field in ipairs({ 'item', 'classID', 'subClassID' }) do
            local original = s[field]
            s[field] = opaque
            local _, why = p:GetItemInfoInstant(123)
            assert(why == 'restricted-value')
            s[field] = original
        end

        s.classID = nil
        assert(p:GetItemInfoInstant(123) == nil)
        s.classID = 16
        s.subClassID = -1
        assert(p:GetItemInfoInstant(123) == nil)
    end
)

test(
    'glyph item classification centralizes player class and explicit captured class while allowing source editing on retail',
    function()
        local _, p, s = fixture()
        local record = assert(p:GetGlyphItemInfo(123))
        assert(record.itemID == 123 and s.calls.class == 1)
        s.class = 8
        assert(p:GetGlyphItemInfo(123, 7).subClassID == 7 and s.calls.class == 1)
        assert(p:GetGlyphItemInfo(123) == nil)
        s.class = 7
        s.classID = 1
        local _, why = p:GetGlyphItemInfo(123, 7)
        assert(why == 'invalid-glyph-item')
        local _, retail = fixture(1, 12, '12.0.0', 120000)
        assert(retail:GetGlyphItemInfo(123).classID == 16)
    end
)

test(
    'glyph classification keeps missing and restricted class or item metadata unavailable without a loader substitute',
    function()
        local f, p, s = fixture()
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        for _, input in ipairs({ '123', {}, 0, opaque }) do
            assert(p:GetGlyphItemInfo(input) == nil)
        end

        s.class = nil
        local _, why = p:GetGlyphItemInfo(123)
        assert(why == 'class-data-unavailable')
        s.class = opaque
        _, why = p:GetGlyphItemInfo(123)
        assert(why == 'restricted-value')
        s.class = 7
        f.env.UnitClass = nil
        _, why = p:GetGlyphItemInfo(123)
        assert(why == 'missing-api')
        s.item = nil
        _, why = p:GetGlyphItemInfo(123, 7)
        assert(why == 'item-data-unavailable')
        s.item = 123
        s.classID = opaque
        _, why = p:GetGlyphItemInfo(123, 7)
        assert(why == 'restricted-value')
    end
)

test('verified Wrath and Cata Mists editions use their actual distinct socket spell positions', function()
    for _, case in ipairs({
        { 11, 2, '3.4.0', 30400, 3 },
        { 11, 2, '3.4.3', 30403, 3 },
        { 14, 3, '4.4.2', 40402, 4 },
        { 19, 4, '5.5.0', 50500, 4 },
        { 19, 4, '5.5.4', 50504, 4 },
    }) do
        local _, p, s = fixture(unpack(case))
        s.count = 1

        if case[5] == 4 then
            s.slots[1] = { true, 1, 2, 9001, 1, 1001 }
        end

        local snapshot = assert(p:GetGlyphSocketSnapshot())

        assert(
            snapshot.complete
                and snapshot.slots[1].active
                and snapshot.slots[1].spellID == 9001
                and s.calls.count == 1
                and s.calls.slot1 == 1
        )
    end
end)

test('unverified product edition build and future layouts never query glyph socket APIs', function()
    for _, case in ipairs({
        { 1, 12, '12.0.0', 120000 },
        { 2, 0, '1.15.9', 11509 },
        { 5, 1, '2.5.6', 20506 },
        { 18, 12, '1.60.1', 16001 },
        { 999, 4, '5.5.0', 50500 },
        { 11, 2, '4.4.2', 40402 },
        { 14, 3, '3.4.0', 30400 },
        { 19, 4, '5.6.0', 50600 },
        { 19, 4, '5.5.99', 50599 },
        { 19, 3, '5.5.0', 50500 },
    }) do
        local _, p, s = fixture(unpack(case))
        local record, why = p:GetGlyphSocketSnapshot()
        assert(record == nil and why == 'unsupported-glyph-layout' and next(s.calls) == nil)
    end

    local f, p, s = fixture()
    f.env.GetBuildInfo = nil
    assert(p:GetGlyphSocketSnapshot() == nil and next(s.calls) == nil)
end)

test('locked empty and zero sockets are complete while partial unknown slots retain explicit reasons', function()
    local _, p, s = fixture()
    s.slots = { { false, 1, 9001, 1 }, { true, 1, nil, 1 }, { nil, 1, nil, 1 } }
    s.count = 3
    local record = assert(p:GetGlyphSocketSnapshot())
    assert(record.complete and #record.slots == 3)

    for _, slot in ipairs(record.slots) do
        assert(slot.active == false and not slot.spellID)
    end

    s.slots[2] = {}
    record = p:GetGlyphSocketSnapshot()

    assert(
        not record.complete and record.slots[2].active == nil and record.slots[2].reason == 'glyph-socket-unavailable'
    )

    s.count = 0
    s.calls = {}
    record = p:GetGlyphSocketSnapshot()
    assert(record.complete and #record.slots == 0 and not s.calls.slot1)
end)

test('count missing malformed restricted and failed observations cannot pretend a complete scan', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ -1, 1.5, 65, math.huge, '2', {}, opaque }) do
        s.count = bad
        assert(p:GetGlyphSocketSnapshot() == nil)
    end

    s.count = nil
    assert(p:GetGlyphSocketSnapshot() == nil)
    s.count = 2
    s.throw = 'count'
    local _, why = p:GetGlyphSocketSnapshot()
    assert(why == 'api-error')
    f.env.GetNumGlyphSockets = nil
    _, why = p:GetGlyphSocketSnapshot()
    assert(why == 'missing-api' and not s.calls.slot1)
end)

test('socket unreadable malformed missing and failed tuples remain partial rather than silently empty', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.count = 1

    for _, tuple in ipairs({
        { opaque, 1, 9001 },
        { true, 1, opaque },
        { true, 1, 0 },
        { 1, 1, 9001 },
        { true, opaque, 9001 },
        { nil, nil, nil },
    }) do
        s.slots[1] = tuple
        local record = p:GetGlyphSocketSnapshot()
        assert(not record.complete and record.slots[1].active == nil)
    end

    s.throw = 'slot1'
    local record = p:GetGlyphSocketSnapshot()
    assert(record.slots[1].reason == 'api-error')
    s.throw = nil
    f.env.GetGlyphSocketInfo = nil
    local unavailable, why = p:GetGlyphSocketSnapshot()
    assert(unavailable == nil and why == 'missing-api')
end)

finish()
