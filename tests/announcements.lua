-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Platform/communication.lua')
    f.load('Core/announcements.lua')
    local observed = { chat = {}, localText = {}, sounds = {} }
    local e = f.env
    e.IsInRaid = function() return false end
    e.IsInGroup = function() return false end
    e.UnitIsGroupLeader = function() return false end
    e.UnitIsGroupAssistant = function() return false end

    e.C_ChatInfo = {
        SendChatMessage = function(text, destination)
            observed.chat[#observed.chat + 1] = { text = text, destination = destination }
        end,
    }

    f.addon.announce = function(_, text)
        observed.localText[#observed.localText + 1] = text
    end

    e.PlaySoundFile = function(path, channel)
        assert(channel == 'Master')
        observed.sounds[#observed.sounds + 1] = path
        return true
    end

    f.libraries['LibSharedMedia-3.0'] = {
        Fetch = function(_, kind, key, silent)
            assert(kind == 'sound' and key == 'Chime' and silent)
            return 'chime.ogg'
        end,
    }

    return f, observed
end

test('routing preserves solo party raid and permitted warning choices', function()
    local f, o = fixture()
    local a = f.addon
    local e = f.env
    a:DispatchAnnouncement({ announce = 'partyraid' }, 'solo')
    a:DispatchAnnouncement({ announce = 'party' }, 'skipped')
    a:DispatchAnnouncement({ announce = 'raidwarn' }, 'solo warning')
    assert(#o.localText == 2 and #o.chat == 0)
    e.IsInGroup = function() return true end

    for _, mode in ipairs({ 'partyraid', 'party', 'raidwarn' }) do
        a:DispatchAnnouncement({ announce = mode }, mode)
    end

    for _, entry in ipairs(o.chat) do
        assert(entry.destination == 'PARTY')
    end

    e.IsInRaid = function() return true end
    a:DispatchAnnouncement({ announce = 'partyraid' }, 'raid')
    a:DispatchAnnouncement({ announce = 'raidwarn' }, 'member')
    assert(o.chat[4].destination == 'RAID' and o.chat[5].destination == 'RAID')
    e.UnitIsGroupAssistant = function() return true end
    a:DispatchAnnouncement({ announce = 'raidwarn' }, 'assistant')
    assert(o.chat[6].destination == 'RAID_WARNING')
    e.UnitIsGroupAssistant = function() return false end
    e.UnitIsGroupLeader = function() return true end
    a:DispatchAnnouncement({ announce = 'raidwarn' }, 'leader')
    assert(o.chat[7].destination == 'RAID_WARNING')
    a:DispatchAnnouncement({ announce = 'party' }, 'subgroup')
    assert(o.chat[8].destination == 'PARTY')
end)

test('direct local and saved legacy destinations do not need group APIs', function()
    local f, o = fixture()
    local a = f.addon

    f.env.IsInRaid = function()
        error('should not be queried')
    end

    a:DispatchAnnouncement({ announce = 'local' }, 'local')

    for _, mode in ipairs({ 'say', 'yell', 'emote' }) do
        a:DispatchAnnouncement({ announce = mode }, mode)
    end

    assert(o.localText[1] == 'local' and #o.chat == 1)
    assert(o.chat[1].destination == 'EMOTE')
    a:DispatchAnnouncement({ announce = 'unknown' }, 'bad')
    a:DispatchAnnouncement({ announce = 'none' }, 'none')
    assert(#o.chat == 1 and #o.localText == 1)
end)

test('unknown group membership never guesses a destination', function()
    local f, o = fixture()

    f.env.IsInRaid = function()
        error('unavailable')
    end

    for _, mode in ipairs({ 'partyraid', 'party', 'raidwarn' }) do
        local result = f.addon:DispatchAnnouncement({ announce = mode }, 'unknown')
        assert(not result.chat)
    end

    assert(#o.chat == 0 and #o.localText == 0)
    f.env.IsInRaid = function() return true end
    f.env.UnitIsGroupLeader = nil
    f.env.UnitIsGroupAssistant = nil
    f.addon:DispatchAnnouncement({ announce = 'raidwarn' }, 'known raid')
    assert(o.chat[1].destination == 'RAID')
end)

test('sound is independent of chat and audible mode never emits chat', function()
    local f, o = fixture()
    local a = f.addon
    local result = a:DispatchAnnouncement({ announce = 'audible', announce_sound = 'Chime' }, nil)
    assert(result.sound and not result.chat and #o.sounds == 1 and #o.chat == 0 and #o.localText == 0)
    result = a:DispatchAnnouncement({ announce = 'local', announce_sound = 'Chime' }, 'both')
    assert(result.sound and result.chat and #o.sounds == 2 and o.localText[1] == 'both')

    f.env.C_ChatInfo.SendChatMessage = function()
        error('restricted')
    end

    result = a:DispatchAnnouncement({ announce = 'emote', announce_sound = 'Chime' }, 'blocked')
    assert(not result.chat and result.sound and #o.sounds == 3)

    f.env.PlaySoundFile = function()
        error('audio failure')
    end

    result = a:DispatchAnnouncement({ announce = 'local', announce_sound = 'Chime' }, 'still local')
    assert(result.chat and not result.sound and #o.localText == 2)
end)

test('missing malformed or restricted sound observations are unavailable without raising', function()
    local f, o = fixture()
    local a = f.addon
    local secret = {}
    f.env.issecretvalue = function(value) return value == secret end

    for _, fetch in ipairs({
        function()
            error('bad media')
        end,
        function() return secret end,
        function() return false end,
        function() return math.huge end,
        function() return -1 end,
    }) do
        f.libraries['LibSharedMedia-3.0'] = { Fetch = fetch }
        assert(not a:DispatchAnnouncement({ announce = 'audible', announce_sound = 'Chime' }, 'unused').sound)
    end

    f.libraries['LibSharedMedia-3.0'] = nil
    assert(not a:DispatchAnnouncement({ announce = 'audible', announce_sound = 'Chime' }, 'unused').sound)
    f.libraries['LibSharedMedia-3.0'] = 123
    assert(not a:DispatchAnnouncement({ announce = 'audible', announce_sound = 'Chime' }, 'unused').sound)
    assert(#o.sounds == 0)
    f.env.PlaySoundFile = nil
    assert(not a:DispatchAnnouncement({ announce = 'audible', announce_sound = 'Chime' }, nil).sound)
    assert(not a:DispatchAnnouncement({ announce = 'local' }, secret).chat and #o.localText == 0)
end)

finish()
