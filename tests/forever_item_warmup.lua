-- Actual cold initialization; only external item API capabilities are modeled.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local make = dofile('tests/fixtures/client_baseline.lua')

local function build(mode, case)
    local disk = loadfile
    local observed = { modern = {}, legacy = {}, nativeReads = 0 }

    _G.loadfile = function(path, ...)
        local chunk, why = disk(path, ...)

        if path ~= 'init.lua' or not chunk then
            return chunk, why
        end

        return function(name, a)
            local env = getfenv(1)
            observed.env = env
            observed.a = a
            local opaque = {}
            observed.opaque = opaque
            env.canaccessvalue = function(value) return value ~= opaque end

            env.C_Item = {
                GetItemInfoInstant = function(item)
                    if item == 'Warmup name' then
                        return 201
                    end

                    return item
                end,
            }

            env.GetItemInfo = nil
            env.GetItemInfoInstant = nil

            local function modern(item)
                observed.modern[#observed.modern + 1] = item

                if mode == 'throw' then
                    error('ITEM_METADATA_FAILURE')
                end

                if mode == 'unavailable' then
                    return nil
                end
                if mode == 'restricted' then
                    return opaque
                end
                if mode == 'invalid' then
                    return false
                end

                return 'Item ' .. tostring(item), 'item:' .. tostring(item), nil, nil, nil, nil, nil, nil, nil, 123
            end

            local function legacy(item)
                observed.legacy[#observed.legacy + 1] = item

                if mode == 'legacy-throw' then
                    error('LEGACY_METADATA_FAILURE')
                end

                return 'Item ' .. tostring(item), 'item:' .. tostring(item), nil, nil, nil, nil, nil, nil, nil, 123
            end

            if mode ~= 'missing' and mode ~= 'legacy' and mode ~= 'legacy-throw' then
                env.C_Item.GetItemInfo = modern
            end
            if mode ~= 'missing' and mode ~= 'modern-only' then
                env.GetItemInfo = legacy
            end

            local diagnostics = assert(disk('Diagnostics/errors.lua'))
            setfenv(diagnostics, env)
            diagnostics(name, a)
            setfenv(chunk, env)
            return chunk(name, a)
        end
    end

    local ok, c = pcall(make, case or { 'forever', 18, 12, 'restricted' })
    _G.loadfile = disk
    assert(ok, c)
    return c, observed
end

local function healthy(c, policy)
    local a = c.a
    assert(not a.initializationErrorReport and not a.adviceErrorReport, 'advisory warmup blocked initialization')
    assert(#a.Diagnostics:GetReports() == 0, 'advisory warmup produced startup diagnostic')
    assert(a.Platform:GetClientInfo().combatDataPolicy == (policy or 'restricted') and a.currentRotation == nil)
end

test('modern-only item metadata permits actual Forever cold initialization', function()
    local c, o = build('modern-only')
    healthy(c)
    assert(#o.modern > 0 and #o.legacy == 0)
    assert(c.e.GetItemInfo == nil and c.a.db.global.itemsets and c.a.db.profile.rotationStore)
end)

test('available modern metadata is preferred over the legacy global', function()
    local c, o = build('both')
    healthy(c)
    assert(#o.modern > 0 and #o.legacy == 0, 'warmup bypassed modern capability')
end)

test('modern errors unavailable invalid and restricted metadata are advisory without legacy fallthrough', function()
    for _, mode in ipairs({ 'throw', 'unavailable', 'invalid', 'restricted' }) do
        local c, o = build(mode)
        healthy(c)
        assert(#o.modern > 0 and #o.legacy == 0, mode .. ' fell through to legacy')
    end
end)

-- Forever has no GetItemInfo global at all; only Classic still provides it (behind its
-- default loadDeprecationFallbacks=1), so the legacy route is exercised on Era.
test('missing modern method uses legacy only when absent and legacy failure is advisory', function()
    for _, mode in ipairs({ 'legacy', 'legacy-throw' }) do
        local c, o = build(mode, { 'era', 2, 0, 'probe' })
        healthy(c, 'probe')
        assert(#o.legacy > 0 and #o.modern == 0)
    end
end)

test('missing both metadata APIs never blocks initialization or fabricates facts', function()
    local c, o = build('missing')
    healthy(c)
    assert(#o.modern == 0 and #o.legacy == 0)
    local record, why = c.a.Platform:GetItemDisplayInfo(101)
    assert(record == nil and why == 'missing-api')
end)

local function coldWarmup(a)
    for i = 1, 40 do
        local name, value = debug.getupvalue(a.init, i)

        if not name then
            break
        end

        if name == 'cacheItems' then
            return value
        end
    end

    error('actual private cold warmup not found')
end

test('all four warmup categories keep original arguments and repeated per-item fresh calls', function()
    local c, o = build('modern-only')
    healthy(c)
    local a = c.a
    local warm = coldWarmup(a)
    -- Exercise the supported legacy data walk in addition to both saved set scopes.
    a.InitializeScopedRotationStorage = nil
    a.db.profile.rotationStore = nil

    a.db.profile.rotations = {
        [0] = {
            old = {
                rotation = {
                    {
                        id = 'warmup-item-step',
                        type = 'item',
                        action = { 101, 'Warmup name' },
                        conditions = { type = 'EQUIPPED', item = { 102 } },
                    },
                },
                cooldowns = {},
            },
        },
    }

    a.db.global.itemsets = { global = { items = { 103, 101 } } }
    a.db.profile.itemsets = { profile = { items = { 104 } } }
    local args = {}
    local actual = a.Platform.GetItemDisplayInfo

    a.Platform.GetItemDisplayInfo = function(self, item)
        assert(self == a.Platform)
        args[item] = (args[item] or 0) + 1
        return actual(self, item)
    end

    o.modern = {}
    warm()

    assert(
        args[101] == 2 and args['Warmup name'] == 1 and args[102] == 1 and args[103] == 1 and args[104] == 1,
        'a warmup category or original argument was lost'
    )

    local counts = {}

    for _, item in ipairs(o.modern) do
        counts[item] = (counts[item] or 0) + 1
    end

    assert(
        #o.modern == 6
            and counts[101] == 2
            and counts[201] == 1
            and counts[102] == 1
            and counts[103] == 1
            and counts[104] == 1,
        'warmup deduplicated or retained item facts'
    )

    assert(
        a.db.profile.rotations[0].old.rotation[1].action[2] == 'Warmup name'
            and a.db.global.itemsets.global.items[2] == 101
    )
end)

test('cold warmup observes a replacement metadata provider for each following item', function()
    local c, o = build('modern-only')
    healthy(c)
    local a = c.a
    local warm = coldWarmup(a)
    a.db.global.itemsets = { one = { items = { 101, 101, 101 } } }
    a.db.profile.itemsets = {}
    local first, second = 0, 0

    c.e.C_Item.GetItemInfo = function(item)
        first = first + 1

        c.e.C_Item.GetItemInfo = function(nextItem)
            assert(nextItem == 101)
            second = second + 1
            return nil
        end

        return nil
    end

    warm()
    assert(first == 1 and second == 2, 'cold warmup retained provider or cached duplicate item result')
end)

finish()
