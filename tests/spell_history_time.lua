local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_spell_history_time.lua')
local tags={'SPELL_HISTORY_TIME','PETSPELL_HISTORY_TIME'}
local function read(path)local file=assert(io.open(path));local text=file:read('*a');file:close();return text end
local function fixture(modern)
 local f=F.new(5,1,'WARLOCK');local a,e=f.addon,f.env;local s={time=100,known=true,calls=0,ids={},canonical=686}
 e.BOOKTYPE_SPELL='spell';e.BOOKTYPE_PET='pet';e.GetTime=function() return s.time end;e.UnitGUID=function(unit) assert(unit=='player');return 'Player-1' end
 e.GetAddOnMetadata=function(_,field) return field=='Title' and 'Rotation Master' or 'test' end
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
local function node(tag,threshold,operator)return {type=tag,spell=tag=='SPELL_HISTORY_TIME' and 686 or 3110,ranked=true,operator=operator or 'EQUALS',value=threshold or 5}end
local function known(a,v,want)
 assert(a.conditionDefinitions[v.type].valid(0,v),'time history fixture fails actual validation')
 assert(a:evaluateConditionResult(v).status==(want and 'match' or 'no-match'),'retained occurrence ignored')
 assert(a:evaluateConditionResult({type='NOT',value=v}).status==(want and 'no-match' or 'match'))
 for _,kind in ipairs({'AND','OR'})do assert(a:evaluateConditionResult({type=kind,value={v}}).status==(want and 'match' or 'no-match'))end
 local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=686}},onFalse={{id='no',type='spell',action=686}}}}}
 assert(a:EvaluateRotationSequence(body,function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id;return true end).status=='complete' and selected==(want and 'yes' or 'no'))
end
local function older(a,s,tag)
 if tag=='SPELL_HISTORY_TIME' then s.cast('player',686,95);s.cast('pet',3110,99) else s.cast('pet',3110,95);s.cast('player',686,99) end;s.time=100
 assert(#a.spellHistory==2 and a.spellHistory[2].spell==node(tag).spell and a.spellHistory[2].time==95)
end

test('actual player and pet success histories retain older elapsed-time matches through logical and branch contexts',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local _,a,s=fixture(modern);older(a,s,tag);known(a,node(tag),true)end end
end)
test('newer same-spell false elapsed comparisons do not hide older separately recorded casts',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture();older(a,s,tag);s.cast(tag=='SPELL_HISTORY_TIME' and 'player' or 'pet',node(tag).spell,99.5);s.time=100
  known(a,node(tag,5),true);known(a,node(tag,.5),true);known(a,node(tag,2),false)
 end
end)
test('all operators zero and fractional elapsed thresholds keep their original arithmetic',function()
 local cases={{'EQUALS',5,true},{'EQUALS',2,false},{'EQUALS',0,false},{'LESSTHAN',1,true},{'LESSTHAN',.5,false},{'LESSTHANOREQUALS',.5,true},{'GREATERTHAN',4,true},{'GREATERTHAN',5,false},{'GREATERTHANOREQUALS',5,true},{'NOTEQUALS',.5,true},{'DIVISIBLE',5,true},{'DIVISIBLE',3,false}}
 for _,tag in ipairs(tags)do local _,a,s=fixture();older(a,s,tag);s.cast(tag=='SPELL_HISTORY_TIME' and 'player' or 'pet',node(tag).spell,99.5);s.time=100
  for _,entry in ipairs(cases)do known(a,node(tag,entry[2],entry[1]),entry[3])end
 end
end)
test('empty missing newest and current elapsed-time controls keep known results',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture();known(a,node(tag),false);s.cast('player',999,90);known(a,node(tag),false);s.cast(tag=='SPELL_HISTORY_TIME' and 'player' or 'pet',node(tag).spell,95);s.time=100;known(a,node(tag),true);s.time=95;known(a,node(tag,0),true)end
end)
test('callbacks consume only supplied evaluation clocks and empty histories remain lazy',function()
 for _,tag in ipairs(tags)do local f,a,s=fixture();older(a,s,tag);local fn=a.conditionDefinitions[tag].evaluate;local v=node(tag,5.25);f.env.GetTime=function()error('history callback added native clock query')end
  assert(fn(v,{},100.25)==true and fn(v,{},100.5)==false);a.spellHistory={};assert(fn(v,{},nil)==false)
 end
end)
test('nonmatching rows do not consume timestamps and matching timestamp failures keep error identity',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture();older(a,s,tag);local fn=a.conditionDefinitions[tag].evaluate;local v=node(tag);local marker={}
  a.spellHistory[1]=setmetatable({spell=999},{__index=function(_,key)assert(key=='time');error(marker)end});assert(fn(v,{},100)==true)
  a.spellHistory={setmetatable({spell=v.spell},{__index=function(_,key)assert(key=='time');error(marker)end})};local ok,why=pcall(fn,v,{},100);assert(not ok and why==marker)
 end
end)
test('operator capture precedes timestamp lookup and threshold lookup still follows elapsed arithmetic',function()
 for _,tag in ipairs(tags)do local _,a=fixture();local fn=a.conditionDefinitions[tag].evaluate
  local v=node(tag,0,'GREATERTHAN');a.spellHistory={setmetatable({spell=v.spell},{__index=function(_,key)assert(key=='time');v.operator='LESSTHAN';return 95 end})};assert(fn(v,{},100)==true and v.operator=='LESSTHAN')
  v=node(tag,0,'GREATERTHAN');a.spellHistory={setmetatable({spell=v.spell},{__index=function(_,key)assert(key=='time');v.value=20;return 95 end})};assert(fn(v,{},100)==false and v.value==20)
 end
end)
test('custom comparison nil and nonboolean first results preserve direct values legacy truthiness and stop ordering',function()
 for _,tag in ipairs(tags)do for _,result in ipairs({'nil','0','"truthy"','{}'})do local _,a,s=fixture();s.cast(tag=='SPELL_HISTORY_TIME' and 'player' or 'pet',node(tag).spell,95);s.cast(tag=='SPELL_HISTORY_TIME' and 'player' or 'pet',node(tag).spell,99);s.time=100
  local args={{name='operator',type='string',description='Operator'},{name='elapsed',type='number',description='Elapsed seconds'},{name='threshold',type='number',description='Configured seconds'}}
  assert(a:InstallCustomFunction('COMPARE_RESULT',{description='Result preservation',args=args,returns={},bindings={},code='if elapsed ~= 1 then error("read later occurrence") end;return '..result..',"unused tail"'}))
  local source=a:GetBuiltinConditionSource(tag);source.bindings['Functions.values.compare']='COMPARE_RESULT';local copy=assert(a:CompileCustomCondition('CUSTOM_COMPARE',source));a:RegisterCondition('CUSTOM_COMPARE',copy);local v=node(tag);v.type='CUSTOM_COMPARE'
  local archived=a:CopySettingsData(source);archived.evaluate=old[tag];local raw=assert(a:CompileCustomCondition('RAW_COMPARE',archived));a:RegisterCondition('RAW_COMPARE',raw);local rv=a:CopySettingsData(v);rv.type='RAW_COMPARE'
  local function first(...)assert(select('#',...)==1);return ... end;local got=first(copy.evaluate(v,{},100));local previous=first(raw.evaluate(rv,{},100));assert(type(got)==type(previous) and(type(got)=='table'or got==previous))
  known(a,v,result~='nil');known(a,rv,result~='nil')
 end end
end)
test('pet learned bank observation retains pass caching known absence and unavailable recovery',function()
 for _,modern in ipairs({false,true})do local _,a,s=fixture(modern);older(a,s,'PETSPELL_HISTORY_TIME');local fn=a.conditionDefinitions.PETSPELL_HISTORY_TIME.evaluate;local v=node('PETSPELL_HISTORY_TIME');local cache={}
  assert(fn(v,cache,100)==true and fn(v,cache,100)==true and s.calls==1 and s.ids[1]==3110);s.known=false;assert(fn(v,cache,100)==true);known(a,v,false)
  s.known=nil;assert(a:evaluateConditionResult(v).status=='unavailable' and a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable');s.known=true;known(a,v,true)
 end
end)
test('player exact rank unranked identity schemas and summaries stay unchanged',function()
 local _,a,s=fixture();older(a,s,'SPELL_HISTORY_TIME');local v=node('SPELL_HISTORY_TIME');known(a,v,true);s.canonical=695;v.ranked=false;known(a,v,false);s.cast('player',695,99);s.time=100;v.value=1;known(a,v,true)
 v.value=-1;assert(not a.conditionDefinitions[v.type].valid(0,v));v.value=2.5;assert(a.conditionDefinitions[v.type].valid(0,v) and a:printCondition(v,0):find('2.5 seconds ago',1,true))
end)
test('strict time inverses retain completed count fixes whole modules and four private source identities',function()
 local _,a=fixture();for path,hash in pairs({['Conditions/spell.lua']='5826d33a',['Conditions/petspell.lua']='8e83e381'})do local text=dofile('tests/fixtures/restore_spell_range_presence.lua')(dofile('tests/fixtures/restore_spell_history_time_readiness.lua')(read(path),path),path);assert(a:FunctionSourceHash(inverse(text,path))==hash and inverse(text)==inverse(text,path));assert(not pcall(inverse,text..text,path))end
 for _,tag in ipairs(tags)do assert(inverse(repaired[tag],tag,true)==old[tag] and not pcall(inverse,old[tag],tag,true) and not pcall(inverse,repaired[tag]..' ',tag,true))end
 for path,entries in pairs({['Conditions/spell.lua']={color='906341b8',helpers='769a506e'},['Conditions/petspell.lua']={color='fedaa3e7',helpers='60920b9d'}})do for name,hash in pairs(entries)do local id='builtin:'..path..':'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules[path](name)))end end
end)
test('raw archived time callbacks keep first-row behavior and stored source without rewriting',function()
 local _,a,s=fixture();for _,tag in ipairs(tags)do local source=a:GetBuiltinConditionSource(tag);source.evaluate=old[tag];assert(a:FunctionSourceHash(source)==(tag=='SPELL_HISTORY_TIME'and'b3baa557'or'5b27b194'));local before=a:CopySettingsData(source);a.db.global.custom_conditions=a.db.global.custom_conditions or {};a.db.global.custom_conditions['RAW_'..tag]=source
  a:RegisterCondition('RAW_'..tag,assert(a:CompileCustomCondition('RAW_'..tag,source)));a.spellHistory={};older(a,s,tag);local v=node(tag);v.type='RAW_'..tag;known(a,v,false);assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions[v.type]==source)
 end
end)
test('actual current editable time copies scan older matches and preserve all unrelated export fields',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local _,a,s=fixture(modern);older(a,s,tag);local source=a:GetBuiltinConditionSource(tag);local normalized=dofile('tests/fixtures/restore_spell_history_time_readiness.lua')(source.evaluate,tag,true);assert(normalized==repaired[tag],'spell time catalog pending');local restored=a:CopySettingsData(source);restored.evaluate=inverse(normalized,tag,true);assert(a:FunctionSourceHash(restored)==(tag=='SPELL_HISTORY_TIME'and'b3baa557'or'5b27b194'))
  local before=a:CopySettingsData(source);a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)));local v=node(tag);v.type='COPY_'..tag;known(a,v,true);assert(a:SettingsDataEqual(before,source))
 end end
end)
finish()
