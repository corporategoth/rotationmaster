local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'MANA','MANAPCT','POWER','POWERPCT'}
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={exists=true,powerType=3,current={[0]=20,[1]=10,[3]=20,[26]=-25},maximum={[0]=100,[1]=100,[3]=100,[26]=100},calls={},trace={}}
    e.Enum.PowerType.Mana=0;e.Enum.PowerType.Rage=1;e.Enum.PowerType.Energy=3;e.Enum.PowerType.Balance=26
    local function call(key,...) s.calls[key]=(s.calls[key] or 0)+1;s.trace[#s.trace+1]={key=key,n=select('#',...),...};if s.throw==key then error('native failure') end end
    e.UnitExists=function(unit) call('exists',unit);return s.exists end
    e.UnitPowerType=function(...) assert(select('#',...)==1);call('type',...);return s.powerType,'UNUSED' end
    e.UnitPower=function(...) assert(select('#',...)==2);local unit,id=...;call('current',unit,id);return s.current[id==nil and s.powerType or id] end
    e.UnitPowerMax=function(...) assert(select('#',...)==2);local unit,id=...;call('maximum',unit,id);return s.maximum[id==nil and s.powerType or id] end
    local file=io.open('Platform/unit_power.lua');if file then file:close();f.load('Platform/unit_power.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag) return {type=tag,unit='target',operator='EQUALS',value=tag:find('PCT',1,true) and .2 or 20} end
local function unknown(a,value)
    assert(a:evaluateConditionResult(value).status=='unavailable',value.type..' became known')
    assert(a:evaluateConditionResult({type='NOT',value=value}).status=='unavailable',value.type..' unknown became NOT match')
    for _,kind in ipairs({'AND','OR'}) do assert(a:evaluateConditionResult({type=kind,value={value}}).status=='unavailable') end
    local body={rotation={{id='guard',type='branch',conditions=value,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unavailable power selected action') end).status=='unavailable')
end
local function clones(a)
    for _,tag in ipairs(tags) do a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag))))) end
end

test('both percent conditions compare the computed percentage to the stored fractional threshold',function()
    local _,a=fixture()
    for _,tag in ipairs({'MANAPCT','POWERPCT'}) do for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE'}) do for _,amount in ipairs({0,.01,.2,.5,1}) do
        local v=node(tag);v.operator=operator;v.value=amount;assert(a.conditionDefinitions[tag].evaluate(v,{})==a.compare(operator,20,amount*100),tag..' percent/fraction scale mismatch')
    end end end
end)
test('known absent actors remain invertible while missing failed restricted and malformed facts stay unavailable',function()
    local _,a,s=fixture();s.exists=false
    for _,tag in ipairs(tags) do assert(a:evaluateConditionResult(node(tag)).status=='no-match' and a:evaluateConditionResult({type='NOT',value=node(tag)}).status=='match') end
    assert(not s.calls.type and not s.calls.current and not s.calls.maximum)
    for _,mode in ipairs({'nil-exists','missing-exists','throw-exists','restricted-exists','invalid-exists','nil-current','missing-current','throw-current','restricted-current','nan-current','infinite-current','string-current'}) do for _,tag in ipairs(tags) do
        local f,b,state=fixture();local id=tag:find('MANA',1,true) and 0 or 3;local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='nil-exists' then state.exists=nil elseif mode=='missing-exists' then f.env.UnitExists=nil elseif mode=='throw-exists' then state.throw='exists' elseif mode=='restricted-exists' then state.exists=secret elseif mode=='invalid-exists' then state.exists=1 elseif mode=='nil-current' then state.current[id]=nil elseif mode=='missing-current' then f.env.UnitPower=nil elseif mode=='throw-current' then state.throw='current' elseif mode=='restricted-current' then state.current[id]=secret elseif mode=='nan-current' then state.current[id]=0/0 elseif mode=='infinite-current' then state.current[id]=math.huge else state.current[id]='20' end
        unknown(b,node(tag))
    end end
end)
test('current type and enum failures never authorize NOT or accidentally query a different resource',function()
    for _,mode in ipairs({'nil','missing','throw','restricted','string','unknown','fraction'}) do local f,a,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='nil' then s.powerType=nil elseif mode=='missing' then f.env.UnitPowerType=nil elseif mode=='throw' then s.throw='type' elseif mode=='restricted' then s.powerType=secret elseif mode=='string' then s.powerType='ENERGY' elseif mode=='unknown' then s.powerType=100000 else s.powerType=1.5 end
        unknown(a,node('POWER'));unknown(a,node('POWERPCT'));assert(not s.calls.current)
        for _,tag in ipairs({'MANA','MANAPCT'}) do assert(a:evaluateConditionResult(node(tag)).status=='match',tag..' depended on a different current bar') end
    end
    local f,a,s=fixture();f.env.Enum.PowerType.Mana=nil;unknown(a,node('MANA'));unknown(a,node('MANAPCT'));assert(not s.calls.current,'missing Mana enum defaulted to current bar')
end)
test('maximum availability only blocks deficit and percentage queries and zero denominator stays unknown',function()
    for _,mode in ipairs({'missing','nil','throw','restricted','nan','infinite','negative','string'}) do local f,a,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='missing' then f.env.UnitPowerMax=nil elseif mode=='nil' then s.maximum[0]=nil;s.maximum[3]=nil elseif mode=='throw' then s.throw='maximum' else local bad=mode=='restricted' and secret or mode=='nan' and 0/0 or mode=='infinite' and math.huge or mode=='negative' and -1 or '100';s.maximum[0]=bad;s.maximum[3]=bad end
        for _,tag in ipairs({'MANA','POWER'}) do local before=s.calls.maximum or 0;assert(a:evaluateConditionResult(node(tag)).status=='match' and (s.calls.maximum or 0)==before);local v=node(tag);v.value=-80;unknown(a,v) end
        for _,tag in ipairs({'MANAPCT','POWERPCT'}) do unknown(a,node(tag)) end
    end
    local _,a,s=fixture();s.current[0]=0;s.maximum[0]=0;s.current[3]=0;s.maximum[3]=0
    for _,tag in ipairs({'MANA','POWER'}) do local v=node(tag);v.value=0;assert(a:evaluateConditionResult(v).status=='match') end
    for _,tag in ipairs({'MANAPCT','POWERPCT'}) do unknown(a,node(tag)) end
end)
test('fractional quantities retain their scale and negative explicit mana stays unavailable',function()
    local _,a,s=fixture();s.current[0]=.5;s.maximum[0]=2.5;s.current[3]=.5;s.maximum[3]=2.5
    for _,tag in ipairs(tags) do local v=node(tag);v.value=tag:find('PCT',1,true) and .2 or .5;assert(a:evaluateConditionResult(v).status=='match') end
    s.current[0]=-1;unknown(a,node('MANA'));unknown(a,node('MANAPCT'))
end)
test('signed Balance current retains existing raw deficit and below-zero percentage meanings',function()
    local _,a,s=fixture();s.powerType=26
    local v=node('POWER');v.value=0;v.operator='LESSTHAN';assert(a:evaluateConditionResult(v).status=='match','signed current was clamped or rejected')
    v=node('POWER');v.value=-125;assert(a:evaluateConditionResult(v).status=='match','signed deficit changed meaning')
    v=node('POWERPCT');v.value=0;v.operator='LESSTHAN';assert(a:evaluateConditionResult(v).status=='match','below-zero percent was clamped')
end)
test('nonfinite derived percentages stay unavailable without changing finite adapter records',function()
    local _,a,s=fixture();s.current[0]=1e308;s.maximum[0]=1e-308;s.current[3]=1e308;s.maximum[3]=1e-308
    for _,tag in ipairs({'MANAPCT','POWERPCT'}) do unknown(a,node(tag)) end
end)
test('finite signed native inputs whose deficit overflows stay unavailable through NOT branches and editable copies',function()
    local _,a,s=fixture();s.powerType=26;s.current[26]=-1e308;s.maximum[26]=1e308
    local record=assert(a.Platform:GetUnitPowerObservation('target','current',true));assert(record.current==-1e308 and record.maximum==1e308)
    local value=node('POWER');value.value=-1;value.operator='GREATERTHAN'
    local result,why=a.conditionDefinitions.POWER.evaluate(value,{});assert(result==nil and why=='invalid-power-deficit');unknown(a,value)
    clones(a);value.type='COPY_POWER';unknown(a,value)
end)
test('normalized per-pass query identities share nil tuples and retry form changes on the next pass',function()
    local _,a,s=fixture();local cache={};local deficit=node('POWER');deficit.value=-80
    assert(a.conditionDefinitions.POWER.evaluate(deficit,cache));assert(a.conditionDefinitions.POWERPCT.evaluate(node('POWERPCT'),cache));assert(s.calls.type==1 and s.calls.current==1 and s.calls.maximum==1)
    s.powerType=1;local v=node('POWER');v.value=10;assert(a.conditionDefinitions.POWER.evaluate(v,{}));assert(s.calls.type==2)
    s.powerType=0;cache={};assert(a.conditionDefinitions.MANA.evaluate(node('MANA'),cache));local before=s.calls.current;assert(a.conditionDefinitions.POWER.evaluate(node('POWER'),cache));assert(s.calls.current==before+1,'explicit and current modes collapsed at Mana0')
    s.current[0]=nil;cache={};local first,why=a.conditionDefinitions.MANA.evaluate(node('MANA'),cache);assert(first==nil and type(why)=='string');s.current[0]=20
    local again,reason=a.conditionDefinitions.MANA.evaluate(node('MANA'),cache);assert(again==nil and reason==why);assert(a.conditionDefinitions.MANA.evaluate(node('MANA'),{}))
end)
test('restricted and unsupported combat policies cannot observe resources or authorize NOT',function()
    for _,project in ipairs({999}) do local _,a,s=fixture(project);for _,tag in ipairs(tags) do unknown(a,node(tag)) end;assert(next(s.calls)==nil) end
end)
test('editable Built In clones use repaired observation and scale while saved raw custom code stays exact',function()
    local _,a,s=fixture();clones(a)
    for _,tag in ipairs(tags) do assert(a:GetBuiltinConditionSource(tag).evaluate:find('addon.Platform.GetUnitPowerObservation',1,true),'resource catalog is stale');local v=node(tag);v.type='COPY_'..tag;assert(a:evaluateConditionResult(v).status=='match') end
    s.powerType=26;local v=node('POWERPCT');v.type='COPY_POWERPCT';v.value=0;v.operator='LESSTHAN';assert(a:evaluateConditionResult(v).status=='match')
    local raw=assert(a:GetBuiltinConditionSource('POWERPCT'));raw.evaluate='if not addon.getCached(cache,UnitExists,value.unit) then return false end;local power=addon.getCached(cache,UnitPowerType,value.unit);if power==nil then return false end;local pct=addon.getCached(cache,UnitPower,value.unit,power)/addon.getCached(cache,UnitPowerMax,value.unit,power)*100;return addon.compare(value.operator,pct,value.value)'
    local saved=assert(a:CompileCustomCondition('SAVED_RAW_POWER_PERCENT',raw));s.powerType=3;v=node('POWERPCT');v.operator='GREATERTHAN';v.value=.5;assert(saved.evaluate(v,{})==true,'saved raw percent callback was silently rewritten');v.type='COPY_POWERPCT';assert(a:evaluateConditionResult(v).status=='no-match')
    s.current[3]=nil;for _,tag in ipairs({'POWER','POWERPCT'}) do v=node(tag);v.type='COPY_'..tag;unknown(a,v) end
end)
test('public observer clones resolve actual helpers and document mode-specific signed quantities',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_power.lua:Platform_GetUnitPowerObservation';local source=a:CopySettingsData(assert(a.builtinFunctions[id],'resource helper catalog missing').source)
    assert(source.args[1].type=='RMPlatform' and source.args[2].name=='unit' and source.args[3].name=='resource' and source.args[4].name=='includeMaximum' and source.description:find('signed',1,true))
    assert(a:InstallCustomFunction('COPY_POWER_OBSERVER',source));local fn=a:ResolveFunctionBinding('COPY_POWER_OBSERVER');s.powerType=26;local r=assert(fn(a.Platform,'vehicle','current',true));assert(r.powerType==26 and r.current==-25 and r.maximum==100)
    local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end;s.current[26]=secret;local value,why=fn(a.Platform,'vehicle','current',true);assert(value==nil and why=='restricted-value')
    assert(source.bindings.finite=='builtin:Platform/unit_power.lua:finite' and a:ResolveFunctionBinding(source.bindings.finite)==a.builtinSourceModules['Platform/unit_power.lua']('finite'))
end)
finish()
