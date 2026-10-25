local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local names={'nullable','nullable_value','compareString','playerize'}
local historical={nullable='01ae36cb',nullable_value='eeca0663'}
local function fixture()
    local f=F.new();local a=f.addon
    f.load('Platform/range.lua');f.load('Core/conditions.lua');f.load('Conditions/common.lua');f.load('Conditions/spatial.lua')
    f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua');f.load('Core/function_data.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,a
end
local function owner(a) return assert(a.Functions.presentation,'owned presentation module missing') end
local function id(name) return 'builtin:utils.lua:'..name end
test('presentation implementations own canonical helpers while legacy APIs IDs and source getters remain available',function()
    local f,a=fixture();local p=owner(a)
    for _,name in ipairs(names) do
        local record=assert(a.builtinFunctions[id(name)]);assert(a[name]==p[name] and a:ResolveFunctionBinding(id(name))==p[name])
        assert(record.source.namespace=='Functions.presentation' and record.source.name==name)
        assert(a.builtinSourceModules['utils.lua'](name)==p[name] and not a.builtinFunctions['builtin:Functions/presentation.lua:'..name])
    end
    local legacy={description='Saved legacy presentation calls',args={},returns={},bindings={},code='return addon.nullable(false),addon.nullable_value("key",{key=false}),addon.playerize("player","you","target"),addon.compareString("EQUALS","left","right")'}
    assert(a:InstallCustomFunction('LEGACY_PRESENTATION_APIS',legacy));local first,second,third,fourth=a:ResolveFunctionBinding('LEGACY_PRESENTATION_APIS')()
    assert(first==false and second==false and third=='you' and fourth==p.compareString('EQUALS','left','right'))
    assert(a:ResolveFunctionBinding('builtin:utils.lua:color')==f.env.color,'shared captured color identity changed')
    assert(not f.env.Functions)
end)
test('nullable and lookup formatting preserve nil false malformed maps translated placeholders and shared colors',function()
    local f,a=fixture();local p=owner(a);local color=f.env.color
    f.translations['<value>']='Translated value';color.RED='[red]';color.RESET='[reset]'
    assert(p.nullable(nil)=='[red]Translated value[reset]' and p.nullable(nil,'Custom')=='[red]Custom[reset]')
    assert(p.nullable(false)==false and p.nullable(0)==0 and p.nullable('')=='')
    assert(p.nullable_value('key',{key=false})==false and p.nullable_value('key',{key=0})==0)
    for _,map in ipairs({false,42,'invalid',{},function() end}) do assert(p.nullable_value('missing',map,'Fallback')=='[red]Fallback[reset]') end
    assert(p.nullable_value(nil,{key=1})=='[red]Translated value[reset]' and p.nullable_value('key',nil)=='[red]Translated value[reset]')
end)
test('comparison wording preserves every operator primary alternatives captured operators and live negation data',function()
    local f,a=fixture();local p=owner(a);local original=a.operators
    for operator,positive in pairs(original) do
        local negative=a.negatedOperators[operator];local expected='L '..(negative and '{{'..positive..'|'..negative..'}}' or positive)..' R'
        assert(p.compareString(operator,'L','R')==expected)
        if negative then assert(p.compareString(operator,'L','R',true)=='L {{!'..positive..'|'..negative..'}} R') end
    end
    f.translations['<operator>']='Translated operator';local missing=p.compareString('UNKNOWN','L','R')
    assert(missing=='L '..f.env.color.RED..'Translated operator'..f.env.color.RESET..' R')
    original.EQUALS='same';a.operators={EQUALS='replacement'};a.negatedOperators={EQUALS='different'}
    assert(p.compareString('EQUALS',1,2,true)=='1 {{!same|different}} 2','captured positive map or live negative map changed')
end)
test('player selection retains exact chosen values and legacy nullable dispatch stays live',function()
    local _,a=fixture();local p=owner(a);local marker={}
    assert(p.playerize('player',false,marker)==false and p.playerize('target',false,marker)==marker and p.playerize(nil,nil,0)==0)
    a.nullable=function(value,default) return value==nil and 'override:'..default or value end
    assert(p.nullable_value('missing',{},'Fallback')=='override:Fallback')
    a.operators.EQUALS=nil;assert(p.compareString('EQUALS','L','R'):find('override:',1,true),'legacy dispatch was frozen or silently rewritten')
end)
test('compiled presentation helpers and real Distance Count summary retain actual behavior with explicit private dependencies',function()
    local f,a=fixture();local p=owner(a)
    for _,name in ipairs(names) do
        local record=a.builtinFunctions[id(name)];assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)))
        local copy=assert(a:ResolveFunctionBinding('COPY_'..name))
        if name=='nullable' then assert(copy(nil,'Missing')==p[name](nil,'Missing') and copy(false)==false)
        elseif name=='nullable_value' then assert(copy('key',{key=false})==false)
        elseif name=='playerize' then assert(copy('player',false,true)==false)
        else assert(copy('EQUALS','left','right',true)==p[name]('EQUALS','left','right',true)) end
    end
    local source=assert(a:GetBuiltinConditionSource('DISTANCE_COUNT'))
    assert(source.print:find('Functions.presentation.compareString',1,true) and source.bindings['Functions.presentation.nullable']==id('nullable'))
    assert(source.bindings.Functions==nil)
    local copy=assert(a:CompileCustomCondition('COPY_DISTANCE_COUNT_PRESENTATION',source));a:RegisterCondition('COPY_DISTANCE_COUNT_PRESENTATION',copy);local value={enemy=true,operator='EQUALS',distance=10,value=0}
    assert(copy.print(0,value)==a.conditionDefinitions.DISTANCE_COUNT.print(0,value))
    assert(not f.env.Functions and not f.env.functions)
end)
test('all spatial summaries use canonical presentation calls with their corrected wording',function()
    local _,a=fixture();local expected={
        PROXIMITY='the number of Raid or Party members within 10 yards of you is greater than 2',
        DISTANCE='you are closer than 2 yards',
        DISTANCE_COUNT='Number of enemies within 10 yards is greater than 2',
        ZONE='in Zone A',
    }
    for tag,text in pairs(expected) do
        local value={unit='player',value=tag=='ZONE' and 'Zone A' or 2,operator='GREATERTHAN',distance=10,enemy=true}
        local definition=a.conditionDefinitions[tag];assert(definition.print(0,value)==text,'original '..tag..' wording changed')
        local source=assert(a:GetBuiltinConditionSource(tag));assert(source.print:find('Functions.presentation.',1,true),tag..' still uses legacy presentation calls')
        assert(not source.print:find('addon.nullable(',1,true) and not source.print:find('addon.playerize(',1,true) and not source.print:find('addon.compareString(',1,true))
        local copy=assert(a:CompileCustomCondition('COPY_SUMMARY_'..tag,source));a:RegisterCondition('COPY_SUMMARY_'..tag,copy);assert(copy.print(0,value)==text,tag..' clone wording changed')
        assert(copy.print(0,value,true)==definition.print(0,value,true),tag..' negated clone wording changed')
    end
end)
test('collector rejects a captured value reference when the existing getter returns a different table',function()
    local env=setmetatable({dofile=function(path)
        local result=dofile(path)
        if path=='tools/public_helpers.lua' then result.nullable.captureBindings={color='builtin:utils.lua:cachedResult'} end
        return result
    end,print=function() end},{__index=_G})
    local tool=assert(loadfile('tools/collect_builtin_sources.lua'));setfenv(tool,env)
    local ok,why=pcall(tool);assert(not ok and tostring(why):find('captured binding getter mismatch',1,true),'collector trusted a mismatched captured table')
end)
test('historical nullable hashes retain their exact color dependency and namespace-only import compatibility',function()
    local _,a=fixture();owner(a)
    for name,hash in pairs(historical) do
        local record=a.builtinFunctions[id(name)];assert(record.source.bindings.color=='builtin:utils.lua:color')
        local old=a:CopySettingsData(record.source);old.namespace='utils';assert(a:FunctionSourceHash(old)==hash,'unchanged historical helper hash drifted')
        local source={description='Legacy presentation consumer',args={},returns={},code=name=='nullable' and 'return helper(nil,"Missing")' or 'return helper("key",{key=false})',bindings={helper=id(name)}}
        local bundle=assert(a:BuildFunctionBundle('function','LEGACY_'..name,source,false))
        for _,requirement in ipairs(bundle.requirements) do if requirement.id==id(name) then requirement.hash=hash end end
        local plan=assert(a:PlanFunctionBundleImport(bundle));assert(plan.valid and a:ApplyFunctionBundleImport(plan))
        local legacy=assert(a:ResolveFunctionBinding('LEGACY_'..name))
        if name=='nullable' then assert(legacy()==a.nullable(nil,'Missing')) else assert(legacy()==false) end
        local changed=a:CopySettingsData(old);changed.bindings.color='builtin:Functions/presentation.lua:color'
        for _,requirement in ipairs(bundle.requirements) do if requirement.id==id(name) then requirement.hash=a:FunctionSourceHash(changed) end end
        assert(not assert(a:PlanFunctionBundleImport(bundle)).valid,'hash compatibility ignored changed captured value identity')
    end
end)
finish()
