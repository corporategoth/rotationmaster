local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_zone_pvp_repairs.lua')
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={result='hostile',calls=0,legacy=0}
    e.C_PvP={GetZonePVPInfo=function(...) assert(select('#',...)==0);s.calls=s.calls+1;if s.throw then error('modern zone failure') end;return s.result,s.tail end}
    e.GetZonePVPInfo=function(...) assert(select('#',...)==0);s.legacy=s.legacy+1;return s.result end
    local file=io.open('Platform/zone_pvp.lua');if file then file:close();f.load('Platform/zone_pvp.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/misc.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(selected,tag) return {type=tag or 'ZONEPVP',value=selected} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'probe fields invalid')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown zone became '..result.status) end
    local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown zone selected branch') end).status=='unavailable')
end
test('required surface and observation failures remain unknown even for the valid no PvP selection',function()
    for _,mode in ipairs({'missing','throw','restricted','namespace','method',false,0,{}}) do local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then f.env.C_PvP=nil;f.env.GetZonePVPInfo=nil elseif mode=='throw' then s.throw=true elseif mode=='restricted' then s.result=opaque elseif mode=='namespace' then f.env.C_PvP=opaque elseif mode=='method' then f.env.C_PvP.GetZonePVPInfo=opaque else s.result=mode end
        unknown(a,node(nil));unknown(a,node('hostile'));assert(s.legacy==0,'unknown modern observation used fallback')
    end
end)
test('successful nil is known no PvP while empty and future strings retain exact inequality',function()
    local f,a,s=fixture();s.result=nil;assert(a:evaluateConditionResult(node(nil)).status=='match' and a:evaluateConditionResult(node('hostile')).status=='no-match')
    assert(a:evaluateConditionResult({type='NOT',value=node(nil)}).status=='no-match')
    f.env.C_PvP.GetZonePVPInfo=function(...) assert(select('#',...)==0);return end;assert(a:evaluateConditionResult(node(nil)).status=='match')
    f.env.C_PvP.GetZonePVPInfo=function() return s.result end
    for _,kind in ipairs({'arena','friendly','contested','hostile','sanctuary','combat','','future'}) do s.result=kind;assert(a:evaluateConditionResult(node(nil)).status=='no-match')
        for selected in pairs(a.zonepvp) do assert(a:evaluateConditionResult(node(selected)).status==(selected==kind and 'match' or 'no-match')) end
    end
end)
test('one pass shares empty and unknown snapshots across selectors while self and next pass isolate',function()
    local _,a,s=fixture();local evaluate=a.conditionDefinitions.ZONEPVP.evaluate;local cache={};s.result=nil
    assert(evaluate(node(nil),cache)==true and evaluate(node('hostile'),cache)==false and s.calls==1 and s.legacy==0)
    s.result='hostile';assert(evaluate(node(nil),cache)==true and s.calls==1);assert(evaluate(node('hostile'),{})==true and s.calls==2)
    local other=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,a.Platform.GetZonePVPObservation,other).pvpType=='hostile' and s.calls==3)
    cache={};s.throw=true;local value,why=evaluate(node(nil),cache);assert(value==nil and why=='api-error' and s.calls==4);s.throw=nil
    value,why=evaluate(node('hostile'),cache);assert(value==nil and why=='api-error' and s.calls==4)
    assert(evaluate(node('hostile'))==true and evaluate(node('hostile'))==true and s.calls==6 and next(a.longtermCache)==nil)
end)
test('modern and global capability selection recovers on fresh evaluations without quarantine',function()
    local f,a,s=fixture();s.throw=true;unknown(a,node(nil));s.throw=nil;assert(a:evaluateConditionResult(node('hostile')).status=='match')
    f.env.C_PvP.GetZonePVPInfo=nil;assert(a:evaluateConditionResult(node('hostile')).status=='match' and s.legacy==1)
    for _,project in ipairs({1,18,2,5,11,14,19}) do local _,b=fixture(project);assert(b:evaluateConditionResult(node('hostile')).status=='match') end
    local _,b,state=fixture(999);unknown(b,node(nil));assert(state.calls==0 and state.legacy==0)
end)
test('current exported callback and helper source clones preserve successful empty records and ownership',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('ZONEPVP'));assert(source.evaluate==repaired,'ZONEPVP catalog stale')
    local copy=assert(a:CompileCustomCondition('COPY_ZONE',source));a:RegisterCondition('COPY_ZONE',copy);local cache={};s.result=nil
    assert(a.conditionDefinitions.ZONEPVP.evaluate(node(nil),cache)==true and copy.evaluate(node(nil),cache)==true and s.calls==1 and s.legacy==0)
    s.throw=true;unknown(a,node(nil,'COPY_ZONE'));s.throw=nil;assert(a:evaluateConditionResult(node(nil,'COPY_ZONE')).status=='match')
    local id='builtin:Platform/zone_pvp.lua:Platform_GetZonePVPObservation';local record=assert(a.builtinFunctions[id],'zone public observer missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetZonePVPObservation and a.builtinSourceModules['Platform/zone_pvp.lua']('Platform_GetZonePVPObservation')==a.Platform.GetZonePVPObservation)
    assert(#record.source.args==1 and record.source.args[1].type=='RMPlatform' and next(record.source.bindings)==nil)
    assert(a:InstallCustomFunction('COPY_ZONE_HELPER',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_ZONE_HELPER');assert(next(fn(a.Platform))==nil)
    s.result='future';assert(fn(a.Platform).pvpType=='future')
end)
test('raw old saved source remains exact and keeps its global native lookup and nil behavior',function()
    local f,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('ZONEPVP'));source.evaluate=old;local before=a:CopySettingsData(source)
    local raw=assert(a:CompileCustomCondition('RAW_ZONE',source));a:RegisterCondition('RAW_ZONE',raw)
    f.env.GetZonePVPInfo=nil;assert(raw.evaluate(node(nil),{})==true and raw.evaluate(node('hostile'),{})==false and s.calls==0)
    f.env.GetZonePVPInfo=function() return nil,'ignored' end;assert(raw.evaluate(node(nil),{})==true)
    assert(a:SettingsDataEqual(before,source),'raw saved source rewritten')
end)
test('only exact zone evaluator differs from complete baseline and private identities stay exact',function()
    local _,a=fixture();local file=assert(io.open('Conditions/misc.lua'));local text=file:read('*a');file:close()
    assert(a:FunctionSourceHash(inverse(dofile('tests/fixtures/restore_environment_selector_repairs.lua')(text)))=='002c653f','misc changed beyond ZONEPVP fromf537fe1')
    for name,hash in pairs({color='89a5436e',helpers='3ab28a24'}) do local id='builtin:Conditions/misc.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/misc.lua'](name)) end
    local instance=a:GetBuiltinConditionSource('INSTANCE');instance.widget=dofile('tests/fixtures/restore_environment_selector_repairs.lua')(instance.widget,'INSTANCE')
    assert(a:FunctionSourceHash(instance)=='7245e52a','instance source changed beyond its separate approved selector repair')
end)
finish()
