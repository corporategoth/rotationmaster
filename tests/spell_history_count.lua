local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_spell_history_count.lua')
local tags={'SPELL_HISTORY','PETSPELL_HISTORY'}
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
local function node(tag,threshold,operator)return {type=tag,spell=tag=='SPELL_HISTORY' and 686 or 3110,ranked=true,operator=operator or 'EQUALS',value=threshold or 2}end
local function known(a,v,want)
 assert(a.conditionDefinitions[v.type].valid(0,v),'history fixture fails actual validation')
 assert(a:evaluateConditionResult(v).status==(want and 'match' or 'no-match'),'retained occurrence ignored')
 assert(a:evaluateConditionResult({type='NOT',value=v}).status==(want and 'no-match' or 'match'))
 for _,kind in ipairs({'AND','OR'})do assert(a:evaluateConditionResult({type=kind,value={v}}).status==(want and 'match' or 'no-match'))end
 local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=686}},onFalse={{id='no',type='spell',action=686}}}}}
 assert(a:EvaluateRotationSequence(body,function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id;return true end).status=='complete' and selected==(want and 'yes' or 'no'))
end
local function older(a,s,tag)
 if tag=='SPELL_HISTORY' then s.cast('player',686,90);s.cast('pet',3110,95) else s.cast('pet',3110,90);s.cast('player',686,95) end;s.time=100
 assert(#a.spellHistory==2 and a.spellHistory[2].spell==node(tag).spell and a.spellHistory[2].time==90)
end

test('actual player and pet event producers retain older count matches through NOT groups and branches',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local _,a,s=fixture(modern);older(a,s,tag);known(a,node(tag),true)end end
end)
test('a newer same-spell false count does not hide a separately retained older occurrence',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture();older(a,s,tag);s.cast(tag=='SPELL_HISTORY' and 'player' or 'pet',node(tag).spell,99);s.time=100
  known(a,node(tag,3),true);known(a,node(tag,2),false);known(a,node(tag,1),true)
 end
end)
test('each retained count uses the unchanged operator and fractional threshold meanings',function()
 local cases={{'EQUALS',2,true},{'EQUALS',3,false},{'EQUALS',0,false},{'LESSTHAN',2,false},{'LESSTHAN',2.5,true},{'LESSTHANOREQUALS',2,true},{'GREATERTHAN',2,true},{'GREATERTHAN',4,false},{'GREATERTHANOREQUALS',4,true},{'NOTEQUALS',2,true},{'DIVISIBLE',2,true},{'DIVISIBLE',3,false}}
 for _,tag in ipairs(tags)do local _,a,s=fixture();older(a,s,tag);s.cast(tag=='SPELL_HISTORY' and 'player' or 'pet',node(tag).spell,97);s.cast(tag=='SPELL_HISTORY' and 'pet' or 'player',999,98)
  assert(a.spellHistory[2].spell==node(tag).spell and a.spellHistory[4].spell==node(tag).spell)
  for _,entry in ipairs(cases)do known(a,node(tag,entry[2],entry[1]),entry[3])end
 end
end)
test('empty missing and newest matching history retain known false or true controls',function()
 for _,tag in ipairs(tags)do local _,a,s=fixture();known(a,node(tag),false);s.cast('player',999,90);known(a,node(tag),false);s.cast(tag=='SPELL_HISTORY' and 'player' or 'pet',node(tag).spell,95);known(a,node(tag,1),true)end
end)
test('pet learned-state guards keep exact native bank pass cache and fresh-pass recovery',function()
 for _,modern in ipairs({false,true})do local _,a,s=fixture(modern);older(a,s,'PETSPELL_HISTORY');local v=node('PETSPELL_HISTORY');local fn=a.conditionDefinitions.PETSPELL_HISTORY.evaluate;local cache={}
  assert(fn(v,cache)==true and fn(v,cache)==true and s.calls==1 and s.ids[1]==3110)
  s.known=false;assert(fn(v,cache)==true);known(a,v,false)
  s.known=nil;assert(a:evaluateConditionResult(v).status=='unavailable' and a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable')
  s.known=true;known(a,v,true)
 end
end)
test('player exact-rank and unranked resolution retain the original selected spell identity',function()
 local _,a,s=fixture();older(a,s,'SPELL_HISTORY');local v=node('SPELL_HISTORY');known(a,v,true);s.canonical=695;v.ranked=false;known(a,v,false);s.cast('player',695,99);v.value=1;known(a,v,true)
end)
test('custom comparison results retain direct and legacy engine behavior without normalization',function()
 for _,tag in ipairs(tags)do for _,result in ipairs({'nil','0','"truthy"','{}'})do local _,a,s=fixture();s.cast(tag=='SPELL_HISTORY' and 'player' or 'pet',node(tag).spell,90);s.cast(tag=='SPELL_HISTORY' and 'player' or 'pet',node(tag).spell,95)
  local code=result=='nil' and 'if index ~= 1 then error("nil result scanned later occurrence") end; return nil,"unused tail"' or 'return '..result..',"unused tail"'
  local args={{name='operator',type='string',description='Comparison operator'},{name='index',type='number',description='History index'},{name='threshold',type='number',description='Configured count'}}
  assert(a:InstallCustomFunction('COMPARE_RESULT',{description='Result preservation',args=args,returns={},bindings={},code=code}))
  local source=a:GetBuiltinConditionSource(tag);source.bindings['Functions.values.compare']='COMPARE_RESULT';local copy=assert(a:CompileCustomCondition('CUSTOM_COMPARE',source));a:RegisterCondition('CUSTOM_COMPARE',copy);local v=node(tag);v.type='CUSTOM_COMPARE'
  assert(copy.valid(0,v));local function first(...)assert(select('#',...)==1);return ... end;local got=first(copy.evaluate(v,{}));assert(result=='nil' and got==nil or result=='0' and got==0 or result=='"truthy"' and got=='truthy' or result=='{}' and type(got)=='table')
  local archived=a:CopySettingsData(source);archived.evaluate=old[tag];local raw=assert(a:CompileCustomCondition('RAW_COMPARE',archived));a:RegisterCondition('RAW_COMPARE',raw)
  local rawValue=a:CopySettingsData(v);rawValue.type='RAW_COMPARE';local rawGot=first(raw.evaluate(rawValue,{}));assert(type(rawGot)==type(got) and (type(got)=='table' or rawGot==got))
  assert(a:evaluateConditionResult(v).status==a:evaluateConditionResult(rawValue).status and a:evaluateConditionResult({type='NOT',value=v}).status==a:evaluateConditionResult({type='NOT',value=rawValue}).status)
  assert(a:evaluateConditionResult(v).status==(result=='nil' and 'no-match' or 'match'))
 end end
end)
test('schema thresholds summaries and source fields retain their original contracts',function()
 for _,tag in ipairs(tags)do local _,a=fixture();local v=node(tag);assert(a.conditionDefinitions[tag].valid(0,v));v.value=-1;assert(not a.conditionDefinitions[tag].valid(0,v));v.value=2.5;assert(a.conditionDefinitions[tag].valid(0,v));assert(a:printCondition(v,0):find('2.5 casts ago',1,true))end
end)
test('strict evaluator inverses preserve complete modules and every private identity',function()
 local _,a=fixture()
 for path,hash in pairs({['Conditions/spell.lua']='6b6e47be',['Conditions/petspell.lua']='325bd9c5'})do local text=dofile('tests/fixtures/restore_spell_range_presence.lua')(read(path),path);assert(a:FunctionSourceHash(inverse(dofile('tests/fixtures/restore_spell_history_time.lua')(text,path),path))==hash and inverse(text)==inverse(text,path));assert(not pcall(inverse,text..text,path))end
 for _,tag in ipairs(tags)do assert(inverse(repaired[tag],tag,true)==old[tag] and not pcall(inverse,old[tag],tag,true) and not pcall(inverse,repaired[tag]..' ',tag,true))end
 for path,entries in pairs({['Conditions/spell.lua']={color='906341b8',helpers='769a506e'},['Conditions/petspell.lua']={color='fedaa3e7',helpers='60920b9d'}})do for name,hash in pairs(entries)do local id='builtin:'..path..':'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules[path](name)))end end
end)
test('raw saved history sources retain first-row behavior and their complete stored exports',function()
 local _,a,s=fixture();for _,tag in ipairs(tags)do local source=a:GetBuiltinConditionSource(tag);source.evaluate=old[tag];assert(a:FunctionSourceHash(source)==(tag=='SPELL_HISTORY' and 'd36e6cc2' or '3772ec5e'));local before=a:CopySettingsData(source);a.db.global.custom_conditions=a.db.global.custom_conditions or {};a.db.global.custom_conditions['RAW_'..tag]=source
  a:RegisterCondition('RAW_'..tag,assert(a:CompileCustomCondition('RAW_'..tag,source)));a.spellHistory={};older(a,s,tag);local v=node(tag);v.type='RAW_'..tag;known(a,v,false);assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions[v.type]==source)
 end
end)
test('actual current editable copies scan retained occurrences and preserve complete export metadata',function()
 for _,modern in ipairs({false,true})do for _,tag in ipairs(tags)do local _,a,s=fixture(modern);older(a,s,tag);local source=a:GetBuiltinConditionSource(tag);assert(source.evaluate==repaired[tag],'spell history catalog pending');local restored=a:CopySettingsData(source);restored.evaluate=inverse(restored.evaluate,tag,true);assert(a:FunctionSourceHash(restored)==(tag=='SPELL_HISTORY' and 'd36e6cc2' or '3772ec5e'))
  local before=a:CopySettingsData(source);a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)));local v=node(tag);v.type='COPY_'..tag;known(a,v,true);assert(a:SettingsDataEqual(before,source))
 end end
end)
finish()
