-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/rotation_data.lua')

local function clone(v)
    if type(v) ~= 'table' then
        return v
    end

    assert(not getmetatable(v))
    local r = {}

    for k, c in pairs(v) do
        r[k] = clone(c)
    end

    return r
end

local function fixture(saved, class, name)
    class = class or 'SHAMAN'
    name = name or 'A'
    local env = setmetatable({ ScopeDB = saved }, { __index = _G })
    env._G = env
    dofile('tests/fixtures/tbc_player_env.lua')(env)
    local scripts = {}

    env.CreateFrame = function()
        return {
            RegisterEvent = function() end,
            SetScript = function(_, e, fn)
                scripts[e] = fn
            end,
        }
    end

    env.UnitFactionGroup = function() return 'Horde' end
    env.GetLocale = function() return 'enUS' end
    env.UnitClass = function() return class, class end
    env.UnitRace = function() return 'Orc', 'Orc' end
    env.GetRealmName = function() return 'Realm' end
    env.UnitNameUnmodified = function() return name end
    env.GetCurrentRegionName = function() return 'US' end
    env.GetCurrentRegion = function() return 1 end
    env.strlenutf8 = string.len
    env.securecallfunction = function(fn, ...) return fn(...) end
    env.DEFAULT = 'Fallback'
    env.NEW = 'New'
    local data = make()
    local a = { RotationData = data }

    local function load(path)
        local c = assert(loadfile(path))
        setfenv(c, env)
        c('rotationmaster', a)
    end

    env.LibStub = false
    load('Libs/LibStub/LibStub.lua')
    load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
    load('Libs/AceDB-3.0/AceDB-3.0.lua')

    env.LibStub:NewLibrary('AceLocale-3.0', 1).GetLocale = function()
        return setmetatable({}, { __index = function(_, k) return k end })
    end

    a.db = env.LibStub('AceDB-3.0'):New(
        'ScopeDB',
        { profile = { enable = true }, global = { effects = {} }, char = { bindings = {} } },
        'Shared'
    )

    for _, p in ipairs({
        'Platform/client.lua', 'Core/rotation_active.lua', 'Data/catalog.lua', 'Data/diff.lua',
        'Data/rotation_store.lua', 'Core/rotation_references.lua', 'Core/rotation_library.lua',
        'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Core/rotation_lifecycle.lua'
    }) do
        load(p)
    end

    a.GetRotationContext = function()
        return {
            class = class,
            family = 'tbc',
            spec = 0,
            level = 11,
            actionContext = 'player',
            combatDataPolicy = 'probe',
        }
    end

    return a, env, scripts
end

local function ref(scope, id, class, owner)
    return {
        kind = 'custom',
        address = {
            scope = scope,
            class = class or 'SHAMAN',
            owner = owner or (scope == 'class' and (class or 'SHAMAN') or 'A - Realm'),
            spec = 0,
            id = id,
        },
    }
end

local function body(name)
    return { name = name, rotation = {}, cooldowns = {} }
end

test('profile lifecycle binds after Set Copy Reset and imported overlay before runtime resumes', function()
    local a = fixture()
    assert(a:InitializeScopedRotationStorage())
    local activated = {}
    a.currentSpec = 0
    a.db.profile.enable = true

    a.DisableRotation = function(self)
        self.currentRotation = nil
    end

    a.EnableRotation = function(self)
        assert(self:ListRotationHeaders(0))
        activated[#activated + 1] = self.db.profile
    end

    a.RefreshConfiguration = function() end
    a:InstallRotationProfileLifecycle()
    local first = a.db.profile
    assert(a:CommitRotationDraft(ref('class', 'owned'), nil, { body = body('Original') }, 'class'))
    a.db:SetProfile('Second')
    assert(a.db.profile ~= first and a:ListRotationHeaders(0) and a.db.profile.rotationFallbackID == 'Fallback')
    a.db:CopyProfile('Shared')
    assert(a:GetRotationRecordSnapshot(0, ref('class', 'owned')).body.name == 'Original')
    a.db:ResetProfile()
    assert(a:ListRotationHeaders(0) and not a:GetRotationRecordSnapshot(0, ref('class', 'owned')))
    -- Reset fires its event before the imported roots replace the empty store.
    local old = a:GetScopedRotationCoordinator()

    a.db.profile.rotationStore = {
        version = 1,
        classes = { SHAMAN = { [0] = { imported = { body = body('Imported') } } } },
        characters = {},
        legacy = {},
    }

    assert(not a:ListRotationHeaders(0))
    assert(a:RefreshRotationProfileStorage())

    assert(
        old ~= a:GetScopedRotationCoordinator()
            and a:GetRotationRecordSnapshot(0, ref('class', 'imported')).body.name == 'Imported'
    )

    assert(#activated >= 3)
end)

test('blocked profile migration fails closed and preserves exact malformed and character legacy roots', function()
    local a = fixture({
        profiles = { Shared = { rotations = false } },
        char = { ['A - Realm'] = { rotations = { [0] = { old = {} } } } },
    })

    a.warn = function() end
    local ok, why = a:RefreshRotationProfileStorage()
    assert(not ok and why)
    assert(a.db.profile.rotations == false, 'malformed profile root changed')
    assert(a.db.char.rotations[0].old, 'character archive lost')
    assert(not a:ListRotationHeaders(0), 'blocked profile authorized headers')
end)

test('batched temporary profile transitions cannot publish advice and final disabled profile stays disabled', function()
    local a = fixture()
    assert(a:InitializeScopedRotationStorage())
    local enabled = 0
    a.DisableRotation = function() end

    a.EnableRotation = function()
        enabled = enabled + 1
    end

    a:InstallRotationProfileLifecycle()
    a.rotationProfileChangeDepth = 1
    a.db:SetProfile('Temporary')
    a.db:CopyProfile('Shared')
    a.db:SetProfile('Shared')
    assert(enabled == 0 and a:ListRotationHeaders(0))
    a.rotationProfileChangeDepth = 0
    assert(a:RotationProfileChanged())
    assert(enabled == 1)
    a.db.profile.enable = false
    assert(a:RotationProfileChanged())
    assert(enabled == 1)
end)

test('native profile creation binds the final profile and never enables a temporary import target', function()
    local a, env = fixture()
    assert(a:InitializeScopedRotationStorage())
    a:InstallRotationProfileLifecycle()
    local original = a.db.profile
    local enabled = 0
    a.DisableRotation = function() end

    a.EnableRotation = function()
        assert(a.db.profile == original, 'enabled transient profile')
        enabled = enabled + 1
    end

    a.RefreshConfiguration = function() end
    a.CopySettingsData = function(_, v) return clone(v) end
    a.CollectionFooter = function() end

    local p = {
        creating = true,
        newProfileName = 'Imported target',
        importProfile = {
            rotationFallbackID = 'Fallback',
            rotationStore = {
                version = 1,
                classes = { SHAMAN = { [0] = { imported = { body = body('Imported') } } } },
                characters = {},
                legacy = {},
            },
        },
        fields = {},
    }

    function p:UseRoster() end
    function p:Heading() end
    function p:Text() end
    function p:Edit() end
    function p:Draw() end

    function p:Message(reason)
        error(reason)
    end

    function p:CreationActions(apply)
        self.accept = apply
    end

    local chunk = assert(loadfile('UI/settings_profiles.lua'))
    setfenv(chunk, env)
    chunk('rotationmaster', a)
    a:BuildProfileSettings(p)
    p.accept()
    assert(a.db.profile == original and enabled == 1 and a:ListRotationHeaders(0))
    assert(a.db.sv.profiles['Imported target'].rotationStore.classes.SHAMAN[0].imported.body.name == 'Imported')
    original.enable = false
    p.creating = true
    p.newProfileName = 'Empty target'
    p.importProfile = nil
    a:BuildProfileSettings(p)
    p.accept()
    assert(enabled == 1 and a.db.profile == original)
end)

finish()
