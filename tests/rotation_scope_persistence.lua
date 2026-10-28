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
        { profile = { rotations = {}, rotationLibrary = {} }, global = { effects = {} }, char = { bindings = {} } },
        'Shared'
    )

    for _, p in ipairs({
        'Platform/client.lua',
        'Data/catalog.lua',
        'Data/diff.lua',
        'Data/rotation_store.lua',
        'Core/rotation_references.lua',
        'Core/rotation_library.lua',
        'Core/rotation_scope.lua',
        'Core/rotation_migration.lua',
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

test(
    'real AceDB keeps explicit fallback and unassigned exact bodies across save reload and shared class profiles',
    function()
        local a, env, scripts = fixture({
            profiles = { Shared = { rotations = { [0] = { Fallback = {}, unknown = body('Unknown') } } } },
            char = { ['B - Realm'] = { rotations = { [0] = { offline = body('Offline') } } } },
        })

        assert(a:InitializeScopedRotationStorage())
        assert(next(a.db.profile.rotationStore.legacy.rotations[0].Fallback) == nil)

        assert(a:ApplyRotationAdoption(assert(a:PlanRotationAdoption({
            kind = 'profile',
            spec = 0,
            id = 'unknown',
        }, 'class'))))

        assert(a:CommitRotationDraft(ref('character', 'same'), nil, { body = body('A character') }, 'character'))
        scripts.OnEvent(nil, 'PLAYER_LOGOUT')
        local saved = clone(env.ScopeDB)
        local b, benv, bscripts = fixture(saved, 'MAGE', 'B')
        assert(b:InitializeScopedRotationStorage())
        local headers = b:ListRotationHeaders(0)

        for _, h in ipairs(headers) do
            assert(h.name ~= 'Unknown' and h.name ~= 'A character' and h.name ~= 'Offline')
        end

        assert(
            b.db.profile.rotationFallbackID == 'Fallback'
                and b.db.profile.rotationStore.classes.SHAMAN[0].unknown.body.name == 'Unknown'
        )

        assert(b:CommitRotationDraft(ref('class', 'same', 'MAGE'), nil, { body = body('Mage Class') }, 'class'))
        bscripts.OnEvent(nil, 'PLAYER_LOGOUT')
        local c = fixture(clone(benv.ScopeDB), 'SHAMAN', 'C')
        assert(c:InitializeScopedRotationStorage())
        local names = {}

        for _, h in ipairs(c:ListRotationHeaders(0)) do
            names[h.name] = true
        end

        assert(names.Unknown and not names['A character'] and not names['Mage Class'])
        c.db:SetProfile('Second')
        assert(not c:ListRotationHeaders(0))
        assert(c:InitializeScopedRotationStorage())
        assert(#c:ListRotationHeaders(0) == 1)
        c.db:SetProfile('Shared')
        assert(c:BindRotationProfile())
        assert(c:GetRotationRecordSnapshot(0, ref('class', 'unknown')).body.name == 'Unknown')
    end
)

finish()
