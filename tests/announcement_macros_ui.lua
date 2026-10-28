-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local h = assert(io.open('tests/settings_pages.lua'))
    local source = h:read('*a')
    h:close()
    local prefix = assert(source:match('^(.-)\ntest%('))

    prefix = prefix:gsub(
        '    local codecData,codecDeps=[^\n]+\n',
        "    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/diff.lua','Data/import_session.lua'})do f.load(path)end\n"
    )

    local f, parent = assert(loadstring(prefix .. '\nreturn fixture()', '@announcement-macro-ui'))()
    local a = f.addon

    a.db.profile.announces = {
        {
            id = '11111111-1111-1111-1111-111111111111',
            type = 'macro',
            identifier = 'FOO',
            announce = 'say',
            value = 'Hello {{target}}',
        },
    }

    return f, a, parent
end

local function input(p, key, text)
    local c = assert(p.fields[key], key)
    c:SetText(text)
    c:GetScript('OnTextChanged')(c, true)
    return c
end

test('macro details show identifier and macro destinations without cast action or event fields', function()
    local _, a, parent = fixture()
    local p = a:OpenNativeSettings(parent, 'Announces')

    assert(
        p.fields.entry1identifier and not p.fields.entry1action and not p.fields.entry1event,
        'macro fields not isolated'
    )

    p.fields.entry1channel:Click()
    local rows = p.menu.entries or p.menu.rows
    assert(rows, 'missing destination menu')
    local modes = {}

    for _, row in ipairs(rows) do
        modes[row.value] = true
    end

    assert(modes.say and modes.yell and modes.whisper, 'macro restricted choices missing')
end)

test('invalid and duplicate pending macro identifiers prevent parent Apply without changing saved data', function()
    local _, a, parent = fixture()

    a.db.profile.announces[2] = {
        id = '22222222-2222-2222-2222-222222222222',
        type = 'macro',
        identifier = 'BAR',
        announce = 'local',
        value = 'Other',
    }

    local p = a:OpenNativeSettings(parent, 'Announces')
    local c = input(p, 'entry1identifier', 'bad space')
    p.fields.apply:Click()
    assert(a.db.profile.announces[1].identifier == 'FOO' and c:GetText() == 'bad space')
    input(p, 'entry1identifier', 'BAR')
    p.fields.apply:Click()
    assert(a.db.profile.announces[1].identifier == 'FOO', 'duplicate identifier saved')
    input(p, 'entry1identifier', 'NEW')
    p.fields.apply:Click()
    assert(a.db.profile.announces[1].identifier == 'NEW')
end)

test('stale pooled identifier callback and parent Discard cannot publish macro changes', function()
    local _, a, parent = fixture()
    local p = a:OpenNativeSettings(parent, 'Announces')
    local c = input(p, 'entry1identifier', 'DRAFT')
    local old = c:GetScript('OnEditFocusLost')
    p.fields.cancel:Click()
    assert(a.db.profile.announces[1].identifier == 'FOO')
    p:Release()
    old(c)
    assert(a.db.profile.announces[1].identifier == 'FOO')
end)

test('macro condition editor receives explicit dynamic-unit option and comparison includes identifier', function()
    local _, a, parent = fixture()
    local options

    a.ShowConditionEditor = function(_, _, _, _, _, _, value)
        options = value
    end

    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.entry1conditions:Click()
    assert(options and options.announcement and options.announcementTarget)
    local left = a.db.profile.announces[1]
    local right = a:CopySettingsData(left)
    right.identifier = 'NEW'
    local rows = a:CollectionComparisonRows('announcement', left, right, false)
    assert(#rows == 1 and rows[1].label == 'Identifier')
end)

test('explicit duplicate creates a distinct callable identifier and stays staged', function()
    local _, a, parent = fixture()
    a.uuid = function() return '22222222-2222-2222-2222-222222222222' end
    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.duplicate:Click()
    local values = p:SettingsData().profile.announces

    assert(
        #values == 2 and values[2].identifier == 'FOO_2' and values[2].type == 'macro' and values[2].announce == 'say'
    )

    assert(#a.db.profile.announces == 1)
    p.fields.apply:Click()
    assert(#a.db.profile.announces == 2 and a:AreMacroAnnouncementIdentifiersUnique(a.db.profile.announces))
end)

test('type switching clears cast fields and event entries never expose macro-only destinations', function()
    local _, a, parent = fixture()

    a.db.profile.announces[1] = {
        id = 'a',
        type = 'spell',
        spell = 403,
        event = 'START',
        announce = 'local',
        value = 'Message',
    }

    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.entry1channel:Click()

    for _, row in ipairs(p.menu.entries) do
        assert(row.value ~= 'say' and row.value ~= 'yell' and row.value ~= 'whisper')
    end

    p.menu:Hide()
    p.fields.entry1type:Click()
    p.menu.changed('macro', 'Via Macro')
    local entry = p:SettingsData().profile.announces[1]
    assert(entry.type == 'macro' and entry.spell == nil and entry.event == nil and entry.identifier == 'ANNOUNCE')
    assert(p.fields.entry1identifier and not p.fields.entry1action and not p.fields.entry1event)
end)

test('announcement import rejects an ambiguous New identifier and permits exact selected Replace', function()
    local _, a, parent = fixture()
    local callback

    a.NewRotationCodec = function()
        return {
            Encode = function() return 'encoded' end,
            Decode = function()
                return {
                    value = {
                        format = 'RM-Announcement',
                        version = 1,
                        announcement = a:CopySettingsData(a.db.profile.announces[1]),
                    },
                }
            end,
        }
    end

    a.ShowSettingsTextTransfer = function(_, _, _, _, apply)
        callback = apply
    end

    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.transfer:Click()
    assert(callback)
    local ok = callback('encoded', { mode = 'new', name = 'Imported' })
    assert(not ok and #p:SettingsData().profile.announces == 1)
    assert(callback('encoded', { mode = 'replace' }))
    assert(p:SettingsData().profile.announces[1].identifier == 'FOO' and #a.db.profile.announces == 1)
end)

finish()
