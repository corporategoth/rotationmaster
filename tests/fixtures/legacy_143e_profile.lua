-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- A minimal SavedVariables table in the shape release 1.4.3e wrote (raw AceDB
-- layout: profiles, char, global), derived from that release's defaults,
-- validators and upgrade code. It deliberately holds the older formats the
-- upgrade passes exist for: a cooldown effect stored by NAME, 'pet' steps and
-- PETSPELL_* conditions, rune names, items stored as bare ids, an itemset
-- reference, an indexed effect list and a rotation under a character root.
-- Returns a function that builds a fresh copy each call (AceDB mutates it).
local function uuid(n)
    return string.format('00000000-0000-4000-8000-%012d', n)
end

return function()
    local ITEMSET = uuid(901)

    local function steps(base)
        local list = {}

        local function add(step)
            step.id = uuid(base + #list)
            step.conditions = step.conditions or {}
            list[#list + 1] = step
        end

        add({
            type = 'spell',
            action = 403,
            ranked = true,
            use_name = true,
            name = 'Bolt step',
            conditions = {
                type = 'AND',
                value = {
                    { type = 'COMBAT', unit = 'player' },
                    { type = 'SPELL_AVAIL', spell = 403, ranked = true },
                    {
                        type = 'OR',
                        value = {
                            { type = 'PETSPELL_AVAIL', spell = 3110 },
                            { type = 'RUNE', rune = 'BLOOD', operator = 'GREATERTHAN', value = 1 },
                        },
                    },
                },
            },
        })

        add({ type = 'spell', action = 8042, disabled = true })
        add({ type = 'item', action = 5512 })  -- a bare item id, before item sets
        add({ type = 'item', action = { 5512, 'Healthstone' } })
        add({ type = 'item', action = ITEMSET })
        add({ type = 'pet', action = 3110 })  -- before the 'any' spell step

        add({
            type = 'any',
            action = 8042,
            conditions = { type = 'ITEM_COOLDOWN', item = 5512, operator = 'LESSTHAN', value = 5 },
        })

        return list
    end

    local cooldowns = steps(2000)

    for index, step in ipairs(cooldowns) do
        step.effect = uuid(700 + (index % 2) + 1)
        step.color = { r = .5, g = .5, b = 1, a = 1 }
        step.magnification = 1.7
        step.setpoint = 'TOPLEFT'
        step.xoffs = 3
        step.yoffs = 4
        step.announce = uuid(801)
        step.announce_sound = 'LoudSound'
    end

    cooldowns[2].effect = 'MyPixel'  -- an effect named, not identified
    cooldowns[3].effect = 'NoSuchEffect'  -- named, and gone: kept as it was

    local shaman = {
        version = 2,
        enable = true,
        poll = 0.2,
        ignore_mana = true,
        ignore_range = true,
        effect = uuid(702),
        color = { r = .1, g = .2, b = .3, a = .9 },
        magnification = 2,
        setpoint = 'TOPLEFT',
        xoffs = 5,
        yoffs = 6,
        loglevel = 3,
        detailed_profiling = true,
        disable_autoswitch = true,
        live_config_update = 5,
        spell_history = 30,
        combat_history = 20,
        damage_history = 40,
        disable_buttons = true,
        preview_spells = 3,
        minimap = { hide = true, minimapPos = 123 },
        itemsets = { [uuid(902)] = { name = 'ProfileSet', items = { 13444, 'Mana Potion' } } },
        announces = {
            {
                id = uuid(801),
                name = 'Bolt cast',
                type = 'spell',
                spell = 403,
                ranked = false,
                announce = 'party',
                event = 'SUCCEEDED',
                value = 'Casting %s',
            },
        },
        rotations = {
            [0] = {
                Default = { name = 'Default', switch = {}, cooldowns = cooldowns, rotation = steps(1000) },
                [uuid(11)] = {
                    name = 'Everything',
                    disabled = false,
                    switch = {
                        type = 'AND',
                        value = {
                            { type = 'SELF_LEVEL', operator = 'GREATERTHAN', value = 10 },
                            { type = 'INSTANCE', value = 'party' },
                            { type = 'OUTDOORS' },
                        },
                    },
                    cooldowns = {},
                    rotation = {
                        {
                            id = uuid(3001),
                            type = 'spell',
                            action = 403,
                            conditions = { type = 'NOT', value = { type = 'COMBAT', unit = 'player' } },
                        },
                    },
                },
                [uuid(12)] = {
                    name = 'Solo',
                    switch = { type = 'NOT', value = { type = 'GROUP', raid = true } },
                    cooldowns = {},
                    rotation = { { id = uuid(3002), type = 'spell', action = 8042, conditions = {} } },
                },
            },
        },
    }

    return {
        profileKeys = { ['Fixture Character - Fixture Realm'] = 'SHAMAN', ['Alt - Fixture Realm'] = 'LEGACY' },
        profiles = {
            SHAMAN = shaman,
            -- A profile this character never uses: its archive is upgraded as well.
            LEGACY = {
                debug = true,
                verbose = true,
                overlay = 'MyPixel',
                rotations = {
                    [0] = {
                        Default = {
                            name = 'Default',
                            switch = {},
                            cooldowns = {
                                {
                                    id = uuid(4001),
                                    type = 'pet',
                                    action = 3110,
                                    effect = 'MyPixel',
                                    conditions = { type = 'PETSPELL_RANGE', spell = 3110 },
                                },
                            },
                            rotation = {
                                {
                                    id = uuid(4002),
                                    type = 'spell',
                                    action = 403,
                                    conditions = { type = 'RUNE', rune = 'FROST', operator = 'EQUALS', value = 2 },
                                },
                            },
                        },
                    },
                },
            },
        },
        char = {
            ['Fixture Character - Fixture Realm'] = {
                version = 1,
                bindings = { [uuid(902)] = { 12 }, [ITEMSET] = 34 },
            },
            ['Alt - Fixture Realm'] = {
                rotations = {
                    [0] = {
                        charold = {
                            name = 'Pre-1.3 character rotation',
                            switch = {},
                            cooldowns = {},
                            rotation = {
                                {
                                    id = uuid(5001),
                                    type = 'pet',
                                    action = 3110,
                                    conditions = { type = 'PETSPELL_COOLDOWN', spell = 3110 },
                                },
                            },
                        },
                    },
                },
            },
        },
        global = {
            version = 1,
            itemsets = { [ITEMSET] = { name = 'MyHeals', items = { 5512, 'Healthstone' }, modified = true } },
            effects = {
                [uuid(701)] = { type = 'texture', name = 'MyTex', texture = 'Interface\\Cooldown\\ping4' },
                [uuid(702)] = {
                    type = 'pixel',
                    name = 'MyPixel',
                    lines = 8,
                    frequency = .25,
                    length = 2,
                    thickness = 2,
                },
            },
        },
    }
end
