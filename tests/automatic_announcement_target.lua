local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function fixture()
    local f = F.new()
    local a, e = f.addon, f.env

    for _, path in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Data/validation.lua',
        'Core/conditions.lua',
        'Core/announcements.lua',
    }) do
        f.load(path)
    end

    local units = {
        player = { 'Self', 'Realm', 'Player-1' },
        target = { 'Other', 'Realm', 'Player-2' },
        mouseover = { 'Healed', 'Realm', 'Player-3' },
    }

    local function lookup(unit)
        if units[unit] then
            return units[unit]
        end

        for _, row in pairs(units) do
            if unit == row[1] or unit == row[1] .. '-' .. row[2] then
                return row
            end
        end
    end

    e.UnitExists = function(unit) return lookup(unit) ~= nil end

    e.UnitName = function(unit)
        local row = units[unit]

        if row then
            return row[1], row[2]
        end
    end

    e.UnitGUID = function(unit)
        local row = lookup(unit)
        return row and row[3]
    end

    a:RegisterCondition('UNIT', {
        fields = { unit = 'string' },
        valid = function(_, v) return a.units[v.unit] ~= nil end,
        evaluate = function(v) return v.unit == 'Healed-Realm' or v.unit == 'mouseover' end,
    })

    return f, a, units
end

test('automatic announcement target resolves exact spell recipient instead of selected target', function()
    local _, a = fixture()
    local tree = { type = 'UNIT', unit = 'announcementtarget' }
    assert(a:AnnouncementConditionMatches({ type = 'spell', conditions = tree }, 'Healed-Realm'))
    assert(tree.unit == 'announcementtarget' and a.units.announcementtarget == nil)
    assert(not a:AnnouncementConditionMatches({ type = 'spell', conditions = tree }, 'Other-Realm'))
end)

test('absent or rebound automatic recipients never match under NOT', function()
    local _, a, units = fixture()
    local node = { type = 'NOT', value = { type = 'UNIT', unit = 'announcementtarget' } }
    assert(not a:AnnouncementConditionMatches({ type = 'spell', conditions = node }, nil))
    assert(not a:AnnouncementConditionMatches({ type = 'spell', conditions = node }, 'Missing-Realm'))

    a.conditionDefinitions.UNIT.evaluate = function()
        units.mouseover = { 'Rebound', 'Realm', 'Player-5' }
        return false
    end

    assert(not a:AnnouncementConditionMatches({ type = 'spell', conditions = node }, 'Healed-Realm'))
end)

test('automatic recipient lookup is lazy and ordinary or macro unit behavior stays fresh', function()
    local f, a = fixture()
    local n = 0
    local exists = f.env.UnitExists

    f.env.UnitExists = function(unit)
        n = n + 1
        return exists(unit)
    end

    local alias = { type = 'UNIT', unit = 'announcementtarget' }

    assert(
        a:AnnouncementConditionMatches({
            type = 'spell',
            conditions = { type = 'OR', value = { { type = 'UNIT', unit = 'mouseover' }, alias } },
        }, 'Healed-Realm') and n == 0
    )

    assert(a:AnnouncementConditionMatches({ type = 'macro', conditions = alias }, 'Healed-Realm', nil, 'mouseover'))
    assert(not a:AnnouncementConditionMatches({ type = 'macro', conditions = alias }, 'Healed-Realm'))
    assert(a:evaluateConditionResult(alias).status == 'unavailable')
end)

test('actual cast events apply contextual conditions to that cast recipient only', function()
    local prefix = assert(read('tests/announcement_conditions_events.lua'):match('^(.-)\ntest%('))
    local f, a, outputs = assert(loadstring(prefix .. '\nreturn fixture()', '@automatic-announcement-events'))()
    local e = f.env

    e.UnitExists = function(unit)
        return unit == 'player' or unit == 'target' or unit == 'mouseover' or unit == 'Clickcast-Realm'
    end

    e.UnitName = function(unit)
        return unit == 'mouseover' and 'Clickcast' or unit == 'player' and 'Self' or 'Other', 'Realm'
    end

    e.UnitGUID = function(unit) return 'guid-' .. unit end

    a:RegisterCondition('UNIT', {
        fields = { unit = 'string' },
        valid = function(_, v) return a.units[v.unit] ~= nil end,
        evaluate = function(v) return v.unit == 'Clickcast-Realm' end,
    })

    a.db.profile.announces[1].conditions = { type = 'UNIT', unit = 'announcementtarget' }
    a:UNIT_SPELLCAST_SENT('UNIT_SPELLCAST_SENT', 'player', 'Clickcast-Realm', 'cast-1', 547)
    a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START', 'player', 'cast-1', 547)
    assert(#outputs == 1)
    a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START', 'player', 'cast-2', 547)
    assert(#outputs == 1, 'prior recipient leaked')
end)

test('automatic Group alias still resolves party recipient after mouseover has moved away', function()
    local f, a = fixture()
    local e = f.env
    f.load('Platform/announcement_recipient.lua')
    f.load('Conditions/character.lua')
    e.IsInGroup = function() return true end
    e.IsInRaid = function() return false end
    e.UnitExists = function(unit) return unit == 'player' or unit == 'party1' or unit == 'PartyHeal-Realm' end
    e.UnitName = function(unit) return unit == 'party1' and 'PartyHeal' or 'Self', 'Realm' end
    e.UnitGUID = function(unit) return 'guid-' .. unit end
    e.UnitInParty = function(unit) return unit == 'party1' end
    e.UnitInRaid = function() return nil end

    assert(a:AnnouncementConditionMatches({
        type = 'spell',
        conditions = { type = 'GROUP', unit = 'announcementtarget' },
    }, 'PartyHeal-Realm'))
end)

test('Dead/Ghost validates announcement alias and observes the recorded recipient name', function()
    local f, a = fixture()
    f.load('Platform/unit_states.lua')
    f.load('Conditions/unit_states.lua')

    f.env.UnitIsDeadOrGhost = function(unit)
        assert(unit == 'Healed-Realm')
        return true
    end

    local node = { type = 'DEAD', unit = 'announcementtarget' }
    assert(a:validateAnnouncementCondition(node, 0) and not a:validateCondition(node, 0))
    assert(a:AnnouncementConditionMatches({ type = 'spell', conditions = node }, 'Healed-Realm'))
    assert(a.units.announcementtarget == nil and a:evaluateConditionResult(node).status == 'unavailable')

    a:RegisterCondition('ENEMY', {
        fields = { unit = 'string' },
        valid = function() return true end,
        evaluate = function() return false end,
    })

    assert(
        not a:AnnouncementConditionMatches({
            type = 'spell',
            conditions = { type = 'NOT', value = { type = 'ENEMY', unit = 'announcementtarget' } },
        }, 'Missing-Realm')
    )
end)

test('all announcement editors expose contextual target and macro guidance belongs in Help', function()
    local prefix = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))

    prefix = prefix:gsub(
        '    local codecData,codecDeps=[^\n]+\n',
        "    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/diff.lua','Data/import_session.lua'})do f.load(path)end\n"
    )

    local f, parent = assert(loadstring(prefix .. '\nreturn fixture()', '@auto-announcement-ui'))()
    local a = f.addon
    local options

    a.ShowConditionEditor = function(_, _, _, _, _, _, value)
        options = value
    end

    a.db.profile.announces = {
        { id = 'a', type = 'spell', spell = 547, event = 'START', announce = 'local', value = 'Message' },
    }

    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.entry1conditions:Click()
    assert(options.announcementTarget)

    p:SettingsData().profile.announces[1] = {
        id = 'b',
        type = 'macro',
        identifier = 'REZ',
        announce = 'whisper',
        value = 'Hello',
    }

    local texts = {}
    local old = p.Text

    p.Text = function(self, text, ...)
        texts[#texts + 1] = text
        return old(self, text, ...)
    end

    p:Draw()

    for _, text in ipairs(texts) do
        assert(
            not text:find('/run RM_Annouce', 1, true) and text ~= f.translations['Help.Announces.macro.brief'],
            'inline macro help remains'
        )
    end
end)

finish()
