local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(...)
    local f = F.new(...)
    f.load('Platform/client.lua')
    f.load('Platform/items.lua')
    return f
end

test('modern and legacy item-use metadata returns detached canonical spell records for IDs names and links', function()
    local f = fixture()
    local p = f.addon.Platform

    for _, native in ipairs({ true, false }) do
        local fn = function(item)
            assert(item == 5512 or item == 'Healthstone' or item == 'item:5512')
            return 'Healthstone', 234
        end

        f.env.C_Item = native and { GetItemSpell = fn } or nil
        f.env.GetItemSpell = not native and fn or nil

        for _, item in ipairs({ 5512, 'Healthstone', 'item:5512' }) do
            local info = p:GetItemUseSpell(item)
            assert(info.name == 'Healthstone' and info.spellID == 234)
            info.name = 'edited'
            assert(p:GetItemUseSpell(item).name == 'Healthstone')
        end
    end
end)

test('missing nil malformed secret and throwing metadata remain unavailable without legacy fallback', function()
    local f = fixture()
    local p = f.addon.Platform
    local calls = 0

    f.env.C_Item = {
        GetItemSpell = function()
            calls = calls + 1
            return 'Healthstone', 234
        end,
    }

    for _, item in ipairs({ 0, -1, 1.5, math.huge, {}, false, '', string.rep('x', 1025) }) do
        assert(p:GetItemUseSpell(item) == nil)
    end

    assert(calls == 0)
    local opaque = {}
    f.env.canaccessvalue = function(v) return v ~= opaque end
    assert(p:GetItemUseSpell(opaque) == nil and calls == 0)

    f.env.GetItemSpell = function()
        error('must not fall back from native failure')
    end

    for _, record in ipairs({
        {},
        { 'Healthstone' },
        { '', 234 },
        { 'Healthstone', 0 },
        { 'Healthstone', 1.5 },
        { opaque, 234 },
        { 'Healthstone', opaque },
    }) do
        f.env.C_Item.GetItemSpell = function() return unpack(record) end
        local info, reason = p:GetItemUseSpell(5512)
        assert(info == nil and reason)
    end

    f.env.C_Item.GetItemSpell = function()
        error('native failure')
    end

    local info, reason = p:GetItemUseSpell(5512)
    assert(not info and reason == 'api-error')
    f.env.C_Item = nil
    f.env.GetItemSpell = nil
    info, reason = p:GetItemUseSpell(5512)
    assert(not info and reason == 'missing-api')
end)

test(
    'item identity resolves modern and legacy names and links and refuses unreadable or unavailable results',
    function()
        local f = fixture()
        local p = f.addon.Platform
        assert(p:GetItemID(5512) == 5512)

        for _, native in ipairs({ true, false }) do
            local fn = function(item)
                assert(item == 'Healthstone' or item == 'item:5512')
                return 5512, 'Consumable', 'Other', '', 1, 0, 0
            end

            f.env.C_Item = native and { GetItemInfoInstant = fn } or nil
            f.env.GetItemInfoInstant = not native and fn or nil
            assert(p:GetItemID('Healthstone') == 5512 and p:GetItemID('item:5512') == 5512)
        end

        local opaque = {}
        f.env.canaccessvalue = function(v) return v ~= opaque end
        f.env.C_Item = { GetItemInfoInstant = function() return opaque end }
        assert(p:GetItemID('Healthstone') == nil)
        f.env.C_Item.GetItemInfoInstant = function() return nil end
        assert(p:GetItemID('Healthstone') == nil)

        f.env.C_Item.GetItemInfoInstant = function()
            error('metadata missing')
        end

        local id, reason = p:GetItemID('Healthstone')
        assert(not id and reason == 'api-error')
    end
)

test('item readiness uses carried ownership usability and the item cooldown in modern and legacy clients', function()
    for _, native in ipairs({ true, false }) do
        local f = fixture()
        local p = f.addon.Platform
        local count, usable, power, start, duration, enabled = 1, true, false, 0, 0, 1
        local calls = {}

        local countFn = function(id, bank, uses)
            assert(id == 5512 and bank == false and uses == false)
            return count
        end

        local usableFn = function(id)
            assert(id == 5512)
            return usable, power
        end

        local cooldownFn = function(id)
            assert(id == 5512)
            calls[#calls + 1] = id
            return start, duration, enabled
        end

        f.env.C_Item = native and { GetItemCount = countFn, IsUsableItem = usableFn } or nil
        f.env.C_Container = native and { GetItemCooldown = cooldownFn } or nil
        f.env.GetItemCount = not native and countFn or nil
        f.env.IsUsableItem = not native and usableFn or nil
        f.env.GetItemCooldown = not native and cooldownFn or nil
        assert(p:IsItemReady(5512, 100) == true)
        count = 0
        assert(p:IsItemReady(5512, 100) == false and #calls == 1, 'missing carried item still queried cooldown')
        count = 1
        usable = false
        assert(p:IsItemReady(5512, 100) == false)
        usable = true
        power = true
        assert(p:IsItemReady(5512, 100) == false)
        power = false
        start = 90
        duration = 30
        assert(p:IsItemReady(5512, 100) == false)
        start = 70
        assert(p:IsItemReady(5512, 100) == true)
        enabled = 0
        assert(p:IsItemReady(5512, 100) == false)
    end
end)

test('item readiness never turns nil restricted malformed or throwing values into availability', function()
    local f = fixture()
    local p = f.addon.Platform
    local opaque = {}
    f.env.canaccessvalue = function(value) return value ~= opaque end
    f.env.C_Item = { GetItemCount = function() return 1 end, IsUsableItem = function() return true, false end }
    f.env.C_Container = { GetItemCooldown = function() return 0, 0, 1 end }

    f.env.GetItemCooldown = function()
        error('must not fall back')
    end

    for _, now in ipairs({ -1, math.huge, 0 / 0, '100', opaque }) do
        assert(p:IsItemReady(5512, now) == nil)
    end

    for _, count in ipairs({ -1, 1.5, math.huge, opaque, false }) do
        f.env.C_Item.GetItemCount = function() return count end
        assert(p:IsItemReady(5512, 100) == nil)
    end

    f.env.C_Item.GetItemCount = function() return 1 end

    for _, tuple in ipairs({ {}, { true }, { opaque, false }, { true, opaque } }) do
        f.env.C_Item.IsUsableItem = function() return unpack(tuple) end
        assert(p:IsItemReady(5512, 100) == nil)
    end

    f.env.C_Item.IsUsableItem = function() return true, false end

    for _, tuple in ipairs({
        {},
        { 0, 0 },
        { -1, 5, 1 },
        { 0, -1, 1 },
        { 0, 0, 2 },
        { opaque, 0, 1 },
        { 0, math.huge, 1 },
        { 0, 0, opaque },
    }) do
        f.env.C_Container.GetItemCooldown = function() return unpack(tuple) end
        assert(p:IsItemReady(5512, 100) == nil)
    end

    f.env.C_Container.GetItemCooldown = function()
        error('native failure')
    end

    local ready, reason = p:IsItemReady(5512, 100)
    assert(ready == nil and reason == 'api-error')
    f.env.C_Item.GetItemCount = function() return nil end
    assert(p:IsItemReady(5512, 100) == nil)
end)

test('item range requires a positive observation or an explicit rangeless shape and uses native APIs first', function()
    for _, native in ipairs({ true, false }) do
        local f = fixture()
        local p = f.addon.Platform
        local range = true
        local shape = true

        local hasRange = function(id)
            assert(id == 5512)
            return shape
        end

        local inRange = function(id, unit)
            assert(id == 5512 and unit == 'target')
            return range
        end

        f.env.C_Item = native and { ItemHasRange = hasRange, IsItemInRange = inRange } or nil
        f.env.ItemHasRange = not native and hasRange or nil
        f.env.IsItemInRange = not native and inRange or nil
        assert(p:GetItemRangeState(5512, 'target').inRange)
        range = false
        assert(p:GetItemRangeState(5512, 'target').inRange == false)
        range = nil
        assert(p:GetItemRangeState(5512, 'target') == nil)
        shape = false
        assert(p:GetItemRangeState(5512, 'target').applicable == false)
        shape = nil
        assert(p:GetItemRangeState(5512, 'target') == nil)

        if not native then
            shape = true
            range = 1
            assert(p:GetItemRangeState(5512, 'target').inRange)
            range = 0
            assert(not p:GetItemRangeState(5512, 'target').inRange)
        end
    end

    local f = fixture()
    local p = f.addon.Platform
    local opaque = {}
    f.env.canaccessvalue = function(value) return value ~= opaque end
    f.env.C_Item = { ItemHasRange = function() return true end, IsItemInRange = function() return opaque end }

    f.env.IsItemInRange = function()
        error('legacy fallback')
    end

    assert(p:GetItemRangeState(5512, 'target') == nil)

    f.env.C_Item.IsItemInRange = function()
        error('native failure')
    end

    local state, reason = p:GetItemRangeState(5512, 'target')
    assert(not state and reason == 'api-error')
    f.env.C_Item = nil
    f.env.IsItemInRange = nil
    assert(p:GetItemRangeState(5512, 'target') == nil)
end)

-- C_Item.GetItemCooldown is Retail's and Forever's (tests/fixtures/client_api_*.lua).
test('current Item cooldown namespace supplies canonical boolean records and readiness without old globals', function()
    local f = fixture(1, 12)
    local p = f.addon.Platform
    local enabled = true
    local start, duration = 0, 0

    f.env.C_Item = {
        GetItemCount = function() return 1 end,
        IsUsableItem = function() return true, false end,
        GetItemCooldown = function(id)
            assert(id == 5512)
            return start, duration, enabled
        end,
        GetItemInfoInstant = function() return 5512 end,
    }

    assert(p.GetItemCooldown, 'normalized item cooldown adapter missing')
    local record = assert(p:GetItemCooldown('Healthstone'))
    assert(record.startTime == 0 and record.duration == 0 and record.isEnabled)
    record.startTime = 500
    assert(p:GetItemCooldown(5512).startTime == 0, 'caller mutation changed another cooldown record')
    assert(p:IsItemReady(5512, 100) == true)
    enabled = false
    assert(p:IsItemReady(5512, 100) == false)
    enabled = true
    start = 90
    duration = 30
    assert(p:IsItemReady(5512, 100) == false)
    start = 70
    assert(p:IsItemReady(5512, 100) == true)
end)

-- Precedence across backends no single client has together (Retail's C_Item, Classic's
-- C_Container, an older build's global): an unguarded environment.
test(
    'item cooldown backend precedence and legacy aliases normalize bool or zero-one without failure fallback',
    function()
        local f = fixture(nil, nil, nil, { clientApi = false })
        local p = f.addon.Platform
        local used = {}

        local function backend(name, flag)
            return function()
                used[#used + 1] = name
                return 10, 20, flag
            end
        end

        f.env.C_Item = { GetItemCooldown = backend('item', true) }
        f.env.C_Container = { GetItemCooldown = backend('container', 1) }
        f.env.GetItemCooldown = backend('legacy', 1)
        assert(p:GetItemCooldown(5512).isEnabled and table.concat(used, ',') == 'item')

        f.env.C_Item.GetItemCooldown = function()
            error('Item query failed')
        end

        local record, reason = p:GetItemCooldown(5512)
        assert(not record and reason == 'api-error' and #used == 1, 'native failure fell through')
        f.env.C_Item.GetItemCooldown = nil
        assert(p:GetItemCooldown(5512).isEnabled and used[2] == 'container')
        f.env.C_Container = nil

        for _, flag in ipairs({ true, false, 1, 0 }) do
            f.env.GetItemCooldown = backend('legacy', flag)
            assert(p:GetItemCooldown(5512).isEnabled == (flag == true or flag == 1))
        end

        f.env.GetItemCooldown = nil
        record, reason = p:GetItemCooldown(5512)
        assert(not record and reason == 'missing-api')
    end
)

test(
    'item cooldown invalid observations and identities remain unavailable rather than becoming disabled or ready',
    function()
        local f = fixture()
        local p = f.addon.Platform
        local secret = {}
        f.env.canaccessvalue = function(value) return value ~= secret end
        local calls = 0

        f.env.C_Item = {
            GetItemCooldown = function()
                calls = calls + 1
                return 0, 0, true
            end,
        }

        for _, id in ipairs({ 0, -1, 1.5, math.huge, {}, false, '', secret }) do
            assert(p:GetItemCooldown(id) == nil)
        end

        assert(calls == 0)
        local fallbackCalls = 0

        f.env.C_Container = {
            GetItemCooldown = function()
                fallbackCalls = fallbackCalls + 1
                return 0, 0, 1
            end,
        }

        for _, tuple in ipairs({
            {},
            { 0, 0 },
            { -1, 0, true },
            { 0, -1, true },
            { math.huge, 0, true },
            { 0, math.huge, true },
            { 0 / 0, 0, true },
            { 0, 0, 2 },
            { 0, 0, 'true' },
            { secret, 0, true },
            { 0, secret, true },
            { 0, 0, secret },
        }) do
            f.env.C_Item.GetItemCooldown = function() return unpack(tuple) end
            local record, reason = p:GetItemCooldown(5512)
            assert(not record and reason, 'invalid item cooldown was accepted')
            assert(fallbackCalls == 0, 'invalid or restricted native data triggered a fallback query')
        end
    end
)

test('item metadata ownership and level adapters copy only readable validated public fields', function()
    local f = fixture()
    local p = f.addon.Platform
    local secret = {}
    f.env.canaccessvalue = function(value) return value ~= secret end

    f.env.C_Item = {
        GetItemInfo = function()
            return 'Potion', '|Hitem:10|h[Potion]|h', 1, 1, 5, 'Consumable', 'Potion', 20, '', 123
        end,
        GetItemCount = function(_, bank, uses)
            assert(bank == false and uses == false)
            return 0
        end,
        IsEquippedItem = function() return false end,
    }

    f.env.UnitLevel = function() return 11 end
    local info = assert(p:GetItemMetadata(10))
    assert(info.name == 'Potion' and info.minimumLevel == 5 and info.iconID == 123)
    info.name = 'Modified'
    assert(p:GetItemMetadata(10).name == 'Potion' and p:IsItemLevelAllowed(10))
    assert(p:GetItemCount(10) == 0 and p:IsItemEquipped(10) == false)

    for _, tuple in ipairs({
        {},
        { secret, 'link', 1, 1, 5 },
        { 'Potion', secret, 1, 1, 5 },
        { 'Potion', 'link', 1, 1, secret },
        { 'Potion', 'link', 1, 1, -1 },
        { 'Potion', 'link', 1, 1, 1.5 },
        { 'Potion', 'link', 1, 1, 0, 'a', 'b', 1, '', math.huge },
    }) do
        f.env.C_Item.GetItemInfo = function() return unpack(tuple) end
        assert(p:GetItemMetadata(10) == nil, 'invalid metadata tuple was accepted')
    end

    f.env.C_Item.GetItemCount = function() return secret end
    assert(p:GetItemCount(10) == nil)
    f.env.C_Item.IsEquippedItem = function() return secret end
    assert(p:IsItemEquipped(10) == nil)
end)

test('display metadata needs no gameplay level and selects a callable backend without failure fallback', function()
    local f = fixture()
    local p = f.addon.Platform
    f.env.GetItemInfo = function(id) return 'Water', 'item:' .. id, nil, nil, nil, nil, nil, nil, nil, 11 end
    f.env.GetItemInfoInstant = function() return 1 end
    f.env.C_Item = { GetItemInfo = true, GetItemInfoInstant = true }
    local info = assert(p:GetItemDisplayInfo('Water'))
    assert(info.itemID == 1 and info.name == 'Water' and info.iconID == 11)
    assert(not p:GetItemMetadata(1), 'display-only metadata was accepted for gameplay level decisions')

    f.env.C_Item.GetItemInfo = function()
        error('native failure')
    end

    local record, reason = p:GetItemDisplayInfo(1)
    assert(not record and reason == 'api-error')

    f.env.C_Item.GetItemInfoInstant = function()
        error('native ID failure')
    end

    record, reason = p:GetItemDisplayInfo('Water')
    assert(not record and reason == 'api-error')
end)

finish()
