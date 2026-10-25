local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_resource_deficit_summary_repairs.lua')
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
-- TBC: its class map gives MAGE Arcane Charges (Era/progression have none).
local function setup(tag)
 local f=F.new(5,1,'MAGE');local a,e=f.addon,f.env
 local s={current=tag=='POINT' and 3 or tag=='HEALTH' and 50 or {[0]=20,[3]=20},maximum=(tag=='POINT' and 5 or tag=='HEALTH' and 100) or {[0]=100,[3]=100}}
 e.UnitExists=function(unit) assert(unit=='target');return true end
 e.UnitClass=function(unit) assert(unit=='target' or unit=='player');return 'Mage','MAGE',8 end
 e.UnitPowerType=function(...) assert(select('#',...)==1 and (...)=='target');return 3,'ENERGY' end
 e.UnitPower=function(...) assert(select('#',...)==2);local unit,id=...;assert(unit=='target');if tag=='POINT' then assert(id==16);return s.current end;assert(id==0 or id==3);return s.current[id] end
 e.UnitPowerMax=function(...) assert(select('#',...)==2);local unit,id=...;assert(unit=='target');if tag=='POINT' then assert(id==16);return s.maximum end;assert(id==0 or id==3);return s.maximum[id] end
 e.UnitHealth=function(unit) assert(unit=='target');return s.current end;e.UnitHealthMax=function(unit) assert(unit=='target');return s.maximum end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 local source=assert(a:GetBuiltinConditionSource(tag));a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)));return f,a,s,source
end

local function expected(a,v,amount)
 assert(a.conditionDefinitions[v.type].valid(0,v));assert(a:evaluateConditionResult(v).status=='match');assert(a:evaluateConditionResult({type='NOT',value=v}).status=='no-match');local picked
 local body={rotation={{id='gate',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};assert(a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) picked=n.id;return true end).status=='complete' and picked=='yes')
 local text=a:printCondition(v,0);assert(text:sub(-#tostring(amount))==tostring(amount) and not text:find('-'..amount,1,true),'wrong summary: '..text)
end
for _,tag in ipairs({'POWER','POINT'}) do test(tag..' BuiltIn displays the positive deficit it compares',function()
 local _,a=setup(tag);for _,name in ipairs({tag}) do expected(a,{type=name,unit='target',operator='EQUALS',value=tag=='POWER' and -80 or -2},tag=='POWER' and 80 or 2) end
end) end
test('negative fractional configured deficits retain exact fractional presentation and observation scale',function()
 for _,tag in ipairs({'POWER','POINT'}) do local _,a,s=setup(tag);if tag=='POWER' then s.current[3]=2.5;s.maximum[3]=3 else s.current=2.5;s.maximum=3 end
  for _,name in ipairs({tag}) do expected(a,{type=name,unit='target',operator='EQUALS',value=-.5},.5) end
 end
end)
test('zero including signed zero and positive configured values retain the raw resource branch',function()
 for _,tag in ipairs({'POWER','POINT'}) do local _,a,s=setup(tag)
  for _,amount in ipairs({0,-0,tag=='POWER' and 20 or 3}) do if tag=='POWER' then s.current[3]=amount else s.current=amount end
   local v={type=tag,unit='target',operator='EQUALS',value=amount};expected(a,v,amount);assert(not a:printCondition(v,0):find('deficit',1,true))
  end
 end
end)
test('HEALTH and MANA positive deficit summaries remain existing independent controls',function()
 for _,tag in ipairs({'HEALTH','MANA'}) do local _,a=setup(tag);expected(a,{type=tag,unit='target',operator='EQUALS',value=tag=='HEALTH' and -50 or -80},tag=='HEALTH' and 50 or 80) end
end)
test('locale literal named tokens percent data and single or double negation preserve positive amount',function()
 for _,tag in ipairs({'POWER','POINT'}) do local f,a=setup(tag);local amount=tag=='POWER' and 80 or 2;local key=tag=='POWER' and '%s power deficit' or '%s point deficit';f.translations[key]='[%s] {amount} 50%%';a.unitsPossessive.target='unit {name} 25%';a.operators.EQUALS='EQ';a.negatedOperators.EQUALS='NEQ'
  local node={type=tag,unit='target',operator='EQUALS',value=-amount};local prefix='[unit {name} 25%] {amount} 50% '
  assert(a:printCondition(node,0)==prefix..'EQ '..amount);assert(a:printCondition({type='NOT',value=node},0)==prefix..'NEQ '..amount);assert(a:printCondition({type='NOT',value={type='NOT',value=node}},0)==prefix..'EQ '..amount)
 end
end)
test('summary reads no native facts and never mutates configured or nested saved fields',function()
 for _,tag in ipairs({'POWER','POINT'}) do local f,a=setup(tag);local marker={};local node={type=tag,unit='target',operator='EQUALS',value=-2,sentinel=marker};local before=a:CopySettingsData(node)
  f.env.UnitExists=function() error('summary queried existence') end;f.env.UnitClass=function() error('summary queried class') end;f.env.UnitPower=function() error('summary queried power') end;f.env.UnitPowerMax=function() error('summary queried max') end;a:printCondition(node,0);assert(node.sentinel==marker and a:SettingsDataEqual(node,before))
 end
end)
test('archived raw exports retain their old negative summary and stored source identity',function()
 for _,tag in ipairs({'POWER','POINT'}) do local _,a,_,source=setup(tag);source.print=old[tag];local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW=source};a:RegisterCondition('RAW',assert(a:CompileCustomCondition('RAW',source)));assert(a:printCondition({type='RAW',unit='target',operator='EQUALS',value=-2},0):find('-2',1,true));assert(a:SettingsDataEqual(source,before) and a.db.global.custom_conditions.RAW==source)
 end
end)
test('only the exact two print expressions change the stats module and inverse rejects other bodies',function()
 local _,a=setup('POWER');local text=read('Conditions/stats.lua');assert(a:FunctionSourceHash(inverse(text))=='f27721a7','stats changed beyond POWER and POINT signs from efad377')
 assert(not pcall(inverse,text..text));for _,tag in ipairs({'POWER','POINT'}) do assert(inverse(repaired[tag],tag)==old[tag] and not pcall(inverse,old[tag],tag) and not pcall(inverse,repaired[tag]..' ',tag)) end
 for name,hash in pairs({color='89107d36',helpers='c19dbbac'}) do local id='builtin:Conditions/stats.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/stats.lua'](name))) end
end)
test('complete current and archived exports preserve all metadata and parameter or binding identities',function()
 for tag,hash in pairs({POWER='d33ea310',POINT='a03b3862'}) do local _,a,_,source=setup(tag);local restored=a:CopySettingsData(source);if restored.print==repaired[tag] then restored.print=inverse(restored.print,tag) else assert(restored.print==old[tag]) end
  if tag=='POINT' then restored.evaluate=dofile('tests/fixtures/restore_point_tbc_transport.lua')(restored.evaluate,'POINT',true) end
  assert(a:FunctionSourceHash(restored)==hash,'unrelated complete export changed '..tag);local raw=a:CopySettingsData(source);raw.print=old[tag]
  if tag=='POINT' then raw.evaluate=dofile('tests/fixtures/restore_point_tbc_transport.lua')(raw.evaluate,'POINT',true) end
  assert(a:FunctionSourceHash(raw)==hash)
 end
end)
test('current generated duplicates display corrected deficits and preserve their complete authored source',function()
 for _,tag in ipairs({'POWER','POINT'}) do local _,a,_,source=setup(tag);assert(source.print==repaired[tag],'deficit summary catalog pending '..tag);local before=a:CopySettingsData(source)
  expected(a,{type='COPY_'..tag,unit='target',operator='EQUALS',value=tag=='POWER' and -80 or -2},tag=='POWER' and 80 or 2)
  assert(a:SettingsDataEqual(source,before),'editable source rewritten')
 end
end)
finish()
