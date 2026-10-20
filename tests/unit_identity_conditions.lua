local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local original=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitIsUnit, value.unit, value.otherunit)
    end,]]
local repaired=[[    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitIdentityObservation, addon.Platform, value.unit, value.otherunit)
    end,]]
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,same=true,calls={}}
    local function call(key,...)
        s.calls[#s.calls+1]={key,...};if s.throw==key then error('native identity failure') end;return s[key]
    end
    e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end
    e.UnitIsUnit=function(...) assert(select('#',...)==2);return call('same',...) end
    local file=io.open('Platform/unit_identity.lua');if file then file:close();f.load('Platform/unit_identity.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/character.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,unit,otherunit) return {type=tag or 'ISSAME',unit=unit or 'target',otherunit=otherunit or 'player'} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass unchanged field validation')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown identity became actionable or fixture invalid')
    end
    local body={rotation={{id='identity',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown identity selected branch') end).status=='unavailable')
end
local function clone(a)
    local source=assert(a:GetBuiltinConditionSource('ISSAME'));assert(source.evaluate:find('addon.Platform.GetUnitIdentityObservation',1,true),'identity source catalog stale')
    a:RegisterCondition('COPY_ISSAME',assert(a:CompileCustomCondition('COPY_ISSAME',source)))
end
test('required identity observations stay unavailable under NOT groups and both branch arms',function()
    for key,api in pairs({exists='UnitExists',same='UnitIsUnit'}) do for _,mode in ipairs({'missing','nil','throw','restricted',0,1,'false'}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then f.env[api]=nil elseif mode=='nil' then s[key]=nil elseif mode=='throw' then s.throw=key elseif mode=='restricted' then s[key]=opaque else s[key]=mode end
        unknown(a,node())
    end end
end)
test('known true false and first-unit absence preserve NOT and branch controls',function()
    for _,case in ipairs({{true,true,'match','yes'},{true,false,'no-match','no'},{false,true,'no-match','no'}}) do
        local _,a,s=fixture();s.exists=case[1];s.same=case[2];local v=node();assert(a:evaluateConditionResult(v).status==case[3])
        assert(a:evaluateConditionResult({type='NOT',value=v}).status==(case[3]=='match' and 'no-match' or 'match'))
        local selected;local body={rotation={{id='identity',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end)
        assert(selected==case[4] and #s.calls==(case[1] and 6 or 3))
    end
end)
test('per-pass ordered token pair cache preserves false nil reasons and fresh or uncached recovery',function()
    local _,a,s=fixture();local evaluate=a.conditionDefinitions.ISSAME.evaluate;local cache={};s.same=nil
    local value,reason=evaluate(node(),cache);assert(value==nil and reason=='unit-identity-unavailable' and #s.calls==2)
    s.same=true;local again,why=evaluate(node(),cache);assert(again==nil and why==reason and #s.calls==2)
    assert(evaluate(node(),{})==true and #s.calls==4)
    s.calls={};cache={};s.same=false;assert(evaluate(node(),cache)==false);s.same=true;assert(evaluate(node(),cache)==false and #s.calls==2)
    assert(evaluate(node(nil,'player','target'),cache)==true and #s.calls==4)
    assert(evaluate(node(nil,'target','pet'),cache)==true and #s.calls==6)
    assert(evaluate(node())==true and evaluate(node())==true and #s.calls==10)
    assert(next(a.longtermCache)==nil,'identity must not create a longterm cache')
end)
test('unsupported policy and transient native errors remain unavailable with next-pass recovery',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a,node());assert(#s.calls==0) end
    local _,a,s=fixture();s.throw='same';unknown(a,node());s.throw=nil;assert(a:evaluateConditionResult(node()).status=='match')
end)
test('current editable copy shares canonical observer and exact native token order',function()
    local _,a,s=fixture();clone(a);local cache={}
    assert(a.conditionDefinitions.ISSAME.evaluate(node(),cache)==true and a.conditionDefinitions.COPY_ISSAME.evaluate(node('COPY_ISSAME'),cache)==true and #s.calls==2)
    assert(s.calls[1][1]=='exists' and s.calls[1][2]=='target' and s.calls[2][1]=='same' and s.calls[2][2]=='target' and s.calls[2][3]=='player')
    s.same=nil;unknown(a,node('COPY_ISSAME'));s.same=false;assert(a:evaluateConditionResult(node('COPY_ISSAME')).status=='no-match')
    s.same=true;assert(a:evaluateConditionResult(node('COPY_ISSAME')).status=='match')
end)
test('old saved raw callback bytes retain their prior nil behavior without rewriting source',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('ISSAME'));source.evaluate=assert(original:match('function%(value, cache%)\n(.*)\n    end,'))
    local before=a:CopySettingsData(source);local definition=assert(a:CompileCustomCondition('SAVED_RAW_ISSAME',source));a:RegisterCondition('SAVED_RAW_ISSAME',definition)
    s.same=nil;local value,why=definition.evaluate(node(),{});assert(value==nil and why==nil)
    assert(a:evaluateConditionResult({type='NOT',value=node('SAVED_RAW_ISSAME')}).status=='match')
    s.exists=nil;assert(definition.evaluate(node(),{})==false and a:SettingsDataEqual(before,source))
end)
test('public observer editable clone resolves its actual owner and current readability guards',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_identity.lua:Platform_GetUnitIdentityObservation';local record=assert(a.builtinFunctions[id],'public identity observer catalog missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetUnitIdentityObservation and a.builtinSourceModules['Platform/unit_identity.lua']('Platform_GetUnitIdentityObservation')==a.Platform.GetUnitIdentityObservation)
    assert(record.source.args[1].type=='RMPlatform' and record.source.args[2].name=='unit' and record.source.args[3].name=='otherunit' and #record.source.description>0)
    assert(a:InstallCustomFunction('COPY_UNIT_IDENTITY',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_UNIT_IDENTITY')
    assert(fn(a.Platform,'pet','target')==true and s.calls[1][2]=='pet' and s.calls[2][2]=='pet' and s.calls[2][3]=='target')
    s.same=false;assert(fn(a.Platform,'target','pet')==false)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.same=opaque
    local value,why=fn(a.Platform,'target','pet');assert(value==nil and why=='restricted-value')
end)
test('only one exact evaluator changes with full module bytes and four private identities intact',function()
    local _,a=fixture();local file=assert(io.open('Conditions/character.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_glyph_presentation_repairs.lua')(text);text=dofile('tests/fixtures/restore_mobinfo2_repairs.lua')(text);text=dofile('tests/fixtures/restore_role_repairs.lua')(text);text=dofile('tests/fixtures/restore_class_group_repairs.lua')(text)
    text=dofile('tests/fixtures/restore_unit_metadata_repairs.lua')(text)
    local first=assert(text:find(repaired,1,true),'exact repaired identity callback missing');assert(not text:find(repaired,first+1,true),'multiple identity replacements')
    text=text:sub(1,first-1)..original..text:sub(first+#repaired)
    assert(a:FunctionSourceHash(text)=='7c75697a','character changed beyond the approved ISSAME evaluator from a8711a9')
    for name,hash in pairs({character_class='f9f4e4b5',color='3f9fe631',helpers='2e9a81e7',unit_class_num='33645816'}) do
        local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/character.lua'](name),'private source identity changed')
    end
end)
finish()
