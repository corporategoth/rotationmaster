local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,oldBody,newBody=dofile('tests/fixtures/restore_health_forecast_deficit.lua')
local function fixture()
 local f=F.new(11,2,'MAGE');local a,e=f.addon,f.env;local s={health=90,maximum=100,unit='target',calls={}}
 local function call(name,...) assert(select('#',...)==1 and select(1,...)==s.unit,'forecast actor or native arity changed');s.calls[#s.calls+1]=name;if s.throw==name then error('native health forecast failure') end end
 e.UnitExists=function(...) call('exists',...);return true end;e.UnitGUID=function(...) call('guid',...);return 'GUID-'..s.unit end;e.UnitHealth=function(...) call('health',...);return s.health end;e.UnitHealthMax=function(...) call('maximum',...);return s.maximum end;e.GetTime=function(...) assert(select('#',...)==0);return 100 end
 a.damageHistory={};a.db.profile.damage_history=10
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 return f,a,s
end
local function node(health,seconds,operator,tag,unit) return {type=tag or 'TT_HEALTH',unit=unit or 'target',health=health,value=seconds,operator=operator or 'EQUALS'} end
local function valid(a,v) assert(a.conditionDefinitions[v.type].valid(0,v),'forecast fixture fails real validation') end
local function branch(a,v)
 local selected;local body={rotation={{id='forecast',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local result=a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end);return result,selected
end
local function repairedControls(a,tag)
 for _,case in ipairs({{0,'EQUALS','match','no-match','yes'},{1,'LESSTHAN','match','no-match','yes'},{1,'GREATERTHAN','no-match','match','no'}}) do
  local v=node(-10,case[1],case[2],tag);valid(a,v);assert(a:evaluateConditionResult(v).status==case[3],'negative health target was not offset from maximum');assert(a:evaluateConditionResult({type='NOT',value=v}).status==case[4]);local result,selected=branch(a,v);assert(result.status=='complete' and selected==case[5])
 end
end
test('documented target deficit uses current90 maximum100 and negative10 at zero or positive seconds',function()
 local _,a=fixture();repairedControls(a,'TT_HEALTH')
end)
test('absolute health shortcuts preserve maximum laziness and the original count thresholds',function()
 local f,a,s=fixture();f.env.UnitHealthMax=function() error('absolute health queried maximum') end
 for _,health in ipairs({90,50,0}) do local v=node(health,0);valid(a,v);assert(a:evaluateConditionResult(v).status==(health==90 and 'match' or 'no-match')) end
 for _,call in ipairs(s.calls) do assert(call~='maximum') end
 assert(a.conditionDefinitions.TT_HEALTH.valid(0,node(-10,0)) and not a.conditionDefinitions.TT_HEALTH.valid(0,node(-10,-1)),'seconds validation changed')
end)
test('new required maximum retains exact native one-argument actor order and shared pass caching',function()
 local _,a,s=fixture();local eval=a.conditionDefinitions.TT_HEALTH.evaluate;local cache={};assert(eval(node(-10,0),cache)==true and eval(node(-10,0),cache)==true);assert(table.concat(s.calls,',')=='exists,guid,health,maximum')
 assert(eval(node(90,0),cache)==true and #s.calls==4,'absolute query did not share existing current facts')
 s.unit='pet';assert(eval(node(-10,0,nil,nil,'pet'),cache)==true);assert(table.concat(s.calls,',')=='exists,guid,health,maximum,exists,guid,health,maximum')
 assert(eval(node(-10,0,nil,nil,'pet'),{})==true and #s.calls==12)
end)
test('missing or failed maximum stays recoverably unavailable without an invented fallback',function()
 for _,mode in ipairs({'nil','throw'}) do local _,a,s=fixture();if mode=='nil' then s.maximum=nil else s.throw='maximum' end;local v=node(-10,0);valid(a,v)
  local result=a:evaluateConditionResult(v);assert(result.status=='unavailable' and result.reason~='condition-callback-error' and #a.Diagnostics:GetReports()==0,'unavailable maximum quarantined the condition')
  assert(a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable','failed maximum became an actionable NOT')
 end
end)
test('current source duplicate gets the repair while saved raw source retains the exact original guard',function()
 local _,a=fixture();local source=assert(a:GetBuiltinConditionSource('TT_HEALTH'));assert(dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')(dofile('tests/fixtures/restore_health_forecast_repairs.lua')(source.evaluate,'TT_HEALTH',true),'TT_HEALTH',true)==newBody,'current forecast source catalog stale');local copy=assert(a:CompileCustomCondition('COPY_FORECAST',source));a:RegisterCondition('COPY_FORECAST',copy);repairedControls(a,'COPY_FORECAST')
 source.evaluate=oldBody;local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW_FORECAST=source};local raw=assert(a:CompileCustomCondition('RAW_FORECAST',source));a:RegisterCondition('RAW_FORECAST',raw)
 local v=node(-10,0,nil,'RAW_FORECAST');valid(a,v);assert(raw.evaluate(v,{})==false and a:evaluateConditionResult({type='NOT',value=v}).status=='match');local r,selected=branch(a,v);assert(r.status=='complete' and selected=='no')
 assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions.RAW_FORECAST==source,'saved raw source was rewritten')
end)
test('one exact guard repair inverses the complete committed module and private identities',function()
 local _,a=fixture();local file=assert(io.open('Conditions/stats.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_health_forecast_repairs.lua')(text);text=dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')(text);text=dofile('tests/fixtures/restore_rune_repairs.lua')(text);assert(a:FunctionSourceHash(inverse(text))=='0cd932cd','stats differs beyond target field guard from5e907ef')
 assert(inverse(newBody,'TT_HEALTH')==oldBody);assert(not pcall(inverse,oldBody,'TT_HEALTH'));assert(not pcall(inverse,newBody..' ','TT_HEALTH'));assert(not pcall(inverse,newBody,'OTHER'));assert(not pcall(inverse,text..text),'inverse accepted duplicate whole callback')
 for name,hash in pairs({color='89107d36',helpers='c19dbbac'}) do local id='builtin:Conditions/stats.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/stats.lua'](name)) end
end)
finish()
