local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project,class)
 local f=F.new(project,nil,class or 'SHAMAN');local a,e=f.addon,f.env;local s={value=0,calls=0,count=3,countCalls=0}
 e.GetShapeshiftForm=function(...) assert(select('#',...)==0);s.calls=s.calls+1;if s.throw then error('native form failure') end;return s.value end
 e.GetNumShapeshiftForms=function(...) assert(select('#',...)==0);s.countCalls=s.countCalls+1;return s.count end
 local file=io.open('Platform/form.lua');if file then file:close();f.load('Platform/form.lua') end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 return f,a,s
end
local function node(value,tag) return {type=tag or 'FORM',value=value or 0} end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'unavailable fixture has invalid fields')
 for _,n in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local r=a:evaluateConditionResult(n);assert(r.status=='unavailable' and r.reason~='invalid-condition-fields','form unknown became actionable') end
 for _,n in ipairs({v,{type='NOT',value=v}}) do local body={rotation={{id='form',type='branch',conditions=n,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unknown form selected branch') end).status=='unavailable') end
end
local function copy(a)
 local source=assert(a:GetBuiltinConditionSource('FORM'));assert(source.evaluate:find('addon.Platform.GetPlayerFormObservation',1,true),'current form source catalog stale');a:RegisterCondition('COPY_FORM',assert(a:CompileCustomCondition('COPY_FORM',source)));return source
end
test('required missing nil malformed restricted and nonfinite facts stay unknown under NOT and branches',function()
 for _,mode in ipairs({'missing','nil','throw','restricted',false,true,'0',{},0/0,math.huge,-math.huge}) do
  local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
  if mode=='missing' then f.env.GetShapeshiftForm=nil elseif mode=='nil' then s.value=nil elseif mode=='throw' then s.throw=true elseif mode=='restricted' then s.value=opaque else s.value=mode end;unknown(a,node())
 end
end)
test('humanoid inclusive forms and fractional configured values retain exact equality and branch controls',function()
 for _,case in ipairs({{'SHAMAN',0,0,true},{'SHAMAN',1,1,true},{'SHAMAN',.5,.5,true},{'DRUID',3,3,true},{'DRUID',.5,.5,true},{'SHAMAN',-1,0,false},{'DRUID',-.5,0,false},{'SHAMAN',1,0,false}}) do
  local _,a,s=fixture(nil,case[1]);s.value=case[2];local v=node(case[3]);assert(a.conditionDefinitions.FORM.valid(0,v));local r=a:evaluateConditionResult(v);assert(r.status==(case[4] and 'match' or 'no-match'));assert(a:evaluateConditionResult({type='NOT',value=v}).status==(case[4] and 'no-match' or 'match'))
  local selected;local body={rotation={{id='form',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end);assert(selected==(case[4] and 'yes' or 'no'))
 end
end)
test('captured SHAMAN validation needs no count and evaluator adds no class count or unit reads',function()
 local f,a,s=fixture();f.env.GetNumShapeshiftForms=function() error('SHAMAN count must not run') end;f.env.UnitClass=function() error('captured class was queried again') end;f.env.UnitExists=function() error('form queried an actor') end
 for _,value in ipairs({0,1,.5}) do local v=node(value);assert(a.conditionDefinitions.FORM.valid(0,v));s.value=value;assert(a:evaluateConditionResult(v).status=='match') end
 assert(not a.conditionDefinitions.FORM.valid(0,node(2)) and s.countCalls==0)
 f,a,s=fixture(nil,'DRUID');local eval=a.conditionDefinitions.FORM.evaluate;s.value=4;assert(eval(node(4),{})==true and s.countCalls==0,'evaluator added a count ceiling');assert(not a.conditionDefinitions.FORM.valid(0,node(4)) and s.countCalls==1)
end)
test('normalized complete tuple caches by method self and pass without longterm storage',function()
 local _,a,s=fixture();local eval=a.conditionDefinitions.FORM.evaluate;local cache={};s.value=nil;local value,why=eval(node(),cache);assert(value==nil and why=='form-unavailable' and s.calls==1)
 s.value=0;local again,reason=eval(node(),cache);assert(again==nil and reason==why and s.calls==1);assert(eval(node(),{})==true and s.calls==2)
 local other=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,a.Platform.GetPlayerFormObservation,other)==0 and s.calls==3)
 assert(eval(node())==true and eval(node())==true and s.calls==5 and next(a.longtermCache)==nil)
end)
test('unsupported policies and transient failures never choose actions and recover next pass',function()
 for _,project in ipairs({999}) do local _,a,s=fixture(project);unknown(a,node());assert(s.calls==0) end
 local _,a,s=fixture();s.throw=true;unknown(a,node());s.throw=nil;assert(a:evaluateConditionResult(node()).status=='match')
end)
test('current editable duplicate shares actual normalized owner and unknown cache tuple',function()
 local _,a,s=fixture();copy(a);local cache={};assert(a.conditionDefinitions.FORM.evaluate(node(),cache)==true and a.conditionDefinitions.COPY_FORM.evaluate(node(0,'COPY_FORM'),cache)==true and s.calls==1)
 s.value=nil;unknown(a,node(0,'COPY_FORM'));s.value=.5;assert(a:evaluateConditionResult(node(.5,'COPY_FORM')).status=='match')
end)
test('public helper getter and executable editable source resolve actual zero-argument owner',function()
 local f,a,s=fixture();local id='builtin:Platform/form.lua:Platform_GetPlayerFormObservation';local record=assert(a.builtinFunctions[id],'form public catalog missing');assert(a:ResolveFunctionBinding(id)==a.Platform.GetPlayerFormObservation and a.builtinSourceModules['Platform/form.lua']('Platform_GetPlayerFormObservation')==a.Platform.GetPlayerFormObservation)
 assert(#record.source.args==1 and record.source.args[1].type=='RMPlatform' and #record.source.description>0)
 assert(a:InstallCustomFunction('COPY_FORM_OBSERVER',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_FORM_OBSERVER');assert(fn(a.Platform)==0);s.value=-.25;assert(fn(a.Platform)==-.25)
 local opaque={};s.value=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;local value,why=fn(a.Platform);assert(value==nil and why=='restricted-value')
end)
test('old saved raw callback keeps equality semantics and source remains unchanged',function()
 local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('FORM'));source.evaluate='\n        return Functions.cache.getCached(cache, GetShapeshiftForm) == value.value\n    ';local before=a:CopySettingsData(source)
 local definition=assert(a:CompileCustomCondition('SAVED_FORM',source));a:RegisterCondition('SAVED_FORM',definition);s.value=nil;assert(definition.evaluate(node(),{})==false and a:evaluateConditionResult({type='NOT',value=node(0,'SAVED_FORM')}).status=='match');s.value=.5;assert(definition.evaluate(node(.5),{})==true);assert(a:SettingsDataEqual(before,source))
end)
test('only exact FORM evaluate changes and all private source identities remain intact',function()
 local _,a=fixture();local file=assert(io.open('Conditions/combat.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_threat_count_repairs.lua')(dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(dofile('tests/fixtures/restore_form_presentation_repairs.lua')(dofile('tests/fixtures/restore_form_localization.lua')(text))));text=dofile('tests/fixtures/restore_combat_time_repairs.lua')(text);text=dofile('tests/fixtures/restore_form_repairs.lua')(text);assert(a:FunctionSourceHash(text)=='58118515','combat differs from75f8297 beyond FORM evaluate')
 for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name)) end
end)
finish()
