-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Historical namespace proof; dedicated CREATURE/ROLE/MobInfo2 suites cover current readiness.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local cases = dofile('tests/fixtures/catalog_inventory.lua').branches

local tags = {
    'ISSAME', 'CLASS', 'CLASS_GROUP', 'ROLE', 'GLYPH', 'CREATURE', 'CLASSIFICATION', 'LEVEL', 'GROUP', 'RUNNER',
    'RESIST', 'IMMUNE'
}

local owners = {
    isin = 'values',
    compare = 'values',
    nullable = 'presentation',
    compareString = 'presentation',
    playerize = 'presentation',
    getCached = 'cache',
    deepcopy = 'collections',
    keys = 'collections',
}

local expected = {
    isin = 21,
    compare = 4,
    nullable = 23,
    compareString = 3,
    playerize = 4,
    getCached = 19,
    deepcopy = 8,
    keys = 4,
}

local branchCounts = { 61, 47, 47, 56, 56, 56, 56, 68 }

local baselineHashes = {
    ['CLASS:common'] = 3088725613,
    ['CLASSIFICATION:common'] = 3454430665,
    ['CLASS_GROUP:common'] = 1911721314,
    ['CREATURE:common'] = 1392664048,
    ['GLYPH:common'] = 233563292,
    ['GROUP:common'] = 1891586705,
    ['IMMUNE:common'] = 3885939024,
    ['ISSAME:common'] = 2733275963,
    ['LEVEL:common'] = 2839935621,
    ['RESIST:common'] = 899540765,
    ['ROLE:inspect'] = 1626999136,
    ['ROLE:talent'] = 1169248649,
    ['RUNNER:common'] = 3996103689,
}

local callbacks = { 'valid', 'evaluate', 'print', 'widget', 'help' }
local restoreClassGroup = dofile('tests/fixtures/restore_class_group_repairs.lua')

local function path(name)
    return 'Functions.' .. owners[name] .. '.' .. name
end

local function identity(name)
    return 'builtin:' .. (owners[name] == 'collections' and 'Functions/collections.lua' or 'utils.lua') .. ':' .. name
end

local function fixture(case)
    case = case or cases[4]
    local f = F.new(unpack(case[1]))
    local a, e = f.addon, f.env

    local s = {
        exists = true,
        group = true,
        raid = false,
        level = 73,
        playerLevel = 70,
        role = 'HEALER',
        name = 'Glyph of Test',
        spellName = 'Glyph of Test',
        subClass = 7,
        calls = {},
        resists = { na = 0.5, naHits = 1 },
        runner = true,
    }

    if case[1][3] == 'DEATHKNIGHT' then
        s.subClass = 6
    end

    local function call(name)
        s.calls[name] = (s.calls[name] or 0) + 1

        if s.throw == name then
            error('native ' .. name .. ' failed')
        end
    end

    e.LOCALIZED_CLASS_NAMES_MALE = { SHAMAN = 'Shaman', DEATHKNIGHT = 'Death Knight', MAGE = 'Mage' }
    e.CLASS_SORT_ORDER = { 'SHAMAN', 'DEATHKNIGHT', 'MAGE' }
    e.RAID = 'Raid'
    e.PARTY = 'Party'

    e.GetBuildInfo = function()
        if case[1][1] == 19 then
            return '5.5.4', '1', '', 50504
        end

        return '3.4.0', '1', '', 30400
    end

    e.UnitClass = function()
        call('class')
        return case[1][3], case[1][3], s.subClass
    end

    e.UnitExists = function()
        call('exists')
        return s.exists
    end

    e.UnitIsUnit = function(x, y)
        call('same')
        return x == y
    end

    e.IsInGroup = function()
        call('group')
        return s.group
    end

    e.IsInRaid = function()
        call('raid')
        return s.raid
    end

    e.UnitLevel = function(unit)
        call('level')
        return unit == 'player' and s.playerLevel or s.level
    end

    e.UnitName = function()
        call('name')
        return 'Fixture'
    end

    e.UnitCreatureType = function()
        call('creature')
        return 'Humanoid'
    end

    e.UnitClassification = function()
        call('classification')
        return 'normal'
    end

    e.GetInspectSpecialization = function()
        call('inspect')
        return 123
    end

    e.GetSpecializationInfoByID = function()
        call('specialization')
        return 123, 'Fixture', nil, nil, nil, s.role
    end

    e.GetTalentGroupRole = function()
        call('talent')
        return s.role
    end

    e.GetItemInfoInstant = function(id)
        call('itemClass')
        return id, 'Glyph', 'Shaman', '', 1, 16, s.subClass
    end

    e.GetItemInfo = function()
        call('item')
        return s.name, s.name and '|Hitem:123|h[Glyph of Test]|h'
    end

    e.GetNumGlyphSockets = function()
        call('count')
        return 1
    end

    e.GetGlyphSocketInfo = function()
        call('socket')

        if case[1][1] == 19 then
            return true, 1, 2, 9001, 1
        end

        return true, 1, 9001, 1
    end

    e.GetSpellInfo = function()
        call('spell')
        return s.spellName
    end

    if case[3] then
        e.MI2_GetMobData = function()
            call('mob')
            return { resists = s.resists, lowHpAction = s.runner }
        end
    end

    for _, file in ipairs({
        'Platform/spells.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/character.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(file)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    local selected = {}

    for _, tag in ipairs(tags) do
        if a.conditionDefinitions[tag] then
            selected[#selected + 1] = tag
        end
    end

    return f, a, s, selected
end

local function node(tag)
    local v = {
        type = tag,
        unit = 'target',
        otherunit = 'target',
        operator = 'GREATERTHAN',
        value = 0,
        class = 'SHAMAN',
        school = 'na',
        item = 123,
        raid = false,
    }

    if tag == 'CLASS' then
        v.value = 'SHAMAN'
    elseif tag == 'ROLE' then
        v.value = 'HEALER'
    elseif tag == 'CREATURE' then
        v.value = 'HUMANOID'
    elseif tag == 'CLASSIFICATION' then
        v.value = 'normal'
    elseif tag == 'LEVEL' then
        v.value = 70
    end

    return v
end

local function legacySource(a, source)
    local old = a:CopySettingsData(source)

    for _, callback in ipairs(callbacks) do
        if old[callback] then
            for name in pairs(owners) do
                old[callback] = old[callback]:gsub(path(name):gsub('%.', '%%.') .. '%(', 'addon.' .. name .. '(')
            end
        end
    end

    for name in pairs(owners) do
        old.bindings[path(name)] = nil
    end

    return old
end

local levelRepairBodies = {
    evaluate = {
        original = "\n"
            .. [=[
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local level = value.value
        if value.relative then
            level = Functions.cache.getCached(addon.longtermCache, UnitLevel, "player") + value.value
        end
        return Functions.values.compare(value.operator, Functions.cache.getCached(cache, UnitLevel, value.unit), level)
    ]=],
        repaired = "\n"
            .. [=[
        local observed,reason=addon:GetConditionUnitLevel(value.unit,cache)
        if observed==nil then return nil,reason end
        if observed==false then return false end
        local level = value.value
        if value.relative then
            local playerLevel,why=addon:GetConditionUnitLevel("player",cache)
            if playerLevel==nil then return nil,why end
            if playerLevel==false then return nil,"player-level-unavailable" end
            level = playerLevel + value.value
            if level~=level or level==math.huge or level==-math.huge then return nil,"invalid-level-threshold" end
        end
        return Functions.values.compare(value.operator, observed, level)
    ]=],
    },
    print = {
        original = "\n"
            .. [=[
        local level = value.value
        if value.relative and value.value ~= nil then
            level = Functions.cache.getCached(addon.longtermCache, UnitLevel, "player") + value.value
        end
        return Functions.presentation.compareString(value.operator, Functions.presentation.playerize(value.unit, L["your level"], string.format(L["%s's level"],
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))), Functions.presentation.nullable(level, L["<level>"]))
    ]=],
        repaired = "\n"
            .. [=[
        local level = value.value
        if value.relative and value.value ~= nil then
            local playerLevel=addon:GetConditionUnitLevel("player")
            level = type(playerLevel)=="number" and playerLevel + value.value or nil
            if level and (level~=level or level==math.huge or level==-math.huge) then level=nil end
        end
        return Functions.presentation.compareString(value.operator, Functions.presentation.playerize(value.unit, L["your level"], string.format(L["%s's level"],
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))), Functions.presentation.nullable(level, L["<level>"]))
    ]=],
    },
}

local identityRepairBodies = {
    original = "\n"
        .. [=[
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitIsUnit, value.unit, value.otherunit)
    ]=],
    repaired = "\n"
        .. [=[
        return Functions.cache.getCached(cache, addon.Platform.GetUnitIdentityObservation, addon.Platform, value.unit, value.otherunit)
    ]=],
}

local metadataRepairBodies = {
    CLASS = {
        original = "\n"
            .. [=[
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local _, englishClass = Functions.cache.getCached(cache, UnitClass, value.unit)
        return englishClass == value.value
    ]=],
        repaired = "\n"
            .. [=[
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "class")
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed == value.value
    ]=],
    },
    CREATURE = {
        original = "\n"
            .. [=[
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitCreatureType, value.unit) == addon.creatures[value.value])
    ]=],
        repaired = "\n"
            .. [=[
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "creature")
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed == addon.creatures[value.value]
    ]=],
    },
    CLASSIFICATION = {
        original = "\n"
            .. [=[
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitClassification, value.unit) == value.value)
    ]=],
        repaired = "\n"
            .. [=[
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "classification")
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed == value.value
    ]=],
    },
}

local function copies(a, selected)
    local canonical, legacy = {}, {}

    for _, tag in ipairs(selected) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        canonical[tag] = assert(a:CompileCustomCondition('COPY_' .. tag, source))
        legacy[tag] = assert(a:CompileCustomCondition('OLD_' .. tag, legacySource(a, source)))
        a:RegisterCondition('COPY_' .. tag, canonical[tag])
        a:RegisterCondition('OLD_' .. tag, legacy[tag])
    end

    return canonical, legacy
end

local function counts(source)
    if source.evaluate and source.evaluate:find('addon:GetClassGroupCount', 1, true) then
        source = {
            evaluate = restoreClassGroup(source.evaluate, true),
            valid = source.valid,
            print = source.print,
            widget = source.widget,
            help = source.help,
        }
    end

    local result = {}

    for _, callback in ipairs(callbacks) do
        if source[callback] then
            for name in pairs(owners) do
                local _, n = source[callback]:gsub(path(name):gsub('%.', '%%.') .. '%(', '')
                result[name] = (result[name] or 0) + n
                assert(not source[callback]:find('addon.' .. name .. '(', 1, true), 'legacy direct call remains')
            end
        end
    end

    return result
end

local function unknown(a, v)
    assert(a:evaluateConditionResult(v).status == 'unavailable')
    assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable')

    local body = {
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = v,
                onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                onFalse = { { id = 'no', type = 'spell', action = 2 } },
            },
        },
    }

    assert(
        a:EvaluateRotationSequence(body, function(x) return a:evaluateConditionResult(x) end, function()
            error('unknown guard chose action')
        end).status == 'unavailable'
    )
end

test('character callbacks call only the namespaced owning leaves, with both ROLE variants', function()
    local seen = {}

    for _, case in ipairs(cases) do
        local f, a, _, selected = fixture(case)

        local manifest = assert(
            a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/character.lua'],
            'character manifest missing'
        )

        local leaves = 0

        for alias, id in pairs(manifest) do
            leaves = leaves + 1
            local name = alias:match('([%w_]+)$')

            assert(
                alias == path(name)
                    and id == identity(name)
                    and a:ResolveFunctionBinding(id) == a.Functions[owners[name]][name]
            )
        end

        assert(leaves == 8 and not f.env.Functions)

        for _, tag in ipairs(selected) do
            local source = assert(a:GetBuiltinConditionSource(tag))
            assert(not source.bindings.Functions, tag .. ': namespace captured as an opaque value')

            for _, callback in ipairs(callbacks) do
                if source[callback] then
                    for name in pairs(owners) do
                        assert(
                            not source[callback]:find('addon.' .. name .. '(', 1, true),
                            tag .. ' ' .. callback .. ' direct legacy ' .. name .. ' remains'
                        )

                        if source[callback]:find(path(name), 1, true) then
                            assert(
                                source.bindings[path(name)] == identity(name),
                                tag .. ' ' .. callback .. ' lacks the binding for ' .. path(name)
                            )
                        end
                    end
                end
            end

            seen[tag .. ':' .. (a.conditionDefinitions[tag].builtinSourceVariant or 'common')] = true
        end
    end

    assert(seen['ROLE:inspect'] and seen['ROLE:talent'])
end)

test(
    'every inventory branch compiles canonical and legacy-shaped callbacks with matching fields and variants',
    function()
        for _, case in ipairs(cases) do
            local _, a, _, selected = fixture(case)
            local canonical, legacy = copies(a, selected)

            for _, tag in ipairs(selected) do
                local source = a:GetBuiltinConditionSource(tag)

                assert(
                    a:SettingsDataEqual(source.fields, canonical[tag].fields) and a:SettingsDataEqual(
                        source.fields,
                        legacy[tag].fields
                    )
                )

                if tag == 'ROLE' then
                    assert((source.fields.unit ~= nil) == (case[1][1] == 1))

                    assert(
                        a.conditionDefinitions[tag].builtinSourceVariant == (case[1][1] == 1 and 'inspect' or 'talent')
                    )
                end
            end
        end
    end
)

test('validators and summaries agree for original canonical and legacy-shaped copies on all branches', function()
    for _, case in ipairs(cases) do
        local _, a, _, selected = fixture(case)
        local canonical, legacy = copies(a, selected)

        for _, tag in ipairs(selected) do
            for _, operator in ipairs({
                'EQUALS',
                'NOTEQUALS',
                'LESSTHAN',
                'LESSTHANOREQUALS',
                'GREATERTHAN',
                'GREATERTHANOREQUALS',
                'DIVISIBLE',
                'INVALID',
            }) do
                for _, unit in ipairs({ 'player', 'target', 'pet', 'missing' }) do
                    local v = node(tag)
                    v.operator = operator
                    v.unit = unit

                    assert(
                        a.conditionDefinitions[tag].valid(0, v) == canonical[tag].valid(0, v) and canonical[tag].valid(
                            0,
                            v
                        )
                            == legacy[tag].valid(0, v),
                        tag .. ' validator changed'
                    )

                    for _, negate in ipairs({ false, true }) do
                        local text = a.conditionDefinitions[tag].print(0, v, negate)

                        assert(
                            text == canonical[tag].print(0, v, negate) and text == legacy[tag].print(0, v, negate),
                            tag .. ' wording changed'
                        )
                    end
                end
            end

            local v = node(tag)
            v.value = nil
            v.item = nil
            v.class = nil

            assert(
                a.conditionDefinitions[tag].valid(0, v) == canonical[tag].valid(0, v) and canonical[tag].valid(0, v)
                    == legacy[tag].valid(0, v)
            )
        end
    end
end)

test('all evaluations retain native argument tuples shared cache identity and current branch behavior', function()
    for _, case in ipairs(cases) do
        local _, a, s, selected = fixture(case)
        local canonical, legacy = copies(a, selected)
        local cache = {}

        for _, tag in ipairs(selected) do
            local v = node(tag)
            local actual, why = a.conditionDefinitions[tag].evaluate(v, cache)
            local before = a:CopySettingsData(s.calls)
            local copied, reason = canonical[tag].evaluate(v, cache)
            local old, oldReason = legacy[tag].evaluate(v, cache)
            assert(actual == copied and actual == old and why == reason and why == oldReason, tag .. ' result changed')

            if tag == 'RUNNER' or tag == 'RESIST' or tag == 'IMMUNE' then
                for _, name in ipairs({ 'name', 'level', 'mob' }) do
                    assert(s.calls[name] == before[name] + 2, tag .. ' raw native call policy changed')
                    before[name] = s.calls[name]
                end
            end

            assert(a:SettingsDataEqual(before, s.calls), tag .. ' cached observations changed')
        end

        local calls = 0

        local function native(...)
            calls = calls + 1
            assert(select('#', ...) == 3)
            return nil, 'pending', nil, 'tail'
        end

        local function tuple(...)
            assert(select('#', ...) == 4)
            local first, why, third, tail = ...
            assert(first == nil and why == 'pending' and third == nil and tail == 'tail')
        end

        tuple(a.Functions.cache.getCached(cache, native, 'target', nil, 'glyph'))
        tuple(a.getCached(cache, native, 'target', nil, 'glyph'))
        assert(calls == 1)
    end
end)

test('repaired GROUP and GLYPH unknowns keep NOT and branches unavailable in both copy forms', function()
    local f, a, s, selected = fixture(cases[6])
    copies(a, selected)

    for _, prefix in ipairs({ '', 'COPY_', 'OLD_' }) do
        s.raid = false

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = { type = prefix .. 'GROUP', raid = true } }).status
                == 'match'
        )

        s.raid = nil
        unknown(a, { type = prefix .. 'GROUP', raid = true })
    end

    for _, mode in ipairs({ 'item-name', 'spell-name', 'restricted-item', 'socket-api' }) do
        s.name = 'Glyph of Test'
        s.spellName = 'Glyph of Test'
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'item-name' then
            s.name = nil
        elseif mode == 'spell-name' then
            s.spellName = nil
        elseif mode == 'restricted-item' then
            s.name = opaque
        else
            f.env.GetGlyphSocketInfo = nil
        end

        for _, prefix in ipairs({ '', 'COPY_', 'OLD_' }) do
            unknown(a, { type = prefix .. 'GLYPH', item = 123 })
        end
    end
end)

test('widget copies retain unit-filter collections dropdown key lists and native field configuration', function()
    for _, case in ipairs(cases) do
        local f, a, _, selected = fixture(case)
        local canonical, legacy = copies(a, selected)
        local originalUnits = a:CopySettingsData(a.units)

        local function render(definition, value)
            local seen = {}

            a.Widget_UnitWidget = function(_, _, units, _, field)
                seen[#seen + 1] = { kind = 'unit', units = a:CopySettingsData(units), field = field }
                local w = f.widget('Unit')

                w.SetList = function(self, list, order)
                    self.list = list
                    self.order = order
                end

                return w
            end

            a.Widget_OperatorWidget = function(_, _, name)
                seen[#seen + 1] = { kind = 'operator', name = name }
                return f.widget('Operator')
            end

            a.Widget_OperatorPercentWidget = function(_, _, name)
                seen[#seen + 1] = { kind = 'percent', name = name }
                return f.widget('Percent')
            end

            a.Widget_SingleItemWidget = function(_, _, scope, _, accept)
                seen[#seen + 1] = { kind = 'item', scope = scope, accept = accept(123) }
                return f.widget('Item')
            end

            local parent = f.widget('Group')
            local top = f.widget('Frame')
            top:SetUserData('root', value)
            top:SetUserData('funcs', { print = function() return 'summary' end })
            parent:SetUserData('top', top)
            definition.widget(parent, 0, value)

            for _, child in ipairs(parent.children) do
                if child.configure then
                    child.configure()
                end

                seen[#seen + 1] = {
                    kind = child.kind or child.type,
                    value = child.value,
                    list = child.list and a:CopySettingsData(child.list),
                    order = child.order and a:CopySettingsData(child.order),
                }
            end

            for _, child in ipairs(parent.children) do
                if child.rmWidget then
                    a:ReleaseConditionWidget(child)
                end
            end

            return seen
        end

        for _, tag in ipairs(selected) do
            local v = node(tag)
            local base = render(a.conditionDefinitions[tag], v)

            assert(
                a:SettingsDataEqual(base, render(canonical[tag], v)) and a:SettingsDataEqual(base, render(
                    legacy[tag],
                    v
                )),
                tag .. ' widget changed'
            )

            if tag == 'ISSAME' then
                assert(base[1].units.player == nil and base[1].units.pet == nil and base[2].units.player ~= nil)
            end
        end

        assert(a:SettingsDataEqual(originalUnits, a.units), 'filtered collection mutated shared units')
    end
end)

-- The MobInfo2 adapter contains a provider error (Platform/mobinfo2.lua), so the three forms agree on 'unavailable'.
test('a failing MobInfo provider is unavailable in the built-in and in both copy forms alike', function()
    local _, a, s, selected = fixture(cases[8])
    local canonical, legacy = copies(a, selected)
    s.throw = 'mob'

    for _, tag in ipairs({ 'RUNNER', 'RESIST', 'IMMUNE' }) do
        for _, definition in ipairs({ a.conditionDefinitions[tag], canonical[tag], legacy[tag] }) do
            local ok, value, reason = pcall(definition.evaluate, node(tag), {})

            assert(
                ok and value == nil and reason == 'mobinfo2-provider-error',
                tag .. ': ' .. tostring(value) .. ' ' .. tostring(reason)
            )
        end
    end
end)

test('private captured values source hashes and original addon aliases remain exact', function()
    for _, case in ipairs(cases) do
        local _, a = fixture(case)

        for name, hash in pairs({
            character_class = 'f9f4e4b5',
            color = '3f9fe631',
            helpers = '2e9a81e7',
            unit_class_num = '33645816',
        }) do
            local id = 'builtin:Conditions/character.lua:' .. name

            assert(
                a:FunctionSourceHash(a.builtinFunctions[id].source) == hash and a:ResolveFunctionBinding(id)
                    == a.builtinSourceModules['Conditions/character.lua'](name)
            )
        end

        for name, owner in pairs(owners) do
            assert(a[name] == a.Functions[owner][name])
        end
    end
end)

finish()
