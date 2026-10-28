local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Platform/communication.lua')
    f.load('Core/announcements.lua')
    f.env.MAXEMOTEINDEX = 1
    f.env.EMOTE1_TOKEN = 'CHEER'
    f.env.EMOTE1_CMD1 = '/cheer'
    return f.addon, f.env
end

test('automatic and explicit clicked emote observations stay separate and omit recipients', function()
    local a, e = fixture()
    local calls = 0

    e.C_ChatInfo = {
        PerformEmote = function(token, target)
            calls = calls + 1
            assert(token == 'CHEER')
            return false, nil
        end,
    }

    assert(
        a:DispatchAnnouncement({
            announce = 'gesture',
            emote = 'CHEER',
            emote_target = true,
        }, nil, 'Private-Healed').chat
    )

    assert(a:TestAnnouncementEmote().chat and calls == 2)
    local text = a:GetAnnouncementEmoteReport()
    assert(text:find('Automatic:', 1, true) and text:find('Explicit click test:', 1, true))

    assert(
        text:find('C_ChatInfo.PerformEmote', 1, true) and text:find('native returns=2', 1, true) and text:find(
            'first boolean=false',
            1,
            true
        )
    )

    assert(text:find('cast-recipient', 1, true) and not text:find('Private', 1, true), 'recipient escaped report')
    assert(text:find('does not prove visible output', 1, true), 'call completion is not acceptance')
end)

test('pre-native skips remain diagnosable without invoking an output API', function()
    local a, e = fixture()

    e.C_ChatInfo = {
        PerformEmote = function()
            error('must not run')
        end,
    }

    a:DispatchAnnouncement({ announce = 'gesture', emote = 'CHEER', emote_target = true }, nil, nil)
    assert(a:GetAnnouncementEmoteReport():find('cast-recipient-unavailable', 1, true))
    a:DispatchAnnouncement({ announce = 'gesture', emote = 'MISSING' }, nil)
    assert(a:GetAnnouncementEmoteReport():find('emote-unavailable', 1, true))
end)

test('emote exceptions never retry and opaque native returns never leak', function()
    local a, e = fixture()
    local other = 0

    e.C_ChatInfo = {
        PerformEmote = function()
            other = other + 1
        end,
    }

    e.DoEmote = function()
        error('Private failure text')
    end

    assert(not a:TestAnnouncementEmote().chat and other == 0)
    local text = a:GetAnnouncementEmoteReport()
    assert(text:find('api-error', 1, true) and not text:find('Private', 1, true))
    local secret = {}
    e.issecretvalue = function(v) return v == secret end
    e.DoEmote = function() return secret end
    a:TestAnnouncementEmote()
    text = a:GetAnnouncementEmoteReport()
    assert(text:find('unavailable', 1, true) and not text:find('table:', 1, true))
end)

test('newer reentrant automatic and test operations keep their own latest results', function()
    local a, e = fixture()
    local nested = false

    e.C_ChatInfo = {
        PerformEmote = function()
            if not nested then
                nested = true
                a:TestAnnouncementEmote()
                return true
            end

            return false
        end,
    }

    a:TestAnnouncementEmote()
    local text = a:GetAnnouncementEmoteReport()
    assert(text:find('first boolean=false', 1, true) and not text:find('first boolean=true', 1, true))
end)

finish()
