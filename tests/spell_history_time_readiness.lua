local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_spell_history_time_readiness.lua')
local tags={'SPELL_HISTORY_TIME','PETSPELL_HISTORY_TIME'}
local function read(path)local file=assert(io.open(path));local text=file:read('*a');file:close();return text end
local function fixture(modern)
 local f=F.new(5,1,'WARLOCK');local a,e=f.addon,f.env;local s={time=100,known=true,calls=0,ids={},canonical=686}
 e.BOOKTYPE_SPELL='spell';e.BOOKTYPE_PET='pet';e.GetTime=function() return s.time end;e.UnitGUID=function(unit) assert(unit=='player');return 'Player-1' end
 -- No client has a GetAddOnMetadata global any more; metadata comes from C_AddOns.
 e.C_AddOns={GetAddOnMetadata=function(_,field) return field=='Title' and 'Rotation Master' or 'test' end}
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={};f.libraries['LibDBIcon-1.0']={}
 f.libraries['LibDataBroker-1.1']={NewDataObject=function()return {} end};f.libraries['ThreatClassic-1.0']={Disable=function()end}
 -- Execute the whole production event producer. Only external library/native
 -- boundaries are supplied; no handler bodies or history algorithms are copied.
 f.load('main.lua');a.debug=function()end;a.db.profile.announces={};a.spellHistory={}
 e.GetBuildInfo=function()return '2.5.6','70006','',20506 end
 local function info(id)
  if id=='Shadow Bolt' then id=s.canonical elseif id=='Firebolt' then id=3110 end
  if id==686 or id==695 then return {name='Shadow Bolt',spellID=id,iconID=1,subtext=id==686 and 'Rank 1' or 'Rank 2'} elseif id==3110 then return {name='Firebolt',spellID=id,iconID=2,subtext='Rank 1'} end
 end
 local function link(id)return '|Hspell:'..id..'|h[Spell]|h' end
 if modern then
  e.Enum.SpellBookSpellBank={Player=0,Pet=1};e.C_Spell={GetSpellInfo=info,GetSpellLink=link};e.C_SpellBook={IsSpellKnown=function(id,bank) assert(bank==1);s.calls=s.calls+1;s.ids[#s.ids+1]=id;return s.known end}
 else
  e.GetSpellInfo=function(id)local r=info(id);if r then return r.name,r.subtext,r.iconID,0,0,30,r.spellID end end;e.GetSpellLink=link
  e.IsSpellKnown=function(id,pet)assert(pet==true);s.calls=s.calls+1;s.ids[#s.ids+1]=id;return s.known end
 end
 for _,path in ipairs({'Platform/spells.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/petspell.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 e.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,e)end;return fn,why end
 local serial=0
 function s.cast(unit,id,when) s.time=when;serial=serial+1;a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED',unit,'Cast-'..serial,id) end
 return f,a,s
end

local function node(tag,n,operator)return{type=tag,spell=tag=='SPELL_HISTORY_TIME'and 686 or 3110,ranked=true,operator=operator or'EQUALS',value=n or 5}end
local function cast(s,tag,when)s.cast(tag=='SPELL_HISTORY_TIME'and'player'or'pet',node(tag).spell,when)end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid fixture cannot prove unknown')
 for _,n in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}})do
  local r=a:evaluateConditionResult(n);assert(r.status=='unavailable'and r.reason~='invalid-condition-fields','required time became actionable: '..r.status)
 end
 for _,n in ipairs({v,{type='NOT',value=v}})do
  local r=a:EvaluateRotationSequence({rotation={{id='guard',type='branch',conditions=n,onTrue={{id='yes',type='spell',action=686}},onFalse={{id='no',type='spell',action=686}}}}},function(c)return a:evaluateConditionResult(c)end,function()error('unknown time chose branch')end)
  assert(r.status=='unavailable')
 end
end
local function compiled(a,tag,key)
 local source=a:GetBuiltinConditionSource(tag)
 a:RegisterCondition(key,assert(a:CompileCustomCondition(key,source)));return source
end
local function capturedFunctions(fn)
 for i=1,20 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name=='Functions'then return value end end
 error('actual authored Functions capture not found')
end

test('actual player and pet event producers with NaN time stay unavailable under NOT groups and both branch arms',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local _,a,s=fixture(modern);cast(s,tag,0/0);s.time=100
  assert(#a.spellHistory==1 and a.spellHistory[1].spell==node(tag).spell and a.spellHistory[1].time~=a.spellHistory[1].time)
  unknown(a,node(tag))
 end end
end)
test('actual finite event times followed by unavailable evaluation observations never authorize negative advice',function()
 for _,tag in ipairs(tags)do for _,mode in ipairs({'nan','restricted'})do local f,a,s=fixture(true);cast(s,tag,95);s.time=mode=='nan'and 0/0 or 100
  if mode=='restricted'then f.env.canaccessvalue=function(v)return v~=95 end end;unknown(a,node(tag))
 end end
end)
test('consumed direct evaluation clock fields require readable finite numbers without an added native query',function()
 for _,tag in ipairs(tags)do for _,case in ipairs({'nil','false','text','table','nan','positiveinf','negativeinf','restricted'})do
  local f,a,s=fixture(true);cast(s,tag,95);local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  local inputs={['false']=false,text='100',table={},nan=0/0,positiveinf=math.huge,negativeinf=-math.huge,restricted=opaque}
  f.env.GetTime=function()error('callback added clock')end;local v,why=a.conditionDefinitions[tag].evaluate(node(tag),{},inputs[case]);assert(v==nil and why,case)
 end end
end)
test('finite arithmetic overflow and unreadable derived elapsed are unavailable before comparison',function()
 for _,tag in ipairs(tags)do local f,a,s=fixture(true);cast(s,tag,-1e308);s.time=1e308;unknown(a,node(tag,0,'GREATERTHAN'))
  f,a,s=fixture(true);cast(s,tag,95);s.time=100;f.env.canaccessvalue=function(v)return v~=5 end;unknown(a,node(tag))
 end
end)
test('consumed timestamp malformed values fail while timestamp getter failures preserve thrown identity',function()
 for _,tag in ipairs(tags)do for _,bad in ipairs({false,'95',{},math.huge,-math.huge,0/0})do
  local _,a=fixture(true);local v=node(tag);a.spellHistory={{spell=v.spell,time=bad}};local result,reason=a.conditionDefinitions[tag].evaluate(v,{},100);assert(result==nil and reason)
 end
 local _,a=fixture(true);local v=node(tag);a.spellHistory={{spell=v.spell}};local result,reason=a.conditionDefinitions[tag].evaluate(v,{},100);assert(result==nil and reason)
 local marker={};a.spellHistory={setmetatable({spell=v.spell},{__index=function(_,k)assert(k=='time');error(marker)end})};local ok,why=pcall(a.conditionDefinitions[tag].evaluate,v,{},100);assert(not ok and why==marker)
 end
end)
test('signed fractional future and all-operator ordered arithmetic remain exact',function()
 for _,tag in ipairs(tags)do for _,row in ipairs({{95,100,5},{99.5,100,.5},{105,100,-5},{-2.5,-1,1.5},{-2,-10,-8}})do
  local _,a,s=fixture(true);cast(s,tag,row[1]);local v=node(tag,math.abs(row[3]));local elapsed=row[2]-row[1]
  for _,op in ipairs(a.operators)do v.operator=op;assert(a.conditionDefinitions[tag].valid(0,v));assert(a.conditionDefinitions[tag].evaluate(v,{},row[2])==a.Functions.values.compare(op,elapsed,v.value),op)end
 end end
end)
test('empty unrelated histories and known-absent pet remain lazy and preserve native pet bank cache',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local f,a,s=fixture(modern);local fn=a.conditionDefinitions[tag].evaluate;local v=node(tag)
  assert(fn(v,{},nil)==false);a.spellHistory={setmetatable({spell=999},{__index=function()error('unrelated timestamp read')end})};assert(fn(v,{},nil)==false)
  f.env.GetTime=function()error('new native clock')end;assert(fn(v,{},nil)==false)
  if tag=='PETSPELL_HISTORY_TIME'then s.known=false;a.spellHistory={setmetatable({spell=v.spell},{__index=function()error('absent pet time read')end})};assert(fn(v,{},nil)==false)
   s.known=true;a.spellHistory={{spell=v.spell,time=95}};local cache={};s.calls=0;assert(fn(v,cache,100)==true and fn(v,cache,100)==true and s.calls==1 and s.ids[#s.ids]==3110)
  end
 end end
end)
test('actual captured compare and configured operator precede timestamp getter while threshold follows subtraction',function()
 for _,tag in ipairs(tags)do local _,a=fixture(true);local fn=a.conditionDefinitions[tag].evaluate;local functions=capturedFunctions(fn);local original=functions.values.compare
  local v=node(tag,0,'GREATERTHAN');local calls=0;functions.values.compare=function(op,left,right)calls=calls+1;assert(op=='GREATERTHAN'and left==5 and right==20);return false end
  a.spellHistory={setmetatable({spell=v.spell},{__index=function(_,key)assert(key=='time');v.operator='LESSTHAN';v.value=20;functions.values.compare=function()error('later callee adopted')end;return 95 end})}
  assert(fn(v,{},100)==false and calls==1);functions.values.compare=original
 end
end)
test('readability checks do not eagerly consume threshold on unavailable numeric facts',function()
 for _,tag in ipairs(tags)do local _,a=fixture(true);local v=node(tag);v.value=nil;setmetatable(v,{__index=function(_,key)if key=='value'then error('unavailable consumed threshold')end end})
  a.spellHistory={{spell=v.spell,time=0/0}};local result,why=a.conditionDefinitions[tag].evaluate(v,{},100);assert(result==nil and why)
 end
end)
test('deliberate custom comparison nil false zero string table preserve raw first-result and legacy engine semantics',function()
 for _,tag in ipairs(tags)do for _,result in ipairs({'nil','false','0','"truthy"','{}'})do local _,a,s=fixture(true);cast(s,tag,95);cast(s,tag,99);s.time=100
  assert(a:InstallCustomFunction('READINESS_COMPARE',{description='first-result parity',args={{name='operator',type='string'},{name='elapsed',type='number'},{name='threshold',type='number'}},returns={},bindings={},code=(result=='false'and'return false,"ignoredtail"'or'assert(elapsed==1);return '..result..',"ignoredtail"')}))
  local source=a:GetBuiltinConditionSource(tag);source.evaluate=repaired[tag];source.bindings['Functions.values.compare']='READINESS_COMPARE';local raw=a:CopySettingsData(source);raw.evaluate=old[tag]
  local fresh=assert(a:CompileCustomCondition('FRESH_COMPARE',source));local archived=assert(a:CompileCustomCondition('RAW_COMPARE',raw));a:RegisterCondition('FRESH_COMPARE',fresh);a:RegisterCondition('RAW_COMPARE',archived)
  local function observe(name,fn)local v=node(tag);v.type=name;local function first(...)assert(select('#',...)==1);return ... end;local value=first(fn(v,{},100));return type(value),a:evaluateConditionResult(v).status,a:evaluateConditionResult({type='NOT',value=v}).status end
  local t,r,n=observe('FRESH_COMPARE',fresh.evaluate);local ot,orr,on=observe('RAW_COMPARE',archived.evaluate);assert(t==ot and r==orr and n==on)
 end end
end)
test('legacy raw callbacks retain unchecked comparison behavior without rewriting stored definitions',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture(true);local source=a:GetBuiltinConditionSource(tag);source.evaluate=old[tag]
  local before=a:CopySettingsData(source);a.db.global.custom_conditions=a.db.global.custom_conditions or{};a.db.global.custom_conditions['RAW_'..tag]=source
  a:RegisterCondition('RAW_'..tag,assert(a:CompileCustomCondition('RAW_'..tag,source)));cast(s,tag,0/0);s.time=100;local v=node(tag);v.type='RAW_'..tag
  assert(a:evaluateConditionResult({type='NOT',value=v}).status=='match');assert(a:SettingsDataEqual(before,source)and a.db.global.custom_conditions[v.type]==source)
 end
end)
-- What was a byte-exact inverse of the module is now only the part that matters to saved copies: the private helpers a copy can
-- bind to (builtin:<path>:<name>) keep their source identity and resolve to the shipped getters.
test('private helper source identities of the spell modules stay exact',function()
 local _,a=fixture()
 for path,entries in pairs({['Conditions/spell.lua']={color='906341b8',helpers='769a506e'},['Conditions/petspell.lua']={color='fedaa3e7',helpers='60920b9d'}})do for name,hash in pairs(entries)do local id='builtin:'..path..':'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules[path](name)))end end
end)
test('actual current exported copies use checked timestamps and preserve every other complete export field',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture(true);local source=compiled(a,tag,'COPY_'..tag);local v=node(tag);v.type='COPY_'..tag
  cast(s,tag,0/0);s.time=100;unknown(a,v)
 end
end)
finish()
