-- Idle gate: out of combat with no target/focus, timer ticks evaluate only after
-- a watched notification or once per idle_poll; otherwise every tick evaluates.
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

local function make(options)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)
    options.buttons = true
    options.poll = .15
    local c = build(options)

    for _ = 1, 8 do
        c.tick()
    end

    return c
end

local function run(c, n)
    local gate = c.a.idleGate
    local e, s = gate.evaluated, gate.skipped

    for _ = 1, n do
        c.tick()
    end

    return gate.evaluated - e, gate.skipped - s
end

test('idle with no target evaluates about once per idle_poll', function()
    local c = make({ target = false })
    local evaluated, skipped = run(c, 60)  -- 9 seconds of ticks
    assert(evaluated >= 8 and evaluated <= 11, 'evaluated ' .. evaluated)
    assert(skipped == 60 - evaluated)
    assert(not c.a.adviceErrorReport)
end)

test('a watched notification makes the next tick evaluate', function()
    local c = make({ target = false })
    run(c, 8)
    -- Step past the idle_poll floor so the next clean tick is a skip.
    c.fire('UNIT_AURA', 'player')
    c.tick()
    local before = c.a.idleGate.evaluated
    c.tick()
    assert(c.a.idleGate.evaluated == before, 'tick should be skipped')
    c.fire('UNIT_AURA', 'player')
    c.tick()
    assert(c.a.idleGate.evaluated == before + 1, 'aura change not evaluated')
    c.tick()
    assert(c.a.idleGate.evaluated == before + 1, 'clean tick should be skipped again')
end)

test('advice still follows a change while idle', function()
    local c = make({ target = false })
    run(c, 8)
    local spell = c.a.currentSpell
    c.setEnchant(true)
    c.setAura(true)
    c.fire('UNIT_AURA', 'player')
    c.fire('UNIT_INVENTORY_CHANGED', 'player')
    c.tick()
    c.setEnchant(false)
    c.setAura(false)
    c.fire('UNIT_AURA', 'player')
    c.fire('UNIT_INVENTORY_CHANGED', 'player')
    c.tick()
    assert(c.a.currentSpell == spell)
end)

test('any target means every tick evaluates', function()
    local c = make({ target = true })
    local evaluated, skipped = run(c, 40)
    assert(evaluated == 40 and skipped == 0, evaluated .. '/' .. skipped)
end)

test('combat means every tick evaluates', function()
    local c = make({ target = false, combat = true })
    local evaluated, skipped = run(c, 40)
    assert(evaluated == 40 and skipped == 0, evaluated .. '/' .. skipped)
end)

test('idle_poll 0 turns the gate off', function()
    local c = make({ target = false })
    c.a.db.profile.idle_poll = 0
    local evaluated, skipped = run(c, 40)
    assert(evaluated == 40 and skipped == 0)
end)

test('a rotation change evaluates at once', function()
    local c = make({ target = false })
    run(c, 8)
    local before = c.a.idleGate.evaluated
    c.a.idleGate.rotation = 'something-else'
    c.tick()
    assert(c.a.idleGate.evaluated == before + 1)
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
