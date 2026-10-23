local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local kinds={'combat','enemy','pvp'}
local apis={combat='UnitAffectingCombat',enemy='UnitIsEnemy',pvp='UnitIsPVP'}
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,combat=true,enemy=true,pvp=true,calls={}}
    local function call(key,...)
        local args={n=select('#',...),...};s.calls[#s.calls+1]={key=key,args=args}
        if s.throw==key then error('native failure') end;return s[key]
    end
    e.UnitExists=function(...) return call('exists',...) end
    e.UnitAffectingCombat=function(...) return call('combat',...) end
    e.UnitIsEnemy=function(...) return call('enemy',...) end
    e.UnitIsPVP=function(...) return call('pvp',...) end
    local file=io.open('Platform/unit_flags.lua');if file then file:close();f.load('Platform/unit_flags.lua') end
    return f,a.Platform,s
end
local function observe(p,unit,kind) assert(type(p.GetUnitFlagObservation)=='function','owned unit-flag adapter missing');return p:GetUnitFlagObservation(unit,kind) end
local function unknown(p,kind,why) local value,reason=observe(p,'target',kind);assert(value==nil and reason==why,tostring(value)..':'..tostring(reason)..' expected '..why) end
test('three flags retain exact selected native tuples boolean false and mode isolation',function()
    for _,kind in ipairs(kinds) do for _,unit in ipairs({'player','pet','target','vehicle'}) do
        local f,p,s=fixture();for other,api in pairs(apis) do if other~=kind then f.env[api]=nil end end
        local value,why=observe(p,unit,kind);assert(value==true and why==nil and #s.calls==2)
        local first,second=s.calls[1],s.calls[2];assert(first.key=='exists' and first.args.n==1 and first.args[1]==unit and second.key==kind)
        if kind=='enemy' then assert(second.args.n==2 and second.args[1]=='player' and second.args[2]==unit) else assert(second.args.n==1 and second.args[1]==unit) end
        s[kind]=false;value,why=observe(p,unit,kind);assert(value==false and why==nil)
        s.exists=false;s.calls={};value,why=observe(p,unit,kind);assert(value==false and why==nil and #s.calls==1)
    end end
end)
test('probe families retain flag queries and unsupported policies cannot touch native state',function()
    for _,project in ipairs({2,5,11,14,19}) do local _,p=fixture(project);for _,kind in ipairs(kinds) do assert(observe(p,'target',kind)==true) end end
    for _,project in ipairs({999}) do local _,p,s=fixture(project);for _,kind in ipairs(kinds) do unknown(p,kind,'unsupported-policy') end;assert(#s.calls==0) end
end)
test('query readability and closed kind validation precede native calls even for absent units',function()
    local f,p,s=fixture();s.exists=false;local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,unit in ipairs({'',false,0,{},opaque}) do local value,why=observe(p,unit,'combat');assert(value==nil and why==(rawequal(unit,opaque) and 'restricted-value' or 'invalid-unit')) end
    assert(observe(p,nil,'combat')==nil)
    for _,kind in ipairs({'',false,0,{},'COMBAT','attackable',opaque}) do local value,why=observe(p,'target',kind);assert(value==nil and why==(rawequal(kind,opaque) and 'restricted-value' or 'invalid-unit-flag-query')) end
    assert(observe(p,'target',nil)==nil and #s.calls==0)
end)
test('required existence and selected flags reject missing nil thrown malformed and opaque results',function()
    for _,kind in ipairs(kinds) do for _,key in ipairs({'exists',kind}) do
        local f,p,s=fixture();s[key]=nil;unknown(p,kind,key=='exists' and 'unit-data-unavailable' or 'unit-flag-unavailable')
        for _,bad in ipairs({0,1,'false',{}}) do s[key]=bad;unknown(p,kind,'invalid-api-result') end
        s[key]=true;s.throw=key;unknown(p,kind,'api-error');s.throw=nil
        local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s[key]=opaque;unknown(p,kind,'restricted-value')
        f.env[key=='exists' and 'UnitExists' or apis[key]]=nil;unknown(p,kind,'missing-api')
    end end
end)
test('absence requires no selected API and fresh calls see API replacement without load-time captures',function()
    for _,kind in ipairs(kinds) do local f,p,s=fixture();s.exists=false;f.env[apis[kind]]=nil;local v,why=observe(p,'target',kind);assert(v==false and why==nil and #s.calls==1)
        s.exists=true;unknown(p,kind,'missing-api');f.env[apis[kind]]=function() return false end;assert(observe(p,'target',kind)==false)
        f.env[apis[kind]]=function() return true end;assert(observe(p,'target',kind)==true)
        local before=#s.calls;f.env.UnitExists=function() error('module load queried existence') end;f.env[apis[kind]]=function() error('module load queried flag') end
        f.load('Platform/unit_flags.lua');assert(#s.calls==before)
    end
end)
test('secret predicate and native access denial are honored before truthiness',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=nil;f.env.issecretvalue=function(v) return rawequal(v,opaque) end;s.combat=opaque;unknown(p,'combat','restricted-value')
    f.env.issecretvalue=nil;f.env.canaccessvalue=function(v) return v~=false end;s.pvp=false;unknown(p,'pvp','restricted-value')
end)
finish()
