local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local names={'findConditionGroup','listConditions','describeCondition','widgetCondition'}
local function fixture(baseline)
    local f=F.new();local a=f.addon;f.load('Core/conditions.lua')
    for tag in pairs(a.conditionSpecials) do a.conditionSpecials[tag]=nil end
    a.conditionSpecials.SPECIAL={icon='special-icon',desc='Special',fields={value='condition'}}
    local help=function() end;local fields={amount='number'}
    for tag,description in pairs({A='Alpha',B='Beta',C='Gamma',D='Delta',H='Hidden'}) do a:RegisterCondition(tag,{description=description,icon=tag..'-icon',help=help,fields=fields}) end
    a.db.profile={condition_groups={{id='g',conditions={'B','A','B','UNKNOWN'}},{id='second',conditions={'B','SPECIAL'}}},other_conditions_order={'A','C','A','UNKNOWN'},switch_conditions={'B','UNKNOWN','B'},disabled_conditions={'A','B','C','H'}}
    a.db.global={custom_conditions={C={},A={}}}
    f.load('Core/condition_catalog.lua')
    return f,a
end
local function services(a) for _,name in ipairs(names) do assert(type(a[name])=='function','missing Core catalog service: '..name) end end
local function array(actual,expected) assert(#actual==#expected,'different list length');for i,value in ipairs(expected) do assert(actual[i]==value,'unexpected item at '..i..': '..tostring(actual[i])) end end
local function set(actual,expected) local counts={};for _,value in ipairs(actual) do counts[value]=(counts[value] or 0)+1 end;for _,value in ipairs(expected) do assert(counts[value] and counts[value]>0,'missing '..value);counts[value]=counts[value]-1 end;for _,count in pairs(counts) do assert(count==0,'extra result') end end

test('Core owns all four services without loading a legacy renderer or accessing AceGUI',function()
    local f=F.new();f.load('Core/conditions.lua');local stub=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','Core catalog looked up AceGUI');return stub(name,...) end
    local file=io.open('Core/condition_catalog.lua');assert(file,'Core condition catalog module missing');file:close();f.load('Core/condition_catalog.lua');services(f.addon)
    for _,name in ipairs(names) do assert(debug.getinfo(f.addon[name],'S').source=='@Core/condition_catalog.lua','service is still owned by a renderer') end
    assert(f.addon.EditCondition==nil and f.addon.LayoutConditionFrame==nil,'catalog extraction also installed UI bridges')
    f.addon.db.profile={condition_groups={},switch_conditions={},other_conditions_order={},disabled_conditions={}};f.addon.db.global.custom_conditions={}
    assert(#f.addon:listConditions('ALL')==4 and f.addon:findConditionGroup('missing')=='DEFAULT')
    assert(f.addon:describeCondition('AND') and select('#',f.addon:widgetCondition({},0,{type='missing'}))==0)
end)
test('group and switch queries preserve configured duplicates unknown filtering and special appends',function()
    local _,a=fixture(true);services(a)
    array(a:listConditions('g'),{'B','A','B'});array(a:listConditions('second'),{'B','SPECIAL'})
    array(a:listConditions('SWITCH'),{'B','B','SPECIAL'});array(a:listConditions('unknown'),{})
end)
test('Other and All retain their existing explicit-order hiding and duplicate quirks',function()
    local _,a=fixture(true);services(a)
    array(a:listConditions('DEFAULT'),{'A','C','A','D'})
    local visible=a:listConditions('DEFAULT',true);array({visible[1],visible[2],visible[3]},{'A','C','A'});set({unpack(visible,4)},{'D','H'})
    array(a:listConditions('ALL'),{'A','B','B','B','D','C','SPECIAL'})
    array(a:listConditions('ALL',true),{'A','B','B','B','D','C','H','SPECIAL'})
end)
test('custom queries sort registered descriptions and preserve an orphan registration error',function()
    local _,a=fixture(true);services(a)
    array(a:listConditions('CUSTOM'),{'A','C'});a.db.global.custom_conditions.MISSING={}
    assert(not pcall(a.listConditions,a,'CUSTOM'),'mechanical extraction silently filtered an orphan custom entry')
end)
test('explicit draft stores affect queries without mutating saved preferences',function()
    local _,a=fixture(true);services(a);local saved=a:CopySettingsData(a.db)
    local store={profile={condition_groups={{id='g',conditions={'C'}}},other_conditions_order={'H'},switch_conditions={'A'},disabled_conditions={'C'}},global={custom_conditions={B={}}}}
    local before=a:CopySettingsData(store)
    array(a:listConditions('g',false,store),{'C'});array(a:listConditions('CUSTOM',false,store),{'B'});array(a:listConditions('SWITCH',false,store),{'A','SPECIAL'})
    set(a:listConditions('DEFAULT',false,store),{'A','B','D','H','SPECIAL'})
    assert(a:SettingsDataEqual(a.db,saved) and a:SettingsDataEqual(store,before))
end)
test('group lookup reads current addon profile and retains falsy and default results',function()
    local _,a=fixture(true);services(a)
    assert(a:findConditionGroup(nil)==nil and a:findConditionGroup(false)==nil and a:findConditionGroup('B')=='g' and a:findConditionGroup('unknown')=='DEFAULT')
    local other={db={profile={condition_groups={{id='other',conditions={'B'}}}}}}
    assert(a.findConditionGroup(other,'B')=='g','receiver replaced the original addon closure')
    a.db.profile={condition_groups={{id='replacement',conditions={'B'}}}};assert(a:findConditionGroup('B')=='replacement')
end)
test('registry captures stay live across registration but retain original table identities and pairs',function()
    local f,a=fixture(true);services(a);local definitions,specials=a.conditionDefinitions,a.conditionSpecials
    a:RegisterCondition('LATE',{description='Late',icon='late',fields={}});assert(a:describeCondition('LATE')=='late');a:UnregisterCondition('LATE');assert(a:describeCondition('LATE')==nil)
    a.conditionDefinitions={};a.conditionSpecials={};f.env.pairs=function() error('late replacement of captured pairs') end
    assert(select(2,a:describeCondition('A'))=='Alpha' and select(2,a:describeCondition('SPECIAL'))=='Special')
    array(a:listConditions('g'),{'B','A','B'});a.conditionDefinitions=definitions;a.conditionSpecials=specials
    a.index=function() return true end;array(a:listConditions('SWITCH'),{'B','B'})
end)
test('description lookup preserves exact four-result tuples and zero-result unknowns',function()
    local _,a=fixture(true);services(a);local definition=a.conditionDefinitions.A;local special=a.conditionSpecials.SPECIAL
    local icon,description,help,fields=a:describeCondition('A');assert(icon==definition.icon and description==definition.description and help==definition.help and fields==definition.fields and select('#',a:describeCondition('A'))==4)
    icon,description,help,fields=a:describeCondition('SPECIAL');assert(icon==special.icon and description==special.desc and help=='' and fields==special.fields and select('#',a:describeCondition('SPECIAL'))==4)
    assert(select('#',a:describeCondition(nil))==0 and select('#',a:describeCondition('missing'))==0)
end)
test('widget dispatch preserves arguments no-op cases ignored returns and thrown errors',function()
    local _,a=fixture(true);services(a);local parent={};local value={type='A'};local calls=0
    local definition=a.conditionDefinitions.A;definition.disabled=true;definition.functionUnavailable=true
    definition.widget=function(received,spec,record) assert(received==parent and spec==7 and record==value);calls=calls+1;return 'ignored' end
    assert(select('#',a:widgetCondition(parent,7,value))==0 and calls==1)
    for _,record in ipairs({{}, {type='missing'}, {type='B'}}) do assert(select('#',a:widgetCondition(parent,7,record))==0) end
    assert(select('#',a:widgetCondition(parent,7,nil))==0 and calls==1)
    definition.widget=function() error('dispatch sentinel') end
    local ok,why=pcall(a.widgetCondition,a,parent,7,value);assert(not ok and tostring(why):find('dispatch sentinel',1,true))
end)
test('dispatch rejects foreign widgets before changing native ownership or the foreign frame',function()
    local f,a=fixture(true);services(a);local parent=a:CreateConditionGroup();local called=0
    local foreign={frame={SetParent=function() error('foreign frame reparented') end,Hide=function() error('foreign frame hidden') end},parent={marker=true}}
    local originalParent=foreign.parent
    a.conditionDefinitions.A.widget=function(container) called=called+1;container:AddChild(foreign) end
    local ok,why=pcall(a.widgetCondition,a,parent,0,{type='A'})
    assert(not ok and tostring(why):find('foreign-or-inactive-condition-child',1,true) and called==1)
    assert(#parent.children==0 and foreign.parent==originalParent and foreign.parent.marker and parent.rmActive)
    a:ReleaseConditionWidget(parent)
end)
finish()
