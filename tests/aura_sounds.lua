-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Game-played announcement sounds (Core/aura_sounds.lua): a cooldown whose folded conditions are only own-buff checks
-- and whose announcement has a sound is registered with C_UnitAuras.AddAuraSound for the aura event that makes it
-- true, every rank included; anything else is not; registrations change only out of combat and are dropped when the
-- rotation stops.
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

local added, removed, nextHandle, combat, onEvent = {}, {}, 0, false, nil
local known, policy = { [408510] = true }, 'restricted'

_G.Enum = { UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 } }

_G.C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        nextHandle = nextHandle + 1

        added[nextHandle] = {
            trigger = trigger,
            spell = info.spellID,
            file = info.soundFileName,
            unit = info.unitToken,
        }

        return nextHandle
    end,
    RemoveAuraSound = function(handle)
        removed[#removed + 1] = handle
        added[handle] = nil
    end,
}

_G.InCombatLockdown = function() return combat end

_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn)
            onEvent = fn
        end,
    }
end

_G.LibStub = function(name)
    assert(name == 'LibSharedMedia-3.0')

    return {
        Fetch = function(_, kind, key) return kind == 'sound' and key == 'Alarm' and 'Sound\\alarm.ogg' or nil end,
    }
end

local addon = {
    Platform = {
        GetCombatDataPolicy = function() return policy end,
        CanReadValue = function() return true end,
    },
    SpellCatalog = {
        GetAllSpellIds = function(_, id) return id == 324 and { 324, 325, 905 } or { id } end,
    },
}

function addon:evaluateConditionResult(node)
    return { status = known[node.spell] and 'match' or 'no-match' }
end

assert(loadfile('Core/condition_folding.lua'))('RotationMaster', addon)
assert(loadfile('Core/aura_sounds.lua'))('RotationMaster', addon)

local function buff(spell)
    return { type = 'BUFF', unit = 'player', spell = spell }
end

local function NOT(node)
    return { type = 'NOT', value = node }
end

local water = {
    id = 'water-shield',
    type = 'spell',
    action = 408510,
    announce_sound = 'Alarm',
    conditions = NOT({ type = 'OR', value = { buff(408510), buff(324) } }),
}

local lightning = {
    id = 'lightning-shield',
    type = 'spell',
    action = 324,
    announce_sound = 'Alarm',
    conditions = {
        type = 'AND',
        value = { NOT({ type = 'SPELL_KNOWN', spell = 408510 }), NOT(buff(324)) },
    },
}

local function count()
    local n, spells = 0, {}

    for _, entry in pairs(added) do
        n = n + 1
        spells[#spells + 1] = entry.spell
    end

    table.sort(spells)
    return n, table.concat(spells, ',')
end

test(
    'the shaman shields: Water Shield sounds on either shield dropping, every rank; Lightning Shield folds away',
    function()
        addon:SyncAuraSounds({ water, lightning })
        local n, spells = count()
        assert(n == 4 and spells == '324,325,905,408510', spells)

        for _, entry in pairs(added) do
            assert(entry.trigger == 2 and entry.file == 'Sound\\alarm.ogg' and entry.unit == 'player')
        end

        assert(addon:IsAuraSoundRegistered('water-shield') and not addon:IsAuraSoundRegistered('lightning-shield'))
    end
)

test('an unchanged set registers nothing again; a changed one swaps; clearing drops all', function()
    local before = nextHandle
    addon:SyncAuraSounds({ water, lightning })
    assert(nextHandle == before, 're-registered')
    known[408510] = false
    addon:SyncAuraSounds({ water, lightning })
    assert(addon:IsAuraSoundRegistered('lightning-shield'), 'Lightning Shield once Water Shield is unknown')
    addon:ClearAuraSounds()
    assert(count() == 0 and not addon:IsAuraSoundRegistered('water-shield'))
    known[408510] = true
end)

test('in combat the change waits for combat to end', function()
    combat = true
    addon:SyncAuraSounds({ water })
    assert(count() == 0, 'registered in combat')
    combat = false
    onEvent()
    assert(addon:IsAuraSoundRegistered('water-shield'))
    addon:ClearAuraSounds()
end)

test('no sound, a disabled step, other conditions or an unrestricted client register nothing', function()
    local silent = { id = 'a', announce_sound = '', conditions = NOT(buff(1)) }
    local off = { id = 'b', announce_sound = 'Alarm', disabled = true, conditions = NOT(buff(1)) }

    local mixed = {
        id = 'c',
        announce_sound = 'Alarm',
        conditions = { type = 'AND', value = { NOT(buff(1)), { type = 'COMBAT' } } },
    }

    local target = {
        id = 'd',
        announce_sound = 'Alarm',
        conditions = NOT({ type = 'BUFF', unit = 'target', spell = 1 }),
    }

    addon:SyncAuraSounds({ silent, off, mixed, target })
    assert(count() == 0)
    policy = 'probe'
    addon:SyncAuraSounds({ water })
    assert(count() == 0, 'RM announces itself where auras are readable')
    policy = 'restricted'
end)

test('trigger shapes: have the buff, lack it, lack all of several', function()
    assert(addon:GetAuraSoundTrigger({ type = 'AND', value = { buff(1) } }) == 'Added')
    local trigger, leaves = addon:GetAuraSoundTrigger({ type = 'AND', value = { NOT(buff(1)), NOT(buff(2)) } })
    assert(trigger == 'Removed' and #leaves == 2)
    assert(addon:GetAuraSoundTrigger(NOT({ type = 'AND', value = { buff(1), buff(2) } })) == nil)
    assert(addon:GetAuraSoundTrigger(false) == nil)
end)

print(('%d passed, %d failed'):format(pass, fail))

if fail > 0 then
    os.exit(1)
end
