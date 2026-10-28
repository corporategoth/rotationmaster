-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Blizzard Assisted Combat as a display and a signal source: the rotation-set
-- and availability conditions (ASSISTED_ROTATION_SPELL, ASSISTED_AVAILABLE)
-- and the option to let Blizzard's Assisted Highlight draw a "Blizzard's
-- suggestion" step (Core/assisted_highlight.lua). C_AssistedCombat, the
-- assistedCombatHighlight CVar and AssistedCombatManager are modelled from
-- Blizzard's UI source (Gethe/wow-ui-source live e7aa82019d, forever
-- ca8368f2f2): Retail has all three; Forever declares the API and the CVar
-- but loads no AssistedCombatManager (game type camelot); the Classic
-- clients may declare the API; TBC/Era fixtures here have none of it.
local F = dofile('tests/fixtures/addon.lua')
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

local root = assert(io.popen('pwd'):read('*l'))
local RETAIL, FOREVER, TBC, ERA = 1, 18, 5, 2

-- A modelled C_AssistedCombat (see tests/assisted_combat.lua).
local function model(state)
    state.calls = state.calls or {}

    local function count(name)
        state.calls[name] = (state.calls[name] or 0) + 1
    end

    return {
        IsAvailable = function()
            count('IsAvailable')

            if state.availableError then
                error('blocked')
            end

            return state.available ~= false, state.reason or ''
        end,
        GetNextCastSpell = function(check)
            count('GetNextCastSpell')
            state.lastCheck = check
            return state.next
        end,
        GetRotationSpells = function()
            count('GetRotationSpells')

            if state.rotationError then
                error('blocked')
            end

            return state.rotation or {}
        end,
        GetActionSpell = function()
            count('GetActionSpell')
            return state.action
        end,
    }
end

local function condition(product)
    local f = F.new(product or RETAIL, 12, 'PALADIN')
    f.load('Platform/spells.lua')
    f.load('Platform/assisted_combat.lua')
    f.load('Conditions/common.lua')
    f.load('Conditions/assisted.lua')

    f.env.C_Spell = {
        GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. id, iconID = 1 } end,
        GetSpellLink = function(id) return 'spell:' .. id end,
    }

    return f.addon.definitions, f.env, f.addon, f
end

-- Reader ---------------------------------------------------------------------
test('reader: rotation membership, override and base, and the documented failures', function()
    local _, e, a = condition()
    local p = a.Platform
    local state = { rotation = { 85256, 20271, 255937 } }
    e.C_AssistedCombat = model(state)
    e.C_Spell.GetBaseSpell = function(id) return id == 427453 and 255937 or id end
    e.C_Spell.GetOverrideSpell = function(id) return id == 255937 and 427453 or id end
    assert(p:IsAssistedRotationSpell(85256) == true, 'listed spell')
    assert(p:IsAssistedRotationSpell(427453) == true, 'an override of a listed spell counts')
    assert(p:IsAssistedRotationSpell(31884) == false, 'unlisted spell')
    local value, why = p:IsAssistedRotationSpell(-1)
    assert(value == nil and why == 'invalid-spell')
    state.available = false
    value, why = p:IsAssistedRotationSpell(85256)
    assert(value == nil and why == 'assisted-unavailable', tostring(why))
    state.available = true
    state.rotationError = true
    value, why = p:IsAssistedRotationSpell(85256)
    assert(value == nil and why == 'api-error')
    state.rotationError = nil
    e.issecretvalue = function(v) return v == 20271 end
    value, why = p:IsAssistedRotationSpell(85256)
    assert(value == nil and why == 'restricted-value', 'a secret member is never skipped: ' .. tostring(why))
    e.issecretvalue = function() return false end
    state.rotation = { 'Judgment' }
    value, why = p:IsAssistedRotationSpell(85256)
    assert(value == nil and why == 'invalid-api-result')
    e.C_AssistedCombat = nil
    value, why = p:IsAssistedRotationSpell(85256)
    assert(value == nil and why == 'missing-api')
end)

test('reader: the set is kept until SPELLS_CHANGED, as Blizzard\'s manager keeps it', function()
    local _, e, a = condition()
    local frames = {}
    local create = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = create(...)
        frame.events = {}

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        frames[#frames + 1] = frame
        return frame
    end

    local state = { rotation = { 85256 } }
    e.C_AssistedCombat = model(state)
    local p = a.Platform

    assert(
        p:IsAssistedRotationSpell(85256) == true
            and p:IsAssistedRotationSpell(20271) == false
            and p:IsAssistedRotationSpell(85256) == true
    )

    assert(
        state.calls.GetRotationSpells == 1,
        'the set was read more than once: ' .. tostring(state.calls.GetRotationSpells)
    )

    local watcher

    for _, frame in ipairs(frames) do
        if frame.events.SPELLS_CHANGED then
            watcher = frame
        end
    end

    assert(watcher, 'no SPELLS_CHANGED watcher')
    state.rotation = { 20271 }
    watcher.scripts.OnEvent(watcher, 'SPELLS_CHANGED')

    assert(
        p:IsAssistedRotationSpell(20271) == true
            and p:IsAssistedRotationSpell(85256) == false
            and state.calls.GetRotationSpells == 2,
        'set not refreshed'
    )

    state.rotationError = true
    watcher.scripts.OnEvent(watcher, 'SPELLS_CHANGED')
    assert(p:IsAssistedRotationSpell(20271) == nil)
    state.rotationError = nil
    assert(p:IsAssistedRotationSpell(20271) == true, 'a failed read was cached')
end)

test('reader: Blizzard\'s highlight exists on Retail only, and the CVar is written outside combat', function()
    local _, e, a = condition(RETAIL)
    local p = a.Platform
    local cvars = { assistedCombatHighlight = '0' }
    local combat = false
    e.C_AssistedCombat = model({})
    e.AssistedCombatManager = {}

    e.C_CVar = {
        GetCVar = function(name) return cvars[name] end,
        SetCVar = function(name, value)
            cvars[name] = tostring(value)
        end,
    }

    e.InCombatLockdown = function() return combat end
    assert(p:GetAssistedHighlightSupport() == true and p:GetAssistedHighlightCVar() == '0')
    assert(p:SetAssistedHighlightCVar('1') == '1' and cvars.assistedCombatHighlight == '1')
    combat = true
    local value, why = p:SetAssistedHighlightCVar('0')
    assert(value == nil and why == 'combat-lockdown' and cvars.assistedCombatHighlight == '1', 'written in combat')
    combat = false
    -- Forever: the API and the CVar, but no AssistedCombatManager.
    e.AssistedCombatManager = nil
    value, why = p:GetAssistedHighlightSupport()
    assert(value == nil and why == 'missing-highlighter', tostring(why))
    e.AssistedCombatManager = {}
    cvars.assistedCombatHighlight = nil
    value, why = p:GetAssistedHighlightSupport()
    assert(value == nil and why == 'missing-cvar')
    cvars.assistedCombatHighlight = '0'
    e.C_CVar = nil
    e.GetCVar = function(name) return cvars[name] end

    e.SetCVar = function(name, v)
        cvars[name] = v
    end

    assert(p:GetAssistedHighlightSupport() == true, 'legacy GetCVar/SetCVar not used')
    e.issecretvalue = function(v) return v == '0' end
    value, why = p:GetAssistedHighlightCVar()
    assert(value == nil and why == 'restricted-value')
    e.issecretvalue = function() return false end
    e.C_AssistedCombat = nil
    value, why = p:GetAssistedHighlightSupport()
    assert(value == nil and why == 'missing-api')
    local _, e2, b = condition(TBC)
    e2.C_AssistedCombat = nil
    e2.C_CVar = nil
    e2.GetCVar = nil
    value, why = b.Platform:GetAssistedHighlightSupport()
    assert(value == nil and why == 'missing-api', 'TBC')
end)

-- Conditions -------------------------------------------------------------------
test('ASSISTED_ROTATION_SPELL: true, false and unavailable, never guessed, on every edition', function()
    local d, e = condition()
    local r = d.ASSISTED_ROTATION_SPELL
    assert(r, 'not registered')
    local state = { rotation = { 85256, 20271 } }
    e.C_AssistedCombat = model(state)

    assert(
        r.valid(nil, { spell = 85256 })
            and not r.valid(nil, {})
            and not r.valid(nil, { spell = -3 })
            and not r.valid(nil, { spell = 85256, ranked = 'yes' })
    )

    assert(r.evaluate({ spell = 85256 }, {}) == true and r.evaluate({ spell = 31884 }, {}) == false)
    state.available = false
    local value, why = r.evaluate({ spell = 85256 }, {})
    assert(value == nil and why == 'assisted-unavailable')
    state.available = true
    e.issecretvalue = function(v) return v == 20271 end
    value, why = r.evaluate({ spell = 85256 }, {})
    assert(value == nil and why == 'restricted-value')
    e.issecretvalue = function() return false end
    assert(type(r.print(nil, { spell = 85256 })) == 'string')

    -- Forever and Classic declare the namespace; whether it is offered is the
    -- client's answer. TBC/Era fixtures without it are missing-api.
    for _, product in ipairs({ FOREVER, TBC, ERA }) do
        local d2, e2 = condition(product)
        local s2 = { rotation = { 85256 }, available = false }
        e2.C_AssistedCombat = model(s2)
        value, why = d2.ASSISTED_ROTATION_SPELL.evaluate({ spell = 85256 }, {})
        assert(value == nil and why == 'assisted-unavailable', 'declared but not offered on ' .. product)
        e2.C_AssistedCombat = nil
        value, why = d2.ASSISTED_ROTATION_SPELL.evaluate({ spell = 85256 }, {})
        assert(value == nil and why == 'missing-api', 'missing on ' .. product)
    end
end)

test(
    'ASSISTED_AVAILABLE: a real false where the feature is not offered, unavailable where the API is missing',
    function()
        local d, e = condition()
        local r = d.ASSISTED_AVAILABLE
        assert(r and r.valid(nil, {}))
        local state = {}
        e.C_AssistedCombat = model(state)
        assert(r.evaluate({}, {}) == true)
        state.available = false
        state.reason = 'Not available for this specialization'
        local value, why = r.evaluate({}, {})
        assert(value == false and why == nil, 'not offered must be false: ' .. tostring(value))
        e.issecretvalue = function(v) return v == true or v == false end
        state.available = true
        value, why = r.evaluate({}, {})
        assert(value == nil and why == 'restricted-value')
        e.issecretvalue = function() return false end
        state.availableError = true
        value, why = r.evaluate({}, {})
        assert(value == nil and why == 'api-error')
        state.availableError = nil

        for _, product in ipairs({ FOREVER, TBC, ERA }) do
            local d2, e2 = condition(product)
            e2.C_AssistedCombat = model({ available = false })
            assert(d2.ASSISTED_AVAILABLE.evaluate({}, {}) == false, 'declared but not offered on ' .. product)
            e2.C_AssistedCombat = nil
            value, why = d2.ASSISTED_AVAILABLE.evaluate({}, {})
            assert(value == nil and why == 'missing-api')
        end

        assert(type(r.print(nil, {})) == 'string')
    end
)

test('both conditions read once per evaluation cache', function()
    local d, e = condition()
    local state = { rotation = { 85256 } }
    e.C_AssistedCombat = model(state)
    local cache = {}
    d.ASSISTED_AVAILABLE.evaluate({}, cache)
    d.ASSISTED_AVAILABLE.evaluate({}, cache)
    assert(state.calls.IsAvailable == 1, 'availability read twice: ' .. tostring(state.calls.IsAvailable))
    state.calls = {}
    cache = {}
    d.ASSISTED_ROTATION_SPELL.evaluate({ spell = 85256 }, cache)
    d.ASSISTED_ROTATION_SPELL.evaluate({ spell = 85256 }, cache)
    assert(state.calls.IsAvailable == 1, 'membership read twice')
end)

-- Whole-poll fixture: TBC Shaman bars 403, 8042, 324, 8017, with the Retail
-- surfaces modelled on top.
local function fixture(options)
    options = options or {}

    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)({
        target = true,
        combat = true,
        buttons = true,
        poll = .15,
    })

    local a, e = c.a, c.e

    local state = {
        next = 8042,
        rotation = { 8042, 403, 324 },
        cvars = { assistedCombatHighlight = options.cvar or '0' },
        combat = false,
        writes = {},
    }

    if options.api ~= false then
        e.C_AssistedCombat = model(state)
    end
    if options.manager ~= false then
        e.AssistedCombatManager = {}
    end
    if options.cvars ~= false then
        e.C_CVar = {
            GetCVar = function(name) return state.cvars[name] end,
            SetCVar = function(name, value)
                state.writes[#state.writes + 1] = tostring(value)
                state.cvars[name] = tostring(value)

                -- Blizzard fires CVAR_UPDATE; model it synchronously.
                if a.AssistedHighlight then
                    a.AssistedHighlight:OnEvent('CVAR_UPDATE', name, tostring(value))
                end
            end,
        }
    end

    e.InCombatLockdown = function() return state.combat end
    c.load('Platform/assisted_combat.lua')
    c.load('Conditions/assisted.lua')
    c.load('Core/assisted_highlight.lua')
    a.db.char = a.db.char or {}
    local glows = 0
    local glow = a.Glow

    a.Glow = function(self, button, id, ...)
        if id == 'next' then
            glows = glows + 1
        end

        return glow(self, button, id, ...)
    end

    return c, a, e, state, function() return glows end
end

local function custom(a, id, body)
    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = id },
    }

    assert(a:CommitRotationDraft(reference, nil, { body = body }, 'class'))
    return a:GetScopedRotationCoordinator():Key(reference)
end

local function assistedBody(name, extra)
    local rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } }

    for _, step in ipairs(extra or {}) do
        rotation[#rotation + 1] = step
    end

    return { name = name, priority = 0, rotation = rotation, cooldowns = {} }
end

local function select(c, a, name)
    a:HandleCommand('set ' .. name)
    a.AssistedHighlight:OnEvent('ROTATIONMASTER_ROTATION')

    for _ = 1, 3 do
        c.tick()
    end
end

local function login(a)
    a.AssistedHighlight:OnEvent('PLAYER_ENTERING_WORLD')
end

test('highlight: Rotation Master\'s glow (the default) never touches the CVar', function()
    local c, a, _, state, glows = fixture()
    login(a)
    assert(a:GetAssistedHighlightMode() == 'rm', 'default mode ' .. tostring(a.db.profile.assisted_highlight))
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(#state.writes == 0 and state.cvars.assistedCombatHighlight == '0', 'the default wrote the CVar')
    assert(a.currentSpell == 8042 and a:IsGlowing(8042) and glows() > 0, 'RM glow missing')
end)

test(
    'highlight: Blizzard\'s highlight draws the assisted step, RM still glows other steps, and the CVar comes back',
    function()
        local c, a, _, state, glows = fixture()
        login(a)
        a.db.profile.assisted_highlight = 'blizzard'

        custom(a, 'assisted', assistedBody('Assisted', {
            { id = 'bolt', type = 'spell', action = 403, conditions = {} },
        }))

        select(c, a, 'Assisted')
        assert(state.cvars.assistedCombatHighlight == '1', 'CVar not turned on')
        local record = a.db.char.assistedHighlight
        assert(record and record.previous == '0' and record.applied == '1', 'restore record missing')
        assert(a.assistedGlowHidden == true)

        assert(
            a.currentSpell == 8042 and a:IsGlowing(8042, nil, true) and not a:IsGlowing(8042),
            'assisted step was glowed by RM'
        )

        local before = glows()
        state.next = 324
        c.tick()

        assert(
            a.currentSpell == 324 and a:IsGlowing(324, nil, true) and glows() == before,
            'new suggestion glowed by RM'
        )

        state.next = nil
        c.tick()
        assert(a.currentSpell == 403 and a:IsGlowing(403) and glows() > before, 'a spell step lost its RM glow')
        state.next = 8042
        c.tick()
        assert(a.currentSpell == 8042 and a:IsGlowing(8042, nil, true))

        -- A rotation without the step gives the CVar back.
        custom(a, 'plain', {
            name = 'Plain',
            priority = 0,
            cooldowns = {},
            rotation = { { id = 'bolt', type = 'spell', action = 403, conditions = {} } },
        })

        select(c, a, 'Plain')

        assert(
            state.cvars.assistedCombatHighlight == '0'
                and a.db.char.assistedHighlight == nil
                and a.assistedGlowHidden == false,
            'not restored on switch'
        )

        -- Disabling RM gives it back too.
        select(c, a, 'Assisted')
        assert(state.cvars.assistedCombatHighlight == '1')
        a:DisableRotation()
        a.AssistedHighlight:OnEvent('ROTATIONMASTER_ROTATION')

        assert(
            state.cvars.assistedCombatHighlight == '0' and a.db.char.assistedHighlight == nil,
            'not restored on disable'
        )
    end
)

test('highlight: Both keeps RM\'s glow on the assisted step; the standard engine agrees with the lean one', function()
    local c, a, _, state, glows = fixture()
    login(a)
    a.db.profile.assisted_highlight = 'both'
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')

    assert(
        state.cvars.assistedCombatHighlight == '1'
            and a.assistedGlowHidden == false
            and a:IsGlowing(8042)
            and glows() > 0,
        'both'
    )

    a.db.profile.assisted_highlight = 'blizzard'
    a:RefreshAssistedHighlight(true)
    c.tick()
    assert(a:IsGlowing(8042, nil, true), 'lean engine did not hand the step over')
    assert(a:SetEvaluationEngine('standard'))
    state.next = 324
    c.tick()
    c.tick()

    assert(
        a.currentSpell == 324 and a:IsGlowing(324, nil, true) and not a:IsGlowing(324),
        'standard engine glowed the assisted step'
    )

    a.db.profile.assisted_highlight = 'both'
    a:RefreshAssistedHighlight(true)
    c.tick()
    assert(a:IsGlowing(324), 'standard engine did not glow again')
    assert(a:SetEvaluationEngine('lean'))
end)

test('highlight: a user who already has it on is never touched', function()
    local c, a, _, state = fixture({ cvar = '1' })
    login(a)
    a.db.profile.assisted_highlight = 'blizzard'
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(#state.writes == 0 and a.db.char.assistedHighlight == nil and a.assistedGlowHidden == true)
    a:DisableRotation()
    a.AssistedHighlight:OnEvent('ROTATIONMASTER_ROTATION')
    a.AssistedHighlight:OnEvent('PLAYER_LOGOUT')
    assert(#state.writes == 0 and state.cvars.assistedCombatHighlight == '1', 'the user\'s own setting changed')
end)

test('highlight: never written in combat; the change waits for PLAYER_REGEN_ENABLED', function()
    local c, a, _, state = fixture()
    login(a)
    a.db.profile.assisted_highlight = 'blizzard'
    custom(a, 'assisted', assistedBody('Assisted'))

    custom(a, 'plain', {
        name = 'Plain',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'bolt', type = 'spell', action = 403, conditions = {} } },
    })

    state.combat = true
    select(c, a, 'Assisted')

    assert(
        #state.writes == 0 and a.AssistedHighlight.pending and a.assistedGlowHidden == false,
        'written in combat, or RM glow hidden with no Blizzard highlight'
    )

    assert(a:IsGlowing(8042), 'RM must keep glowing until Blizzard\'s highlight is really on')
    state.combat = false
    a.AssistedHighlight:OnEvent('PLAYER_REGEN_ENABLED')
    c.tick()
    assert(state.cvars.assistedCombatHighlight == '1' and a:IsGlowing(8042, nil, true))
    state.combat = true
    select(c, a, 'Plain')
    assert(state.cvars.assistedCombatHighlight == '1', 'restored in combat')
    state.combat = false
    a.AssistedHighlight:OnEvent('PLAYER_REGEN_ENABLED')
    assert(state.cvars.assistedCombatHighlight == '0')
end)

test('highlight: the user\'s own change wins until the mode is chosen again', function()
    local c, a, e, state = fixture()
    login(a)
    a.db.profile.assisted_highlight = 'blizzard'
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(state.cvars.assistedCombatHighlight == '1')
    -- The user turns it off in Blizzard's options (CVAR_UPDATE).
    e.C_CVar.SetCVar('assistedCombatHighlight', '0')
    assert(a.db.char.assistedHighlight == nil and a.assistedGlowHidden == false, 'override not honoured')
    local writes = #state.writes
    a.AssistedHighlight:OnEvent('PLAYER_REGEN_ENABLED')
    select(c, a, 'Assisted')
    assert(#state.writes == writes and state.cvars.assistedCombatHighlight == '0', 'RM fought the user')
    assert(a:IsGlowing(8042), 'RM glow not back after the user turned Blizzard\'s off')
    a:RefreshAssistedHighlight(true)
    assert(state.cvars.assistedCombatHighlight == '1', 'choosing the mode again did not re-apply')
end)

test('highlight: logout and reload restore it, and the next login finishes a restore that did not stick', function()
    local c, a, _, state = fixture()
    login(a)
    a.db.profile.assisted_highlight = 'blizzard'
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    a.AssistedHighlight:OnEvent('PLAYER_LOGOUT')
    assert(state.cvars.assistedCombatHighlight == '0', 'not restored at logout')
    local record = a.db.char.assistedHighlight
    assert(record and record.restoredAtLogout, 'record not kept for the next login')
    -- Next session, the logout write stuck: the record is cleared (and the
    -- active rotation applies it again).
    local saved = a.db.char
    local c2, b, _, state2 = fixture()
    b.db.char = saved
    state2.cvars.assistedCombatHighlight = '0'
    b.db.profile.assisted_highlight = 'rm'
    login(b)
    assert(saved.assistedHighlight == nil and #state2.writes == 0, 'a stuck restore was not recognised')
    -- Next session, the logout write did not stick (still ours): restored now.
    saved.assistedHighlight = { previous = '0', applied = '1', restoredAtLogout = true }
    local _, d, _, state3 = fixture({ cvar = '1' })
    d.db.char = saved
    d.db.profile.assisted_highlight = 'rm'
    login(d)

    assert(
        state3.cvars.assistedCombatHighlight == '0' and saved.assistedHighlight == nil,
        'a lost restore was not finished'
    )

    -- A reload in combat cannot write; the record alone restores it at login.
    local c4, g, _, state4 = fixture()
    login(g)
    g.db.profile.assisted_highlight = 'blizzard'
    custom(g, 'assisted', assistedBody('Assisted'))
    select(c4, g, 'Assisted')
    state4.combat = true
    g.AssistedHighlight:OnEvent('PLAYER_LOGOUT')
    assert(state4.cvars.assistedCombatHighlight == '1' and g.db.char.assistedHighlight.restoredAtLogout == nil)
    local kept = g.db.char
    local _, h, _, state5 = fixture({ cvar = '1' })
    h.db.char = kept
    h.db.profile.assisted_highlight = 'blizzard'
    login(h)

    assert(
        state5.cvars.assistedCombatHighlight == '0' and kept.assistedHighlight == nil,
        'record after a combat reload was not restored'
    )

    -- If the user changed it between sessions, their value stands.
    kept.assistedHighlight = { previous = '0', applied = '1' }
    local _, k, _, state6 = fixture({ cvar = '0' })
    k.db.char = kept
    login(k)
    assert(#state6.writes == 0 and kept.assistedHighlight == nil)
    assert(c2 and c4)
end)

test('highlight: Forever, TBC and Era never write it; RM keeps its own glow', function()
    for _, options in ipairs({
        { manager = false },
        { api = false, manager = false },
        { api = false, manager = false, cvars = false },
    }) do
        local c, a, _, state = fixture(options)
        login(a)
        a.db.profile.assisted_highlight = 'blizzard'
        assert(not a:GetAssistedHighlightSupport())

        custom(a, 'assisted', assistedBody('Assisted', {
            { id = 'bolt', type = 'spell', action = 403, conditions = {} },
        }))

        select(c, a, 'Assisted')
        assert(#state.writes == 0 and a.assistedGlowHidden == false, 'written without Blizzard\'s highlighter')

        if options.api == false then
            assert(a.currentSpell == 403 and a:IsGlowing(403))
        else
            assert(a.currentSpell == 8042 and a:IsGlowing(8042))
        end
    end

    -- Assisted Combat not offered for this specialization: no write either.
    local c, a, _, state = fixture()
    state.available = false
    login(a)
    a.db.profile.assisted_highlight = 'blizzard'
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(#state.writes == 0)
end)

test('highlight: a profile change re-evaluates, and the mode is validated', function()
    local c, a, _, state = fixture()
    login(a)
    custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(#state.writes == 0)
    a.db.profile.assisted_highlight = 'nonsense'
    assert(a:GetAssistedHighlightMode() == 'rm')
    a.db.profile.assisted_highlight = 'blizzard'
    a.AssistedHighlight:Reconcile()
    assert(state.cvars.assistedCombatHighlight == '1')
    c.load('UI/settings_draft.lua')
    c.load('Core/profile_data.lua')
    assert(a:ValidateProfileTransfer({ assisted_highlight = 'both', assistedSignalConditionsSeeded = true }))

    assert(
        not a:ValidateProfileTransfer({ assisted_highlight = 1 })
            and not a:ValidateProfileTransfer({ assistedSignalConditionsSeeded = 'yes' })
    )
end)

test('the conditions gate steps in a real poll, under NOT too, and evaluate unavailable without the API', function()
    local c, a, _, state = fixture()

    custom(a, 'gated', {
        name = 'Gated',
        priority = 0,
        cooldowns = {},
        rotation = {
            {
                id = 'shock',
                type = 'spell',
                action = 8042,
                conditions = { type = 'NOT', value = { type = 'ASSISTED_ROTATION_SPELL', spell = 8017 } },
            },
            { id = 'bolt', type = 'spell', action = 403, conditions = { type = 'ASSISTED_AVAILABLE' } },
        },
    })

    select(c, a, 'Gated')
    assert(a.currentSpell == 8042, 'NOT in rotation ' .. tostring(a.currentSpell))
    state.rotation = { 8017 }
    c.fire('SPELLS_CHANGED')
    c.tick()
    assert(a.currentSpell == 403, 'set change not seen: ' .. tostring(a.currentSpell))
    state.available = false
    c.tick()

    assert(
        a.currentSpell ~= 8042 and a.currentSpell ~= 403,
        'unavailable membership or false availability recommended a step'
    )

    local _, b = fixture({ api = false })
    assert(b:evaluateConditionResult({ type = 'NOT', value = { type = 'ASSISTED_AVAILABLE' } }).status == 'unavailable')

    assert(
        b:evaluateConditionResult({ type = 'NOT', value = { type = 'ASSISTED_ROTATION_SPELL', spell = 8042 } }).status
            == 'unavailable'
    )
end)

test('validation, export/import and compiled copies accept the conditions', function()
    local c, a = fixture()
    c.load('Data/diff.lua')
    c.load('Data/import_session.lua')
    c.load('Core/imports.lua')
    local data = a.RotationData
    local options = a:GetImportValidationOptions()

    local body = assistedBody('Portable', {
        {
            id = 'bolt',
            type = 'spell',
            action = 403,
            conditions = {
                type = 'AND',
                value = {
                    { type = 'ASSISTED_AVAILABLE' },
                    { type = 'NOT', value = { type = 'ASSISTED_ROTATION_SPELL', spell = 403 } },
                },
            },
        },
    })

    local result = data.ValidateBody(body, options)

    assert(
        result.valid and result.supported,
        'rejected: ' .. tostring(result.diagnostics[1] and result.diagnostics[1].code)
    )

    assert(a:rotationValidConditions(body, 0), 'the legacy validity check rejected the conditions')
    local bad = data.CopyData(body)
    bad.rotation[2].conditions = { type = 'ASSISTED_ROTATION_SPELL' }

    assert(
        not a:validateCondition(bad.rotation[2].conditions, 0) and not a:rotationValidConditions(bad, 0),
        'a membership test without a spell was accepted'
    )

    local key = custom(a, 'portable', body)
    c.tick()
    local exported = assert(a:GetRotationExportData(0, key))
    local text = 'copied'

    local codec = {
        Decode = function(_, value)
            assert(value == text)
            local copy = data.CopyData(exported)
            return { kind = copy.format == 'RotationMaster' and 'envelope' or 'legacy', original = value, value = copy }
        end,
    }

    local session = data.NewImportSession(codec, options)
    local candidate = assert(session:Stage(text))
    local imported = assert(a:ApplyRotationImport(session, candidate.token, 0, 'Imported signals'))
    local copy = assert(a:GetEditableRotation(0, imported))

    assert(
        copy.rotation[2].conditions.value[2].value.type == 'ASSISTED_ROTATION_SPELL'
            and copy.rotation[2].conditions.value[2].value.spell == 403,
        'condition lost in transport'
    )
end)

test('compiled copies of the built-in sources evaluate the same, under NOT too', function()
    local f = F.new(RETAIL, 12, 'PALADIN')
    local a, e = f.addon, f.env

    e.C_Spell = {
        GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. id, iconID = 1 } end,
        GetSpellLink = function(id) return 'spell:' .. id end,
    }

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Platform/spells.lua', 'Platform/assisted_combat.lua', 'Core/presentation.lua',
        'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/assisted.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    local state = { rotation = { 8042 } }
    e.C_AssistedCombat = model(state)

    for _, tag in ipairs({ 'ASSISTED_ROTATION_SPELL', 'ASSISTED_AVAILABLE' }) do
        a:RegisterCondition('COPY_' .. tag, assert(a:CompileCustomCondition('COPY_' .. tag, assert(
            a:GetBuiltinConditionSource(tag)
        ))))
    end

    local function status(v)
        return a:evaluateConditionResult(v).status
    end

    local cases = {
        { type = 'ASSISTED_ROTATION_SPELL', spell = 8042 },
        { type = 'ASSISTED_ROTATION_SPELL', spell = 8017 },
        { type = 'ASSISTED_AVAILABLE' },
    }

    for _, available in ipairs({ true, false }) do
        state.available = available

        for _, v in ipairs(cases) do
            local copied = { type = 'COPY_' .. v.type, spell = v.spell }

            assert(
                status(v) == status(copied) and status({ type = 'NOT', value = v }) == status({
                    type = 'NOT',
                    value = copied,
                }),
                'compiled copy differs for ' .. v.type
            )
        end
    end

    state.available = true
    assert(status(cases[1]) == 'match' and status(cases[2]) == 'no-match' and status(cases[3]) == 'match')
    state.available = false

    assert(
        status(cases[1]) == 'unavailable'
            and status({ type = 'NOT', value = cases[1] }) == 'unavailable'
            and status(cases[3]) == 'no-match'
            and status({ type = 'NOT', value = cases[3] }) == 'match'
    )
end)

test(
    'settings: the choice shows where Blizzard\'s highlight exists, applies through the draft, and is hidden elsewhere',
    function()
        -- The settings fixture's codec needs the bit library (luajit), as
        -- tests/settings_pages.lua does; tools/check runs this file in both.
        if not pcall(require, 'bit') then
            print('SKIP settings page under plain Lua 5.1 (no bit library)')
            return
        end

        local source = assert(io.open('tests/settings_pages.lua')):read('*a')
        local settings = assert(loadstring(assert(source:match('^(.-)\ntest%(')) .. '\nreturn fixture'))()

        -- Retail has Blizzard's Assisted Combat and its highlighter; a Classic client has neither.
        local function open(support)
            local f, parent = settings(support ~= 'classic' and 1 or nil)
            local a, e = f.addon, f.env
            e.C_AssistedCombat = model({ available = support ~= 'spec' })

            if support ~= 'classic' then
                e.AssistedCombatManager = {}
            end

            local cvars = { assistedCombatHighlight = '0' }

            e.C_CVar = {
                GetCVar = function(n) return cvars[n] end,
                SetCVar = function(n, v)
                    cvars[n] = v
                end,
            }

            f.load('Platform/assisted_combat.lua')
            f.load('Core/assisted_highlight.lua')
            a.db.profile.color = { r = 1, g = 1, b = 1, a = 1 }
            a.db.global.effects = {}
            local refreshed = {}

            a.RefreshAssistedHighlight = function(_, clear)
                refreshed[#refreshed + 1] = clear
            end

            return a, a:OpenNativeSettings(parent, 'General'), refreshed
        end

        local a, p, refreshed = open('retail')
        local control = assert(p.fields.assisted_highlight, 'choice missing on Retail')
        assert(control:GetText() == "Rotation Master's glow", 'default shown as ' .. tostring(control:GetText()))
        control:Click()
        local row

        for _, entry in ipairs(p.menu.rows or {}) do
            if entry:GetText() == "Blizzard's Assisted Highlight" then
                row = entry
            end
        end

        assert(row, 'Blizzard option missing')
        row:Click()
        assert(a.db.profile.assisted_highlight ~= 'blizzard' and #refreshed == 0, 'applied before Apply')
        assert(p:IsSettingsDraftDirty(), 'the choice is not a pending edit')
        assert(p:SaveSettingsDraft())

        assert(
            a.db.profile.assisted_highlight == 'blizzard' and refreshed[1] == true,
            'apply did not reach the manager'
        )

        local help = a:GetGeneralOptionHelp()
        local found = false

        for _, entry in ipairs(help) do
            if entry.id == 'assisted_highlight' then
                found = true
            end
        end

        assert(found, 'help entry missing')
        p:Release()
        local _, q = open('spec')
        assert(q.fields.assisted_highlight, 'hidden for a specialization without Assisted Combat')
        q:Release()
        local b, r = open('classic')
        assert(not r.fields.assisted_highlight, 'shown without Blizzard\'s highlighter')

        for _, entry in ipairs(b:GetGeneralOptionHelp()) do
            assert(entry.id ~= 'assisted_highlight', 'help for a hidden control')
        end

        r:Release()
    end
)

test('the condition editor stores the chosen spell and the summary names it', function()
    local d, e, a, f = condition()
    e.C_AssistedCombat = model({ rotation = { 85256 } })
    local r = d.ASSISTED_ROTATION_SPELL
    local top = f.widget('top')
    local root = {}
    local printed
    top:SetUserData('root', root)

    top:SetUserData('funcs', {
        print = function()
            printed = true
            return 'x'
        end,
    })

    local parent = f.widget('parent')
    parent:SetUserData('top', top)
    local value = { type = 'ASSISTED_ROTATION_SPELL' }
    local captured

    a.Widget_SpellWidget = function(_, spec, editbox, v, _, _, update)
        captured = { spec = spec, editbox = editbox, value = v, update = update }
        return f.widget('spell')
    end

    r.widget(parent, 0, value)
    assert(captured and captured.value == value and #parent.children == 1, 'spell widget not offered')
    value.spell = 85256
    captured.update()
    assert(printed, 'status not refreshed')
    assert(r.valid(nil, value) and r.evaluate(value, {}) == true)
    a.Widget_GetSpellLink = function(_, id) return '[Spell ' .. id .. ']' end
    assert(r.print(nil, value):find('Spell 85256', 1, true), 'summary does not name the spell')
    local help = f.widget('help')
    r.help(help)
    assert(#help.children > 0)
    help = f.widget('help')
    d.ASSISTED_AVAILABLE.help(help)
    assert(#help.children > 0)
end)

test('the conditions join the Spells category once per profile', function()
    local _, a = fixture()
    local spells

    for _, category in ipairs(a.db.profile.condition_groups) do
        if category.id == '8034819e-26f5-4f4e-9153-d8cab5e65f31' then
            spells = category
        end
    end

    assert(spells and a.db.profile.assistedSignalConditionsSeeded, 'not seeded')

    local function count(tag)
        local n = 0

        for _, t in ipairs(spells.conditions) do
            if t == tag then
                n = n + 1
            end
        end

        return n
    end

    assert(count('ASSISTED_ROTATION_SPELL') == 1 and count('ASSISTED_AVAILABLE') == 1)

    for i = #spells.conditions, 1, -1 do
        if spells.conditions[i] == 'ASSISTED_AVAILABLE' then
            table.remove(spells.conditions, i)
        end
    end

    a:InitializeUnitStateConditions(nil, a.db)
    assert(count('ASSISTED_AVAILABLE') == 0, 'a removed seed came back')

    -- A profile seeded with ASSISTED_SUGGESTION before these existed still gets them.
    local db = {
        profile = {
            assistedConditionsSeeded = true,
            unitStateSwitchSeeded = true,
            switch_conditions = {},
            condition_groups = {
                { id = '8034819e-26f5-4f4e-9153-d8cab5e65f31', conditions = { 'ASSISTED_SUGGESTION' } },
            },
        },
    }

    a:InitializeUnitStateConditions(nil, db)

    assert(
        table.concat(db.profile.condition_groups[1].conditions, ',')
            == 'ASSISTED_SUGGESTION,ASSISTED_ROTATION_SPELL,ASSISTED_AVAILABLE'
    )
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
