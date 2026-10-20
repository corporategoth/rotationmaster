local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired,added=dofile('tests/fixtures/restore_item_summary_literals.lua')
local modulePath='Conditions/item.lua'
local key='the number of {item} you are carrying {comparison} {quantity}'
local name='Potions {{!READY|SPENT}} 50% {item}'
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture(native)
    local f=F.new();local a,e=f.addon,f.env
    a.db.profile.itemsets={personal={name='Personal',items={10,11}},collision=false};a.db.global.itemsets={global={name='Global',items={11}},collision={name='Ignored',items={11}}};a.combatCache={};a.bagContents={}
    local state={count={[10]=2,[11]=5},equipped={},start=0,duration=0,enabled=true,range=true,minimum=1,metadata=true,calls={}}
    local function call(name) state.calls[name]=(state.calls[name] or 0)+1;if state.throw==name then error('native '..name..' failed') end end
    local api={GetItemInfoInstant=function(value) return value=='Potion' and 10 or tonumber(value) end,
        GetItemInfo=function(id) call('metadata');if state.metadata then return 'Potion '..id,'|Hitem:'..id..'|h[Potion '..id..']|h',1,1,state.minimum,'Consumable','Potion',20,'',123 end end,
        GetItemCount=function(id) call('count');return (state.count[id] or 0)+(state.equipped[id] and 1 or 0) end,
        IsEquippedItem=function(id) call('equipped');return state.equipped[id]==true end,
        GetItemCooldown=function() call('cooldown');if native then return state.start,state.duration,state.enabled end;return state.start,state.duration,state.enabled and 1 or 0 end,
        ItemHasRange=function() return true end,
        IsItemInRange=function() call('range');if native or state.range==nil then return state.range end;return state.range and 1 or 0 end}
    if native then e.C_Item=api else for name,callback in pairs(api) do e[name]=callback end end
    local function slots(bag) call('slots');return bag==0 and 2 or 0 end
    local function entry(_,slot)
        call('bag');local id=slot==1 and 10 or 11;local count=state.count[id] or 0;if count==0 then return end
        if native then return {itemID=id,stackCount=count} end
        return 123,count,false,1,false,false,'item:'..id,false,false,id
    end
    e.NUM_BAG_SLOTS=4
    if native then e.C_Container={GetContainerNumSlots=slots,GetContainerItemInfo=entry} else e.GetContainerNumSlots=slots;e.GetContainerItemInfo=entry end
    e.UnitLevel=function() return 20 end
    e.C_Spell={GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    for _,path in ipairs({'Platform/spells.lua','Platform/items.lua','Platform/inventory.lua','Diagnostics/errors.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Core/conditions.lua','Core/item_sets.lua','Core/itemset_services.lua','Conditions/common.lua',modulePath,'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state,api
end

local function node(tag,item) return {type=tag or 'CARRYING',item=item or 'personal',operator='EQUALS',value=2} end
local function known(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid test fields')
 assert(a:evaluateConditionResult(v).status=='match' and a:evaluateConditionResult({type='NOT',value=v}).status=='no-match')
 local selected;local body={rotation={{id='gate',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 assert(a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end).status=='complete' and selected=='yes')
end
local function literal(a,v,text)
 local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7)
 assert(positive:find(text,1,true),'positive summary changed literal: '..positive)
 assert(negative:find(text,1,true),'negative summary changed literal: '..negative)
 assert(a:printCondition({type='NOT',value={type='NOT',value=v}},7)==positive)
 return positive,negative
end
local function mount(a,value,definition)
 definition=definition or a.conditionDefinitions.CARRYING
 local parent=a:CreateConditionGroup();parent:SetWidth(640);local owner={values={root=value}};local state={statuses=0}
 local funcs={print=function(_,root,spec) assert(root==value and spec==7);return a:printCondition(root,spec) end};owner.values.funcs=funcs
 function owner:GetUserData(key) return self.values[key] end
 function owner:SetUserData(key,data) self.values[key]=data end
 function owner:SetStatusText(text) state.statuses=state.statuses+1;state.status=text end
 parent:SetUserData('top',owner);definition.widget(parent,7,value);a:configure_frame(parent);parent:DoLayout()
 return parent,parent.children[2].children[2],state
end

test('accepted literal item-set name preserves actual bag count and both positive and negative summary meaning',function()
 for _,native in ipairs({false,true}) do local _,a=fixture(native);a.db.profile.itemsets.personal.name=name
  assert(a:ValidateProfileTransfer({version=3,itemsets={personal={name=name,items={10,11}}}}))
  local v=node();known(a,v);local positive,negative=literal(a,v,name)
  assert(positive:find('is equal to 2',1,true) and negative:find('is not equal to 2',1,true),'outer comparison was not negated')
  local group={type='AND',value={v,{type='OR',value={v,{type='NOT',value=v}}}}};assert(a:evaluateConditionResult(group).status=='match')
  local combined=a:printCondition(group,7);assert(combined:find(name,1,true))
 end
end)
test('personal and global names treat primary and secondary markers braces percent links and color codes as literal data',function()
 for _,native in ipairs({false,true}) do local _,a=fixture(native)
  for _,data in ipairs({name,'{{yes|no}} {{!one|two}}','{comparison} {quantity} 100%','|Hitem:10|h[{{!Hot|Cold}}]|h','|cff123456Tint {{!A|B}}|r'}) do
   for _,id in ipairs({'personal','global'}) do local set=id=='personal' and a.db.profile.itemsets[id] or a.db.global.itemsets[id];set.name=data;local v=node(nil,id);literal(a,v,data);assert(set.name==data) end
  end
 end
end)
test('every operator preserves live positive negative and double negative comparison authority',function()
 local _,a=fixture(true);a.db.profile.itemsets.personal.name=name
 for _,op in ipairs({'LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','EQUALS','NOTEQUALS','DIVISIBLE'}) do
  local v=node();v.operator=op;assert(a.conditionDefinitions.CARRYING.valid(0,v));a.operators[op]='POS_'..op;a.negatedOperators[op]='NEG_'..op
  local positive,negative=literal(a,v,name);assert(positive:find('POS_'..op,1,true) and negative:find('NEG_'..op,1,true))
 end
end)
test('locale reorders named slots without recursively parsing inserted user data',function()
 local f,a=fixture(true);a.db.profile.itemsets.personal.name=name;f.translations[key]='{quantity} units :: {comparison} :: {item} :: 50%'
 local positive,negative=literal(a,node(),name)
 assert(positive:find('2 units :: is equal to :: ',1,true) and negative:find('2 units :: is not equal to :: ',1,true) and positive:sub(-3)=='50%')
end)
test('ordinary names first-item lists metadata fallback and empty field placeholders retain descriptor semantics',function()
 for _,native in ipairs({false,true}) do
  local _,a=fixture(native);local v=node();assert(a:printCondition(v,7)=='the number of a |cFFFFFFFFPersonal|r item set item you are carrying is equal to 2')
  v.item={10};literal(a,v,'|Hitem:10|h[Potion 10]|h');v.item={10,11};literal(a,v,'|Hitem:10|h[Potion 10]|h or 1 others')
  local _,missing,state=fixture(native);state.metadata=false;v=node(nil,{10});literal(missing,v,'the number of 10 you are carrying')
  v.item=nil;v.value=nil;local positive,negative=literal(missing,v,'<item>');assert(positive:find('<quantity>',1,true) and negative:find('<quantity>',1,true))
 end
end)
test('named-set summaries add no native observation queries and never mutate configured names or condition values',function()
 local f,a,state,api=fixture(true);a.db.profile.itemsets.personal.name=name;local marker={};local v=node();v.sentinel=marker
 local before=a:CopySettingsData(v);local stores=a:CopySettingsData({a.db.profile.itemsets,a.db.global.itemsets});local calls=a:CopySettingsData(state.calls)
 for native in pairs(api) do api[native]=function() error('summary queried '..native) end end
 literal(a,v,name);assert(v.sentinel==marker and a:SettingsDataEqual(v,before) and a:SettingsDataEqual({a.db.profile.itemsets,a.db.global.itemsets},stores) and a:SettingsDataEqual(state.calls,calls))
end)
test('native Fields UI status refresh handles literal names and incomplete quantity without rewriting the selection',function()
 local _,a=fixture(true);a.db.profile.itemsets.personal.name=name;local v=node();local parent,quantity,state=mount(a,v)
 quantity.events.OnEnterPressed(quantity,'OnEnterPressed','2');assert(state.statuses==1 and state.status:find(name,1,true) and state.status:find('is equal to 2',1,true))
 quantity.events.OnEnterPressed(quantity,'OnEnterPressed','');assert(v.value==nil and v.item=='personal' and state.status:find(name,1,true) and state.status:find('<quantity>',1,true));parent:Release()
end)
test('retired native quantity callbacks remain inert after owner release and later field acquisition',function()
 local _,a=fixture(true);local v=node();local parent,quantity,state=mount(a,v);local stale=quantity.events.OnEnterPressed;parent:Release()
 local current=node();current.value=5;local owner,_,fresh=mount(a,current);stale(quantity,'OnEnterPressed','9')
 assert(v.value==2 and current.value==5 and state.statuses==0 and fresh.statuses==0);owner:Release()
end)
test('exact body and local selections inverse preserves whole item module and all private source and getter identities',function()
 local _,a=fixture(true);local text=dofile('tests/fixtures/restore_item_neighbor_summary_literals.lua')(read(modulePath));assert(a:FunctionSourceHash(inverse(text))=='2154174d','item module changed beyond named CARRYING summary')
 assert(inverse(repaired,true)==old and not pcall(inverse,old,true) and not pcall(inverse,repaired..' ',true) and not pcall(inverse,text..text))
 for capture,id in pairs(added) do assert(a.builtinCallbackBindings['Conditions/item.lua'][capture]==id) end
 for capture,hash in pairs({get_item_desc='fd63ea61',itemHelp='0f2e90aa',color='a59312f4',helpers='57c6fe6a'}) do local id='builtin:Conditions/item.lua:'..capture;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/item.lua'](capture))) end
end)
test('archived raw complete export retains old name-marker behavior and exact stored source',function()
 local _,a=fixture(true);a.db.profile.itemsets.personal.name=name;local source=a:GetBuiltinConditionSource('CARRYING')
 if source.print==repaired then source=inverse(source,'export') else assert(source.print==old) end
 assert(a:FunctionSourceHash(source)=='5e38c6c5');local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW=source};a:RegisterCondition('RAW',assert(a:CompileCustomCondition('RAW',source)))
 local v=node('RAW');local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7)
 assert(positive:find('Potions READY 50% {item}',1,true) and negative:find('Potions SPENT 50% {item}',1,true) and negative:find('is equal to 2',1,true))
 assert(a.db.global.custom_conditions.RAW==source and a:SettingsDataEqual(source,before))
end)
test('accepted oversized names retain native outcomes while the existing summary budget gives a fixed bounded fallback',function()
 local _,a=fixture(true);local longName=string.rep('x',64000);local set=a.db.profile.itemsets.personal;set.name=longName
 assert(a:ValidateProfileTransfer({version=3,itemsets={personal={name=longName,items={10,11}}}}))
 a:RegisterCondition('COPY_LONG_CARRYING',assert(a:CompileCustomCondition('COPY_LONG_CARRYING',a:GetBuiltinConditionSource('CARRYING'))))
 for _,tag in ipairs({'CARRYING','COPY_LONG_CARRYING'}) do local v=node(tag);local before=a:CopySettingsData(v);known(a,v)
  local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7)
  assert(positive=='Condition summary unavailable: invalid template or values.' and negative==positive and #positive<=64000)
  assert(a:SettingsDataEqual(v,before) and a.db.profile.itemsets.personal==set and set.name==longName)
 end
end)
test('generated editable copy owns only two explicit selected summary leaves and preserves the complete historical export inverse',function()
 local _,a=fixture(true);a.db.profile.itemsets.personal.name=name;local source=a:GetBuiltinConditionSource('CARRYING');assert(source.print==repaired,'CARRYING catalog pending')
 local before=a:CopySettingsData(source);local restored=inverse(source,'export');assert(a:FunctionSourceHash(restored)=='5e38c6c5' and not source.bindings.Summary)
 for capture,id in pairs(added) do assert(source.bindings[capture]==id and rawequal(a:ResolveFunctionBinding(id),a.Functions.presentation[capture:match('%.(.+)$')])) end
 a:RegisterCondition('COPY',assert(a:CompileCustomCondition('COPY',source)));local v=node('COPY');known(a,v);literal(a,v,name)
 local parent,quantity,state=mount(a,v,a.conditionDefinitions.COPY);quantity.events.OnEnterPressed(quantity,'OnEnterPressed','2');assert(state.status:find(name,1,true));parent:Release()
 assert(a:SettingsDataEqual(source,before))
end)
finish()
