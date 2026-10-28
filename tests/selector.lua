local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('UI/window.lua')
    return f
end

test('condition selectors use a native searchable popup and preserve selection on cancellation', function()
    local f = fixture()
    local a = f.addon
    local w = a:CreateConditionDropdown()
    local chosen
    w:SetLabel('Unit')
    w:SetList({ player = 'You', target = 'Your target' }, { 'player', 'target' })
    w:SetValue('player')

    w:SetCallback('OnValueChanged', function(_, _, id)
        chosen = id
    end)

    assert(w.type == 'RM-Selector' and not w.pullout and not w.dropdown)
    w.button:Click()
    assert(w.selector.frame:IsShown())
    w.selector.search:SetText('target')
    w.selector.search.scripts.OnTextChanged()
    assert(w.selector.rows[1]:GetText() == 'Your target')
    w.selector.rows[1]:Click()
    assert(chosen == 'target' and w:GetValue() == 'target')
    w.button:Click()
    w.selector.search.scripts.OnEscapePressed()
    assert(not w.selector.frame:IsShown() and w:GetValue() == 'target')
    w.button:Click()
    local stale = w.selector.rows[1].scripts.OnClick
    w:OnRelease()
    w.userdata = {}
    w:OnAcquire()
    w:SetList({ player = 'You' })
    w:SetValue('player')
    stale()
    assert(w:GetValue() == 'player')
end)

test('all production condition dropdowns use the shared selector', function()
    local names = {
        'character', 'combat', 'common', 'debuffs', 'ext_stats', 'misc', 'spatial_stats', 'stats', 'talent', 'totem'
    }

    for _, name in ipairs(names) do
        local h = assert(io.open('Conditions/' .. name .. '.lua'))
        local text = h:read('*a')
        h:close()
        assert(not text:find('AceGUI:Create("Dropdown")', 1, true), name .. ' still uses the old dropdown')
    end
end)

test('non-inline selectors take search focus while inline suggestions leave it alone', function()
    local f = fixture()
    local a = f.addon
    local anchor = f.env.CreateFrame('EditBox', nil, f.env.UIParent)
    anchor:SetFocus()
    local menu = a:CreateWorkbenchSelector()
    menu:Open(anchor, { { value = 1, text = 'One' } }, nil, function() end, function() return true end)
    assert(menu.search.focused, 'menu did not focus its search')
    menu:Hide()
    menu:Open(anchor, { { value = 1, text = 'One' } }, nil, function() end, function() return true end, true)
    assert(not menu.search.focused and anchor.focused, 'inline suggestions stole reference focus')
end)

test('condition checkboxes use flat native controls with value callbacks and readonly lifecycle guards', function()
    local f = fixture()
    local a = f.addon
    assert(a.CreateConditionCheckBox, 'native checkbox helper missing')
    local w = a:CreateConditionCheckBox()
    local calls = 0
    w:SetLabel('Any spell rank')
    w:SetValue(false)

    w:SetCallback('OnValueChanged', function(_, _, value)
        calls = calls + 1
        assert(value == true)
    end)

    assert(w.type == 'RM-CheckBox')
    w.button:Click()
    assert(w:GetValue() == true and calls == 1)
    w:SetDisabled(true)
    w.button:Click()
    assert(calls == 1)
    w:SetDisabled(false)
    local old = w.button.scripts.OnClick
    w:OnRelease()
    old()
    assert(calls == 1, 'released checkbox fired its callback')
end)

test('aura checkbox options use the shared native checkbox factory', function()
    for _, name in ipairs({ 'buffs', 'debuffs', 'character', 'common', 'item', 'known_spell', 'spatial', 'weapon' }) do
        local h = assert(io.open('Conditions/' .. name .. '.lua'))
        local source = h:read('*a')
        h:close()
        assert(not source:find('AceGUI:Create("CheckBox")', 1, true), name .. ' retains old checkbox controls')
    end
end)

test('selector fits filtered rows spans its anchor and uses contiguous compact entries', function()
    local f = fixture()
    local a = f.addon
    local anchor = f.env.CreateFrame('Button', nil, f.env.UIParent)
    anchor:SetWidth(420)
    local menu = a:CreateWorkbenchSelector()

    menu:Open(anchor, { { value = 1, text = 'One' }, { value = 2, text = 'Two' } }, nil, function() end, function()
        return true
    end)

    assert(menu.frame:GetHeight() < 120 and menu.frame:GetWidth() == 420)

    assert(
        menu.rows[1]:GetWidth() == menu.scroll:GetWidth()
            and menu.rows[1]:GetHeight() == 20
            and menu.rows[2].point[3] == -21
    )

    menu.search:SetText('One')
    menu.search.scripts.OnTextChanged()
    assert(menu.scroll:GetHeight() == 21)
end)

test('clicking an already open dropdown anchor closes it while inline suggestions can refresh', function()
    local f = fixture()
    local a = f.addon
    local anchor = f.env.CreateFrame('Button', nil, f.env.UIParent)
    local menu = a:CreateWorkbenchSelector()
    local values = { { value = 1, text = 'One' } }
    menu:Open(anchor, values, nil, function() end, function() return true end)
    assert(menu.frame:IsShown())
    menu:Open(anchor, values, nil, function() end, function() return true end)
    assert(not menu.frame:IsShown())
    menu:Open(anchor, values, nil, function() end, function() return true end, true)
    menu:Open(anchor, values, nil, function() end, function() return true end, true)
    assert(menu.frame:IsShown())
end)

finish()
