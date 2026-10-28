-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local prefix = assert(read('tests/nameplate_lifecycle.lua'):match('^(.-)\ntest%('))
local original = assert(loadstring(prefix .. '\nreturn fixture', '@resume-fixture'))()
local passed, failed = 0, 0

local function test(name, fn)
    local ok, why = pcall(fn)

    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(name .. ': ' .. tostring(why) .. '\n')
    end
end

local function fixture()
    local a, e = original()
    local s = { guids = { nameplate1 = 'Creature-A' }, exists = { nameplate1 = true }, frames = {} }

    e.UnitGUID = function(unit)
        if s.onGUID then
            s.onGUID(unit)
        end

        return s.guids[unit]
    end

    e.UnitExists = function(unit) return s.exists[unit] == true end

    e.UnitName = function(unit)
        if s.onName then
            s.onName(unit)
        end

        return 'Name ' .. unit
    end

    e.C_NamePlate = {
        GetNamePlates = function()
            if s.onList then
                s.onList()
            end

            return s.frames
        end,
    }

    a.RegisterEvent = a.RegisterEvent or function() end
    a.DestroyAllGlows = a.DestroyAllGlows or function() end

    a.UnregisterAllEvents = function()
        s.disabled = true
    end

    a.UpdateSkill = function() end
    a.EnableRotation = function() end
    a.RefreshPreviewWindow = nil

    local function frame(unit)
        return { IsForbidden = function() return false end, GetUnit = function() return unit end }
    end

    local function add(unit)
        a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED', unit or 'nameplate1')
    end

    add()
    local old = assert(a.unitsInRange['Creature-A'])
    a:disable()
    assert(s.disabled)
    return a, e, s, old, add, frame
end

test('actual missed REMOVE retired at enable', function()
    local a, e, s = fixture()
    s.guids.nameplate1 = nil
    s.exists.nameplate1 = false
    a:enable()
    assert(not a.unitsInRange['Creature-A'], 'stale record retained')
end)

test('still visible identity and newly visible plate reseeded', function()
    local a, e, s, old, add, frame = fixture()
    s.guids.nameplate2 = 'Creature-B'
    s.exists.nameplate2 = true
    s.frames = { frame('nameplate1'), frame('nameplate2') }
    a:enable()
    assert(a.unitsInRange['Creature-A'] == old)
    assert(a.unitsInRange['Creature-B'].unit == 'nameplate2')
end)

test('positive alias preserves old identity on token reuse', function()
    local a, e, s, old, add, frame = fixture()
    s.guids.target = 'Creature-A'
    s.guids.nameplate1 = 'Creature-B'
    s.frames = { frame('nameplate1') }
    a:enable()
    assert(a.unitsInRange['Creature-A'] == old and old.unit == 'target')
    assert(a.unitsInRange['Creature-B'])
end)

test('unknown enumeration preserves entire old map', function()
    for _, mode in ipairs({ 'missing', 'error', 'nil', 'tokenless', 'forbidden', 'restricted' }) do
        local a, e, s, old, add, frame = fixture()
        local snapshot = a.unitsInRange
        s.guids.nameplate1 = nil
        s.exists.nameplate1 = false

        if mode == 'missing' then
            e.C_NamePlate = nil
        elseif mode == 'error' then
            e.C_NamePlate.GetNamePlates = function()
                error('unavailable')
            end
        elseif mode == 'nil' then
            s.frames = nil
        elseif mode == 'tokenless' then
            s.frames = { frame(nil) }
        elseif mode == 'forbidden' then
            local f = frame('nameplate1')
            f.IsForbidden = function() return true end
            s.frames = { f }
        else
            e.canaccessvalue = function() return false end
        end

        a:enable()
        assert(a.unitsInRange == snapshot and snapshot['Creature-A'] == old, mode)
    end
end)

test('partial enumeration cannot delete positive native membership', function()
    local a, e, s, old = fixture()
    s.frames = {}
    a:enable()
    assert(a.unitsInRange['Creature-A'] == old)
end)

test('unknown absence and nonstandard units survive', function()
    local a, e, s, old = fixture()
    s.guids.nameplate1 = nil
    e.UnitExists = function() return nil end
    a.unitsInRange.Script = { unit = 'customPlate' }
    a:enable()
    assert(a.unitsInRange['Creature-A'] == old and a.unitsInRange.Script)
end)

test('nested ADD wins without staged stale cleanup', function()
    local a, e, s, old, add, frame = fixture()
    s.guids.nameplate1 = nil
    s.exists.nameplate1 = false

    s.onList = function()
        s.onList = nil
        s.guids.nameplate1 = 'Creature-B'
        s.exists.nameplate1 = true
        add()
    end

    a:enable()
    assert(a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A'])
end)

test('nested enable wins old transaction', function()
    local a, e, s, old, add, frame = fixture()

    s.onList = function()
        s.onList = nil
        s.guids.nameplate1 = 'Creature-B'
        s.frames = { frame('nameplate1') }
        a:enable()
    end

    a:enable()
    assert(a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A'])
end)

test('direct record and root replacement win', function()
    for _, root in ipairs({ false, true }) do
        local a, e, s = fixture()
        local newer = { unit = 'nameplate1' }
        s.guids.nameplate1 = nil
        s.exists.nameplate1 = false

        s.onList = function()
            if root then
                a.unitsInRange = { Newer = newer }
            else
                a.unitsInRange['Creature-A'] = newer
            end
        end

        a:enable()
        assert(root and a.unitsInRange.Newer == newer or not root and a.unitsInRange['Creature-A'] == newer)
    end
end)

test('pooled frame reuse during metadata aborts all staged changes', function()
    local a, e, s, old, add, frame = fixture()
    local token = 'nameplate2'
    s.guids.nameplate2 = 'Creature-B'
    s.guids.nameplate3 = 'Creature-C'
    s.exists.nameplate2 = true
    s.frames = { { IsForbidden = function() return false end, GetUnit = function() return token end } }

    s.onName = function()
        token = 'nameplate3'
    end

    a:enable()
    assert(a.unitsInRange['Creature-A'] == old and not a.unitsInRange['Creature-B'])
end)

test('profile change stops old enable reconciliation', function()
    local a, e, s, old = fixture()
    s.guids.nameplate1 = nil
    s.exists.nameplate1 = false

    s.onList = function()
        local profile = {}

        for k, v in pairs(a.db.profile) do
            profile[k] = v
        end

        a.db.profile = profile
    end

    a:enable()
    assert(a.unitsInRange['Creature-A'] == old)
end)

test('nested REMOVE and direct stored unit changes win', function()
    for _, event in ipairs({ false, true }) do
        local a, e, s, old = fixture()
        s.guids.nameplate1 = nil
        s.exists.nameplate1 = false

        s.onList = function()
            if event then
                a:NAME_PLATE_UNIT_REMOVED('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
            else
                old.unit = 'customPlate'
            end
        end

        a:enable()

        assert(
            event and not a.unitsInRange['Creature-A']
                or not event and a.unitsInRange['Creature-A'] == old and old.unit == 'customPlate'
        )
    end
end)

test('new snapshot slots survive stale transaction', function()
    local a, e, s, old = fixture()
    s.guids.nameplate1 = nil
    s.exists.nameplate1 = false
    local new = { unit = 'customPlate' }

    s.onList = function()
        a.unitsInRange.New = new
    end

    a:enable()
    assert(a.unitsInRange.New == new and a.unitsInRange['Creature-A'] == old)
end)

test('snapshot or record metatable changes abort staging', function()
    for _, root in ipairs({ false, true }) do
        local a, e, s, old = fixture()
        s.guids.nameplate1 = nil
        s.exists.nameplate1 = false

        s.onList = function()
            setmetatable(root and a.unitsInRange or old, {})
        end

        a:enable()
        assert(a.unitsInRange['Creature-A'] == old)
    end
end)

test('native callback cannot replace commit primitives', function()
    local a, e, s = fixture()
    s.guids.nameplate1 = nil
    s.exists.nameplate1 = false
    local writes = 0
    local original = e.rawset

    s.onList = function()
        e.rawset = function(...)
            writes = writes + 1
            return original(...)
        end
    end

    a:enable()
    assert(writes == 0, 'public replacement invoked during commit')
    assert(not a.unitsInRange['Creature-A'])
end)

test('late GUID callback pool reuse is rechecked before commit', function()
    local a, e, s, old = fixture()
    local token = 'nameplate2'
    s.guids.nameplate2 = 'Creature-B'
    s.exists.nameplate2 = true
    s.frames = { { IsForbidden = function() return false end, GetUnit = function() return token end } }
    local reads = 0

    s.onGUID = function(unit)
        if unit == 'nameplate2' then
            reads = reads + 1

            if reads == 2 then
                token = 'nameplate3'
            end
        end
    end

    a:enable()
    assert(reads >= 2)

    assert(
        a.unitsInRange['Creature-A'] == old and not a.unitsInRange['Creature-B'],
        'late pooled binding was published'
    )
end)

print(string.format('Nameplate resume: %d passed, %d failed', passed, failed))

if failed > 0 then
    os.exit(1)
end
