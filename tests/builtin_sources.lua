local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,expansion,class)
    local f=F.new(product,expansion,class);f.env.UnitClass=function() return class or 'Shaman',class or 'SHAMAN',7 end;f.load('Core/custom_authoring.lua');f.load('Core/schema_authoring.lua');f.addon.delayed_condition={}
    for _,path in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua'}) do local file=io.open(path);if file then file:close();f.load(path) end end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then f.load(path) end end
    f.addon.conditionDefinitions=f.addon.definitions
    return f,f.addon
end
test('every registered builtin has source with original parameters and compiled clonable callbacks',function()
    local _,a=fixture();assert(a.GetBuiltinConditionSource,'builtin source API missing')
    for id in pairs(a.conditionDefinitions) do
        local source=assert(a:GetBuiltinConditionSource(id),id..' has no source');local clone,why=a:CompileCustomCondition('CLONE_'..id,source)
        assert(clone,id..': '..tostring(why and why.reason));assert(clone.evaluate and clone.print and source.parameters.evaluate)
    end
end)
test('captured helper and class bindings preserve actual clone behavior',function()
    local f,a=fixture();f.env.UnitExists=function() return true end;f.env.UnitAffectingCombat=function() return true end;a.getCached=function(_,fn,...) return fn(...) end
    local source=assert(a:GetBuiltinConditionSource('COMBAT'));local clone=assert(a:CompileCustomCondition('MY_COMBAT',source))
    assert(clone.evaluate({unit='player'},{})==a.conditionDefinitions.COMBAT.evaluate({unit='player'},{}));assert(clone.print(0,{unit='player'})==a.conditionDefinitions.COMBAT.print(0,{unit='player'}))
    local itemSource=assert(a:GetBuiltinConditionSource('CARRYING'));local itemClone=assert(a:CompileCustomCondition('MY_ITEM',itemSource));assert(itemClone.print(0,{item={123},operator='GREATERTHAN',value=0})==a.conditionDefinitions.CARRYING.print(0,{item={123},operator='GREATERTHAN',value=0}))
end)
test('builtin utility source is visible independently and duplicating it needs no source copies',function()
    local _,a=fixture();local record=a.builtinFunctions['builtin:Conditions/talent.lua:integer'];assert(record and not record.valueBinding and record.source.code:find('type(value)',1,true))
    assert(a:InstallCustomFunction('MY_INTEGER',a:CopySettingsData(record.source)));assert(a:ResolveFunctionBinding('MY_INTEGER')(5,1,10)==true and a:ResolveFunctionBinding('MY_INTEGER')('5',1,10)==false)
end)
test('all supported catalog branches have compilable source including deferred integrations',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local _,a=fixture(unpack(case[1]))
        for _,group in pairs(a.delayed_condition) do for id,definition in pairs(group) do a.conditionDefinitions[id]=definition end end
        for id in pairs(a.conditionDefinitions) do local source=assert(a:GetBuiltinConditionSource(id),id);local copy,why=a:CompileCustomCondition('COPY_'..id,source);assert(copy,id..': '..tostring(why and (why.detail or why.reason))) end
    end
end)
test('cloned deferred stat initialization retains shared integration state across callbacks',function()
    local f,a=fixture();local loads=0
    local data={GetStatInfo=function(_,key) return key=='power' and 42 or nil end}
    f.env.ECSLoader={ImportModule=function() loads=loads+1;return data end};f.env.ExtendedCharacterStats={profile={refName='power',text='Power'}}
    a.conditionDefinitions.ECS_STAT=a.delayed_condition.ExtendedCharacterStats.ECS_STAT
    local source=assert(a:GetBuiltinConditionSource('ECS_STAT'));local copy,why=a:CompileCustomCondition('MY_STAT',source);assert(copy,why and why.reason)
    copy.on_register();a.conditionDefinitions.ECS_STAT.on_register();assert(loads==1,'cloned registration did not share the initialized state')
    a.getCached=function(_,fn,...) return fn(...) end
    assert(copy.evaluate({stat='power',operator='GREATERTHAN',value=40},{})==true)
end)
test('glyph clone retains the expansion-scoped player class binding',function()
    local f,a=fixture(19,4,'SHAMAN');f.env.GetItemInfoInstant=function() return nil,nil,nil,nil,nil,16,7 end
    local source=assert(a:GetBuiltinConditionSource('GLYPH'));local copy=assert(a:CompileCustomCondition('MY_GLYPH',source))
    assert(copy.valid(0,{item=123})==true and a.conditionDefinitions.GLYPH.valid(0,{item=123})==true)
end)
test('source display removes only common leading indentation and keeps authored source immutable',function()
    local _,a=fixture();assert(a.FormatLuaSourceDisplay,'display formatter missing')
    local authored='\n        if value then\n            return true\n        end\n    '
    assert(a:FormatLuaSourceDisplay(authored)=='if value then\n    return true\nend')
    assert(a:FormatLuaSourceDisplay('    one\n\t two')=='    one\n\t two','different indentation was silently rewritten')
end)
finish()
