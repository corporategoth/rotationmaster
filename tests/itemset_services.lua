local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local names = { 'ItemSetInUse', 'UpdateItemSetButtons', 'get_item_list', 'item_list_popup' }

local function fixture(baseline)
    local f = F.new()
    local a = f.addon
    local create = f.env.CreateFrame
    local frames = {}

    f.env.CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        frame.attributes = {}
        frame.attributeWrites = {}

        function frame:GetName()
            return self.name
        end

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
            self.attributeWrites[key] = (self.attributeWrites[key] or 0) + 1
        end

        function frame:GetAttribute(key)
            return self.attributes[key]
        end

        if name then
            f.env[name] = frame
        end

        frames[#frames + 1] = frame
        return frame
    end

    a.units = { player = 'Player', target = 'Target' }
    a.itemSetButtons = {}
    a.db.char = { bindings = {} }
    a.db.profile = { itemsets = {}, rotations = {} }
    a.db.global = { itemsets = {} }
    local file = io.open('Core/itemset_services.lua')

    if file then
        file:close()
        f.load('Core/itemset_services.lua')
    elseif baseline then
        f.load('Options/itemset.lua')
    end

    return f, a, frames
end

local function services(a)
    for _, name in ipairs(names) do
        assert(type(a[name]) == 'function', 'missing Core ItemSet service: ' .. name)
    end
end

local function array(actual, expected)
    assert(#actual == #expected, 'different list length')

    for i, value in ipairs(expected) do
        assert(actual[i] == value, 'unexpected item at ' .. i)
    end
end

local function rotations(a, body)
    a.db.profile.rotations = { [0] = { rotation = body } }
end

test('Core owns ItemSet services without the old renderer or any library lookup', function()
    local f = F.new()

    f.env.LibStub = function()
        error('Core ItemSet service looked up a library')
    end

    local file = io.open('Core/itemset_services.lua')
    assert(file, 'Core ItemSet services module missing')
    file:close()
    f.load('Core/itemset_services.lua')
    services(f.addon)

    for _, name in ipairs(names) do
        assert(
            debug.getinfo(f.addon[name], 'S').source == '@Core/itemset_services.lua',
            'service is still owned by old options'
        )
    end

    assert(f.addon.create_itemset_list == nil and f.addon.bind_popup == nil, 'service extraction also installed old UI')
    f.addon.db.char = { bindings = {} }
    f.addon.db.profile = { rotations = {}, itemsets = {} }
    f.addon.db.global = { itemsets = {} }
    assert(not f.addon:ItemSetInUse('missing'))
    local selects, sorted = f.addon:get_item_list(false)
    assert(selects[''] == false and sorted[1] == '')
end)

test('item list query retains profile ordering global coloring collision duplicates and two results', function()
    local f, a = fixture(true)
    services(a)

    a.db.profile.itemsets = {
        a = { name = 'Alpha' },
        b = { name = 'Beta' },
        same = { name = 'Z profile' },
        ignored = false,
        unnamed = { name = false },
    }

    a.db.global.itemsets = { g = { name = 'Zulu' }, same = { name = 'A global' } }
    local selects, sorted = a:get_item_list('Custom')
    array(sorted, { 'a', 'b', 'same', 'same', 'g', '' })

    assert(
        selects.a == 'Alpha'
            and selects.ignored == nil
            and selects.unnamed == nil
            and selects.same == f.env.color.CYAN .. 'A global' .. f.env.color.RESET
            and selects[''] == 'Custom'
    )

    assert(select('#', a:get_item_list()) == 2)
    selects, sorted = a:get_item_list(false)
    assert(selects[''] == false and sorted[#sorted] == '')
    selects, sorted = a:get_item_list(nil)
    assert(selects[''] == nil and sorted[#sorted] == '')
end)

test('item query preserves current receiver data original color capture and malformed-global failures', function()
    local f, a = fixture(true)
    services(a)
    local colors = f.env.color
    f.env.color = { CYAN = 'replacement', RESET = 'replacement' }

    local other = {
        db = {
            profile = { itemsets = { p = { name = 'Private' } } },
            global = { itemsets = { g = { name = 'Global' } } },
        },
    }

    local selects, sorted = a.get_item_list(other, 'Empty')
    array(sorted, { 'p', 'g', '' })
    assert(selects.g == colors.CYAN .. 'Global' .. colors.RESET)
    colors.CYAN = 'changed captured cyan'
    selects = a.get_item_list(other)
    assert(selects.g == 'changed captured cyanGlobal' .. colors.RESET)
    a.db.global.itemsets.bad = false
    assert(not pcall(a.get_item_list, a), 'mechanical extraction silently filtered malformed global records')
end)

test('ItemSetInUse retains false bindings direct actions and nested recognized predicates', function()
    local _, a = fixture(true)
    services(a)
    a.db.char.bindings.set = false
    assert(a:ItemSetInUse('set'))
    a.db.char.bindings.set = nil
    rotations(a, { cooldowns = { { type = 'item', action = 'set' } } })
    assert(a:ItemSetInUse('set'))
    rotations(a, { rotation = { { type = 'item', action = 'set' } } })
    assert(a:ItemSetInUse('set'))

    for _, tag in ipairs({ 'EQUIPPED', 'CARRYING', 'ITEM', 'ITEM_RANGE', 'ITEM_COOLDOWN' }) do
        rotations(a, {
            rotation = {
                {
                    conditions = {
                        type = 'NOT',
                        value = { type = 'AND', value = { { type = 'OR', value = { { type = tag, item = 'set' } } } } },
                    },
                },
            },
        })

        assert(a:ItemSetInUse('set'), tag)
    end

    rotations(a, { cooldowns = { { conditions = { type = 'ITEM', item = 'set' } } } })
    assert(a:ItemSetInUse('set'))
end)

test('ItemSetInUse keeps existing switch branch custom-list and malformed-group quirks', function()
    local _, a = fixture(true)
    services(a)

    for _, body in ipairs({
        { switch = { type = 'ITEM', item = 'set' } },
        {
            rotation = {
                {
                    type = 'branch',
                    yes = { { type = 'item', action = 'set' } },
                    no = { { conditions = { type = 'ITEM', item = 'set' } } },
                },
            },
        },
        { rotation = { { type = 'item', action = { 'set' } } } },
        { rotation = { { conditions = { type = 'ITEM_STACKS', item = 'set' } } } },
        { rotation = { { conditions = { type = 'ITEM', item = 5 } } } },
    }) do
        rotations(a, body)
        assert(not a:ItemSetInUse('set'))
    end

    rotations(a, { rotation = { { conditions = { type = 'AND' } } } })
    assert(not pcall(a.ItemSetInUse, a, 'set'), 'malformed group behavior changed')
end)

test('secure macro buttons create hidden exact attributes and reuse their identities on update', function()
    local f, a, frames = fixture(true)
    services(a)
    a.db.profile.itemsets.s = { name = 'Heal_Potion! v2', items = { 101, 202 } }
    assert(select('#', a:UpdateItemSetButtons('s')) == 0 and #frames == 2)
    local player, target = a.itemSetButtons.s.player, a.itemSetButtons.s.target

    assert(
        player.template == 'SecureActionButtonTemplate'
            and player:GetName() == 'RM_HealPotionv2_player'
            and player:GetParent() == f.env.UIParent
            and not player:IsShown()
    )

    assert(
        player:GetAttribute('type') == 'macro'
            and player:GetAttribute('macrotext') == '/use [@player] item:101\n/use [@player] item:202\n'
    )

    assert(
        target:GetAttribute('macrotext') == '/use [@target] item:101\n/use [@target] item:202\n'
            and f.env[player:GetName()] == player
    )

    a.db.profile.itemsets.s.items = { 303 }
    a:UpdateItemSetButtons('s')

    assert(
        #frames == 2
            and a.itemSetButtons.s.player == player
            and a.itemSetButtons.s.target == target
            and player.attributeWrites.type == 1
            and player:GetAttribute('macrotext') == '/use [@player] item:303\n'
    )
end)

test('secure macro name replacement and missing-set removal detach frames and clear globals', function()
    local f, a, frames = fixture(true)
    services(a)
    a.db.profile.itemsets.s = { name = 'Old', items = { 1 } }
    a:UpdateItemSetButtons('s')
    local old = a.itemSetButtons.s.player
    a.db.profile.itemsets.s.name = 'New'
    a:UpdateItemSetButtons('s')
    local replacement = a.itemSetButtons.s.player

    assert(
        #frames == 4
            and replacement ~= old
            and old:GetParent() == nil
            and f.env[old:GetName()] == nil
            and f.env[replacement:GetName()] == replacement
    )

    a.db.profile.itemsets.s = nil
    a:UpdateItemSetButtons('s')
    assert(a.itemSetButtons.s == nil and replacement:GetParent() == nil and f.env[replacement:GetName()] == nil)
    a:UpdateItemSetButtons('missing')
    assert(#frames == 4)
end)

test('profile precedence false overrides captured units and captured frame factory stay unchanged', function()
    local f, a, frames = fixture(true)
    services(a)
    local units = a.units
    local parent = f.env.UIParent

    f.env.CreateFrame = function()
        error('late replacement of captured CreateFrame')
    end

    f.env.UIParent = {}
    a.units = { focus = 'Replacement table' }
    a.db.global.itemsets.s = { name = 'Global', items = { 1 } }
    a.db.profile.itemsets.s = { name = 'Profile', items = { 2 } }
    a:UpdateItemSetButtons('s')

    assert(
        #frames == 2
            and a.itemSetButtons.s.player:GetName() == 'RM_Profile_player'
            and a.itemSetButtons.s.player:GetParent() == parent
            and a.itemSetButtons.s.focus == nil
    )

    units.focus = 'Focus'
    units.target = nil
    a:UpdateItemSetButtons('s')

    assert(
        #frames == 3 and a.itemSetButtons.s.focus and a.itemSetButtons.s.target,
        'old units-removal behavior changed'
    )

    a.db.profile.itemsets.s = false
    a:UpdateItemSetButtons('s')
    assert(a.itemSetButtons.s == nil, 'false profile record unexpectedly fell through to global')
end)

test(
    'native popup forwarding preserves all seven positional arguments live receiver dispatch and return tuple',
    function()
        local _, a = fixture(true)
        services(a)
        local items = { 1 }
        local valid = function() end
        local update = function() end
        local close = function() end
        local options = { valid = function() return true end }
        local marker = {}

        a.OpenItemListPopup = function(self, name, kind, received, validator, changed, onclose, settings)
            assert(
                self == a
                    and name == 'Selected'
                    and kind == 'Inventory_EditBox'
                    and received == items
                    and validator == valid
                    and changed == update
                    and onclose == close
                    and settings == options
            )

            return marker, nil, 'tail'
        end

        local first, second, third = a:item_list_popup(
            'Selected',
            'Inventory_EditBox',
            items,
            valid,
            update,
            close,
            options
        )

        assert(first == marker and second == nil and third == 'tail')

        a.OpenItemListPopup = function(_, _, _, _, _, _, _, settings)
            assert(settings == nil)
            return 'six'
        end

        assert(a:item_list_popup('Selected', 'Item_EditBox', items, valid, update, close) == 'six')

        local other = {
            OpenItemListPopup = function(self)
                assert(self ~= a)
                return 'other receiver'
            end,
        }

        assert(a.item_list_popup(other) == 'other receiver')
    end
)

finish()
