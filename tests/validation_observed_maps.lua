-- Exercise maps retained through the supported live pairs override, without
-- debug/upvalue access to RM's private observations.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local source = read('tests/rotation_validation_adjacent.lua')

local fixture, current = assert(loadstring(
    assert(source:match('^(.-)\ntest%(')) .. '\nreturn fixture,current',
    '@observed-map-runtime'
))()

local function retain(e, a, kind)
    local sourceMap = kind == 'conditions' and a.conditionDefinitions
        or kind == 'effects' and a.db.global.effects
        or a.db.global.itemsets

    local key, value = next(sourceMap)

    if not key then
        key = 'RETAINED'
        value = {}
        sourceMap[key] = value
    end

    -- Refresh before temporarily replacing pairs; retain only the normalized map
    -- passed to public detached-copy construction, then restore the primitive.
    a:GetRotationValidationOptions()
    local original = e.pairs
    local leaked

    e.pairs = function(t)
        if t ~= sourceMap and rawget(t, key) == value then
            leaked = t
        end

        return original(t)
    end

    local options = a:GetRotationValidationOptions()
    e.pairs = original
    assert(leaked and leaked ~= sourceMap and leaked ~= options[kind], 'private normalized map was not retained')
    return leaked, key, value
end

for _, kind in ipairs({ 'conditions', 'effects' }) do
    test('retained ' .. kind .. ' getter cannot hide a late itemset mutation', function()
        local e, a = fixture()
        local p = assert(a:AcquireRotationRuntimePass(0))
        local leaked, key, value = retain(e, a, kind)
        leaked[key] = nil
        local reads = 0

        setmetatable(leaked, {
            __index = function(_, name)
                reads = reads + 1
                a.db.global.itemsets.changedDuringLookup = { items = { 10 } }
                return name == key and value or nil
            end,
        })

        local ok, why = p:IsCurrent()
        assert(not ok and why == 'rotation-dependencies-changed', tostring(ok) .. '/' .. tostring(why))
        assert(reads == 1, 'native fallback getter count changed')
    end)
end

for _, kind in ipairs({ 'itemsets', 'conditions', 'effects' }) do
    for _, shape in ipairs({ 'plain-meta', 'opaque-meta' }) do
        test('retained ' .. kind .. ' ' .. shape .. ' keeps both fresh stamp reads', function()
            local e, a = fixture()
            local leaked = retain(e, a, kind)
            local p = assert(a:AcquireRotationRuntimePass(0))
            local meta = {}

            if shape == 'opaque-meta' then
                meta.__metatable = 'opaque'
            end

            setmetatable(leaked, meta)
            current(a, p, 2)
        end)
    end
end

test('unchanged normalized maps retain adjacent reuse and detached public options', function()
    local e, a = fixture()
    local one = a:GetRotationValidationOptions()
    local p = assert(a:AcquireRotationRuntimePass(0))
    current(a, p, 1)
    one.conditions.INJECTED = {}
    current(a, p, 1)
    local two = a:GetRotationValidationOptions()
    assert(two ~= one and two.conditions ~= one.conditions and not two.conditions.INJECTED)
end)

test('shared definition payload identities do not disable adjacent reuse', function()
    local _, a = fixture()
    local shared = { fields = {} }
    a.conditionDefinitions.ONE = shared
    a.conditionDefinitions.TWO = shared
    local p = assert(a:AcquireRotationRuntimePass(0))
    current(a, p, 1)
end)

test('retained map throwing getter preserves the exact fresh-path error object', function()
    local e, a = fixture()
    local p = assert(a:AcquireRotationRuntimePass(0))
    local leaked, key = retain(e, a, 'conditions')
    leaked[key] = nil
    local marker = {}
    local reads = 0

    setmetatable(leaked, {
        __index = function()
            reads = reads + 1
            error(marker)
        end,
    })

    local ok, why = pcall(p.IsCurrent, p)
    assert(not ok and why == marker and reads == 1)
end)

finish()
