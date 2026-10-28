-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- A rotation with no switch condition: the editor's switch pane says what that means (in English and
-- another language), and says nothing of the kind for a switch that has conditions.
local F = dofile('tests/fixtures/addon.lua')

local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture', '@rotation-switch-empty-fixture'))()
local test, finish = F.suite()
local KEY = 'No switch condition: this rotation can be selected automatically whenever its specialization and level apply.'

-- The entry a locale file holds for KEY.
local function translation(language)
    if language == 'enUS' then
        return KEY
    end

    local found

    local L = setmetatable({}, {
        __newindex = function(_, key, value)
            if key == KEY then
                found = value
            end
        end,
    })

    local env = setmetatable({ LibStub = function() return { NewLocale = function() return L end } end }, {
        __index = _G,
    })

    local chunk = assert(loadfile('Locales/' .. language .. '.lua'))
    setfenv(chunk, env)
    chunk('rotationmaster')
    return found
end

for _, language in ipairs({ 'enUS', 'deDE' }) do
    test(
        language
            .. ': an empty switch says it is selected automatically whenever the rotation applies; a real one shows its condition',
        function()
            local f, parent = fixture()

            if language ~= 'enUS' then
                f.env.GetLocale = function() return language end
                f.load('Locales/' .. language .. '.lua')
            end

            local a = f.addon
            a.HasSwitchCondition = function(_, switch) return type(switch) == 'table' and switch.type ~= nil end
            local expected = assert(translation(language), language .. ' has no translation of the empty switch text')

            if language ~= 'enUS' then
                assert(
                    expected ~= KEY and expected ~= '' and not expected:find('whenever its specialization', 1, true),
                    'the text was not translated'
                )
            end

            local pane = assert(a:CreateRotationEditor(parent, 0, 'mine'))

            assert(pane.switchText:GetText() == a:PlainWorkbenchName(expected), ("[%s] vs [%s]"):format(
                tostring(pane.switchText:GetText()),
                tostring(a:PlainWorkbenchName(expected))
            ))

            local g, host = fixture()
            g.addon.HasSwitchCondition = a.HasSwitchCondition
            g.addon.db.profile.rotations[0].mine.switch = { type = 'COMBAT', unit = 'player' }
            g.addon.DescribeCardCondition = function() return 'You are in combat' end
            local other = assert(g.addon:CreateRotationEditor(host, 0, 'mine'))
            assert(other.switchText:GetText() == 'You are in combat', tostring(other.switchText:GetText()))
        end
    )
end

finish()
