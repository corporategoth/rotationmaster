local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    if not (a.Functions and a.Functions.trends) then
        local file=io.open('Functions/trends.lua');if file then file:close();f.load('Functions/trends.lua');f.load('utils.lua') end
    end
    for _,p in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(p) end
    f.env.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,a
end
local function pack(...) return {n=select('#',...),...} end
local function same(x,y) return math.abs(x-y)<1e-10 end
local function history() return {damage={{time=100,value=10},{time=99,value=12},{time=97,value=8}},heals={{time=100,value=2},{time=97,value=3}}} end
local function body(fn)
    local info=debug.getinfo(fn,'S');local lines={};for line in io.lines(info.source:sub(2)) do lines[#lines+1]=line end
    return '\n'..table.concat(lines,'\n',info.linedefined+1,info.lastlinedefined-1)..'\n'
end
test('trend implementations have physical canonical owners and direct legacy aliases',function()
    local _,a=fixture();local trends=assert(a.Functions.trends,'canonical trend namespace missing')
    assert(trends.calculate==a.calculate_trend and trends.calculateOld==a.calculate_trend_old,'legacy trend API is a wrapper or different implementation')
    for _,fn in ipairs({trends.calculate,trends.calculateOld}) do
        assert(debug.getinfo(fn,'S').source=='@Functions/trends.lua','implementation still belongs to utils')
        local key,value=debug.getupvalue(fn,1);assert(key=='addon' and value==a and debug.getupvalue(fn,2)==nil,'runtime capture contract changed')
    end
end)
test('current trend preserves early tuple arity weighted streams and lazy truthy modes',function()
    local f,a=fixture();local calls=0;f.env.GetTime=function() calls=calls+1;return 100 end;a.db.profile.damage_history=10
    for _,empty in ipairs({{},{false}}) do local r=pack(a.calculate_trend(empty[1]));assert(r.n==1 and r[1]==0 and calls==0,'falsy history acquired runtime dependencies or a second result') end
    local h=history();local before=a:CopySettingsData(h);local r=pack(a.calculate_trend(h));assert(r.n==2 and same(r[1],-223/34) and r[2]==3 and calls==1)
    r=pack(a.calculate_trend(h,nil,true));assert(same(r[1],-132/17) and r[2]==3)
    r=pack(a.calculate_trend(h,nil,false,true));assert(same(r[1],41/34) and r[2]==3)
    r=pack(a.calculate_trend({},nil,'truthy',{}));assert(r.n==2 and r[1]==0 and r[2]==0,'mode truthiness or lazy list access changed')
    r=pack(a.calculate_trend({damage={},heals={}}));assert(r.n==2 and r[1]==0 and r[2]==0)
    a.db.profile={damage_history=7};r=pack(a.calculate_trend(h));assert(same(r[1],-74/11) and r[2]==3,'replaced profile is not live')
    r=pack(a.calculate_trend(h,false));assert(same(r[1],-74/11),'falsy window did not use current profile')
    r=pack(a.calculate_trend(h,10));assert(same(r[1],-223/34),'explicit window changed');r=pack(a.calculate_trend({},0,true,true));assert(r.n==2 and r[1]==0 and r[2]==0)
    assert(a:SettingsDataEqual(before,h),'trend mutated history input')
end)
test('legacy health trend preserves old weighting and return counts; no change is zero, not NaN',function()
    local f,a=fixture();f.env.GetTime=function() return 100 end;a.db.profile.damage_history=10
    for _,empty in ipairs({{},{false}}) do local r=pack(a.calculate_trend_old(empty[1]));assert(r.n==1 and r[1]==0) end
    local r=pack(a.calculate_trend_old({}));assert(r.n==1 and r[1]==0,'an empty history returned NaN or a bucket count')
    local h={{time=100,value=80,max=100},{time=99,value=90,max=100},{time=98,value=95,max=100}};local before=a:CopySettingsData(h)
    r=pack(a.calculate_trend_old(h));assert(r.n==2 and same(r[1],-130/17) and r[2]==2);assert(a:SettingsDataEqual(before,h))
    r=pack(a.calculate_trend_old({{time=100,value=100,max=100}}));assert(r.n==1 and r[1]==0,'legacy full-health stop returned NaN')
    r=pack(a.calculate_trend_old({{time=100,value=80,max=100},{time=99,value=80,max=100}}));assert(r.n==2 and r[1]==0 and r[2]==1,'an unchanged reading is not a zero trend')
    r=pack(a.calculate_trend_old({{time=100,value=80,max=100}}));assert(r.n==1 and r[1]==0,'a single reading returned NaN')
end)
test('trend time rounding and malformed-input errors remain live compatibility services',function()
    local f,a=fixture();local calls=0;f.env.GetTime=function(...) assert(select('#',...)==0);calls=calls+1;return 100 end;a.db.profile.damage_history=10
    local original=a.round;local rounds=0;a.Functions.values.round=function() error('canonical rounding must not replace live legacy dispatch') end
    a.round=function(...) assert(select('#',...)==1);rounds=rounds+1;return original(...) end
    a.calculate_trend(history());assert(rounds==5 and calls==1,'current stream rounding or time query changed')
    a.calculate_trend_old({{time=100,value=80,max=100}});assert(rounds==6 and calls==2,'legacy rounding/time query changed')
    a.round=function() error('LIVE_ROUND') end
    for _,case in ipairs({{a.calculate_trend,history()},{a.calculate_trend_old,{{time=100,value=80,max=100}}}}) do local ok,why=pcall(case[1],case[2]);assert(not ok and tostring(why):find('LIVE_ROUND',1,true)) end
    a.round=original;f.env.GetTime=function() error('LIVE_CLOCK') end;local ok,why=pcall(a.calculate_trend,history());assert(not ok and tostring(why):find('LIVE_CLOCK',1,true))
    f.env.GetTime=function() return 100 end;assert(not pcall(a.calculate_trend,{damage={}}),'missing heals became tolerated');assert(not pcall(a.calculate_trend_old,1),'malformed legacy array became tolerated')
end)
test('raw saved function source keeps its dynamic legacy aliases and tuple arity',function()
    local _,a=fixture()
    for index,name in ipairs({'calculate_trend','calculate_trend_old'}) do
        local source={description='Raw saved trend consumer',args={{name='history',type='table'}},returns={},bindings={},code='return addon.'..name..'(history)'};local before=a:CopySettingsData(source)
        assert(a:InstallCustomFunction('RAW_TREND_'..index,source));local fn=a:ResolveFunctionBinding('RAW_TREND_'..index)
        a[name]=function() return 19,nil,'legacy' end;local r=pack(fn({}));assert(r.n==3 and r[1]==19 and r[2]==nil and r[3]=='legacy','raw source stopped using live legacy alias')
        assert(a:SettingsDataEqual(source,before),'raw saved source rewritten')
    end
end)
if arg[1]~='--runtime-only' then
    test('new actual public trend sources compile with exact owners and no invented historical IDs',function()
        local f,a=fixture();f.env.GetTime=function() return 100 end;a.db.profile.damage_history=10
        for _,case in ipairs({{'calculate','calculate_trend',4},{'calculateOld','calculate_trend_old',1}}) do
            local id='builtin:Functions/trends.lua:'..case[1];local record=assert(a.builtinFunctions[id],'current trend catalog missing')
            assert(a:ResolveFunctionBinding(id)==a.Functions.trends[case[1]] and a.builtinSourceModules['Functions/trends.lua'](case[1])==a[case[2]],'actual source getter owner changed')
            assert(#record.source.args==case[3] and next(record.source.bindings)==nil and record.source.code==body(a[case[2]]),'public source signature/body/captures changed')
            assert(not a.builtinFunctions['builtin:utils.lua:'..case[2]] and a.builtinSourceModules['utils.lua'](case[2])==nil,'invented historical trend source ID')
            assert(a:InstallCustomFunction('COPY_TREND_'..case[1],a:CopySettingsData(record.source)));local copy=a:ResolveFunctionBinding('COPY_TREND_'..case[1]);local r=pack(copy(nil));assert(r.n==1 and r[1]==0)
            if case[1]=='calculate' then r=pack(copy(history()));assert(r.n==2 and same(r[1],-223/34) and r[2]==3) else r=pack(copy({}));assert(r.n==1 and r[1]==0) end
            a.round=function() error('CLONE_LIVE_ROUND') end;local ok,why=pcall(copy,case[1]=='calculate' and history() or {{time=100,value=80,max=100}});assert(not ok and tostring(why):find('CLONE_LIVE_ROUND',1,true))
        end
    end)
end
finish()
