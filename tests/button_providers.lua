-- Run from repository root: lua5.1 tests/button_providers.lua (and luajit)
-- Button discovery for third-party bar addons, with fake frames shaped like the
-- ones each addon creates. No client is involved: the shapes come from the
-- addons' public source (see the comments in buttons.lua).
local passed, failed = 0, 0

local function test(name, body)
    local ok, err = pcall(body)

    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

-- slotSpell: action slot -> spell ID held there. loaded: addon name -> true.
local function fixture(opts)
    opts = opts or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5, 1, 5
    env.tinsert = table.insert
    local loaded, libs, slotSpell = {}, {}, {}
    env.C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end }
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local stub = { GetLibrary = function(_, name) return libs[name] end }

    if opts.iterate ~= false then
        stub.IterateLibraries = function() return pairs(libs) end
    end

    env.LibStub = setmetatable(stub, {
        __call = function(_, name)
            if name == 'AceLocale-3.0' then
                return { GetLocale = function() return L end }
            end
            if name == 'LibCustomGlow-1.0' then
                return {
                    PixelGlow_Stop = function() end,
                    AutoCastGlow_Stop = function() end,
                    ButtonGlow_Stop = function() end,
                }
            end
            if name == 'AceGUI-3.0' then
                return {}
            end

            error('Unexpected library ' .. name)
        end,
    })

    env.HasAction = function(slot) return slotSpell[slot] ~= nil end
    env.GetActionInfo = function(slot) return 'spell', slotSpell[slot] end
    env.GetSpellInfo = function(id) return 'Spell' .. id, nil, nil, nil, nil, nil, id end
    local addon = { db = { profile = {}, global = { effects = {} } } }
    function addon:debug() end
    function addon:verbose() end
    local presentation = assert(loadfile('Core/presentation.lua'))
    setfenv(presentation, env)
    presentation('rotationmaster', addon)

    for _, path in ipairs({
        'Platform/client.lua',
        'Platform/spells.lua',
        'Platform/items.lua',
        'Platform/macros.lua',
        'Functions/collections.lua',
    }) do
        local load = assert(loadfile(path))
        setfenv(load, env)
        load('rotationmaster', addon)
    end

    local chunk = assert(loadfile('buttons.lua'))
    setfenv(chunk, env)
    chunk('rotationmaster', addon)
    return env, addon, loaded, libs, slotSpell
end

-- A frame that reads like an action button: type and action attributes.
local function button(slot, visible)
    local b = { attrs = { type = 'action', action = slot }, visible = visible ~= false }

    function b:GetAttribute(key)
        return self.attrs[key]
    end

    function b:IsVisible()
        return self.visible
    end

    return b
end

-- The buttons the highlight of one slot reaches.
local function glowed(addon, slot)
    local hit = {}

    addon.Glow = function(_, frame)
        hit[#hit + 1] = frame
    end

    addon:HighlightSlots({ slot })
    return hit
end

local function lib(...)
    local set = {}

    for _, b in ipairs({ ... }) do
        set[b] = true
    end

    return { GetAllButtons = function() return set end }
end

test('EllesmereUI: EABButton frames are indexed and the hidden stock twin is left out', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.EllesmereUIActionBars = true
    slots[1], slots[61] = 133, 134
    local twin = button(1, false)
    env.ActionButton1 = twin
    local twin2 = button(61, false)
    env.MultiBarBottomLeftButton1 = twin2
    local eab1, eab61 = button(1), button(61)
    env.EABButton1, env.EABButton61 = eab1, eab61
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and addon:FindSpell({ 134 }) == 134)
    local hit = glowed(addon, 1)
    assert(#hit == 1 and hit[1] == eab1, 'glow must land on the drawn EllesmereUI button only')
    hit = glowed(addon, 61)
    assert(#hit == 1 and hit[1] == eab61)
end)

test('EllesmereUI: every slot from 1 to 180 is looked up, 181 is not', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.EllesmereUI = true
    slots[180], slots[181] = 133, 134
    env.EABButton180, env.EABButton181 = button(180), button(181)
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and addon:FindSpell({ 134 }) == nil)
end)

test('EllesmereUI: a paged main bar follows its live action attribute', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.EllesmereUIActionBars = true
    slots[73] = 133
    local eab = button(73)
    env.EABButton1 = eab
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and #glowed(addon, 73) == 1)
end)

test('EllesmereUI: the frames are recognized without the addon name when its hidden parent exists', function()
    local env, addon, _, _, slots = fixture()
    slots[1] = 133
    env.EABHiddenParent = {}
    env.EABButton1 = button(1)
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133)
end)

test('EllesmereUI: when its bars are hidden the visible stock button stays indexed', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.EllesmereUIActionBars = true
    slots[1] = 133
    local stock = button(1, true)
    env.ActionButton1 = stock
    env.EABButton1 = button(1, false)
    addon:Fetch()
    local hit = glowed(addon, 1)
    assert(#hit >= 1)
    local seen = false

    for _, b in ipairs(hit) do
        if b == stock then
            seen = true
        end
    end

    assert(seen, 'a visible stock button was dropped for a hidden replacement')
end)

test('hidden stock buttons are kept when no replacement bar draws their slot', function()
    local env, addon, _, _, slots = fixture()
    slots[1] = 133
    local stock = button(1, false)
    env.ActionButton1 = stock
    addon:Fetch()
    local hit = glowed(addon, 1)
    assert(#hit == 1 and hit[1] == stock)
end)

test('LibActionButton: every variant LibStub lists is read, once, and other libraries are not', function()
    local env, addon, _, libs, slots = fixture()
    slots[1], slots[2], slots[3], slots[4] = 133, 134, 135, 136
    local a, b, c, d = button(1), button(2), button(3), button(4)
    libs['LibActionButton-1.0'] = lib(a)
    libs['LibActionButton-1.0-ElvUI'] = lib(b)
    libs['LibActionButton-1.0-Fork'] = lib(c)
    libs['LibActionButton-1.0-Alias'] = libs['LibActionButton-1.0-Fork']
    libs['LibCustomGlow-1.0'] = lib(d)
    local reads = 0
    local original = libs['LibActionButton-1.0-Fork'].GetAllButtons

    libs['LibActionButton-1.0-Fork'].GetAllButtons = function(...)
        reads = reads + 1
        return original(...)
    end

    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and addon:FindSpell({ 134 }) == 134 and addon:FindSpell({ 135 }) == 135)
    assert(addon:FindSpell({ 136 }) == nil, 'a library that is not a LibActionButton variant was read')
    assert(reads == 1, 'one library reached by two names was read twice')
end)

test('LibActionButton: the two historical names still work when LibStub cannot be iterated', function()
    local _, addon, _, libs, slots = fixture({ iterate = false })
    slots[1], slots[2] = 133, 134
    libs['LibActionButton-1.0'] = lib(button(1))
    libs['LibActionButton-1.0-ElvUI'] = lib(button(2))
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and addon:FindSpell({ 134 }) == 134)
end)

test('LibActionButton: a failing variant does not stop the scan', function()
    local _, addon, _, libs, slots = fixture()
    slots[2] = 134

    libs['LibActionButton-1.0-Broken'] = {
        GetAllButtons = function()
            error('boom')
        end,
    }

    libs['LibActionButton-1.0'] = lib(button(2))
    addon:Fetch()
    assert(addon:FindSpell({ 134 }) == 134)
end)

test('Dominos: custom buttons 1-24 and 73-132 are found, not just 1-60', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.Dominos = true
    local want = { [1] = 201, [24] = 202, [73] = 203, [100] = 204, [132] = 205 }

    for slot, spell in pairs(want) do
        slots[slot] = spell
        env['DominosActionButton' .. slot] = button(slot)
    end

    slots[133] = 206
    env.DominosActionButton133 = button(133)  -- not a Dominos custom slot
    addon:Fetch()

    for slot, spell in pairs(want) do
        assert(addon:FindSpell({ spell }) == spell, 'slot ' .. slot)
    end

    assert(addon:FindSpell({ 206 }) == nil)
end)

test('Dominos: the buttons it names after Blizzard bars are found', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.Dominos = true
    slots[25], slots[145] = 207, 208
    env.MultiBarRightActionButton1 = button(25)
    env.MultiBar5ActionButton1 = button(145)
    addon:Fetch()
    assert(addon:FindSpell({ 207 }) == 207 and addon:FindSpell({ 208 }) == 208)
end)

test('Dominos: its public button registry is used, and a failing registry is contained', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.Dominos = true
    slots[40] = 209
    local odd = button(40)
    env.Dominos = { ActionButtons = { GetAll = function() return pairs({ [odd] = 40 }) end } }
    addon:Fetch()
    assert(addon:FindSpell({ 209 }) == 209)

    env.Dominos = {
        ActionButtons = {
            GetAll = function()
                error('registry failed')
            end,
        },
    }

    slots[1] = 210
    env.DominosActionButton1 = button(1)
    addon:Fetch()
    assert(addon:FindSpell({ 210 }) == 210, 'the name scan did not cover a failing registry')
end)

test('AzeriteUI6: pet buttons are mapped; action buttons arrive through the library', function()
    local env, addon, loaded, libs, slots = fixture()
    loaded.AzeriteUI6 = true
    slots[1] = 133
    libs['LibActionButton-1.0'] = lib(button(1))

    env.GetPetActionInfo = function(index)
        if index == 2 then
            return 'Growl', nil, false, nil, nil, nil, 2649
        end
    end

    local pet = { GetID = function() return 2 end, GetAttribute = function() end }
    env.AZUI6_PetActionBarButton2 = pet
    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133)
    assert(addon:FindSpell({ 2649 }) == 2649, 'AzeriteUI6 pet button was not mapped')
end)

test('AzeriteUI6: pet buttons are not read while the addon is not loaded', function()
    local env, addon = fixture()
    env.GetPetActionInfo = function() return 'Growl', nil, false, nil, nil, nil, 2649 end
    env.AZUI6_PetActionBarButton2 = { GetID = function() return 2 end, GetAttribute = function() end }
    addon:Fetch()
    assert(addon:FindSpell({ 2649 }) == nil)
end)

test('retired bar addons are no longer scanned', function()
    local env, addon, loaded, _, slots = fixture()

    for _, name in ipairs({ 'G15Buttons', 'SyncUI', 'DiabolicUI', 'Neuron', 'SamyTotemTimers' }) do
        loaded[name] = true
    end

    slots[1], slots[2], slots[3], slots[4] = 133, 134, 135, 136
    env.objG15_btn_2 = button(1)
    env.EngineBar1Button1 = button(2)
    env.NeuronActionBar1_ActionButton1 = button(3)
    env.SamyTotemTimers1CastTotemButton = button(4)
    env.SyncUI_ActionBar = { Button1 = button(1) }
    addon:Fetch()

    for _, spell in ipairs({ 133, 134, 135, 136 }) do
        assert(addon:FindSpell({ spell }) == nil, spell)
    end
end)

test('RegisterButtonProvider: a provider adds buttons on every scan', function()
    local _, addon, _, _, slots = fixture()
    slots[7], slots[8] = 301, 302
    local scans = 0

    assert(
        addon:RegisterButtonProvider('MyBars', function(add)
            scans = scans + 1
            add(button(7))
            add(button(8))
        end) == true
    )

    addon:Fetch()
    assert(scans == 1 and addon:FindSpell({ 301 }) == 301 and addon:FindSpell({ 302 }) == 302)
    addon:Fetch()
    assert(scans == 2)
    local list = addon:ListButtonProviders()
    assert(#list == 1 and list[1].id == 'MyBars' and list[1].buttons == 2 and list[1].error == nil)
end)

test('RegisterButtonProvider: pet buttons go through the pet route', function()
    local env, addon = fixture()

    env.GetPetActionInfo = function(index)
        if index == 3 then
            return 'Bite', nil, false, nil, nil, nil, 17253
        end
    end

    local pet = { GetID = function() return 3 end, GetAttribute = function() end }

    addon:RegisterButtonProvider('Pets', function(_, addPet)
        addPet(pet, 3)
    end)

    addon:Fetch()
    assert(addon:FindSpell({ 17253 }) == 17253)
end)

test('RegisterButtonProvider: invalid registrations are refused with a reason', function()
    local _, addon = fixture()
    local ok, reason = addon:RegisterButtonProvider('', function() end)
    assert(ok == false and reason == 'invalid-id')
    ok, reason = addon:RegisterButtonProvider(5, function() end)
    assert(ok == false and reason == 'invalid-id')
    ok, reason = addon:RegisterButtonProvider(string.rep('x', 129), function() end)
    assert(ok == false and reason == 'invalid-id')
    ok, reason = addon:RegisterButtonProvider('X', 'nope')
    assert(ok == false and reason == 'invalid-provider')
    assert(#addon:ListButtonProviders() == 0)
end)

test('RegisterButtonProvider: an error is contained, recorded, and does not stop other scans', function()
    local env, addon, loaded, _, slots = fixture()
    loaded.Dominos = true
    slots[1], slots[9] = 133, 303
    env.DominosActionButton1 = button(1)

    addon:RegisterButtonProvider('Bad', function(add)
        add(button(9))
        error('provider broke')
    end)

    addon:RegisterButtonProvider('Good', function(add)
        add(button(9))
    end)

    addon:Fetch()
    assert(addon:FindSpell({ 133 }) == 133 and addon:FindSpell({ 303 }) == 303)
    local list = addon:ListButtonProviders()
    assert(list[1].id == 'Bad' and tostring(list[1].error):find('provider broke', 1, true))
    assert(list[2].id == 'Good' and list[2].error == nil)
end)

test('RegisterButtonProvider: junk buttons are ignored and the per-provider count is bounded', function()
    local _, addon, _, _, slots = fixture()

    for i = 1, 600 do
        slots[i] = 1000 + i
    end

    addon:RegisterButtonProvider('Many', function(add)
        add(nil)
        add('text')
        add({})
        add(42)

        for i = 1, 600 do
            add(button(i))
        end
    end)

    addon:Fetch()
    assert(addon:ListButtonProviders()[1].buttons == 512)
    assert(addon:FindSpell({ 1512 }) == 1512 and addon:FindSpell({ 1513 }) == nil)
end)

test('RegisterButtonProvider: registering again replaces, unregistering removes and rescans', function()
    local _, addon, _, _, slots = fixture()
    slots[1], slots[2] = 133, 134
    local fetches = 0

    addon.ButtonFetch = function()
        fetches = fetches + 1
    end

    addon:RegisterButtonProvider('P', function(add)
        add(button(1))
    end)

    addon:RegisterButtonProvider('P', function(add)
        add(button(2))
    end)

    assert(fetches == 2 and #addon:ListButtonProviders() == 1)
    addon:Fetch()
    assert(addon:FindSpell({ 134 }) == 134 and addon:FindSpell({ 133 }) == nil)
    assert(addon:UnregisterButtonProvider('P') == true and fetches == 3)
    assert(addon:UnregisterButtonProvider('P') == false and fetches == 3)
    addon:Fetch()
    assert(addon:FindSpell({ 134 }) == nil and #addon:ListButtonProviders() == 0)
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
