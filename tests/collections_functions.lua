local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local names={'keys','spairs','tomap','index','tablelength','multiinsert','cleanArray','deepcopy','compareArray'}
local function fixture()
    local f=F.new();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua');f.load('Core/function_data.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,f.addon
end
local function owner(a) return assert(a.Functions.collections,'owned collections module missing') end
local function equal(actual,expected)
    for key,value in pairs(expected) do assert(actual[key]==value,'unexpected value for '..tostring(key)) end
    for key,value in pairs(actual) do assert(expected[key]==value,'unexpected extra key '..tostring(key)) end
end
local function record(a,name)
    local id='builtin:Functions/collections.lua:'..name
    return assert(a.builtinFunctions[id],'canonical collection source missing: '..name),id
end
test('collection implementations have one actual owner and retain all legacy addon APIs',function()
    local f,a=fixture();local c=owner(a)
    for _,name in ipairs(names) do
        assert(a[name]==c[name] and debug.getinfo(c[name],'S').source=='@Functions/collections.lua','implementation was only aliased')
        local r,id=record(a,name);assert(r.source.namespace=='Functions.collections' and r.callName=='Functions.collections.'..name)
        assert(a:ResolveFunctionBinding(id)==c[name] and a.builtinSourceModules['Functions/collections.lua'](name)==c[name])
        assert(not a.builtinFunctions['builtin:utils.lua:'..name] and not a.builtinSourceModules['utils.lua'](name),'invented a historical collection identity')
    end
    assert(not f.env.Functions)
    assert(a:InstallCustomFunction('OLD_COLLECTION_API',{description='Existing addon API consumer',args={},returns={},bindings={},code='return addon.tablelength(addon.deepcopy({keep=false,drop=true},{"drop"}))'}))
    assert(a:ResolveFunctionBinding('OLD_COLLECTION_API')()==1)
end)
test('keys sorts keys by their values rather than sorting their names',function()
    local _,a=fixture();local c=a.Functions.collections or a
    equal(c.keys({alpha=3,beta=1,gamma=2}),{'beta','gamma','alpha'})
    assert(#c.keys({})==0 and not pcall(c.keys,{a=false,b=true}))
    local ties=c.keys({a=1,b=1});assert(#ties==2 and ties[1]~=ties[2])
end)
test('spairs snapshots keys while reading live values and preserving its iterator contract',function()
    local _,a=fixture();local c=a.Functions.collections or a;local values={b=2,a=1};local iterator=c.spairs(values)
    values.a=false;values.c=3
    local k,v=iterator();assert(k=='a' and v==false);k,v=iterator();assert(k=='b' and v==2 and iterator()==nil and iterator()==nil)
    values.a=1
    local checked=0;local ordered=c.spairs(values,function(t,lhs,rhs) assert(t==values);checked=checked+1;return t[lhs]>t[rhs] end)
    assert(checked>0);local keys={};for key in ordered do keys[#keys+1]=key end;equal(keys,{'c','b','a'})
    assert(select('#',c.spairs({}))==1 and c.spairs({[false]='legacy false key'})()==nil)
end)
test('tomap stringifies keys with captured tostring while preserving value identity and collisions',function()
    local f,a=fixture();local c=a.Functions.collections or a;local nested={};local values={[2]=false,key=nested}
    f.env.tostring=function() return 'changed global tostring' end
    equal(c.tomap(values),{['2']=false,key=nested});assert(next(c.tomap({}))==nil)
    local collision=c.tomap({[1]='numeric',['1']='string'});assert(c.tablelength(collision)==1 and (collision['1']=='numeric' or collision['1']=='string'))
end)
test('index and tablelength retain nil false and sparse-map semantics',function()
    local f,a=fixture();local c=a.Functions.collections or a;local nested={}
    f.env.pairs=function() error('late replacement of captured pairs') end
    assert(c.index(nil,'x')==nil and c.index(false,'x')==nil and c.index({item=false},false)=='item')
    assert(c.index({[false]=nested},nested)==false and c.index({nested}, {})==nil and c.index({},nil)==nil)
    assert(c.tablelength(nil)==0 and c.tablelength({[5]=false,a=true,[false]='x'})==3 and not pcall(c.tablelength,false))
end)
test('multiinsert inserts values at matching leading indices and returns no results',function()
    local _,a=fixture();local c=a.Functions.collections or a;local nested={};local target={'old1','old2'}
    assert(select('#',c.multiinsert(target,{nested,false}))==0);equal(target,{nested,false,'old1','old2'})
    c.multiinsert(target,{[1]='first',[3]='ignored after hole'});assert(target[1]=='first' and target[2]==nested and #target==5)
end)
test('cleanArray mutates in place and except invert select keys using list values',function()
    local _,a=fixture();local c=a.Functions.collections or a
    assert(select('#',c.cleanArray(nil))==0)
    local source={a=false,b=2,c=3};assert(select('#',c.cleanArray(source,{'a'}))==0);equal(source,{a=false})
    source={a=false,b=2,c=3};c.cleanArray(source,{'a'},true);equal(source,{b=2,c=3})
    source={a=1,b=2};c.cleanArray(source,{a='b'});equal(source,{b=2})
    source={a=1};c.cleanArray(source,nil,true);equal(source,{a=1});c.cleanArray(source);assert(next(source)==nil)
end)
test('deepcopy remains a shallow filtered copy with inverse exception behavior to cleanArray',function()
    local _,a=fixture();local c=a.Functions.collections or a;local nested={};local source=setmetatable({a=false,b=nested},{__index={inherited=true}});source.self=source
    local copy=c.deepcopy(source);assert(copy~=source and copy.b==nested and copy.self==source and getmetatable(copy)==nil and copy.a==false and copy.inherited==nil)
    equal(c.deepcopy(source,{'a','self'}),{b=nested});equal(c.deepcopy(source,{'a'},true),{a=false})
    assert(next(c.deepcopy(source,nil,true))==nil and c.deepcopy(nil)==nil and source.b==nested)
end)
test('compareArray compares both key sets shallowly and preserves false versus missing',function()
    local _,a=fixture();local c=a.Functions.collections or a;local nested={}
    assert(c.compareArray({a=false,b=nested},{a=false,b=nested}) and c.compareArray({},{}))
    assert(not c.compareArray({a=false},{}) and not c.compareArray({},{a=false}) and not c.compareArray({a={}},{a={}}))
    assert(not pcall(c.compareArray,nil,{}) and not pcall(c.compareArray,{},nil))
    assert(c.compareArray({a=1},setmetatable({},{__index={a=1}})),'normal indexing metamethod was bypassed')
    local meta={__eq=function() return true end};assert(c.compareArray({a=setmetatable({},meta)},{a=setmetatable({},meta)}),'Lua equality metamethod was bypassed')
end)
test('real editable collection clones retain ordering mutation and shallow identity contracts',function()
    local _,a=fixture();owner(a);local copies={}
    for _,name in ipairs(names) do local r=record(a,name);assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(r.source)));copies[name]=assert(a:ResolveFunctionBinding('COPY_'..name)) end
    equal(copies.keys({a=2,b=1}),{'b','a'})
    local order={};for key in copies.spairs({b=false,a=true}) do order[#order+1]=key end;equal(order,{'a','b'})
    local nested={};equal(copies.tomap({[3]=nested}),{['3']=nested});assert(copies.index({key=false},false)=='key' and copies.tablelength({x=false})==1)
    local target={nested};copies.multiinsert(target,{false});equal(target,{false,nested})
    target={a=false,b=nested};copies.cleanArray(target,{'a'});equal(target,{a=false})
    local copy=copies.deepcopy({a=false,b=nested},{'a'});assert(copy.b==nested and copy.a==nil and copies.compareArray(copy,{b=nested}))
end)
test('new collection dependencies import by current source without invented old namespace compatibility',function()
    local _,a=fixture();owner(a)
    for _,name in ipairs(names) do
        local r,id=record(a,name)
        local bundle=assert(a:BuildFunctionBundle('function','REQUIRE_'..name,{description='Collection dependency',args={},returns={},code='return helper',bindings={helper=id}},false))
        assert(assert(a:PlanFunctionBundleImport(bundle)).valid)
        local altered=a:CopySettingsData(r.source);altered.namespace='utils'
        for _,requirement in ipairs(bundle.requirements) do if requirement.id==id then requirement.hash=a:FunctionSourceHash(altered) end end
        assert(not assert(a:PlanFunctionBundleImport(bundle)).valid,'new helper accepted invented utils namespace history')
    end
end)
finish()
