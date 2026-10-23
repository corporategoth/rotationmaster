local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={exists=true,current=50,maximum=100,calls={}}
    local function call(key) s.calls[key]=(s.calls[key] or 0)+1;if s.throw==key then error('native failure') end end
    e.UnitExists=function(unit) assert(unit=='target');call('exists');return s.exists end
    e.UnitHealth=function(unit) assert(unit=='target');call('current');return s.current end
    e.UnitHealthMax=function(unit) assert(unit=='target');call('maximum');return s.maximum end
    local file=io.open('Platform/unit_health.lua');if file then file:close();f.load('Platform/unit_health.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag) return {type=tag,unit='target',operator='EQUALS',value=tag=='HEALTHPCT' and .5 or 50} end
local function unknown(a,v)
    assert(a:evaluateConditionResult(v).status=='unavailable',v.type..' became known')
    assert(a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable',v.type..' unavailable became NOT match')
    local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown health selected action') end).status=='unavailable')
end
local function clones(a)
    for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag))))) end
end

test('missing nil failed malformed and restricted health observations stay unavailable through NOT and branches',function()
    for _,mode in ipairs({'missing-exists','nil-exists','throw-exists','invalid-exists','restricted-exists','missing-current','nil-current','throw-current','restricted-current','nan-current','infinite-current','negative-current','string-current'}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing-exists' then f.env.UnitExists=nil elseif mode=='nil-exists' then s.exists=nil elseif mode=='throw-exists' then s.throw='exists' elseif mode=='invalid-exists' then s.exists=1 elseif mode=='restricted-exists' then s.exists=opaque
        elseif mode=='missing-current' then f.env.UnitHealth=nil elseif mode=='nil-current' then s.current=nil elseif mode=='throw-current' then s.throw='current' elseif mode=='restricted-current' then s.current=opaque elseif mode=='nan-current' then s.current=0/0 elseif mode=='infinite-current' then s.current=math.huge elseif mode=='negative-current' then s.current=-1 else s.current='50' end
        for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do unknown(a,node(tag)) end
    end
end)
test('maximum failures affect deficit and percentage but leave raw health usable',function()
    for _,mode in ipairs({'missing','nil','throw','restricted','nan','infinite','negative','string'}) do local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then f.env.UnitHealthMax=nil elseif mode=='nil' then s.maximum=nil elseif mode=='throw' then s.throw='maximum' elseif mode=='restricted' then s.maximum=opaque elseif mode=='nan' then s.maximum=0/0 elseif mode=='infinite' then s.maximum=math.huge elseif mode=='negative' then s.maximum=-1 else s.maximum='100' end
        assert(a:evaluateConditionResult(node('HEALTH')).status=='match' and not s.calls.maximum)
        local deficit=node('HEALTH');deficit.value=-50;unknown(a,deficit);unknown(a,node('HEALTHPCT'))
    end
    local _,a,s=fixture();s.maximum=0;s.current=0;unknown(a,node('HEALTHPCT'));local v=node('HEALTH');v.value=0;assert(a:evaluateConditionResult(v).status=='match')
end)
test('finite native inputs whose percentage overflows stay unavailable through NOT and branches',function()
    local _,a,s=fixture();s.current=1e308;s.maximum=1e-308
    local record=assert(a.Platform:GetUnitHealthObservation('target',true));assert(record.current==s.current and record.maximum==s.maximum)
    unknown(a,node('HEALTHPCT'));clones(a);local copied=node('HEALTHPCT');copied.type='COPY_HEALTHPCT';unknown(a,copied)
end)
test('readable absent units and zero health retain ordinary false and comparison semantics',function()
    local _,a,s=fixture();s.exists=false
    for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do assert(a:evaluateConditionResult(node(tag)).status=='no-match' and a:evaluateConditionResult({type='NOT',value=node(tag)}).status=='match') end
    assert(not s.calls.current and not s.calls.maximum)
    s.exists=true;s.current=0;local v=node('HEALTH');v.value=0;assert(a:evaluateConditionResult(v).status=='match');v=node('HEALTHPCT');v.value=0;assert(a:evaluateConditionResult(v).status=='match')
    s.current=50;for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do assert(a:evaluateConditionResult(node(tag)).status=='match') end
    v=node('HEALTH');v.value=-50;assert(a:evaluateConditionResult(v).status=='match')
end)
test('restricted and unknown client policies cannot query health or authorize NOT',function()
    for _,project in ipairs({999}) do local _,a,s=fixture(project);for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do unknown(a,node(tag)) end;assert(next(s.calls)==nil) end
end)
test('per-evaluation adapter caches preserve nil reasons and recover on the next observation',function()
    local _,a,s=fixture();local v=node('HEALTH');local cache={};s.current=nil
    local first,reason=a.conditionDefinitions.HEALTH.evaluate(v,cache);assert(first==nil and reason=='health-data-unavailable');s.current=50
    local second,again=a.conditionDefinitions.HEALTH.evaluate(v,cache);assert(second==nil and again==reason and s.calls.current==1)
    assert(a.conditionDefinitions.HEALTH.evaluate(v,{})==true and s.calls.current==2)
    cache={};local p=node('HEALTHPCT');v.value=-50;assert(a.conditionDefinitions.HEALTH.evaluate(v,cache)==true);local calls=s.calls.current;assert(a.conditionDefinitions.HEALTHPCT.evaluate(p,cache)==true and s.calls.current==calls)
end)
test('new Built In editable clones preserve repaired contract and saved raw callbacks remain executable',function()
    local _,a,s=fixture();clones(a)
    for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetUnitHealthObservation',1,true),'catalog is stale');local v=node(tag);assert(a.conditionDefinitions['COPY_'..tag].evaluate(v,{})==true) end
    s.exists=nil;for _,tag in ipairs({'HEALTH','HEALTHPCT'}) do local v=node(tag);v.type='COPY_'..tag;unknown(a,v) end
    local source=assert(a:GetBuiltinConditionSource('HEALTH'));source.evaluate='if not addon.getCached(cache,UnitExists,value.unit) then return false end;return addon.compare(value.operator,addon.getCached(cache,UnitHealth,value.unit),value.value)'
    local saved=assert(a:CompileCustomCondition('SAVED_RAW_HEALTH',source));assert(saved.evaluate(node('HEALTH'),{})==false,'stored raw callback was rewritten')
end)
test('public adapter source clones resolve actual finite helper and live readability policy',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_health.lua:Platform_GetUnitHealthObservation';local source=a:CopySettingsData(assert(a.builtinFunctions[id],'health public helper catalog missing').source)
    assert(#source.description>0 and source.args[1].type=='RMPlatform' and source.args[2].name=='unit' and source.args[3].name=='includeMaximum')
    assert(a:InstallCustomFunction('HEALTH_OBSERVER_COPY',source));local fn=a:ResolveFunctionBinding('HEALTH_OBSERVER_COPY');local r=assert(fn(a.Platform,'target',true));assert(r.exists and r.current==50 and r.maximum==100)
    assert(source.bindings.finite=='builtin:Platform/unit_health.lua:finite' and a:ResolveFunctionBinding(source.bindings.finite)==a.builtinSourceModules['Platform/unit_health.lua']('finite'))
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.current=opaque;local value,reason=fn(a.Platform,'target',false);assert(value==nil and reason=='restricted-value')
end)
finish()
