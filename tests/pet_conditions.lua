local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local original={
    PET=[[    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, UnitExists, "pet")
    end,]],
    PET_NAME=[[    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, GetUnitName, "pet") == value.value
    end,]],
}
local repaired={
    PET=[[    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, false)
        if not record then return nil,reason end
        return record.exists
    end,]],
    PET_NAME=[[    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, true)
        if not record then return nil,reason end
        if not record.exists then return false end
        return record.name == value.value
    end,]],
}
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,name='Wolf',calls={}}
    local function call(key,...)
        assert(select('#',...)==1 and select(1,...)=='pet','pet query changed token or arity')
        s.calls[#s.calls+1]=key;if s.throw==key then error('native pet failure') end;return s[key]
    end
    e.UnitExists=function(...) return call('exists',...) end;e.GetUnitName=function(...) return call('name',...) end
    e.UnitName=function() error('pet name must retain GetUnitName') end
    local file=io.open('Platform/pet.lua');if file then file:close();f.load('Platform/pet.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,value) return {type=tag or 'PET',value=value or 'Wolf'} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass real field validation')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown pet fact became actionable')
    end
    local body={rotation={{id='pet',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown pet selected branch') end).status=='unavailable')
end
local function clones(a)
    for _,tag in ipairs({'PET','PET_NAME'}) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetPetObservation',1,true),'pet source catalog stale')
        a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)))
    end
end
test('required existence and requested names stay unknown under NOT groups and both branch arms',function()
    for _,tag in ipairs({'PET','PET_NAME'}) do for _,key in ipairs(tag=='PET' and {'exists'} or {'exists','name'}) do
        for _,mode in ipairs({'missing','nil','throw','restricted','empty',0,1,{}}) do
            local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
            if mode=='missing' then f.env[key=='exists' and 'UnitExists' or 'GetUnitName']=nil
            elseif mode=='nil' then s[key]=nil elseif mode=='throw' then s.throw=key elseif mode=='restricted' then s[key]=opaque elseif mode=='empty' then s[key]='' else s[key]=mode end
            unknown(a,node(tag))
        end
    end end
end)
test('known presence absence and name differences preserve positive NOT and branch controls',function()
    for _,case in ipairs({{'PET',true,'Wolf','match','yes'},{'PET',false,'Wolf','no-match','no'},{'PET_NAME',true,'Wolf','match','yes'},{'PET_NAME',true,'Bear','no-match','no'},{'PET_NAME',false,'Wolf','no-match','no'}}) do
        local _,a,s=fixture();s.exists=case[2];s.name=case[3];local v=node(case[1])
        assert(a:evaluateConditionResult(v).status==case[4] and a:evaluateConditionResult({type='NOT',value=v}).status==(case[4]=='match' and 'no-match' or 'match'))
        local selected;local body={rotation={{id='pet',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end)
        assert(selected==case[5] and #s.calls==((case[1]=='PET' or not case[2]) and 3 or 6))
    end
end)
test('only name mode requires metadata and configured names retain exact spelling formatting and schema',function()
    local f,a,s=fixture();f.env.GetUnitName=nil;assert(a:evaluateConditionResult(node('PET')).status=='match');unknown(a,node('PET_NAME'))
    s.exists=false;assert(a:evaluateConditionResult(node('PET_NAME')).status=='no-match')
    f,a,s=fixture();s.name='Wolf (*)';assert(a:evaluateConditionResult(node('PET_NAME','Wolf (*)')).status=='match' and a:evaluateConditionResult(node('PET_NAME','Wolf')).status=='no-match')
    assert(a:evaluateConditionResult(node('PET_NAME','wolf (*)')).status=='no-match' and a:evaluateConditionResult(node('PET_NAME','Wolf (*) ')).status=='no-match')
    local empty=node('PET_NAME','');assert(a.conditionDefinitions.PET_NAME.valid(0,empty) and a:evaluateConditionResult(empty).status=='no-match')
    s.name='';unknown(a,empty)
end)
test('complete cached record and nil reason snapshots separate mode self and pass without longterm writes',function()
    local _,a,s=fixture();local cache={};local named=a.conditionDefinitions.PET_NAME.evaluate;s.name=nil
    local value,why=named(node('PET_NAME'),cache);assert(value==nil and why=='pet-name-unavailable' and #s.calls==2)
    s.name='Wolf';local again,reason=named(node('PET_NAME'),cache);assert(again==nil and reason==why and #s.calls==2)
    assert(named(node('PET_NAME'),{})==true and #s.calls==4)
    s.calls={};cache={};s.exists=false;local exists=a.conditionDefinitions.PET.evaluate
    assert(exists(node(),cache)==false);s.exists=true;assert(exists(node(),cache)==false and #s.calls==1)
    assert(named(node('PET_NAME'),cache)==true and #s.calls==3)
    local other=setmetatable({},{__index=a.Platform})
    assert(a.Functions.cache.getCached(cache,a.Platform.GetPetObservation,other,false).exists==true and #s.calls==4)
    assert(exists(node())==true and exists(node())==true and #s.calls==6 and next(a.longtermCache)==nil)
end)
test('unsupported policies and transient native failures cannot choose actions and recover next pass',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a,node());unknown(a,node('PET_NAME'));assert(#s.calls==0) end
    for _,key in ipairs({'exists','name'}) do local _,a,s=fixture();s.throw=key;unknown(a,node('PET_NAME'));s.throw=nil;assert(a:evaluateConditionResult(node('PET_NAME')).status=='match') end
end)
test('fresh editable copies use shared normalized observations with mode-specific unknowns',function()
    local _,a,s=fixture();clones(a);local cache={}
    assert(a.conditionDefinitions.PET.evaluate(node(),cache)==true and a.conditionDefinitions.COPY_PET.evaluate(node('COPY_PET'),cache)==true and #s.calls==1)
    assert(a.conditionDefinitions.PET_NAME.evaluate(node('PET_NAME'),cache)==true and a.conditionDefinitions.COPY_PET_NAME.evaluate(node('COPY_PET_NAME'),cache)==true and #s.calls==3)
    s.name=nil;unknown(a,node('COPY_PET_NAME'));assert(a:evaluateConditionResult(node('COPY_PET')).status=='match')
    s.exists=false;assert(a:evaluateConditionResult(node('COPY_PET_NAME')).status=='no-match');s.exists=true;s.name='Wolf';assert(a:evaluateConditionResult(node('COPY_PET_NAME')).status=='match')
end)
test('old saved raw callbacks retain legacy nil and unguarded-name behavior without source rewriting',function()
    local _,a,s=fixture()
    for _,tag in ipairs({'PET','PET_NAME'}) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=assert(original[tag]:match('function%([^\n]*%)\n(.*)\n    end,'));local before=a:CopySettingsData(source)
        local definition=assert(a:CompileCustomCondition('SAVED_RAW_'..tag,source));a:RegisterCondition('SAVED_RAW_'..tag,definition)
        if tag=='PET' then s.exists=nil;local value,why=definition.evaluate(node(),{});assert(value==nil and why==nil)
        else s.exists=false;s.name='Wolf';assert(definition.evaluate(node(tag),{})==true);s.name=nil;assert(definition.evaluate(node(tag),{})==false) end
        assert(a:evaluateConditionResult({type='NOT',value=node('SAVED_RAW_'..tag)}).status=='match' and a:SettingsDataEqual(before,source))
    end
end)
test('public editable observer clone resolves actual owner and optional mode with live readability policy',function()
    local f,a,s=fixture();local id='builtin:Platform/pet.lua:Platform_GetPetObservation';local record=assert(a.builtinFunctions[id],'pet helper source catalog missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetPetObservation and a.builtinSourceModules['Platform/pet.lua']('Platform_GetPetObservation')==a.Platform.GetPetObservation)
    assert(record.source.args[1].type=='RMPlatform' and record.source.args[2].name=='includeName' and #record.source.description>0)
    assert(a:InstallCustomFunction('COPY_PET_OBSERVER',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_PET_OBSERVER')
    assert(fn(a.Platform).exists and fn(a.Platform,true).name=='Wolf');s.exists=false;assert(fn(a.Platform,true).exists==false)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.exists=true;s.name=opaque
    local value,why=fn(a.Platform,true);assert(value==nil and why=='restricted-value' and fn(a.Platform,false).exists==true)
end)
test('only two exact pet evaluators change with full module inverse and three private identities',function()
    local _,a=fixture();local file=assert(io.open('Conditions/combat.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_threat_count_repairs.lua')(text);text=dofile('tests/fixtures/restore_combat_time_repairs.lua')(text);text=dofile('tests/fixtures/restore_form_repairs.lua')(text);text=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')(text);text=dofile('tests/fixtures/restore_threat_repairs.lua')(text)
    for _,tag in ipairs({'PET','PET_NAME'}) do local first=assert(text:find(repaired[tag],1,true),'exact repaired '..tag..' missing');assert(not text:find(repaired[tag],first+1,true),'multiple repaired '..tag..' bodies')
        text=text:sub(1,first-1)..original[tag]..text:sub(first+#repaired[tag])
    end
    assert(a:FunctionSourceHash(text)=='f0ca653e','combat changed beyond two pet evaluators from4487926')
    for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do
        local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name))
    end
end)
finish()
