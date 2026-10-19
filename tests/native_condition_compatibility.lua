local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local modules={'Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua'}
local hashes={['Conditions/common.lua']='ffb7bef3',['Conditions/combat.lua']='a287fe2d',['Conditions/talent.lua']='93be2f51'}
local function fixture()
    local f=F.new();f.load('Core/conditions.lua');f.load('Platform/spells.lua');f.env.C_Spell={GetSpellInfo=function(id) return {spellID=id,name='Fixture spell'} end};return f,f.addon
end
local function loadModules(f) for _,path in ipairs(modules) do f.load(path) end end
test('native condition definitions and spell factories load without Ace lookup or layout registration',function()
    local f,a=fixture();local stub=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native condition import looked up Ace');return stub(name,...) end
    f.libraries['AceGUI-3.0'].RegisterLayout=function() error('native condition import registered a legacy layout') end
    loadModules(f)
    local value={spell=123,ranked=false};local group=a:Widget_SpellWidget(0,'Spell_EditBox',value,function(v) return tonumber(v) end,function() return true end,function() end)
    assert(group.layout=='RM-SpellField' and #group.children==3);a:ReleaseConditionWidget(group)
    assert(a.conditionDefinitions.COMBAT and a.conditionDefinitions.TALENT)
end)
test('retained condition library values keep exact source hashes and execute historical captured code',function()
    local f,a=fixture();loadModules(f)
    for _,p in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(p) end
    for index,path in ipairs(modules) do
        local id='builtin:'..path..':AceGUI';assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hashes[path])
        assert(a.builtinSourceModules[path]('AceGUI')==f.libraries['AceGUI-3.0'] and a:ResolveFunctionBinding(id)==f.libraries['AceGUI-3.0'])
        assert(a:InstallCustomFunction('SAVED_CONDITION_LIB_'..index,{description='Saved condition library capture',args={},returns={},bindings={AceGUI=id},code='return AceGUI'}))
        assert(a:ResolveFunctionBinding('SAVED_CONDITION_LIB_'..index)()==f.libraries['AceGUI-3.0'])
    end
end)
test('explicit spell layout compatibility registers once and preserves forwarded arguments',function()
    local f,a=fixture();local calls={};local ace=f.libraries['AceGUI-3.0']
    ace.RegisterLayout=function(_,name,fn) calls[#calls+1]={name=name,fn=fn} end
    f.load('Conditions/common.lua');assert(#calls==0,'native common registered compatibility layout')
    f.load('UI/spell_field_compat.lua');assert(#calls==1 and calls[1].name=='RM-SpellField')
    local content,children={},{};local runs=0
    a.LayoutWorkbenchSpellGroup=function(self,c,k) assert(self==a and c==content and k==children);runs=runs+1 end
    calls[1].fn(content,children);assert(runs==1)
    ace.RegisterLayout=nil;f.load('UI/spell_field_compat.lua');assert(#calls==1)
end)
test('collector rejects missing proxy and foreign library identities for retained condition modules',function()
    local function collect(target,mode)
        local wrapped={new=function(...)
            local f=F.new(...);local load=f.load
            f.load=function(path)
                local result=load(path)
                if path==target then local getter=f.addon.builtinSourceModules[path];local replacement=mode=='proxy' and setmetatable({},{__index=f.libraries['AceGUI-3.0']}) or mode=='foreign' and {} or nil
                    f.addon.builtinSourceModules[path]=function(name) if name=='AceGUI' then return replacement end;return getter(name) end
                end
                return result
            end
            return f
        end}
        local env=setmetatable({dofile=function(path) if path=='tests/fixtures/addon.lua' then return wrapped end;return dofile(path) end,print=function() end},{__index=_G})
        local tool=assert(loadfile('tools/collect_builtin_sources.lua'));setfenv(tool,env);return pcall(tool)
    end
    local ok,why=collect();assert(ok,why)
    for _,path in ipairs(modules) do for _,mode in ipairs({'missing','proxy','foreign'}) do
        ok,why=collect(path,mode);assert(not ok and tostring(why):find('retained widget library identity mismatch: '..path,1,true),path..' accepted '..mode..': '..tostring(why))
    end end
end)
finish()
