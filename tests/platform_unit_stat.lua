local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
 local f=F.new(project or 11,2,'MAGE');local a,e=f.addon,f.env;local s={exists=true,value=42,calls={}}
 local function call(name,...) s.calls[#s.calls+1]={name,n=select('#',...),...};if s.throw==name then error('native stat unavailable') end end
 e.UnitExists=function(...) assert(select('#',...)==1);call('exists',...);return s.exists,s.unused end
 e.UnitStat=function(...) assert(select('#',...)==2);call('stat',...);return s.unused,s.value,s.unused,s.unused,s.unused end
 e.UnitArmor=function(...) assert(select('#',...)==1);call('armor',...);return s.unused,s.value,s.unused,s.unused,s.unused end
 local file=io.open('Platform/unit_stat.lua');if file then file:close();f.load('Platform/unit_stat.lua') end
 return f,a.Platform,s
end
local function read(p,unit,stat) assert(type(p.GetUnitStatObservation)=='function','unit-stat observation API absent');return p:GetUnitStatObservation(unit,stat) end
local function unknown(p,unit,stat,reason) local record,why=read(p,unit,stat);assert(record==nil and why==reason,tostring(why)..' expected '..reason) end

test('stat selectors preserve exact actor arity routing return two and ignored fields',function()
 local f,p,s=fixture();local opaque={};s.unused=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
 for stat=1,6 do s.calls={};local record,why=read(p,'pet',stat);assert(record.exists==true and record.value==42 and why==nil);assert(#s.calls==2 and s.calls[1][1]=='exists' and s.calls[1][2]=='pet');local call=s.calls[2];assert(call[1]==(stat==6 and 'armor' or 'stat') and call[2]=='pet' and call.n==(stat==6 and 1 or 2));if stat<6 then assert(call[3]==stat) end end
end)
test('query routing is closed over readable nonempty units and integral RM selectors one through six',function()
 local f,p,s=fixture();for _,unit in ipairs({'',1,false,{}}) do unknown(p,unit,1,'invalid-unit') end;unknown(p,nil,1,'invalid-unit')
 for _,stat in ipairs({0,-1,7,1.5,math.huge,0/0,'1',false,{}}) do unknown(p,'player',stat,'invalid-stat-query') end;unknown(p,'player',nil,'invalid-stat-query')
 local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;unknown(p,opaque,1,'restricted-value');unknown(p,'player',opaque,'restricted-value');assert(#s.calls==0)
end)
test('known absence returns an absence record before requiring either statistic API',function()
 local f,p,s=fixture();s.exists=false;f.env.UnitStat=nil;f.env.UnitArmor=nil
 for _,stat in ipairs({1,6}) do local record=read(p,'target',stat);assert(record.exists==false and record.value==nil) end;assert(#s.calls==2)
end)
test('required existence distinguishes false from unavailable malformed restricted and failed observations',function()
 local f,p,s=fixture();s.exists=nil;unknown(p,'player',1,'unit-data-unavailable')
 for _,value in ipairs({0,'true',{},math.huge}) do s.exists=value;unknown(p,'player',1,'invalid-api-result') end
 local opaque={};s.exists=opaque;f.env.issecretvalue=function(v) return rawequal(v,opaque) end;unknown(p,'player',1,'restricted-value');s.exists=true;s.throw='exists';unknown(p,'player',1,'api-error');s.throw=nil;f.env.UnitExists=nil;unknown(p,'player',1,'missing-api')
 for _,call in ipairs(s.calls) do assert(call[1]=='exists') end
end)
test('only consumed effective numeric results are finite while zero signed and fractional results remain valid',function()
 for _,stat in ipairs({1,6}) do local f,p,s=fixture()
  for _,value in ipairs({0,-3.5,2.25}) do s.value=value;local record=read(p,'player',stat);assert(record.value==value) end
  s.value=nil;unknown(p,'player',stat,'stat-data-unavailable')
  for _,value in ipairs({false,'42',{},0/0,math.huge,-math.huge}) do s.value=value;unknown(p,'player',stat,'invalid-api-result') end
  local opaque={};s.value=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;unknown(p,'player',stat,'restricted-value');s.value=42;s.throw=stat==6 and 'armor' or 'stat';unknown(p,'player',stat,'api-error');s.throw=nil;f.env[stat==6 and 'UnitArmor' or 'UnitStat']=nil;unknown(p,'player',stat,'missing-api')
 end
end)
test('probe policy refuses unsupported or restricted families without native calls and loads lazily',function()
 for _,project in ipairs({2,5,11,14,19}) do local _,p,s=fixture(project);assert(#s.calls==0 and read(p,'player',1).value==42) end
 for _,project in ipairs({1,18,999}) do local _,p,s=fixture(project);unknown(p,'player',1,'unsupported-policy');assert(#s.calls==0) end
end)
finish()
