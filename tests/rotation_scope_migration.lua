local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/rotation_data.lua')

local function fixture()
    local data = make()

    local a = {
        RotationData = data,
        db = {
            keys = { char = 'A - Realm' },
            profile = {
                rotations = { [0] = { Fallback = {}, same = { name = 'Keep exact', rotation = {}, cooldowns = {} } } },
                rotationLibrary = { preferences = {} },
            },
            sv = {
                profiles = {},
                char = {
                    ['A - Realm'] = { rotations = { [0] = { charold = { name = 'Character recovery' } } } },
                    ['B - Realm'] = { rotations = { [0] = { offline = { name = 'Offline' } } } },
                },
            },
        },
    }

    local n = 0

    a.uuid = function()
        n = n + 1
        return 'id-' .. n
    end

    local env = setmetatable({
        DEFAULT = 'Fallback',
        NEW = 'New',
        LibStub = function()
            return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
        end,
    }, { __index = _G })

    dofile('tests/fixtures/tbc_player_env.lua')(env)

    local function load(path)
        local f = io.open(path)

        if f then
            f:close()
            local c = assert(loadfile(path))
            setfenv(c, env)
            c('rotationmaster', a)
        end
    end

    for _, path in ipairs({
        'Platform/client.lua',
        'Data/catalog.lua',
        'Data/diff.lua',
        'Data/rotation_store.lua',
        'Core/rotation_references.lua',
        'Core/rotation_library.lua',
        'Core/rotation_scope.lua',
        'Core/rotation_migration.lua',
    }) do
        load(path)
    end

    a.db.global = {}

    a.GetRotationContext = function()
        return { class = 'SHAMAN', family = 'tbc', actionContext = 'player', combatDataPolicy = 'probe' }
    end

    a.db.sv.profiles.Shared = a.db.profile
    return a, load
end

test('migration archives every unknown legacy body exactly and is idempotent without inferred ownership', function()
    local a = fixture()
    assert(a.PlanRotationProfileMigration, 'migration service missing')
    local plan = assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))
    assert(a.db.profile.rotationStore == nil)
    assert(a:ApplyRotationProfileMigration(plan))
    local state = a.db.profile.rotationStore

    assert(
        next(state.classes) == nil and next(state.characters) == nil and next(state.legacy.rotations[0].Fallback) == nil
    )

    assert(a.db.profile.rotationFallbackID == 'Fallback' and next(a.db.profile.rotations) == nil)
    assert(a:PlanRotationProfileMigration(a.db.profile, 'Other'))
    assert(a.db.profile.rotationStore == state)
    assert(a.db.sv.char['B - Realm'].rotations[0].offline.name == 'Offline')
end)

test('migration refuses stale plans and scoped missing configuration without guessing or mutation', function()
    local a = fixture()
    local plan = assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))
    a.db.profile.rotations[0].same.name = 'Changed'
    assert(not a:ApplyRotationProfileMigration(plan) and a.db.profile.rotationStore == nil)
    a.db.profile = { rotationStore = { version = 1, classes = {}, characters = {}, legacy = {} } }
    local plan, why = a:PlanRotationProfileMigration(a.db.profile, 'Fallback')
    assert(not plan and why == 'missing-fallback-configuration')
end)

test(
    'explicit profile adoption preserves IDs and incomplete bodies and stale or colliding previews change neither source nor target',
    function()
        local a = fixture()
        assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
        assert(a:BindRotationProfile())
        local rows = assert(a:ListUnassignedRotations())
        assert(#rows == 3)
        local plan = assert(a:PlanRotationAdoption({ kind = 'profile', spec = 0, id = 'Fallback' }, 'character'))
        assert(a:ApplyRotationAdoption(plan))
        assert(next(a.db.profile.rotationStore.characters['A - Realm'].specs[0].Fallback.body) == nil)
        assert(a.db.profile.rotationStore.legacy.rotations[0].Fallback == nil)
        local p = assert(a:PlanRotationAdoption({ kind = 'profile', spec = 0, id = 'same' }, 'class'))
        a.db.profile.rotationStore.legacy.rotations[0].same.name = 'Changed'
        assert(not a:ApplyRotationAdoption(p) and a.db.profile.rotationStore.classes.SHAMAN == nil)
    end
)

test('current-character adoption publishes both guarded roots and leaves offline archives untouched', function()
    local a = fixture()
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
    assert(a:BindRotationProfile())
    local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }, 'class'))
    assert(a:ApplyRotationAdoption(plan))
    assert(a.db.profile.rotationStore.classes.SHAMAN[0].charold.body.name == 'Character recovery')

    assert(
        a.db.sv.char['A - Realm'].rotations[0].charold == nil
            and a.db.sv.char['B - Realm'].rotations[0].offline.name == 'Offline'
    )
end)

test(
    'Character adoption guards source destination configuration and current identity before either root publishes',
    function()
        for _, scenario in ipairs({ 'source', 'destination', 'fallback', 'identity' }) do
            local a = fixture()
            assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
            assert(a:BindRotationProfile())
            local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }, 'character'))

            if scenario == 'source' then
                a.db.sv.char['A - Realm'].rotations[0].charold.name = 'Changed'
            elseif scenario == 'destination' then
                a.db.profile.rotationStore.classes.SHAMAN = { [0] = { new = { body = { name = 'External' } } } }
            elseif scenario == 'fallback' then
                a.db.profile.rotationFallbackID = 'Changed'
            else
                a.db.keys.char = 'B - Realm'
            end

            assert(not a:ApplyRotationAdoption(plan), scenario)

            assert(
                a.db.profile.rotationStore.characters['A - Realm'] == nil
                    and a.db.sv.char['A - Realm'].rotations[0].charold ~= nil
            )
        end
    end
)

test('adoption never accepts a foreign owner selector or reidentifies a collision', function()
    local a = fixture()
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
    assert(a:BindRotationProfile())
    assert(not a:PlanRotationAdoption({ kind = 'character', owner = 'B - Realm', spec = 0, id = 'charold' }, 'class'))
    assert(a:ApplyRotationAdoption(assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }))))
    local original = a.db.sv.char['A - Realm'].rotations
    original[0].charold = { name = 'Again' }
    local plan, why = a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }, 'class')
    assert(not plan and why == 'rotation-id-collision')

    assert(
        original[0].charold.name == 'Again'
            and a.db.profile.rotationStore.classes.SHAMAN[0].charold.body.name == 'Character recovery'
    )
end)

test('migration detaches shared cross-profile library containers before retiring sidecars', function()
    local a = fixture()
    local shared = { preferences = { pack = { enabled = false } }, origins = { [0] = { same = { note = 'retain' } } } }
    a.db.profile.rotationLibrary = shared
    local other = { rotations = { [0] = { same = { name = 'Other' } } }, rotationLibrary = shared }
    a.db.sv.profiles.Other = other
    assert(a:InitializeScopedRotationStorage())
    assert(a.db.profile.rotationStore.legacy.origins[0].same.note == 'retain')
    assert(other.rotationStore.legacy.origins[0].same.note == 'retain' and shared.origins[0].same.note == 'retain')

    assert(
        a.db.profile.rotationLibrary ~= other.rotationLibrary
            and a.db.profile.rotationLibrary.preferences ~= other.rotationLibrary.preferences
    )

    assert(
        a.db.profile.rotationLibrary.preferences.pack.enabled == false
            and other.rotationLibrary.preferences.pack.enabled == false
    )
end)

test('Character adoption requires the current profile and roots to be explicitly bound at plan and Apply', function()
    local a = fixture()
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
    assert(a:BindRotationProfile())
    local original = a.db.profile

    local replacement = {
        rotationStore = { version = 1, classes = {}, characters = {}, legacy = {} },
        rotationFallbackID = 'Fallback',
    }

    a.db.profile = replacement
    local p, why = a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }, 'class')
    assert(not p and why == 'rotation-profile-changed')
    assert(next(replacement.rotationStore.classes) == nil and a.db.sv.char['A - Realm'].rotations[0].charold)
    a.db.profile = original
    local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'charold' }, 'class'))
    a:GetScopedRotationCoordinator():Retire()
    assert(not a:ApplyRotationAdoption(plan) and a.db.sv.char['A - Realm'].rotations[0].charold)
end)

test('explicit false legacy body and sidecar roots fail without normalization or data retirement', function()
    for _, kind in ipairs({ 'rotations', 'origins', 'imports', 'comparisons' }) do
        local a = fixture()

        if kind == 'rotations' then
            a.db.profile.rotations = false
        else
            a.db.profile.rotationLibrary[kind] = false
        end

        local plan = a:PlanRotationProfileMigration(a.db.profile, 'Fallback')
        assert(not plan, kind .. ' false root silently normalized')
        assert(a.db.profile.rotationStore == nil)

        if kind == 'rotations' then
            assert(a.db.profile.rotations == false)
        else
            assert(a.db.profile.rotationLibrary[kind] == false)
        end
    end
end)

test(
    'unassigned snapshots detach complete profile archives including orphan source evidence without mutation',
    function()
        local a = fixture()

        a.db.profile.rotationLibrary.origins = {
            [0] = { same = { source = 'origin' }, orphan = { source = 'orphan' } },
        }

        a.db.profile.rotationLibrary.imports = { [0] = { same = { source = 'import' } } }
        a.db.profile.rotationLibrary.comparisons = { [0] = { same = { source = 'comparison' } } }
        assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
        assert(a:BindRotationProfile())
        assert(a.GetUnassignedRotationSnapshot, 'archival snapshot API missing')
        local root = a.db.profile.rotationStore
        local snapshot = assert(a:GetUnassignedRotationSnapshot({ kind = 'profile', spec = 0, id = 'same' }))

        assert(
            snapshot.body.name == 'Keep exact'
                and snapshot.origin.source == 'origin'
                and snapshot.imported.source == 'import'
                and snapshot.comparison.source == 'comparison'
        )

        snapshot.body.name = 'Detached'
        snapshot.origin.source = 'Detached'
        snapshot.imported.source = 'Detached'
        snapshot.comparison.source = 'Detached'
        local nextSnapshot = assert(a:GetUnassignedRotationSnapshot({ kind = 'profile', spec = 0, id = 'same' }))

        assert(
            nextSnapshot.body.name == 'Keep exact'
                and nextSnapshot.origin.source == 'origin'
                and nextSnapshot.imported.source == 'import'
                and nextSnapshot.comparison.source == 'comparison'
        )

        local orphan = assert(a:GetUnassignedRotationSnapshot({ kind = 'profile', spec = 0, id = 'orphan' }))
        assert(orphan.body == nil and orphan.origin.source == 'orphan')
        local empty = assert(a:GetUnassignedRotationSnapshot({ kind = 'profile', spec = 0, id = 'Fallback' }))
        assert(next(empty.body) == nil)

        assert(
            a.db.profile.rotationStore == root
                and root.legacy.rotations[0].same.name == 'Keep exact'
                and next(root.classes) == nil
        )
    end
)

test(
    'unassigned current-character snapshots isolate exact archives and reject foreign or malformed selections',
    function()
        local a = fixture()
        assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
        assert(a:BindRotationProfile())
        assert(a.GetUnassignedRotationSnapshot, 'archival snapshot API missing')
        local raw = a.db.sv.char['A - Realm'].rotations
        local snapshot = assert(a:GetUnassignedRotationSnapshot({ kind = 'character', spec = 0, id = 'charold' }))
        assert(snapshot.body.name == 'Character recovery')
        snapshot.body.name = 'Detached'
        assert(raw[0].charold.name == 'Character recovery')
        local value, why = a:GetUnassignedRotationSnapshot({ kind = 'character', spec = 0, id = 'offline' })
        assert(value == nil and why == 'unknown-rotation')

        local invalid = {
            false,
            {},
            { kind = 'profile', spec = 0, id = 'same', owner = 'B - Realm' },
            { kind = 'character', spec = 0, id = 'charold', owner = 'B - Realm' },
            { kind = 'profile', spec = 0 / 0, id = 'same' },
            { kind = 'profile', spec = math.huge, id = 'same' },
            { kind = 'profile', spec = -1, id = 'same' },
            { kind = 'profile', spec = .5, id = 'same' },
            { kind = 'profile', spec = 0, id = '' },
            { kind = 'profile', spec = 0, id = 'bad\1' },
            setmetatable({ kind = 'profile', spec = 0, id = 'same' }, {}),
        }

        for _, selection in ipairs(invalid) do
            local ok, result, reason = pcall(a.GetUnassignedRotationSnapshot, a, selection)
            assert(ok and result == nil and reason == 'invalid-legacy-selection')
        end

        a.db.sv.char['A - Realm'].rotations = false
        value, why = a:GetUnassignedRotationSnapshot({ kind = 'character', spec = 0, id = 'charold' })
        assert(value == nil and why == 'invalid-legacy-state')
    end
)

test('unassigned snapshots require a current bound profile and explicit valid owner context', function()
    local a = fixture()
    assert(a.GetUnassignedRotationSnapshot, 'archival snapshot API missing')
    local selection = { kind = 'profile', spec = 0, id = 'same' }
    local value, why = a:GetUnassignedRotationSnapshot(selection)
    assert(value == nil and why == 'rotation-profile-not-bound')
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
    assert(a:BindRotationProfile())
    local original = a.db.profile

    a.db.profile = {
        rotationStore = { version = 1, classes = {}, characters = {}, legacy = {} },
        rotationFallbackID = 'Fallback',
    }

    value, why = a:GetUnassignedRotationSnapshot(selection)
    assert(value == nil and why == 'rotation-profile-changed')
    a.db.profile = original
    local getContext = a.GetRotationContext
    a.GetRotationContext = function() return {} end
    value, why = a:GetUnassignedRotationSnapshot(selection)
    assert(value == nil and why == 'missing-owner-context')
    a.GetRotationContext = getContext
    a.db.keys.char = nil
    value, why = a:GetUnassignedRotationSnapshot({ kind = 'character', spec = 0, id = 'charold' })
    assert(value == nil and why == 'missing-owner-context')
    assert(a:GetUnassignedRotationSnapshot(selection).body.name == 'Keep exact')
    a:GetScopedRotationCoordinator():Retire()
    value, why = a:GetUnassignedRotationSnapshot(selection)
    assert(value == nil and why == 'rotation-profile-changed')
end)

test('adopted fallback retires virtual pending leases without overwriting a dirty old workspace', function()
    local a, load = fixture()

    for _, path in ipairs({ 'Data/rotation_draft.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua' }) do
        load(path)
    end

    a.validateCondition = function() return true end
    a.db.profile.rotations[0].Fallback = { name = 'Recovered fallback', rotation = {}, cooldowns = {} }
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(a.db.profile, 'Fallback'))))
    assert(a:BindRotationProfile())
    local rows = assert(a:ListRotationHeaders(0))
    local virtual

    for _, row in ipairs(rows) do
        if row.virtual then
            virtual = row
        end
    end

    assert(virtual and virtual.pending)
    local old = assert(a:GetRotationEditWorkspace(0, virtual.key))
    assert(old.pending and old:Command('SetBodyField', 'description', 'Keep this unsaved draft'))
    local plan = assert(a:PlanRotationAdoption({ kind = 'profile', spec = 0, id = 'Fallback' }, 'class'))
    local ok, reference = a:ApplyRotationAdoption(plan)
    assert(ok)
    assert(not a:GetScopedRotationCoordinator():IsPending(reference), 'saved adoption remained pending')
    assert(not old:ValidTarget() and not old:Apply(), 'dirty virtual workspace overwrote adopted record')

    assert(
        old:Snapshot().description == 'Keep this unsaved draft'
            and a.db.profile.rotationStore.classes.SHAMAN[0].Fallback.body.description == nil
    )

    assert(not a:ResolveRotationReference(0, virtual.key), 'retired virtual key authorized the saved record')
    local fresh = assert(a:GetRotationEditWorkspace(0, reference))
    assert(fresh ~= old and not fresh.pending and fresh:Snapshot().name == 'Recovered fallback')
end)

finish()
