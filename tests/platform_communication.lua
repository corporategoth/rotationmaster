-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Platform/communication.lua')
    return f, f.addon.Platform
end

test('native chat sender is preferred without a second send on failure', function()
    local f, p = fixture()
    local native, legacy = 0, 0

    f.env.C_ChatInfo = {
        SendChatMessage = function(text, channel)
            assert(text == 'Hello' and channel == 'RAID')
            native = native + 1
        end,
    }

    f.env.SendChatMessage = function()
        legacy = legacy + 1
    end

    assert(p:SendAnnouncementChat('Hello', 'RAID'))
    assert(native == 1 and legacy == 0)

    f.env.C_ChatInfo.SendChatMessage = function()
        native = native + 1
        error('restricted')
    end

    local ok, why = p:SendAnnouncementChat('Hello', 'RAID')
    assert(not ok and why == 'api-error' and native == 2 and legacy == 0)
    f.env.C_ChatInfo.SendChatMessage = false
    assert(p:SendAnnouncementChat('Hello', 'RAID') and legacy == 1)
    f.env.SendChatMessage = nil
    ok, why = p:SendAnnouncementChat('Hello', 'RAID')
    assert(not ok and why == 'missing-api')
end)

test('chat arguments must be public text and an explicit supported destination', function()
    local f, p = fixture()
    local sends = 0

    f.env.SendChatMessage = function()
        sends = sends + 1
    end

    local secret = {}
    f.env.issecretvalue = function(v) return v == secret end

    for _, args in ipairs({
        { secret, 'RAID' },
        { 'Hi', secret },
        { 123, 'RAID' },
        { 'Hi', 'WHISPER' },
        { 'Hi', '' },
        { false, 'RAID' },
    }) do
        assert(not p:SendAnnouncementChat(unpack(args)))
    end

    assert(sends == 0)
end)

test('group status uses public modern leader and assistant observations', function()
    local f, p = fixture()
    f.env.IsInRaid = function() return true end

    f.env.IsInGroup = function()
        error('redundant query')
    end

    f.env.UnitIsGroupLeader = function(unit)
        assert(unit == 'player')
        return false
    end

    f.env.UnitIsGroupAssistant = function(unit)
        assert(unit == 'player')
        return true
    end

    local g = assert(p:GetAnnouncementGroup())
    assert(g.inRaid and g.inGroup and not g.isLeader and g.isAssistant)
    g.isAssistant = false
    assert(p:GetAnnouncementGroup().isAssistant, 'mutable context escaped')
    f.env.IsInRaid = function() return false end
    f.env.IsInGroup = function() return false end

    f.env.UnitIsGroupLeader = function()
        error('solo permissions queried')
    end

    g = assert(p:GetAnnouncementGroup())
    assert(not g.inRaid and not g.inGroup)
    f.env.IsInGroup = function() return true end
    g = assert(p:GetAnnouncementGroup())
    assert(g.inGroup and not g.inRaid)
end)

test('unknown membership stays unknown while unavailable permission does not erase a known raid', function()
    local f, p = fixture()
    local secret = {}
    f.env.issecretvalue = function(v) return v == secret end

    for _, fn in ipairs({
        function()
            error('blocked')
        end,
        function() return secret end,
        function() return 1 end,
        function() end,
    }) do
        f.env.IsInRaid = fn
        assert(not p:GetAnnouncementGroup())
    end

    f.env.IsInRaid = nil
    assert(not p:GetAnnouncementGroup())
    f.env.IsInRaid = function() return false end
    f.env.IsInGroup = nil
    assert(not p:GetAnnouncementGroup())
    f.env.IsInRaid = function() return true end
    f.env.UnitIsGroupLeader = function() return secret end

    f.env.UnitIsGroupAssistant = function()
        error('blocked')
    end

    local g = assert(p:GetAnnouncementGroup())
    assert(g.inRaid and g.isLeader == nil and g.isAssistant == nil)
end)

test('legacy raid-leader fallback has no unit argument and is never retried after native failure', function()
    local f, p = fixture()
    f.env.IsInRaid = function() return true end
    local calls = 0

    -- No current client has IsRaidLeader (UnitIsGroupLeader everywhere): an older build, past the guard.
    rawset(f.env, 'IsRaidLeader', function(...)
        assert(select('#', ...) == 0, 'legacy leader received a unit')
        calls = calls + 1
        return true
    end)

    local g = assert(p:GetAnnouncementGroup())
    assert(g.isLeader == true and calls == 1)

    f.env.UnitIsGroupLeader = function()
        error('restricted')
    end

    g = assert(p:GetAnnouncementGroup())
    assert(g.isLeader == nil and calls == 1)
end)

finish()
