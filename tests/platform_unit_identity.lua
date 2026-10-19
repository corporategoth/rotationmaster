local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,same=true,calls={}}
    local function call(key,...)
        s.calls[#s.calls+1]={key,...};if s.throw==key then error('native identity failure') end;return s[key]
    end
    e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end
    e.UnitIsUnit=function(...) assert(select('#',...)==2);return call('same',...) end
    e.UnitGUID=function() error('identity must not infer GUID equality') end
    local file=io.open('Platform/unit_identity.lua');if file then file:close();f.load('Platform/unit_identity.lua') end
    return f,a.Platform,s
end
local function observe(p,unit,otherunit)
    assert(type(p.GetUnitIdentityObservation)=='function','owned identity observer missing')
    return p:GetUnitIdentityObservation(unit or 'target',otherunit or 'player')
end
local function unavailable(p,reason)
    local value,why=observe(p);assert(value==nil and why==reason,tostring(value)..':'..tostring(why)..' expected '..reason)
end
test('identity preserves exact ordered tokens with one first-unit existence query',function()
    local _,p,s=fixture()
    for _,pair in ipairs({{'target','player'},{'player','target'},{'pet','vehicle'},{'focus','focus'}}) do
        s.calls={};local value,why=observe(p,unpack(pair));assert(value==true and why==nil and #s.calls==2)
        assert(s.calls[1][1]=='exists' and s.calls[1][2]==pair[1] and #s.calls[1]==2)
        assert(s.calls[2][1]=='same' and s.calls[2][2]==pair[1] and s.calls[2][3]==pair[2] and #s.calls[2]==3)
    end
    s.same=false;assert(observe(p)==false)
end)
test('policy and both readable nonempty unit inputs precede every native query',function()
    for _,project in ipairs({1,18,999}) do local _,p,s=fixture(project);unavailable(p,'unsupported-policy');assert(#s.calls==0) end
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,bad in ipairs({'',false,0,{},opaque}) do for _,slot in ipairs({1,2}) do
        local pair={'target','player'};pair[slot]=bad
        local value,why=p:GetUnitIdentityObservation(unpack(pair));assert(value==nil and why==(rawequal(bad,opaque) and 'restricted-value' or 'invalid-unit'))
    end end
    assert(p:GetUnitIdentityObservation(nil,'player')==nil and p:GetUnitIdentityObservation('target',nil)==nil and #s.calls==0)
end)
test('required observations reject missing failed nil malformed and restricted results',function()
    for key,api in pairs({exists='UnitExists',same='UnitIsUnit'}) do
        local f,p,s=fixture();s[key]=nil;unavailable(p,key=='exists' and 'unit-data-unavailable' or 'unit-identity-unavailable')
        for _,bad in ipairs({0,1,'false',{}}) do s[key]=bad;unavailable(p,'invalid-api-result') end
        s[key]=true;s.throw=key;unavailable(p,'api-error');s.throw=nil
        local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s[key]=opaque;unavailable(p,'restricted-value')
        f.env[api]=nil;unavailable(p,'missing-api')
    end
end)
test('readable absent first unit returns false without requiring identity API or second existence',function()
    local f,p,s=fixture();s.exists=false;f.env.UnitIsUnit=nil
    local value,why=observe(p);assert(value==false and why==nil and #s.calls==1)
    f,p,s=fixture();s.exists=false;s.throw='same';assert(observe(p)==false and #s.calls==1)
end)
test('secret and inaccessible false results are unavailable before boolean comparisons',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=nil;f.env.issecretvalue=function(v) return rawequal(v,opaque) end;s.same=opaque
    unavailable(p,'restricted-value');s.same=false;assert(observe(p)==false)
    f.env.issecretvalue=nil;f.env.canaccessvalue=function(v) return v~=false end;unavailable(p,'restricted-value')
    s.exists=false;s.same=true;unavailable(p,'restricted-value')
end)
test('all probe families read live natives while module loading performs no queries',function()
    for _,project in ipairs({2,5,11,14,19}) do
        local f,p,s=fixture(project);f.load('Platform/unit_identity.lua');assert(#s.calls==0,'adapter queried native APIs at load')
        assert(observe(p)==true and #s.calls==2)
        f.env.UnitIsUnit=function(...)
            assert(select('#',...)==2 and select(1,...)=='target' and select(2,...)=='player')
            return false
        end
        assert(observe(p)==false and #s.calls==3,'adapter retained obsolete identity API')
        f.env.UnitExists=function(unit) assert(unit=='target');return false end
        f.env.UnitIsUnit=function() error('absent first unit queried replacement identity') end
        assert(observe(p)==false and #s.calls==3,'adapter retained obsolete existence API')
    end
end)
finish()
