local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project, expansion, version, interface)
    local f = F.new(project or 11, expansion or 2)
    local a, e = f.addon, f.env

    local s = {
        name = 'Glyph of Test',
        spellName = 'Glyph of Test',
        socket = 9001,
        count = 1,
        enabled = true,
        group = true,
        raid = false,
        class = 7,
        itemClass = 16,
        subClass = 7,
        calls = {},
    }

    e.GetBuildInfo = function() return version or '3.4.0', '1', '', interface or 30400 end
    e.UnitClass = function() return 'Shaman', 'SHAMAN', s.class end

    e.IsInGroup = function()
        s.calls.group = (s.calls.group or 0) + 1
        return s.group
    end

    e.IsInRaid = function()
        s.calls.raid = (s.calls.raid or 0) + 1
        return s.raid
    end

    local function instant(id)
        return id, 'Glyph', 'Shaman', '', 1, s.itemClass, s.subClass
    end

    e.GetItemInfoInstant = instant

    local function info()
        s.calls.item = (s.calls.item or 0) + 1
        return s.name, s.name and '|Hitem:123|h[Glyph of Test]|h'
    end

    e.GetItemInfo = info
    -- Every current client also has these in C_Item (the globals are gone on Retail/Forever).
    e.C_Item = { GetItemInfoInstant = instant, GetItemInfo = info }

    e.GetNumGlyphSockets = function()
        s.calls.count = (s.calls.count or 0) + 1
        return s.count
    end

    e.GetGlyphSocketInfo = function(index)
        if s.unknownSlot == index then
            return
        end
        if s.otherSlot == index then
            return true, 1, 9002, 9002
        end
        if project == 14 or project == 19 then
            return s.enabled, 1, 2, s.socket, 1
        end

        return s.enabled, 1, s.socket, 1
    end

    e.GetSpellInfo = function(id)
        s.calls.spell = (s.calls.spell or 0) + 1

        if id == 9002 then
            return s.otherName
        end
        if id == s.socket then
            return s.spellName
        end
    end

    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/groups.lua', 'Platform/glyphs.lua', 'Diagnostics/errors.lua',
        'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/character.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, s
end

local function unknown(a, v)
    assert(a:evaluateConditionResult(v).status == 'unavailable', v.type .. ' lost unknown')

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable',
        v.type .. ' unknown authorized NOT'
    )

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
        a:EvaluateRotationSequence(body, function(node) return a:evaluateConditionResult(node) end, function()
            error('unknown guard authorized action')
        end).status == 'unavailable'
    )
end

local function clones(a)
    for _, tag in ipairs({ 'GROUP', 'GLYPH' }) do
        local copy = assert(a:CompileCustomCondition('COPY_' .. tag, assert(a:GetBuiltinConditionSource(tag))))
        a:RegisterCondition('COPY_' .. tag, copy)
    end
end

test('raid false is preserved without party fallback while readable false remains negatable', function()
    local _, a, s = fixture()
    assert(a:evaluateConditionResult({ type = 'GROUP', raid = true }).status == 'no-match')
    assert(not s.calls.group)
    assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'GROUP', raid = true } }).status == 'match')
    assert(a:evaluateConditionResult({ type = 'GROUP' }).status == 'match')
end)

test('group missing failed restricted nil and unsupported observations stay unknown through guards', function()
    for _, mode in ipairs({ 'missing', 'throw', 'nil', 'secret', 'invalid', 'unsupported' }) do
        local f, a, s = fixture()
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'missing' then
            f.env.IsInRaid = nil
        elseif mode == 'throw' then
            f.env.IsInRaid = function()
                error('failed')
            end
        elseif mode == 'nil' then
            s.raid = nil
        elseif mode == 'secret' then
            s.raid = opaque
        elseif mode == 'invalid' then
            s.raid = 0
        else
            f.env.WOW_PROJECT_ID = 999
        end

        unknown(a, { type = 'GROUP', raid = true })
        assert(not s.calls.group)
    end
end)

test('glyph uses actual Wrath Cata and Mists spell positions and ignores locked stale spells', function()
    for _, case in ipairs({ { 11, 2, '3.4.0', 30400 }, { 14, 3, '4.4.2', 40402 }, { 19, 4, '5.5.4', 50504 } }) do
        local _, a, s = fixture(unpack(case))
        assert(a:evaluateConditionResult({ type = 'GLYPH', item = 123 }).status == 'match')
        s.enabled = false
        assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'GLYPH', item = 123 } }).status == 'match')
    end
end)

test('glyph missing names APIs classification and restricted observations cannot authorize absence', function()
    for _, mode in ipairs({
        'item-name', 'spell-name', 'item-api', 'socket-api', 'count-api', 'secret-item', 'secret-spell', 'wrong-class',
        'unsupported'
    }) do
        local f, a, s = fixture()
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'item-name' then
            s.name = nil
        elseif mode == 'spell-name' then
            s.spellName = nil
        elseif mode == 'item-api' then
            f.env.GetItemInfo = nil
            f.env.C_Item.GetItemInfo = nil
        elseif mode == 'socket-api' then
            f.env.GetGlyphSocketInfo = nil
        elseif mode == 'count-api' then
            f.env.GetNumGlyphSockets = nil
        elseif mode == 'secret-item' then
            s.name = opaque
        elseif mode == 'secret-spell' then
            s.spellName = opaque
        elseif mode == 'wrong-class' then
            s.subClass = 8
        else
            f.env.WOW_PROJECT_ID = 1
        end

        unknown(a, { type = 'GLYPH', item = 123 })
    end
end)

test('glyph positive evidence survives unrelated unknown slots but negative requires complete metadata', function()
    local _, a, s = fixture()
    s.count = 2
    s.unknownSlot = 2
    assert(a:evaluateConditionResult({ type = 'GLYPH', item = 123 }).status == 'match')
    s.unknownSlot = 1
    s.otherSlot = 2
    s.otherName = 'Glyph of Test'

    assert(
        a:evaluateConditionResult({ type = 'GLYPH', item = 123 }).status == 'match',
        'later definite evidence was hidden by an earlier unknown slot'
    )

    s.unknownSlot = 2
    s.otherSlot = nil
    s.spellName = 'Other'
    unknown(a, { type = 'GLYPH', item = 123 })
    s.unknownSlot = nil
    s.otherSlot = 2
    s.otherName = nil
    unknown(a, { type = 'GLYPH', item = 123 })
    s.otherName = 'Another'
    assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'GLYPH', item = 123 } }).status == 'match')
    s.count = 0
    assert(a:evaluateConditionResult({ type = 'GLYPH', item = 123 }).status == 'no-match')
end)

test('per-evaluation snapshots recover deferred metadata and never borrow stale loader or longterm results', function()
    local _, a, s = fixture()
    a.itemCache = { [123] = { name = 'Glyph of Test' } }
    s.name = nil
    unknown(a, { type = 'GLYPH', item = 123 })
    s.name = 'Glyph of Test'
    s.spellName = nil
    unknown(a, { type = 'GLYPH', item = 123 })
    s.spellName = 'Glyph of Test'
    assert(a:evaluateConditionResult({ type = 'GLYPH', item = 123 }).status == 'match')
    s.calls = {}
    local v = { type = 'GLYPH', item = 123 }
    assert(a:evaluateConditionResult({ type = 'AND', value = { v, v } }).status == 'match')
    assert(s.calls.count == 1 and s.calls.item == 1 and s.calls.spell == 1)
    s.spellName = 'Other'
    assert(a:evaluateConditionResult(v).status == 'no-match')
end)

test('GLYPH validator and actual widget predicate use guarded classification with original captured class', function()
    local _, a, s = fixture()
    local definition = a.conditionDefinitions.GLYPH
    assert(definition.valid(0, { item = 123 }))
    s.class = 8
    assert(definition.valid(0, { item = 123 }), 'captured class identity changed')
    local predicate, kind

    local top = {
        GetUserData = function(_, key)
            if key == 'funcs' then
                return { print = function() return '' end }
            end
        end,
        SetStatusText = function() end,
    }

    local parent = { GetUserData = function() return top end, AddChild = function() end }

    a.Widget_SingleItemWidget = function(_, _, scope, _, accept)
        kind = scope
        predicate = accept
        return {}
    end

    definition.widget(parent, 0, { item = 123 })
    assert(kind == 'Glyph_EditBox' and predicate(123))
    s.subClass = 8
    assert(not predicate(123))
    s.subClass = 7
    s.itemClass = 1
    assert(not predicate(123))
    assert(not predicate({ 123 }) and not predicate('item:123'))
end)

test(
    'registered clones preserve repaired APIs and old private identities while saved raw callbacks remain executable',
    function()
        local _, a, s = fixture()
        clones(a)

        for _, tag in ipairs({ 'GROUP', 'GLYPH' }) do
            local node = { type = 'COPY_' .. tag, raid = true, item = 123 }
            local original = { type = tag, raid = true, item = 123 }
            assert(a:evaluateConditionResult(node).status == a:evaluateConditionResult(original).status)
        end

        s.name = nil
        unknown(a, { type = 'COPY_GLYPH', item = 123 })
        s.raid = nil
        unknown(a, { type = 'COPY_GROUP', raid = true })

        for name, hash in pairs({
            character_class = 'f9f4e4b5',
            color = '3f9fe631',
            helpers = '2e9a81e7',
            unit_class_num = '33645816',
        }) do
            local id = 'builtin:Conditions/character.lua:' .. name
            assert(a:FunctionSourceHash(a.builtinFunctions[id].source) == hash)
            assert(a:ResolveFunctionBinding(id) == a.builtinSourceModules['Conditions/character.lua'](name))
        end

        local oldGlyph = a:GetBuiltinConditionSource('GLYPH')
        oldGlyph.evaluate = 'local name=addon.getCached(addon.longtermCache,GetItemInfo,value.item);for i=1,GetNumGlyphSockets() do local spell=select(3,addon.getCached(addon.combatCache,GetGlyphSocketInfo,i));if addon.getCached(addon.longtermCache,GetSpellInfo,spell)==name then return true end end;return false'
        local savedGlyph = assert(a:CompileCustomCondition('SAVED_GLYPH', oldGlyph))
        s.name = 'Glyph of Test'
        assert(savedGlyph.evaluate({ item = 123 }, {}) == true)
        local old = a:GetBuiltinConditionSource('GROUP')
        old.evaluate = 'return value.raid and addon.getCached(cache,IsInRaid) or addon.getCached(cache,IsInGroup)'
        local copy = assert(a:CompileCustomCondition('SAVED_GROUP', old))
        s.raid = false
        assert(copy.evaluate({ raid = true }, {}) == true)
    end
)

-- Forever reports expansion 0 and registers no GLYPH (its old {18,12} case modelled another expansion).
test('all registration branches preserve GLYPH editing availability independently of runtime layout', function()
    for _, case in ipairs({
        { 1, 12, true },
        { 2, 0, false },
        { 5, 1, false },
        { 11, 2, true },
        { 14, 3, true },
        { 19, 4, true },
        { 18, 0, false },
        { 999, 4, true },
    }) do
        local _, a = fixture(case[1], case[2])
        assert((a.conditionDefinitions.GLYPH ~= nil) == case[3])
        assert(a.conditionDefinitions.GROUP)

        if case[3] then
            assert(a.conditionDefinitions.GLYPH.valid(0, { item = 123 }))

            if case[1] ~= 11 then
                unknown(a, { type = 'GLYPH', item = 123 })
            end
        end
    end
end)

test('public adapter source clones resolve exact helpers and obey live readability and layout contracts', function()
    local f, a, s = fixture()
    local copied = {}

    for _, entry in ipairs({
        { 'items', 'GetItemInfoInstant' },
        { 'groups', 'GetGroupMembership' },
        { 'glyphs', 'GetGlyphItemInfo' },
        { 'glyphs', 'GetGlyphSocketSnapshot' },
    }) do
        local id = 'builtin:Platform/' .. entry[1] .. '.lua:Platform_' .. entry[2]
        local record = assert(a.builtinFunctions[id])
        assert(record.source.description ~= '' and record.source.args[1].name == 'self')
        assert(a:InstallCustomFunction('COPY_' .. entry[2], record.source))
        copied[entry[2]] = assert(a:ResolveFunctionBinding('COPY_' .. entry[2]))
        assert(a:ResolveFunctionBinding(id) == a.Platform[entry[2]])
    end

    assert(
        copied.GetItemInfoInstant(a.Platform, 123).classID == 16
            and copied.GetGlyphItemInfo(a.Platform, 123, 7).subClassID == 7
    )

    assert(copied.GetGroupMembership(a.Platform, true) == false)
    assert(copied.GetGlyphSocketSnapshot(a.Platform).slots[1].spellID == 9001)
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.subClass = opaque
    local record, why = copied.GetGlyphItemInfo(a.Platform, 123, 7)
    assert(record == nil and why == 'restricted-value')
    s.socket = opaque
    record = copied.GetGlyphSocketSnapshot(a.Platform)
    assert(not record.complete and record.slots[1].reason == 'restricted-value')
    f.env.WOW_PROJECT_ID = 999
    s.calls = {}
    record, why = copied.GetGroupMembership(a.Platform, true)
    assert(record == nil and why == 'unsupported-client' and next(s.calls) == nil)
    record, why = copied.GetGlyphSocketSnapshot(a.Platform)
    assert(record == nil and why == 'unsupported-glyph-layout' and next(s.calls) == nil)
end)

finish()
