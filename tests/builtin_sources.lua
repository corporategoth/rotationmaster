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
    -- Metadata registration uses the fixture's inert registry. Load the real
    -- summary manager for callbacks that return its opaque named protocol.
    local definitions=a.conditionDefinitions;f.load('Core/conditions.lua');a.conditionDefinitions=definitions
    local itemSource=assert(a:GetBuiltinConditionSource('CARRYING'));local itemClone=assert(a:CompileCustomCondition('MY_ITEM',itemSource));local node={item={123},operator='GREATERTHAN',value=0}
    for _,negated in ipairs({false,true}) do assert(a:RenderConditionSummary(itemClone.print(0,node),negated)==a:RenderConditionSummary(a.conditionDefinitions.CARRYING.print(0,node),negated)) end
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
    local data={GetStatInfo=function(key) return key=='power' and 42 or nil end}
    f.env.ECSLoader={ImportModule=function() loads=loads+1;return data end};f.env.ExtendedCharacterStats={profile={refName='power',text='Power'}}
    a.conditionDefinitions.ECS_STAT=a.delayed_condition.ExtendedCharacterStats.ECS_STAT
    local source=assert(a:GetBuiltinConditionSource('ECS_STAT'));local copy,why=a:CompileCustomCondition('MY_STAT',source);assert(copy,why and why.reason)
    copy.on_register();a.conditionDefinitions.ECS_STAT.on_register();assert(loads==1,'cloned registration did not share the initialized state')
    a.getCached=function(_,fn,...) return fn(...) end
    assert(copy.evaluate({stat='power',operator='GREATERTHAN',value=40},{})==true)
end)
test('glyph clone retains the expansion-scoped player class binding',function()
    local f,a=fixture(19,4,'SHAMAN');f.env.GetItemInfoInstant=function(item) return item,nil,nil,nil,nil,16,7 end
    local source=assert(a:GetBuiltinConditionSource('GLYPH'));local copy=assert(a:CompileCustomCondition('MY_GLYPH',source))
    assert(copy.valid(0,{item=123})==true and a.conditionDefinitions.GLYPH.valid(0,{item=123})==true)
end)
test('ROLE clones use the registered product variant rather than the last collected callback body',function()
    for _,case in ipairs({{1,12,true},{19,4,false},{18,12,false},{5,2,false}}) do
        local f,a=fixture(case[1],case[2]);local calls={inspect=0,talent=0}
        -- Isolate source-variant dispatch; role_conditions.lua checks real policy denial.
        a.Platform.GetClientInfo=function() return {combatDataPolicy='probe'} end
        f.env.UnitExists=function(unit) assert(unit=='target');return true end
        f.env.GetInspectSpecialization=function(unit) assert(unit=='target');calls.inspect=calls.inspect+1;return 123 end
        f.env.GetSpecializationInfoByID=function(id) assert(id==123);return id,'Fixture',nil,nil,'HEALER','SHAMAN' end
        f.env.GetTalentGroupRole=function(spec) assert(spec==a.currentSpec);calls.talent=calls.talent+1;return 'TANK' end
        local source=assert(a:GetBuiltinConditionSource('ROLE'));local copy=assert(a:CompileCustomCondition('COPY_ROLE',source))
        local value={unit='target',value='HEALER'};local original=a.conditionDefinitions.ROLE
        assert(copy.evaluate(value,{})==original.evaluate(value,{}),'exported ROLE body selected another client implementation')
        assert(copy.valid(0,value)==original.valid(0,value) and copy.print(0,value)==original.print(0,value))
        assert((source.fields.unit~=nil)==case[3],'source fields do not match the selected callback')
        if case[3] then assert(calls.inspect==2 and calls.talent==0 and copy.evaluate(value,{})==true)
        else assert(calls.talent==2 and calls.inspect==0 and copy.evaluate(value,{})==false) end
        local function widgets(definition)
            local parent=f.widget('Group');local top=f.widget('Frame');top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'summary' end});parent:SetUserData('top',top)
            definition.widget(parent,0,value);return #parent.children
        end
        assert(widgets(copy)==widgets(original) and widgets(copy)==(case[3] and 2 or 1))
    end
end)
test('unknown or absent Built In source variants fail closed without mutating saved source',function()
    local _,a=fixture(1,12);local definition=a.conditionDefinitions.ROLE
    definition.builtinSourceVariant='unknown';local source,why=a:GetBuiltinConditionSource('ROLE')
    assert(source==nil and why=='builtin-source-variant-unavailable')
    definition.builtinSourceVariant=nil;source,why=a:GetBuiltinConditionSource('ROLE')
    assert(source==nil and why=='builtin-source-variant-unavailable')
end)
local function collect(mode)
    local output
    local wrapped={new=function(...)
        local f=F.new(...);local load=f.load
        f.load=function(path)
            local result=load(path)
            if path=='Conditions/character.lua' and f.addon.definitions.ROLE then
                local role=f.addon.definitions.ROLE
                if mode=='unmarked' then role.builtinSourceVariant=nil
                elseif mode=='mixed' and f.env.WOW_PROJECT_ID==1 then role.builtinSourceVariant=nil
                elseif mode=='same-key' then role.builtinSourceVariant='same'
                elseif mode=='invalid-key' then role.builtinSourceVariant=true
                elseif mode=='missing-callback' and f.env.UnitClass()=='DEATHKNIGHT' then role.help=nil end
            end
            return result
        end
        return f
    end}
    local env=setmetatable({dofile=function(path)
        if path=='tests/fixtures/addon.lua' then return wrapped end
        local value=dofile(path)
        if mode=='reverse' and path=='tests/fixtures/catalog_inventory.lua' then
            local reversed={};for i=#value.branches,1,-1 do reversed[#reversed+1]=value.branches[i] end;value.branches=reversed
        end
        return value
    end,print=function(value) output=value end},{__index=_G})
    local tool=assert(loadfile('tools/collect_builtin_sources.lua'));setfenv(tool,env)
    local ok,why=pcall(tool);return ok,why,output
end
test('collector rejects unmarked mixed invalid and same-key divergent source variants including missing callbacks',function()
    for _,entry in ipairs({{'unmarked','ambiguous builtin callback source'},{'mixed','mixed marked/unmarked'},{'same-key','ambiguous builtin callback source'},{'invalid-key','invalid builtin source variant'},{'missing-callback','ambiguous builtin callback source'}}) do
        local ok,why=collect(entry[1]);assert(not ok and tostring(why):find(entry[2],1,true),entry[1]..' variant ambiguity was accepted: '..tostring(why))
    end
end)
test('all observed source variants are preserved independently of registration inventory traversal order',function()
    local ok,why,forward=collect();assert(ok,why)
    local reversed,reason,backward=collect('reverse');assert(reversed,reason)
    assert(forward==backward,'catalog depends on which client variant was observed last')
end)
test('source display removes only common leading indentation and keeps authored source immutable',function()
    local _,a=fixture();assert(a.FormatLuaSourceDisplay,'display formatter missing')
    local authored='\n        if value then\n            return true\n        end\n    '
    assert(a:FormatLuaSourceDisplay(authored)=='if value then\n    return true\nend')
    assert(a:FormatLuaSourceDisplay('    one\n\t two')=='    one\n\t two','different indentation was silently rewritten')
end)
finish()
