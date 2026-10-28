-- Unbinding an item set clears its bound slots by picking the item up, which
-- must never swap with or discard what the cursor already holds.
local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/startup.lua'):match('^(.-)\ntest%('))

local fixture, initialize = assert(loadstring(
    prefix .. '\nreturn fixture,initialize',
    '@item-set-unbind-startup-fixture'
))()

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function world()
    local env, a, load = fixture()
    load('main.lua')
    initialize(a)
    a.debug = function() end
    a.ButtonFetch = function() end
    a.db.char.bindings = { mana = { 1, 2 } }

    local w = {
        actions = { [1] = { kind = 'item', id = 11 }, [2] = { kind = 'item', id = 11 } },
        cursor = nil,
        timers = {},
    }

    env.GetActionInfo = function(slot)
        local v = w.actions[slot]

        if v then
            return v.kind, v.id
        end
    end

    env.GetCursorInfo = function()
        if w.cursor then
            return w.cursor.kind, w.cursor.id
        end
    end

    env.ClearCursor = function()
        w.cursor = nil
    end

    -- Picking up an action swaps it with whatever the cursor holds.
    env.PickupAction = function(slot)
        local held = w.actions[slot]
        w.actions[slot] = w.cursor
        w.cursor = held
    end

    env.C_Timer = {
        After = function(_, fn)
            w.timers[#w.timers + 1] = fn
        end,
    }

    env.InCombatLockdown = function() return false end
    a.FindItemInItemSet = function(_, id, item) return id == 'mana' and item == 11 and 1 or nil end

    local function flush()
        local t = w.timers
        w.timers = {}

        for _, fn in ipairs(t) do
            fn()
        end
    end

    return a, w, flush
end

test('unbind with an empty cursor clears the bound slots at once', function()
    local a, w = world()
    assert(a:UnbindItemSet('mana'))
    assert(a.db.char.bindings.mana == nil and w.actions[1] == nil and w.actions[2] == nil and w.cursor == nil)
end)

test('unbind while the cursor holds something keeps it and clears the slots later', function()
    local a, w, flush = world()
    w.cursor = { kind = 'spell', id = 403 }
    assert(a:UnbindItemSet('mana'))
    assert(a.db.char.bindings.mana == nil, 'binding not removed at once')
    assert(w.cursor.kind == 'spell' and w.cursor.id == 403, 'held action was swapped or discarded')
    assert(w.actions[1].id == 11 and w.actions[2].id == 11, 'slots touched while the cursor was busy')
    flush()
    assert(w.actions[1].id == 11, 'cleared while still busy')
    w.cursor = nil
    flush()
    assert(w.actions[1] == nil and w.actions[2] == nil and w.cursor == nil, 'slots not cleared once the cursor emptied')
end)

finish()
