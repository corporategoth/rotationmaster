local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
 local f=F.new(project or 11,2,'SHAMAN');local a,e=f.addon,f.env;local opaque={};local s={exists=true,name='Audit Mob',level=20,data={lowHpAction=1,resists={fi=1,fiHits=2}},calls={}}
 e.canaccessvalue=function(v) return not rawequal(v,opaque) end
 local function query(key,...) assert(select('#',...)==(key=='provider' and 3 or 1));s.calls[#s.calls+1]={key,...};if s.throw==key then error('mobinfo query failed') end end
 e.UnitExists=function(...) query('exists',...);return s.exists end;e.UnitName=function(...) query('name',...);return s.name,opaque end;e.UnitLevel=function(...) query('level',...);return s.level,opaque end
 e.MI2_GetMobData=function(...) query('provider',...);return s.data,opaque end
 local h=io.open('Platform/mobinfo2.lua');if h then h:close();f.load('Platform/mobinfo2.lua') end
 return f,a.Platform,s,opaque,a
end
local function observe(p,kind,school,cache,unit) assert(type(p.GetMobInfo2Observation)=='function','MobInfo2 observation missing');return p:GetMobInfo2Observation(unit or 'target',kind or 'runner',school or 'fi',cache) end
local function unknown(fn) local result,reason=fn();assert(result==nil and type(reason)=='string',tostring(result)..':'..tostring(reason)) end
test('exact current native order and dot provider arity3 preserve first result identity',function()
 local _,p,s=fixture();local result=observe(p);assert(result.exists and result.runner==true);assert(#s.calls==4 and s.calls[1][1]=='exists' and s.calls[2][1]=='name' and s.calls[3][1]=='level' and s.calls[4][1]=='provider');assert(s.calls[4][2]=='Audit Mob' and s.calls[4][3]==20 and s.calls[4][4]=='target')
 s.level=-2.5;s.name='Nom localisé';assert(observe(p).runner and s.calls[#s.calls][2]==s.name and s.calls[#s.calls][3]==-2.5)
end)
test('presence alone caches complete false and nil tuples while name level provider remain live',function()
 local _,p,s=fixture();local cache={};assert(observe(p,'runner','fi',cache).runner);s.data.lowHpAction=false;assert(observe(p,'runner','fi',cache).runner==false and #s.calls==7)
 s.calls={};s.exists=false;cache={};assert(observe(p,'runner','fi',cache).exists==false);s.exists=true;assert(observe(p,'resist','fi',cache).exists==false and #s.calls==1)
 assert(observe(p,'resist','fi',{}).ratio==.5);s.calls={};s.exists=nil;cache={};local value,why=observe(p,'runner','fi',cache);assert(value==nil and why);s.exists=true;local again,reason=observe(p,'immune','fi',cache);assert(again==nil and reason==why and #s.calls==1);assert(observe(p).runner==false)
end)
test('policy query and cache guards reject unreadable values before any native call',function()
 for _,project in ipairs({999}) do local _,p,s=fixture(project);unknown(function() return observe(p) end);assert(#s.calls==0) end
 local _,p,s,opaque=fixture();for _,args in ipairs({{opaque,'runner','fi'},{'target',opaque,'fi'},{'target','resist',opaque},{'','runner','fi'},{'target','bad','fi'},{'target','runner','fi',opaque},{'target','runner','fi',false}}) do unknown(function() return p:GetMobInfo2Observation(unpack(args)) end) end;assert(#s.calls==0)
end)
test('known absent units need no provider name level or school data',function()
 local f,p,s=fixture();s.exists=false;f.env.UnitName=nil;f.env.UnitLevel=nil;f.env.MI2_GetMobData=nil;local value,why=observe(p);assert(value.exists==false and why==nil and #s.calls==1)
end)
test('required native and provider failures reject nil malformed opaque and nonfinite values',function()
 for _,field in ipairs({'exists','name','level','provider'}) do for _,mode in ipairs({'missing','throw','opaque','bad'}) do
  local f,p,s,opaque=fixture();local api=({exists='UnitExists',name='UnitName',level='UnitLevel',provider='MI2_GetMobData'})[field]
  if mode=='missing' then f.env[api]=nil elseif mode=='throw' then s.throw=field elseif mode=='opaque' then if field=='provider' then s.data=opaque else s[field]=opaque end elseif field=='provider' then s.data=1 else s[field]={} end
  unknown(function() return observe(p) end)
 end end
 for _,field in ipairs({'exists','name','level'}) do local _,p,s=fixture();s[field]=nil;unknown(function() return observe(p) end) end
 for _,bad in ipairs({'',false,5}) do local _,p,s=fixture();s.name=bad;unknown(function() return observe(p) end) end
 for _,bad in ipairs({false,'20',0/0,math.huge,-math.huge}) do local _,p,s=fixture();s.level=bad;unknown(function() return observe(p) end) end
end)
test('successful unrecorded nil and omitted optional fields are distinct known no observations',function()
 local _,p,s=fixture();s.data=nil;for _,kind in ipairs({'runner','resist','immune'}) do local result,why=observe(p,kind);assert(result.exists and result.recorded==false and why==nil) end
 s.data={};assert(observe(p).runner==false);assert(observe(p,'resist').recorded==false and observe(p,'immune').recorded==false)
 s.data={resists={}};assert(observe(p,'resist').recorded==false and observe(p,'immune').recorded==false)
 s.data=false;unknown(function() return observe(p) end)
end)
test('runner preserves finite numeric boolean and string truthiness but rejects compound unreadable and nonfinite data',function()
 local _,p,s,opaque=fixture();for _,value in ipairs({0,-1,1.5,true,false,'','run'}) do s.data.lowHpAction=value;assert(observe(p).runner==(value and true or false)) end
 for _,value in ipairs({{},function() end,coroutine.create(function() end),opaque,0/0,math.huge,-math.huge}) do s.data.lowHpAction=value;unknown(function() return observe(p) end) end
end)
test('school sign branches default missing hits only and guard required finite ratios separately from immunity',function()
 local _,p,s,opaque=fixture();s.data.resists.fiHits=nil;assert(observe(p,'resist').ratio==1);s.data.resists.fiHits=false;assert(observe(p,'resist').ratio==1)
 for _,bad in ipairs({0,0/0,math.huge,{},opaque,'2'}) do s.data.resists.fiHits=bad;unknown(function() return observe(p,'resist') end) end
 s.data.resists.fi=-1;s.data.resists.fiHits=0;local record=observe(p,'immune');assert(record.immune and record.hits==0);assert(observe(p,'resist').recorded==false)
 s.data.resists.fiHits=opaque;record=observe(p,'immune');assert(record.immune and record.hits==nil and record.hitsReason=='restricted-value')
 s.data.resists.fi=1;assert(observe(p,'immune').recorded==false);s.data.resists.fi=1e308;s.data.resists.fiHits=1e-308;unknown(function() return observe(p,'resist') end)
 s.data.resists.fi=opaque;unknown(function() return observe(p,'immune') end)
end)
test('only selected history fields are read and throwing fields remain protected unavailable facts',function()
 local _,p,s,opaque=fixture();s.data={lowHpAction='run',resists=opaque};assert(observe(p).runner)
 s.data=setmetatable({},{__index=function() error('provider field failed') end});unknown(function() return observe(p) end);unknown(function() return observe(p,'resist') end)
 s.data={resists=setmetatable({},{__index=function(_,key) if key=='fi' then return nil end;error('unobserved school hits read') end})};assert(observe(p,'resist').recorded==false)
 s.data.resists=setmetatable({fi=0},{__index=function() error('unselected sign hits read') end});assert(observe(p,'resist').recorded==false and observe(p,'immune').recorded==false)
 s.data.resists=setmetatable({fi=-1},{__index=function() error('hits failed') end});local observed=observe(p,'immune');assert(observed.immune and observed.hits==nil and observed.hitsReason=='mobinfo2-data-error')
end)
test('live capability replacements load without native work and receiver unit snapshots stay separate',function()
 for _,project in ipairs({2,5,11,14,19}) do local f,p,s,_,a=fixture(project);assert(type(p.GetMobInfo2Observation)=='function','MobInfo2 observer missing');f.load('Platform/mobinfo2.lua');assert(#s.calls==0)
  local cache={};observe(p,'runner','fi',cache);observe(p,'runner','fi',cache,'pet');local other=setmetatable({},{__index=p});observe(other,'runner','fi',cache);assert(#s.calls==12)
  f.env.MI2_GetMobData=function(...) assert(select('#',...)==3);return {lowHpAction=''} end;assert(observe(p).runner);assert(next(a.longtermCache)==nil)
 end
end)
finish()
