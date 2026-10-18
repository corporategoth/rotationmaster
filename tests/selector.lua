local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua');return f
end
test('condition selectors use a native searchable popup and preserve selection on cancellation',function()
    local f=fixture();local a=f.addon;local w=a:CreateConditionDropdown();local chosen
    w:SetLabel('Unit');w:SetList({player='You',target='Your target'},{'player','target'});w:SetValue('player');w:SetCallback('OnValueChanged',function(_,_,id) chosen=id end)
    assert(w.type=='RM-Selector' and not w.pullout and not w.dropdown)
    w.button:Click();assert(w.selector.frame:IsShown());w.selector.search:SetText('target');w.selector.search.scripts.OnTextChanged();assert(w.selector.rows[1]:GetText()=='Your target')
    w.selector.rows[1]:Click();assert(chosen=='target' and w:GetValue()=='target')
    w.button:Click();w.selector.search.scripts.OnEscapePressed();assert(not w.selector.frame:IsShown() and w:GetValue()=='target')
    w.button:Click();local stale=w.selector.rows[1].scripts.OnClick;w:OnRelease();w.userdata={};w:OnAcquire();w:SetList({player='You'});w:SetValue('player');stale();assert(w:GetValue()=='player')
end)
test('all production condition dropdowns use the shared selector',function()
    local names={'character','combat','common','debuffs','ext_stats','misc','spatial_stats','stats','talent','totem'}
    for _,name in ipairs(names) do local h=assert(io.open('Conditions/'..name..'.lua'));local text=h:read('*a');h:close();assert(not text:find('AceGUI:Create("Dropdown")',1,true),name..' still uses the old dropdown') end
end)
test('non-inline selectors take search focus while inline suggestions leave it alone',function()
    local f=fixture();local a=f.addon;local anchor=f.env.CreateFrame('EditBox',nil,f.env.UIParent);anchor:SetFocus();local menu=a:CreateWorkbenchSelector()
    menu:Open(anchor,{{value=1,text='One'}},nil,function() end,function() return true end);assert(menu.search.focused,'menu did not focus its search');menu:Hide()
    menu:Open(anchor,{{value=1,text='One'}},nil,function() end,function() return true end,true);assert(not menu.search.focused and anchor.focused,'inline suggestions stole reference focus')
end)
finish()
