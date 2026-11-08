-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Macro conditionals (Platform/macro_conditions.lua): only bracketed groups are accepted, never a command or a second
-- clause; the game's answer comes back as a boolean, an unreadable or missing answer is unavailable.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local secret = {}
local platform = {}

function platform:CanReadValue(value)
    return value ~= secret
end

assert(loadfile('Platform/macro_conditions.lua'))('RotationMaster', { Platform = platform })

test('only bracketed conditional groups are accepted', function()
    for _, good in ipairs({ '[combat]', ' [combat,harm] ', '[mod:shift][@focus,exists,nodead]', '[]' }) do
        assert(platform:IsMacroConditionText(good), good)
    end

    for _, bad in ipairs({
        '',
        'combat',
        '[combat] /cast Fireball',
        '[combat]; [nocombat]',
        '[combat] 1',
        '[[combat]]',
        '[combat',
        '[combat]\n/run x()',
        string.rep('[combat]', 40),
        42,
    }) do
        assert(not platform:IsMacroConditionText(bad), tostring(bad))
    end
end)

test('the game answer is a boolean; unreadable, missing or refused text is unavailable', function()
    local passed

    _G.SecureCmdOptionParse = function(text)
        passed = text
        return text == '[combat] 1' and '1' or nil
    end

    assert(platform:GetMacroConditionObservation('[combat]') == true and passed == '[combat] 1')
    assert(platform:GetMacroConditionObservation('[nocombat]') == false)
    local value, reason = platform:GetMacroConditionObservation('[combat] /cast Fireball')
    assert(value == nil and reason == 'invalid-macro-condition')
    _G.SecureCmdOptionParse = function() return secret end
    value, reason = platform:GetMacroConditionObservation('[combat]')
    assert(value == nil and reason == 'restricted-value')
    _G.SecureCmdOptionParse = nil
    value, reason = platform:GetMacroConditionObservation('[combat]')
    assert(value == nil and reason == 'missing-api')
end)

print(('%d passed, %d failed'):format(pass, fail))

if fail > 0 then
    os.exit(1)
end
