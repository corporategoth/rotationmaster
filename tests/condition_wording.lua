-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Renders every registered condition's wording, for you and for a target,
-- positive and under NOT, on every
-- client family, and fails on the text defects the website's condition
-- reference turned up: doubled words ("Cat Form form"), "a" before a vowel
-- ("a Elite"), raw keys where a label belongs ("target is closer", "The minimum
-- health"), leftover format specifiers or named slots, a verb that does not
-- agree with "you" or "your target" across a playerize pair, a plural count
-- used as a singular subject ("talent points in X is", where "the number of"
-- belongs) and a comparison verb in a "when" phrase ("was cast is less than 3
-- casts ago").
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function tocPaths(prefix)
    local result = {}

    for line in io.lines('RotationMaster.toc') do
        local path = line:gsub('\r', ''):match('^%s*(' .. prefix .. '/.-%.lua)%s*$')

        if path then
            result[#result + 1] = path
        end
    end

    assert(#result > 0, 'no ' .. prefix .. ' files in TOC')
    return result
end

-- Every condition file as the client loads it, plus the optional ones: MobInfo2's
-- (RUNNER, RESIST, IMMUNE) and the delayed Extended Character Stats pair.
local function load(project, expansion, class)
    local f = F.new(project, expansion, class)
    local a, e = f.addon, f.env
    e.UnitLevel = function() return 60 end
    e.GetNumShapeshiftForms = function() return 0 end
    e.UnitHasVehicleUI = function() return false end
    e.C_PetBattles = { IsInBattle = function() return false end }
    e.GetBuildInfo = function() return 'fixture', '70006', '', 1 end
    e.RAID, e.PARTY = e.RAID or 'Raid', e.PARTY or 'Party'
    e.MI2_GetMobData = function() return {} end

    e.ECSLoader = {
        ImportModule = function()
            return { GetStatInfo = function(name) return name == 'Crit' and '5.00%' or 100 end }
        end,
    }

    e.ExtendedCharacterStats = {
        profile = { { refName = 'AttackPower', text = 'Attack Power' }, { refName = 'Crit', text = 'Crit' } },
    }

    e.C_Spell = e.C_Spell or {}
    e.C_Spell.GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. tostring(id), iconID = 1 } end

    e.C_Spell.GetSpellLink = function(id)
        return '|cff71d5ff|Hspell:' .. tostring(id) .. '|h[Spell ' .. tostring(id) .. ']|h|r'
    end

    local names = {
        [768] = 'Cat Form',
        [5487] = 'Bear Form',
        [783] = 'Travel Form',
        [2457] = 'Battle Stance',
        [71] = 'Defensive Stance',
        [2645] = 'Ghost Wolf',
        [1784] = 'Stealth',
    }

    e.C_Spell.GetSpellInfo = function(id)
        return { spellID = id, name = names[id] or 'Spell ' .. tostring(id), iconID = 1 }
    end

    e.GetSpellInfo = function(id) return names[id] or 'Spell ' .. tostring(id), nil, 1 end

    e.GetSpellLink = function(id)
        return '|cff71d5ff|Hspell:' .. tostring(id) .. '|h[Spell ' .. tostring(id) .. ']|h|r'
    end

    e.LOCALIZED_CLASS_NAMES_MALE = e.LOCALIZED_CLASS_NAMES_MALE or {
        WARRIOR = 'Warrior',
        DRUID = 'Druid',
        EVOKER = 'Evoker',
        DEATHKNIGHT = 'Death Knight',
        SHAMAN = 'Shaman',
    }

    e.SCHOOL_STRINGS = e.SCHOOL_STRINGS or { 'Physical', 'Holy', 'Fire', 'Nature', 'Frost', 'Shadow', 'Arcane' }
    a.delayed_condition = {}
    f.load('init.lua')
    local defaults = { char = {}, profile = {}, global = {} }
    a:augmentDefaults(defaults)
    a.db = defaults
    a.db.profile.rotations = {}
    a.db.profile.itemsets = {}
    f.load('Core/conditions.lua')

    for _, path in ipairs(tocPaths('Conditions')) do
        f.load(path)
    end

    for _, definitions in pairs(a.delayed_condition) do
        for tag, definition in pairs(definitions) do
            if not a.conditionDefinitions[tag] then
                a:RegisterCondition(tag, definition)
            end
        end
    end

    pcall(f.load, 'Platform/spells.lua')
    pcall(f.load, 'Platform/talents.lua')
    return f, a, e
end

local function keys(map)
    local result = {}

    for k in pairs(map or {}) do
        if k ~= 'fields' then
            result[#result + 1] = k
        end
    end

    table.sort(result, function(x, y) return tostring(x) < tostring(y) end)
    return result
end

local defaults = {
    operator = 'LESSTHAN',
    value = 3,
    spell = 116,
    item = 6948,
    distance = 10,
    health = .5,
    mana = .5,
    healthoperator = 'LESSTHAN',
    manaoperator = 'LESSTHAN',
    operation = 'minimum',
    samegroup = false,
    includepets = true,
    ranked = true,
    offhand = false,
    rune = 1,
    stat = 1,
    threat = 2,
    school = 'fi',
    form = 1,
    mode = 'both',
    slot = 'head',
    loc_type = 'STUN',
    debufftype = 'Magic',
    otherunit = 'focus',
    class = 'DRUID',
    spec = 1,
    encounter = 1,
    set = 1,
    subclass = 1,
    enchant = 1,
    kind = 'spell',
    action = 'HEAL',
    context = 'player',
    tree = 1,
    node = 1,
    entry = 1,
    talent = 1,
}

-- Fields whose valid values are local to the condition's file.
local samples = {
    WEAPON_TYPE = { slot = 'mainhand', kind = 'weapon' },
    FORM = { form = 768 },
    PET_NAME = { value = 'Fluffy' },
    ZONE = { value = 'Orgrimmar' },
}

-- Enumerated fields: every label is rendered, so an article or a raw key shows
-- up for whichever label triggers it. The map is the one the printer reads.
local function enumerations(a, e, tag)
    local byTag = {
        CLASS = { value = e.LOCALIZED_CLASS_NAMES_MALE },
        CLASSIFICATION = { value = a.classifications },
        CREATURE = { value = a.creatures },
        ROLE = { value = a.roles },
        INSTANCE = { value = a.instances },
        ZONEPVP = { value = a.zonepvp },
        CLASS_GROUP = { class = e.LOCALIZED_CLASS_NAMES_MALE },
    }

    local result = {
        operation = a.math_operations,
        action = a.actions,
        mode = a.trendmode,
        debufftype = a.debufftypes,
        loc_type = a.loc_types,
        otherunit = a.units,
        operator = a.operators,
        threat = a.threat,
    }

    for field, map in pairs(byTag[tag] or {}) do
        result[field] = map
    end

    return result
end

local function plain(text)
    return (text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|H.-|h(.-)|h', '%1'))
end

-- Whole-word, case-sensitive search; Lua patterns have no word boundary for
-- multi-byte text, so frontier patterns over ASCII word characters are enough.
local function hasWord(text, word)
    return text:find('%f[%w]' .. word:gsub('%p', '%%%0') .. '%f[%W]') ~= nil
end

local function defects(text, raws)
    local found = {}
    local flat = plain(text)

    if flat:find('Condition summary unavailable', 1, true) then
        found[#found + 1] = 'summary fallback'
    end

    -- Doubled words ("form form", "glyph glyph"), ignoring numbers.
    local previous, placeholder = nil, 0

    local words = flat:gsub('<[^>]*>', function()
        placeholder = placeholder + 1
        return ' placeholder' .. placeholder .. ' '
    end)

    for word in words:gmatch('[%a\'][%w\']*') do
        local lower = word:lower()

        -- "is not Not specified": a negated predicate before the client's own
        -- creature type label is the one legitimate repeat.
        if previous and lower == previous and not lower:match('^%d') and not (lower == 'not' and word == 'Not') then
            found[#found + 1] = 'doubled word "' .. word .. '"'
        end

        previous = lower
    end

    -- "a" before a vowel-initial word; "an" before a consonant.
    for word in flat:gmatch('%f[%w]a ([%a]+)') do
        if
            word:match('^[AEIOaeio]')
            or (word:match('^[Uu]') and not word:match('^[Uu]ni') and not word:match('^[Uu]s'))
        then
            found[#found + 1] = '"a ' .. word .. '"'
        end
    end

    for word in flat:gmatch('%f[%w]an ([%a]+)') do
        if not word:match('^[AEIOUaeiouHh]') then
            found[#found + 1] = '"an ' .. word .. '"'
        end
    end

    -- Leftover string.format specifiers or named/alternative slots.
    if flat:find('%%[%-%d%.]*[sdfgiqxXc]') or flat:find('%%%%') then
        found[#found + 1] = 'format specifier'
    end
    if hasWord(flat, 'nil') then
        found[#found + 1] = 'a nil value printed'
    end
    if flat:find('{[%a_][%w_]*}') or flat:find('{{', 1, true) or flat:find('}}', 1, true) then
        found[#found + 1] = 'unresolved slot'
    end

    -- A label followed by a noun it already contains: "<glyph> glyph",
    -- "[Glyph of Frost Nova] glyph", "<role> role".
    for label, word in flat:gmatch('[%[<]([^%]>]+)[%]>] (%a+)') do
        if hasWord(label:lower(), word:lower()) then
            found[#found + 1] = 'label noun repeated "' .. label .. ' ' .. word .. '"'
        end
    end

    -- Agreement with the subject across a playerize pair. "of you is" is an
    -- object followed by the main verb, not a subject.
    local lower = ' ' .. flat:lower()

    for _, bad in ipairs({
        'you is', 'you has', 'you was', 'you does', 'you\'s', 'your target have', 'your target are', 'your target were',
        'your target do not', '\'s is', '\'s are', '\'s has'
    }) do
        for before in lower:gmatch(
            '(%a*)' .. (bad:sub(1, 1) == "'" and '' or ' ') .. bad:gsub('%p', '%%%0') .. '%f[%W]'
        ) do
            if not ({
                of = true,
                to = true,
                than = true,
                with = true,
                from = true,
                at = true,
                on = true,
                by = true,
                ['for'] = true,
            })[before] then
                found[#found + 1] = '"' .. bad .. '"'
            end
        end
    end

    -- A plural count as the subject of "is": "talent points in X is equal to 2",
    -- "ranks in X is", "stacks of X is". Counts read "the number of ... is".
    local subject = flat:lower():match('^(.-) is ')

    if subject and not subject:find('number of', 1, true) then
        local head = {}

        for word in subject:gmatch('[%a\']+') do
            if word ~= 'the' and word ~= 'your' and word ~= 'a' and word ~= 'an' then
                head[#head + 1] = word
            end

            if #head == 2 then
                break
            end
        end

        for _, word in ipairs(head) do
            if ({
                points = true,
                ranks = true,
                stacks = true,
                charges = true,
                runes = true,
                members = true,
                enemies = true,
                allies = true,
                casts = true,
                actions = true,
                pieces = true,
                units = true,
            })[word] then
                found[#found + 1] = 'plural subject "' .. word .. '" with "is" (use "the number of")'
            end
        end
    end

    -- A "when" phrase takes no comparison verb: "was cast is less than 3 casts
    -- ago" reads "was cast fewer than 3 casts ago".
    if
        flat:find('%f[%a]is not [%a ]-than [^,]- ago%f[%A]')
        or flat:find('%f[%a]is [%a ]-than [^,]- ago%f[%A]')
        or flat:find('%f[%a]is n?o?t? ?equal to [^,]- ago%f[%A]')
        or flat:find('%f[%a]is n?o?t? ?evenly divisible by [^,]- ago%f[%A]')
    then
        found[#found + 1] = 'comparison verb before "ago"'
    end

    -- Raw keys: remove every label first (a label may contain its key, e.g.
    -- "your target"), then the key itself must not remain.
    local stripped = flat
    local labels = {}

    for _, pair in ipairs(raws) do
        for _, label in ipairs(pair.labels) do
            labels[#labels + 1] = label
        end
    end

    table.sort(labels, function(x, y) return #x > #y end)

    for _, label in ipairs(labels) do
        stripped = stripped:gsub(label:gsub('%p', '%%%0'), ' ')
    end

    for _, pair in ipairs(raws) do
        local key = tostring(pair.key)

        if not key:match('^%d+$') and not pair.same and hasWord(stripped, key) then
            found[#found + 1] = 'raw key "' .. key .. '"'
        end
    end

    return found
end

local clients = {
    { 'retail', 1, 12 },
    { 'era', 2, 0 },
    { 'tbc', 5, 1 },
    { 'wrath', 11, 2 },
    { 'mists', 19, 4 },
    { 'forever', 18, 12 },
}

local classes = { 'DEATHKNIGHT', 'SHAMAN', 'DRUID' }
local rendered, checked = 0, {}

for _, client in ipairs(clients) do
    for _, class in ipairs(classes) do
        test('every condition renders clean wording on ' .. client[1] .. '/' .. class, function()
            local f, a, e = load(client[2], client[3], class)
            local problems = {}
            local tags = keys(a.conditionDefinitions)
            assert(#tags > 100, 'conditions did not load: ' .. #tags)

            for _, tag in ipairs(tags) do
                local definition = a.conditionDefinitions[tag]

                if definition.print and definition.fields then
                    checked[tag] = true
                    local enums = enumerations(a, e, tag)
                    local sample = samples[tag] or {}

                    -- Both subjects even where the picker hides one: a saved or imported
                    -- condition can still carry any valid unit.
                    for _, unit in ipairs(definition.fields.unit and { 'player', 'target' } or { false }) do
                        -- One base sample, then each enumerated field across its labels.
                        local variants = { {} }

                        for field, kind in pairs(definition.fields) do
                            local map = enums[field]

                            if map and field ~= 'unit' then
                                for _, k in ipairs(keys(map)) do
                                    variants[#variants + 1] = { [field] = k }
                                end
                            end

                            -- Each flag both ways ("your own", "that is dispellable", off hand).
                            if kind == 'boolean' then
                                variants[#variants + 1] = { [field] = true }
                                variants[#variants + 1] = { [field] = false }
                            end

                            -- Negative thresholds select the deficit wording.
                            if (field == 'value' or field == 'health' or field == 'mana') and kind == 'number' then
                                variants[#variants + 1] = { [field] = -500 }
                            end
                        end

                        for _, variant in ipairs(variants) do
                            local value = { type = tag }

                            for field in pairs(definition.fields) do
                                if field == 'unit' then
                                    value.unit = unit or nil
                                elseif variant[field] ~= nil then
                                    value[field] = variant[field]
                                elseif sample[field] ~= nil then
                                    value[field] = sample[field]
                                elseif enums[field] and field ~= 'unit' then
                                    value[field] = keys(enums[field])[1]
                                elseif defaults[field] ~= nil then
                                    value[field] = defaults[field]
                                end
                            end

                            local raws = {}

                            local function raw(key, ...)
                                local labels = {}

                                for i = 1, select('#', ...) do
                                    local label = select(i, ...)

                                    if type(label) == 'string' then
                                        labels[#labels + 1] = label
                                    end
                                end

                                local same = false

                                for _, label in ipairs(labels) do
                                    if label == key then
                                        same = true
                                    end
                                end

                                raws[#raws + 1] = { key = key, labels = labels, same = same }
                            end

                            if value.unit then
                                raw(value.unit, a.units[value.unit], a.unitsPossessive[value.unit])
                            end
                            if value.otherunit then
                                raw(value.otherunit, a.units[value.otherunit], a.unitsPossessive[value.otherunit])
                            end

                            for field, map in pairs(enums) do
                                if value[field] ~= nil and definition.fields[field] and field ~= 'otherunit' then
                                    raw(
                                        value[field],
                                        map[value[field]],
                                        field == 'operation'
                                            and a.math_operations_prose
                                            and a.math_operations_prose[value[field]]
                                            or nil
                                    )
                                end
                            end

                            for _, node in ipairs({ value, { type = 'NOT', value = value } }) do
                                local ok, text = pcall(a.printCondition, a, node, 0)

                                local label = tag
                                    .. (unit and ' [' .. unit .. ']' or '')
                                    .. (node.type == 'NOT' and ' NOT' or '')

                                if not ok then
                                    problems[#problems + 1] = label .. ': error ' .. tostring(text)
                                else
                                    rendered = rendered + 1

                                    for _, problem in ipairs(defects(text, raws)) do
                                        problems[#problems + 1] = label
                                            .. ': '
                                            .. problem
                                            .. ' in "'
                                            .. plain(text)
                                            .. '"'
                                    end
                                end
                            end
                        end
                    end
                end
            end

            assert(#problems == 0, '\n  ' .. table.concat(problems, '\n  '))
        end)
    end
end

test('the detector itself catches each defect class', function()
    local function has(text, raws, what)
        for _, problem in ipairs(defects(text, raws or {})) do
            if problem:find(what, 1, true) then
                return true
            end
        end

        return false
    end

    assert(has('you are in Cat Form form', nil, 'doubled'))
    assert(has('you have [Glyph of X] glyph glyph', nil, 'doubled'))
    assert(has('your target is a Elite', nil, '"a Elite"'))
    assert(has('your target is a Undead', nil, '"a Undead"'))
    assert(not has('a unit', nil, '"a'))
    assert(has('target is closer than 3 yards', { { key = 'target', labels = { 'your target' } } }, 'raw key'))
    assert(not has('your target is closer than 3 yards', { { key = 'target', labels = { 'your target' } } }, 'raw key'))
    assert(has('The minimum health of Party members', { { key = 'minimum', labels = { 'Minimum' } } }, 'raw key'))
    assert(has('the %s of x', nil, 'format'))
    assert(has('at 50%% health', nil, 'format'))
    assert(not has('at 50% health', nil, 'format'))
    assert(has('the {operation} health', nil, 'slot'))

    assert(
        has('your target have [Spell 1]', nil, 'agreement') or has(
            'your target have [Spell 1]',
            nil,
            'your target have'
        )
    )

    assert(has('you is attackable', nil, 'you is'))
    assert(not has('within 10 yards of you is less than 3', nil, 'you is'))
    assert(has('your target\'s is in a Tank role', nil, "'s is"))
    assert(has('you have <glyph> glyph', nil, 'label noun repeated'))
    assert(not has('talent points in <talent> (<talent tree>)', nil, 'doubled'))
    assert(has('talent points in Improved Execute (Fury) is equal to 2', nil, 'plural subject'))
    assert(has('ranks in Improved Execute is not less than 2', nil, 'plural subject'))
    assert(has('stacks of [Sunder Armor] is 5', nil, 'plural subject'))
    assert(not has('the number of talent points in Improved Execute (Fury) is equal to 2', nil, 'plural subject'))
    assert(not has('the number of stacks of [Sunder Armor] on your target is 5', nil, 'plural subject'))
    assert(not has('the lowest health of Party members within 10 yards is less than 50%', nil, 'plural subject'))
    assert(has('[Spell 1] was cast is less than 3 casts ago', nil, '"ago"'))
    assert(has('you were hit is not less than 3 actions ago', nil, '"ago"'))
    assert(has('[Spell 1] was cast is equal to 3 seconds ago', nil, '"ago"'))
    assert(has('[Spell 1] was cast is evenly divisible by 3 casts ago', nil, '"ago"'))
    assert(not has('[Spell 1] was cast fewer than 3 casts ago', nil, '"ago"'))
    assert(not has('[Spell 1] was not cast less than 3 seconds ago', nil, '"ago"'))
end)

-- The counts and histories the plural and "ago" rules exist for, rendered with
-- every operator, positive and under NOT: TALENT counts talent points (or
-- trait ranks), and the history conditions say when something happened.
test('counts and histories keep their wording under every operator', function()
    local f, a = load(5, 1, 'DRUID')
    local seen = 0

    for _, op in ipairs(keys(a.operators)) do
        for _, case in ipairs({
            { { type = 'TALENT', tree = 1, talent = 1, operator = op, value = 2 }, '^the number of talent points in ' },
            {
                { type = 'SPELL_HISTORY', spell = 116, operator = op, value = 3 },
                ' was cast [%a ]-3 casts ago$',
                ' was not cast [%a ]-3 casts ago$',
            },
            {
                { type = 'SPELL_HISTORY_TIME', spell = 116, operator = op, value = 3 },
                ' was cast [%a ]-3 seconds ago$',
                ' was not cast [%a ]-3 seconds ago$',
            },
            {
                { type = 'PETSPELL_HISTORY', spell = 116, operator = op, value = 3 },
                ' was cast [%a ]-3 casts ago$',
                ' was not cast [%a ]-3 casts ago$',
            },
            {
                { type = 'PETSPELL_HISTORY_TIME', spell = 116, operator = op, value = 3 },
                ' was cast [%a ]-3 seconds ago$',
                ' was not cast [%a ]-3 seconds ago$',
            },
            {
                { type = 'COMBAT_HISTORY', unit = 'player', action = 'WOUND', operator = op, value = 3 },
                '^you were hit [%a ]-3 actions ago$',
                '^you were not hit [%a ]-3 actions ago$',
            },
            {
                { type = 'COMBAT_HISTORY', unit = 'target', action = 'WOUND', operator = op, value = 3 },
                '^your target was hit [%a ]-3 actions ago$',
                '^your target was not hit [%a ]-3 actions ago$',
            },
            {
                { type = 'COMBAT_HISTORY_TIME', unit = 'target', action = 'HEAL', operator = op, value = 3 },
                '^your target was healed [%a ]-3 seconds ago$',
                '^your target was not healed [%a ]-3 seconds ago$',
            },
        }) do
            local node, positive, negative = case[1], case[2], case[3] or case[2]

            for _, pair in ipairs({ { node, positive }, { { type = 'NOT', value = node }, negative } }) do
                local text = plain(a:printCondition(pair[1], 0))
                assert(text:find(pair[2]), node.type .. ' ' .. op .. ': "' .. text .. '"')

                assert(
                    not text:find('%f[%a]is%f[%A]') or node.type == 'TALENT',
                    node.type .. ' ' .. op .. ' compares with "is": "' .. text .. '"'
                )

                local problems = defects(text, {})

                assert(
                    #problems == 0,
                    node.type .. ' ' .. op .. ': ' .. table.concat(problems, '; ') .. ' in "' .. text .. '"'
                )

                seen = seen + 1
            end
        end
    end

    assert(seen == 7 * 8 * 2, 'rendered ' .. seen)
end)

test('the sweep visited every registered condition at least once', function()
    local count = 0

    for _ in pairs(checked) do
        count = count + 1
    end

    assert(count >= 125, 'only ' .. count .. ' conditions checked')
    assert(rendered > 1000, 'only ' .. rendered .. ' renderings')
end)

finish()
