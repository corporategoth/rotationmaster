local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired,added=dofile('tests/fixtures/restore_item_neighbor_summary_literals.lua')
local modulePath='Conditions/item.lua'
local tags={'EQUIPPED','ITEM','ITEM_RANGE','ITEM_COOLDOWN'}
local expected={EQUIPPED='0894ab4e',ITEM='765ed7a9',ITEM_RANGE='5894423b',ITEM_COOLDOWN='924ed669'}
local keys={EQUIPPED='you {{!have|do not have}} {item} equipped',ITEM='{item} {{!is|is not}} available{carrying}',ITEM_RANGE='{item} {{!is|is not}} in range{carrying}',ITEM_COOLDOWN='the cooldown on {item} {comparison} {duration}{carrying}'}
local name='Potions {{!READY|SPENT}} 50% {item}'
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
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


local function node(tag,item)return{type=tag,item=item or 'personal',operator='EQUALS',value=0}end
local function prepare(native)
 local f,a,s,api=fixture(native);s.equipped[10]=true;s.equipped[11]=true;a.db.profile.itemsets.personal.name=name;a.db.global.itemsets.global.name=name
 return f,a,s,api
end
local function known(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid test fields '..v.type)
 assert(a:evaluateConditionResult(v).status=='match'and a:evaluateConditionResult({type='NOT',value=v}).status=='no-match')
 local selected;local branch={rotation={{id='gate',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 assert(a:EvaluateRotationSequence(branch,function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id;return true end).status=='complete'and selected=='yes')
 assert(a:evaluateConditionResult({type='AND',value={v,{type='OR',value={v,{type='NOT',value=v}}}}}).status=='match')
end
local function literal(a,v,text)
 local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7)
 assert(positive:find(text,1,true),'positive changed literal '..v.type..': '..positive)
 assert(negative:find(text,1,true),'negative changed literal '..v.type..': '..negative)
 assert(a:printCondition({type='NOT',value={type='NOT',value=v}},7)==positive)
 return positive,negative
end
local function mount(a,v,definition)
 local parent=a:CreateConditionGroup();parent:SetWidth(640);local state={statuses=0};local owner={}
 local funcs={print=function(_,root,spec)assert(root==v and spec==7);return a:printCondition(root,spec)end}
 function owner:GetUserData(key)if key=='root'then return v elseif key=='funcs'then return funcs end end
 function owner:SetStatusText(text)state.statuses=state.statuses+1;state.status=text end
 parent:SetUserData('top',owner);(definition or a.conditionDefinitions[v.type]).widget(parent,7,v);a:configure_frame(parent);parent:DoLayout()
 return parent,parent.children[1].children[2],state
end
for _,tag in ipairs(tags)do test(tag..' preserves accepted item-set literal and exact real predicate negation',function()
 for _,native in ipairs({false,true})do local _,a=prepare(native);assert(a:ValidateProfileTransfer({version=3,itemsets={personal={name=name,items={10,11}}}}))
  local v=node(tag);known(a,v);local positive,negative=literal(a,v,name)
  if tag=='EQUIPPED'then assert(positive:find('you have',1,true)and negative:find('you do not have',1,true))
  elseif tag=='ITEM_COOLDOWN'then assert(positive:find('is equal to 0 seconds',1,true)and negative:find('is not equal to 0 seconds',1,true))
  else assert(negative:find(tag=='ITEM'and'is not available'or'is not in range',1,true))end
 end
end)end
test('personal and global names preserve alternative markers braces percent hyperlinks and colors literally',function()
 for _,native in ipairs({false,true})do local _,a=prepare(native)
  for _,value in ipairs({name,'{{yes|no}} {{!one|two}}','{item} {comparison} 100%','|Hitem:10|h[{{!Hot|Cold}}]|h','|cff123456Tint {{!A|B}}|r'})do
   a.db.profile.itemsets.personal.name=value;a.db.global.itemsets.global.name=value
   for _,tag in ipairs(tags)do for _,id in ipairs({'personal','global'})do local v=node(tag,id);known(a,v);literal(a,v,value)end end
  end
 end
end)
test('cooldown all operators preserve canonical comparison and fractional seconds while qualifiers stay positive',function()
 local _,a=prepare(true)
 for _,op in ipairs({'LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','EQUALS','NOTEQUALS','DIVISIBLE'})do
  local v=node('ITEM_COOLDOWN');v.operator=op;v.value=.5;v.notcarrying=true;assert(a.conditionDefinitions.ITEM_COOLDOWN.valid(0,v));a.operators[op]='POS_'..op;a.negatedOperators[op]='NEG_'..op
  local positive,negative=literal(a,v,name);assert(positive:find('POS_'..op..' 0.5 seconds',1,true)and negative:find('NEG_'..op..' 0.5 seconds',1,true))
  assert(positive:find(', even if you do not currently have one',1,true)and negative:find(', even if you do not currently have one',1,true))
 end
end)
test('all new whole translations reorder named values without parsing inserted data',function()
 for _,tag in ipairs(tags)do local f,a=prepare(true);local v=node(tag);v.notcarrying=true
  if tag=='EQUIPPED'then f.translations[keys[tag]]='{item} :: {{!equipped|unequipped}} :: 50%'
  elseif tag=='ITEM_COOLDOWN'then f.translations[keys[tag]]='{duration} :: {comparison} :: {item}{carrying} :: 50%'
  else f.translations[keys[tag]]='{carrying}{item} :: {{!present|absent}} :: 50%'end
  local positive,negative=literal(a,v,name);assert(positive:sub(-3)=='50%'and negative:sub(-3)=='50%')
  if tag=='EQUIPPED'then assert(negative:find(' :: unequipped :: ',1,true))elseif tag=='ITEM_COOLDOWN'then assert(negative:find('0 seconds :: is not equal to :: ',1,true))else assert(negative:find(' :: absent :: ',1,true))end
 end
end)
test('ordinary name descriptor list missing metadata empty placeholders and carrying suffix retain original output',function()
 for _,native in ipairs({false,true})do local _,a,s=prepare(native);a.db.profile.itemsets.personal.name='Ordinary'
  for _,tag in ipairs(tags)do local source=a:GetBuiltinConditionSource(tag);if source.print==repaired[tag]then source=inverse(source,tag,'export')else assert(source.print==old[tag])end
   a:RegisterCondition('CONTROL_'..tag,assert(a:CompileCustomCondition('CONTROL_'..tag,source)))
   for _,reference in ipairs({'personal','global',{10},{10,11},{}})do for _,flag in ipairs({false,true})do
    local v=node(tag,reference);v.notcarrying=flag;local control=a:CopySettingsData(v);control.type='CONTROL_'..tag
    -- Global name intentionally has markers: ordinary-data equality only.
    if reference~='global'then assert(a:printCondition(v,7)==a:printCondition(control,7)and a:printCondition({type='NOT',value=v},7)==a:printCondition({type='NOT',value=control},7),'ordinary wording changed '..tag)end
   end end
   local v=node(tag);v.item=nil;v.value=nil;local control=a:CopySettingsData(v);control.type='CONTROL_'..tag;assert(a:printCondition(v,7)==a:printCondition(control,7))
  end
  s.metadata=false
  for _,tag in ipairs(tags)do local v=node(tag,{99});local control=a:CopySettingsData(v);control.type='CONTROL_'..tag;assert(a:printCondition(v,7)==a:printCondition(control,7))end
 end
end)
test('named-set summaries add no native queries or saved-data writes',function()
 local _,a,s,api=prepare(true);local before=a:CopySettingsData({a.db.profile.itemsets,a.db.global.itemsets});local calls=a:CopySettingsData(s.calls)
 for native in pairs(api)do api[native]=function()error('summary queried '..native)end end
 for _,tag in ipairs(tags)do local v=node(tag);local data=a:CopySettingsData(v);literal(a,v,name);assert(a:SettingsDataEqual(v,data))end
 assert(a:SettingsDataEqual({a.db.profile.itemsets,a.db.global.itemsets},before)and a:SettingsDataEqual(s.calls,calls))
end)
test('actual native field selection refreshes status and nil clears selection without parsing names',function()
 for _,tag in ipairs(tags)do local _,a=prepare(true);local v=node(tag);local parent,item,state=mount(a,v)
  item.events.OnValueChanged(item,'OnValueChanged','global');assert(v.item=='global'and state.status:find(name,1,true))
  item.events.OnValueChanged(item,'OnValueChanged',nil);assert(v.item==nil and state.status:find('<item>',1,true))
  if tag=='ITEM_COOLDOWN'then local quantity=parent.children[2].children[2];quantity.events.OnEnterPressed(quantity,'OnEnterPressed','');assert(v.value==nil and state.status:find('<value>',1,true)and state.status:find(' seconds',1,true))end
  parent:Release()
 end
end)
test('retired selection callbacks cannot write a released or newly acquired native owner',function()
 for _,tag in ipairs(tags)do local _,a=prepare(true);local v=node(tag);local parent,item,state=mount(a,v);local stale=item.events.OnValueChanged;parent:Release()
  local current=node(tag);local owner,_,fresh=mount(a,current);stale(item,'OnValueChanged','global');assert(v.item=='personal'and current.item=='personal'and state.statuses==0 and fresh.statuses==0);owner:Release()
 end
end)
test('strict full module inverse preserves completed CARRYING body bindings private sources and getter IDs',function()
 local _,a=prepare(true);local text=read(modulePath);assert(a:FunctionSourceHash(inverse(text))=='50f07ef7','item changed beyond four print bodies and one selected root')
 assert(not pcall(inverse,text..'\n-- unrelated')and not pcall(inverse,text..text))
 for _,tag in ipairs(tags)do assert(inverse(repaired[tag],tag,true)==old[tag]and not pcall(inverse,old[tag],tag,true)and not pcall(inverse,repaired[tag]..' ',tag,true))end
 assert(a:FunctionSourceHash(a:GetBuiltinConditionSource('CARRYING'))=='5e034bda','completed CARRYING export drifted')
 for alias,hash in pairs({get_item_desc='fd63ea61',itemHelp='0f2e90aa',color='a59312f4',helpers='57c6fe6a'})do local id='builtin:Conditions/item.lua:'..alias;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/item.lua'](alias)))end
end)
test('accepted oversized names keep actual native outcomes while named summaries use the existing bounded fallback',function()
 local _,a=prepare(true);local longName=string.rep('x',64000);local set=a.db.profile.itemsets.personal;set.name=longName
 assert(a:ValidateProfileTransfer({version=3,itemsets={personal={name=longName,items={10,11}}}}))
 for _,tag in ipairs(tags)do local v=node(tag);local before=a:CopySettingsData(v);known(a,v)
  local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7)
  assert(positive=='Condition summary unavailable: invalid template or values.'and negative==positive and #positive<=64000)
  assert(a:SettingsDataEqual(v,before)and a.db.profile.itemsets.personal==set and set.name==longName)
 end
end)
test('archived raw complete exports keep old token behavior and source identity unchanged',function()
 local _,a=prepare(true);a.db.global.custom_conditions={}
 for _,tag in ipairs(tags)do local source=a:GetBuiltinConditionSource(tag);if source.print==repaired[tag]then source=inverse(source,tag,'export')else assert(source.print==old[tag])end
  assert(a:FunctionSourceHash(source)==expected[tag]);local before=a:CopySettingsData(source);local id='RAW_'..tag;a.db.global.custom_conditions[id]=source;a:RegisterCondition(id,assert(a:CompileCustomCondition(id,source)));local v=node(id);known(a,v)
  local positive=a:printCondition(v,7);local negative=a:printCondition({type='NOT',value=v},7);assert(not positive:find(name,1,true)and not negative:find(name,1,true)and positive:find('Potions READY',1,true));assert(a:SettingsDataEqual(source,before)and a.db.global.custom_conditions[id]==source)
 end
end)
test('current generated copies use exact selected leaves and preserve complete archived export inverses and native UI',function()
 local _,a=prepare(true)
 for _,tag in ipairs(tags)do local source=a:GetBuiltinConditionSource(tag);assert(source.print==repaired[tag],'catalog pending '..tag);local before=a:CopySettingsData(source);assert(a:FunctionSourceHash(inverse(source,tag,'export'))==expected[tag])
  assert(not source.bindings.Literal and not source.bindings.Summary)
  for capture,id in pairs(added[tag])do assert(source.bindings[capture]==id)end
  if tag~='ITEM_COOLDOWN'then assert(source.bindings['Summary.predicate']==nil and source.bindings['Summary.phrase']==nil,'unused operator leaf spread to literal-only print')else assert(source.bindings['Literal.phrase']==nil)end
  local id='COPY_'..tag;a:RegisterCondition(id,assert(a:CompileCustomCondition(id,source)));local v=node(id);known(a,v);literal(a,v,name);local parent,item,state=mount(a,v,a.conditionDefinitions[id]);item.events.OnValueChanged(item,'OnValueChanged','global');assert(state.status:find(name,1,true));parent:Release();assert(a:SettingsDataEqual(source,before))
 end
end)
finish()
