local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/rotation_data.lua')

local function body(name)
    return {
        name = name,
        switch = {},
        rotation = { { id = 'step', type = 'spell', action = 403, conditions = {} } },
        cooldowns = {},
    }
end

local function ref(scope, id, owner, class)
    return {
        kind = 'custom',
        address = {
            scope = scope or 'class',
            class = class or 'SHAMAN',
            owner = owner or (scope == 'character' and 'A - Realm' or 'SHAMAN'),
            spec = 0,
            id = id or 'shared',
        },
    }
end

local function fixture()
    local data, envelope, validation = make()

    local a = {
        RotationData = data,
        conditionDefinitions = validation.conditions,
        db = {
            keys = { char = 'A - Realm' },
            global = { effects = {} },
            profile = {
                rotationFallbackID = 'Saved fallback',
                rotationStore = {
                    version = 1,
                    classes = {
                        SHAMAN = {
                            [0] = {
                                shared = { body = body('Class') },
                                ['Saved fallback'] = { body = body('Class fallback') },
                            },
                        },
                        MAGE = { [0] = { shared = { body = body('Foreign') } } },
                    },
                    characters = {
                        ['A - Realm'] = {
                            class = 'SHAMAN',
                            specs = {
                                [0] = {
                                    shared = { body = body('Character') },
                                    ['Saved fallback'] = { body = body('Character fallback') },
                                },
                            },
                        },
                    },
                    legacy = { rotations = { [0] = { old = body('Unassigned') } } },
                },
                rotationLibrary = {},
            },
        },
    }

    local context = {
        family = 'tbc',
        class = 'SHAMAN',
        level = 11,
        spec = 0,
        actionContext = 'player',
        combatDataPolicy = 'probe',
    }

    local n = 0

    a.uuid = function()
        n = n + 1
        return 'new-' .. n
    end

    local env = setmetatable({
        DEFAULT = 'Localized fallback',
        NEW = 'New',
        LibStub = function()
            return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
        end,
    }, { __index = _G })

    dofile('tests/fixtures/tbc_player_env.lua')(env)

    local function load(path)
        local file = io.open(path)

        if file then
            file:close()
            local chunk = assert(loadfile(path))
            setfenv(chunk, env)
            chunk('rotationmaster', a)
        end
    end

    for _, path in ipairs({
        'Platform/client.lua', 'Core/rotation_active.lua', 'Data/catalog.lua', 'Data/diff.lua',
        'Data/rotation_store.lua', 'Core/rotation_references.lua', 'Core/rotation_library.lua',
        'Core/rotation_tags.lua', 'Core/imports.lua', 'Core/rotation_scope.lua'
    }) do
        load(path)
    end

    a.GetRotationContext = function() return context end
    return a, context, envelope, load
end

local function bound()
    local a, c, e, load = fixture()
    assert(type(a.BindRotationProfile) == 'function', 'scoped facade missing')
    assert(a:BindRotationProfile())
    return a, c, e, load
end

local function reason(want, value, why)
    assert(value == nil and why == want, tostring(why) .. ' instead of ' .. want)
end

test(
    'bound headers contain only current owners and detached complete metadata with distinct fallback references',
    function()
        local a = bound()
        local rows = assert(a:ListRotationHeaders(0))
        assert(#rows == 4)
        local names, keys = {}, {}

        for _, row in ipairs(rows) do
            names[row.name] = true
            assert(type(row.key) == 'string' and row.key:sub(1, 1) == string.char(1) and not keys[row.key])
            keys[row.key] = true

            assert(
                type(row.search) == 'string'
                    and type(row.tags) == 'table'
                    and row.record == nil
                    and row.body == nil
                    and row.seal == nil
            )

            if row.name == 'Character fallback' then
                assert(row.fallback and row.effectiveFallback)
            elseif row.name == 'Class fallback' then
                assert(row.fallback and not row.effectiveFallback)
            end

            row.reference.address.class = 'MAGE'
        end

        assert(names.Class and names.Character and not names.Foreign and not names.Unassigned)
        assert(a:ListRotationHeaders(0)[1].reference.address.class == 'SHAMAN')
    end
)

test('DEFAULT is an effective alias while colliding bare IDs fail and exact references stay distinct', function()
    local a = bound()
    local fallback = assert(a:ResolveRotationReference(0, 'Localized fallback'))
    assert(fallback.address.scope == 'character' and fallback.address.id == 'Saved fallback')
    reason('ambiguous-rotation-reference', a:ResolveRotationReference(0, 'shared'))
    assert(a:GetRotationRecordSnapshot(0, ref()).body.name == 'Class')
    assert(a:GetRotationRecordSnapshot(0, ref('character')).body.name == 'Character')
    reason('foreign-owner', a:GetRotationRecordSnapshot(0, ref('class', 'shared', 'MAGE', 'MAGE')))
end)

test('record snapshots and expected tokens atomically replace or move complete exact records', function()
    local a = bound()
    local record, expected = assert(a:GetRotationRecordSnapshot(0, ref()))
    record.body.name = 'Moved'
    reason('rotation-id-collision', a:CommitRotationDraft(ref(), expected, record, 'character'))
    assert(a:GetRotationRecordSnapshot(0, ref('character')).body.name == 'Character')
    local _, characterExpected = a:GetRotationRecordSnapshot(0, ref('character'))
    assert(a:DeleteRotationRecord(ref('character'), characterExpected))
    local moved = assert(a:CommitRotationDraft(ref(), expected, record, 'character'))
    assert(moved.address.scope == 'character')
    assert(a:GetRotationRecordSnapshot(0, moved).body.name == 'Moved')
    reason('unknown-rotation', a:GetRotationRecordSnapshot(0, ref()))
end)

test('new drafts default Class preserve stable keys and write nothing until explicit commit', function()
    local a = bound()
    local reference, key = a:NewRotationDraftTarget(0)
    assert(reference and key and reference.address.scope == 'class')
    assert(a.db.profile.rotationStore.classes.SHAMAN[0][reference.address.id] == nil)
    local record = { body = body('New body') }
    local saved = assert(a:CommitRotationDraft(reference, nil, record, 'class'))

    assert(
        saved.address.id == reference.address.id and a:ResolveRotationReference(0, key).address.id == saved.address.id
    )

    local char = assert(a:NewRotationDraftTarget(0, 'character'))
    assert(char.address.scope == 'character')
end)

test(
    'invalid Character fallback blocks Class substitution and missing identity never selects Class fallback',
    function()
        local a, c = bound()
        a.db.profile.rotationStore.characters['A - Realm'].specs[0]['Saved fallback'].body.rotation = 'bad'
        assert(a:BindRotationProfile())
        local pass = assert(a:AcquireRotationRuntimePass(0))
        reason('invalid-fallback', pass:Get('Localized fallback'))
        a.db.keys.char = nil
        assert(a:BindRotationProfile())
        reason('missing-owner-context', a:ResolveRotationReference(0, 'Localized fallback'))
        assert(#a:ListRotationHeaders(0) >= 2)
    end
)

test('managed warm runtime assets avoid copies and legacy mutable exposure stays visible after Refresh', function()
    local a = bound()
    local target = ref('character')
    local pass = assert(a:AcquireRotationRuntimePass(0))
    local initial = assert(pass:Get(target))
    assert(initial.name == 'Character')
    local raw = assert(a:GetEditableRotation(0, target))
    raw.name = 'Legacy edit'
    local nextPass = assert(a:AcquireRotationRuntimePass(0))
    assert(nextPass:Get(target).name == 'Legacy edit' and initial.name == 'Character')
    assert(a:BindRotationProfile())
    raw.name = 'Late retained edit'
    assert(a:AcquireRotationRuntimePass(0):Get(target).name == 'Late retained edit')
end)

test('missing scoped fallback config blocks binding without guessing IDs or falling back to old maps', function()
    local a = fixture()
    a.db.profile.rotationFallbackID = nil
    assert(type(a.BindRotationProfile) == 'function', 'scoped facade missing')
    reason('missing-fallback-configuration', a:BindRotationProfile())
    a.db.profile.rotations = { [0] = { shared = body('Must stay hidden') } }
    local rows = a:GetRuntimeRotations(0)
    assert(next(rows) == nil)
end)

test('Built In headers and runtime keys remain class gated detached and preference aware', function()
    local a, c, envelope = bound()
    local pack = envelope()
    assert(a:RegisterDefaultRotation(pack))
    local foreign = envelope()
    foreign.id = 'foreign'
    foreign.applicability.class = 'MAGE'
    assert(a:RegisterDefaultRotation(foreign))
    local rows = assert(a:ListRotationHeaders(0))
    local builtin

    for _, h in ipairs(rows) do
        if h.kind == 'builtin' then
            assert(h.canonicalId == pack.id and h.readOnly)
            builtin = h
        end
    end

    assert(builtin, 'Built In header absent')
    local record = a:GetRotationRecordSnapshot(0, builtin.key)
    assert(record.body.name == pack.nameKey)
    local pass = assert(a:AcquireRotationRuntimePass(0))
    assert(pass:Get(builtin.key))
    assert(a:GetDefaultIdForRuntime(0, builtin.key) == pack.id)
    c.level = 99
    assert(not pass:Get(builtin.key) and not pass:IsCurrent())
    assert(a:AcquireRotationRuntimePass(0):Candidates()[builtin.key])
    c.level = 11
    assert(a:SetDefaultRotationEnabled(pack.id, false))
    assert(not pass:IsCurrent())
    assert(not a:AcquireRotationRuntimePass(0):Get(builtin.key))
end)

test(
    'source applicability and disabled dependency are enforced for customs without exposing lineage on polls',
    function()
        local a, c = bound()
        local raw = a:GetEditableRotation(0, ref())
        raw.switch = { type = 'SPELL_KNOWN', spell = 403 }
        a.conditionDefinitions.SPELL_KNOWN.disabled = true
        assert(not a:AcquireRotationRuntimePass(0):Get(ref()))
    end
)

test('malformed public references and pending foreign context return errors without throwing', function()
    local a, c = bound()

    for _, value in ipairs({
        { kind = 'custom', address = {} },
        { kind = 'custom', address = { scope = 'class', id = 'x' } },
        { kind = 'custom', address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = {} } },
        { kind = 'builtin', id = {} },
        {},
    }) do
        local ok, result = pcall(a.ResolveRotationReference, a, 0, value)
        assert(ok and result == nil, 'malformed reference threw or resolved')
    end

    local r, key = a:NewRotationDraftTarget(0)
    c.class = 'MAGE'
    reason('foreign-owner', a:ResolveRotationReference(0, key))
    reason('foreign-owner', a:ResolveRotationReference(0, r))
    assert(not a:NewRotationDraftTarget(0 / 0))
end)

test('scoped copies retain source baselines and exact custom ancestor addresses without mutating sources', function()
    local a, c, envelope = bound()
    local pack = envelope()
    assert(a:RegisterDefaultRotation(pack))
    local id, why, reference = a:CloneDefaultRotation(0, pack.id, 'Cloned', { scope = 'character' })
    assert(id and not why and reference.address.scope == 'character', tostring(why))
    local source = assert(a:GetSourcedRotationView(0, reference))
    assert(source.lineage.sourceId == pack.id and source.envelope.body.rotation[1].id ~= 'step-1')
    local copied, why, target = a:DuplicateCustomRotation(0, ref(), 'Duplicate')
    assert(copied and not why, tostring(why))
    local identity = assert(a:GetRotationComparisonIdentity(0, target))
    assert(identity.id == 'shared' and identity.sourceAddress.scope == 'class')
    assert(a:GetRotationRecordSnapshot(0, ref()).body.rotation[1].id == 'step')
    local nextId, why, nextRef = a:DuplicateCustomRotation(0, target, 'Duplicate again')
    assert(nextId, tostring(why))
    assert(a:GetRotationComparisonIdentity(0, nextRef).sourceAddress.scope == 'class')
end)

test(
    'scoped imports and replacement previews require exact target authority and preserve the selected owner',
    function()
        local a = bound()
        local prepared = { body = body('Input') }
        local id, why, r = a:CreateImportedRotation(prepared, 0, 'Imported', nil, { scope = 'character' })
        assert(id and r and r.address.scope == 'character', tostring(why))
        local record, expected = a:GetRotationRecordSnapshot(0, ref())
        local replacement = { reference = ref(), recordToken = expected, profile = a.db.profile }
        local nextId, why, target = a:CreateImportedRotation(prepared, 0, 'Replacement', replacement)
        assert(nextId == 'shared' and target.address.scope == 'class', tostring(why))

        assert(
            a:GetRotationRecordSnapshot(0, ref()).body.name == 'Replacement'
                and a:GetRotationRecordSnapshot(0, ref('character')).body.name == 'Character'
        )

        assert(not a:CreateImportedRotation(prepared, 0, 'Stale', replacement))
        local _, envelope = make()
        local pack = envelope()
        pack.applicability.class = 'MAGE'
        local old = a.uuid

        a.uuid = function()
            error('foreign import allocated')
        end

        local imported = { body = pack.body, manifest = pack }
        imported.manifest.body = nil
        local value, why = a:CreateImportedRotation(imported, 0, 'Foreign')
        assert(not value and why == 'class-mismatch')
        a.uuid = old
    end
)

test(
    'warm native headers and runtime avoid body and foreign payload copies while invalid owned records stay visible',
    function()
        local a = bound()
        local d = a.RotationData
        local foreign = {}

        for i = 1, 1000 do
            local b = body('Foreign ' .. i)
            foreign[b] = true
            a.db.profile.rotationStore.classes.MAGE[0]['other-' .. i] = { body = b }
        end

        assert(a:BindRotationProfile())
        a:ListRotationHeaders(0)
        a:AcquireRotationRuntimePass(0):Candidates()
        local bodies = {}

        for _, r in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do
            bodies[r.body] = true
        end

        for _, r in pairs(a.db.profile.rotationStore.characters['A - Realm'].specs[0]) do
            bodies[r.body] = true
        end

        local copied, checked = 0, 0
        local originalCopy, originalCheck = d.CopyData, d.CheckPortable

        d.CopyData = function(v)
            if bodies[v] or foreign[v] then
                copied = copied + 1
            end

            return originalCopy(v)
        end

        d.CheckPortable = function(v)
            if foreign[v] then
                checked = checked + 1
            end

            return originalCheck(v)
        end

        for i = 1, 10 do
            assert(a:ListRotationHeaders(0))
            assert(a:AcquireRotationRuntimePass(0):Candidates())
        end

        d.CopyData = originalCopy
        d.CheckPortable = originalCheck
        assert(copied == 0 and checked == 0, tostring(copied) .. ' copies/' .. checked .. ' foreign traversals')
        a.db.profile.rotationStore.characters['A - Realm'].specs[0].shared.body.rotation = false
        assert(a:BindRotationProfile())
        local found = false

        for _, h in ipairs(a:ListRotationHeaders(0)) do
            if h.name == 'Character' then
                assert(h.validationState == 'invalid')
                found = true
            end
        end

        assert(found)
    end
)

test('configured fallback changes and profile transitions fail closed until explicit rebind', function()
    local a = bound()
    a.db.profile.rotationFallbackID = 'Changed'
    assert(not a:AcquireRotationRuntimePass(0))
    a.db.profile = { rotations = { [0] = { shared = body('Unassigned new profile') } } }
    assert(not a:GetEditableRotation(0, 'shared'))
    local rows = a:GetRuntimeRotations(0)
    assert(next(rows) == nil)
end)

test('comparisons distinguish same IDs at different owners and retain three-way sourced reports', function()
    local a, c, envelope = bound()
    local result = assert(a:BuildRotationComparison(0, ref(), ref('character')))
    assert(#result.views == 1)
    local value, why = a:BuildRotationComparison(0, ref(), ref())
    assert(not value and why == 'self-comparison')
    local pack = envelope()
    assert(a:RegisterDefaultRotation(pack))
    local id, why, target = a:CloneDefaultRotation(0, pack.id, 'Clone')
    assert(id, tostring(why))
    local source = assert(a:GetSourcedRotationView(0, target))
    local no, why = a:GetImportedRotationView(0, target)
    assert(not no and why == 'not-imported')
    result = assert(a:BuildRotationComparison(0, target, { kind = 'builtin', id = pack.id }))
    assert(#result.views == 3 and source.lineage.baseline.body.rotation[1].action == 403)
end)

test('legacy mutable exposure cannot edit shared foreign payloads or immutable lineage baselines', function()
    local a, c, envelope = bound()
    local pack = envelope()
    assert(a:RegisterDefaultRotation(pack))
    local id, why, target = a:CloneDefaultRotation(0, pack.id, 'Aliased source')
    assert(id, tostring(why))
    local record = a.db.profile.rotationStore.classes.SHAMAN[0][id]
    local condition = record.body.rotation[1].conditions
    record.origin.lineage.baseline.body.rotation[1].conditions = condition
    a.db.profile.rotationStore.classes.MAGE[0].shared.body.rotation[1].conditions = condition
    assert(a:BindRotationProfile())
    local editable = assert(a:GetEditableRotation(0, target))
    editable.rotation[1].conditions.spell = 974

    assert(
        record.origin.lineage.baseline.body.rotation[1].conditions.spell == 403,
        'legacy edit changed immutable source'
    )

    assert(
        a.db.profile.rotationStore.classes.MAGE[0].shared.body.rotation[1].conditions.spell == 403,
        'legacy edit changed foreign owner'
    )

    assert(a:GetEditableRotation(0, target) == editable)
    assert(a:BindRotationProfile())
    editable.name = 'Retained pointer'
    assert(a:AcquireRotationRuntimePass(0):Get(target).name == 'Retained pointer')
end)

test('imported duplicates retain step correspondence and applicability under scoped comparisons', function()
    local a, c, envelope = bound()
    local pack = envelope()
    local prepared = { body = pack.body, manifest = pack }
    prepared.manifest.body = nil
    local id, why, reference = a:CreateImportedRotation(prepared, 0, 'Imported')
    assert(id, tostring(why))
    local duplicate, why, target = a:DuplicateCustomRotation(0, reference, 'Duplicate import')
    assert(duplicate, tostring(why))
    local diff = assert(a:BuildRotationComparison(0, target, reference))

    for _, change in ipairs(diff.changes) do
        assert(change.kind ~= 'added' and change.kind ~= 'removed', 'import correspondence lost')
    end

    c.level = 99
    assert(not a:AcquireRotationRuntimePass(0):Get(target))
    assert(a:AcquireRotationRuntimePass(0):Candidates()[a:GetScopedRotationCoordinator():Key(target)])
end)

test('runtime passes retain selected and candidate membership seals without staling on unrelated records', function()
    local a = bound()
    local pass = assert(a:AcquireRotationRuntimePass(0))
    local old = assert(pass:Get(ref()))
    local changed, token = a:GetRotationRecordSnapshot(0, ref('character'))
    changed.body.name = 'Unrelated'
    assert(a:CommitRotationDraft(ref('character'), token, changed))
    assert(pass:IsCurrent() and pass:Get(ref()) == old)
    changed, token = a:GetRotationRecordSnapshot(0, ref())
    assert(a:CommitRotationDraft(ref(), token, changed))
    assert(not pass:IsCurrent() and not pass:Get(ref()), 'same-value selected replacement left pass current')
    pass = assert(a:AcquireRotationRuntimePass(0))
    assert(pass:Candidates())
    assert(pass:IsCurrent())
    changed, token = a:GetRotationRecordSnapshot(0, ref('character'))
    changed.body.name = 'Candidate changed'
    assert(a:CommitRotationDraft(ref('character'), token, changed))
    assert(not pass:IsCurrent(), 'candidate list change left pass current')
    local result, why = pass:Candidates()
    assert(next(result) == nil and why)
end)

test('deleted issued keys remain cleanup only after the exact address is recreated', function()
    local a = bound()
    local key

    for _, h in ipairs(a:ListRotationHeaders(0)) do
        if h.name == 'Class' then
            key = h.key
        end
    end

    local outgoing = assert(a:AcquireRotationRuntimePass(0):Get(key))
    local _, token = a:GetRotationRecordSnapshot(0, ref())
    assert(a:DeleteRotationRecord(ref(), token))
    assert(a:CommitRotationDraft(ref(), nil, { body = body('Recreated') }))
    assert(not a:ResolveRotationReference(0, key), 'old issued key reached recreated record')
    assert(a:GetRotationForCleanup(0, key) == outgoing)
    local fresh

    for _, h in ipairs(a:ListRotationHeaders(0)) do
        if h.name == 'Recreated' then
            fresh = h.key
        end
    end

    assert(fresh and fresh ~= key and a:ResolveRotationReference(0, fresh).address.id == 'shared')
end)

test('header stamps stay stable until owned presentation records or library preferences change', function()
    local a, c, envelope = bound()
    local pack = envelope()
    assert(a:RegisterDefaultRotation(pack))
    local _, stamp = a:ListRotationHeaders(0)
    local _, unchanged = a:ListRotationHeaders(0)
    assert(stamp == unchanged, 'unchanged header stamp churned')
    assert(a:SetDefaultRotationEnabled(pack.id, false))
    local _, disabled = a:ListRotationHeaders(0)
    assert(disabled ~= stamp)
    local raw = assert(a:GetEditableRotation(0, ref()))
    local _, detached = a:ListRotationHeaders(0)
    local _, stable = a:ListRotationHeaders(0)
    assert(detached == stable)
    raw.name = 'Changed presentation'
    local _, renamed = a:ListRotationHeaders(0)
    assert(renamed ~= detached)
    local _, again = a:ListRotationHeaders(0)
    assert(again == renamed)
end)

test(
    'runtime direct fallback references obey Character precedence while saved Class snapshots stay editable',
    function()
        local a = bound()
        local class = ref('class', 'Saved fallback')
        local character = ref('character', 'Saved fallback')
        assert(a:GetRotationRecordSnapshot(0, class).body.name == 'Class fallback')
        local value, why = a:AcquireRotationRuntimePass(0):Get(class)
        assert(not value and why == 'inactive-fallback')
        local changed, token = a:GetRotationRecordSnapshot(0, character)
        changed.body.rotation = false
        assert(a:CommitRotationDraft(character, token, changed))
        value, why = a:AcquireRotationRuntimePass(0):Get(class)
        assert(not value and why == 'inactive-fallback')
        a.db.profile.rotationStore.characters['A - Realm'].specs[0]['Saved fallback'] = nil
        assert(a:BindRotationProfile())
        local pass = assert(a:AcquireRotationRuntimePass(0))
        assert(pass:Get(class))
        assert(a:CommitRotationDraft(character, nil, { body = body('New override') }))
        assert(not pass:IsCurrent(), 'new Character override did not retire prior Class fallback selection')
    end
)

test(
    'runtime passes discard partial candidates after mutation and detect exposed legacy or eligibility changes',
    function()
        local a = bound()
        local pass = assert(a:AcquireRotationRuntimePass(0))
        local original = a.HasDisabledRotationDependency
        local changed = false

        a.HasDisabledRotationDependency = function(self, value)
            if not changed then
                changed = true
                local r = ref('character', 'Saved fallback')
                local record, token = self:GetRotationRecordSnapshot(0, r)
                record.body.name = 'Changed during candidates'
                assert(self:CommitRotationDraft(r, token, record))
            end

            return original(self, value)
        end

        local rows, why = pass:Candidates()

        assert(
            next(rows) == nil and why == 'rotation-records-changed' and not pass:IsCurrent(),
            'partial candidate batch escaped'
        )

        a.HasDisabledRotationDependency = original
        local raw = assert(a:GetEditableRotation(0, ref()))
        pass = assert(a:AcquireRotationRuntimePass(0))
        assert(pass:Get(ref()))
        raw.name = 'Changed after read'
        assert(not pass:IsCurrent())
        local b, c = bound()
        pass = assert(b:AcquireRotationRuntimePass(0))
        assert(pass:Get(ref()))
        c.actionContext = 'vehicle'
        assert(not pass:IsCurrent() and not pass:Get(ref()))
    end
)

test('candidate batches check complete list authority a constant number of times at one thousand records', function()
    local a = bound()

    for i = 1, 1000 do
        a.db.profile.rotationStore.classes.SHAMAN[0]['extra-' .. i] = {
            body = { name = 'Extra ' .. i, rotation = {}, cooldowns = {} },
        }
    end

    local makeStore = a.RotationData.NewRotationStore
    local listChecks = 0
    local lists = setmetatable({}, { __mode = 'k' })

    a.RotationData.NewRotationStore = function(options)
        local bind = options.bindInternalReader

        options.bindInternalReader = function(reader)
            local list, current = reader.ListOwned, reader.IsCurrent

            reader.ListOwned = function(self, ...)
                local rows, seal = list(self, ...)

                if rows then
                    lists[seal] = true
                end

                return rows, seal
            end

            reader.IsCurrent = function(self, seal, ...)
                if lists[seal] then
                    listChecks = listChecks + 1
                end

                return current(self, seal, ...)
            end

            bind(reader)
        end

        return makeStore(options)
    end

    assert(a:BindRotationProfile())
    a.RotationData.NewRotationStore = makeStore
    local pass = assert(a:AcquireRotationRuntimePass(0))
    local rows = assert(pass:Candidates())
    local count = 0

    for _ in pairs(rows) do
        count = count + 1
    end

    assert(count == 1003 and listChecks == 1, tostring(count) .. ' rows/' .. listChecks .. ' list checks')
    listChecks = 0
    assert(pass:Candidates())
    assert(listChecks == 2, 'repeated batch performed per-row list checks')
end)

finish()
