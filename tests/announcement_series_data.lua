-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()

    for _, path in ipairs({ 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/validation.lua' }) do
        f.load(path)
    end

    local a = f.addon

    return f, a, {
        id = '11111111-1111-1111-1111-111111111111',
        type = 'macro',
        identifier = 'FOO',
        outputs = {
            { id = '22222222-2222-2222-2222-222222222222', announce = 'say', value = 'Ready' },
            { id = '33333333-3333-3333-3333-333333333333', announce = 'whisper', value = 'Ready {{target}}' },
        },
    }
end

test('series profiles preserve ordered independent outputs and legacy entries', function()
    local _, a, entry = fixture()
    assert(a:IsValidAnnouncement(entry, true))
    assert(a:ValidateProfileTransfer({ announces = { entry } }))
    local copy = a.RotationData.CopyData(entry)
    copy.outputs[1], copy.outputs[2] = copy.outputs[2], copy.outputs[1]
    assert(a:IsValidAnnouncement(copy, true))

    assert(a:IsValidAnnouncement({
        type = 'spell',
        spell = 403,
        event = 'START',
        announce = 'local',
        value = 'Legacy',
    }))

    entry.outputs = {}
    assert(a:IsValidAnnouncement(entry, true), 'empty series must be harmless and editable')
end)

test('series cards have closed dense bounded shape and unique stable identities', function()
    local _, a, entry = fixture()
    local copy = a.RotationData.CopyData

    for _, mutate in ipairs({
        function(v)
            v.outputs[2].id = v.outputs[1].id
        end,
        function(v)
            v.outputs[1].id = nil
        end,
        function(v)
            v.outputs.extra = {}
        end,
        function(v)
            v.outputs[4] = v.outputs[2]
        end,
        function(v)
            v.outputs[1].type = 'macro'
        end,
        function(v)
            v.outputs[1].disabled = 'yes'
        end,
        function(v)
            v.outputs[1].unexpected = true
        end,
        function(v)
            v.outputs[1].value = string.rep('x', 4097)
        end,
        function(v)
            v.announce = 'local'
        end,
        function(v)
            v.conditions = {}
        end,
    }) do
        local v = copy(entry)
        mutate(v)
        assert(not a:IsValidAnnouncement(v, true), 'invalid series accepted')
    end

    for i = 3, 65 do
        entry.outputs[i] = { id = string.format('%08x-1111-1111-1111-111111111111', i), announce = 'local' }
    end

    assert(not a:IsValidAnnouncement(entry, true))
end)

test('channel output stores a readable exact name and stays macro-only', function()
    local _, a, entry = fixture()

    entry.outputs[1] = {
        id = entry.outputs[1].id,
        announce = 'channel',
        channel_name = 'Trade - City',
        value = 'Message',
    }

    assert(a:IsValidAnnouncement(entry, true))

    for _, name in ipairs({ '', 'General\nInjected', string.rep('x', 257) }) do
        entry.outputs[1].channel_name = name
        assert(not a:IsValidAnnouncement(entry))
    end

    entry.outputs[1].channel_name = 'Custom'
    entry.outputs[1].channel_id = 2
    assert(not a:IsValidAnnouncement(entry))
    entry.outputs[1].channel_id = nil
    entry.type = 'spell'
    entry.identifier = nil
    entry.spell = 403
    entry.event = 'START'

    for _, mode in ipairs({ 'channel', 'say', 'yell', 'whisper' }) do
        entry.outputs[1].announce = mode
        assert(not a:IsValidAnnouncement(entry), mode)
    end

    entry.outputs[1].announce = 'local'
    entry.outputs[1].channel_name = nil
    entry.outputs[2].announce = 'partyraid'
    assert(a:IsValidAnnouncement(entry))
end)

test('each output validates condition data without executing imported callbacks', function()
    local f, a, entry = fixture()
    f.load('Core/conditions.lua')

    a:RegisterCondition('IMPORT_ONLY', {
        fields = { flag = 'boolean' },
        valid = function()
            error('import ran validator')
        end,
        evaluate = function()
            error('import evaluated')
        end,
    })

    entry.outputs[1].conditions = { type = 'IMPORT_ONLY', flag = true }
    assert(a:IsValidAnnouncement(entry))
    entry.outputs[2].conditions = { type = 'IMPORT_ONLY', flag = 'bad' }
    assert(not a:IsValidAnnouncement(entry))
end)

finish()
