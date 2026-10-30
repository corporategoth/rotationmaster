-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The by-name aura lookup must give exactly what walking every aura gives.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(records, byName)
    local f = F.new()
    f.env.UnitExists = function(unit) return unit ~= 'none' end
    local lookups = 0

    local function admitted(record, filter)
        local helpful = filter:find('HELPFUL', 1, true) ~= nil

        if (record.helpful ~= false) ~= helpful then
            return false
        end
        if filter:find('PLAYER', 1, true) and record.sourceUnit ~= 'player' then
            return false
        end

        return true
    end

    local function copy(r)
        local c = {}

        for k, v in pairs(r) do
            if k ~= 'helpful' then
                c[k] = v
            end
        end

        return c
    end

    f.env.C_UnitAuras = {
        GetAuraDataByIndex = function(_, index, filter)
            local n = 0

            for _, r in ipairs(records) do
                if admitted(r, filter) then
                    n = n + 1

                    if n == index then
                        return copy(r)
                    end
                end
            end
        end,
    }

    if byName then
        f.env.C_UnitAuras.GetAuraDataBySpellName = function(_, name, filter)
            lookups = lookups + 1

            for _, r in ipairs(records) do
                if r.name == name and admitted(r, filter) then
                    return copy(r)
                end
            end
        end
    end

    f.env.C_Spell = {
        GetSpellInfo = function(id)
            local names = {
                [324] = 'Lightning Shield',
                [325] = 'Lightning Shield',
                [974] = 'Earth Shield',
                [8017] = 'Rockbiter',
            }

            return names[id] and { name = names[id], spellID = id, iconID = 1 }
        end,
    }

    f.env.GetTime = function() return 100 end

    for _, path in ipairs({
        'Platform/client.lua',
        'Platform/spells.lua',
        'Platform/auras.lua',
        'Core/conditions.lua',
        'Core/aura_conditions.lua',
        'Conditions/buffs.lua',
        'Conditions/debuffs.lua',
    }) do
        f.load(path)
    end

    f.addon.Platform.secretsUnrestricted = true
    return f, function() return lookups end
end

local scenarios = {
    {},
    {
        {
            name = 'Lightning Shield',
            spellId = 324,
            sourceUnit = 'player',
            applications = 3,
            duration = 600,
            expirationTime = 400,
        },
    },
    {
        {
            name = 'Lightning Shield',
            spellId = 325,
            sourceUnit = 'player',
            applications = 2,
            duration = 600,
            expirationTime = 110,
        },
    },
    {
        {
            name = 'Earth Shield',
            spellId = 974,
            sourceUnit = 'party2',
            applications = 6,
            duration = 600,
            expirationTime = 200,
        },
        {
            name = 'Earth Shield',
            spellId = 974,
            sourceUnit = 'player',
            applications = 2,
            duration = 600,
            expirationTime = 103,
        },
    },
    {
        {
            name = 'Rockbiter',
            spellId = 8017,
            sourceUnit = 'player',
            applications = 0,
            duration = 0,
            expirationTime = 0,
        },
        {
            name = 'Lightning Shield',
            spellId = 325,
            sourceUnit = 'party1',
            applications = 1,
            duration = 600,
            expirationTime = 150,
        },
        {
            name = 'Lightning Shield',
            spellId = 324,
            sourceUnit = 'player',
            applications = 3,
            duration = 600,
            expirationTime = 120,
        },
    },
    {
        {
            name = 'Lightning Shield',
            spellId = 324,
            sourceUnit = 'player',
            helpful = false,
            applications = 1,
            duration = 10,
            expirationTime = 105,
        },
    },
}

local values = {}

for _, tag in ipairs({ 'BUFF', 'BUFF_REMAIN', 'BUFF_STACKS', 'DEBUFF', 'DEBUFF_REMAIN', 'DEBUFF_STACKS' }) do
    for _, spell in ipairs({ 324, 325, 974, 'Lightning Shield', 'Earth Shield', 9999 }) do
        for _, flags in ipairs({
            {},
            { anyrank = true },
            { ownbuff = true, owndebuff = true },
            { anyrank = true, ownbuff = true, owndebuff = true },
        }) do
            for _, op in ipairs({ 'LESSTHAN', 'GREATERTHAN' }) do
                local v = {
                    type = tag,
                    unit = 'player',
                    spell = spell,
                    operator = op,
                    value = tag:find('STACKS') and 2 or 30,
                }

                for k, x in pairs(flags) do
                    v[k] = x
                end

                values[#values + 1] = v
            end
        end
    end
end

test('by-name lookup matches the full walk for every scenario and condition', function()
    local used = 0

    for i, records in ipairs(scenarios) do
        local walk = fixture(records, false)
        local fast, lookups = fixture(records, true)

        for _, v in ipairs(values) do
            local a, b = walk.addon:evaluateConditionResult(v), fast.addon:evaluateConditionResult(v)

            assert(a.status == b.status, ('scenario %d %s spell=%s anyrank=%s own=%s: walk %s, lookup %s'):format(
                i,
                v.type,
                tostring(v.spell),
                tostring(v.anyrank),
                tostring(v.ownbuff),
                a.status,
                b.status
            ))
        end

        used = used + lookups()
    end

    assert(used > 0, 'lookup never used')
end)

finish()
