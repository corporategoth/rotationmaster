-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    f.env.BOOKTYPE_SPELL = 'spell'
    f.env.BOOKTYPE_PET = 'pet'
    f.env.GetNumTotemSlots = function() return 4 end
    f.env.GetTotemInfo = function() return false, '', 0, 0, 0 end

    f.env.C_Spell = {
        GetSpellInfo = function(id)
            if id == 8071 or id == 8154 then
                return { spellID = id, name = 'Stoneskin Totem', subtext = id == 8071 and 'Rank 1' or 'Rank 2' }
            end
            if id == 5394 then
                return { spellID = id, name = 'Healing Stream Totem' }
            end
        end,
    }

    local compress = f.libraries.LibCompress
    compress.fcs16init = function() return '' end
    compress.fcs16update = function(_, hash, value) return hash .. value .. '|' end
    compress.fcs16final = function(_, hash) return hash end

    for _, path in ipairs({
        'Platform/client.lua',
        'Platform/spells.lua',
        'Platform/totems.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/totem.lua',
    }) do
        f.load(path)
    end

    return f
end

local function value(tag, spell, amount, ranked)
    return { type = tag, spell = spell, ranked = ranked, operator = 'LESSTHAN', value = amount }
end

test('totem adapters preserve observed empty slots and normalize modern and legacy tuple shapes', function()
    local f = fixture()
    local p = f.addon.Platform
    assert(p:GetTotemSlotCount() == 4)
    assert(p:GetTotemInfo(1).active == false)

    f.env.GetTotemInfo = function(slot)
        assert(slot == 2)
        return true, 'Stoneskin Totem', 90, 120, 136098, 2, 8071
    end

    local info = p:GetTotemInfo(2)

    assert(
        info.active
            and info.name == 'Stoneskin Totem'
            and info.startTime == 90
            and info.duration == 120
            and info.modRate == 2
            and info.spellID == 8071
    )

    info.name = 'edited'
    assert(p:GetTotemInfo(2).name == 'Stoneskin Totem')
    f.env.GetTotemInfo = function() return true, 'Stoneskin Totem', 0, 120, 136098 end
    info = p:GetTotemInfo(2)
    assert(info.active and info.modRate == 1 and info.spellID == nil, 'legacy active timer starting at zero was lost')
    f.env.GetTotemInfo = function() return true, '', 0, 0, 0 end
    assert(not p:GetTotemInfo(2).active, 'slot capability with zero duration is not active')
end)

test(
    'missing secret throwing and malformed observations remain unavailable and invalid requests do not call the API',
    function()
        local f = fixture()
        local p = f.addon.Platform
        local calls = 0

        f.env.GetTotemInfo = function()
            calls = calls + 1
        end

        for _, slot in ipairs({ 0, -1, 1.5, 65, '1', math.huge }) do
            assert(p:GetTotemInfo(slot) == nil)
        end

        assert(calls == 0)
        assert(p:GetTotemInfo(1) == nil)

        f.env.GetTotemInfo = function()
            error('native error')
        end

        assert(p:GetTotemInfo(1) == nil)
        local opaque = {}
        f.env.canaccessvalue = function(v) return v ~= opaque end

        for _, record in ipairs({
            { opaque, '', 0, 0, 0 },
            { true, opaque, 90, 120, 1 },
            { true, 'Totem', opaque, 120, 1 },
            { true, 'Totem', 90, -1, 1 },
            { true, 'Totem', 90, 120, 1, 0 },
            { true, 'Totem', 90, 120, 1, 1, opaque },
        }) do
            f.env.GetTotemInfo = function() return unpack(record) end
            assert(p:GetTotemInfo(1) == nil)
        end

        for _, count in ipairs({ -1, 65, math.huge, 1.5, '4', opaque }) do
            f.env.GetNumTotemSlots = function() return count end
            assert(p:GetTotemSlotCount() == nil)
        end
    end
)

test('all four predicates preserve unknown under NOT and reject malformed saved fields before API calls', function()
    local f = fixture()
    local a = f.addon
    f.env.GetTotemInfo = function() return nil end

    for _, v in ipairs({
        value('TOTEM', 1),
        value('TOTEM_REMAIN', 1, 5),
        value('TOTEM_SPELL', 8071),
        value('TOTEM_SPELL_REMAIN', 8071, 5),
    }) do
        assert(
            a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable',
            v.type .. ' promoted missing data'
        )
    end

    f.env.GetTotemInfo = function()
        error('invalid condition called native API')
    end

    for _, v in ipairs({
        value('TOTEM', 1.5),
        value('TOTEM', 0),
        value('TOTEM_SPELL', -1),
        value('TOTEM_REMAIN', 1, '5'),
        value('TOTEM_REMAIN', 1, math.huge),
        value('TOTEM_SPELL_REMAIN', 8071, -1),
    }) do
        assert(not a:validateCondition(v, 0), v.type .. ' accepted malformed saved fields')
    end
end)

test('specific remaining time compares seconds to the requested amount and requires an active totem', function()
    local f = fixture()
    local a = f.addon

    f.env.GetTotemInfo = function(slot)
        if slot == 2 then
            return true, 'Stoneskin Totem', 90, 15, 136098, 2, 8071
        end

        return false, '', 0, 0, 0
    end

    assert(a:evaluateCondition(value('TOTEM', 2)))
    assert(a:evaluateCondition(value('TOTEM_REMAIN', 2, 6)))
    assert(a:evaluateCondition(value('TOTEM_SPELL', 8071)))
    assert(a:evaluateCondition(value('TOTEM_SPELL_REMAIN', 8071, 6)))
    assert(not a:evaluateCondition(value('TOTEM_SPELL_REMAIN', 8071, 4)))
    f.env.GetTime = function() return 105 end

    for _, v in ipairs({
        value('TOTEM', 2),
        value('TOTEM_REMAIN', 2, 6),
        value('TOTEM_SPELL', 8071),
        value('TOTEM_SPELL_REMAIN', 8071, 6),
    }) do
        assert(not a:evaluateCondition(v), v.type .. ' matched an expired totem')
    end
end)

test('specific ranks use observed IDs and name-only legacy ranks remain explicitly unavailable', function()
    local f = fixture()
    local a = f.addon

    f.env.GetTotemInfo = function(slot)
        if slot == 1 then
            return true, 'Stoneskin Totem', 90, 120, 136098, 1, 8154
        end

        return false, '', 0, 0, 0
    end

    assert(a:evaluateCondition(value('TOTEM_SPELL', 8071)))
    assert(not a:evaluateCondition(value('TOTEM_SPELL', 8071, nil, true)))
    assert(a:evaluateCondition(value('TOTEM_SPELL', 8154, nil, true)))

    f.env.GetTotemInfo = function(slot)
        if slot == 1 then
            return true, 'Stoneskin Totem', 90, 120, 136098
        end

        return false, '', 0, 0, 0
    end

    assert(a:evaluateCondition(value('TOTEM_SPELL', 8071)))

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = value('TOTEM_SPELL', 8071, nil, true) }).status
            == 'unavailable'
    )
end)

test('a definite match can survive an unknown different slot but absence needs a complete scan', function()
    local f = fixture()
    local a = f.addon
    local calls = {}

    f.env.GetTotemInfo = function(slot)
        calls[slot] = (calls[slot] or 0) + 1

        if slot == 1 then
            return nil
        end
        if slot == 4 then
            return true, 'Stoneskin Totem', 90, 120, 136098, 1, 8071
        end

        return false, '', 0, 0, 0
    end

    local v = value('TOTEM_SPELL', 8071)
    assert(a:evaluateCondition({ type = 'AND', value = { v, v } }))

    for _, count in pairs(calls) do
        assert(count == 1, 'observations were not reused inside one evaluation')
    end

    assert(a:evaluateConditionResult({ type = 'NOT', value = value('TOTEM_SPELL', 5394) }).status == 'unavailable')
    f.env.GetNumTotemSlots = function() return 5 end

    f.env.GetTotemInfo = function(slot)
        if slot == 5 then
            return true, 'Healing Stream Totem', 90, 120, 1, 1, 5394
        end

        return false, '', 0, 0, 0
    end

    assert(a:evaluateCondition(value('TOTEM_SPELL', 5394)), 'specific scan assumed four native slots')
end)

test('an active unidentified legacy totem cannot prove that an exact rank is absent', function()
    local f = fixture()
    local a = f.addon

    f.env.GetTotemInfo = function(slot)
        if slot == 1 then
            return true, '', 90, 120, 1
        end

        return false, '', 0, 0, 0
    end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = value('TOTEM_SPELL', 8071, nil, true) }).status
            == 'unavailable'
    )
end)

test('an observed zero slot count is an empty complete specific-totem scan', function()
    local f = fixture()
    local a = f.addon
    f.env.GetNumTotemSlots = function() return 0 end

    f.env.GetTotemInfo = function()
        error('zero available slots must not be queried')
    end

    assert(a.Platform:GetTotemSlotCount() == 0)
    assert(a:evaluateConditionResult(value('TOTEM_SPELL', 8071)).status == 'no-match')
    assert(a:evaluateCondition({ type = 'NOT', value = value('TOTEM_SPELL', 8071) }))
end)

finish()
