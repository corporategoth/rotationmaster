local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local owners={round='values',isint='values',starts_with='text',ends_with='text'}
local function identity(name) return 'builtin:Functions/'..owners[name]..'.lua:'..name end
local function fixture()
    local f=F.new();local a=f.addon
    f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua');f.load('Core/function_data.lua')
    f.env.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,a
end
local function owner(a,name) return assert(a.Functions[owners[name]][name],'canonical '..name..' missing') end
test('remaining pure bodies have physical owners and direct legacy aliases without invented legacy source identities',function()
    local f,a=fixture()
    for name,namespace in pairs(owners) do local fn=owner(a,name)
        assert(a[name]==fn and debug.getinfo(fn,'S').source=='@Functions/'..namespace..'.lua','pure helper is still physically owned by utils')
        assert(not a.builtinFunctions['builtin:utils.lua:'..name],'invented historical helper source')
    end
    assert(not f.env.Functions)
end)
test('round keeps the original asymmetric formula decimal places captures and error contract',function()
    local f,a=fixture();local round=owner(a,'round')
    for _,case in ipairs({{-1.5,nil,-1},{-.5,nil,0},{.5,nil,1},{1.5,nil,2},{-1.25,1,-1.2},{123,-1,120},{1.2345,3,1.235}}) do
        assert(round(case[1],case[2])==case[3] and select('#',round(case[1],case[2]))==1)
    end
    assert(not pcall(round,nil) and not pcall(round,{},1))
    f.env.math=setmetatable({floor=function() error('round lost captured floor') end},{__index=math})
    assert(round(1.5)==2)
end)
test('isint retains canonical spelling nonfinite legacy inputs and captured primitive functions',function()
    local f,a=fixture();local isint=owner(a,'isint')
    for _,value in ipairs({0,1,-1,'1','-1','nan','inf','-inf'}) do assert(isint(value)==true,tostring(value)) end
    for _,value in ipairs({1.5,'01','1.0','+1',' 1','1e0','',false,{}}) do assert(isint(value)==false,tostring(value)) end
    assert(isint(nil)==false and select('#',isint(1))==1)
    f.env.type=function() error('isint lost captured type') end;f.env.tonumber=function() error('isint lost captured tonumber') end
    f.env.tostring=function() error('isint lost captured tostring') end
    f.env.math=setmetatable({floor=function() error('isint lost captured floor') end},{__index=math})
    assert(isint('1') and not isint('01') and isint(2))
end)
test('literal prefix and suffix helpers preserve empty needles exact bytes case and errors',function()
    local _,a=fixture();local starts,ends=owner(a,'starts_with'),owner(a,'ends_with')
    assert(starts('abc','') and starts('','') and starts('[x].','[x]') and not starts('Abc','a') and not starts('a','abc'))
    assert(ends('abc','') and ends('','') and ends('[x].','[x].') and not ends('abc','B') and not ends('a','abc'))
    assert(select('#',starts('abc','a'))==1 and select('#',ends('abc','c'))==1)
    assert(not pcall(starts,nil,'a') and not pcall(starts,'a',nil) and not pcall(ends,nil,'a') and not pcall(ends,'a',nil))
end)
test('new canonical sources compile real copies and transport explicit dependency bundles',function()
    local _,a=fixture()
    for name,namespace in pairs(owners) do local id=identity(name);local record=assert(a.builtinFunctions[id],'canonical source missing: '..name)
        assert(record.public and record.source.namespace=='Functions.'..namespace and record.source.name==name)
        assert(a:ResolveFunctionBinding(id)==owner(a,name) and a.builtinSourceModules['Functions/'..namespace..'.lua'](name)==owner(a,name))
        assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)));local copy=assert(a:ResolveFunctionBinding('COPY_'..name))
        if name=='round' then assert(copy(-1.5)==-1 and copy(1.2345,3)==1.235)
        elseif name=='isint' then assert(copy('1') and not copy('01') and copy('nan'))
        elseif name=='starts_with' then assert(copy('[a]','[') and not copy('A','a'))
        else assert(copy('abc','') and copy('[a]',']') and not copy('A','a')) end
        local consumer={description='Canonical pure consumer',args={},returns={},bindings={helper=id},code=name=='round' and 'return helper(-1.5)' or name=='isint' and 'return helper("01")' or 'return helper("abc", "a")'}
        local bundle=assert(a:BuildFunctionBundle('function','USE_'..name,consumer,true));local plan=assert(a:PlanFunctionBundleImport(bundle));assert(plan.valid and a:ApplyFunctionBundleImport(plan))
        local result=a:ResolveFunctionBinding('USE_'..name)();assert(result==(name=='round' and -1 or name=='starts_with'))
    end
    local floor=assert(a.builtinFunctions['builtin:Functions/values.lua:floor'],'captured floor value missing')
    assert(floor.valueBinding and a:ResolveFunctionBinding('builtin:Functions/values.lua:floor')==math.floor)
end)
test('all prior utility source hashes and source-bound live dispatches remain exact',function()
    local f,a=fixture();local rows={}
    local forecastAdditions={}
    for _,name in ipairs({'Forecast_calculate','finite','readField'}) do
        local id='builtin:Functions/forecast.lua:'..name
        assert(a.builtinFunctions[id],'new forecast source missing: '..id);forecastAdditions[id]=true
    end
    for id,record in pairs(a.builtinFunctions) do
        local new=forecastAdditions[id] or id=='builtin:Functions/values.lua:floor' or id=='builtin:Functions/trends.lua:calculate' or id=='builtin:Functions/trends.lua:calculateOld'
        for name in pairs(owners) do new=new or id==identity(name) end
        if not new and (id:match('^builtin:utils.lua:') or id:match('^builtin:Functions/')) then rows[#rows+1]=id..'='..a:FunctionSourceHash(record.source) end
    end
    table.sort(rows);assert(#rows==32 and a:FunctionSourceHash({text=table.concat(rows,'\n')})=='65b4cd2a','old utility source record changed')
    f.load('Conditions/common.lua');f.load('Conditions/totem.lua')
    for id,hash in pairs({['builtin:Conditions/common.lua:Widget_SpellWidget']='0e324b13',['builtin:Conditions/totem.lua:findSpecific']='f753db9d',['builtin:Conditions/totem.lua:observe']='e59e23eb'}) do
        assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash,'source-bound live helper changed: '..id)
    end
    local raw={description='Saved raw pure helper calls',args={},returns={},bindings={},code='return addon.round(1.5),addon.isint("01"),addon.starts_with("abc","a"),addon.ends_with("abc","c")'}
    local before=a:CopySettingsData(raw);assert(a:InstallCustomFunction('SAVED_RAW_PURE',raw));local fn=a:ResolveFunctionBinding('SAVED_RAW_PURE')
    local one,two,three,four=fn();assert(one==2 and two==false and three==true and four==true)
    a.round=function() return 91 end;a.isint=function() return 'integer override' end
    a.starts_with=function() return 'prefix override' end;a.ends_with=function() return 'suffix override' end
    one,two,three,four=fn();assert(one==91 and two=='integer override' and three=='prefix override' and four=='suffix override')
    assert(a:SettingsDataEqual(before,raw))
end)
finish()
