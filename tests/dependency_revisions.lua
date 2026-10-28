-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    a.conditionDefinitions = { KNOWN = { fields = {} } }
    a.db.profile.itemsets = {}
    a.db.global.itemsets = {}
    a.db.global.effects = {}
    return f, a
end

local function notify(a)
    assert(a.InvalidateRotationDependencies, 'managed invalidation API missing')
    assert(a:InvalidateRotationDependencies())
end

local function runtime()
    local h = assert(io.open('tests/rotation_scope_runtime.lua'))
    local text = h:read('*a')
    h:close()

    return assert(loadstring(
        assert(text:match('^(.-)\nlocal function gate')) .. '\nreturn fixture',
        '@dependency-real-runtime'
    ))()()
end

test('explicit actual-owner invalidation advances private stamp and refuses foreign receiver', function()
    local _, a = fixture()
    local s = a:GetRotationValidationStamp()
    notify(a)
    assert(a:GetRotationValidationStamp() ~= s)
    s = a:GetRotationValidationStamp()
    local v, why = a.InvalidateRotationDependencies({})
    assert(v == nil and why == 'foreign-dependency-owner' and a:GetRotationValidationStamp() == s)
end)

test('options stay detached and normalize false shadow markers after explicit raw notifications', function()
    local _, a = fixture()
    local shared = {}
    a.db.global.itemsets = { x = shared }
    a.db.profile.itemsets = { x = false }
    a.db.global.effects.glow = {}
    notify(a)
    local options, s = a:GetRotationValidationOptions()
    assert(options.itemsets.x == false)
    options.effects.glow = nil
    options.conditions.KNOWN = nil
    local nextOptions, nextStamp = a:GetRotationValidationOptions()
    assert(nextOptions ~= options and nextOptions.effects.glow and nextOptions.conditions.KNOWN and nextStamp == s)
    a.db.profile.itemsets.x = nil
    notify(a)
    assert(a:GetRotationValidationOptions().itemsets.x == shared and a:GetRotationValidationStamp() ~= s)
end)

test('live public option iteration cannot retain or poison a cached private projection', function()
    local f, a = fixture()
    notify(a)
    local definition = a.conditionDefinitions.KNOWN
    local captured = {}

    f.env.pairs = function(value)
        if type(value) == 'table' and value ~= a.conditionDefinitions and rawget(value, 'KNOWN') == definition then
            captured[#captured + 1] = value
        end

        return pairs(value)
    end

    local options, before = a:GetRotationValidationOptions()
    assert(options.conditions.KNOWN == definition)

    for _, value in ipairs(captured) do
        value.KNOWN = nil

        setmetatable(value, {
            __index = function()
                error('retained projection getter')
            end,
        })
    end

    options.conditions.KNOWN = nil
    local nextOptions, after = a:GetRotationValidationOptions()
    assert(nextOptions.conditions.KNOWN == definition, 'private normalized projection escaped into live pairs')
    assert(after == before and a.conditionDefinitions.KNOWN == definition, 'option copying changed actual authority')
end)

test('public options retain their entry stamp when a live iterator invalidates reentrantly', function()
    local f, a = fixture()
    notify(a)
    local before = a:GetRotationValidationStamp()
    local changed = false

    f.env.pairs = function(value)
        if value == a.conditionDefinitions and not changed then
            changed = true
            notify(a)
            assert(a:GetRotationValidationStamp() ~= before)
        end

        return pairs(value)
    end

    local options, entry = a:GetRotationValidationOptions()

    assert(
        changed and options.conditions.KNOWN and entry == before,
        'partially built options acquired a newer generation'
    )

    assert(a:GetRotationValidationStamp() ~= entry, 'nested invalidation lost its authority')
end)

test('normal owner stamp reads scan zero entries even with default metatables and large maps', function()
    local f, a = fixture()

    local fallback = setmetatable({}, {
        __index = function()
            error('missing default must not be materialized')
        end,
    })

    a.db.profile.itemsets = fallback

    for i = 1, 500 do
        a.conditionDefinitions['D' .. i] = {}
        a.db.global.effects[i] = {}
        a.db.global.itemsets[i] = {}
    end

    local expected = a:GetRotationValidationStamp()
    local reads = 0
    local pairs0 = pairs

    f.env.pairs = function(value)
        if
            value == a.conditionDefinitions
            or value == a.db.global.effects
            or value == a.db.global.itemsets
            or value == fallback
        then
            reads = reads + 1
        end

        return pairs0(value)
    end

    for i = 1, 40 do
        assert(a:GetRotationValidationStamp() == expected)
    end

    assert(reads == 0, 'unchanged dependency-map walks=' .. reads)
end)

test('raw root changes retire stamps while unannounced in-place writes require explicit notification', function()
    local _, a = fixture()
    local s = a:GetRotationValidationStamp()
    a.db.global.effects.new = {}
    assert(a:GetRotationValidationStamp() == s, 'new contract silently resumed automatic map scans')
    notify(a)
    local nextStamp = a:GetRotationValidationStamp()
    assert(nextStamp ~= s)
    a.db.global.effects = {}
    assert(a:GetRotationValidationStamp() ~= nextStamp)
end)

test('foreign receiver remains isolated legacy observer and cannot reuse owner revision', function()
    local _, a = fixture()
    local own = a:GetRotationValidationStamp()

    local foreign = {
        db = { profile = { itemsets = {} }, global = { itemsets = {}, effects = {} } },
        conditionDefinitions = {},
    }

    local before = a.GetRotationValidationStamp(foreign)
    foreign.db.global.effects.x = {}
    assert(a.GetRotationValidationStamp(foreign) ~= before and a:GetRotationValidationStamp() == own)
end)

test('real AceDB initialized closed runtime reads no dependency map entries across warm polls', function()
    local e, a, events = runtime()
    assert(e.LibStub('AceDB-3.0').db_registry[a.db], 'bundled AceDB registry missing')
    assert(a.InvalidateRotationDependencies, 'managed actual startup service missing')

    local function copy(v)
        if type(v) ~= 'table' then
            return v
        end

        local out = {}

        for k, x in pairs(v) do
            out[k] = copy(x)
        end

        return out
    end

    local defaults = copy(a.db.defaults)
    defaults.profile.itemsets['*'] = { items = {} }
    a.db:RegisterDefaults(defaults)
    assert(getmetatable(a.db.profile.itemsets), 'real AceDB default map metatable missing')

    for i = 1, 3 do
        a:EvaluateNextActionInternal()
    end

    local reads = 0
    local native = e.pairs or pairs

    e.pairs = function(value)
        if
            value == a.conditionDefinitions
            or value == a.db.global.effects
            or value == a.db.global.itemsets
            or value == a.db.profile.itemsets
        then
            reads = reads + 1
        end

        return native(value)
    end

    for i = 1, 25 do
        a:GetRotationValidationStamp()
    end

    assert(reads == 0, 'actual AceDB unchanged stamp walks=' .. reads)
    a:EvaluateNextActionInternal()
    assert(a.currentSpell == 403 and #events > 0)
end)

test('explicit invalidation during actual action evaluation rejects stale staged publication', function()
    local _, a, events, body, _, save = runtime()
    assert(a.InvalidateRotationDependencies, 'managed runtime API missing')
    local changed = false

    a:RegisterCondition('DEPENDENCY_CHANGE', {
        fields = {},
        valid = function() return true end,
        evaluate = function()
            if not changed then
                changed = true
                a.db.global.effects.changed = {}
                notify(a)
            end

            return true
        end,
        print = function() return 'Change' end,
        widget = function() end,
        help = function() end,
    })

    body.rotation[1].conditions = { type = 'DEPENDENCY_CHANGE' }
    save(body)
    a:EvaluateNextActionInternal()
    assert(changed and #events == 0, 'managed callback published stale advice')
end)

test('startup handoff retires retained installer and keeps private epochs monotonic', function()
    local owner = {}
    local chunk = assert(loadfile('Core/dependency_revisions.lua'))
    chunk('test', owner)
    local bind = owner.BindRotationDependencyReader
    local read

    assert(bind(owner, function(value)
        read = value
    end))

    local token, epoch = read(owner)
    assert(type(token) == 'table' and epoch == 0 and read({}) == nil)

    local ok, why = bind(owner, function()
        error('retired binder called callback')
    end)

    assert(ok == nil and why == 'dependency-reader-already-bound')
    assert(owner:InvalidateRotationDependencies('effect', 'x'))
    local changed, nextEpoch = read(owner)
    assert(changed ~= token and nextEpoch > epoch)
end)

test('normalized Shaman real AceAddon and AceDB owner uses managed stamps in both target modes', function()
    local make = dofile('tests/fixtures/rotation_execution.lua')

    for _, target in ipairs({ false, true }) do
        local c = make({ target = target })
        local a, e = c.a, c.e
        assert(getmetatable(a).__tostring and e.LibStub('AceDB-3.0').db_registry[a.db])

        for i = 1, 3 do
            c.tick()
        end

        local before = a.currentSpell
        local nativePairs = e.pairs
        local scans = 0

        e.pairs = function(value)
            if
                value == a.conditionDefinitions
                or value == a.db.global.effects
                or value == a.db.global.itemsets
                or value == a.db.profile.itemsets
            then
                scans = scans + 1
            end

            return nativePairs(value)
        end

        local expected = a:GetRotationValidationStamp()

        for i = 1, 30 do
            assert(a:GetRotationValidationStamp() == expected)
        end

        assert(scans == 0, 'real Shaman managed stamp walked dependency maps')
        e.pairs = nativePairs
        c.tick()
        assert(a.currentSpell == before)
    end
end)

finish()
