local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,current=50,maximum=100,calls={}}
    local function call(name) s.calls[name]=(s.calls[name] or 0)+1;if s.throw==name then error('native failure') end end
    e.UnitExists=function(unit) assert(unit=='target');call('exists');return s.exists end
    e.UnitHealth=function(unit) assert(unit=='target');call('current');return s.current end
    e.UnitHealthMax=function(unit) assert(unit=='target');call('maximum');return s.maximum end
    local file=io.open('Platform/unit_health.lua');if file then file:close();f.load('Platform/unit_health.lua') end
    assert(type(a.Platform.GetUnitHealthObservation)=='function','owned health adapter missing')
    return f,a.Platform,s
end
test('health records distinguish present zero and absent without unnecessary maximum reads',function()
    local _,p,s=fixture();local r,why=p:GetUnitHealthObservation('target');assert(r.exists and r.current==50 and r.maximum==nil and why==nil and not s.calls.maximum)
    r=p:GetUnitHealthObservation('target',true);assert(r.current==50 and r.maximum==100)
    r.current=999;assert(p:GetUnitHealthObservation('target',false).current==50)
    s.current=0;s.maximum=0;r=p:GetUnitHealthObservation('target',true);assert(r.exists and r.current==0 and r.maximum==0)
    s.exists=false;s.calls={};r=p:GetUnitHealthObservation('target',true);assert(r.exists==false and r.current==nil and s.calls.exists==1 and not s.calls.current and not s.calls.maximum)
end)
test('policy and readable typed query guards run before native access',function()
    for _,project in ipairs({1,18,999}) do local _,p,s=fixture(project);local r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='unsupported-policy' and next(s.calls)==nil) end
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,unit in ipairs({'',0,false,{},opaque}) do assert(p:GetUnitHealthObservation(unit)==nil) end
    for _,query in ipairs({'true',1,{},opaque}) do assert(p:GetUnitHealthObservation('target',query)==nil) end
    assert(p:GetUnitHealthObservation(nil)==nil and next(s.calls)==nil)
end)
test('existence nil is unavailable and only readable boolean false establishes absence',function()
    local f,p,s=fixture();s.exists=nil;local r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='unit-data-unavailable')
    for _,bad in ipairs({0,1,'false',{}}) do s.exists=bad;r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='invalid-api-result') end
    s.throw='exists';r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='api-error');s.throw=nil
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.exists=opaque;r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='restricted-value')
    f.env.UnitExists=nil;r,why=p:GetUnitHealthObservation('target');assert(r==nil and why=='missing-api' and not s.calls.current)
end)
test('required current and maximum reject nil missing failed restricted and nonfinite native data',function()
    for _,key in ipairs({'current','maximum'}) do local f,p,s=fixture();s[key]=nil;local r,why=p:GetUnitHealthObservation('target',true);assert(r==nil and why=='health-data-unavailable')
        for _,bad in ipairs({false,'50',{},-1,math.huge,-math.huge,0/0}) do s[key]=bad;r,why=p:GetUnitHealthObservation('target',true);assert(r==nil and why=='invalid-api-result') end
        local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s[key]=opaque;r,why=p:GetUnitHealthObservation('target',true);assert(r==nil and why=='restricted-value')
        s.throw=key;r,why=p:GetUnitHealthObservation('target',true);assert(r==nil and why=='api-error');s.throw=nil
        f.env[key=='current' and 'UnitHealth' or 'UnitHealthMax']=nil;r,why=p:GetUnitHealthObservation('target',true);assert(r==nil and why=='missing-api')
    end
end)
test('optional native readability proof preserves older clients and the broader platform guard',function()
    local f,p,s=fixture();f.env.canaccessvalue=nil
    local r=assert(p:GetUnitHealthObservation('target',true));assert(r.current==50 and r.maximum==100)
    local opaque={};f.env.issecretvalue=function(value) return rawequal(value,opaque) end;s.current=opaque
    local value,why=p:GetUnitHealthObservation('target',true);assert(value==nil and why=='restricted-value')
    s.current=50;s.maximum=opaque;value,why=p:GetUnitHealthObservation('target',true);assert(value==nil and why=='restricted-value')
    f.env.issecretvalue=nil;f.env.canaccessvalue=function(value) return not rawequal(value,opaque) end
    value,why=p:GetUnitHealthObservation('target',true);assert(value==nil and why=='restricted-value')
end)
finish()
