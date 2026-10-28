-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The Set Mark step: the whitelist, the pseudo spell id, the one macro line a hidden button runs, hostile saved or
-- imported values that must never reach secure text, button creation (lazy, out of combat, never over a foreign global),
-- recognizing the macro on a bar, readiness (exists, not already marked, the group rule), the Bind flow, validation and
-- flagging on a client that cannot place marks, the editor fields, and a whole poll through both engines. See
-- docs/raid-marks.md.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local W = dofile('tests/fixtures/raid_mark_world.lua')
local C = dofile('tests/fixtures/condition_client.lua')

local BASE = 1073741824
local UNITS = { 'player', 'target', 'focus', 'mouseover', 'pet', 'targettarget', 'focustarget' }
local WORDS = {'none', 'star', 'circle', 'diamond', 'triangle', 'moon', 'square', 'cross', 'skull'}
local FAMILIES = { 'retail', 'forever', 'mists', 'tbc', 'era' }

-- Every text a hostile export could put in a unit or mark field: macro syntax, a second command, control characters,
-- bracket and conditional syntax, escapes, an over-long value, near misses of real names and the wrong kinds of value.
local HOSTILE = {
    'target]\n/run print(1)',
    'target] 8\n/cast Pyroblast',
    'target;mouseover',
    'target, mouseover',
    '[@target]',
    'target]/script x',
    '@target',
    'Target',
    'TARGET',
    ' target',
    'target ',
    'target\n',
    'target\0',
    'targ\0et',
    'skull]\n/run x',
    'skull\n/run x',
    'Skull',
    'skull ',
    '8',
    '0',
    '',
    ' ',
    '|cffff0000target|r',
    '|Hspell:1|h[x]|h',
    'raid1',
    'party1',
    'nameplate1',
    'boss1',
    'arena1',
    'focus,target',
    'target_skull',
    'RM_Mark_target_skull',
    '/tm [@target] 8',
    '/click RM_Mark_target_skull',
    string.rep('target', 200),
    string.rep('a', 5000),
    '\226\128\174target',
    '../target',
    'none,skull',
}

local OTHER_KINDS = { 8, 0, -1, 1.5, 0 / 0, math.huge, true, false, {}, function() end, { 'target' } }

-- The step a rotation would hold.
local function step(unit, action)
    return { id = 'mark', type = 'mark', unit = unit, action = action, conditions = {} }
end

-- The number of a mark word (none is 0).
local function number(word)
    for index, candidate in ipairs(WORDS) do
        if candidate == word then
            return index - 1
        end
    end
end

-- The unit of the world: a GUID, a mark and a hostility.
local function unit(guid, mark, enemy)
    return { guid = guid, mark = mark, enemy = enemy == true, friend = enemy == false }
end

-- A client with the Set Mark step's platform pieces; the spell reader is loaded too, for the pseudo spell id's name.
local function client(name, options)
    local f, a, e, w = W.client(name, options)
    f.load('Platform/spells.lua')
    return f, a, e, w
end

test('every unit and mark pair has its own pseudo spell id, button name and macro line', function()
    local _, a = client('tbc')
    local seen, names = {}, {}
    local pairsSeen = 0

    for _, token in ipairs(UNITS) do
        for _, word in ipairs(WORDS) do
            local mark = number(word)
            local id = a.Platform:GetMarkActionId(token, mark)
            assert(id and id >= BASE and not seen[id], 'id for ' .. token .. ' ' .. word)
            seen[id] = true
            local decodedUnit, decodedMark = a.Platform:DecodeMarkActionId(id)
            assert(decodedUnit == token and decodedMark == mark, 'round trip of ' .. token .. ' ' .. word)
            assert(a.Platform:IsMarkActionId(id))
            local name = a.Platform:GetMarkButtonName(token, mark)
            assert(name == 'RM_Mark_' .. token .. '_' .. word and not names[name], name)
            assert(name:match('^RM_Mark_%l+_%l+$'), 'a name is lower-case letters and underscores: ' .. name)
            names[name] = true
            local text = a.Platform:GetMarkMacroText(token, mark)
            assert(text == '/tm [@' .. token .. '] ' .. mark, text)
            assert(text:match('^/tm %[@%l+%] [0-8]$'), 'the template: ' .. text)
            local barName, body = a.Platform:GetMarkBarMacro(token, mark)

            assert(
                #barName <= 16 and not barName:find('[^%w /]'),
                'a macro name of at most sixteen plain characters: ' .. barName
            )

            assert(body == '/click ' .. name)
            pairsSeen = pairsSeen + 1
        end
    end

    assert(pairsSeen == 63)
end)

test('real spell ids and nearby numbers are never mistaken for a mark id', function()
    local _, a = client('tbc')

    for _, value in ipairs({
        0,
        1,
        403,
        8042,
        1500000,
        BASE - 1,
        BASE,
        BASE + 15,
        BASE + 7 * 16 + 9,
        BASE + 8 * 16,
        BASE + 1.5,
        BASE * 2,
        -BASE,
        0 / 0,
        math.huge,
    }) do
        assert(a.Platform:DecodeMarkActionId(value) == nil, tostring(value))
        assert(not a.Platform:IsMarkActionId(value))
        assert(a.Platform:GetMarkActionInfo(value) == nil)
    end

    for _, value in ipairs({ '1073741840', true, {}, false }) do
        assert(a.Platform:DecodeMarkActionId(value) == nil)
    end

    assert(a.Platform:DecodeMarkActionId(nil) == nil)
    assert(a.Platform:GetMarkActionId('target', 9) == nil and a.Platform:GetMarkActionId('target', -1) == nil)
    assert(a.Platform:GetMarkActionId('target', 1.5) == nil and a.Platform:GetMarkActionId('target', '8') == nil)
end)

test('hostile unit and mark values never produce an id, a button name, a macro line or a macro', function()
    local _, a, _, w = client('tbc')

    for _, bad in ipairs(HOSTILE) do
        assert(a.Platform:GetMarkStepActionId(step(bad, 'skull')) == nil, 'accepted unit ' .. bad)
        assert(a.Platform:GetMarkStepActionId(step('target', bad)) == nil, 'accepted mark ' .. bad)
        assert(a.Platform:GetMarkStepActionId(step(bad, bad)) == nil)
        assert(a.Platform:GetMarkMacroText(bad, 8) == nil)
        assert(a.Platform:GetMarkButtonName(bad, 8) == nil)
        assert(a.Platform:GetMarkBarMacro(bad, 8) == nil)
        assert(a.Platform:GetMarkActionId(bad, 8) == nil)
        assert(not a.Platform:IsMarkActionUnit(bad), bad)
        assert(a:GetStepSupport(step(bad, 'skull')) == 'invalid-mark-step')
        assert(a:GetStepSupport(step('target', bad)) == 'invalid-mark-step')
        local ok, why = a:BeginMarkBind(bad, 'skull')
        assert(ok == false and why == 'invalid-mark-step', tostring(why))
        ok, why = a:BeginMarkBind('target', bad)
        assert(ok == false and why == 'invalid-mark-step', tostring(why))
        assert(#a:GetMarkStepSpellIds(step(bad, 'skull')) == 0 and #a:GetMarkStepSpellIds(step('target', bad)) == 0)
        assert(a.Platform:FindMarkBarMacro(bad, 8) == nil and a.Platform:CreateMarkBarMacro(bad, 8) == nil)
    end

    for _, bad in ipairs(OTHER_KINDS) do
        assert(a.Platform:GetMarkStepActionId(step(bad, 'skull')) == nil)
        assert(a.Platform:GetMarkStepActionId(step('target', bad)) == nil)

        assert(
            a.Platform:GetMarkMacroText('target', bad) == nil
                or type(bad) == 'number' and bad >= 0 and bad <= 8 and bad % 1 == 0
        )

        assert(a.Platform:GetMarkActionId('target', bad) == nil or bad == 8 or bad == 0)
        assert(#a:GetMarkStepSpellIds(step(bad, 'skull')) == 0)
        assert(select(1, a:BeginMarkBind(bad, 'skull')) == false)
    end

    assert(a.Platform:GetMarkStepActionId(nil) == nil and a.Platform:GetMarkStepActionId('target') == nil)
    assert(a:GetStepSupport(nil) == nil and a:GetStepSupport({ type = 'spell', action = 1 }) == nil)

    -- Forged pseudo ids: a mark above 8, a unit past the list, below the base.
    for _, forged in ipairs({ BASE + 16 + 9, BASE + 16 * 8, BASE + 16 * 7 + 15, BASE, BASE - 1, 403 }) do
        local ready, why = a:EnsureMarkButton(forged)
        assert(ready == false and why == 'invalid-mark-step', tostring(forged))
    end

    assert(#w.attributeWrites == 0, 'a hostile value reached a secure attribute')
    assert(#w.macros == 0, 'a hostile value made a macro')
    assert(next(a.markButtons) == nil, 'a hostile value made a button')
end)

test(
    'a button is made the first time a Set Mark step is evaluated, with exactly the template and nothing else',
    function()
        local _, a, e, w = client('tbc')
        assert(next(a.markButtons) == nil and #w.attributeWrites == 0, 'nothing is made at load')
        assert(not a.Platform:IsMarkActionTracking())

        for _, token in ipairs(UNITS) do
            for _, word in ipairs(WORDS) do
                local ids = a:GetMarkStepSpellIds(step(token, word))
                local expected = a.Platform:GetMarkActionId(token, number(word))
                assert(#ids == 1 and ids[1] == expected, token .. ' ' .. word)
            end
        end

        local count = 0

        for _, write in ipairs(w.attributeWrites) do
            count = count + 1
            local name = write.name
            assert(name and name:match('^RM_Mark_%l+_%l+$'), 'the button name: ' .. tostring(name))
            local token, word = name:match('^RM_Mark_(%l+)_(%l+)$')

            if write.key == 'type' then
                assert(write.value == 'macro')
            else
                assert(write.key == 'macrotext', 'attribute ' .. tostring(write.key))
                assert(write.value == '/tm [@' .. token .. '] ' .. number(word), 'macrotext ' .. tostring(write.value))
            end
        end

        assert(count == 63 * 2, 'two attributes per button: ' .. count)
        local button = e.RM_Mark_target_skull
        assert(button and button.attributes.type == 'macro' and button.attributes.macrotext == '/tm [@target] 8')
        assert(button.visible == false or button.shown == false or button.visible ~= true, 'the button is hidden')
        assert(a.Platform:IsMarkActionTracking(), 'macros on the bars are recognized once a step is in use')
        assert(w.fetches == 1, 'one bar rescan for the first button, not one per button: ' .. w.fetches)
        -- Evaluating again makes nothing.
        a:GetMarkStepSpellIds(step('target', 'skull'))
        assert(#w.attributeWrites == count)
    end
)

test('a button is not made in combat and is made at the next evaluation out of combat', function()
    local _, a, e, w = client('tbc')
    w.combat = true
    local ids = a:GetMarkStepSpellIds(step('target', 'skull'))
    assert(#ids == 1, 'the step still resolves its id in combat')
    assert(e.RM_Mark_target_skull == nil and #w.attributeWrites == 0, 'a secure button was made in combat')
    local ready, why = a:EnsureMarkButton(ids[1])
    assert(ready == false and why == 'combat')
    w.combat = false
    a:GetMarkStepSpellIds(step('target', 'skull'))
    assert(e.RM_Mark_target_skull ~= nil)
end)

test('a global of the same name that is not ours is never reused or overwritten', function()
    local _, a, e, w = client('tbc')

    local foreign = {
        SetAttribute = function()
            error('touched a foreign object')
        end,
    }

    e.RM_Mark_target_skull = foreign
    local ready, why = a:EnsureMarkButton(a.Platform:GetMarkActionId('target', 8))
    assert(ready == false and why == 'name-taken')
    assert(e.RM_Mark_target_skull == foreign and #w.attributeWrites == 0)
end)

test('a client that cannot place marks makes no button and gives no id', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, e, w = client(name, { set = false })
        assert(a.Platform:GetMarkActionSupport() == 'missing-api', name)
        assert(#a:GetMarkStepSpellIds(step('target', 'skull')) == 0, name)
        assert(e.RM_Mark_target_skull == nil and #w.attributeWrites == 0, name)
        assert(a:GetStepSupport(step('target', 'skull')) == 'missing-api', name)
        local ok, why = a:BeginMarkBind('target', 'skull')
        assert(ok == false and why == 'unsupported', name)
        assert(#w.macros == 0)
    end
end)

test('the command alone is enough capability, and so is SetRaidTarget alone', function()
    local _, a, e = client('tbc')
    e.SetRaidTarget = nil
    assert(a.Platform:GetMarkActionSupport() == nil, 'SecureCmdList.TARGET_MARKER is a capability')
    e.SecureCmdList = nil
    assert(a.Platform:GetMarkActionSupport() == 'missing-api')
    e.SlashCmdList = { TARGET_MARKER = function() end }
    assert(a.Platform:GetMarkActionSupport() == nil, 'SlashCmdList.TARGET_MARKER is a capability')
    e.SlashCmdList = nil
    e.SetRaidTarget = function() end
    assert(a.Platform:GetMarkActionSupport() == nil)
end)

test('the focus units are offered only where the client has a focus target', function()
    local _, a = client('tbc')
    local offered = {}

    for _, token in ipairs(a.Platform:GetMarkActionUnits()) do
        offered[token] = true
    end

    assert(
        offered.focus
            and offered.focustarget
            and offered.player
            and offered.target
            and #a.Platform:GetMarkActionUnits() == 7
    )

    local _, b = client('era', { catalog = false })
    b.Platform.IsFocusUnitSupported = function() return false end
    assert(not b.Platform:IsMarkActionUnit('focus') and not b.Platform:IsMarkActionUnit('focustarget'))
    assert(#b.Platform:GetMarkActionUnits() == 5)
    assert(b.Platform:GetMarkStepActionId(step('focus', 'skull')) == nil)
    assert(select(2, b.Platform:GetMarkStepActionId(step('focus', 'skull'))) == 'unsupported-unit')
    assert(b:GetStepSupport(step('focus', 'skull')) == 'unsupported-unit')
end)

test('macros on the bars are recognized only once a step is in use, and only for a whitelisted button name', function()
    local _, a, e, w = client('tbc')
    local reads = 0
    w.macros[1] = { name = 'x', body = '/click RM_Mark_target_skull' }
    local body = e.GetMacroBody

    e.GetMacroBody = function(...)
        reads = reads + 1
        return body(...)
    end

    -- Tracking is off: nothing is read.
    assert(a.Platform:GetMarkMacroActionId(1) == nil and reads == 0, 'a macro was read while tracking was off')
    a.Platform:SetMarkActionTracking(true)
    local expected = a.Platform:GetMarkActionId('target', 8)
    assert(a.Platform:GetMarkMacroActionId(1) == expected and reads == 1)

    local bodies = {
        { '/click RM_Mark_target_skull', expected },
        { '/click RM_Mark_target_skull\n', expected },
        { '#showtooltip\n/click RM_Mark_target_skull', expected },
        { '/CLICK RM_Mark_target_skull', expected },
        { '/Click   RM_Mark_target_skull', expected },
        { '/click RM_Mark_target_skull LeftButton', expected },
        { '/click RM_Mark_target_skull:LeftButton', expected },
        { '/click SomethingElse\n/click RM_Mark_mouseover_none', a.Platform:GetMarkActionId('mouseover', 0) },
        { '/click RM_Mark_target_skullx', nil },
        { '/click xRM_Mark_target_skull', nil },
        { '/click RM_Mark_target_skull_', nil },
        { '/click RM_Mark_target_Skull', nil },
        { '/click RM_Mark_Target_skull', nil },
        { '/click RM_Mark_player_', nil },
        { '/click RM_Mark_nonsense_skull', nil },
        { '/click RM_Mark_target_nine', nil },
        { 'RM_Mark_target_skull', nil },
        { '/cast RM_Mark_target_skull', nil },
        { '/use RM_Mark_target_skull', nil },
        { '/tm [@target] 8', nil },
        { '/clickRM_Mark_target_skull', nil },
        { '', nil },
        { string.rep('/click RM_Mark_target_skull\n', 400), nil },
    }

    for _, case in ipairs(bodies) do
        w.macros[1].body = case[1]
        assert(a.Platform:GetMarkMacroActionId(1) == case[2], 'body ' .. string.format('%q', case[1]:sub(1, 60)))
    end

    w.macros[1].body = '/click RM_Mark_target_skull'
    assert(a.Platform:GetMarkMacroActionId(2) == nil, 'a macro index with no macro')
    assert(a.Platform:GetMarkMacroActionId({}) == nil and a.Platform:GetMarkMacroActionId(nil) == nil)
    assert(a.Platform:GetMarkMacroActionId(true) == nil)
    reads = 0
    a.Platform:SetMarkActionTracking(false)
    assert(a.Platform:GetMarkMacroActionId(1) == nil and reads == 0, 'tracking off again')
end)

test('an unreadable or failing macro body is not a Set Mark macro', function()
    local _, a, e, w = client('retail')
    a.Platform:SetMarkActionTracking(true)
    w.macros[1] = { body = '/click RM_Mark_target_skull' }
    e.GetMacroBody = function() return W.SECRET end
    assert(a.Platform:GetMarkMacroActionId(1) == nil)

    e.GetMacroBody = function()
        error('boom')
    end

    assert(a.Platform:GetMarkMacroActionId(1) == nil)
    e.GetMacroBody = function() return 7 end
    assert(a.Platform:GetMarkMacroActionId(1) == nil)
    e.GetMacroBody = nil
    assert(a.Platform:GetMarkMacroActionId(1) == nil)
    e.GetMacroBody = function() return '/click RM_Mark_target_skull' end
    assert(a.Platform:GetMarkMacroActionId(W.SECRET) == nil, 'a hidden macro index')
end)

test('GetMacroAction answers a Set Mark macro with its pseudo spell id, on every client and policy', function()
    for _, name in ipairs(FAMILIES) do
        local f, a, e = client(name)
        f.load('Platform/macros.lua')
        a.Platform:SetMarkActionTracking(true)
        e.GetMacroBody = function() return '/click RM_Mark_focus_moon' end

        e.GetMacroItem = function()
            error('a Set Mark macro must not be read as an item macro')
        end

        e.GetMacroSpell = function()
            error('a Set Mark macro must not be read as a spell macro')
        end

        local action = a.Platform:GetMacroAction(1)
        assert(action and action.kind == 'mark' and action.spellID == a.Platform:GetMarkActionId('focus', 5), name)
        e.GetMacroBody = function() return '/cast Fireball' end
        local other, why = a.Platform:GetMacroAction(1)

        if name == 'retail' or name == 'forever' then
            assert(other == nil and why == 'unsupported-policy', name .. ' ' .. tostring(why))
        end
    end
end)

test('the pseudo spell id has a name and an icon for the preview and the reports', function()
    local _, a = client('tbc')
    local id = a.Platform:GetMarkActionId('target', 8)
    local info = a.Platform:GetSpellInfo(id)

    assert(
        info and info.name == 'Skull' and info.iconID == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_8',
        info and info.name
    )

    local clear = a.Platform:GetSpellInfo(a.Platform:GetMarkActionId('target', 0))
    assert(clear and clear.name == 'None' and clear.iconID == 'Interface\\Icons\\INV_Misc_QuestionMark')
    assert(a.Platform:GetMarkActionInfo(id).unit == 'target' and a.Platform:GetMarkActionInfo(id).mark == 8)
    assert(a.Platform:GetRaidMarkName(1) == 'Star' and a.Platform:GetRaidMarkName(9) == nil)
    assert(a.Platform:GetRaidMarkTexture(3) == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_3')
    local _, b, e = client('tbc')
    e.RAID_TARGET_8 = 'Totenkopf'

    assert(
        b.Platform:GetSpellInfo(b.Platform:GetMarkActionId('target', 8)).name == 'Totenkopf',
        'the game name is preferred'
    )

    -- A real spell id still reaches the client.
    e.C_Spell = { GetSpellInfo = function(spell) return { name = 'Real ' .. spell, iconID = 5, spellID = spell } end }
    assert(b.Platform:GetSpellInfo(403).name == 'Real 403')
end)

test('a step reads as a sentence, and as Set Mark while it is not filled in', function()
    local _, a = client('tbc')

    assert(a:DescribeMarkStep(step('target', 'skull')) == 'Set Skull on your target', a:DescribeMarkStep(step(
        'target',
        'skull'
    )))

    assert(a:DescribeMarkStep(step('focus', 'none')) == 'Clear the mark on your focus target')
    assert(a:DescribeMarkStep(step('mouseover', 'moon')) == 'Set Moon on your mouseover target')

    assert(
        a:DescribeMarkStep(step('target', nil)) == 'Set Mark' and a:DescribeMarkStep(step(nil, 'skull')) == 'Set Mark'
    )

    assert(
        a:DescribeMarkStep(step('target]\n/run x', 'skull')) == 'Set Mark',
        'a hostile unit is never shown as a unit'
    )

    assert(a:DescribeMarkStep(nil) == 'Set Mark')
    assert(a:GetMarkStepIcon(step('target', 'star')) == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_1')
    assert(a:GetMarkStepIcon(step('target', 'none')) == 'Interface\\Icons\\INV_Misc_QuestionMark')
    assert(a:GetMarkStepIcon(nil) == 'Interface\\Icons\\INV_Misc_QuestionMark')
end)

-- Readiness. The unit exists, does not already carry the mark, and you may place marks.
local function ready(a, token, word)
    return a.Platform:IsMarkActionReady(a.Platform:GetMarkActionId(token, number(word)))
end

test('a Set Mark step is ready while its unit exists and does not carry the mark yet', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, _, w = client(name)
        local ok, why = ready(a, 'target', 'skull')
        assert(ok == false and why == 'no-unit', name .. ' ' .. tostring(why))
        w:set('target', unit('G1', nil, true))
        assert(ready(a, 'target', 'skull') == true, name)
        w.tokens.target.mark = 3
        assert(ready(a, 'target', 'skull') == true, name .. ' a different mark is replaced')
        w.tokens.target.mark = 8
        ok, why = ready(a, 'target', 'skull')
        assert(ok == false and why == 'already-marked', name .. ' ' .. tostring(why))
        assert(ready(a, 'target', 'none') == true, name .. ' clearing a marked unit')
        w.tokens.target.mark = nil
        ok, why = ready(a, 'target', 'none')
        assert(ok == false and why == 'already-marked', name .. ' there is nothing to clear')
    end
end)

test('a Set Mark step is not ready when the mark or the unit cannot be read', function()
    local _, a, e, w = client('retail')
    w:set('target', unit('G1', nil, true))
    w.secretMarks.target = true
    local ok, why = ready(a, 'target', 'skull')
    assert(ok == false and why == 'restricted-value', tostring(why))
    w.secretMarks.target = nil
    e.UnitExists = function() return W.SECRET end
    ok, why = ready(a, 'target', 'skull')
    assert(ok == false and why == 'restricted-value', tostring(why))
    e.UnitExists = function() return nil end
    ok, why = ready(a, 'target', 'skull')
    assert(ok == false and why == 'unit-data-unavailable', tostring(why))
    ok, why = a.Platform:IsMarkActionReady(403)
    assert(ok == false and why == 'invalid-mark-step')
end)

test('in a raid only the leader and assistants can place a mark; in a party anyone can', function()
    local _, a, e, w = client('tbc')
    w:set('target', unit('G1', nil, true))
    w.group = { raid = false, size = 5 }
    assert(ready(a, 'target', 'skull') == true, 'a party member can mark')
    w.group = { raid = false, size = 0 }
    assert(ready(a, 'target', 'skull') == true, 'alone you can mark')
    w.group = { raid = true, size = 20 }
    local ok, why = ready(a, 'target', 'skull')
    assert(ok == false and why == 'no-mark-permission', 'a raid member cannot mark: ' .. tostring(why))
    w.group.leader = true
    assert(ready(a, 'target', 'skull') == true, 'the leader can mark')
    w.group = { raid = true, size = 20, assistant = true }
    assert(ready(a, 'target', 'skull') == true, 'an assistant can mark')
    -- A client that cannot say who may mark gets the benefit of the doubt.
    w.group = { raid = true, size = 20 }
    e.UnitIsGroupAssistant = nil
    assert(ready(a, 'target', 'skull') == true and a.Platform:CanSetRaidMark() == nil)
    e.UnitIsGroupAssistant = function() return false end
    e.UnitIsGroupLeader = nil
    assert(ready(a, 'target', 'skull') == true and a.Platform:CanSetRaidMark() == nil)
    e.UnitIsGroupLeader = function() return W.SECRET end
    assert(a.Platform:CanSetRaidMark() == nil, 'a hidden leader flag is not an answer')
    e.IsInRaid = nil
    assert(a.Platform:CanSetRaidMark() == nil and ready(a, 'target', 'skull') == true)
end)

test('a Set Mark step reads the unit and the mark once per poll through the readiness memo', function()
    local f, a, _, w = client('tbc')
    w:set('target', unit('G1', nil, true))
    f.load('Platform/actions.lua')
    f.load('Platform/range.lua')
    f.load('Core/action_policy.lua')
    local readiness = a:NewActionReadiness(100)
    local id = a.Platform:GetMarkActionId('target', 8)
    w.calls.GetRaidTargetIndex = 0
    assert(readiness('mark', id) == true and readiness('mark', id) == true and readiness('mark', id) == true)
    assert(w.calls.GetRaidTargetIndex == 1, 'read ' .. w.calls.GetRaidTargetIndex .. ' times in one poll')
    assert(readiness('mark', a.Platform:GetMarkActionId('target', 7)) == true)
    w.tokens.target.mark = 8
    assert(a:NewActionReadiness(101)('mark', id) == false, 'a new poll reads again')
end)

test('validation keeps a Set Mark step and flags it where the client cannot place marks', function()
    for _, name in ipairs(FAMILIES) do
        local _, a = client(name)
        local body = { name = 'Marks', priority = 0, cooldowns = {}, rotation = { step('target', 'skull') } }
        local result = a.RotationData.ValidateBody(body, a:GetRotationValidationOptions())
        assert(result.valid and result.supported and result.resolved, name)
        local fb, b = client(name, { set = false })
        local flagged = b.RotationData.ValidateBody(body, b:GetRotationValidationOptions())
        assert(flagged.valid and flagged.supported, name .. ' a Set Mark step is a known step type')
        assert(flagged.resolved == false and flagged.executionStatus == 'unavailable', name)
        local code

        for _, issue in ipairs(flagged.diagnostics) do
            if issue.code == 'unsupported-mark-step' then
                code = issue
            end
        end

        assert(
            code and code.reason == 'missing-api' and code.path:find('rotation', 1, true),
            name .. ' flagged: ' .. tostring(code and code.path)
        )

        assert(body.rotation[1].type == 'mark' and body.rotation[1].unit == 'target', 'the step is kept, not dropped')

        -- The editor and the eligibility report say why in words.
        fb.load('Core/rotation_selection.lua')
        local sentence = b:DescribeRotationIssue(code, body)
        assert(sentence and sentence:find('uses a Set Mark step this client cannot run', 1, true), tostring(sentence))
    end
end)

test('validation flags values outside the whitelists, missing fields, the optional list and a stray unit', function()
    local _, a = client('tbc')
    local options = a:GetRotationValidationOptions()

    local function codes(body)
        local found = {}

        for _, issue in ipairs(a.RotationData.ValidateBody(body, options).diagnostics) do
            found[issue.code] = true
        end

        return found
    end

    local function rotation(...)
        return { name = 'x', priority = 0, cooldowns = {}, rotation = { ... } }
    end

    assert(codes(rotation(step('target]\n/run x', 'skull')))['unsupported-mark-step'])
    assert(codes(rotation(step('target', 'purple')))['unsupported-mark-step'])
    assert(codes(rotation({ id = 'mark', type = 'mark', action = 'skull', conditions = {} }))['missing-field'])
    assert(codes(rotation({ id = 'mark', type = 'mark', unit = 'target', conditions = {} }))['missing-field'])

    assert(
        codes({
            name = 'x',
            priority = 0,
            cooldowns = { step('target', 'skull') },
            rotation = {},
        })['mark-in-optional-list']
    )

    assert(
        codes(rotation({
            id = 's',
            type = 'spell',
            action = 403,
            unit = 'target',
            conditions = {},
        }))['unexpected-mark-option']
    )

    assert(next(codes(rotation(step('target', 'none')))) == nil, 'a clearing step is valid')
end)

test('explicit repair keeps a Set Mark step whole and reports no extra field', function()
    local f = F.new()

    for _, path in ipairs({
        'Core/conditions.lua',
        'Core/condition_catalog.lua',
        'UI/condition_entrypoints.lua',
        'validate.lua',
    }) do
        f.load(path)
    end

    local warnings = {}

    f.addon.warn = function(_, message, ...)
        warnings[#warnings + 1] = string.format(message, ...)
    end

    f.addon.RotationData = dofile('tests/fixtures/rotation_data.lua')()

    local body = {
        name = 'Fixture',
        priority = 0,
        switch = {},
        cooldowns = {},
        rotation = {
            {
                id = '00000000-0000-0000-0000-000000000001',
                type = 'mark',
                unit = 'focus',
                action = 'moon',
                conditions = {},
            },
        },
    }

    f.addon:validate_rotation('Fixture', f.env.DEFAULT, body, true)

    assert(
        body.rotation[1].type == 'mark' and body.rotation[1].unit == 'focus' and body.rotation[1].action == 'moon',
        'repair changed the step'
    )

    assert(#warnings == 0, 'the step was diagnosed: ' .. table.concat(warnings, '; '))
end)

test('Bind makes the macro once, puts it on the cursor, and says why it cannot', function()
    local _, a, _, w = client('tbc')
    local ok, name = a:BeginMarkBind('target', 'skull')
    assert(ok == true and name == 'RM skull/tgt', tostring(name))
    assert(#w.macros == 1 and w.picked == 1)
    local macro = w.macros[1]
    assert(macro.name == 'RM skull/tgt' and macro.body == '/click RM_Mark_target_skull' and macro.perCharacter == true)
    assert(a.markButtons[a.Platform:GetMarkActionId('target', 8)] ~= nil, 'the button the macro presses exists')
    -- Again: the macro is reused, not duplicated.
    w.picked = nil
    ok = a:BeginMarkBind('target', 'skull')
    assert(ok and #w.macros == 1 and w.picked == 1)
    -- Another pair is another macro.
    assert(a:BeginMarkBind('focus', 'none') and #w.macros == 2 and w.macros[2].body == '/click RM_Mark_focus_none')
    w.combat = true
    local failed, why = a:BeginMarkBind('target', 'moon')
    assert(failed == false and why == 'combat' and #w.macros == 2)
    w.combat = false
    w.cursor = 'item'
    failed, why = a:BeginMarkBind('target', 'moon')
    assert(failed == false and why == 'cursor' and #w.macros == 2)
    w.cursor = nil
end)

test('Bind reports full macro lists and missing macro calls', function()
    local _, a, e, w = client('tbc')
    e.CreateMacro = function() return nil end
    local ok, why = a:BeginMarkBind('target', 'skull')
    assert(ok == false and why == 'macros-full', tostring(why))

    e.CreateMacro = function()
        error('too many macros')
    end

    ok, why = a:BeginMarkBind('target', 'skull')
    assert(ok == false and why == 'api-error', tostring(why))
    e.CreateMacro = nil
    ok, why = a:BeginMarkBind('target', 'skull')
    assert(ok == false and why == 'missing-api', tostring(why))
    local _, b, f, v = client('tbc')
    f.PickupMacro = nil
    ok, why = b:BeginMarkBind('target', 'skull')
    assert(ok == false and why == 'api-error' and #v.macros == 1, tostring(why))
    local _, c, g = client('tbc')
    g.GetMacroIndexByName = nil
    ok, why = c:BeginMarkBind('target', 'skull')
    assert(ok == false and why == 'missing-api', tostring(why))
end)

test('the source writes secure text in one place and from one template', function()
    local function read(path)
        local handle = assert(io.open(path))
        local text = handle:read('*a')
        handle:close()
        return text
    end

    local buttons = read('Core/raid_mark_buttons.lua')
    local actions = read('Platform/raid_mark_actions.lua')
    local _, setters = buttons:gsub(':SetAttribute%(', '')
    assert(setters == 2, 'SetAttribute calls in Core/raid_mark_buttons.lua: ' .. setters)
    assert(buttons:find("button:SetAttribute('macrotext', text)", 1, true), 'the macro text is the template result')
    assert(buttons:find('local text = platform:GetMarkMacroText(unit, mark)', 1, true))
    assert(not actions:find('SetAttribute', 1, true) and not actions:find('CreateFrame', 1, true))
    local _, templates = actions:gsub("MACRO_TEMPLATE = '/tm %[@%%s%] %%d'", '')
    assert(templates == 1, 'one macro template')
    assert(not read('Core/itemset_services.lua'):find('raid_mark', 1, true), 'the item set sink is untouched')
end)

-- Whole poll: the real addon in TOC order, a rotation whose first step sets a mark on your target and a spell step
-- behind it, a macro on the first action bar slot that presses the step's button.
local root = assert(io.popen('pwd'):read('*l'))

-- Builds the whole-poll world with the Set Mark platform pieces, a character whose first bar slot holds the macro and a
-- rotation named Marks that is active. options go to the whole-poll fixture. Returns the fixture, the state the test
-- steers (mark, slot, body), the pseudo spell id of the first step, and the timers the first button asked for.
local function wholePoll(options)
    options = options or {}
    options.target, options.combat, options.buttons, options.macro, options.poll = true, true, true, true, .15
    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)(options)
    local a, e = c.a, c.e

    for _, path in ipairs({
        'Platform/unit_presence.lua',
        'Platform/raid_marks.lua',
        'Platform/raid_mark_actions.lua',
        'Core/raid_mark_buttons.lua',
    }) do
        c.load(path)
    end

    local state = { mark = nil, slot = 'macro', body = '/click RM_Mark_target_skull' }
    local create = e.CreateFrame

    e.CreateFrame = function(kind, name, ...)
        local frame = create(kind, name, ...)
        frame.attributes = {}

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
        end

        function frame:GetAttribute(key)
            return self.attributes[key]
        end

        if name then
            e[name] = frame
        end

        return frame
    end

    local spells = { 403, 8042, 324, 8017 }

    e.GetActionInfo = function(slot)
        if slot == 1 and state.slot == 'macro' then
            return 'macro', 1
        end

        return 'spell', spells[slot]
    end

    e.GetMacroBody = function() return state.body end
    e.GetRaidTargetIndex = function(token) return token == 'target' and state.mark or nil end
    e.SetRaidTarget = function() end
    e.UnitIsGroupLeader = function() return false end
    e.UnitIsGroupAssistant = function() return false end
    e.IsInRaid = function() return false end
    e.GetNumGroupMembers = function() return 0 end

    -- The first button asks for a rescan through the addon timer; the test runs it by hand.
    local timers = {}

    a.ScheduleTimer = function(_, callback)
        timers[#timers + 1] = callback
        return #timers
    end

    a.CancelTimer = function() end
    a.db.profile.idle_poll = 0

    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'marks' },
    }

    assert(a:CommitRotationDraft(
        reference,
        nil,
        {
            body = {
                name = 'Marks',
                priority = 0,
                cooldowns = {},
                rotation = {
                    { id = 'mark', type = 'mark', unit = 'target', action = 'skull', conditions = {} },
                    { id = 'bolt', type = 'spell', action = 8042, conditions = {} },
                },
            },
        },
        'class'
    ))

    a:HandleCommand('set Marks')

    for _ = 1, 3 do
        c.tick()
    end

    return c, state, a.Platform:GetMarkActionId('target', 8), timers
end

test('whole poll: both engines advise the bound Set Mark button until the mark is placed', function()
    local c, state, markId, timers = wholePoll()
    local a, e = c.a, c.e

    -- The first evaluation made the button and asked for one rescan; run it as the timer would.
    assert(#timers == 1, 'one rescan was asked for: ' .. #timers)

    assert(
        e.RM_Mark_target_skull and e.RM_Mark_target_skull.attributes.macrotext == '/tm [@target] 8',
        'the button was not made'
    )

    assert(a.Platform:IsMarkActionTracking())
    a:Fetch()

    for _, engine in ipairs({ 'lean', 'standard' }) do
        assert(a:SetEvaluationEngine(engine))
        state.mark = nil
        c.tick()
        c.tick()

        assert(
            a.currentSpell == markId,
            engine .. ' the bound Set Mark button is advised: ' .. tostring(a.currentSpell)
        )

        assert(
            a:FindSpell({ markId }) == markId
                and a:GetStepBinding({ type = 'mark', unit = 'target', action = 'skull' }) == true
        )

        state.mark = 8
        c.tick()
        c.tick()
        assert(a.currentSpell == 8042, engine .. ' the mark is placed, so the next step: ' .. tostring(a.currentSpell))
        state.mark = nil
        c.tick()
        c.tick()
        assert(a.currentSpell == markId, engine .. ' the mark is gone again: ' .. tostring(a.currentSpell))
    end

    -- The macro leaves the bar: the step is not bound, so it is skipped, and the editor can say so.
    state.slot = 'spell'
    a:Fetch()
    assert(a:GetStepBinding({ type = 'mark', unit = 'target', action = 'skull' }) == false)

    for _, engine in ipairs({ 'lean', 'standard' }) do
        assert(a:SetEvaluationEngine(engine))
        c.tick()
        c.tick()
        assert(a.currentSpell == 8042, engine .. ' an unbound Set Mark step is skipped: ' .. tostring(a.currentSpell))
    end

    -- A macro that presses another button, or none, is not this step's button.
    state.slot, state.body = 'macro', '/click RM_Mark_target_cross'
    a:Fetch()
    assert(a:FindSpell({ markId }) == nil)
    assert(a:FindSpell({ a.Platform:GetMarkActionId('target', 7) }) ~= nil)
    assert(a:SetEvaluationEngine('lean'))
    assert(not a.adviceErrorReport, 'evaluation raised an error')
end)

test('whole poll: on a restricted client a Set Mark step is never matched to another button by name', function()
    local c, state, targetSkull = wholePoll()
    local a, e = c.a, c.e
    e.WOW_PROJECT_ID = e.WOW_PROJECT_MAINLINE
    state.body = '/click RM_Mark_focus_skull'
    a:Fetch()
    assert(a.Platform:GetCombatDataPolicy() == 'restricted', 'the model client is restricted now')
    local focusSkull = a.Platform:GetMarkActionId('focus', 8)
    assert(a:FindSpell({ focusSkull }) == focusSkull, 'the focus button is found by its own macro line')
    assert(a:FindSpell({ targetSkull }) == nil, 'a button for the same mark on another unit was taken for this step')
    assert(a.Platform:GetMarkActionId('target', 7) and a:FindSpell({ a.Platform:GetMarkActionId('target', 7) }) == nil)
end)

test('whole poll: the preview window shows the mark icon and a sentence, not a spell link', function()
    local c, state, markId = wholePoll({ preview = 2 })
    local a, e = c.a, c.e
    local linked, texts = false, {}

    e.GameTooltip = {
        SetOwner = function() end,
        SetHyperlink = function()
            linked = true
        end,
        SetText = function(_, text)
            texts[#texts + 1] = text
        end,
        IsOwned = function() return false end,
        Hide = function() end,
    }

    a:Fetch()
    state.mark = nil
    c.tick()
    c.tick()
    assert(a.currentSpell == markId)
    local icon = a.nextWindow.icons[1]
    assert(icon and icon.spellId == markId, 'the preview holds the Set Mark step first')
    assert(icon.texture.texture == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_8', tostring(icon.texture.texture))
    icon.scripts.OnEnter(icon)
    assert(not linked and texts[1] == 'Set Skull on your target', tostring(texts[1]))
end)

finish()
