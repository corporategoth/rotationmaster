local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local e=f.env;local s={result='hostile',modern=0,legacy=0}
    local function query(kind,...) assert(select('#',...)==0,'zone PvP native received arguments or receiver');s[kind]=s[kind]+1;if s.throw==kind then error('native zone failure') end;return s.result,s.tail end
    e.C_PvP={GetZonePVPInfo=function(...) return query('modern',...) end};e.GetZonePVPInfo=function(...) return query('legacy',...) end
    for _,name in ipairs({'IsInInstance','UnitExists','UnitIsPVP','GetZoneText','GetSubZoneText'}) do e[name]=function() error('unexpected zone inference') end end
    local file=io.open('Platform/zone_pvp.lua');if file then file:close();f.load('Platform/zone_pvp.lua') end
    return f,f.addon.Platform,s
end
local function observe(p) assert(type(p.GetZonePVPObservation)=='function','owned zone PvP observer missing');return p:GetZonePVPObservation() end
local function unknown(p,reason) local result,why=observe(p);assert(result==nil and why==reason,tostring(why)..' expected '..reason) end
test('modern public surface wins on all identified families with zero argument fresh observations',function()
    for _,project in ipairs({1,18,2,5,11,14,19}) do local f,p,s=fixture(project);assert(s.modern==0 and s.legacy==0)
        for _,kind in ipairs({'arena','friendly','contested','hostile','sanctuary','combat','','future-zone'}) do s.result=kind;local record,why=observe(p);assert(record.pvpType==kind and why==nil);assert(observe(p)~=record) end
        assert(s.modern==16 and s.legacy==0 and next(f.addon.longtermCache)==nil)
    end
end)
test('global fallback occurs only when the readable modern callable is absent',function()
    for _,surface in ipairs({{}, {GetZonePVPInfo=false}, {GetZonePVPInfo=17}, {GetZonePVPInfo='missing'}}) do local f,p,s=fixture();f.env.C_PvP=surface;assert(observe(p).pvpType=='hostile' and s.modern==0 and s.legacy==1) end
    local f,p,s=fixture();f.env.C_PvP=nil;assert(observe(p).pvpType=='hostile' and s.legacy==1)
    f.env.C_PvP=false;assert(observe(p).pvpType=='hostile' and s.legacy==2)
    f.env.GetZonePVPInfo=nil;unknown(p,'missing-api')
end)
test('successful nil no returns and ignored restricted tails remain known empty records',function()
    local f,p,s=fixture();s.result=nil;local record,why=observe(p);assert(type(record)=='table' and next(record)==nil and why==nil and s.legacy==0)
    f.env.C_PvP.GetZonePVPInfo=function(...) assert(select('#',...)==0);return end
    record,why=observe(p);assert(type(record)=='table' and next(record)==nil and why==nil and s.legacy==0)
    local opaque={};f.env.canaccessvalue=function(v) assert(not rawequal(v,opaque),'ignored tail inspected');return true end
    f.env.C_PvP.GetZonePVPInfo=function() return 'friendly',opaque,opaque end;assert(observe(p).pvpType=='friendly')
    f.env.C_PvP.GetZonePVPInfo=function() return nil,opaque,opaque end;assert(next(observe(p))==nil)
end)
test('modern failures restricted and malformed results never fall back to the legacy function',function()
    local f,p,s=fixture();s.throw='modern';unknown(p,'api-error');assert(s.legacy==0);s.throw=nil
    for _,bad in ipairs({false,true,0,17,{},math.huge}) do s.result=bad;unknown(p,'invalid-api-result');assert(s.legacy==0) end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.result=opaque;unknown(p,'restricted-value');assert(s.legacy==0)
    f.env.canaccessvalue=nil;f.env.issecretvalue=function(v) return rawequal(v,opaque) end;unknown(p,'restricted-value');assert(s.legacy==0)
end)
test('namespace and method readability is required before selecting any fallback',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    f.env.C_PvP=opaque;unknown(p,'restricted-value');assert(s.modern==0 and s.legacy==0)
    f.env.C_PvP={GetZonePVPInfo=opaque};unknown(p,'restricted-value');assert(s.modern==0 and s.legacy==0)
    f.env.C_PvP=nil;f.env.GetZonePVPInfo=opaque;unknown(p,'restricted-value');assert(s.legacy==0)
end)
test('legacy failures remain unavailable and current surface replacement recovers without retained state',function()
    local f,p,s=fixture();f.env.C_PvP=nil;s.throw='legacy';unknown(p,'api-error');s.throw=nil;s.result=nil;assert(next(observe(p))==nil)
    s.result=false;unknown(p,'invalid-api-result');s.result='combat';assert(observe(p).pvpType=='combat')
    f.env.C_PvP={GetZonePVPInfo=function(...) assert(select('#',...)==0);return 'future' end};assert(observe(p).pvpType=='future')
    f.env.C_PvP.GetZonePVPInfo=nil;assert(observe(p).pvpType=='combat')
end)
test('unknown families never query and unreadable nil is not interpreted as successful empty',function()
    local _,p,s=fixture(999);unknown(p,'unsupported-policy');assert(s.modern==0 and s.legacy==0)
    local f;f,p,s=fixture();f.env.canaccessvalue=function(v) return v~=nil end;s.result=nil;unknown(p,'restricted-value');assert(s.legacy==0)
end)
finish()
