local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
 local f=F.new(project or 11,2,'SHAMAN');local p,e=f.addon.Platform,f.env
 local s={exists=true,spec=77,role='HEALER',talent='TANK',calls={}};local opaque={}
 e.canaccessvalue=function(v) return not rawequal(v,opaque) end
 local function query(key,...)
  assert(select('#',...)==1,'native arity changed');s.calls[#s.calls+1]={key,arg=(...),arity=select('#',...)}
  if s.throw==key then error('native role failure') end
 end
 e.UnitExists=function(...) query('exists',...);return s.exists end
 e.GetInspectSpecialization=function(...) query('legacy',...);return s.spec end
 e.C_SpecializationInfo={GetInspectSpecialization=function(...) query('modern',...);return s.spec,opaque end}
 e.GetSpecializationInfoByID=function(...) query('metadata',...);return opaque,opaque,opaque,opaque,s.role,opaque end
 e.GetTalentGroupRole=function(...) query('talent',...);return s.talent,opaque end
 local h=io.open('Platform/role.lua');if h then h:close();f.load('Platform/role.lua') end
 return f,p,s,opaque
end
local function inspect(p,unit) assert(type(p.GetInspectRoleObservation)=='function','inspect role observer missing');return p:GetInspectRoleObservation(unit or 'target') end
local function talent(p,...) assert(type(p.GetTalentGroupRoleObservation)=='function','talent role observer missing');return p:GetTalentGroupRoleObservation(...) end
local function unknown(fn,reason) local v,r=fn();assert(v==nil and type(r)=='string' and (not reason or r==reason),tostring(v)..':'..tostring(r)) end
test('modern inspect uses exact ordered dot calls role result5 and only consumed tuple fields',function()
 local _,p,s=fixture();assert(inspect(p)=='HEALER' and #s.calls==3);assert(s.calls[1][1]=='exists' and s.calls[1].arg=='target');assert(s.calls[2][1]=='modern' and s.calls[2].arg=='target');assert(s.calls[3][1]=='metadata' and s.calls[3].arg==77)
 s.role='FUTURE_ROLE';assert(inspect(p,'pet')=='FUTURE_ROLE');s.role='NONE';assert(inspect(p)=='NONE')
end)
test('policy and unreadable query guards stop before all native calls and namespaces',function()
 for _,project in ipairs({999}) do local _,p,s=fixture(project);unknown(function() return inspect(p) end,'unsupported-policy');unknown(function() return talent(p,2) end,'unsupported-policy');assert(#s.calls==0) end
 local _,p,s,opaque=fixture();unknown(function() return p:GetInspectRoleObservation(opaque) end,'restricted-value');unknown(function() return talent(p,opaque) end,'restricted-value')
 for _,bad in ipairs({'',false,1,{}}) do unknown(function() return p:GetInspectRoleObservation(bad) end,'invalid-unit') end
 assert(#s.calls==0)
end)
test('known absence skips missing or broken inspect namespace and metadata capabilities',function()
 local f,p,s=fixture();s.exists=false;f.env.C_SpecializationInfo=setmetatable({},{__index=function() error('absent lookup') end});f.env.GetInspectSpecialization=nil;f.env.GetSpecializationInfoByID=nil
 assert(inspect(p)==false and #s.calls==1)
end)
test('missing failed malformed and restricted required exists spec role and talent remain unavailable',function()
 for _,field in ipairs({'exists','spec','role','talent'}) do for _,mode in ipairs({'nil','throw','missing','opaque',false,0,{},''}) do
  local f,p,s,opaque=fixture();local kind=field=='talent' and 'talent' or 'inspect'
  if mode=='nil' then s[field]=nil elseif mode=='throw' then s.throw=field=='spec' and 'modern' or field=='role' and 'metadata' or field
  elseif mode=='missing' then if field=='exists' then f.env.UnitExists=nil elseif field=='spec' then f.env.C_SpecializationInfo=nil;f.env.GetInspectSpecialization=nil elseif field=='role' then f.env.GetSpecializationInfoByID=nil else f.env.GetTalentGroupRole=nil end
  elseif mode=='opaque' then s[field]=opaque else s[field]=mode end
  if not (field=='exists' and mode==false) then unknown(function() if kind=='talent' then return talent(p,2) else return inspect(p) end end) end
 end end
 for _,bad in ipairs({-1,1.5,0/0,math.huge,-math.huge}) do local _,p,s=fixture();s.spec=bad;unknown(function() return inspect(p) end);assert(#s.calls==2) end
end)
test('modern absent capability falls back while selected modern failures never use legacy',function()
 local f,p,s,opaque=fixture();f.env.C_SpecializationInfo=nil;assert(inspect(p)=='HEALER' and s.calls[2][1]=='legacy')
 f.env.C_SpecializationInfo={};s.calls={};assert(inspect(p)=='HEALER' and s.calls[2][1]=='legacy')
 for _,bad in ipairs({false,4,opaque,setmetatable({},{__index=function() error('member lookup') end}),{GetInspectSpecialization=opaque}}) do f.env.C_SpecializationInfo=bad;s.calls={};unknown(function() return inspect(p) end);assert(#s.calls==1) end
 f.env.C_SpecializationInfo={GetInspectSpecialization=function() error('selected modern') end};s.calls={};unknown(function() return inspect(p) end,'api-error');assert(#s.calls==1)
 f.env.C_SpecializationInfo={GetInspectSpecialization=function() return 0 end};s.calls={};unknown(function() return inspect(p) end);assert(#s.calls==1)
end)
test('talent consumes exact live group as one argument including nil with no invented bounds',function()
 local _,p,s=fixture();assert(talent(p,nil)=='TANK');assert(s.calls[1][1]=='talent' and s.calls[1].arity==1 and s.calls[1].arg==nil)
 for _,group in ipairs({0,-1,1.5,'future',{}}) do assert(talent(p,group)=='TANK' and s.calls[#s.calls].arg==group) end
 s.talent='FUTURE_ROLE';assert(talent(p,2)=='FUTURE_ROLE');assert(#s.calls==7)
end)
test('probe families load without queries and methods observe live replacements',function()
 for _,project in ipairs({2,5,11,14,19}) do local f,p,s=fixture(project);assert(type(p.GetInspectRoleObservation)=='function','role observer missing');f.load('Platform/role.lua');assert(#s.calls==0)
  f.env.C_SpecializationInfo.GetInspectSpecialization=function(unit) assert(unit=='target');return 1e9 end
  f.env.GetSpecializationInfoByID=function(id) assert(id==1e9);return nil,nil,nil,nil,'TANK' end
  assert(inspect(p)=='TANK');f.env.GetTalentGroupRole=function(...) assert(select('#',...)==1);return 'HEALER' end;assert(talent(p,2)=='HEALER')
 end
end)
finish()
