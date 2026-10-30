-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(raid)
    local f = F.new()
    local p, e = f.addon.Platform, f.env
    f.load('Platform/groups.lua')
    e.IsInGroup = function() return true end
    e.IsInRaid = function() return raid == true end
    local roster = { player = { 'Self', 'Realm' }, party1 = { 'Healed', 'Realm' }, party2 = { 'Other', 'Elsewhere' } }

    if raid then
        roster = { raid1 = { 'Self', 'Realm' }, raid2 = { 'Healed', 'Realm' } }
    end

    e.UnitExists = function(unit) return roster[unit] ~= nil end

    e.UnitName = function(unit)
        local v = roster[unit]

        if v then
            return v[1], v[2]
        end
    end

    e.UnitGUID = function(unit) return roster[unit] and 'guid-' .. unit end
    local calls = {}

    p.GetUnitGroupMembership = function(_, unit, only)
        calls[#calls + 1] = { unit, only }
        return true
    end

    f.load('Platform/announcement_recipient.lua')
    return f, p, e, roster, calls
end

test('event name resolves to party token and never the selected target', function()
    local _, p, e, _, calls = fixture()
    local old = e.UnitName

    e.UnitName = function(unit)
        assert(unit ~= 'target')
        return old(unit)
    end

    assert(p:GetAnnouncementRecipientGroupMembership('Healed-Realm', false) == true and calls[1][1] == 'party1')
    assert(p:GetAnnouncementRecipientGroupMembership('Healed', false) == true and calls[2][1] == 'party1')
    assert(p:GetAnnouncementRecipientGroupMembership('Stranger-Realm', false) == false and #calls == 2)
end)

test('raid token resolves and raid-only party query is false without native recipient query', function()
    local _, p, _, _, calls = fixture(true)

    assert(
        p:GetAnnouncementRecipientGroupMembership('Healed-Realm', true) == true
            and calls[1][1] == 'raid2'
            and calls[1][2]
    )

    local _, party, _, _, pcalls = fixture()
    assert(party:GetAnnouncementRecipientGroupMembership('Healed', true) == false and #pcalls == 0)
end)

test('missing restricted ambiguous or incomplete recipient stays unavailable including under NOT', function()
    local f, p, e, roster, calls = fixture()
    assert(p:GetAnnouncementRecipientGroupMembership(nil, false) == nil)
    local secret = {}
    e.issecretvalue = function(v) return v == secret end
    assert(p:GetAnnouncementRecipientGroupMembership(secret, false) == nil)
    roster.party2 = { 'Healed', 'Elsewhere' }
    assert(p:GetAnnouncementRecipientGroupMembership('Healed', false) == nil and #calls == 0)
    assert(p:GetAnnouncementRecipientGroupMembership('Healed-Realm', false) == true)
    roster.party2 = { secret, 'Realm' }
    assert(p:GetAnnouncementRecipientGroupMembership('Healed-Realm', false) == nil)
end)

test('roster replacement or native API replacement during membership query retires resolution', function()
    local _, p, e, roster = fixture()

    p.GetUnitGroupMembership = function()
        roster.party1 = { 'Changed', 'Realm' }
        return true
    end

    assert(p:GetAnnouncementRecipientGroupMembership('Healed-Realm', false) == nil)
    local _, p2, e2 = fixture()

    p2.GetUnitGroupMembership = function()
        e2.UnitName = function() return 'Healed', 'Realm' end
        return true
    end

    assert(p2:GetAnnouncementRecipientGroupMembership('Healed-Realm', false) == nil)
end)

test('actual GROUP announcement context uses roster tokens and unavailable stays unavailable under NOT', function()
    local f, p, e, roster, calls = fixture()
    local a = f.addon
    f.load('Platform/groups.lua')

    e.UnitInParty = function(unit)
        assert(unit == 'party1', 'native membership received a name or selected target')
        return true
    end

    e.UnitInRaid = function() return nil end

    for _, path in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Core/conditions.lua',
        'Core/announcements.lua',
        'Conditions/character.lua',
    }) do
        f.load(path)
    end

    local node = { type = 'GROUP', unit = 'spellrecipient' }
    assert(a:AnnouncementConditionMatches({ conditions = node }, 'Healed-Realm'))
    assert(a:evaluateConditionResult(node).status == 'unavailable', 'normal rotation must have no event context')
    assert(not a:AnnouncementConditionMatches({ conditions = { type = 'NOT', value = node } }, nil))
    roster.party2 = { 'Healed', 'Other' }
    assert(not a:AnnouncementConditionMatches({ conditions = { type = 'NOT', value = node } }, 'Healed'))
end)

finish()
