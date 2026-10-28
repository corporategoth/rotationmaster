-- The desired-stock feature is retired. A saved profile stockTargets map from
-- it must stay inert: never read, never stripped, never a reason to refuse a
-- profile copy, import, export or repair.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function row(item)
    return { itemID = item or 1710, minimum = 5, target = 12, enabled = true }
end

local function fixture()
    local f = F.new()
    f.load('Data/plain.lua')
    f.load('Data/tags.lua')
    f.load('Data/rotation_tree.lua')
    f.load('Data/validation.lua')
    return f, f.addon
end

test('no stock code or settings page remains', function()
    local f, a = fixture()

    assert(
        a.StockTargets == nil
            and a.StockSettings == nil
            and a.BuildStockSettings == nil
            and a.ItemSettingsSourceOptions == nil,
        'stock code is still loaded'
    )

    for _, path in ipairs({ 'Core/stock_targets.lua', 'UI/stock_profile_safety.lua', 'UI/settings_stock.lua' }) do
        assert(io.open(path) == nil, path .. ' still exists')
    end

    local toc = assert(io.open('RotationMaster.toc')):read('*a')
    assert(not toc:lower():find('stock', 1, true), 'TOC still lists stock files')
end)

test('saved stock targets roundtrip unread through profile transfer', function()
    local _, a = fixture()
    local plan = { a = row(), b = row(1711) }
    local p = { version = 3, poll = .15, stockTargets = plan }
    assert(a:ValidateProfileTransfer(p))
    local wire = assert(a:ProfileToPortable(p))
    local copy = assert(a:ProfileFromPortable(wire))
    assert(a:ValidateProfileTransfer(copy))

    assert(
        wire.stockTargets ~= plan and copy.stockTargets.a.itemID == 1710 and copy.stockTargets.b.target == 12,
        'stock data was stripped or changed'
    )

    local q = { version = 3 }

    assert(
        a:ValidateProfileTransfer(q)
            and assert(a:ProfileFromPortable(assert(a:ProfileToPortable(q)))).stockTargets == nil,
        'a stock field was synthesized'
    )
end)

test('maintenance keeps an existing stock map by identity while repairing other fields', function()
    local f, a = fixture()
    f.load('validate.lua')
    local warnings = {}

    a.warn = function(_, message, ...)
        warnings[#warnings + 1] = string.format(message, ...)
    end

    local template = {
        global = {},
        char = { bindings = {} },
        profile = { version = 3, itemsets = {}, announces = {}, rotations = {}, condition_groups = {} },
    }

    local plan = { a = row() }
    local p = { version = 3, stockTargets = plan, unrelatedExtra = 'repair this' }
    local db = { global = {}, char = {}, profiles = { Default = p } }
    f.env.RetiredStockDB = db
    a.savedVariableName = 'RetiredStockDB'
    a:validate(template, true)

    assert(
        p.stockTargets == plan and plan.a.target == 12 and p.unrelatedExtra == nil,
        'maintenance erased or rewrote saved stock data'
    )

    for _, warning in ipairs(warnings) do
        assert(not warning:lower():find('stock', 1, true), 'maintenance still inspects stock: ' .. warning)
    end

    assert(template.profile.stockTargets == nil)
end)

finish()
