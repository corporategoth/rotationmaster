local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local kinds={COMBAT='combat',ENEMY='enemy',PVP='pvp'}
local native={COMBAT='UnitAffectingCombat',ENEMY='UnitIsEnemy',PVP='UnitIsPVP'}
local original={
    COMBAT=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitAffectingCombat, value.unit)
    end,]],
    ENEMY=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitIsEnemy, "player", value.unit)
    end,]],
    PVP=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitIsPVP, value.unit)
    end,]],
}
local repaired={}
for tag,kind in pairs(kinds) do repaired[tag]='    evaluate = function(value, cache)\n        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "'..kind..'")\n    end,' end
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,combat=true,enemy=true,pvp=true,calls={}}
    local function call(key,...)
        s.calls[#s.calls+1]={key,...};if s.throw==key then error('native failure') end;return s[key]
    end
    e.UnitExists=function(...) return call('exists',...) end
    e.UnitAffectingCombat=function(...) return call('combat',...) end
    e.UnitIsEnemy=function(...) return call('enemy',...) end
    e.UnitIsPVP=function(...) return call('pvp',...) end
    local file=io.open('Platform/unit_flags.lua');if file then file:close();f.load('Platform/unit_flags.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Conditions/misc.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,unit) return {type=tag,unit=unit or 'target'} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must have valid fields')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','required flag became known or fixture missed native path')
    end
    local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unavailable unit flag selected branch') end).status=='unavailable')
end
local function clone(a)
    for tag in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetUnitFlagObservation',1,true),'unit flag source catalog is stale')
        a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)))
    end
end
local function stage(f,s,tag,key,mode)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    if mode=='missing' then f.env[key=='exists' and 'UnitExists' or native[tag]]=nil
    elseif mode=='throw' then s.throw=key elseif mode=='nil' then s[key]=nil elseif mode=='restricted' then s[key]=opaque else s[key]=mode end
end
test('each required existence and flag observation stays unavailable through NOT groups and both branch arms',function()
    for tag,kind in pairs(kinds) do for _,key in ipairs({'exists',kind}) do for _,mode in ipairs({'missing','nil','throw','restricted',0,1,'false'}) do
        local f,a,s=fixture();stage(f,s,tag,key,mode);unknown(a,node(tag))
    end end end
end)
test('known flag true false and unit absence retain positive negative and branch meanings',function()
    for tag,kind in pairs(kinds) do for _,case in ipairs({{true,true,'match','yes'},{true,false,'no-match','no'},{false,true,'no-match','no'}}) do
        local _,a,s=fixture();s.exists=case[1];s[kind]=case[2];local v=node(tag)
        assert(a:evaluateConditionResult(v).status==case[3] and a:evaluateConditionResult({type='NOT',value=v}).status==(case[3]=='match' and 'no-match' or 'match'))
        local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end);assert(selected==case[4])
        assert(#s.calls==(case[1] and 6 or 3))
    end end
end)
test('complete tuple cache isolates kind and unit preserves false and nil reasons and retries on fresh passes',function()
    local _,a,s=fixture();local cache={};local evaluate=a.conditionDefinitions.COMBAT.evaluate;s.combat=nil
    local value,why=evaluate(node('COMBAT'),cache);assert(value==nil and why=='unit-flag-unavailable' and #s.calls==2)
    s.combat=true;local again,reason=evaluate(node('COMBAT'),cache);assert(again==nil and reason==why and #s.calls==2)
    assert(evaluate(node('COMBAT'),{})==true and #s.calls==4)
    s.calls={};cache={};a.longtermCache={sentinel={value=42}};local originalCache=a.longtermCache
    s.combat=false;assert(evaluate(node('COMBAT'),cache)==false);s.combat=true;assert(evaluate(node('COMBAT'),cache)==false and #s.calls==2)
    assert(a.conditionDefinitions.ENEMY.evaluate(node('ENEMY'),cache)==true and #s.calls==4)
    assert(a.conditionDefinitions.PVP.evaluate(node('PVP'),cache)==true and #s.calls==6)
    assert(a.conditionDefinitions.PVP.evaluate(node('PVP','pet'),cache)==true and #s.calls==8)
    assert(a.longtermCache==originalCache and a.longtermCache.sentinel.value==42 and next(a.longtermCache,'sentinel')==nil)
end)
test('restricted and unknown policies stay unavailable and transient native failure recovers without quarantine',function()
    for _,project in ipairs({999}) do local _,a,s=fixture(project);for tag in pairs(kinds) do unknown(a,node(tag)) end;assert(#s.calls==0) end
    for tag,kind in pairs(kinds) do local _,a,s=fixture();s.throw=kind;unknown(a,node(tag));s.throw=nil;assert(a:evaluateConditionResult(node(tag)).status=='match') end
end)
test('fresh editable copies use exact shared normalized observations and preserve selected actor tuples',function()
    local _,a,s=fixture();clone(a)
    for tag,kind in pairs(kinds) do local cache={};s.calls={};local v=node(tag,'pet');local copied=node('COPY_'..tag,'pet')
        assert(a.conditionDefinitions[tag].evaluate(v,cache)==true and a.conditionDefinitions[copied.type].evaluate(copied,cache)==true and #s.calls==2)
        assert(s.calls[1][1]=='exists' and s.calls[1][2]=='pet' and s.calls[2][1]==kind)
        if tag=='ENEMY' then assert(s.calls[2][2]=='player' and s.calls[2][3]=='pet') else assert(s.calls[2][2]=='pet' and #s.calls[2]==2) end
        s[kind]=nil;unknown(a,copied);s[kind]=true;assert(a:evaluateConditionResult(copied).status=='match')
        s[kind]=false;assert(a:evaluateConditionResult(copied).status=='no-match');s[kind]=true
    end
end)
test('saved raw callbacks retain native source and legacy nil outcomes without silent rewrite',function()
    local _,a,s=fixture()
    for tag,kind in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=assert(original[tag]:match('function%(value, cache%)\n(.*)\n    end,'))
        local compiled=assert(a:CompileCustomCondition('SAVED_RAW_'..tag,source));a:RegisterCondition('SAVED_RAW_'..tag,compiled)
        s[kind]=nil;local value,why=compiled.evaluate(node(tag),{});assert(value==nil and why==nil)
        assert(a:evaluateConditionResult({type='NOT',value=node('SAVED_RAW_'..tag)}).status=='match')
        s[kind]=true;s.exists=nil;assert(compiled.evaluate(node(tag),{})==false);s.exists=true
    end
end)
test('public observer source clone resolves actual owner and preserves kinds live readability and false tuples',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_flags.lua:Platform_GetUnitFlagObservation';local source=a:CopySettingsData(assert(a.builtinFunctions[id],'public flag helper catalog missing').source)
    assert(#source.description>0 and source.args[1].type=='RMPlatform' and source.args[2].name=='unit' and source.args[3].name=='kind')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetUnitFlagObservation and a.builtinSourceModules['Platform/unit_flags.lua']('Platform_GetUnitFlagObservation')==a.Platform.GetUnitFlagObservation)
    assert(a:InstallCustomFunction('COPY_UNIT_FLAG_OBSERVER',source));local fn=a:ResolveFunctionBinding('COPY_UNIT_FLAG_OBSERVER')
    for _,kind in pairs(kinds) do assert(fn(a.Platform,'target',kind)==true);s[kind]=false;assert(fn(a.Platform,'target',kind)==false);s[kind]=true end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.pvp=opaque;local value,why=fn(a.Platform,'target','pvp');assert(value==nil and why=='restricted-value')
end)
finish()
