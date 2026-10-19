local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local names={'split','wrap','trim'}
local oldHashes={split='b08ca976',wrap='f1a74632',trim='6f81e02c'}
local function fixture()
    local f=F.new();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua');f.load('Core/function_data.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,f.addon
end
local function owner(a) return assert(a.Functions.text,'owned text module missing') end
local function id(name) return 'builtin:utils.lua:'..name end
test('text implementations preserve legacy APIs stable identities and source getter aliases',function()
    local f,a=fixture();local text=owner(a)
    for _,name in ipairs(names) do
        local r=assert(a.builtinFunctions[id(name)]);assert(r.source.namespace=='Functions.text' and a[name]==text[name] and a:ResolveFunctionBinding(id(name))==text[name])
        assert(a.builtinSourceModules['utils.lua'](name)==text[name] and not a.builtinFunctions['builtin:Functions/text.lua:'..name])
    end
    assert(not f.env.Functions)
end)
test('split retains character-class separators whitespace defaults empty-field omission and shared string identity',function()
    local f,a=fixture();local text=owner(a)
    assert(table.concat(text.split('one  two\tthree'),'|')=='one|two|three')
    assert(table.concat(text.split('a,,b,',','),'|')=='a|b' and #text.split('',',')==0)
    assert(table.concat(text.split('a,b;c',',;'),'|')=='a|b|c','separator became a literal multi-character delimiter')
    assert(a:ResolveFunctionBinding('builtin:utils.lua:string')==f.env.string,'captured string table identity changed')
end)
test('wrapping preserves existing whitespace long words defaults and exactly one returned value',function()
    local _,a=fixture();local text=owner(a)
    assert(text.wrap('one two three four',7)=='one two\nthree\nfour')
    assert(text.wrap('superlongword short word',7)=='superlongword\nshort\nword')
    assert(text.wrap('one\ntwo three',7)=='one\ntwo\nthree' and text.wrap('short unchanged')=='short unchanged')
    assert(select('#',text.wrap('one two three',7))==1,'gsub substitution count leaked into the API')
end)
test('trim preserves internal whitespace and its single-result contract',function()
    local _,a=fixture();local text=owner(a)
    assert(text.trim(' \t value  with spaces\r\n')=='value  with spaces' and text.trim(' \t\n')=='' and text.trim('')=='')
    assert(select('#',text.trim(' value '))==1,'gsub substitution count leaked into the API')
end)
test('real text helper clones preserve bodies captures old hashes and strict namespace-only import compatibility',function()
    local _,a=fixture();local text=owner(a)
    for _,name in ipairs(names) do
        local record=a.builtinFunctions[id(name)];local old=a:CopySettingsData(record.source);old.namespace='utils'
        assert(a:FunctionSourceHash(old)==oldHashes[name],'historical '..name..' source changed')
        if name=='split' then assert(old.bindings.string=='builtin:utils.lua:string') end
        assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)));local copy=assert(a:ResolveFunctionBinding('COPY_'..name))
        if name=='split' then assert(table.concat(copy('a,,b',','),'|')=='a|b') elseif name=='wrap' then assert(copy('one two three four',7)==text.wrap('one two three four',7)) else assert(copy(' x ')=='x') end
        local source={description='Legacy text consumer',args={},returns={},code='return helper("one two")',bindings={helper=id(name)}}
        local bundle=assert(a:BuildFunctionBundle('function','LEGACY_'..name,source,false))
        for _,requirement in ipairs(bundle.requirements) do if requirement.id==id(name) then requirement.hash=oldHashes[name] end end
        local plan=assert(a:PlanFunctionBundleImport(bundle));assert(plan.valid and a:ApplyFunctionBundleImport(plan))
        local legacy=assert(a:ResolveFunctionBinding('LEGACY_'..name));local expected=text[name]('one two')
        if name=='split' then assert(table.concat(legacy(),'|')==table.concat(expected,'|')) else assert(legacy()==expected) end
        for _,change in ipairs({
            function(changed) changed.code=changed.code..'\nreturn nil' end,
            function(changed) changed.description=changed.description..' changed' end,
            function(changed) changed.args[1].type='table' end,
            function(changed) changed.returns[1].description='changed return contract' end,
            function(changed) changed.namespace='arbitrary' end,
        }) do
            local changed=a:CopySettingsData(old);change(changed)
            for _,requirement in ipairs(bundle.requirements) do if requirement.id==id(name) then requirement.hash=a:FunctionSourceHash(changed) end end
            assert(not assert(a:PlanFunctionBundleImport(bundle)).valid,'old namespace compatibility ignored a changed source contract')
        end
        if name=='split' then
            local changed=a:CopySettingsData(old);changed.bindings.string='builtin:Functions/text.lua:string'
            for _,requirement in ipairs(bundle.requirements) do if requirement.id==id(name) then requirement.hash=a:FunctionSourceHash(changed) end end
            assert(not assert(a:PlanFunctionBundleImport(bundle)).valid,'old namespace compatibility ignored the captured string identity')
        end
    end
end)
test('collector verifies the captured original string table rather than trusting an arbitrary table alias',function()
    local env=setmetatable({dofile=function(path)
        local result=dofile(path)
        if path=='tools/public_helpers.lua' then result.split.captureBindings={string='builtin:utils.lua:cachedResult'} end
        return result
    end,print=function() end},{__index=_G})
    local tool=assert(loadfile('tools/collect_builtin_sources.lua'));setfenv(tool,env)
    local ok,why=pcall(tool);assert(not ok and tostring(why):find('captured binding getter mismatch',1,true),'collector trusted a mismatched captured string table')
end)
finish()
