-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Platform/items.lua')
    local a, e = f.addon, f.env
    local queue = {}

    a.ScheduleTimer = function(_, method, _, ...)
        queue[#queue + 1] = { method = method, args = { ... } }
    end

    local function flush()
        local pending = queue
        queue = {}

        for _, job in ipairs(pending) do
            a[job.method](a, unpack(job.args))
        end
    end

    local names = { [1] = 'Water', [2] = 'Bread' }
    e.GetItemInfoInstant = nil
    e.GetItemInfo = nil

    e.C_Item = {
        GetItemInfoInstant = function(item) return item == 'Water' and 1 or item == 'Bread' and 2 end,
        GetItemInfo = function(id) return names[id], 'item:' .. id, nil, nil, nil, nil, nil, nil, nil, 10 + id end,
    }

    local text = {
        SetText = function(self, value)
            self.value = value
        end,
    }

    local icon = {
        frame = {},
        SetText = function(self, value)
            self.value = value
        end,
        SetImage = function(self, value)
            self.image = value
        end,
    }

    e.GameTooltip = { IsOwned = function() return false end }
    return f, text, icon, flush, function() return #queue end
end

test('legacy name display consumers share native picker metadata without requiring a minimum level', function()
    local f, text, icon = fixture()
    local a = f.addon
    a:UpdateItem_Name_ID('Water', text, icon)
    assert(text.value == 'Water' and icon.value == 1)
    a:UpdateItem_Name_Image(2, text, icon)
    assert(text.value == 'Bread' and icon.image == 12)
end)

test('explicit ID display methods preserve identity while image lookup uses native display metadata', function()
    local f, text, icon = fixture()
    local a = f.addon
    a:UpdateItem_ID_ID('Water', text, icon)
    assert(text.value == 1 and icon.value == 1)
    a:UpdateItem_ID_Image(2, text, icon)
    assert(text.value == 2 and icon.image == 12)
end)

test('unloaded display metadata retries and never presents raw numeric IDs as names', function()
    local f, text, icon, flush, pending = fixture()
    local ready = false

    f.env.C_Item.GetItemInfo = function()
        if ready then
            return 'Water', 'item:1', nil, nil, nil, nil, nil, nil, nil, 11
        end
    end

    f.addon:UpdateItem_Name_Image(1, text, icon)
    assert(text.value ~= 1 and text.value ~= '1' and pending() == 1)
    ready = true
    flush()
    assert(text.value == 'Water' and icon.image == 11)
end)

test('failed native metadata clears former labels and cannot revive legacy globals', function()
    local f, text, icon = fixture()
    local a = f.addon
    a:UpdateItem_Name_Image(1, text, icon)

    f.env.GetItemInfo = function()
        error('legacy fallback')
    end

    f.env.C_Item.GetItemInfo = function()
        error('temporary native failure')
    end

    a:UpdateItem_Name_Image(1, text, icon)
    assert(text.value ~= 'Water' and not icon.image)
    a:UpdateItem_Name_Image(nil, text, icon)
    assert(not text.value and not icon.image)
end)

test('old delayed updates cannot overwrite a reused text or icon widget', function()
    local f, text, icon, flush = fixture()
    local a = f.addon
    local ready = false
    local get = f.env.C_Item.GetItemInfo

    f.env.C_Item.GetItemInfo = function(id)
        if id ~= 1 or ready then
            return get(id)
        end
    end

    a:UpdateItem_Name_Image(1, text, icon)
    a:UpdateItem_Name_Image(2, text, icon)
    ready = true
    flush()
    assert(text.value == 'Bread' and icon.image == 12, 'stale timer overwrote the current selection')
    ready = false
    a:UpdateItem_Name_Image(1, text, icon)
    a:UpdateItem_Name_Image(nil, text, icon)
    ready = true
    flush()
    assert(not text.value and not icon.image, 'stale timer undid Clear')
end)

test('restricted malformed or absent item metadata never reaches widget string or texture handling', function()
    local f, text, icon = fixture()
    local secret = {}
    f.env.canaccessvalue = function(value) return value ~= secret end

    for _, record in ipairs({
        { name = secret },
        { name = 'Water', icon = secret },
        { name = 'Water', link = {} },
        { name = false },
        { name = 'Water', icon = math.huge },
    }) do
        f.env.C_Item.GetItemInfo = function()
            return record.name, record.link, nil, nil, nil, nil, nil, nil, nil, record.icon
        end

        f.addon:UpdateItem_Name_Image(1, text, icon)
        assert(text.value ~= 'Water' and text.value ~= secret and not icon.image)
    end
end)

finish()
