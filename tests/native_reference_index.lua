-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    local s = { mode = 'ready', name = 'Potion', calls = 0 }
    a.bagContents = {}

    a.Platform.GetItemDisplayInfo = function(_, id)
        s.calls = s.calls + 1

        if s.mode ~= 'ready' then
            return nil, s.mode
        end

        return { itemID = id, name = s.name, iconID = 100 + id, link = 'item:' .. id }
    end

    local base = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(not name:find('AceGUI', 1, true), 'native index requested GUI/loader')
        return base(name, ...)
    end

    assert(type(a.UpdateReferenceItem) == 'function', 'native reference event index missing')
    return f, a, s, a:GetReferenceProvider('item')
end

test('metadata indexing uses guarded native records and returns detached presentations', function()
    local _, a, s, p = fixture()
    assert(type(a.UpdateReferenceItem) == 'function', 'native reference event index missing')
    local record = assert(a:UpdateReferenceItem(7))
    assert(record.id == 7 and record.name == 'Potion')
    record.name = 'changed'
    local rows = assert(p.search('Potion'))
    assert(#rows == 1 and rows[1].id == 7 and rows[1].name == 'Potion')
    rows[1].name = 'changed'
    assert(p.search('Potion')[1].name == 'Potion')
    s.name = 'Updated'
    a:UpdateReferenceItem(7)
    assert(#p.search('Potion') == 0 and p.search('Updated')[1].name == 'Updated')
end)

test('unloaded indexed metadata stays searchable without claiming inventory ownership', function()
    local _, a, s, p = fixture()
    a:UpdateReferenceItem(7)
    s.mode = 'item-data-unavailable'
    assert(p.info(7) == nil and p.search('Potion')[1].id == 7)
    assert(#a:GetReferenceProvider('Inventory_EditBox').search('', { inventory = true }) == 0)
    a.bagContents = { [7] = { count = 1 } }
    assert(p.search('Potion', { inventory = true })[1].id == 7)
end)

test('restricted and failed observations suppress old rows and fresh successful queries recover', function()
    for _, reason in ipairs({ 'restricted-value', 'api-error', 'invalid-api-result' }) do
        local _, a, s, p = fixture()
        a:UpdateReferenceItem(7)
        s.mode = reason
        assert(p.info(7) == nil and #p.search('Potion') == 0)
        s.mode = 'ready'
        assert(p.search('Potion')[1].id == 7)
    end
end)

test('metadata index rejects unreadable and malformed IDs before native lookup', function()
    local f, a, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ opaque, {}, false, 0, -1, 1.5, math.huge, 'not an item' }) do
        assert(a:UpdateReferenceItem(bad) == nil)
    end

    assert(a:UpdateReferenceItem(nil) == nil and s.calls == 0)
end)

finish()
