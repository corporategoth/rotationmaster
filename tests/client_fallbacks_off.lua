-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Clients with loadDeprecationFallbacks off (Blizzard's default is on, but a player or
-- a future patch can turn it off) and Retail/Forever globals removed outright: the
-- engine reaches the same results through the C_* APIs (tests/fixtures/client_api_*.lua).
local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/startup.lua'):match('^(.-)\ntest%('))

local fixture, initialize = assert(loadstring(
    prefix .. '\nreturn fixture,initialize',
    '@client-fallbacks-startup-fixture'
))()

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- An Era client: the startup fixture on WOW_PROJECT_CLASSIC with LibClassicDurations.
local function era(fallbacks)
    local env, a, load = fixture(true, true)
    env.WOW_PROJECT_ID = 2
    local registered = 0
    local lib = env.LibStub

    env.LibStub = function(name, ...)
        if name == 'LibClassicDurations' then
            return {
                Register = function()
                    registered = registered + 1
                end,
            }
        end

        return lib(name, ...)
    end

    if fallbacks then
        env.UnitAura = function() end
        env.CombatLogGetCurrentEventInfo = function() end
    end

    load('main.lua')
    initialize(a)
    a.debug = function() end
    return env, a, function() return registered end
end

test('Era registers LibClassicDurations only while the globals it captured exist', function()
    local _, _, registered = era(true)
    assert(registered() == 1, 'fallbacks on: library not registered')
    _, _, registered = era(false)
    assert(registered() == 0, 'fallbacks off: the library would run into a nil UnitAura on every combat-log event')
end)

test('Era with fallbacks off reads the combat-log payload through C_CombatLog and keeps advising', function()
    local env, a = era(false)
    a.damageHistory = {}
    assert(env.CombatLogGetCurrentEventInfo == nil)

    env.C_CombatLog = {
        GetCurrentEventInfo = function()
            return 100,
                'SPELL_DAMAGE',
                false,
                'Player-2',
                'Other',
                0,
                0,
                'Creature-7',
                'Boar',
                0,
                0,
                133,
                'Fireball',
                4,
                250
        end,
    }

    a:COMBAT_LOG_EVENT_UNFILTERED('COMBAT_LOG_EVENT_UNFILTERED')
    local entry = a.damageHistory['Creature-7']
    assert(entry and entry.damage[1] and entry.damage[1].value == 250, 'combat-log damage not recorded')
    assert(not a.adviceErrorReport and not a.initializationErrorReport, 'the handler failed and stopped advice')
end)

-- Item-set binding on a client that has only C_Item.PickupItem (Retail, Forever; Classic
-- with fallbacks off): the cursor receives the set's first item.
test('item-set binding picks the item up through C_Item where PickupItem is gone', function()
    local env, a, load = fixture(true, true)
    load('main.lua')
    initialize(a)
    load('UI/item_set_binding.lua')
    a.debug = function() end
    a.ButtonFetch = function() end
    a.db.char.bindings = {}
    local cursor
    env.PickupItem = nil

    env.C_Item = {
        PickupItem = function(id)
            cursor = id
        end,
    }

    env.InCombatLockdown = function() return false end

    env.GetCursorInfo = function()
        if cursor then
            return 'item', cursor
        end
    end

    env.C_Timer = { After = function() end }
    a.WatchItemSetBind = function() end
    local ok, why = a:BeginItemSetBind('mana', 11)
    assert(ok and why == nil and cursor == 11, 'bind failed: ' .. tostring(why))
end)

finish()
