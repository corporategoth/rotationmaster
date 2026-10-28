-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

test(
    'actual announcement and profile codec roundtrips preserve macro identifiers and literal contextual trees',
    function()
        local f = F.new()
        local a = f.addon
        local data, deps = dofile('tests/fixtures/codec.lua')()
        a.RotationData = data
        f.load('Core/conditions.lua')

        a:RegisterCondition('MACRO_UNIT', {
            fields = { unit = 'string' },
            valid = function()
                error('transfer ran custom validation')
            end,
            evaluate = function()
                error('transfer evaluated')
            end,
        })

        local entry = {
            id = '11111111-1111-1111-1111-111111111111',
            type = 'macro',
            identifier = 'FOO',
            announce = 'whisper',
            value = 'Hello {{target}}',
            conditions = { type = 'MACRO_UNIT', unit = 'announcementtarget' },
        }

        local codec = assert(data.NewCodec(deps))
        local wire = assert(codec:Encode({ format = 'RM-Announcement', version = 1, announcement = entry }))
        local decoded = assert(codec:Decode(wire)).value.announcement

        assert(
            a:IsValidAnnouncement(decoded, true)
                and decoded.identifier == 'FOO'
                and decoded.conditions.unit == 'announcementtarget'
        )

        local profile = { announces = { decoded } }
        local portable = assert(a:ProfileToPortable(profile))
        local profileWire = assert(codec:Encode({ format = 'RM-Profile', version = 1, profile = portable }))
        local imported = assert(a:ProfileFromPortable(assert(codec:Decode(profileWire)).value.profile))

        assert(
            a:ValidateProfileTransfer(imported)
                and imported.announces[1].identifier == 'FOO'
                and imported.announces[1].conditions.unit == 'announcementtarget'
        )
    end
)

finish()
