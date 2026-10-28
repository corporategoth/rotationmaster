-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Special action contexts on the real addon (TOC-order whole-poll fixture):
-- possession, vehicle, override bar and pet battle each select an applicable
-- rotation or suspend advice, and leaving restores the player's rotation.
-- Class pet bars and vehicle/override buttons map recommendations; abilities
-- outside both spellbooks are ready through their bound button.
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

local function fixture(options)
    options = options or {}

    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)({
        target = true,
        combat = options.combat == true,
        buttons = true,
        poll = .15,
    })

    local a, e = c.a, c.e
    local st = { possess = false, override = false, battle = false, vehicle = false }
    e.IsPossessBarVisible = function() return st.possess end
    e.HasOverrideActionBar = function() return st.override end

    if options.petBattles then
        e.C_PetBattles = { IsInBattle = function() return st.battle end }
    end

    local function set(kind, value)
        st[kind] = value

        if kind == 'vehicle' then
            c.setVehicle(value)
        end
    end

    a:RefreshActionContext()

    -- Debounced button refetches run at once here.
    a.ScheduleTimer = function(_, fn, _, ...)
        if type(fn) == 'function' then
            fn(...)
        else
            a[fn](a, ...)
        end

        return {}
    end

    a.CancelTimer = function() end

    for _ = 1, 4 do
        c.tick()
    end

    return c, a, e, set, st
end

local function name(a)
    local body = a.currentRotation and a:GetRuntimeRotation(0, a.currentRotation)
    return body and body.name
end

local function bare(a, id, body)
    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = id },
    }

    assert(a:CommitRotationDraft(reference, nil, { body = body }, 'class'))
    return a:GetScopedRotationCoordinator():Key(reference)
end

local function step(id, spell)
    return { id = id, type = 'spell', action = spell, ranked = false, conditions = {} }
end

test('possession suspends player advice and the manual rotation returns on release (TBC mind control)', function()
    local c, a, _, set = fixture()
    local before = a.currentRotation
    assert(before and a.currentSpell, 'fixture gave no advice')
    set('possess', true)
    a:UPDATE_POSSESS_BAR('UPDATE_POSSESS_BAR')
    assert(a:GetActionContext() == 'possession', 'possession not observed')
    assert(a.currentRotation == nil, 'player rotation kept advising through a possessed unit')

    for _ = 1, 3 do
        c.tick()
    end

    assert(a.currentSpell == nil, 'advice continued while possessing')
    set('possess', false)
    a:UPDATE_POSSESS_BAR('UPDATE_POSSESS_BAR')
    assert(a:GetActionContext() == 'player' and a.currentRotation == before, 'player rotation not restored')

    for _ = 1, 3 do
        c.tick()
    end

    assert(a.currentSpell ~= nil, 'advice did not resume')
end)

test(
    'a rotation whose switch requires a vehicle is selected in the vehicle and the player rotation returns on exit',
    function()
        local c, a = fixture()
        a:HandleCommand('set auto')
        a:UpdateAutoSwitch()
        a:SwitchRotation()
        local player = a.currentRotation
        assert(player and not a.manualRotation)

        local key = bare(a, 'vehicle-rotation', {
            name = 'Siege engine',
            priority = 100,
            switch = { type = 'ACTION_CONTEXT', context = 'vehicle' },
            rotation = { step('ram', 8042) },
            cooldowns = {},
        })

        a:UpdateAutoSwitch()
        a:SwitchRotation()
        assert(a.currentRotation == player, 'vehicle rotation chosen outside the vehicle')
        local _, a2 = nil, a
        c.setVehicle(true)
        a2:UNIT_ENTERED_VEHICLE('UNIT_ENTERED_VEHICLE', 'player')

        assert(
            a:GetActionContext() == 'vehicle' and a.currentRotation == key,
            'vehicle rotation not selected: ' .. tostring(name(a))
        )

        for _ = 1, 3 do
            c.tick()
        end

        assert(a.currentSpell == 8042, 'vehicle advice ' .. tostring(a.currentSpell))
        c.setVehicle(false)
        a:UNIT_EXITED_VEHICLE('UNIT_EXITED_VEHICLE', 'player')

        assert(
            a:GetActionContext() == 'player' and a.currentRotation == player,
            'player rotation not restored after the vehicle'
        )
    end
)

test('bare rotations stay off a special bar while their switch does not require it', function()
    local _, a, _, set = fixture()
    a:HandleCommand('set auto')
    a:UpdateAutoSwitch()
    a:SwitchRotation()

    local key = bare(a, 'player-only', {
        name = 'Player only',
        priority = 100,
        switch = { type = 'NOT', value = { type = 'ACTION_CONTEXT', context = 'override' } },
        rotation = { step('bolt', 403) },
        cooldowns = {},
    })

    a:UpdateAutoSwitch()
    set('override', true)
    a:UPDATE_OVERRIDE_ACTIONBAR('UPDATE_OVERRIDE_ACTIONBAR')
    assert(a:GetActionContext() == 'override')

    assert(
        a.currentRotation == nil and not a:GetRuntimeRotation(0, key),
        'NOT/absent opt-in admitted a bare rotation on the override bar'
    )

    set('override', false)
    a:UPDATE_OVERRIDE_ACTIONBAR('UPDATE_OVERRIDE_ACTIONBAR')
    assert(a.currentRotation ~= nil)
end)

test('with automatic switching off a manual choice is suspended and restored around an override bar', function()
    local _, a, _, set = fixture()
    local before = a.currentRotation
    a.db.profile.autoswitch_poll = 0
    assert(a.manualRotation)
    set('override', true)
    a:UPDATE_OVERRIDE_ACTIONBAR('UPDATE_OVERRIDE_ACTIONBAR')
    assert(a.currentRotation == nil)
    set('override', false)
    a:UPDATE_OVERRIDE_ACTIONBAR('UPDATE_OVERRIDE_ACTIONBAR')
    assert(a.currentRotation == before and a.manualRotation, 'manual choice lost with automatic switching off')
end)

test('pet battles are a separate context only where C_PetBattles exists', function()
    local _, a, _, set = fixture({ petBattles = true })
    set('battle', true)
    a:PET_BATTLE_OPENING_START('PET_BATTLE_OPENING_START')
    assert(a:GetActionContext() == 'petbattle' and a.currentRotation == nil)
    set('battle', false)
    a:PET_BATTLE_CLOSE('PET_BATTLE_CLOSE')
    assert(a:GetActionContext() == 'player' and a.currentRotation ~= nil)
    local _, b, e = fixture()
    e.C_PetBattles = nil
    e.IsPossessBarVisible = nil
    e.HasOverrideActionBar = nil
    assert(b:ReadActionContext() == 'player', 'missing optional APIs did not read as the player bar')
end)

test('control lost while taking a possessed unit keeps that unit\'s rotation advising', function()
    local c, a, _, set = fixture()
    a:HandleCommand('set auto')
    a:UpdateAutoSwitch()
    a:SwitchRotation()

    local key = bare(a, 'mind-control', {
        name = 'Mind controlled',
        priority = 100,
        switch = { type = 'ACTION_CONTEXT', context = 'possession' },
        rotation = { step('smash', 8042) },
        cooldowns = {},
    })

    a:UpdateAutoSwitch()
    set('possess', true)
    a:PLAYER_CONTROL_LOST('PLAYER_CONTROL_LOST')
    a:UPDATE_POSSESS_BAR('UPDATE_POSSESS_BAR')
    assert(a.currentRotation == key and a.rotationTimer, 'possession rotation not running after control lost')

    for _ = 1, 3 do
        c.tick()
    end

    assert(a.currentSpell == 8042, 'possessed unit advice ' .. tostring(a.currentSpell))
    set('possess', false)
    a:PLAYER_CONTROL_GAINED('PLAYER_CONTROL_GAINED')
    a:UPDATE_POSSESS_BAR('UPDATE_POSSESS_BAR')

    assert(
        a.currentRotation and a.currentRotation ~= key and a.rotationTimer,
        'player rotation not running after release'
    )
end)

test('detection order and per-client availability are feature-detected', function()
    local _, a, e = fixture()

    local function read()
        return a:ReadActionContext()
    end

    e.UnitHasVehicleUI = nil
    e.UnitInVehicle = nil
    e.HasOverrideActionBar = nil
    e.IsPossessBarVisible = nil
    e.C_PetBattles = nil
    assert(read() == 'player', 'an Era/TBC client without bar APIs is not the player bar')
    e.IsPossessBarVisible = function() return true end
    assert(read() == 'possession')
    e.HasOverrideActionBar = function() return true end
    assert(read() == 'override', 'override bar does not win over possession')
    e.HasVehicleActionBar = function() return true end
    assert(read() == 'vehicle', 'vehicle bar does not win over override')
    e.HasVehicleActionBar = nil
    e.UnitInVehicle = function() return true end
    assert(read() == 'vehicle', 'vehicle fallback without UnitHasVehicleUI')
    e.C_PetBattles = { IsInBattle = function() return true end }
    assert(read() == 'petbattle', 'pet battle does not win')
    e.C_PetBattles = nil
    e.UnitInVehicle = nil

    e.HasOverrideActionBar = function()
        error('blocked')
    end

    e.IsPossessBarVisible = function()
        error('blocked')
    end

    assert(read() == 'player', 'a failing optional API changed the context')
end)

test('an unchanged bar notification keeps the lean plan; a change rebuilds it once', function()
    local c, a, _, set = fixture({ combat = true })

    for _ = 1, 4 do
        c.tick()
    end

    local built, context = a.leanStats.built, a.leanStats.context

    for _ = 1, 3 do
        a:UPDATE_BONUS_ACTIONBAR('UPDATE_BONUS_ACTIONBAR')
        c.tick()
    end

    assert(
        a.leanStats.built == built and a.leanStats.context == context,
        'unchanged bar notification dropped the lean plan'
    )

    a.manualRotation = false
    a.db.profile.autoswitch_poll = 1

    local key = bare(a, 'bonus-rotation', {
        name = 'Bonus',
        priority = 100,
        switch = { type = 'ACTION_CONTEXT', context = 'possession' },
        rotation = { step('bolt', 403) },
        cooldowns = {},
    })

    a:UpdateAutoSwitch()
    set('possess', true)
    a.idleGate.dirty = false
    a:UPDATE_BONUS_ACTIONBAR('UPDATE_BONUS_ACTIONBAR')

    assert(
        a.idleGate.dirty == true and a.currentRotation == key,
        'a context change neither dirtied the idle gate nor reselected'
    )

    c.tick()
    c.tick()

    assert(
        a.leanStats.built == built + 1,
        'context change did not rebuild the lean plan exactly once: ' .. (a.leanStats.built - built)
    )
end)

test('the auto-switch re-check settles a notification the client never sent', function()
    local _, a, _, set = fixture()
    a:HandleCommand('set auto')
    a:UpdateAutoSwitch()
    a:SwitchRotation()
    set('possess', true)
    a:AutoSwitchTick()
    assert(a:GetActionContext() == 'possession' and a.currentRotation == nil, 'missed notification left advice running')
    set('possess', false)
    a:AutoSwitchTick()
    assert(a:GetActionContext() == 'player' and a.currentRotation ~= nil)
end)

test('class pet bar buttons map pet abilities and skip command tokens', function()
    local _, a, e = fixture()
    local nativeCreate = e.CreateFrame

    local actions = {
        { 'Bite', 1, false, false, true, true, 17253 },
        { 'PET_ACTION_ATTACK', 1, true, false, false, false, nil },
        { 'Claw', 1, false, false, true, false, nil },
    }

    e.GetPetActionInfo = function(index)
        local row = actions[index]

        if row then
            return unpack(row, 1, 7)
        end
    end

    e.C_Spell.GetSpellInfo = function(id)
        if id == 'Claw' then
            return { spellID = 16827, name = 'Claw', iconID = 1 }
        end

        return { spellID = id, name = 'Spell ' .. tostring(id), iconID = 1 }
    end

    for i = 1, 3 do
        local button = nativeCreate('Button', nil, e.UIParent)
        button.GetID = function() return i end

        button.GetAttribute = function(_, key)
            if key == 'type' then
                return 'pet'
            end
        end

        e['PetActionButton' .. i] = button
    end

    a:Fetch()

    assert(
        a:FindSpell({ 17253 }) == 17253 and a:GetPetActionButtonIndex(e.PetActionButton1) == 1,
        'pet ability not mapped from its spell ID'
    )

    assert(a:FindSpell({ 16827 }) == 16827, 'older pet action layout not resolved by name')

    assert(
        a:GetPetActionButtonIndex(e.PetActionButton2) == 2 and a:FindSpell({ 'PET_ACTION_ATTACK' }) == nil,
        'command token indexed'
    )
end)

test('vehicle abilities outside both spellbooks are ready through their override bar button', function()
    local c, a, e = fixture()
    a:HandleCommand('set auto')
    a:UpdateAutoSwitch()
    a:SwitchRotation()
    local known = e.IsSpellKnown

    e.IsSpellKnown = function(id, ...)
        if id == 77777 then
            return false
        end

        return known(id, ...)
    end

    local hasAction, actionInfo = e.HasAction, e.GetActionInfo
    e.HasAction = function(slot) return slot == 133 or hasAction(slot) end

    e.GetActionInfo = function(slot)
        if slot == 133 then
            return 'spell', 77777
        end

        return actionInfo(slot)
    end

    local usable, cooldown = true, 0

    e.IsUsableAction = function(slot)
        assert(slot == 133)
        return usable, false
    end

    e.GetActionCooldown = function(slot)
        assert(slot == 133)
        return cooldown > 0 and 99 or 0, cooldown, 1
    end

    e.IsActionInRange = function() return nil end
    local button = e.CreateFrame('Button', nil, e.UIParent)

    button.GetAttribute = function(_, key)
        if key == 'type' then
            return 'action'
        elseif key == 'action' then
            return 133
        end
    end

    e.OverrideActionBarButton1 = button
    a:Fetch()

    local key = bare(a, 'override-rotation', {
        name = 'Override',
        priority = 100,
        switch = { type = 'ACTION_CONTEXT', context = 'override' },
        rotation = { step('lance', 77777) },
        cooldowns = {},
    })

    a:UpdateAutoSwitch()
    local ready = a:NewActionReadiness(100)
    assert(ready('spell', 77777) == false, 'player bar admitted an unknown spell')
    e.HasOverrideActionBar = function() return true end
    a:UPDATE_OVERRIDE_ACTIONBAR('UPDATE_OVERRIDE_ACTIONBAR')
    assert(a.currentRotation == key, 'override rotation not selected')

    for _ = 1, 3 do
        c.tick()
    end

    assert(a.currentSpell == 77777, 'override ability not recommended: ' .. tostring(a.currentSpell))
    usable = false
    ready = a:NewActionReadiness(100)
    assert(ready('spell', 77777) == false, 'unusable bound action reported ready')
    usable = true
    cooldown = 30
    ready = a:NewActionReadiness(100)
    assert(ready('spell', 77777) == false, 'cooling bound action reported ready')
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
