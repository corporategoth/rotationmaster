-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Restricted clients (Retail, Forever) hand addons secret values. A condition
-- runs there when its source can be readable: never-secret sources always,
-- conditionally secret ones whenever the value this poll passes CanReadValue
-- (a secret one is unavailable, also under NOT). Only always-secret or removed
-- sources are unsupported (Core/condition_support.lua). The classification and
-- its evidence: docs/restricted-clients.md. Lua cannot make a secret value, so
-- one sentinel stands in for every secret field and issecretvalue and
-- canaccessvalue recognise it.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local corpus = dofile('tests/fixtures/default_corpus.lua')
local root = assert(io.popen('pwd'):read('*l'))

local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

local function isSecret(value)
    return rawequal(value, SECRET)
end

local function canAccess(value)
    return not rawequal(value, SECRET)
end

local expansions = { [1] = 12, [18] = 12, [2] = 0, [5] = 1, [19] = 4 }

-- The real addon's conditions, evaluable, on the given client.
local function client(project, class)
    local f = corpus.load(project, expansions[project], class or 'ROGUE', { modules = false })
    local a, e = f.addon, f.env

    if type(a.Platform.GetTalentLayout) ~= 'function' then
        f.load('Platform/talents.lua')
    end

    f.load('Core/condition_support.lua')
    f.load('Platform/spells.lua')
    f.load('Platform/range.lua')

    for _, definition in pairs(a.conditionDefinitions) do
        definition.evaluate = nil
    end

    for line in io.lines('RotationMaster.toc') do
        local path = line:gsub('\r', ''):match('^%s*(Conditions/.-%.lua)%s*$')

        if path then
            f.load(path)
        end
    end

    e.issecretvalue = isSecret
    e.canaccessvalue = canAccess

    -- Universal natives these checks look for, as on every real client.
    for _, name in ipairs({
        'UnitExists', 'UnitIsPVP', 'UnitLevel', 'UnitAttackSpeed', 'UnitIsEnemy', 'UnitGUID', 'UnitCastingInfo',
        'UnitChannelInfo', 'UnitHealth', 'UnitHealthMax', 'UnitPower', 'UnitPowerMax', 'UnitPowerType',
        'UnitAffectingCombat', 'UnitCanAttack', 'UnitIsDead', 'UnitIsFriend', 'UnitIsDeadOrGhost', 'UnitClassification',
        'UnitThreatSituation', 'GetUnitSpeed', 'IsStealthed', 'HasFullControl', 'IsOutdoors', 'UnitIsUnit',
        'UnitCreatureType', 'IsInRaid', 'IsInGroup', 'UnitPosition'
    }) do
        if type(e[name]) ~= 'function' then
            e[name] = function() end
        end
    end

    e.C_CVar = e.C_CVar or { GetCVar = function() return '40' end }
    a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
    return f, a, e
end

local function status(a, condition)
    local r = a:evaluateConditionResult(condition)
    return r.status, r.reason
end

local function expect(a, condition, wanted, label)
    local got, reason = status(a, condition)

    assert(
        got == wanted,
        (label or condition.type) .. ': ' .. tostring(got) .. ' (' .. tostring(reason) .. '), wanted ' .. wanted
    )

    if wanted == 'unavailable' then
        local negated = status(a, { type = 'NOT', value = condition })
        assert(negated == 'unavailable', (label or condition.type) .. ' under NOT became ' .. tostring(negated))
    end
end

local function support(a, condition)
    return a:GetConditionSupport(condition.type, a.conditionDefinitions[condition.type], condition)
end

test('never-secret readers run on Retail and Forever and read their values', function()
    for _, project in ipairs({ 1, 18 }) do
        local _, a, e = client(project)
        e.UnitExists = function(unit) return unit == 'player' or unit == 'target' end
        e.UnitAffectingCombat = function(unit) return unit == 'player' end
        e.UnitCanAttack = function() return true end
        e.UnitIsDead = function() return false end
        e.UnitIsEnemy = function() return true end
        e.UnitIsFriend = function() return false end
        e.UnitIsDeadOrGhost = function() return false end
        e.UnitClassification = function() return 'elite' end
        e.IsStealthed = function() return false end
        e.HasFullControl = function() return true end
        e.IsOutdoors = function() return true end

        local cases = {
            { { type = 'COMBAT', unit = 'player' }, 'match' },
            { { type = 'COMBAT', unit = 'target' }, 'no-match' },
            { { type = 'ATTACKABLE', unit = 'target' }, 'match' },
            { { type = 'ENEMY', unit = 'target' }, 'match' },
            { { type = 'FRIENDLY', unit = 'target' }, 'no-match' },
            { { type = 'DEAD', unit = 'target' }, 'no-match' },
            { { type = 'CLASSIFICATION', unit = 'target', value = 'elite' }, 'match' },
            { { type = 'STEALTHED' }, 'no-match' },
            { { type = 'INCONTROL' }, 'match' },
            { { type = 'OUTDOORS' }, 'match' },
        }

        for _, case in ipairs(cases) do
            local reason = support(a, case[1])
            assert(reason == nil, case[1].type .. ' unsupported on ' .. project .. ': ' .. tostring(reason))
            expect(a, case[1], case[2], project .. ' ' .. case[1].type)
        end
    end
end)

test('conditionally secret readers read a readable value and are unavailable on a secret one', function()
    for _, project in ipairs({ 1, 18 }) do
        local _, a, e = client(project)
        e.UnitExists = function(unit) return unit == 'player' or unit == 'target' end
        e.UnitIsEnemy = function() return true end
        local state = { threat = 3, speed = 7, class = 'MAGE', same = true, pvp = false, classification = 'elite' }
        e.UnitThreatSituation = function() return state.threat end
        e.GetUnitSpeed = function() return state.speed end

        e.UnitClass = function(unit)
            if unit == 'player' then
                return 'Rogue', 'ROGUE', 4
            end

            return 'Mage', state.class, 8
        end

        e.UnitIsUnit = function() return state.same end
        e.UnitIsPVP = function() return state.pvp end
        e.UnitClassification = function() return state.classification end
        e.LOCALIZED_CLASS_NAMES_MALE = { MAGE = 'Mage', ROGUE = 'Rogue' }

        local cases = {
            { { type = 'THREAT', unit = 'target', threat = 3 }, 'threat' },
            { { type = 'MOVING' }, 'speed' },
            { { type = 'CLASS', unit = 'target', value = 'MAGE' }, 'class' },
            { { type = 'ISSAME', unit = 'target', otherunit = 'focus' }, 'same' },
            { { type = 'PVP', unit = 'target' }, 'pvp' },
            { { type = 'CLASSIFICATION', unit = 'target', value = 'elite' }, 'classification' },
        }

        for _, case in ipairs(cases) do
            assert(support(a, case[1]) == nil, case[1].type .. ' unsupported on ' .. project)
            local readable = status(a, case[1])
            assert(readable == 'match' or readable == 'no-match', case[1].type .. ' readable: ' .. tostring(readable))
            local saved = state[case[2]]
            state[case[2]] = SECRET
            expect(a, case[1], 'unavailable', project .. ' secret ' .. case[1].type)
            state[case[2]] = saved
        end
    end
end)

test('a classification the game cannot read is unavailable, not false, also under NOT', function()
    for _, project in ipairs({ 1, 18, 2 }) do
        local _, a, e = client(project)
        e.UnitExists = function(unit) return unit == 'target' end
        local condition = { type = 'CLASSIFICATION', unit = 'target', value = 'elite' }
        e.UnitClassification = function() return 'elite' end
        expect(a, condition, 'match', project .. ' readable classification')

        e.UnitClassification = function()
            error('classification unavailable')
        end

        expect(a, condition, 'unavailable', project .. ' failing UnitClassification')
    end
end)

test('a secret cast name still proves a cast; what it hides is unavailable', function()
    local _, a, e = client(1)
    e.UnitExists = function() return true end
    local cast = {'Fireball', 'Fireball', 1, 90000, 103000, false, 'cast-1', false, 133}
    e.UnitCastingInfo = function() return unpack(cast, 1, 9) end
    expect(a, { type = 'CASTING', unit = 'target' }, 'match')
    expect(a, { type = 'CAST_INTERRUPTABLE', unit = 'target' }, 'match')
    expect(a, { type = 'CASTING_SPELL', unit = 'target', spell = 'Fireball' }, 'match')
    cast[1] = SECRET
    cast[8] = SECRET
    expect(a, { type = 'CASTING', unit = 'target' }, 'match', 'secret name: casting')

    expect(
        a,
        { type = 'CASTING_SPELL', unit = 'target', spell = 'Fireball' },
        'unavailable',
        'secret name: spell by name'
    )

    expect(a, { type = 'CAST_INTERRUPTABLE', unit = 'target' }, 'unavailable', 'secret interruptibility')
    expect(a, { type = 'CASTING_SPELL', unit = 'target', spell = 133, ranked = true }, 'match', 'readable spell ID')
    cast[9] = SECRET
    expect(a, { type = 'CASTING_SPELL', unit = 'target', spell = 133, ranked = true }, 'unavailable', 'secret spell ID')
    e.UnitCastingInfo = function() return nil end
    expect(a, { type = 'CASTING', unit = 'target' }, 'no-match', 'no cast')
end)

test('always-secret and removed sources stay unsupported; restrictions and power flags decide', function()
    local unsupported = {
        { { type = 'HEALTH', unit = 'player', operator = 'GREATERTHAN', value = 1 }, 'secret-health' },
        { { type = 'HEALTHPCT', unit = 'target', operator = 'LESSTHAN', value = 0.2 }, 'secret-health' },
        { { type = 'TT_HEALTH', unit = 'target', operator = 'LESSTHAN', value = 5 }, 'secret-health' },
        { { type = 'PROXIMITY_HEALTHPCT_COUNT' }, 'secret-health' },
        { { type = 'SWING_TIME_REMAIN', operator = 'LESSTHAN', value = 1 }, 'combat-log-unavailable' },
        { { type = 'MANA', unit = 'player', operator = 'GREATERTHAN', value = 1 }, 'secret-power' },
        { { type = 'MANAPCT', unit = 'player', operator = 'GREATERTHAN', value = 0.5 }, 'secret-power' },
        { { type = 'POWER', unit = 'player', operator = 'GREATERTHAN', value = 1 }, 'secret-power' },
    }

    for _, project in ipairs({ 1, 18 }) do
        local _, a, e = client(project)

        for _, case in ipairs(unsupported) do
            local reason = support(a, case[1])
            assert(reason == case[2], project .. ' ' .. case[1].type .. ': ' .. tostring(reason))

            assert(a:DescribeUnsupportedCondition({
                code = 'unsupported-condition',
                condition = case[1].type,
                reason = reason,
            }):find('not available on this client', 1, true))
        end

        -- With restrictions off, health reads; the combat log stays removed.
        e.C_Secrets = { HasSecretRestrictions = function() return false end }

        assert(
            support(a, unsupported[1][1]) == nil and support(a, unsupported[6][1]) == nil,
            'restrictions off still unsupported'
        )

        assert(support(a, unsupported[3][1]) == 'combat-log-unavailable', 'TT_HEALTH needs the combat log')
        assert(support(a, unsupported[5][1]) == 'combat-log-unavailable')
        -- An unreadable answer is restricted.
        e.C_Secrets = { HasSecretRestrictions = function() return SECRET end }
        assert(support(a, unsupported[1][1]) == 'secret-health', 'an unreadable restriction answer was trusted')
        -- Power follows Blizzard's per-type flag (0 = NeverSecret).
        local flags = {}

        e.C_Secrets = {
            HasSecretRestrictions = function() return true end,
            GetPowerTypeSecrecy = function(id) return flags[id] or 2 end,
        }

        assert(support(a, unsupported[6][1]) == 'secret-power' and support(a, unsupported[8][1]) == 'secret-power')
        flags[e.Enum.PowerType.Energy] = 0
        assert(support(a, unsupported[6][1]) == 'secret-power', 'Energy flagged never secret freed Mana')
        assert(support(a, unsupported[8][1]) == nil, 'a never-secret primary power leaves POWER supported')
        flags[e.Enum.PowerType.Mana] = 0

        assert(
            support(a, unsupported[6][1]) == nil and support(a, unsupported[7][1]) == nil,
            'never-secret Mana still unsupported'
        )
    end

    -- Era, TBC and Mists never consult the secret predicates.
    for _, project in ipairs({ 2, 5, 19 }) do
        local _, a, e = client(project)

        e.C_Secrets = {
            HasSecretRestrictions = function()
                error('probe client consulted restrictions')
            end,
        }

        for _, case in ipairs(unsupported) do
            local reason = support(a, case[1])
            assert(reason == nil or reason == 'missing-api', project .. ' ' .. case[1].type .. ': ' .. tostring(reason))
        end
    end
end)

test('a secret power value is unavailable even where the power is supported', function()
    local _, a, e = client(1)
    e.C_Secrets = { HasSecretRestrictions = function() return true end, GetPowerTypeSecrecy = function() return 0 end }
    e.UnitExists = function() return true end
    local state = { power = 50, maximum = 100 }
    e.UnitPowerType = function() return 3 end
    e.UnitPower = function() return state.power end
    e.UnitPowerMax = function() return state.maximum end
    local condition = { type = 'POWER', unit = 'player', operator = 'GREATERTHAN', value = 10 }
    assert(support(a, condition) == nil)
    expect(a, condition, 'match')
    state.power = SECRET
    expect(a, condition, 'unavailable', 'secret power')
end)

test('histories record unreadable entries as unknown, never as absent', function()
    local _, a, e = client(1)
    e.C_Spell = e.C_Spell or {}
    e.C_Spell.GetSpellInfo = function(id) return { name = 'Spell ' .. id, spellID = id, iconID = 1 } end
    a.db.profile.spell_history = 60
    a.db.profile.combat_history = 10
    local spell = { type = 'SPELL_HISTORY', spell = 133, operator = 'LESSTHANOREQUALS', value = 1 }

    local function readable(result)
        return result == 'match' or result == 'no-match'
    end

    a.spellHistory = { { spell = 133, time = 99 } }
    assert(status(a, spell) == 'match', 'readable cast not found')
    a.spellHistory = { { spell = false, time = 99 } }
    expect(a, spell, 'unavailable', 'secret cast at the position')
    a.spellHistory = { { spell = false, time = 99 }, { spell = 133, time = 98 } }

    assert(
        status(a, { type = 'SPELL_HISTORY', spell = 133, operator = 'LESSTHANOREQUALS', value = 2 }) == 'match',
        'a later readable match is decisive'
    )

    a.spellHistory = { { spell = 21, time = 99 }, { spell = false, time = 98 } }
    assert(status(a, spell) == 'no-match', 'a secret cast beyond the window matters')
    local timed = { type = 'SPELL_HISTORY_TIME', spell = 133, operator = 'LESSTHAN', value = 5 }
    a.spellHistory = { { spell = false, time = 99 } }
    expect(a, timed, 'unavailable', 'secret cast within the time window')
    a.spellHistory = { { spell = false, time = 10 } }
    assert(readable(status(a, timed)), 'a secret cast outside the time window')

    local combat = {
        type = 'COMBAT_HISTORY',
        unit = 'target',
        action = 'WOUND',
        operator = 'LESSTHANOREQUALS',
        value = 1,
    }

    a.combatHistory = { target = { { time = 99, action = 'WOUND' } } }
    assert(status(a, combat) == 'match')
    a.combatHistory = { target = { { time = 99, action = false } } }
    expect(a, combat, 'unavailable', 'unreadable combat action')

    local combatTime = {
        type = 'COMBAT_HISTORY_TIME',
        unit = 'target',
        action = 'WOUND',
        operator = 'LESSTHAN',
        value = 5,
    }

    expect(a, combatTime, 'unavailable', 'unreadable combat action within the window')
    a.combatHistory = { target = { { time = 99, action = 'DODGE' } } }
    assert(status(a, combatTime) == 'no-match')
end)

test('Threat Count and Distance Count read nameplate tokens on restricted clients', function()
    local f, a, e = client(1)
    a.nameplateUnits = { nameplate1 = true, nameplate2 = true, nameplate3 = true }
    local live = { nameplate1 = true, nameplate2 = true }
    local threat = { nameplate1 = 3, nameplate2 = 1 }
    e.UnitExists = function(unit) return live[unit] == true end
    e.UnitIsEnemy = function() return true end
    e.UnitThreatSituation = function(_, unit) return threat[unit] end

    e.UnitGUID = function()
        error('an NPC GUID is secret there; it must not be read')
    end

    f.libraries['LibRangeCheck-3.0'].GetRange = function(_, unit)
        if unit == 'nameplate1' then
            return 0, 8
        end

        return 20, 25
    end

    local count = { type = 'THREAT_COUNT', threat = 3, operator = 'EQUALS', value = 1 }
    assert(support(a, count) == nil)
    expect(a, count, 'match')
    expect(a, { type = 'THREAT_COUNT', threat = 2, operator = 'EQUALS', value = 2 }, 'match', 'threat at least 1')
    threat.nameplate2 = SECRET
    expect(a, count, 'unavailable', 'secret threat on one plate')
    threat.nameplate2 = 1
    local near = { type = 'DISTANCE_COUNT', value = 1, operator = 'EQUALS', distance = 10, enemy = true }
    assert(support(a, near) == nil)
    expect(a, near, 'match')
    f.libraries['LibRangeCheck-3.0'].GetRange = function() return 0, SECRET end
    expect(a, near, 'unavailable', 'secret range')
    a.nameplateUnits = { [SECRET] = true }
    expect(a, count, 'unavailable', 'secret token')
end)

-- The startup suite's main.lua fixture (WoW's API surface only).
local function startupFixture()
    local h = assert(io.open('tests/startup.lua'))
    local text = h:read('*a')
    h:close()
    local common = assert(text:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
    return assert(loadstring(common .. '\nreturn fixture, initialize', '@startup-fixture'))()
end

test('restricted event handlers record readable payloads and skip secret ones', function()
    local fixture, initialize = startupFixture()
    local e, a, load = fixture()
    e.WOW_PROJECT_ID = 1
    e.WOW_PROJECT_CAMELOT = 18
    load('main.lua')
    initialize(a)
    a.debug = function() end
    e.issecretvalue = isSecret
    e.canaccessvalue = canAccess

    assert(
        a.Platform:GetCombatDataPolicy() == 'restricted' and type(a.nameplateUnits) == 'table',
        'restricted clients keep nameplate tokens'
    )

    a.historyWanted.combat = math.huge
    e.GetTime = function() return 100 end

    e.UnitGUID = function()
        error('restricted nameplate events must not read a GUID')
    end

    a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(a.nameplateUnits.nameplate1 == true)
    a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED', SECRET)
    assert(next(a.nameplateUnits, next(a.nameplateUnits)) == nil, 'secret token kept')
    a:NAME_PLATE_UNIT_REMOVED('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(next(a.nameplateUnits) == nil)
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-1', 133)
    assert(a.spellHistory[1].spell == 133)
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED', 'pet', 'cast-2', SECRET)
    assert(a.spellHistory[1].spell == false, 'a secret cast is not unknown')
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED', 'target', 'cast-3', 5)
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED', SECRET, 'cast-4', 5)
    assert(#a.spellHistory == 2, 'another unit or a secret unit was recorded')
    a:UNIT_COMBAT('UNIT_COMBAT', 'target', 'WOUND', nil, 10, 1)
    assert(a.combatHistory.target[1].action == 'WOUND' and a.combatHistory.target[1].value == 10)
    a:UNIT_COMBAT('UNIT_COMBAT', 'target', SECRET, nil, SECRET, 1)
    local entry = a.combatHistory.target[1]
    assert(entry.action == false and entry.value == nil and entry.type == 1, 'unreadable combat action')
    a:UNIT_COMBAT('UNIT_COMBAT', SECRET, 'WOUND', nil, 10, 1)
    assert(#a.combatHistory.target == 2)

    e.CombatLogGetCurrentEventInfo = function()
        error('the combat log is not read on restricted clients')
    end

    a:COMBAT_LOG_EVENT_UNFILTERED('COMBAT_LOG_EVENT_UNFILTERED')
    -- Enabling seeds the shown nameplates and registers the restricted events.
    local registered = {}

    a.RegisterEvent = function(_, event)
        registered[event] = true
    end

    a.UpdateSkill = function() end
    a.EnableRotation = function() end
    e.CreateFrame = nil
    e.UnitExists = function(unit) return unit == 'nameplate2' or unit == 'nameplate7' end
    a:enable()

    assert(
        a.nameplateUnits.nameplate2 and a.nameplateUnits.nameplate7 and not a.nameplateUnits.nameplate1,
        'shown nameplates not seeded'
    )

    assert(
        registered.UNIT_SPELLCAST_SUCCEEDED
            and registered.UNIT_COMBAT
            and registered.NAME_PLATE_UNIT_ADDED
            and not registered.COMBAT_LOG_EVENT_UNFILTERED
    )

    -- A probe client keeps no token set.
    local pe, pa, pload = fixture()
    pload('main.lua')
    initialize(pa)
    assert(pe.WOW_PROJECT_ID == 5 and pa.nameplateUnits == nil)
end)

-- Lean and standard evaluation see the same availability: a never-secret
-- condition decides, a secret one skips its step (Mainline secret model on
-- the whole-poll fixture).
test('lean and standard engines agree on secret and readable values', function()
    local function run(engine)
        local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)({
            target = true,
            combat = true,
            buttons = true,
            poll = .15,
        })

        local a, e = c.a, c.e

        local reference = {
            kind = 'custom',
            address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'secret' },
        }

        assert(a:CommitRotationDraft(
            reference,
            nil,
            {
                body = {
                    name = 'Secret',
                    priority = 0,
                    cooldowns = {},
                    rotation = {
                        {
                            id = 'threat',
                            type = 'spell',
                            action = 8042,
                            conditions = { type = 'THREAT', unit = 'target', threat = 1 },
                        },
                        {
                            id = 'combat',
                            type = 'spell',
                            action = 403,
                            conditions = { type = 'COMBAT', unit = 'player' },
                        },
                    },
                },
            },
            'class'
        ))

        a:HandleCommand('set Secret')
        assert(a:SetEvaluationEngine(engine))
        e.issecretvalue = isSecret
        e.canaccessvalue = canAccess
        a.Platform.secretsUnrestricted = false

        a.Platform.CanReadValue = function(_, v)
            if isSecret(v) or not canAccess(v) then
                return false, 'restricted-value'
            end

            return true
        end

        local threat = 3
        e.UnitThreatSituation = function() return threat end
        local seen = {}

        for _ = 1, 3 do
            c.tick()
        end

        seen[1] = a.currentSpell
        threat = SECRET

        for _ = 1, 2 do
            c.tick()
        end

        seen[2] = a.currentSpell
        threat = 0

        for _ = 1, 2 do
            c.tick()
        end

        seen[3] = a.currentSpell
        assert(not a.adviceErrorReport and #a.Diagnostics:GetReports() == 0, engine .. ' raised an error')
        return seen
    end

    local lean, standard = run('lean'), run('standard')

    for i = 1, 3 do
        assert(
            lean[i] == standard[i],
            'poll ' .. i .. ': lean ' .. tostring(lean[i]) .. ' vs standard ' .. tostring(standard[i])
        )
    end

    assert(standard[2] == 403, 'a secret threat did not skip its step: ' .. tostring(standard[2]))
end)

test('the support table, the conditions and the restricted-client document agree', function()
    local text = assert(io.open('docs/restricted-clients.md')):read('*a')
    local documented = {}

    for tag in text:gmatch('\n| `([A-Z_]+)`') do
        documented[tag] = true
    end

    -- Conditions register per edition; every one has a row.
    for _, project in ipairs({ 1, 18, 2, 5, 19 }) do
        local _, a = client(project)

        for tag, definition in pairs(a.conditionDefinitions) do
            if tag ~= 'NOT' and tag ~= 'AND' and tag ~= 'OR' and tag ~= 'DELETE' and not definition.customCode then
                assert(documented[tag], tag .. ' has no row in docs/restricted-clients.md')
            end
        end

        for tag, list in pairs(a.conditionRequirements) do
            for _, requirement in ipairs(list) do
                assert(requirement ~= 'probe', 'the probe-only gate is gone: ' .. tag)
            end
        end
    end
end)

finish()
