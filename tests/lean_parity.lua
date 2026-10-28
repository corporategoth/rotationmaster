-- Lean evaluation must publish exactly what the standard evaluation publishes:
-- same advice and the same ordered outputs (WeakAuras, messages, glow
-- textures, preview), across state changes, with and without a preview.
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

local function make(engine, options)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    options.buttons = true
    options.poll = .15
    local c = build(options)
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine))

    for _ = 1, 6 do
        c.tick()
    end

    return c
end

local function delivered(c)
    local _, rows = c.snapshot()
    local out = {}

    for _, v in ipairs(rows) do
        if v:match('^WeakAuras|') or v:match('^SendMessage|') or v:match('^Texture%.') or v:match('^Preview%.') then
            out[#out + 1] = v
        end
    end

    return out
end

local function observe(c, n)
    c.reset(true)
    local advice = {}

    for i = 1, n do
        c.tick()
        advice[i] = tostring(c.a.currentSpell)
    end

    local rows = delivered(c)
    c.reset(false)
    assert(not c.a.adviceErrorReport, 'advice error')
    return advice, rows
end

local function same(x, y, what)
    assert(
        #x == #y,
        what .. ': ' .. #x .. ' vs ' .. #y .. ' rows (' .. table.concat(x, ',') .. ' / ' .. table.concat(y, ',') .. ')'
    )

    for i = 1, #x do
        assert(x[i] == y[i], what .. ' row ' .. i .. ': ' .. tostring(x[i]) .. ' vs ' .. tostring(y[i]))
    end
end

local changes = {
    {
        'aura on',
        function(c)
            c.setAura(true)
            c.fire('UNIT_AURA', 'player')
        end,
    },
    {
        'enchant on',
        function(c)
            c.setEnchant(true)
            c.fire('UNIT_INVENTORY_CHANGED', 'player')
        end,
    },
    {
        'aura off',
        function(c)
            c.setAura(false)
            c.fire('UNIT_AURA', 'player')
        end,
    },
    {
        'combat on',
        function(c)
            c.setCombat(true)
            c.fire('PLAYER_REGEN_DISABLED')
        end,
    },
    {
        'cooldown on',
        function(c)
            c.setSpellReady(false)
            c.fire('SPELL_UPDATE_COOLDOWN')
        end,
    },
    {
        'cooldown off',
        function(c)
            c.setSpellReady(true)
            c.fire('SPELL_UPDATE_COOLDOWN')
        end,
    },
    {
        'enchant off',
        function(c)
            c.setEnchant(false)
            c.fire('UNIT_INVENTORY_CHANGED', 'player')
        end,
    },
    {
        'target toggle',
        function(c)
            c.setTarget(not c.targetState)
            c.targetState = not c.targetState
            c.fire('PLAYER_TARGET_CHANGED')
        end,
    },
    {
        'combat off',
        function(c)
            c.setCombat(false)
            c.fire('PLAYER_REGEN_ENABLED')
        end,
    },
    {
        'target toggle back',
        function(c)
            c.setTarget(not c.targetState)
            c.targetState = not c.targetState
            c.fire('PLAYER_TARGET_CHANGED')
        end,
    },
}

for _, target in ipairs({ false, true }) do
    for _, preview in ipairs({ false, 3 }) do
        test('lean matches standard: target=' .. tostring(target) .. ' preview=' .. tostring(preview), function()
            local s, l = make('standard', { target = target, preview = preview }), make('lean', {
                target = target,
                preview = preview,
            })

            s.targetState, l.targetState = target, target
            local a1, r1 = observe(s, 4)
            local a2, r2 = observe(l, 4)
            same(a1, a2, 'steady advice')
            same(r1, r2, 'steady outputs')
            assert(l.a:GetEvaluationEngine() == 'lean', 'lean plan never engaged: ' .. l.a:GetEvaluationEngine())

            for _, change in ipairs(changes) do
                change[2](s)
                change[2](l)
                a1, r1 = observe(s, 3)
                a2, r2 = observe(l, 3)
                same(a1, a2, change[1] .. ' advice')
                same(r1, r2, change[1] .. ' outputs')
            end
        end)
    end
end

test('a rotation write reaches the lean engine on the next poll', function()
    local c = make('lean', { target = true })
    c.tick()
    assert(c.a:GetEvaluationEngine() == 'lean')
    local key = c.a.currentRotation
    local record, token = c.a:GetRotationRecordSnapshot(0, key)
    assert(record and token)
    record.body.rotation = { { id = 'only-shield', type = 'spell', action = 324, conditions = {} } }
    local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, key))
    assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
    c.tick()
    c.tick()
    assert(c.a.currentSpell == 324, 'lean kept the old body: ' .. tostring(c.a.currentSpell))
end)

-- A rotation chosen by hand and restricted to a talent group (body.specs on this TBC client) stops and
-- resumes with the group, identically in both engines.
test('a specialization restriction (body.specs) applies the same in both engines', function()
    local runs = {}

    for _, engine in ipairs({ 'standard', 'lean' }) do
        local c = make(engine, { target = true })
        local a = c.a
        local group = 1
        c.e.GetActiveTalentGroup = function() return group end

        if type(c.e.C_SpecializationInfo) == 'table' then
            c.e.C_SpecializationInfo.GetActiveSpecGroup = function() return group end
        end

        local key = a.currentRotation
        assert(key, 'no rotation selected')
        local record, token = a:GetRotationRecordSnapshot(0, key)
        record.body.specs = { 2 }
        local ref = assert(a:GetScopedRotationCoordinator():Resolve(0, key))
        assert(a:CommitRotationDraft(ref, token, record, 'class'))
        local seq = {}

        -- What UpdateSkill does on ACTIVE_TALENT_GROUP_CHANGED (this fixture's catalog cannot run it whole).
        local function step(label)
            if a.InvalidateBuildContext then
                a:InvalidateBuildContext('talents')
            end

            a:InvalidateRotationChoiceContext()
            a:SwitchRotation()

            for _ = 1, 3 do
                c.tick()

                seq[#seq + 1] = label .. ':' .. tostring(a.currentSpell) .. '/' .. tostring(
                    a.currentRotation ~= nil and a.currentRotation ~= c.e.DEFAULT
                )
            end
        end

        step('primary')
        group = 2
        step('secondary')
        group = 1
        step('primary again')
        assert(not a.adviceErrorReport, 'advice error')
        runs[engine] = seq
    end

    same(runs.standard, runs.lean, 'specialization restriction')
    assert(runs.lean[1]:find('/false', 1, true) and runs.lean[4]:find('/true', 1, true), table.concat(runs.lean, ' '))
end)

-- A rotation with no switch condition (an empty switch, or none at all) matches whenever it applies, so
-- automatic switching selects it and it runs identically in both engines; with a switch that fails it is
-- not selected (a Built In takes over), in both.
test('a rotation with no switch condition is selected and runs the same in both engines', function()
    local runs = {}

    for _, engine in ipairs({ 'standard', 'lean' }) do
        local c = make(engine, { target = true })
        local a = c.a
        local key = a.currentRotation
        assert(key and key ~= c.e.DEFAULT, 'no rotation selected')
        local seq = {}

        for _, switch in ipairs({ 'empty', 'absent', 'fails' }) do
            local record, token = a:GetRotationRecordSnapshot(0, key)

            if switch == 'empty' then
                record.body.switch = {}
            elseif switch == 'absent' then
                record.body.switch = nil
            else
                record.body.switch = { type = 'LEVEL', unit = 'player', operator = 'GREATERTHANOREQUALS', value = 999 }
            end

            local ref = assert(a:GetScopedRotationCoordinator():Resolve(0, key))
            assert(a:CommitRotationDraft(ref, token, record, 'class'))
            a:HandleCommand('set auto')
            a:UpdateAutoSwitch()
            a:SwitchRotation()

            for _ = 1, 3 do
                c.tick()
                seq[#seq + 1] = switch .. ':' .. tostring(c.a.currentSpell) .. '/' .. tostring(a.currentRotation == key)
            end
        end

        assert(not a.adviceErrorReport, 'advice error')
        runs[engine] = seq
    end

    same(runs.standard, runs.lean, 'no switch condition')

    assert(
        runs.lean[1]:find('/true', 1, true) and runs.lean[4]:find('/true', 1, true) and runs.lean[7]:find(
            '/false',
            1,
            true
        ),
        table.concat(runs.lean, ' ')
    )
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
