-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (and Forever) combat readiness: while addon restrictions are in
-- effect C_Spell.GetSpellCooldown hides startTime/duration/modRate
-- (SecretWhenCooldownsRestricted) but never isEnabled/isActive/isOnGCD
-- (NeverSecret). Modelled from Blizzard's generated API documentation,
-- Gethe/wow-ui-source live e7aa82019d (12.1.5.70529) and forever ca8368f2f2
-- (1.60.1.70532): SpellDocumentation.lua and SpellSharedDocumentation.lua.
-- Lua cannot make a secret number, so one unique sentinel stands in for every
-- hidden field and issecretvalue/canaccessvalue recognise it.
local F = dofile('tests/fixtures/addon.lua')
local platformFixture = dofile('tests/fixtures/platform.lua')
local test, finish = F.suite()
local root = assert(io.popen('pwd'):read('*l'))

local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

local function isSecret(value)
    return rawequal(value, SECRET)
end

local function canAccess(value)
    return not rawequal(value, SECRET)
end

-- A SpellCooldownInfo as Retail returns it in combat. flags.secret hides the
-- flags as well, which the documentation rules out but RM must survive.
local function hidden(flags)
    if flags.secret then
        return {
            startTime = SECRET,
            duration = SECRET,
            modRate = SECRET,
            isEnabled = SECRET,
            isActive = SECRET,
            isOnGCD = SECRET,
        }
    end

    local enabled = flags.enabled

    if enabled == nil then
        enabled = true
    end

    return {
        startTime = SECRET,
        duration = SECRET,
        modRate = SECRET,
        isEnabled = enabled,
        isActive = flags.active == true,
        isOnGCD = flags.onGCD,
    }
end

local GCD_IDS = { [29515] = true, [61304] = true }

local function retailPlatform(records)
    local p, e = platformFixture({
        WOW_PROJECT_ID = 1,
        WOW_PROJECT_MAINLINE = 1,
        issecretvalue = isSecret,
        canaccessvalue = canAccess,
        C_Spell = {
            GetSpellCooldown = function(id)
                local r = records[id]

                if r == nil and GCD_IDS[id] then
                    r = records.gcd
                end

                return r
            end,
        },
    })

    assert(not p.secretsUnrestricted, 'a Mainline model must keep the secret checks')
    return p, e
end

test('platform: with the times secret, the never-secret flags decide readiness as the times would', function()
    local records = { gcd = hidden({ active = true, onGCD = true }) }
    local p = retailPlatform(records)
    records[8042] = hidden({ active = false })
    assert(p:IsSpellReady(8042, 100) == true, 'an inactive cooldown is ready')
    records[8042] = hidden({ active = true, onGCD = true })
    assert(p:IsSpellReady(8042, 100) == true, 'a spell only on the global cooldown is ready')
    records[8042] = hidden({ active = true, onGCD = false })
    assert(p:IsSpellReady(8042, 100) == false, 'a spell on its own cooldown is not ready')
    records[8042] = hidden({ enabled = false, active = false })
    assert(p:IsSpellReady(8042, 100) == false, 'a held cooldown is not ready')
    -- The record itself stays unavailable: its times were not read.
    records[8042] = hidden({ active = true, onGCD = true })
    local cooldown, why, enabled, active, onGCD = p:GetSpellCooldown(8042)

    assert(
        cooldown == nil and why == 'restricted-value' and enabled == true and active == true and onGCD == true,
        'flags not reported after the reason'
    )
end)

test('platform: secret, malformed or missing flags leave readiness unavailable', function()
    local records = { gcd = hidden({ active = true, onGCD = true }) }
    local p = retailPlatform(records)
    records[8042] = hidden({ secret = true })
    local ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'secret flags: ' .. tostring(ready))
    local cooldown, reason, enabled = p:GetSpellCooldown(8042)
    assert(cooldown == nil and reason == 'restricted-value' and enabled == nil)
    records[8042] = { startTime = SECRET, duration = SECRET, isEnabled = true, modRate = 1 }
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'a client without isActive was guessed')
    records[8042] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = 1, modRate = 1 }
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'a malformed flag was trusted')
    records[8042] = hidden({ active = true, onGCD = 'yes' })
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value')
    records[8042] = SECRET
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'a secret record')
    records[8042] = nil
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'spell-data-unavailable')
end)

test('platform: isOnGCD is held against the global cooldown itself', function()
    local records = {}
    local p = retailPlatform(records)
    -- "On the GCD" while no GCD runs is a stale flag: the cooldown is the spell's own.
    records.gcd = hidden({ active = false })
    records[8042] = hidden({ active = true, onGCD = true })
    assert(p:IsSpellReady(8042, 100) == false, 'stale isOnGCD trusted with the GCD idle')
    -- isOnGCD unreported: an idle GCD settles it, a running one does not.
    records[8042] = hidden({ active = true })
    assert(p:IsSpellReady(8042, 100) == false, 'an active cooldown with the GCD idle')
    records.gcd = hidden({ active = true, onGCD = true })
    local ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'ambiguous cooldown guessed: ' .. tostring(ready))
    -- GCD readable by its times (a spell may be flagged never secret).
    records.gcd = { startTime = 99.5, duration = 1.5, isEnabled = true, isActive = true, modRate = 1 }
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value')
    records.gcd = { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1 }
    assert(p:IsSpellReady(8042, 100) == false)
    -- GCD unreadable altogether: the documented flag stands.
    records.gcd = hidden({ secret = true })
    records[8042] = hidden({ active = true, onGCD = true })
    assert(p:IsSpellReady(8042, 100) == true, 'documented isOnGCD ignored when the GCD is unreadable')
    records[8042] = hidden({ active = true })
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value')
end)

test('platform: readable spell times with secret GCD times use the GCD flags, never a guessed expiry', function()
    local records = { [8042] = { startTime = 99, duration = 30, isEnabled = true, isActive = true, modRate = 1 } }
    local p = retailPlatform(records)
    records.gcd = hidden({ active = false })
    assert(p:IsSpellReady(8042, 100) == false, 'an idle GCD cannot cover an own cooldown')
    records.gcd = hidden({ active = true, onGCD = true })
    local ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value', 'a running GCD of unknown length was guessed')
    records.gcd = hidden({ secret = true })
    ready, why = p:IsSpellReady(8042, 100)
    assert(ready == nil and why == 'restricted-value')
    -- All readable: the times decide, exactly as before.
    records[8042] = { startTime = 99.5, duration = 1.5, isEnabled = true, isActive = true, modRate = 1 }
    records.gcd = { startTime = 99.5, duration = 1.5, isEnabled = true, isActive = true, modRate = 1 }
    assert(p:IsSpellReady(8042, 100) == true)
    records[8042] = { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1 }
    records.gcd = hidden({ secret = true })
    assert(p:IsSpellReady(8042, 100) == true, 'a ready spell needs no GCD observation')
end)

test('platform: usability and range carry no secret annotation and are read as booleans', function()
    local p, e = platformFixture({
        WOW_PROJECT_ID = 1,
        WOW_PROJECT_MAINLINE = 1,
        issecretvalue = isSecret,
        canaccessvalue = canAccess,
        C_Spell = {
            IsSpellUsable = function() return true, false end,
            SpellHasRange = function() return true end,
            IsSpellInRange = function() return true end,
        },
    }, { 'Platform/client.lua', 'Platform/spells.lua', 'Platform/actions.lua' })

    local usable, power = p:IsSpellUsable(8042)
    assert(usable == true and power == false)
    local range = assert(p:GetSpellRangeState(8042, 'target', 'spell'))
    assert(range.applicable and range.inRange)
    -- Were the client to hide them after all, they stay unavailable.
    e.C_Spell.IsSpellUsable = function() return SECRET, false end
    local value, _, why = p:IsSpellUsable(8042)
    assert(value == nil and why == 'restricted-value')
    e.C_Spell.IsSpellInRange = function() return SECRET end
    local state, reason = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(state == nil and reason == 'restricted-value')
end)

-- Conditions on a Mainline model.
local function conditions(records, charges)
    local f = F.new(1, 12, 'SHAMAN')
    local a = f.addon
    f.env.issecretvalue = isSecret
    f.env.canaccessvalue = canAccess
    f.env.GetBuildInfo = function() return '12.1.5', '70529', '', 120105 end
    f.env.UnitExists = function() return true end
    f.env.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }

    f.env.C_Spell = {
        GetSpellInfo = function(id) return { name = 'Earth Shock', spellID = type(id) == 'number' and id or 8042 } end,
        GetSpellCooldown = function(id)
            local r = records[id]

            if r == nil and GCD_IDS[id] then
                r = records.gcd
            end

            return r
        end,
        GetSpellCharges = function(id) return charges[id] end,
        IsSpellInRange = function() return true end,
        SpellHasRange = function() return true end,
    }

    f.env.C_SpellBook = { IsSpellKnown = function() return true end }

    for _, path in ipairs({
        'Platform/client.lua',
        'Platform/spells.lua',
        'Platform/actions.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/spell.lua',
        'Conditions/petspell.lua',
        'Conditions/anyspell.lua',
    }) do
        f.load(path)
    end

    assert(not a.Platform.secretsUnrestricted)
    return a
end

local function value(tag, extra)
    local v = { type = tag, spell = 8042, ranked = true, operator = 'EQUALS', value = 0 }

    for key, x in pairs(extra or {}) do
        v[key] = x
    end

    return v
end

local function status(a, v)
    return a:evaluateConditionResult(v).status
end

for _, prefix in ipairs({ 'SPELL', 'PETSPELL', 'ANYSPELL' }) do
    test(
        'conditions: ' .. prefix .. '_AVAIL answers from the flags; ' .. prefix .. '_COOLDOWN stays unavailable',
        function()
            local records = { gcd = hidden({ active = true, onGCD = true }) }
            local a = conditions(records, {})
            records[8042] = hidden({ active = false })
            assert(a:evaluateCondition(value(prefix .. '_AVAIL')), 'ready spell')
            records[8042] = hidden({ active = true, onGCD = true })
            assert(a:evaluateCondition(value(prefix .. '_AVAIL')), 'GCD only')
            records[8042] = hidden({ active = true, onGCD = false })
            assert(status(a, value(prefix .. '_AVAIL')) == 'no-match', 'own cooldown')
            assert(status(a, { type = 'NOT', value = value(prefix .. '_AVAIL') }) == 'match')
            records[8042] = hidden({ secret = true })
            assert(status(a, value(prefix .. '_AVAIL')) == 'unavailable', 'secret flags')
            assert(status(a, { type = 'NOT', value = value(prefix .. '_AVAIL') }) == 'unavailable')

            -- A remaining time needs the times, whatever the flags say.
            for _, flags in ipairs({
                { active = false },
                { active = true, onGCD = true },
                { active = true, onGCD = false },
            }) do
                records[8042] = hidden(flags)

                assert(
                    status(a, value(prefix .. '_COOLDOWN', { operator = 'LESSTHAN', value = 5 })) == 'unavailable',
                    'cooldown time invented'
                )

                assert(status(a, { type = 'NOT', value = value(prefix .. '_COOLDOWN') }) == 'unavailable')
            end
        end
    )

    test(
        'conditions: '
            .. prefix
            .. '_REMAIN and '
            .. prefix
            .. '_CHARGES stay unavailable when charge counts and times are secret',
        function()
            local charges = {
                [8042] = {
                    currentCharges = SECRET,
                    maxCharges = 2,
                    cooldownStartTime = SECRET,
                    cooldownDuration = SECRET,
                    chargeModRate = SECRET,
                    isActive = true,
                },
            }

            local a = conditions({ gcd = hidden({ active = false }) }, charges)

            assert(
                status(a, value(prefix .. '_REMAIN', { operator = 'LESSTHAN', value = 5 })) == 'unavailable',
                'recharge time invented'
            )

            assert(
                status(a, value(prefix .. '_CHARGES', { operator = 'GREATERTHANOREQUALS', value = 1 }))
                    == 'unavailable',
                'charge count invented'
            )

            charges[8042].isActive = false

            assert(
                status(a, value(prefix .. '_REMAIN')) == 'unavailable'
                    and status(a, value(prefix .. '_CHARGES', { value = 2 })) == 'unavailable',
                'an idle recharge was read as full'
            )
        end
    )
end

-- Whole poll: the real addon (TOC-order fixture, Shaman bars 403, 8042, 324,
-- 8017) switched to Mainline secret rules in combat.
local function model(state)
    return {
        IsAvailable = function() return true, '' end,
        GetNextCastSpell = function() return state.next end,
        GetRotationSpells = function() return {} end,
        GetActionSpell = function() return nil end,
    }
end

local function wholePoll(measurement)
    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))(measurement or 'price', root, true, root, true)({
        target = true,
        combat = true,
        buttons = true,
        poll = .15,
    })

    c.load('Platform/assisted_combat.lua')
    return c, c.a, c.e
end

local function custom(a, id, body)
    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = id },
    }

    assert(a:CommitRotationDraft(reference, nil, { body = body }, 'class'))
end

local function select(c, a, name)
    a:HandleCommand('set ' .. name)

    for _ = 1, 3 do
        c.tick()
    end
end

-- Mainline secret rules: readability is checked again (the TBC build had made
-- it a constant), and every cooldown hides its times. state.spells[id] holds
-- the flags; the GCD runs throughout, as it does after any cast.
local function retail(c, state)
    local a, e = c.a, c.e
    e.issecretvalue = isSecret
    e.canaccessvalue = canAccess
    a.Platform.secretsUnrestricted = false

    a.Platform.CanReadValue = function(_, v)
        if isSecret(v) or not canAccess(v) then
            return false, 'restricted-value'
        end

        return true
    end

    e.C_Spell.GetSpellCooldown = function(id)
        state.reads = (state.reads or 0) + 1

        if GCD_IDS[id] then
            return hidden(state.gcd or { active = true, onGCD = true })
        end

        return hidden(state.spells[id] or { active = true, onGCD = true })
    end

    e.C_AssistedCombat = model(state)
end

test('whole poll: Blizzard\'s suggestion highlights in combat with secret cooldown times', function()
    local c, a = wholePoll()
    local state = { next = 8042, spells = {} }

    custom(a, 'assisted', {
        name = 'Assisted',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } },
    })

    select(c, a, 'Assisted')
    retail(c, state)
    c.tick()
    c.tick()
    assert(state.reads > 0, 'the Mainline cooldown model was not consulted')

    assert(
        a.currentSpell == 8042 and a:IsGlowing(8042),
        'suggestion on the GCD not highlighted: ' .. tostring(a.currentSpell)
    )

    state.spells[8042] = { active = false }
    c.tick()
    assert(a.currentSpell == 8042, 'ready suggestion not highlighted')
    state.next = 403
    c.tick()
    assert(a.currentSpell == 403 and a:IsGlowing(403) and not a:IsGlowing(8042), 'new suggestion not followed')
    state.spells[403] = { active = true, onGCD = false }
    c.tick()
    assert(a.currentSpell == nil, 'a suggestion on its own cooldown was highlighted: ' .. tostring(a.currentSpell))
    state.spells[403] = { secret = true }
    c.tick()
    assert(a.currentSpell == nil, 'a suggestion with unreadable flags was highlighted')
    assert(not a.adviceErrorReport and #a.Diagnostics:GetReports() == 0, 'secret cooldowns raised an error')
end)

test(
    'whole poll: a spell step highlights in combat with secret cooldown times, and an own cooldown falls through',
    function()
        local c, a = wholePoll()
        local state = { spells = {} }

        custom(a, 'spells', {
            name = 'Spells',
            priority = 0,
            cooldowns = {},
            rotation = {
                { id = 'shock', type = 'spell', action = 8042, conditions = {} },
                { id = 'bolt', type = 'spell', action = 403, conditions = {} },
            },
        })

        select(c, a, 'Spells')
        retail(c, state)
        c.tick()
        c.tick()

        assert(
            a.currentSpell == 8042 and a:IsGlowing(8042),
            'spell step on the GCD not highlighted: ' .. tostring(a.currentSpell)
        )

        state.spells[8042] = { active = true, onGCD = false }
        c.tick()

        assert(
            a.currentSpell == 403 and a:IsGlowing(403),
            'own cooldown did not fall through: ' .. tostring(a.currentSpell)
        )

        state.spells[8042] = { enabled = false }
        c.tick()
        assert(a.currentSpell == 403, 'held cooldown recommended')
        state.spells[8042] = { active = false }
        c.tick()
        assert(a.currentSpell == 8042, 'readiness did not recover')
        state.spells[8042] = { secret = true }
        state.spells[403] = { secret = true }
        c.tick()
        assert(a.currentSpell == nil, 'unreadable flags recommended a spell: ' .. tostring(a.currentSpell))
        -- The standard engine reads the same readiness.
        state.spells = {}
        assert(a:SetEvaluationEngine('standard'))
        c.tick()
        c.tick()
        assert(a.currentSpell == 8042, 'standard engine: ' .. tostring(a.currentSpell))
        state.spells[8042] = { active = true, onGCD = false }
        c.tick()
        assert(a.currentSpell == 403)
        assert(a:SetEvaluationEngine('lean'))
    end
)

-- TBC keeps its readable numbers: the same decisions, the same native calls
-- per poll as before this change (measured on 37852f9 with this fixture), and
-- the flags are never read.
test('TBC: decisions and native call counts are unchanged, and no cooldown flag is read', function()
    for _, case in ipairs({
        {
            true,
            8042,
            { GetSpellCooldown = 3, IsSpellUsable = 3, IsSpellKnown = 3, IsSpellInRange = 3, SpellHasRange = 3 },
        },
        { false, nil, { GetSpellCooldown = 8, IsSpellUsable = 4, IsSpellKnown = 4, IsSpellInRange = 2 } },
    }) do
        local c, a, e = wholePoll('trace')
        assert(a.Platform.secretsUnrestricted == true, 'the TBC model is not unrestricted')
        local native = e.C_Spell.GetSpellCooldown
        local flagReads = 0

        e.C_Spell.GetSpellCooldown = function(id)
            local raw = native(id)

            return setmetatable({}, {
                __index = function(_, key)
                    if key == 'isActive' or key == 'isOnGCD' then
                        flagReads = flagReads + 1
                    end

                    return raw[key]
                end,
            })
        end

        c.setSpellReady(case[1])

        for _ = 1, 8 do
            c.tick()
        end

        c.reset(false)

        for _ = 1, 10 do
            c.tick()
        end

        local counts = c.snapshot()
        assert(a.currentSpell == case[2], 'TBC decision changed: ' .. tostring(a.currentSpell))

        for name, perPoll in pairs(case[3]) do
            assert(
                (counts[name] or 0) == perPoll * 10,
                name .. ' per poll changed: ' .. tostring((counts[name] or 0) / 10) .. ' (was ' .. perPoll .. ')'
            )
        end

        assert((counts.SpellHasRange or 0) == ((case[3].SpellHasRange or 0) * 10))
        assert(flagReads == 0, 'TBC read the cooldown flags ' .. flagReads .. ' times')
    end
end)

finish()
