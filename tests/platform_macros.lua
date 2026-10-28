-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local file = io.open('Platform/macros.lua')

    if file then
        file:close()
        f.load('Platform/macros.lua')
    end

    f.env.GetMacroItem = function() return nil, nil end
    f.env.GetMacroSpell = function() return 133 end
    return f, f.addon.Platform
end

test('macro spell actions normalize current IDs and historical name-rank-ID tuples without resolving names', function()
    local f, p = fixture()
    assert(p.GetMacroAction, 'macro adapter missing')

    for _, macro in ipairs({ 1, 'My Macro' }) do
        local a = assert(p:GetMacroAction(macro))
        assert(a.kind == 'spell' and a.spellID == 133 and not a.itemID)
    end

    f.env.GetMacroSpell = function() return 'Localized Fireball', 'Rank 1', 133 end
    local a = assert(p:GetMacroAction(1))
    assert(a.kind == 'spell' and a.spellID == 133)
    a.spellID = 999
    assert(p:GetMacroAction(1).spellID == 133, 'caller changed subsequent observations')
end)

test('macro item actions preserve exact item/use-spell identity and never fall through uncertain item state', function()
    local f, p = fixture()
    assert(p.GetMacroAction, 'macro adapter missing')
    f.env.GetMacroItem = function() return 'Healthstone', 'item:5512' end

    f.env.GetMacroSpell = function()
        error('item macro fell through')
    end

    f.env.C_Item = {
        GetItemInfoInstant = function(value)
            assert(value == 'item:5512')
            return 5512
        end,
        GetItemSpell = function(id)
            assert(id == 5512)
            return 'Use Healthstone', 234
        end,
    }

    local a = assert(p:GetMacroAction(1))
    assert(a.kind == 'item' and a.itemID == 5512 and a.spellID == 234)
    f.env.C_Item.GetItemInfoInstant = function() return nil end
    assert(not p:GetMacroAction(1))
    f.env.GetMacroItem = function() return 'Healthstone', nil end

    f.env.C_Item.GetItemInfoInstant = function(value)
        assert(value == 'Healthstone')
        return 5512
    end

    assert(not p:GetMacroAction(1), 'a name-only macro item guessed an exact identity')
end)

test(
    'missing failed malformed and restricted macro observations remain unavailable and recover on the next read',
    function()
        local f, p = fixture()
        assert(p.GetMacroAction, 'macro adapter missing')
        local secret = {}
        f.env.canaccessvalue = function(value) return value ~= secret end
        local spell = f.env.GetMacroSpell

        for _, tuple in ipairs({
            { secret, nil },
            { nil, secret },
            { false, nil },
            { nil, {} },
            { 'Unloaded', false },
        }) do
            f.env.GetMacroItem = function() return unpack(tuple) end

            f.env.GetMacroSpell = function()
                error('uncertain item observation fell through')
            end

            assert(not p:GetMacroAction(1))
        end

        f.env.GetMacroItem = function()
            error('failed')
        end

        assert(not p:GetMacroAction(1))
        f.env.GetMacroItem = nil
        assert(not p:GetMacroAction(1))
        f.env.GetMacroItem = function() return nil, nil end
        f.env.GetMacroSpell = nil
        assert(not p:GetMacroAction(1))

        for _, tuple in ipairs({
            {},
            { secret },
            { false },
            { -1 },
            { 1.5 },
            { math.huge },
            { 'Fireball' },
            { 'Fireball', secret, 133 },
            { 'Fireball', 'Rank 1', secret },
            { 133, false },
        }) do
            f.env.GetMacroSpell = function() return unpack(tuple) end
            assert(not p:GetMacroAction(1), 'bad spell observation accepted')
        end

        f.env.GetMacroSpell = function()
            error('failed')
        end

        assert(not p:GetMacroAction(1))
        f.env.GetMacroSpell = spell
        assert(p:GetMacroAction(1).spellID == 133)
    end
)

test('macro inputs and restricted-client policy stop queries before touching combat macro APIs', function()
    local f, p = fixture()
    assert(p.GetMacroAction, 'macro adapter missing')

    f.env.GetMacroItem = function()
        error('must not query')
    end

    for _, value in ipairs({ 0, -1, 1.5, math.huge, {}, false, '', string.rep('x', 1025) }) do
        assert(not p:GetMacroAction(value))
    end

    f.env.WOW_PROJECT_ID = 1
    local a, why = p:GetMacroAction(1)
    assert(not a and why == 'unsupported-policy')
    f.env.WOW_PROJECT_ID = 18
    a, why = p:GetMacroAction(1)
    assert(not a and why == 'unsupported-policy')
end)

test('macro item links carry an explicit identity and a resolver cannot substitute another item', function()
    local f, p = fixture()
    local uses = 0
    local observed = 'Healthstone'
    local resolved = 5513
    f.env.GetMacroItem = function() return 'Healthstone', observed end

    f.env.GetMacroSpell = function()
        error('item result fell through')
    end

    f.env.C_Item = {
        GetItemInfoInstant = function() return resolved end,
        GetItemSpell = function()
            uses = uses + 1
            return 'Use', 234
        end,
    }

    for _, link in ipairs({ 'Healthstone', '5512', 'item:0', 'item:-1', 'item:5512oops', '|Hspell:5512|h[Wrong]|h' }) do
        observed = link
        assert(not p:GetMacroAction(1), 'non-item link guessed an identity: ' .. link)
    end

    observed = 'item:5512'
    assert(not p:GetMacroAction(1), 'resolver substituted a different itemID')
    assert(uses == 0)
    resolved = 5512

    for _, link in ipairs({
        'item:5512',
        'item:5512:0:0',
        '|Hitem:5512|h[Healthstone]|h',
        '|cffffffff|Hitem:5512:0:0|h[Healthstone]|h|r',
    }) do
        observed = link
        assert(p:GetMacroAction(1).itemID == 5512)
    end
end)

finish()
