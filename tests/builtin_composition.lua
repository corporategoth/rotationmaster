-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In composition: authoring-time blocks expand once at registration into an
-- independent tree. Catalog, clone, export and corpus validation never see a block.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/rotation_data.lua')
local ledger = dofile('tests/fixtures/builtin_composition_ledger.lua')

local function fixture()
    local data = make()

    local a = {
        RotationData = data,
        Platform = {},
        db = { profile = { rotations = {}, itemsets = {} }, global = { effects = {} } },
    }

    local context = {
        family = 'tbc',
        class = 'ROGUE',
        level = 35,
        spec = 0,
        actionContext = 'player',
        combatDataPolicy = 'probe',
    }

    local n = 0

    a.uuid = function()
        n = n + 1
        return 'generated-' .. n
    end

    local env = setmetatable({
        LibStub = function()
            return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
        end,
    }, { __index = _G })

    local function load(path)
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk('rotationmaster', a)
    end

    for _, path in ipairs({
        'Core/rotation_active.lua',
        'Core/rotation_references.lua',
        'Data/catalog.lua',
        'Data/diff.lua',
        'Core/rotation_library.lua',
        'Core/rotation_tags.lua',
        'Core/imports.lua',
    }) do
        load(path)
    end

    a.GetRotationContext = function() return context end
    return a, load, context
end

local function canonical(v)
    local t = type(v)

    if t == 'string' then
        return string.format('%q', v)
    elseif t == 'number' then
        return string.format('%.17g', v)
    elseif t ~= 'table' then
        return tostring(v)
    end

    local keys = {}

    for k in pairs(v) do
        keys[#keys + 1] = k
    end

    table.sort(keys, function(x, y)
        if type(x) == type(y) then
            return x < y
        end

        return type(x) == 'number'
    end)

    local out = {}

    for _, k in ipairs(keys) do
        out[#out + 1] = canonical(k) .. '=' .. canonical(v[k])
    end

    return '{' .. table.concat(out, ',') .. '}'
end

-- Change detection only (ledger/pre-conversion pins), not a security hash.
local function digest(v)
    local text, x, y = canonical(v), 5381, 0

    for i = 1, #text do
        local c = text:byte(i)
        x = (x * 33 + c) % 4294967291
        y = (y * 131 + c + i) % 4294967279
    end

    return string.format('%08x%08x', x, y)
end

local function same(x, y)
    return canonical(x) == canonical(y)
end

local function spell(id, action)
    return {
        id = id,
        type = 'spell',
        action = action or 1752,
        conditions = { type = 'SPELL_KNOWN', spell = action or 1752 },
    }
end

local function ref(id, name, prefix)
    return { id = id, type = 'block', block = name, prefix = prefix }
end

local function block(id, steps, extra)
    local b = { id = id, revision = 1, families = { 'tbc' }, steps = steps }

    for k, v in pairs(extra or {}) do
        b[k] = v
    end

    return b
end

local function pack(id, rotation, pins, extra)
    local p = {
        format = 'RotationMaster',
        schemaVersion = 1,
        id = id,
        revision = 1,
        blocks = pins,
        nameKey = id,
        descriptionKey = 'Composition fixture',
        applicability = { families = { 'tbc' }, actionContext = 'player', class = 'ROGUE' },
        sources = { { url = 'https://example.invalid/fixture', reviewedAt = '2026-10-23' } },
        body = { switch = {}, rotation = rotation, cooldowns = {} },
    }

    for k, v in pairs(extra or {}) do
        p[k] = v
    end

    return p
end

local function ids(a, body)
    local tree = assert(a.RotationData.IndexRotationSteps(body))
    local out = {}

    for _, row in ipairs(tree.rows) do
        out[#out + 1] = row.step.id
    end

    return table.concat(out, ' ')
end

local function composedArtifacts(value)
    if type(value) ~= 'table' then
        return false
    end
    if value.type == 'block' or value.blocks ~= nil then
        return true
    end

    for _, child in pairs(value) do
        if composedArtifacts(child) then
            return true
        end
    end

    return false
end

local function rejects(code, ok, why)
    assert(not ok, 'accepted; expected ' .. code)
    assert(type(why) == 'string' and why:sub(1, #code + 4) == code .. ' at ', tostring(why))
    return why
end

local function shipped()
    local a, load = fixture()
    a.loadAllDefaults = true

    for _, path in ipairs(dofile('tools/builtin_modules.lua').paths()) do
        load(path)
    end

    assert(a:InitializeRotationLibrary())
    return a
end

local function newest(rows)
    local top = 0

    for revision in pairs(rows) do
        top = math.max(top, revision)
    end

    return top
end

test('shipped composed packs expand once into plain trees pinned as the ledger records', function()
    local a = shipped()
    local seen = 0

    for id, rows in pairs(ledger.packs) do
        local view = assert(a:GetDefaultRotation(id), id .. ' is not registered')
        assert(view.validation.valid and view.readOnly, id)
        assert(not composedArtifacts(view.envelope), id .. ' leaked composition data')

        assert(
            same(a:GetDefaultRotationComposition(id), { blocks = rows[newest(rows)] }),
            id .. ' pins differ from the ledger'
        )

        seen = seen + 1
    end

    assert(seen > 0, 'no composed shipped packs')

    -- Variants of one role expand a shared block to identical steps under the same prefix.
    local function find(list, id)
        for _, row in ipairs(assert(a.RotationData.IndexRotationSteps({ rotation = list, cooldowns = {} })).rows) do
            if row.step.id == id then
                return row.step
            end
        end
    end

    for _, pair in ipairs({
        { 'rm.tbc.rogue.dps.simulator', 'rm.tbc.rogue.dps.wowhead', 'rogue-sinister' },
        { 'rm.tbc.warrior.dps.simulator', 'rm.tbc.warrior.dps.icyveins', 'warrior-dps-charge' },
        { 'rm.tbc.hunter.ranged.simulator', 'rm.tbc.hunter.ranged.wowhead', 'hunter-auto-shot' },
    }) do
        local left = find(a:GetDefaultRotation(pair[1]).envelope.body.rotation, pair[3])
        local right = find(a:GetDefaultRotation(pair[2]).envelope.body.rotation, pair[3])
        assert(left and right and same(left, right), pair[3] .. ' differs between variants')
    end
end)

test('composed packs pass strict corpus validation with real condition schemas', function()
    local corpus = dofile('tests/fixtures/default_corpus.lua')
    local seen = 0

    for _, class in ipairs({
        'WARRIOR', 'ROGUE', 'HUNTER', 'PALADIN', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID', 'DEATHKNIGHT',
        'DEMONHUNTER', 'EVOKER', 'MONK'
    }) do
        -- Progression packs validate on a Mists client (Death Knight RUNE needs expansion 2+);
        -- every other composed pack on the TBC client.
        for _, client in ipairs({ { 5, 1, false }, { 19, 4, true } }) do
            local f, packs = corpus.load(client[1], client[2], class)

            for _, p in ipairs(packs) do
                if
                    ledger.packs[p.id]
                    and p.applicability.class == class
                    and corpus.contains(p.applicability.families, 'progression') == client[3]
                then
                    assert(not composedArtifacts(p))
                    corpus.check(f, p, true)
                    seen = seen + 1
                    assert(same(p, f.addon:GetDefaultRotation(p.id).envelope), 'corpus and catalog disagree')
                end
            end
        end
    end

    local expected = 0

    for _ in pairs(ledger.packs) do
        expected = expected + 1
    end

    assert(seen == expected, seen .. ' of ' .. expected .. ' composed packs validated')
end)

test('nested references in lists and branch arms derive stable unique IDs', function()
    local function build()
        local a = fixture()
        assert(a:RegisterDefaultBlock(block('fx.inner', { spell('hit') })))

        assert(a:RegisterDefaultBlock(block('fx.outer', {
            ref('first', 'fx.inner'),
            {
                id = 'gate',
                type = 'branch',
                conditions = {},
                onTrue = { ref('second', 'fx.inner', 'alt-') },
                onFalse = { spell('fill', 1757) },
            },
        })))

        local p = pack(
            'fx.nested',
            {
                ref('a', 'fx.outer'),
                { id = 'b', type = 'branch', conditions = {}, onTrue = { ref('c', 'fx.outer', 'c-') }, onFalse = {} },
            },
            { ['fx.inner'] = 1, ['fx.outer'] = 1 }
        )

        p.body.cooldowns = { ref('cd', 'fx.inner') }
        assert(a:RegisterDefaultRotation(p))
        assert(a:InitializeRotationLibrary())
        return a, a:GetDefaultRotation('fx.nested').envelope
    end

    local a, first = build()
    local _, second = build()
    local expected = 'a.first.hit a.gate a.alt-hit a.fill b c-first.hit c-gate c-alt-hit c-fill cd.hit'
    assert(ids(a, first.body) == expected, ids(a, first.body))
    assert(ids(a, second.body) == expected, 'IDs are not stable across reloads')
    assert(same(first, second) and not composedArtifacts(first) and first.body.rotation[3].onTrue[1].action == 1752)
    assert(same(a:GetDefaultRotationComposition('fx.nested'), { blocks = { ['fx.inner'] = 1, ['fx.outer'] = 1 } }))
end)

test('double inclusion yields independent copies and the registry stays isolated', function()
    local a = fixture()
    local authored = block('fx.inner', { spell('hit') })
    assert(a:RegisterDefaultBlock(authored))
    local p = pack('fx.twice', { ref('one', 'fx.inner', 'x-'), ref('two', 'fx.inner', 'y-') }, { ['fx.inner'] = 1 })
    local expanded = assert(a:ExpandDefaultRotation(p))
    local r = expanded.body.rotation
    assert(r[1].id == 'x-hit' and r[2].id == 'y-hit' and r[1] ~= r[2] and r[1].conditions ~= r[2].conditions)
    r[1].conditions.spell = 1
    assert(r[2].conditions.spell == 1752)
    authored.steps[1].action = 4242
    authored.revision = 9
    local again = assert(a:ExpandDefaultRotation(p))
    assert(again.body.rotation[1].action == 1752 and again.body.rotation[1].conditions.spell == 1752)

    assert(
        p.body.rotation[1].type == 'block' and p.blocks['fx.inner'] == 1,
        'expansion mutated the authored definition'
    )
end)

test('edition and specialization overrides select one whole variant or reject', function()
    local function setup(extra)
        local a = fixture()

        assert(a:RegisterDefaultBlock(block('fx.shared', { spell('base') }, {
            families = { 'era', 'tbc' },
            overrides = {
                { families = { 'tbc' }, steps = { spell('tbc', 1757) } },
                { specs = { 2 }, families = { 'era' }, steps = { spell('era-two', 1758) } },
            },
        })))

        return a
    end

    local function scope(families, specs)
        return { applicability = { families = families, specs = specs, actionContext = 'player', class = 'ROGUE' } }
    end

    local function expand(a, families, specs)
        return a:ExpandDefaultRotation(pack('fx.over', { ref('u', 'fx.shared', 'u-') }, { ['fx.shared'] = 1 }, scope(
            families,
            specs
        )))
    end

    local a = setup()
    assert(expand(a, { 'tbc' }).body.rotation[1].id == 'u-tbc')
    assert(expand(a, { 'era' }, { 1 }).body.rotation[1].id == 'u-base')
    assert(expand(a, { 'era' }, { 2 }).body.rotation[1].id == 'u-era-two')
    rejects('ambiguous-block-override', expand(a, { 'era', 'tbc' }))
    rejects('ambiguous-block-override', expand(a, { 'era' }))
    rejects('ambiguous-block-override', expand(a, { 'era' }, { 1, 2 }))
    local b = fixture()

    assert(b:RegisterDefaultBlock(block('fx.twice', { spell('base') }, {
        overrides = { { families = { 'tbc' }, steps = { spell('one') } }, { specs = { 1 }, steps = { spell('two') } } },
    })))

    rejects('ambiguous-block-override', b:ExpandDefaultRotation(pack(
        'fx.over',
        { ref('u', 'fx.twice') },
        { ['fx.twice'] = 1 },
        scope({ 'tbc' }, { 1 })
    )))

    rejects('incompatible-block-edition', b:RegisterDefaultBlock(block('fx.widen', { spell('x') }, {
        overrides = { { families = { 'retail' }, steps = { spell('y') } } },
    })))
end)

test('cycles, missing blocks, duplicate IDs and incompatible scopes are hard rejections', function()
    local cases = {
        { 'missing-block', {}, { ref('r', 'fx.none') }, { ['fx.none'] = 1 } },
        {
            'block-cycle',
            { block('fx.a', { ref('to-b', 'fx.b') }), block('fx.b', { ref('to-a', 'fx.a') }) },
            { ref('r', 'fx.a') },
            { ['fx.a'] = 1, ['fx.b'] = 1 },
        },
        {
            'block-cycle',
            { block('fx.self', { spell('s'), ref('again', 'fx.self') }) },
            { ref('r', 'fx.self') },
            { ['fx.self'] = 1 },
        },
        {
            'duplicate-step-id',
            { block('fx.i', { spell('hit') }) },
            { ref('one', 'fx.i', 'x-'), ref('two', 'fx.i', 'x-') },
            { ['fx.i'] = 1 },
        },
        {
            'duplicate-step-id',
            { block('fx.i', { spell('hit') }) },
            { spell('x-hit'), ref('one', 'fx.i', 'x-') },
            { ['fx.i'] = 1 },
        },
        {
            'duplicate-step-id',
            { block('fx.i', { spell('hit') }) },
            { spell('one'), ref('one', 'fx.i', 'z-') },
            { ['fx.i'] = 1 },
        },
        {
            'incompatible-block-edition',
            { block('fx.era', { spell('e') }, { families = { 'era' } }) },
            { ref('r', 'fx.era') },
            { ['fx.era'] = 1 },
        },
        {
            'incompatible-block-edition',
            { block('fx.o', { ref('in', 'fx.era') }), block('fx.era', { spell('e') }, { families = { 'era' } }) },
            { ref('r', 'fx.o') },
            { ['fx.o'] = 1, ['fx.era'] = 1 },
        },
        {
            'incompatible-block-class',
            { block('fx.mage', { spell('m') }, { class = 'MAGE' }) },
            { ref('r', 'fx.mage') },
            { ['fx.mage'] = 1 },
        },
        { 'undeclared-block-dependency', { block('fx.i', { spell('hit') }) }, { ref('r', 'fx.i') }, nil },
        {
            'undeclared-block-dependency',
            { block('fx.o', { ref('in', 'fx.i') }), block('fx.i', { spell('hit') }) },
            { ref('r', 'fx.o') },
            { ['fx.o'] = 1 },
        },
        {
            'unused-block-dependency',
            { block('fx.i', { spell('hit') }), block('fx.j', { spell('jab') }) },
            { ref('r', 'fx.i') },
            { ['fx.i'] = 1, ['fx.j'] = 1 },
        },
        {
            'stale-block-revision',
            { block('fx.i', { spell('hit') }, { revision = 2 }) },
            { ref('r', 'fx.i') },
            { ['fx.i'] = 1 },
        },
        {
            'invalid-block-reference',
            { block('fx.i', { spell('hit') }) },
            { { id = 'r', type = 'block', block = 'fx.i', conditions = {} } },
            { ['fx.i'] = 1 },
        },
        {
            'invalid-expanded-step-id',
            { block('fx.i', { spell(string.rep('h', 120)) }) },
            { ref('r', 'fx.i', 'long-prefix-') },
            { ['fx.i'] = 1 },
        },
    }

    for index, case in ipairs(cases) do
        local a = fixture()

        for _, b in ipairs(case[2]) do
            assert(a:RegisterDefaultBlock(b))
        end

        local why = rejects(case[1], a:RegisterDefaultRotation(pack('fx.case', case[3], case[4])))
        assert(why:find('$.', 1, true) or why:find('fx.', 1, true), 'diagnostic lacks a location: ' .. why)

        assert(
            a:InitializeRotationLibrary()
                and a:GetDefaultRotation('fx.case') == nil
                and a:GetDefaultRotationComposition('fx.case') == nil,
            'case ' .. index .. ' registered'
        )
    end

    local a = fixture()
    assert(a:RegisterDefaultBlock(block('fx.i', { spell('hit') })))
    rejects('duplicate-block-id', a:RegisterDefaultBlock(block('fx.i', { spell('other') })))

    rejects('duplicate-block-step-id', a:RegisterDefaultBlock(block('fx.d', {
        spell('hit'),
        { id = 'g', type = 'branch', conditions = {}, onTrue = { spell('hit') }, onFalse = {} },
    })))

    rejects('unknown-block-field', a:RegisterDefaultBlock(block('fx.u', { spell('x') }, { switch = {} })))
    rejects('empty-block', a:RegisterDefaultBlock(block('fx.e', {})))
end)

test('clone copies every expanded step and neither side can change the other', function()
    local a = fixture()

    local authoredBlock = block('fx.inner', {
        spell('hit'),
        { id = 'gate', type = 'branch', conditions = {}, onTrue = { spell('deep', 1757) }, onFalse = {} },
    })

    assert(a:RegisterDefaultBlock(authoredBlock))
    local authored = pack('fx.cloneable', { ref('m', 'fx.inner', 'm-'), spell('own', 1758) }, { ['fx.inner'] = 1 })
    assert(a:RegisterDefaultRotation(authored))
    assert(a:InitializeRotationLibrary())
    local cloneId = assert(a:CloneDefaultRotation(0, 'fx.cloneable', 'Mine'))
    local body = a:GetEditableRotation(0, cloneId)

    assert(
        #body.rotation == 3
            and body.rotation[1].action == 1752
            and body.rotation[2].onTrue[1].action == 1757
            and body.rotation[3].action == 1758
    )

    assert(not composedArtifacts(body), 'clone carries a block reference')
    local origin = a.db.profile.rotationLibrary.origins[0][cloneId]
    assert(origin.manifest.blocks == nil and not composedArtifacts(origin.lineage.baseline))
    local origins = {}

    for _, source in pairs(origin.lineage.stepOrigins) do
        origins[source] = true
    end

    for _, expected in ipairs({ 'm-hit', 'm-gate', 'm-deep', 'own' }) do
        assert(origins[expected], 'missing origin ' .. expected)
    end

    for _, row in ipairs(assert(a.RotationData.IndexRotationSteps(body)).rows) do
        assert(not origins[row.step.id], 'clone reused a source step ID')
    end

    body.rotation[1].action = 9999
    body.rotation[2].onTrue[1].conditions.spell = 1
    local source = a:GetDefaultRotation('fx.cloneable').envelope

    assert(
        source.body.rotation[1].action == 1752 and source.body.rotation[2].onTrue[1].conditions.spell == 1757,
        'clone edit reached its source'
    )

    authoredBlock.steps[1].action = 4242
    authoredBlock.steps[2].onTrue[1].action = 4343
    authored.body.rotation[2].action = 4444
    assert(same(source, a:GetDefaultRotation('fx.cloneable').envelope), 'authored tables still alias the Built In')

    assert(
        body.rotation[1].action == 9999
            and body.rotation[2].onTrue[1].action == 1757
            and body.rotation[3].action == 1758,
        'block source edit reached the clone'
    )

    assert(a:RegisterDefaultRotation(pack('fx.later', { ref('n', 'fx.inner') }, { ['fx.inner'] = 1 })))

    assert(
        a:InitializeRotationLibrary() and a:GetDefaultRotation('fx.later').envelope.body.rotation[1].action == 1752,
        'registry aliased its authored block'
    )

    local comparison = assert(a:BuildRotationComparison(0, cloneId, { kind = 'builtin', id = 'fx.cloneable' }))
    local edited = false

    for _, c in ipairs(comparison.customChanges.changes) do
        if c.path:find('rotation', 1, true) then
            edited = true
        end
    end

    assert(
        comparison.valid and #comparison.sourceChanges.changes == 0 and edited,
        'clone edits must compare as custom changes only'
    )
end)

test('export produces the expanded tree for the Built In and its clone', function()
    local a = fixture()
    assert(a:RegisterDefaultBlock(block('fx.inner', { spell('hit') })))

    assert(a:RegisterDefaultRotation(pack('fx.exported', { ref('m', 'fx.inner', 'm-'), spell('own', 1758) }, {
        ['fx.inner'] = 1,
    })))

    assert(a:InitializeRotationLibrary())
    local key

    for _, row in ipairs(a:ListDefaultRotations(0)) do
        if row.id == 'fx.exported' then
            key = row.runtimeKey
        end
    end

    local exported = assert(a:GetRotationExportData(0, assert(key)))
    assert(same(exported, a:GetDefaultRotation('fx.exported').envelope) and not composedArtifacts(exported))

    assert(
        a.RotationData.CheckPortable(exported)
            and a.RotationData.ValidateEnvelope(exported).valid
            and ids(a, exported.body) == 'm-hit own'
    )

    local cloneId = assert(a:CloneDefaultRotation(0, 'fx.exported', 'Mine'))
    local copy = assert(a:GetRotationExportData(0, cloneId))
    assert(not composedArtifacts(copy) and #copy.body.rotation == 2 and copy.body.rotation[1].action == 1752)
end)

test('a block revision is a source revision change for existing clones', function()
    local a = fixture()
    assert(a:RegisterDefaultBlock(block('fx.inner', { spell('hit') })))
    assert(a:RegisterDefaultRotation(pack('fx.updated', { ref('m', 'fx.inner', 'm-') }, { ['fx.inner'] = 1 })))
    assert(a:InitializeRotationLibrary())
    local cloneId = assert(a:CloneDefaultRotation(0, 'fx.updated', 'Mine'))
    local profile = a.db.profile
    -- A new block revision without updating the consumer pin cannot load.
    local stale = fixture()
    assert(stale:RegisterDefaultBlock(block('fx.inner', { spell('hit', 1757) }, { revision = 2 })))

    rejects('stale-block-revision', stale:RegisterDefaultRotation(pack('fx.updated', { ref('m', 'fx.inner', 'm-') }, {
        ['fx.inner'] = 1,
    })))

    local b = fixture()
    assert(b:RegisterDefaultBlock(block('fx.inner', { spell('hit', 1757) }, { revision = 2 })))

    assert(b:RegisterDefaultRotation(pack('fx.updated', { ref('m', 'fx.inner', 'm-') }, { ['fx.inner'] = 2 }, {
        revision = 2,
    })))

    b.db.profile = profile
    assert(b:InitializeRotationLibrary())
    local view = assert(b:GetSourcedRotationView(0, cloneId))
    assert(view.lineage.sourceRevision == 1 and b:GetDefaultRotation('fx.updated').revision == 2)
    local comparison = assert(b:BuildRotationComparison(0, cloneId, { kind = 'builtin', id = 'fx.updated' }))

    local function touches(changes, needle)
        for _, c in ipairs(changes) do
            if c.path:find(needle, 1, true) then
                return true
            end
        end

        return false
    end

    assert(
        comparison.valid and touches(comparison.sourceChanges.changes, 'rotation[m-hit].action'),
        'block change not reported as a source change'
    )

    assert(not touches(comparison.customChanges.changes, 'rotation'), 'block change misreported as a custom edit')
    assert(b:GetEditableRotation(0, cloneId).rotation[1].action == 1752, 'source update rewrote the clone')
end)

test('ledger records every shipped block digest and composed pack pin revision', function()
    local a, load = fixture()
    local authored, registered = {}, {}
    local registerBlock, registerRotation = a.RegisterDefaultBlock, a.RegisterDefaultRotation

    a.RegisterDefaultBlock = function(self, b)
        authored[#authored + 1] = a.RotationData.CopyData(b)
        return registerBlock(self, b)
    end

    a.RegisterDefaultRotation = function(self, p)
        registered[#registered + 1] = p.id
        return registerRotation(self, p)
    end

    a.loadAllDefaults = true

    for _, path in ipairs(dofile('tools/builtin_modules.lua').paths()) do
        load(path)
    end

    assert(a:InitializeRotationLibrary() and #authored > 0)
    local blocks, packs = {}, {}

    for _, b in ipairs(authored) do
        blocks[b.id] = true
        local rows = ledger.blocks[b.id]

        assert(
            rows and rows[b.revision] == digest(b),
            b.id .. ' content changed: bump its revision and append a ledger row ' .. b.revision .. '=' .. digest(b)
        )

        assert(newest(rows) == b.revision, b.id .. ' ledger has a newer revision than the source')
    end

    for _, id in ipairs(registered) do
        local composition = a:GetDefaultRotationComposition(id)

        if composition then
            packs[id] = true
            local view = a:GetDefaultRotation(id)
            local rows = ledger.packs[id]

            assert(
                rows and rows[view.revision] and same(rows[view.revision], composition.blocks),
                id .. ' block pins changed: bump its revision and append a ledger row'
            )

            assert(newest(rows) == view.revision, id .. ' ledger has a newer revision than the source')
        end
    end

    for id in pairs(ledger.blocks) do
        assert(blocks[id], 'ledger block ' .. id .. ' is not shipped')
    end

    for id in pairs(ledger.packs) do
        assert(packs[id], 'ledger pack ' .. id .. ' is not composed')
    end
end)

finish()
