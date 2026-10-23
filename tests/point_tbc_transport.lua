-- Explicit TBC transport policy versus actual pre-slice compiled source; no native failure claim.
local inverse,oldBody,newBody=dofile('tests/fixtures/restore_point_tbc_transport.lua')
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project,combo)
 local f=F.new(project or 5,1,'ROGUE');local a,e=f.addon,f.env;local s={calls={},current=0,maximum=5,combo=5,class='ROGUE',exists=true}
 e.Enum.PowerType.ComboPoints=combo or 4;f.load('Core/point_conditions.lua')
 local function call(k,...)s.calls[#s.calls+1]={k,...};if s.fail==k then error('private marker')end;return s[k]end
 e.UnitExists=function(unit)return call('exists',unit)end;e.UnitClass=function(unit)call('class',unit);return 'Rogue',s.class end
 e.UnitPower=function(unit,p)return call('current',unit,p)end;e.UnitPowerMax=function(unit,p)return call('maximum',unit,p)end;e.GetComboPoints=function(unit,target)return call('combo',unit,target)end
 for _,p in ipairs({'Platform/points.lua','Core/point_conditions.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(p)end
 e.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,e)end;return fn,why end
 local old=assert(a:GetBuiltinConditionSource('POINT'));assert(old.evaluate==oldBody or old.evaluate==newBody);old=a:CopySettingsData(old);old.evaluate=oldBody;a:RegisterCondition('ARCHIVED_POINT',assert(a:CompileCustomCondition('ARCHIVED_POINT',old)));s.calls={};return f,a,s,old
end
local function node(v,unit,tag)return {type=tag or'POINT',unit=unit or'player',operator='EQUALS',value=v or 5}end
local function count(s,k)local n=0;for _,r in ipairs(s.calls)do if r[1]==k then n=n+1 end end;return n end
local function status(a,n)return a:evaluateConditionResult(n).status end
local function unknown(a,n)assert(status(a,n)=='unavailable');assert(status(a,{type='NOT',value=n})=='unavailable')end
test('controlled divergence only: old source uses UnitPower and current policy uses owner-target combo',function()
 local _,a,s=fixture();assert(status(a,node())=='match'and count(s,'combo')==1 and count(s,'current')==0);assert(s.calls[3][2]=='player'and s.calls[3][3]=='target');assert(status(a,node(5,'player','ARCHIVED_POINT'))=='no-match'and count(s,'current')==1)
end)
test('agreeing transports preserve result and fresh passes see changed target observation',function()
 local _,a,s=fixture();s.current=5;assert(status(a,node())=='match'and status(a,node(5,'player','ARCHIVED_POINT'))=='match')
 s.current=0;s.combo=0;assert(status(a,node())=='no-match'and status(a,node(5,'player','ARCHIVED_POINT'))=='no-match')
 assert(status(a,node(0))=='match');for _,row in ipairs(s.calls)do if row[1]=='exists'then assert(row[2]=='player')end end
end)
test('TBC14 and Anniversary4 use live enum capacity and current-before-maximum',function()
 for _,id in ipairs({4,14})do local _,a,s=fixture(5,id);s.combo=3;assert(status(a,node(-2))=='match');local last=s.calls[#s.calls];assert(last[1]=='maximum'and last[2]=='player'and last[3]==id);assert(s.calls[#s.calls-1][1]=='combo')end
end)
test('direct consumer keeps target pet party vehicle actor; schema admission unchanged',function()
 for _,unit in ipairs({'target','pet','party1','vehicle'})do local _,a,s=fixture();s.current=5;assert(a.conditionDefinitions.POINT.evaluate(node(5,unit),{})==true and count(s,'combo')==0 and s.calls[#s.calls][2]==unit)end
end)
test('all explicit map entries including combo numeric keep existing transport',function()
 for _,selector in ipairs({0,4,14,7})do local _,a,s=fixture();a.points.ROGUE=selector;s.current=5;assert(status(a,node())=='match'and count(s,'combo')==0 and s.calls[#s.calls][3]==selector)end
 local _,a,s=fixture();a.points.ROGUE=false;assert(status(a,node())=='match'and count(s,'combo')==1)
end)
test('TBC-first deliberately leaves Era progression Retail Forever unknown unchanged',function()
 for _,project in ipairs({2,11,14,19})do local _,a,s=fixture(project);s.current=5;assert(status(a,node())=='match'and count(s,'combo')==0)end
 for _,project in ipairs({999})do local _,a,s=fixture(project);unknown(a,node());assert(#s.calls==0)end
 -- Retail and Forever read never-secret Combo Points through UnitPower, never the TBC target transport.
 for _,project in ipairs({1,18})do local _,a,s=fixture(project);s.current=5;assert(status(a,node())=='match'and count(s,'combo')==0 and count(s,'current')==1)end
end)
test('enum value or table replacement refuses semantic route without hardcoded4',function()
 for _,mode in ipairs({'value','table'})do local f,a,s=fixture();if mode=='value'then f.env.Enum.PowerType.ComboPoints=14 else f.env.Enum.PowerType={ComboPoints=4}end;s.current=5;assert(status(a,node())=='match'and count(s,'combo')==0)end
end)
test('positive needs no maximum; missing combo never falls back to UnitPower',function()
 local f,a,s=fixture();f.env.UnitPowerMax=nil;assert(status(a,node())=='match');unknown(a,node(-1));assert(count(s,'current')==0)
 for _,mode in ipairs({'missing','throw','nil','false','string','nan','inf','opaque'})do
  f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  if mode=='missing'then f.env.GetComboPoints=nil elseif mode=='throw'then s.fail='combo'elseif mode=='nil'then s.combo=nil elseif mode=='false'then s.combo=false elseif mode=='string'then s.combo='5'elseif mode=='nan'then s.combo=0/0 elseif mode=='inf'then s.combo=math.huge else s.combo=opaque end
  unknown(a,node());assert(count(s,'current')==0 and count(s,'maximum')==0)
 end
end)
test('finite zero fractional signed values accepted and native tails ignored',function()
 for _,v in ipairs({0,.5,3})do local _,a,s=fixture();s.combo=v;assert(status(a,node(v))=='match')end
 local f,a,s=fixture();f.env.GetComboPoints=function()return 5,{}end;assert(status(a,node())=='match');s.combo=-2;s.maximum=0;f.env.GetComboPoints=function()return s.combo end;assert(status(a,node(-2))=='match')
end)
test('same-pass cache memoizes success/failure and new pass recovers',function()
 local _,a,s=fixture();local eval=a.conditionDefinitions.POINT.evaluate;local cache={};s.combo=nil;local v,why=eval(node(),cache);assert(v==nil and why=='point-power-unavailable');s.combo=5;assert(eval(node(),cache)==nil and count(s,'combo')==1);assert(eval(node(),{})==true)
 cache={};assert(eval(node(),cache));s.combo=3;assert(eval(node(0),cache)==false);assert(eval(node(-1),cache)==false);assert(count(s,'maximum')==1)
end)
test('absence false and archived compiled callback keeps old UnitPower transport',function()
 local _,a,s,old=fixture();s.exists=false;assert(status(a,node())=='no-match'and count(s,'combo')==0);s.exists=true
 a:RegisterCondition('ARCHIVED_POINT',assert(a:CompileCustomCondition('ARCHIVED_POINT',old)));assert(status(a,node(5,'player','ARCHIVED_POINT'))=='no-match'and count(s,'current')==1)
 assert(a.builtinSourceModules['Platform/points.lua']('Platform_GetUnitPointPowerObservation')==a.Platform.GetUnitPointPowerObservation)
end)
test('chosen observer is cached once per kind with exact canonical receiver and no unit arg',function()
 local _,a,s=fixture();local original=a.Platform.GetPlayerComboPointObservation;assert(original,'combo observer missing');local calls={}
 a.Platform.GetPlayerComboPointObservation=function(self,...)assert(self==a.Platform and select('#',...)==2);calls[#calls+1]={...};return original(self,...)end
 local cache={};local eval=a.conditionDefinitions.POINT.evaluate;s.combo=3;assert(eval(node(3),cache));assert(eval(node(-2),cache));assert(#calls==2 and calls[1][1]==4 and calls[1][2]=='current'and calls[2][2]=='maximum')
end)
test('a resource map getter is read once and explicit values never require fallback Enum',function()
 local f,a,s=fixture();s.current=5;local reads=0;a.points=setmetatable({},{__index=function()reads=reads+1;return 4 end});f.env.Enum=nil
 assert(status(a,node())=='match'and reads==1 and count(s,'combo')==0)
end)
test('live enum getters cannot fake raw captured fallback provenance',function()
 local f,a,s=fixture();local types=f.env.Enum.PowerType;local combo=types.ComboPoints;types.ComboPoints=nil;setmetatable(types,{__index=function(_,key)assert(key=='ComboPoints');return combo end});s.current=5
 assert(status(a,node())=='match'and count(s,'combo')==0)
end)
test('actual unavailable nodes keep NOT and branch actions unavailable and recover',function()
 local _,a,s=fixture();s.combo=nil;local n=node();unknown(a,n)
 local body={rotation={{id='gate',type='branch',conditions=n,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 assert(a:EvaluateRotationSequence(body,function(v)return a:evaluateConditionResult(v)end,function()error('unknown combo became action')end).status=='unavailable')
 s.combo=5;assert(status(a,n)=='match')
end)
test('current published source and editable copy select new observer while archived copy remains old',function()
 local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('POINT'));assert(source.evaluate:find('GetConditionPointResourceV2',1,true),'POINT catalog pending new transport')
 a:RegisterCondition('CURRENT_POINT_COPY',assert(a:CompileCustomCondition('CURRENT_POINT_COPY',source)))
 assert(status(a,node(5,'player','CURRENT_POINT_COPY'))=='match');assert(status(a,node(5,'player','ARCHIVED_POINT'))=='no-match')
 for _,id in ipairs({'builtin:Core/point_conditions.lua:GetConditionPointResourceV2','builtin:Platform/points.lua:Platform_GetPlayerComboPointObservation'})do
  local record=assert(a.builtinFunctions[id],'new public helper missing');local name=id:find('ResourceV2',1,true)and'COPY_POINT_RESOURCE_V2'or'COPY_PLAYER_COMBO';assert(a:InstallCustomFunction(name,a:CopySettingsData(record.source)))
 end
 local resource=assert(a:ResolveFunctionBinding('COPY_POINT_RESOURCE_V2'));local selected,why,transport=resource(a,'player',{});assert(selected==4 and why==nil and transport=='target-combo')
 local observer=assert(a:ResolveFunctionBinding('COPY_PLAYER_COMBO'));assert(observer(a.Platform,4,'current')==5)
 local cache={};s.calls={};assert(a.conditionDefinitions.POINT.evaluate(node(),cache));assert(a.conditionDefinitions.CURRENT_POINT_COPY.evaluate(node(-0),cache)==false);assert(count(s,'combo')==1)
 for _,id in ipairs({'builtin:Core/point_conditions.lua:GetConditionPointResource','builtin:Platform/points.lua:Platform_GetUnitPointPowerObservation'})do
  local record=assert(a.builtinFunctions[id]);local name=id:find('Resource',1,true)and'COPY_OLD_RESOURCE'or'COPY_OLD_POWER';assert(a:InstallCustomFunction(name,a:CopySettingsData(record.source)))
 end
 assert(a:ResolveFunctionBinding('COPY_OLD_RESOURCE')(a,'player',{})==4)
 assert(a:ResolveFunctionBinding('COPY_OLD_POWER')(a.Platform,'player',4,'current')==0)
end)
test('V2 preserves old identity gate and exposes transport only on selected success',function()
 local _,a,s=fixture();assert(a.GetConditionPointResourceV2,'versioned selector missing');local cache={}
 assert(a:GetConditionPointResource('player',cache)==4);local point,why,mode=a:GetConditionPointResourceV2('player',cache);assert(point==4 and why==nil and mode=='target-combo');assert(count(s,'exists')==1 and count(s,'class')==1)
 a.points.ROGUE=0;point,why,mode=a:GetConditionPointResourceV2('player',cache);assert(point==0 and why==nil and mode=='power')
 s.exists=false;assert(select('#',a:GetConditionPointResourceV2('player',{}))==1 and a:GetConditionPointResourceV2('player',{})==false)
 s.exists=true;a.points.ROGUE={};assert(select('#',a:GetConditionPointResourceV2('player',{}))==2)
end)
test('unprovable trusted-load capability never authorizes combo after later restoration',function()
 for _,mode in ipairs({'missing','inherited','opaque'})do local f,a,s=fixture();local types=f.env.Enum.PowerType;local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  if mode=='missing'then f.env.Enum.PowerType=nil elseif mode=='inherited'then f.env.Enum.PowerType=setmetatable({},{__index={ComboPoints=4}})else types.ComboPoints=opaque end
  f.load('Core/point_conditions.lua');f.env.Enum.PowerType=types;types.ComboPoints=4;s.current=5
  assert(status(a,node())=='match'and count(s,'combo')==0)
 end
end)
test('family changes during resource getter cannot invoke stale chosen transport',function()
 local _,a,s=fixture();local p=a.Platform;local base=p.GetClientInfo
 a.points=setmetatable({},{__index=function()p.GetClientInfo=function(self)local info=base(self);info.family='progression';return info end;return nil end})
 assert(status(a,node())=='unavailable');p.GetClientInfo=base;assert(status(a,{type='NOT',value=node()})=='unavailable');assert(count(s,'combo')==0 and count(s,'current')==0)
end)
test('unreadable raw family or throwing resource selection stays safe and retries',function()
 local f,a,s=fixture();local p=a.Platform;local base=p.GetClientInfo;local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
 p.GetClientInfo=function(self)local info=base(self);info.family=opaque;return info end;s.current=5;assert(status(a,node())=='match'and count(s,'combo')==0)
 p.GetClientInfo=base;a.points=setmetatable({},{__index=function()error('private selection failure')end});unknown(a,node());a.points={};assert(status(a,node())=='match')
end)
test('finite combo observations with overflowing deficit remain unknown',function()
 local _,a,s=fixture();s.combo=-1e308;s.maximum=1e308;unknown(a,node(-1));assert(count(s,'current')==0 and count(s,'combo')==2 and count(s,'maximum')==2)
end)
test('strict inverse restores all three complete modules and exact callback before older repairs',function()
 for _,path in ipairs({'Core/point_conditions.lua','Platform/points.lua','Conditions/stats.lua'})do local h=assert(io.open(path));local text=h:read('*a');h:close();assert(inverse(text,path))end
 assert(inverse(newBody,'POINT',true)==oldBody)
end)
finish()
