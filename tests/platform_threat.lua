local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,enemy=true,threat=2,calls={}}
    local function call(key,...)
        s.calls[#s.calls+1]={key,...};if s.throw==key then error('native threat failure') end;return s[key]
    end
    e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end
    e.UnitIsEnemy=function(...) assert(select('#',...)==2);return call('enemy',...) end
    e.UnitThreatSituation=function(...) assert(select('#',...)==2);return call('threat',...) end
    for _,name in ipairs({'UnitCanAttack','UnitIsDead','UnitAffectingCombat','UnitGUID'}) do e[name]=function() error('unexpected threat inference') end end
    local file=io.open('Platform/threat.lua');if file then file:close();f.load('Platform/threat.lua') end
    return f,a.Platform,s
end
local function observe(p,unit)
    assert(type(p.GetUnitThreatObservation)=='function','owned threat observer missing')
    return p:GetUnitThreatObservation(unit or 'target')
end
local function unavailable(p,reason)
    local value,why=observe(p);assert(value==nil and why==reason,tostring(value)..':'..tostring(why)..' expected '..reason)
end
test('threat preserves finite numbers and exact ordered actor recipient calls',function()
    local _,p,s=fixture()
    for _,unit in ipairs({'target','focus','pet','player'}) do for _,number in ipairs({0,1,2,3,-1,0.5,17}) do
        s.calls={};s.threat=number;local value,why=observe(p,unit);assert(value==number and why==nil and #s.calls==3)
        assert(s.calls[1][1]=='exists' and s.calls[1][2]==unit and #s.calls[1]==2)
        assert(s.calls[2][1]=='enemy' and s.calls[2][2]=='player' and s.calls[2][3]==unit and #s.calls[2]==3)
        assert(s.calls[3][1]=='threat' and s.calls[3][2]=='player' and s.calls[3][3]==unit and #s.calls[3]==3)
    end end
end)
test('policy and readable nonempty unit validation precede native access',function()
    for _,project in ipairs({1,18,999}) do local _,p,s=fixture(project);unavailable(p,'unsupported-policy');assert(#s.calls==0) end
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,bad in ipairs({'',false,0,{},opaque}) do local value,why=p:GetUnitThreatObservation(bad)
        assert(value==nil and why==(rawequal(bad,opaque) and 'restricted-value' or 'invalid-unit'))
    end
    assert(p:GetUnitThreatObservation()==nil and #s.calls==0)
end)
test('required existence enemy booleans reject nil missing failed malformed and restricted',function()
    for key,api in pairs({exists='UnitExists',enemy='UnitIsEnemy'}) do
        local f,p,s=fixture();s[key]=nil;unavailable(p,'unit-data-unavailable')
        for _,bad in ipairs({0,1,'false',{}}) do s[key]=bad;unavailable(p,'invalid-api-result') end
        s[key]=true;s.throw=key;unavailable(p,'api-error');s.throw=nil
        local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s[key]=opaque;unavailable(p,'restricted-value')
        f.env[api]=nil;unavailable(p,'missing-api')
    end
end)
test('known absence and nonenemy short circuit without requiring later APIs',function()
    local f,p,s=fixture();s.exists=false;f.env.UnitIsEnemy=nil;f.env.UnitThreatSituation=nil
    local value,why=observe(p);assert(value==false and why==nil and #s.calls==1)
    f,p,s=fixture();s.enemy=false;f.env.UnitThreatSituation=nil
    value,why=observe(p);assert(value==false and why==nil and #s.calls==2)
end)
test('successful nil or no return is known no threat unlike unavailable query',function()
    local f,p,s=fixture();s.threat=nil;local value,why=observe(p);assert(value==false and why==nil and #s.calls==3)
    f.env.UnitThreatSituation=function(...) assert(select('#',...)==2);return end
    value,why=observe(p);assert(value==false and why==nil)
    f.env.UnitThreatSituation=nil;unavailable(p,'missing-api')
    f,p,s=fixture();s.throw='threat';unavailable(p,'api-error')
    for _,bad in ipairs({false,true,'0',{},math.huge,-math.huge,0/0}) do s.throw=nil;s.threat=bad;unavailable(p,'invalid-api-result') end
end)
test('readability precedes nil boolean and numeric interpretation including secret values',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=nil;f.env.issecretvalue=function(v) return rawequal(v,opaque) end
    s.threat=opaque;unavailable(p,'restricted-value');s.threat=0;assert(observe(p)==0)
    f.env.issecretvalue=nil;f.env.canaccessvalue=function(v) return v~=nil end;s.threat=nil;unavailable(p,'restricted-value')
    f.env.canaccessvalue=function(v) return v~=false end;s.exists=false;unavailable(p,'restricted-value')
end)
test('probe families read current natives with no load time observation or longterm cache',function()
    for _,project in ipairs({2,5,11,14,19}) do local f,p,s=fixture(project);f.load('Platform/threat.lua');assert(#s.calls==0)
        assert(observe(p)==2);f.env.UnitThreatSituation=function(actor,unit) assert(actor=='player' and unit=='target');return 0 end
        assert(observe(p)==0 and #s.calls==5)
        f.env.UnitExists=function(unit) assert(unit=='target');return false end;f.env.UnitIsEnemy=nil
        assert(observe(p)==false and #s.calls==5 and next(f.addon.longtermCache)==nil)
    end
end)
finish()
