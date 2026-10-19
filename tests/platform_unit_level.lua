local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,level=20,calls={}}
    local function call(key,unit) assert(unit=='target' or unit=='player');s.calls[key]=(s.calls[key] or 0)+1;if s.throw==key then error('native failed') end end
    e.UnitExists=function(unit) call('exists',unit);return s.exists end;e.UnitLevel=function(unit) call('level',unit);return s.level end
    e.UnitEffectiveLevel=function() error('effective level substituted') end
    local file=io.open('Platform/unit_level.lua');if file then file:close();f.load('Platform/unit_level.lua') end
    assert(type(a.Platform.GetUnitLevelObservation)=='function','owned unit level adapter missing');return f,a.Platform,s
end
test('supported families observe positive integral actual levels and readable false absence',function()
    for _,project in ipairs({1,2,5,11,14,19,18}) do local _,p,s=fixture(project);local r,why=p:GetUnitLevelObservation('target');assert(r.exists and r.level==20 and why==nil)
        r.level=100;assert(p:GetUnitLevelObservation('player').level==20)
        s.exists=false;s.calls={};r=p:GetUnitLevelObservation('target');assert(r.exists==false and r.level==nil and not s.calls.level)
    end
end)
test('unknown families and invalid unreadable unit tokens cannot query natives',function()
    local _,p,s=fixture(999);local r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='unsupported-client' and next(s.calls)==nil)
    local f;f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,unit in ipairs({'',1,false,{},opaque}) do assert(p:GetUnitLevelObservation(unit)==nil) end
    assert(p:GetUnitLevelObservation(nil)==nil and next(s.calls)==nil)
end)
test('missing failed nil restricted and nonboolean existence never establishes absence',function()
    local f,p,s=fixture();s.exists=nil;local r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='unit-data-unavailable')
    for _,bad in ipairs({0,1,'false',{}}) do s.exists=bad;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='invalid-api-result') end
    s.throw='exists';r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='api-error');s.throw=nil
    local opaque={};f.env.issecretvalue=function(v) return rawequal(v,opaque) end;s.exists=opaque;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='restricted-value')
    f.env.UnitExists=nil;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='missing-api' and not s.calls.level)
end)
test('unknown negative levels and invalid unavailable numbers are never exact levels',function()
    local f,p,s=fixture();s.level=-1;local r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='level-data-unavailable')
    s.level=nil;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='level-data-unavailable')
    for _,bad in ipairs({0,2.5,'20',false,{},math.huge,-math.huge,0/0}) do s.level=bad;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='invalid-api-result') end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.level=opaque;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='restricted-value')
    s.throw='level';r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='api-error');s.throw=nil
    f.env.UnitLevel=nil;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='missing-api')
end)
test('older clients and native secret guards keep the same readiness contract',function()
    local f,p,s=fixture();f.env.canaccessvalue=nil;assert(p:GetUnitLevelObservation('target').level==20)
    local opaque={};f.env.issecretvalue=function(v) return rawequal(v,opaque) end;s.level=opaque;local r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='restricted-value')
    f.env.issecretvalue=nil;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;r,why=p:GetUnitLevelObservation('target');assert(r==nil and why=='restricted-value')
end)
finish()
