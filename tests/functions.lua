local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('Core/custom_authoring.lua');local file=io.open('Core/functions.lua');if file then file:close();f.load('Core/functions.lua') end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,f.addon
end
local function source(code,bindings)
    return {description='Example utility',args={{name='value',type='number',description='Input value'}},returns={{type='number',description='Result'}},code=code,bindings=bindings or {}}
end
test('custom utility functions compile on registration and share explicit named bindings',function()
    local f,a=fixture();assert(a.InstallCustomFunction,'function registry missing')
    local compiles=0;local compiler=f.env.loadstring;f.env.loadstring=function(...) compiles=compiles+1;return compiler(...) end
    assert(a:InstallCustomFunction('DOUBLE',source('return value * 2')))
    assert(a:InstallCustomFunction('PLUS',source('return twice(value) + 1',{twice='DOUBLE'})))
    local fn=assert(a:ResolveFunctionBinding('PLUS'));local before=compiles;for i=1,20 do assert(fn(i)==i*2+1) end;assert(compiles==before)
    assert(a.db.global.custom_functions.DOUBLE.code=='return value * 2')
end)
test('disabled dependencies make all transitive utility consumers unavailable and recover on enable',function()
    local _,a=fixture();assert(a:InstallCustomFunction('BASE',source('return value')));assert(a:InstallCustomFunction('OUTER',source('return inner(value)',{inner='BASE'})))
    local old=a:CopySettingsData(a.db.global.custom_functions.BASE);local disabled=a:CopySettingsData(old);disabled.disabled=true
    assert(a:InstallCustomFunction('BASE',disabled,old));assert(not a:FunctionAvailable('OUTER'));assert(not a:ResolveFunctionBinding('OUTER'))
    assert(a:InstallCustomFunction('BASE',old,disabled));assert(a:FunctionAvailable('OUTER'));assert(a:ResolveFunctionBinding('OUTER')(5)==5)
end)
test('cycles invalid syntax and stale replacements cannot partially replace the registry',function()
    local _,a=fixture();assert(a:InstallCustomFunction('A',source('return value')));assert(a:InstallCustomFunction('B',source('return inner(value)',{inner='A'})))
    local previous=a:CopySettingsData(a.db.global.custom_functions.A);local registry=a.functionRegistry
    assert(not a:InstallCustomFunction('A',source('return other(value)',{other='B'}),previous));assert(a.functionRegistry==registry and a:ResolveFunctionBinding('B')(3)==3)
    assert(not a:InstallCustomFunction('A',source('return )'),previous));assert(not a:InstallCustomFunction('A',source('return value+1'),{}))
    local broken=source('return )');broken.disabled=true;assert(a:InstallCustomFunction('BROKEN',broken));assert(not a:FunctionAvailable('BROKEN'))
end)
test('packaged bindings stay read-only and lazy getters preserve live module state',function()
    local _,a=fixture();local number=3
    assert(a:RegisterBuiltinFunction('builtin:example',{description='Builtin helper',args={},returns={},code='return number'},function() return function() return number end end))
    assert(a:InstallCustomFunction('USE',source('return original() + value',{original='builtin:example'})));number=9;assert(a:ResolveFunctionBinding('USE')(1)==10)
    assert(not a:InstallCustomFunction('builtin:example',source('return 0')))
end)
test('shared dependency graphs are bounded and malformed saved registries fail closed',function()
    local _,a=fixture();a.db.global.custom_functions={BASE=source('return value')};local previous='BASE'
    for i=1,12 do local id='L'..i;a.db.global.custom_functions[id]=source('return first(value)+second(value)',{first=previous,second=previous});previous=id end
    a:InitializeFunctionRegistry();local calls=0;local available=a.FunctionAvailable;a.FunctionAvailable=function(self,...) calls=calls+1;return available(self,...) end
    assert(a:FunctionAvailable(previous) and calls<64,'dependency traversal repeats the same graph exponentially')
    a.db.global.custom_functions=false;a:InitializeFunctionRegistry();assert(not a:FunctionAvailable('BASE'))
end)
test('condition callbacks share utility bindings and disabled dependencies stay unavailable through NOT',function()
    local f,a=fixture();f.load('Core/conditions.lua');assert(a:InstallCustomFunction('READY',source('return true')))
    local condition={description='Helper condition',icon='Interface\\Icons\\INV_Misc_QuestionMark',fields={},valid='return true',evaluate='return ready(1)',print='return "Helper"',widget='',help='',on_register='',on_unregister='',bindings={ready='READY'}}
    local definition,why=a:CompileCustomCondition('HELPER',condition);assert(definition,why and why.reason);a:RegisterCondition('HELPER',definition)
    assert(a:evaluateConditionResult({type='HELPER'}).status=='match')
    local saved=a:CopySettingsData(a.db.global.custom_functions.READY);local disabled=a:CopySettingsData(saved);disabled.disabled=true;assert(a:InstallCustomFunction('READY',disabled,saved))
    assert(a:evaluateConditionResult({type='NOT',value={type='HELPER'}}).status=='unavailable')
    assert(a:InstallCustomFunction('READY',saved,disabled));assert(a:evaluateConditionResult({type='HELPER'}).status=='match')
end)
test('saved unavailable consumers survive registration and recover lifecycle when helpers are enabled',function()
    local f,a=fixture();f.load('Core/conditions.lua');f.load('Options/custom_condition.lua')
    local helper=source('return true');helper.disabled=true;assert(a:InstallCustomFunction('READY',helper))
    local c={description='Dependent',icon=134400,fields={},evaluate='return ready(1)',valid='return true',print='return "Dependent"',widget='',help='',on_register='addon.registered=(addon.registered or 0)+1',on_unregister='addon.unregistered=(addon.unregistered or 0)+1',bindings={ready='READY'}}
    a.db.global.custom_conditions={DEPENDENT=c};assert(a:register_custom_condition('DEPENDENT',c));assert(a.conditionDefinitions.DEPENDENT and not a.registered)
    local enabled=a:CopySettingsData(helper);enabled.disabled=nil;assert(a:InstallCustomFunction('READY',enabled,helper));assert(a.registered==1 and a:evaluateConditionResult({type='DEPENDENT'}).status=='match')
    assert(a:InstallCustomFunction('READY',helper,enabled));assert(a.unregistered==1 and a:evaluateConditionResult({type='NOT',value={type='DEPENDENT'}}).status=='unavailable')
    local disabled=a:CopySettingsData(c);disabled.disabled=true;assert(a:InstallCustomCondition('DEPENDENT',disabled,a.conditionDefinitions.DEPENDENT,c));assert(a.unregistered==1)
end)
test('wrapper escape text cannot run while compiling a function registry',function()
    local f,a=fixture();local injected=source('end, (function() previewExecuted=true end)(), function()')
    local checked=a:ValidateCustomFunctionSource('ESCAPE',injected);local registry=a:BuildFunctionRegistry({ESCAPE=injected})
    assert(not checked and not f.env.previewExecuted and registry.ESCAPE.problem and not registry.ESCAPE.fn,'function body escaped the compile-only boundary')
end)
finish()
