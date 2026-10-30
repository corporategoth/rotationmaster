-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The implicit auto-attack (Attack or Shoot) through both engines, on the real
-- addon (whole-poll fixture, real buttons.lua): the lean and standard engines
-- must recommend the same thing and publish the same outputs, and a Stop's
-- suppress_attack must hold back Shoot and Auto Shot as well as Attack.
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
local WAND, BOW = 5240, 2504

-- slots 1-4 hold the starter's spells; 5 holds Attack, 6 the ranged auto-attack.
local function make(engine, ranged)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    local c = build({ target = true, combat = true, buttons = true, poll = .15 })
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine))
    local e = c.e

    local s = {
        range = { [6603] = true, [ranged] = true },
        bar = {},
        gear = { [18] = ranged == 5019 and WAND or BOW },
        repeating = {},
        bound = { [5] = 6603, [6] = ranged },
    }

    c.state = s
    local ids = { 403, 8042, 324, 8017 }
    local actionInfo = e.GetActionInfo
    e.HasAction = function(slot) return slot >= 1 and slot <= 4 or s.bound[slot] ~= nil end

    e.GetActionInfo = function(slot)
        if slot <= 4 then
            return actionInfo(slot)
        end
        if s.bound[slot] then
            return 'spell', s.bound[slot]
        end
    end

    for i = 5, 6 do
        local slot = i
        local button = e.CreateFrame('Button', nil, e.UIParent)
        button.action = i
        button:SetSize(36, 36)

        button.GetAttribute = function(_, key)
            if key == 'type' then
                return 'action'
            elseif key == 'action' then
                return slot
            end
        end

        e['ActionButton' .. i] = button
    end

    local inRange = e.C_Spell.IsSpellInRange

    e.C_Spell.IsSpellInRange = function(id, ...)
        if s.range[id] ~= nil or id == 6603 or id == ranged then
            return s.range[id]
        end

        return inRange(id, ...)
    end

    e.C_Spell.IsAutoRepeatSpell = function(id) return s.repeating[id] == true end
    e.C_ActionBar = e.C_ActionBar or {}

    e.C_ActionBar.IsActionInRange = function(slot)
        local id = s.bound[slot]

        if id then
            return s.bar[id]
        end

        return nil
    end

    e.GetInventoryItemID = function(_, slot) return s.gear[slot] end
    e.C_Item = e.C_Item or {}

    e.C_Item.GetItemInfoInstant = function(item)
        if item == WAND then
            return item, 'Weapon', 'Wands', 'INVTYPE_RANGEDRIGHT', 1, 2, 19
        end
        if item == BOW then
            return item, 'Weapon', 'Bows', 'INVTYPE_RANGED', 1, 2, 2
        end
    end

    c.a:Fetch()

    for _ = 1, 6 do
        c.tick()
    end

    return c
end

local function write(c, rotation)
    local key = c.a.currentRotation
    local record, token = c.a:GetRotationRecordSnapshot(0, key)
    assert(record and token)
    record.body.rotation = rotation
    local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, key))
    assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
    c.tick()
    c.tick()
end

-- A rotation that recommends nothing: its one step is switched off.
local idle = { { id = 'bolt', type = 'spell', action = 403, disabled = true, conditions = {} } }

local function stopping(suppress)
    return {
        { id = 'halt', type = 'stop', suppress_attack = suppress, conditions = {} },
        { id = 'bolt', type = 'spell', action = 403, conditions = {} },
    }
end

local function delivered(c)
    local _, rows = c.snapshot()
    local out = {}

    for _, v in ipairs(rows) do
        if v:match('^WeakAuras|') or v:match('^SendMessage|') or v:match('^Texture%.') then
            out[#out + 1] = v
        end
    end

    return out
end

local function observe(c)
    c.reset(true)
    c.tick()
    c.tick()
    local advice = c.a.currentSpell
    local rows = delivered(c)
    c.reset(false)
    assert(not c.a.adviceErrorReport, 'advice error')
    return advice, rows
end

local function both(ranged, steps)
    local s, l = make('standard', ranged), make('lean', ranged)

    for _, c in ipairs({ s, l }) do
        write(c, idle)
    end

    for _, step in ipairs(steps) do
        local name, change, expected = step[1], step[2], step[3]

        for _, c in ipairs({ s, l }) do
            change(c, c.state)
        end

        local a1, r1 = observe(s)
        local a2, r2 = observe(l)
        assert(a1 == expected, name .. ': standard recommended ' .. tostring(a1) .. ', expected ' .. tostring(expected))
        assert(a2 == expected, name .. ': lean recommended ' .. tostring(a2) .. ', expected ' .. tostring(expected))
        assert(#r1 == #r2, name .. ': ' .. #r1 .. ' vs ' .. #r2 .. ' output rows')

        for i = 1, #r1 do
            assert(r1[i] == r2[i], name .. ' output row ' .. i .. ': ' .. tostring(r1[i]) .. ' vs ' .. tostring(r2[i]))
        end
    end

    assert(l.a:GetEvaluationEngine() == 'lean', 'lean plan never engaged: ' .. l.a:GetEvaluationEngine())
end

test('wand user: Attack in melee, Shoot beyond it, nothing out of range, both engines alike', function()
    both(5019, {
        { 'melee', function() end, 6603 },
        {
            'beyond melee, wand range from the button',
            function(_, s)
                s.range[6603] = false
                s.bar[5019] = true
            end,
            5019,
        },
        {
            'button out of range',
            function(_, s)
                s.bar[5019] = false
            end,
            nil,
        },
        {
            'no button indicator, spell range in',
            function(_, s)
                s.bar[5019] = nil
                s.range[5019] = true
            end,
            5019,
        },
        {
            'out of range of everything',
            function(_, s)
                s.range[5019] = false
            end,
            nil,
        },
        {
            'back in wand range',
            function(_, s)
                s.range[5019] = true
            end,
            5019,
        },
        {
            'wand already shooting',
            function(_, s)
                s.repeating[5019] = true
            end,
            nil,
        },
        {
            'wand stopped',
            function(_, s)
                s.repeating[5019] = nil
            end,
            5019,
        },
        {
            'no wand equipped',
            function(_, s)
                s.gear = {}
            end,
            nil,
        },
        {
            'wand back on',
            function(_, s)
                s.gear = { [18] = WAND }
            end,
            5019,
        },
        {
            'Shoot taken off the bars',
            function(c, s)
                s.bound[6] = nil
                c.a:Fetch()
            end,
            nil,
        },
        {
            'Shoot back on the bars',
            function(c, s)
                s.bound[6] = 5019
                c.a:Fetch()
            end,
            5019,
        },
        {
            'secret melee range',
            function(c, s)
                local opaque = {}
                c.e.canaccessvalue = function(v) return v ~= opaque end
                s.range[6603] = opaque
            end,
            nil,
        },
        {
            'melee again',
            function(_, s)
                s.range[6603] = true
            end,
            6603,
        },
    })
end)

test('hunter: Auto Shot beyond melee range on a Classic client, Attack inside it', function()
    both(75, {
        { 'melee', function() end, 6603 },
        {
            'beyond melee',
            function(_, s)
                s.range[6603] = false
            end,
            75,
        },
        {
            'Auto Shot running',
            function(_, s)
                s.repeating[75] = true
            end,
            nil,
        },
        {
            'Auto Shot stopped, target too far',
            function(_, s)
                s.repeating[75] = nil
                s.range[75] = false
            end,
            nil,
        },
        {
            'Auto Shot off the bars',
            function(c, s)
                s.range[75] = true
                s.bound[6] = nil
                c.a:Fetch()
            end,
            nil,
        },
    })
end)

test('suppress_attack on a matching Stop holds back Shoot as well as Attack, in both engines', function()
    for _, suppress in ipairs({ true, false }) do
        local s, l = make('standard', 5019), make('lean', 5019)

        for _, c in ipairs({ s, l }) do
            write(c, stopping(suppress))
        end

        for _, melee in ipairs({ true, false }) do
            for _, c in ipairs({ s, l }) do
                c.state.range[6603] = melee
            end

            local expected = not suppress and (melee and 6603 or 5019) or nil
            local a1 = observe(s)
            local a2 = observe(l)

            assert(
                a1 == expected and a2 == expected,
                ('suppress=%s melee=%s: standard %s, lean %s, expected %s'):format(
                    tostring(suppress),
                    tostring(melee),
                    tostring(a1),
                    tostring(a2),
                    tostring(expected)
                )
            )
        end
    end
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
