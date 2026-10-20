-- Native fields are the external boundary; adapter/source code is real.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
 local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,id=1,name='Bête',calls={}}
 e.UnitExists=function(...)assert(select('#',...)==1);local unit=...;s.calls[#s.calls+1]={'exists',unit};if s.throw=='exists'then error('existence failure')end;return s.exists end
 e.UnitCreatureType=function(...)assert(select('#',...)==1);local unit=...;s.calls[#s.calls+1]={'creature',unit};if s.throw=='creature'then error('metadata failure')end;if s.empty then return end;return s.name,s.id,s.tail end
 if not a.Platform.GetUnitCreatureTypeID then local file=io.open('Platform/creature_type.lua');if file then file:close();f.load('Platform/creature_type.lua')end end
 assert(type(a.Platform.GetUnitCreatureTypeID)=='function','numeric creature observer missing')
 return f,a.Platform,s
end
test('probe families consume only ID return two with exact selected-unit arity and order',function()
 for _,project in ipairs({2,5,11,14,19})do
  local _,p,s=fixture(project);for _,unit in ipairs({'target','player','pet','mouseover'})do
   s.calls={};local id,why=p:GetUnitCreatureTypeID(unit);assert(id==1 and why==nil and #s.calls==2 and s.calls[1][1]=='exists'and s.calls[2][1]=='creature'and s.calls[1][2]==unit and s.calls[2][2]==unit)
  end
 end
end)
test('known absence is false and never requires the unconsumed metadata API',function()
 local f,p,s=fixture();s.exists=false;f.env.UnitCreatureType=nil;local id,why=p:GetUnitCreatureTypeID('target');assert(id==false and why==nil and #s.calls==1)
end)
test('all finite observed IDs remain known including zero signed fractional and future identities',function()
 local _,p,s=fixture();for _,id in ipairs({0,-1,.5,1.25,14,999999,1e308,-1e308})do s.id=id;assert(p:GetUnitCreatureTypeID('target')==id)end
end)
test('nil and opaque unused localized name and tuple tails cannot invalidate a readable ID',function()
 local f,p,s=fixture();local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end
 s.name=opaque;s.tail=opaque;assert(p:GetUnitCreatureTypeID('target')==1);s.name=nil;assert(p:GetUnitCreatureTypeID('target')==1)
end)
test('missing failed nil restricted malformed and nonfinite required ID data stay unavailable',function()
 local f,p,s=fixture();local function unknown(reason)local id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why==reason)end
 s.id=nil;unknown('unit-creature-type-unavailable');s.empty=true;unknown('unit-creature-type-unavailable');s.empty=nil
 for _,id in ipairs({false,'1',{},math.huge,-math.huge,0/0})do s.id=id;unknown('invalid-api-result')end
 local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;s.id=opaque;unknown('restricted-value');s.id=1
 s.throw='creature';unknown('api-error');s.throw=nil;f.env.UnitCreatureType=nil;unknown('missing-api')
end)
test('only readable Boolean false establishes absence and invalid queries never reach natives',function()
 for _,project in ipairs({1,18,999})do local _,p,s=fixture(project);local id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='unsupported-policy'and #s.calls==0)end
 local f,p,s=fixture();local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end
 for _,unit in ipairs({'',1,false,{},opaque})do assert(p:GetUnitCreatureTypeID(unit)==nil)end;assert(p:GetUnitCreatureTypeID(nil)==nil and #s.calls==0)
 s.exists=nil;local id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='unit-data-unavailable')
 for _,bad in ipairs({1,0,'false',{}})do s.exists=bad;id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='invalid-api-result')end
 s.exists=opaque;id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='restricted-value');s.exists=true;s.throw='exists';id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='api-error');f.env.UnitExists=nil;id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='missing-api')
end)
test('optional native readability proof retains older-client and secret-only behavior',function()
 local f,p,s=fixture();f.env.canaccessvalue=nil;assert(p:GetUnitCreatureTypeID('target')==1)
 local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end;s.id=opaque;local id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='restricted-value')
 f.env.issecretvalue=nil;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;id,why=p:GetUnitCreatureTypeID('target');assert(id==nil and why=='restricted-value')
end)
test('module definitions query nothing and later native replacement is observed live',function()
 local f,p,s=fixture();s.calls={};f.load('Platform/creature_type.lua');assert(#s.calls==0)
 f.env.UnitCreatureType=function(...)assert(select('#',...)==1 and (...)=='target');return 'Wildtier',99 end
 assert(p:GetUnitCreatureTypeID('target')==99)
end)
finish()
