local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local old=[=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local class
        if value.unit == "player" then
            class = select(2, Functions.cache.getCached(addon.longtermCache, UnitClass, value.unit))
        else
            class = select(2, Functions.cache.getCached(cache, UnitClass, value.unit))
        end
        if class ~= nil then
            local point = addon.points[class] or Enum.PowerType.ComboPoints
            local cur = Functions.cache.getCached(cache, UnitPower, value.unit, point)
            if value.value < 0 then
                local max = Functions.cache.getCached(cache, UnitPowerMax, value.unit, point)
                return Functions.values.compare(value.operator, (max-cur), -value.value)
            else
                return Functions.values.compare(value.operator, cur, value.value)
            end
        else
            return false
        end
    end,]=]
local repaired=[=[    evaluate = function(value, cache)
        local point,reason=addon:GetConditionPointResource(value.unit,cache)
        if point==nil then return nil,reason end
        if point==false then return false end
        local cur,why=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"current")
        if cur==nil then return nil,why end
        if value.value < 0 then
            local maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"maximum")
            if maximum==nil then return nil,maximumReason end
            local deficit=maximum-cur
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-point-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,]=]
local function fixture(project)
 local f=F.new(project or 11,2,'MAGE');local a,e=f.addon,f.env;local s={exists=true,class='MAGE',current=3,maximum=5,calls={}}
 local function call(k,...) s.calls[#s.calls+1]={k,n=select('#',...),...};if s.throw==k then error('native points failure') end;return s[k] end
 e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end;e.UnitClass=function(...) assert(select('#',...)==1);call('class',...);return s.label,s.class,s.id end
 e.UnitPower=function(...) assert(select('#',...)==2);return call('current',...) end;e.UnitPowerMax=function(...) assert(select('#',...)==2);return call('maximum',...) end
 e.UnitPowerType=function() error('POINT primary resource reinterpretation') end;e.GetComboPoints=function() error('POINT actor reinterpretation') end
 for _,p in ipairs({'Platform/points.lua','Core/point_conditions.lua'}) do local file=io.open(p);if file then file:close();f.load(p) end end
 for _,p in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(p) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.calls={}
 return f,a,s
end
local function node(amount,unit,operator,tag) return {type=tag or 'POINT',unit=unit or 'target',value=amount or 3,operator=operator or 'EQUALS'} end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid POINT fixture')
 for _,n in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local r=a:evaluateConditionResult(n);assert(r.status=='unavailable' and r.reason~='invalid-condition-fields','unknown points became actionable: '..r.status) end
 for _,n in ipairs({v,{type='NOT',value=v}}) do local body={rotation={{id='guard',type='branch',conditions=n,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unknown POINT selected branch') end).status=='unavailable') end
end
local function count(s,key) local n=0;for _,c in ipairs(s.calls) do if c[1]==key then n=n+1 end end;return n end
local function copy(a) local source=assert(a:GetBuiltinConditionSource('POINT'));assert(source.evaluate:find('GetConditionPointResource',1,true),'POINT catalog stale');a:RegisterCondition('COPY_POINT',assert(a:CompileCustomCondition('COPY_POINT',source)));return source end
test('missing nil restricted malformed facts remain unavailable through actual NOT groups and branches',function()
 for _,key in ipairs({'exists','class','current','maximum'}) do for _,mode in ipairs({'nil','missing','throw','opaque','bad','nan','inf'}) do
  local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
  if mode=='nil' then s[key]=nil elseif mode=='missing' then f.env[({exists='UnitExists',class='UnitClass',current='UnitPower',maximum='UnitPowerMax'})[key]]=nil elseif mode=='throw' then s.throw=key elseif mode=='opaque' then s[key]=opaque elseif mode=='bad' then s[key]={} elseif mode=='nan' then s[key]=0/0 else s[key]=math.huge end
  unknown(a,node(key=='maximum' and -2 or 3))
 end end
end)
test('finite quantities preserve signed fractions zero negative maxima and exact actor order',function()
 for _,case in ipairs({{3,5,3},{0,5,0},{.5,5,.5},{-1,5,1,'LESSTHAN'},{3,5,-2},{-2,0,-2},{-3,-1,-2},{7,5,-1,'LESSTHAN'}}) do
  local _,a,s=fixture();s.current,s.maximum=case[1],case[2];local v=node(case[3],'pet',case[4]);assert(a.conditionDefinitions.POINT.valid(0,v));assert(a:evaluateConditionResult(v).status=='match');assert(a:evaluateConditionResult({type='NOT',value=v}).status=='no-match')
  assert(s.calls[1][1]=='exists' and s.calls[2][1]=='class' and s.calls[3][1]=='current');for _,call in ipairs(s.calls) do assert(call[2]=='pet' and call.n==((call[1]=='exists' or call[1]=='class') and 1 or 2)) end
 end
 local f,a,s=fixture();s.exists=false;f.env.UnitClass=nil;f.env.UnitPower=nil;assert(a:evaluateConditionResult(node()).status=='no-match' and a:evaluateConditionResult({type='NOT',value=node()}).status=='match' and count(s,'exists')==2)
end)
test('only deficit needs maximum and nonfinite derived deficit remains unknown',function()
 local f,a,s=fixture();f.env.UnitPowerMax=nil;assert(a:evaluateConditionResult(node()).status=='match');unknown(a,node(-2))
 f,a,s=fixture();s.current=-1e308;s.maximum=1e308;unknown(a,node(-2,nil,'GREATERTHAN'))
end)
test('live map and lazy fallback preserve zero future classes and unavailable selection',function()
 local f,a,s=fixture();local eval=a.conditionDefinitions.POINT.evaluate;local cache={};assert(eval(node(),cache));a.points.MAGE=0;assert(eval(node(),cache));assert(s.calls[#s.calls][3]==0 and count(s,'exists')==1)
 a.points.MAGE=false;assert(eval(node(),cache));assert(s.calls[#s.calls][3]==f.env.Enum.PowerType.ComboPoints)
 f,a,s=fixture();f.env.Enum=nil;assert(a:evaluateConditionResult(node()).status=='match');a.points.MAGE=nil;unknown(a,node())
 for _,bad in ipairs({{},'4',-.5,0/0,math.huge}) do f,a,s=fixture();a.points.MAGE=bad;unknown(a,node());assert(count(s,'current')==0) end
 f,a,s=fixture();s.class='FUTURE_CLASS';assert(a:evaluateConditionResult(node()).status=='match' and s.calls[#s.calls][3]==f.env.Enum.PowerType.ComboPoints)
 f,a,s=fixture();local opaque={};s.label=opaque;s.id=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;assert(a:evaluateConditionResult(node()).status=='match');a.points.MAGE=opaque;unknown(a,node())
 f,a,s=fixture();a.points=setmetatable({},{__index=function() error('map lookup failure') end});unknown(a,node())
end)
test('current and maximum kinds share current snapshot across positive and deficit nodes',function()
 for _,reverse in ipairs({false,true}) do local _,a,s=fixture();local eval=a.conditionDefinitions.POINT.evaluate;local cache={}
  assert(eval(node(reverse and -2 or 3),cache));s.current=4;assert(eval(node(reverse and 3 or -2),cache));assert(count(s,'exists')==1 and count(s,'class')==1 and count(s,'current')==1 and count(s,'maximum')==1)
  assert(eval(node(4),{}) and count(s,'current')==2);assert(eval(node(4)) and eval(node(4)) and count(s,'current')==4)
 end
 local _,a,s=fixture();s.current=nil;local eval=a.conditionDefinitions.POINT.evaluate;local cache={};local v,why=eval(node(),cache);assert(v==nil and why=='point-power-unavailable');s.current=3;local n,reason=eval(node(),cache);assert(n==nil and reason==why and count(s,'current')==1);assert(eval(node(),{}))
end)
test('successful player class persists only by native identity while existence refreshes per pass',function()
 local f,a,s=fixture();local eval=a.conditionDefinitions.POINT.evaluate;local cache={};assert(eval(node(3,'player'),cache));assert(eval(node(-2,'player'),cache));assert(count(s,'exists')==1 and count(s,'class')==1)
 s.class='WARLOCK';assert(eval(node(3,'player'),{}));assert(count(s,'exists')==2 and count(s,'class')==1 and s.calls[#s.calls][3]==a.points.MAGE)
 local before=f.env.UnitClass;f.env.UnitClass=function(unit) s.calls[#s.calls+1]={'replacement',unit};return nil,'WARLOCK' end;assert(eval(node(3,'player'),cache) and count(s,'replacement')==0);assert(eval(node(3,'player'),{}) and count(s,'replacement')==1 and s.calls[#s.calls][3]==a.points.WARLOCK)
 a.longtermCache={};assert(eval(node(3,'player'),{}) and count(s,'replacement')==2);a.longtermCache=nil;assert(eval(node(3,'player'),{}) and eval(node(3,'player'),{}) and count(s,'replacement')==4)
 f.env.UnitClass=before;s.exists=false;f.env.UnitPower=nil;assert(eval(node(3,'player'),{})==false)
end)
test('unknown player classes retry next pass and malformed owned success entries recover',function()
 local f,a,s=fixture();local eval=a.conditionDefinitions.POINT.evaluate;s.class=nil;local cache={};local v,why=eval(node(3,'player'),cache);assert(v==nil and why=='point-class-unavailable');s.class='MAGE';assert(eval(node(3,'player'),cache)==nil and count(s,'class')==1);assert(eval(node(3,'player'),{})==true and count(s,'class')==2)
 local getter=assert(a.builtinSourceModules['Core/point_conditions.lua']);local key=assert(getter('playerClassCacheKey'));local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
 for _,bad in ipairs({{},opaque,{api=f.env.UnitClass,class=opaque},{api=f.env.UnitClass,class=''}}) do a.longtermCache[key]=bad;local before=count(s,'class');assert(eval(node(3,'player'),{}) and count(s,'class')==before+1) end
end)
test('unsupported policy and transient errors do not quarantine and recover next pass',function()
 for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a,node());assert(#s.calls==0) end
 local _,a,s=fixture();s.throw='class';unknown(a,node(3,'player'));s.throw=nil;assert(a:evaluateConditionResult(node(3,'player')).status=='match')
end)
test('current editable copies and actual public helper clones share canonical cache authority',function()
 local _,a,s=fixture();copy(a);local cache={};assert(a.conditionDefinitions.POINT.evaluate(node(3,'player'),cache) and a.conditionDefinitions.COPY_POINT.evaluate(node(-2,'player',nil,'COPY_POINT'),cache));assert(count(s,'exists')==1 and count(s,'class')==1 and count(s,'current')==1)
 for _,case in ipairs({{'Core/point_conditions.lua','GetConditionPointResource'},{'Platform/points.lua','Platform_GetUnitPointIdentityObservation'},{'Platform/points.lua','Platform_GetUnitPointPowerObservation'}}) do
  local id='builtin:'..case[1]..':'..case[2];local record=assert(a.builtinFunctions[id],'public POINT source missing');assert(record.get()==a.builtinSourceModules[case[1]](case[2]));assert(a:InstallCustomFunction('COPY_'..case[2],a:CopySettingsData(record.source)))
 end
 local fn=a:ResolveFunctionBinding('COPY_GetConditionPointResource');assert(fn(a,'player',cache)==a.points.MAGE and count(s,'exists')==1)
 local source=a.builtinFunctions['builtin:Core/point_conditions.lua:GetConditionPointResource'].source;assert(source.bindings.playerClassCacheKey=='builtin:Core/point_conditions.lua:playerClassCacheKey' and source.bindings.pointIdentity=='builtin:Core/point_conditions.lua:pointIdentity')
 assert(a:ResolveFunctionBinding(source.bindings.playerClassCacheKey)==a.builtinSourceModules['Core/point_conditions.lua']('playerClassCacheKey'))
 local identity=a:ResolveFunctionBinding('COPY_Platform_GetUnitPointIdentityObservation');assert(identity(a.Platform,'pet',true).class=='MAGE')
 local quantity=a:ResolveFunctionBinding('COPY_Platform_GetUnitPointPowerObservation');s.maximum=-.5;assert(quantity(a.Platform,'pet',0,'maximum')==-.5)
end)
test('saved raw callbacks retain old nil class caching and source unchanged',function()
 local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('POINT'));source.evaluate=assert(old:match('function%([^\n]*%)(.*)end,$'));local before=a:CopySettingsData(source);local d=assert(a:CompileCustomCondition('RAW_POINT',source));a:RegisterCondition('RAW_POINT',d)
 s.class=nil;assert(d.evaluate(node(3,'player'),{})==false);s.class='MAGE';assert(d.evaluate(node(3,'player'),{})==false and count(s,'class')==1);assert(a:SettingsDataEqual(before,source))
end)
test('whole stats exact inverse protects unrelated callbacks fields prose and private identities',function()
 local _,a=fixture();local file=assert(io.open('Conditions/stats.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_health_forecast_repairs.lua')(text);text=dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')(text);text=dofile('tests/fixtures/restore_rune_repairs.lua')(text);text=dofile('tests/fixtures/restore_health_forecast_deficit.lua')(text);local first=assert(text:find(repaired,1,true),'exact POINT repair missing');assert(not text:find(repaired,first+1,true));text=text:sub(1,first-1)..old..text:sub(first+#repaired);assert(a:FunctionSourceHash(text)=='7509f04c','stats changed beyond POINT evaluate and the explicit TT_HEALTH guard')
 for name,hash in pairs({color='89107d36',helpers='c19dbbac'}) do local id='builtin:Conditions/stats.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/stats.lua'](name)) end
end)
test('isolated unit receiver selector and native enum access preserve lazy unknown boundaries',function()
 local f,a,s=fixture();local cache={};assert(a:GetConditionPointResource('target',cache)==a.points.MAGE)
 assert(a:GetConditionPointResource('pet',cache)==a.points.MAGE and count(s,'exists')==2)
 local other=setmetatable({},{__index=a});assert(other:GetConditionPointResource('target',cache)==a.points.MAGE and count(s,'exists')==3)
 local cur=a.Platform.GetUnitPointPowerObservation;assert(a.Functions.cache.getCached(cache,cur,a.Platform,'target',0,'current')==3)
 s.current=7;assert(a.Functions.cache.getCached(cache,cur,a.Platform,'target',0,'current')==3)
 assert(a.Functions.cache.getCached(cache,cur,a.Platform,'pet',0,'current')==7)
 local platform=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,cur,platform,'target',0,'current')==7)
 local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
 local before=#s.calls;local n,why=a:GetConditionPointResource(opaque,cache);assert(n==nil and why=='restricted-value' and #s.calls==before)
 for _,mutate in ipairs({function(e) e.Enum=opaque end,function(e) e.Enum.PowerType=opaque end,function(e) e.Enum.PowerType.ComboPoints=opaque end,function(e) e.Enum=setmetatable({},{__index=function() error('enum access') end}) end}) do
  local ff,aa,ss=fixture();aa.points.MAGE=nil;ff.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;mutate(ff.env);unknown(aa,node());assert(count(ss,'current')==0)
 end
end)
test('known matching differing and absent facts select the original branch arms',function()
 for _,case in ipairs({{true,3,'yes'},{true,4,'no'},{false,3,'no'}}) do local _,a,s=fixture();s.exists,s.current=case[1],case[2]
  local selected;local body={rotation={{id='point',type='branch',conditions=node(),onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
  local result=a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function(v) selected=v.id;return true end);assert(result.status=='complete' and selected==case[3])
 end
end)
finish()
