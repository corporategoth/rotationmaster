local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path) local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
-- One process snapshot: no repeated catalog reads while other owners generate.
local catalogText=read('Data/builtin_sources.lua')
local tags={'TT_HEALTH','TT_HEALTHPCT'}
local function fixture(project)
 local f=F.new(project or 11,2,'MAGE');local a,e=f.addon,f.env;local s={exists=true,guid='GUID-target',current=90,maximum=100,now=100,calls={}};local opaque={}
 local function query(key,...) if key=='clock' then assert(select('#',...)==0) else assert(select('#',...)==1 and ((...)=='target' or (...)=='pet')) end;s.calls[#s.calls+1]=key;if s.throw==key then error('forecast query failed') end;return s[key] end
 e.UnitExists=function(...) return query('exists',...) end;e.UnitGUID=function(...) return query('guid',...) end;e.UnitHealth=function(...) return query('current',...) end;e.UnitHealthMax=function(...) return query('maximum',...) end;e.GetTime=function(...) query('clock',...);return s.now end;e.canaccessvalue=function(v) return not rawequal(v,opaque) end
 for _,path in ipairs({'Platform/health_forecast.lua','Functions/forecast.lua','Core/health_forecast_conditions.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
 a.db.profile.damage_history=10;a.damageHistory={['GUID-target']={damage={{time=99,value=10},{time=97,value=10}},heals={}}}
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 local chunk=assert(loadstring(catalogText,'@process-catalog-snapshot'));setfenv(chunk,e);chunk('rotationmaster',a);f.load('Core/builtin_sources.lua')
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 return f,a,s,opaque
end
local function node(tag) return {type=tag or 'TT_HEALTH',unit='target',health=tag=='TT_HEALTHPCT' and .5 or 50,value=0,operator='EQUALS'} end
local function valid(a,v) assert(a.conditionDefinitions[v.type].valid(0,v),'invalid forecast setup') end
local function branch(a,v)
 local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local r=a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end);return r,selected
end
local function unknown(a,v)
 valid(a,v);local r=a:evaluateConditionResult(v);assert(r.status=='unavailable' and r.reason~='condition-callback-error',tostring(r.status)..':'..tostring(r.reason))
 for _,n in ipairs({{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do assert(a:evaluateConditionResult(n).status=='unavailable','unknown became actionable logical result') end
 local result,selected=branch(a,v);assert(result.status=='unavailable' and selected==nil,'unknown selected branch');result,selected=branch(a,{type='NOT',value=v});assert(result.status=='unavailable' and selected==nil)
end
local function eval(a,tag,cache,v) return a.conditionDefinitions[tag].evaluate(v or node(tag),cache) end
local function rate(a,n,seconds,reason) assert(a.Functions.forecast,'new forecast kernel missing');a.Functions.forecast.calculate=function() return n,seconds,reason end end
test('nil malformed opaque GUID and required native values remain recoverable unknown through NOT and branches',function()
 for _,key in ipairs({'exists','guid','current'}) do for _,mode in ipairs({'nil','opaque','throw','missing','nan'}) do local f,a,s,opaque=fixture()
  if mode=='nil' then s[key]=nil elseif mode=='opaque' then s[key]=opaque elseif mode=='throw' then s.throw=key elseif mode=='missing' then f.env[key=='exists' and 'UnitExists' or key=='guid' and 'UnitGUID' or 'UnitHealth']=nil else s[key]=0/0 end
  for _,tag in ipairs(tags) do unknown(a,node(tag)) end
  if mode~='missing' then s.exists=true;s.guid='GUID-target';s.current=50;s.throw=nil;for _,tag in ipairs(tags) do assert(a:evaluateConditionResult(node(tag)).status=='match','recovered observation quarantined') end end
 end end
end)
test('known absence skips later native facts provider target and thresholds without becoming unknown',function()
 local f,a,s,opaque=fixture();s.exists=false;f.env.UnitGUID=function() error('absent GUID queried') end;f.env.RealMobHealth=opaque
 for _,tag in ipairs(tags) do local v=node(tag);assert(eval(a,tag,{},v)==false);v.health=opaque;v.value=opaque;assert(eval(a,tag,{},v)==false);assert(a:evaluateConditionResult({type='NOT',value=node(tag)}).status=='match') end
end)
test('exact equality and percentage zero controls skip history mode window and kernel clock',function()
 local _,a,s,opaque=fixture();s.current=50;a.damageHistory=nil;a.db.profile.damage_history=opaque
 for _,tag in ipairs(tags) do local v=node(tag);v.mode=opaque;assert(eval(a,tag,{},v)==true) end
 s.current=0;s.maximum=0;assert(eval(a,'TT_HEALTHPCT',{},node('TT_HEALTHPCT'))==true)
 local v=node();v.health=-10;s.current=90;s.maximum=100;assert(eval(a,'TT_HEALTH',{},v)==true)
 for _,call in ipairs(s.calls) do assert(call~='clock','shortcut consumed helper clock') end
end)
test('normalized cache shares identity current maximum nil tuples and isolates selected actors',function()
 local _,a,s=fixture();local cache={};local v=node();v.health=-10;assert(eval(a,'TT_HEALTH',cache,v));assert(eval(a,'TT_HEALTHPCT',cache)==false)
 assert(table.concat(s.calls,',')=='exists,guid,current,maximum,clock','native tuple/query sharing changed')
 s.current=nil;cache={};local result,why=eval(a,'TT_HEALTH',cache);assert(result==nil and type(why)=='string');s.current=50;local again,reason=eval(a,'TT_HEALTHPCT',cache);assert(again==nil and reason==why);assert(eval(a,'TT_HEALTH',{})==true)
 s.calls={};cache={};v=node();v.health=50;assert(eval(a,'TT_HEALTH',cache,v));v.unit='pet';assert(eval(a,'TT_HEALTH',cache,v));assert(table.concat(s.calls,',')=='exists,guid,current,exists,guid,current')
end)
test('percentage provider remains fresh independently partial and cannot hide failed metadata behind native cache',function()
 local f,a,s,opaque=fixture();local current,maximum=nil,180;local providerCalls=0
 f.env.RealMobHealth={GetUnitHealth=function(...) assert(select('#',...)==1 and (...)=='target');providerCalls=providerCalls+1;return current,maximum,opaque end}
 local cache={};assert(eval(a,'TT_HEALTHPCT',cache));maximum=100;assert(eval(a,'TT_HEALTHPCT',cache)==false and providerCalls==2)
 current=50;assert(eval(a,'TT_HEALTHPCT',cache));current=opaque;local r,why=eval(a,'TT_HEALTHPCT',cache);assert(r==nil and why=='restricted-value');unknown(a,node('TT_HEALTHPCT'))
 local before=providerCalls;assert(eval(a,'TT_HEALTH',{})==false and providerCalls==before,'absolute forecast queried provider')
end)
test('history root unavailable differs from missing entry and no estimate never consumes threshold',function()
 for _,root in ipairs({false,1,{}}) do local _,a=fixture();a.damageHistory=root;if type(root)=='table' then for _,tag in ipairs(tags) do assert(eval(a,tag,{})==false) end else for _,tag in ipairs(tags) do unknown(a,node(tag)) end end end
 local _,a,_,opaque=fixture();a.damageHistory=nil;for _,tag in ipairs(tags) do unknown(a,node(tag)) end
 a.damageHistory={['GUID-target']=false};for _,tag in ipairs(tags) do local v=node(tag);v.value=opaque;assert(eval(a,tag,{},v)==false) end
 a.damageHistory={['GUID-target']={damage={},heals={}}};for _,tag in ipairs(tags) do local v=node(tag);v.value=opaque;assert(eval(a,tag,{},v)==false) end
end)
test('initialized zero no-estimate and strict age gate preserve all operator results separately',function()
 local _,a=fixture();for _,tag in ipairs(tags) do for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE'}) do local v=node(tag);v.operator=operator;v.value=1
  for _,r in ipairs({0,10}) do rate(a,r,3);assert(eval(a,tag,{},v)==a.compare(operator,0,1)) end
  rate(a,-1,2);assert(eval(a,tag,{},v)==false);rate(a,false,nil);assert(eval(a,tag,{},v)==false);rate(a,nil,nil);assert(eval(a,tag,{},v)==false)
 end end
end)
test('budget and malformed rate or derived arithmetic reasons propagate before no-estimate mapping',function()
 local _,a,s,opaque=fixture();for _,tag in ipairs(tags) do rate(a,nil,nil,'forecast-work-budget');unknown(a,node(tag))
  for _,bad in ipairs({opaque,0/0,math.huge,'rate'}) do rate(a,bad,3);unknown(a,node(tag)) end
  rate(a,0,nil);unknown(a,node(tag));rate(a,0,math.huge);unknown(a,node(tag))
 end
 rate(a,-1e-308,3);s.current=1e308;for _,tag in ipairs(tags) do local v=node(tag);v.health=0;v.operator='GREATERTHAN';unknown(a,v) end
end)
test('required maximum targets windows and kernel exceptions recover without quarantine',function()
 for _,mode in ipairs({'maximum','target','window','kernel'}) do local _,a,s,opaque=fixture();local actual=a.Functions.forecast.calculate
  for _,tag in ipairs(tags) do s.current=90;s.maximum=100;local v=node(tag);if mode=='maximum' then s.maximum=opaque;if tag=='TT_HEALTH' then v.health=-10 end elseif mode=='target' then v.health=math.huge;if tag=='TT_HEALTHPCT' then v.health=.5;s.current=0/0 end elseif mode=='window' then a.db.profile.damage_history=opaque else a.Functions.forecast.calculate=function() error('checked kernel override failed') end end
   unknown(a,v)
   s.maximum=100;s.current=50;a.db.profile.damage_history=10;a.Functions.forecast.calculate=actual;v=node(tag);assert(a:evaluateConditionResult(v).status=='match','forecast observation was quarantined')
  end
 end
 local _,a=fixture();for _,tag in ipairs(tags) do local v=node(tag);v.value=math.huge;unknown(a,v) end
end)
test('restricted and unsupported policies deny forecasts through actual logical control flow',function()
 for _,project in ipairs({999}) do local _,a,s=fixture(project);for _,tag in ipairs(tags) do unknown(a,node(tag)) end;for _,call in ipairs(s.calls) do assert(call=='clock','policy queried selected unit') end end
end)
test('actual bounded kernel handles stale finite row and malformed history without quarantine',function()
 local _,a,s,opaque=fixture();assert(a.Functions.forecast,'bounded forecast missing');for _,history in ipairs({{damage={{time=-1e308,value=1}},heals={}},{damage={{time=97,value=math.huge}},heals={}},{damage={{time=opaque,value=10}},heals={}}}) do a.damageHistory['GUID-target']=history;for _,tag in ipairs(tags) do unknown(a,node(tag)) end end
 a.damageHistory['GUID-target']={damage={{time=99,value=10},{time=97,value=10}},heals={}};for _,tag in ipairs(tags) do assert(a:evaluateConditionResult(node(tag)).status=='no-match') end
 s.now=math.huge;for _,tag in ipairs(tags) do unknown(a,node(tag)) end
end)
test('public Core override ETA and consumed threshold cannot authorize malformed numeric comparisons',function()
 local _,a,_,opaque=fixture();for _,bad in ipairs({opaque,{},true,'0',0/0,math.huge}) do a.GetConditionHealthForecast=function() return bad end;for _,tag in ipairs(tags) do unknown(a,node(tag)) end end
 a.GetConditionHealthForecast=function() return 0 end;for _,bad in ipairs({opaque,{},true,'0',0/0,math.huge}) do for _,tag in ipairs(tags) do local v=node(tag);v.value=bad;local r,why=eval(a,tag,{},v);assert(r==nil and type(why)=='string') end end
end)
test('current editable copies and new public helper copies use actual owned normalized services',function()
 local f,a,s,opaque=fixture();for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('GetConditionHealthForecast',1,true),'forecast catalog pending');a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)));local v=node(tag);v.type='COPY_'..tag;s.guid=nil;unknown(a,v);s.guid='GUID-target';s.current=50;assert(a:evaluateConditionResult(v).status=='match') end
 for _,id in ipairs({'builtin:Platform/health_forecast.lua:Platform_GetHealthForecastIdentityObservation','builtin:Platform/health_forecast.lua:Platform_GetHealthForecastValueObservation','builtin:Platform/health_forecast.lua:Platform_GetHealthForecastProviderObservation','builtin:Platform/health_forecast.lua:Platform_GetHealthForecastTimeObservation','builtin:Functions/forecast.lua:Forecast_calculate','builtin:Core/health_forecast_conditions.lua:GetConditionHealthForecast'}) do
  local record=assert(a.builtinFunctions[id],'forecast helper catalog missing '..id);local name='COPY_FORECAST_'..id:gsub('[^%w_]','_');assert(a:InstallCustomFunction(name,a:CopySettingsData(record.source)));local fn=assert(a:ResolveFunctionBinding(name))
  if id:find('Identity',1,true) then assert(fn(a.Platform,'target')=='GUID-target') elseif id:find('Value',1,true) then assert(fn(a.Platform,'target','current')==50) elseif id:find('Provider',1,true) then assert(next(fn(a.Platform,'target'))==nil) elseif id:find('Time',1,true) then assert(fn(a.Platform)==100) elseif id:find('Functions/',1,true) then local r,seconds=fn(a.Platform,{damage={{time=97,value=10}},heals={}},10,false,false,100);assert(r<0 and seconds==3) else assert(fn(a,'target',50,false,nil,{})==0) end
 end
 s.guid=opaque;local id='builtin:Core/health_forecast_conditions.lua:GetConditionHealthForecast';local name='COPY_FORECAST_'..id:gsub('[^%w_]','_');local fn=a:ResolveFunctionBinding(name);local r,why=fn(a,'target',50,false,nil,{});assert(r==nil and why=='restricted-value')
end)
test('saved raw current-baseline callbacks retain old dispatch behavior without stored source rewrite',function()
 local _,oldBodies,_,oldBindings=dofile('tests/fixtures/restore_health_forecast_repairs.lua');local _,a,s=fixture();for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=oldBodies[tag];source.bindings=a:CopySettingsData(oldBindings[tag]);local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW=source};a:RegisterCondition('RAW_'..tag,assert(a:CompileCustomCondition('RAW_'..tag,source)));s.guid=nil;local v=node(tag);v.type='RAW_'..tag;assert(a:evaluateConditionResult({type='NOT',value=v}).status=='match');assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions.RAW==source);s.guid='GUID-target' end
end)
test('only exact2 evaluator bodies change with full baseline inverse and every historical helper identity',function()
 local inverse,oldBodies,newBodies=dofile('tests/fixtures/restore_health_forecast_repairs.lua');local _,a=fixture();local text=dofile('tests/fixtures/restore_resource_deficit_summary_repairs.lua')(read('Conditions/stats.lua'));assert(a:FunctionSourceHash(inverse(text))=='fdc91f06','stats changed beyond2 evals from ad20b47');assert(not pcall(inverse,text..text))
 for _,tag in ipairs(tags) do assert(inverse(newBodies[tag],tag,true)==oldBodies[tag]);assert(not pcall(inverse,oldBodies[tag],tag,true));assert(not pcall(inverse,newBodies[tag]..' ',tag,true)) end
 assert(a:FunctionSourceHash(read('Functions/trends.lua'))=='f7f8df96','published legacy trends file changed')
 for name,hash in pairs({color='89107d36',helpers='c19dbbac'}) do assert(a:FunctionSourceHash(a.builtinFunctions['builtin:Conditions/stats.lua:'..name].source)==hash) end
 for name,hash in pairs({calculate='26e53807',calculateOld='a7c35d84'}) do local id='builtin:Functions/trends.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.Functions.trends[name]) end
end)
finish()
