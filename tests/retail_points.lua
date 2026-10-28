-- Retail (and Forever) POINT: class secondary resources under the restricted
-- combat-data policy. UnitPower and GetComboPoints are
-- SecretWhenUnitPowerRestricted ("secret values for power types not explicitly
-- flagged as being never secret, unless the subject unit does not have a power
-- of this type"); UnitPowerMax is SecretWhenUnitPowerMaxRestricted (secret
-- "when the unit isn't player-controlled"). Gethe/wow-ui-source live e7aa82019d
-- (12.1.5.70529) and forever ca8368f2f2 (1.60.1.70532), UnitDocumentation.lua
-- and SecretPredicatesDocumentation.lua, identical on both. Blizzard named the
-- player's secondary resources that are no longer secret: Combo Points, Runes,
-- Soul Shards, Holy Power, Chi, Arcane Charges and Essence.
-- Lua cannot make a secret number, so one sentinel stands in for every secret
-- value and issecretvalue/canaccessvalue recognise it.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })
local RETAIL, TBC, ERA, PROGRESSION, FOREVER, UNKNOWN = 1, 5, 2, 19, 18, 999

-- PowerTypeConstantsDocumentation.lua (identical on live and forever).
local POWER = {
    Mana = 0,
    Rage = 1,
    Focus = 2,
    Energy = 3,
    ComboPoints = 4,
    Runes = 5,
    RunicPower = 6,
    SoulShards = 7,
    LunarPower = 8,
    HolyPower = 9,
    Alternate = 10,
    Maelstrom = 11,
    Chi = 12,
    Insanity = 13,
    BurningEmbers = 14,
    DemonicFury = 15,
    ArcaneCharges = 16,
    Fury = 17,
    Pain = 18,
    Essence = 19,
    RuneBlood = 20,
    RuneFrost = 21,
    RuneUnholy = 22,
    AlternateQuest = 23,
    AlternateEncounter = 24,
    AlternateMount = 25,
    Balance = 26,
    Happiness = 27,
    ShadowOrbs = 28,
    RuneChromatic = 29,
}

local CLASSES = {
    'DEATHKNIGHT', 'DEMONHUNTER', 'DRUID', 'EVOKER', 'HUNTER', 'MAGE', 'MONK', 'PALADIN', 'PRIEST', 'ROGUE', 'SHAMAN',
    'WARLOCK', 'WARRIOR'
}

local function fixture(project, class, expansion)
    local f = F.new(project, expansion or 1, class or 'PALADIN')
    local a, e = f.addon, f.env
    local types = {}

    for name, id in pairs(POWER) do
        types[name] = id
    end

    e.Enum.PowerType = types
    local s = { calls = {}, class = class or 'PALADIN', exists = true, current = 3, maximum = 5, combo = 2 }

    local function call(k, ...)
        s.calls[#s.calls + 1] = { k, ... }
        return s[k]
    end

    e.issecretvalue = function(v) return rawequal(v, SECRET) end
    e.canaccessvalue = function(v) return not rawequal(v, SECRET) end
    e.UnitExists = function(unit) return call('exists', unit) end

    e.UnitClass = function(unit)
        call('class', unit)
        return 'Class', s.class
    end

    e.UnitPower = function(unit, p) return call('current', unit, p) end
    e.UnitPowerMax = function(unit, p) return call('maximum', unit, p) end
    e.GetComboPoints = function(unit, target) return call('combo', unit, target) end

    e.UnitPowerType = function()
        error('POINT never reads the primary power type')
    end

    f.load('constants.lua')

    for _, p in ipairs({
        'Platform/points.lua', 'Core/point_conditions.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua',
        'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua',
        'Conditions/stats.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua',
        'Core/function_data.lua'
    }) do
        f.load(p)
    end

    s.calls = {}
    return f, a, s
end

local function node(value, unit, operator)
    return { type = 'POINT', unit = unit or 'player', operator = operator or 'EQUALS', value = value or 3 }
end

local function status(a, n)
    return a:evaluateConditionResult(n).status
end

local function count(s, k)
    local n = 0

    for _, c in ipairs(s.calls) do
        if c[1] == k then
            n = n + 1
        end
    end

    return n
end

local function unknown(a, n)
    local r = a:evaluateConditionResult(n)
    assert(r.status == 'unavailable', 'became actionable: ' .. r.status)
    r = a:evaluateConditionResult({ type = 'NOT', value = n })
    assert(r.status == 'unavailable', 'NOT became actionable: ' .. r.status)
end

-- The native reads for one evaluation, flattened for exact comparison.
local function trace(s)
    local out = {}

    for _, c in ipairs(s.calls) do
        out[#out + 1] = table.concat({ tostring(c[1]), tostring(c[2]), tostring(c[3]) }, ':')
    end

    return table.concat(out, ' ')
end

-- Expected selection per edition. TBC's player Combo Points (the map's
-- fallback) go through GetComboPoints('player','target'), as before.
local RETAIL_MAP = {
    DEATHKNIGHT = POWER.Runes,
    WARLOCK = POWER.SoulShards,
    MONK = POWER.Chi,
    MAGE = POWER.ArcaneCharges,
    PALADIN = POWER.HolyPower,
    EVOKER = POWER.Essence,
}

local CLASSIC_MAP = {
    DEATHKNIGHT = POWER.Runes,
    WARLOCK = POWER.SoulShards,
    MONK = POWER.Chi,
    MAGE = POWER.ArcaneCharges,
}

test('constants: Retail adds Holy Power and Essence; every other edition keeps the four-entry map', function()
    for _, project in ipairs({ RETAIL, TBC, ERA, PROGRESSION, FOREVER, UNKNOWN }) do
        local _, a = fixture(project)
        local want = project == RETAIL and RETAIL_MAP or CLASSIC_MAP
        local n = 0

        for class, id in pairs(a.points) do
            n = n + 1
            assert(want[class] == id, project .. ' ' .. class)
        end

        local m = 0

        for _ in pairs(want) do
            m = m + 1
        end

        assert(n == m, 'project ' .. project .. ' map has ' .. n .. ' entries')
    end
end)

test('mapping: each Retail class reads its own resource from the player in combat', function()
    for _, class in ipairs(CLASSES) do
        local _, a, s = fixture(RETAIL, class)
        assert(status(a, node(3)) == 'match', class)
        local want = RETAIL_MAP[class] or POWER.ComboPoints
        assert(trace(s) == 'exists:player:nil class:player:nil current:player:' .. want, class .. ': ' .. trace(s))
    end
end)

test('mapping: Forever reads the classic map through UnitPower, never the TBC target transport', function()
    for _, class in ipairs(CLASSES) do
        local _, a, s = fixture(FOREVER, class)
        assert(status(a, node(3)) == 'match', class)
        local want = CLASSIC_MAP[class] or POWER.ComboPoints
        assert(trace(s) == 'exists:player:nil class:player:nil current:player:' .. want, class .. ': ' .. trace(s))
    end
end)

test('mapping: TBC decisions and native calls are unchanged (player combo on target, others UnitPower)', function()
    for _, class in ipairs(CLASSES) do
        local _, a, s = fixture(TBC, class)
        local mapped = CLASSIC_MAP[class]

        if mapped then
            assert(status(a, node(3)) == 'match', class)

            assert(
                trace(s) == 'exists:player:nil class:player:nil current:player:' .. mapped,
                class .. ': ' .. trace(s)
            )
        else
            assert(status(a, node(2)) == 'match', class)
            assert(trace(s) == 'exists:player:nil class:player:nil combo:player:target', class .. ': ' .. trace(s))
        end

        -- Deficit: one more native read, the maximum of the same type.
        _, a, s = fixture(TBC, class)
        local want = mapped and 'current:player:' .. mapped or 'combo:player:target'
        assert(status(a, node(-(mapped and 2 or 3))) == 'match', class)

        assert(
            trace(s)
                == 'exists:player:nil class:player:nil ' .. want .. ' maximum:player:' .. (mapped or POWER.ComboPoints),
            class .. ': ' .. trace(s)
        )

        -- Other units keep UnitPower on the configured unit.
        _, a, s = fixture(TBC, class)
        assert(status(a, node(3, 'target')) == 'match' and count(s, 'combo') == 0, class)
        assert(s.calls[#s.calls][2] == 'target' and s.calls[#s.calls][3] == (mapped or POWER.ComboPoints), class)
    end
end)

-- Era and progression no longer use the classic map or its Combo Points
-- fallback: they select per expansion and specialization (tests/progression_points.lua).
test('mapping: Era and progression select per edition, never the classic map fallback', function()
    local want = {
        [ERA] = { ROGUE = POWER.ComboPoints },
        [PROGRESSION] = { ROGUE = POWER.ComboPoints, PALADIN = POWER.HolyPower },
    }

    for _, project in ipairs({ ERA, PROGRESSION }) do
        for _, class in ipairs({ 'PALADIN', 'EVOKER', 'ROGUE', 'MAGE' }) do
            local _, a, s = fixture(project, class, project == ERA and 0 or 4)
            local id = want[project][class]

            if id then
                assert(status(a, node(3)) == 'match', class)

                assert(
                    trace(s) == 'exists:player:nil class:player:nil current:player:' .. id,
                    project .. ' ' .. class .. ': ' .. trace(s)
                )
            else
                unknown(a, node(3))
                assert(count(s, 'current') == 0 and count(s, 'maximum') == 0, project .. ' ' .. class)
            end
        end
    end
end)

test('restricted: a readable count decides, deficit included, with the player maximum', function()
    local _, a, s = fixture(RETAIL, 'PALADIN')
    s.current = 4
    assert(status(a, node(4)) == 'match')
    assert(status(a, node(3)) == 'no-match')
    assert(status(a, node(3, 'player', 'GREATERTHANOREQUALS')) == 'match')
    s.calls = {}
    assert(status(a, node(-1)) == 'match')
    assert(count(s, 'maximum') == 1 and s.calls[#s.calls][2] == 'player' and s.calls[#s.calls][3] == POWER.HolyPower)
    s.current = 0
    assert(status(a, node(0)) == 'match' and status(a, { type = 'NOT', value = node(3) }) == 'match')
end)

test('restricted: a secret count or maximum is unavailable, never a number', function()
    for _, project in ipairs({ RETAIL, FOREVER }) do
        local _, a, s = fixture(project, 'ROGUE')
        s.current = SECRET
        unknown(a, node(3))
        unknown(a, node(0))
        unknown(a, node(-2))
        _, a, s = fixture(project, 'ROGUE')
        s.maximum = SECRET
        assert(status(a, node(3)) == 'match', 'a positive comparison needs no maximum')
        unknown(a, node(-2))
        local point, why = a.Platform:GetUnitPointPowerObservation('player', POWER.ComboPoints, 'maximum')
        assert(point == nil and why == 'restricted-value')
    end
end)

test('restricted: a secret or missing identity is unavailable; an absent unit is known absence', function()
    local _, a, s = fixture(RETAIL, 'MAGE')
    s.class = SECRET
    unknown(a, node(3, 'target'))
    assert(count(s, 'current') == 0)
    _, a, s = fixture(RETAIL, 'MAGE')
    s.exists = SECRET
    unknown(a, node(3, 'target'))
    assert(count(s, 'class') == 0)
    _, a, s = fixture(RETAIL, 'MAGE')
    s.exists = false
    assert(status(a, node(3, 'target')) == 'no-match' and count(s, 'current') == 0)
end)

test('restricted: a power type not proven never secret is not read', function()
    for _, primary in ipairs({
        'Mana', 'Rage', 'Focus', 'Energy', 'RunicPower', 'LunarPower', 'Maelstrom', 'Insanity', 'Fury', 'Pain'
    }) do
        local _, a, s = fixture(RETAIL, 'ROGUE')
        a.points.ROGUE = POWER[primary]
        local v, why = a.conditionDefinitions.POINT.evaluate(node(3), {})
        assert(v == nil and why == 'unsupported-policy', primary .. ': ' .. tostring(why))
        assert(count(s, 'current') == 0 and count(s, 'maximum') == 0, primary)
        unknown(a, node(3))
        local point, reason = a.Platform:GetUnitPointPowerObservation('player', POWER[primary], 'current')
        assert(point == nil and reason == 'unsupported-policy' and count(s, 'current') == 0, primary)
        -- TBC reads an explicitly mapped type exactly as before.
        _, a, s = fixture(TBC, 'ROGUE')
        a.points.ROGUE = POWER[primary]
        assert(status(a, node(3)) == 'match' and count(s, 'current') == 1 and count(s, 'combo') == 0, primary)
    end
end)

test('platform: the never-secret set is resolved by Enum name and guarded', function()
    local _, a = fixture(RETAIL)
    local p = a.Platform

    for _, name in ipairs({ 'ComboPoints', 'Runes', 'SoulShards', 'HolyPower', 'Chi', 'ArcaneCharges', 'Essence' }) do
        assert(p:IsNeverSecretPointPower(POWER[name]) == true, name)
    end

    for name, id in pairs(POWER) do
        local listed = ({
            ComboPoints = 1,
            Runes = 1,
            SoulShards = 1,
            HolyPower = 1,
            Chi = 1,
            ArcaneCharges = 1,
            Essence = 1,
        })[name]

        if not listed then
            assert(p:IsNeverSecretPointPower(id) == false, name)
        end
    end

    for _, bad in ipairs({ SECRET, '9', 9.5, -1, false }) do
        assert(p:IsNeverSecretPointPower(bad) == false, tostring(bad))
    end

    local f2, a2 = fixture(RETAIL)
    f2.env.Enum.PowerType.HolyPower = nil
    assert(a2.Platform:IsNeverSecretPointPower(9) == false, 'a number is never assumed without its Enum name')
    f2.env.Enum.PowerType.Chi = SECRET
    assert(a2.Platform:IsNeverSecretPointPower(12) == false)
    f2.env.Enum.PowerType = SECRET
    assert(a2.Platform:IsNeverSecretPointPower(4) == false)
end)

test('policy: unsupported clients and the archived V1 API stay unavailable without native reads', function()
    local _, a, s = fixture(UNKNOWN, 'ROGUE')
    unknown(a, node(3))
    assert(#s.calls == 0)

    for _, project in ipairs({ RETAIL, FOREVER }) do
        _, a, s = fixture(project, 'ROGUE')
        local point, why = a:GetConditionPointResource('player', {})
        assert(point == nil and why == 'unsupported-policy' and #s.calls == 0, 'old sources keep their policy')
    end
end)

test('cache: one pass reads each native once; a new pass sees new values', function()
    local _, a, s = fixture(RETAIL, 'EVOKER')
    local eval = a.conditionDefinitions.POINT.evaluate
    local cache = {}

    assert(
        eval(node(3), cache) == true
            and eval(node(-2), cache) == true
            and eval(node(3, 'player', 'GREATERTHAN'), cache) == false
    )

    assert(count(s, 'exists') == 1 and count(s, 'class') == 1 and count(s, 'current') == 1 and count(s, 'maximum') == 1)
    s.current = 5
    assert(eval(node(3), cache) == true, 'same pass keeps its observation')
    assert(eval(node(5), {}) == true)
end)

finish()
