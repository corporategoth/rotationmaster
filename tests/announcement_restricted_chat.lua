local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

test('saved Say and Yell never call protected chat while independent sound still works', function()
    local f = F.new()
    f.load('Platform/communication.lua')
    f.load('Core/announcements.lua')
    local a, e = f.addon, f.env
    local calls, sounds = 0, 0

    e.C_ChatInfo = {
        SendChatMessage = function()
            calls = calls + 1
        end,
    }

    e.SendChatMessage = function()
        calls = calls + 1
    end

    e.PlaySoundFile = function()
        sounds = sounds + 1
        return true
    end

    f.libraries['LibSharedMedia-3.0'] = { Fetch = function() return 'sound.ogg' end }

    for _, mode in ipairs({ 'say', 'yell' }) do
        local entry = {
            type = 'spell',
            spell = 547,
            event = 'START',
            announce = mode,
            value = 'Saved text',
            announce_sound = 'Chime',
        }

        assert(a:IsValidAnnouncement(entry), 'saved entry must remain loadable')
        local r = a:DispatchAnnouncement(entry, 'Saved text')
        assert(not r.chat and r.chatReason == 'hardware-event-required' and r.sound)
        assert(entry.announce == mode and entry.value == 'Saved text', 'must not rewrite saved configuration')
    end

    assert(calls == 0 and sounds == 2)
end)

finish()
