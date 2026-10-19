local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local families={cast={'CASTING','CASTING_SPELL','CASTING_REMAIN','CAST_INTERRUPTABLE'},channel={'CHANNELING','CHANNELING_SPELL','CHANNELING_REMAIN','CHANNEL_INTERRUPTABLE'}}
local tags={};for _,kind in ipairs({'cast','channel'}) do for _,tag in ipairs(families[kind]) do tags[#tags+1]=tag end end
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={now=100,exists=true,name='Arcane Missiles',ending=103000,flag=false,calls={}}
    local function call(key) s.calls[key]=(s.calls[key] or 0)+1;if s.throw==key then error('native '..key..' failed') end end
    e.GetTime=function() call('time');return s.now end;e.UnitExists=function() call('exists');return s.exists end
    e.UnitCastingInfo=function() call('cast');return s.name,'display',1,99000,s.ending,false,'cast-guid',s.flag,5143 end
    e.UnitChannelInfo=function() call('channel');return s.name,'display',1,99000,s.ending,false,s.flag,5143,false,0 end
    for _,file in ipairs({'Platform/casting.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/casting.lua','Conditions/channeling.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(file) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag) return {type=tag,unit='target',spell='Arcane Missiles',operator='EQUALS',value=3} end
local function copies(a)
    local result={};for _,tag in ipairs(tags) do result[tag]=assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag))));a:RegisterCondition('COPY_'..tag,result[tag]) end;return result
end
local function unavailable(a,value)
    assert(a:evaluateConditionResult(value).status=='unavailable',value.type..' became known data')
    assert(a:evaluateConditionResult({type='NOT',value=value}).status=='unavailable',value.type..' unknown negated into match')
    local body={rotation={{id='guard',type='branch',conditions=value,onTrue={{id='yes',type='spell',action=5143}},onFalse={{id='no',type='spell',action=5143}}}}}
    assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unavailable cast guard selected an action') end).status=='unavailable')
end
test('eight real cast and channel predicates use seconds and the correct interruptibility slots',function()
    local _,a=fixture();for _,tag in ipairs(tags) do assert(a:evaluateConditionResult(node(tag)).status=='match',tag..' positive control failed') end
    for _,tag in ipairs({'CASTING_REMAIN','CHANNELING_REMAIN'}) do for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE'}) do
        local v=node(tag);v.operator=operator;v.value=operator=='DIVISIBLE' and 1 or 3;assert(a.conditionDefinitions[tag].evaluate(v,{})==a.compare(operator,3,v.value))
    end end
end)
test('readable inactive casts and absent units remain known false under NOT without querying later fields',function()
    local _,a,s=fixture();s.name=nil
    for _,tag in ipairs(tags) do assert(a:evaluateConditionResult({type='NOT',value=node(tag)}).status=='match') end
    s.exists=false;s.name='Arcane Missiles';s.calls={};for _,tag in ipairs(tags) do assert(a:evaluateConditionResult({type='NOT',value=node(tag)}).status=='match') end
    assert(not s.calls.cast and not s.calls.channel)
end)
test('all consumers share one normalized observation per unit kind and evaluation cache',function()
    local _,a,s=fixture();local values={};for _,tag in ipairs(tags) do values[#values+1]=node(tag) end
    assert(a:evaluateConditionResult({type='AND',value=values}).status=='match');assert(s.calls.cast==1 and s.calls.channel==1 and s.calls.exists==2)
    a:evaluateConditionResult(node('CASTING'));assert(s.calls.cast==2,'new evaluation reused a stale native observation')
    local cache={};local first=a.getCached(cache,a.Platform.GetUnitCastObservation,a.Platform,'target','cast');local second=a.getCached(cache,a.Platform.GetUnitCastObservation,a.Platform,'target','cast');assert(first==second)
    local other=a.getCached(cache,a.Platform.GetUnitCastObservation,a.Platform,'target','channel');assert(other~=first,'cast and channel cache identities collided')
end)
test('optional timer and flag unavailability only blocks predicates that need those observations',function()
    for _,mode in ipairs({'missing','restricted'}) do local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then s.ending=nil;s.flag=nil elseif mode=='restricted' then s.ending=opaque;s.flag=opaque end
        for _,tag in ipairs({'CASTING','CASTING_SPELL','CHANNELING','CHANNELING_SPELL'}) do assert(a:evaluateConditionResult(node(tag)).status=='match',tag..' lost a readable active name') end
        for _,tag in ipairs({'CASTING_REMAIN','CHANNELING_REMAIN'}) do unavailable(a,node(tag)) end
        for _,tag in ipairs({'CAST_INTERRUPTABLE','CHANNEL_INTERRUPTABLE'}) do unavailable(a,node(tag)) end
    end
end)
test('missing failed nil malformed and unreadable unit or cast observations remain unavailable through NOT and branches',function()
    for _,mode in ipairs({'missing-exists','nil-exists','throw-exists','restricted-exists','missing-info','throw-info','restricted-name','empty-name','invalid-name'}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing-exists' then f.env.UnitExists=nil elseif mode=='nil-exists' then s.exists=nil elseif mode=='throw-exists' then s.throw='exists' elseif mode=='restricted-exists' then s.exists=opaque
        elseif mode=='missing-info' then f.env.UnitCastingInfo=nil;f.env.UnitChannelInfo=nil elseif mode=='restricted-name' then s.name=opaque elseif mode=='empty-name' then s.name='' elseif mode=='invalid-name' then s.name=12 end
        for _,tag in ipairs(tags) do if mode=='throw-info' then s.throw=tag:find('CHANNEL',1,true) and 'channel' or 'cast' end;unavailable(a,node(tag)) end
    end
end)
test('restricted and unsupported client policies cannot query native cast information or authorize NOT',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);for _,tag in ipairs(tags) do unavailable(a,node(tag)) end;assert(not s.calls.exists and not s.calls.cast and not s.calls.channel) end
end)
test('compiled copies preserve the repaired observation contract validation and wording with unchanged private captures',function()
    local _,a,s=fixture();local cloned=copies(a)
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetUnitCastObservation',1,true),'catalog still contains old raw observer')
        local v=node(tag);assert(cloned[tag].evaluate(v,{})==a.conditionDefinitions[tag].evaluate(v,{}));assert(cloned[tag].valid(0,v)==a.conditionDefinitions[tag].valid(0,v))
        for _,negated in ipairs({false,true}) do assert(cloned[tag].print(0,v,negated)==a.conditionDefinitions[tag].print(0,v,negated)) end
    end
    s.flag=nil;s.ending=nil;for _,tag in ipairs({'CASTING_REMAIN','CHANNELING_REMAIN','CAST_INTERRUPTABLE','CHANNEL_INTERRUPTABLE'}) do local v=node(tag);v.type='COPY_'..tag;unavailable(a,v) end
    for module,hashes in pairs({casting={color='149792a5',helpers='c2ab875b'},channeling={color='ad3e7907',helpers='f3eed23d'}}) do for name,hash in pairs(hashes) do local id='builtin:Conditions/'..module..'.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/'..module..'.lua'](name)) end end
end)
test('public adapter source clones resolve real private helpers and preserve argument docs and live readability policy',function()
    local f,a,s=fixture();local id='builtin:Platform/casting.lua:Platform_GetUnitCastObservation';local registered=assert(a.builtinFunctions[id]);local source=a:CopySettingsData(registered.source)
    assert(source.description:find('independently',1,true) and source.code:find('UnitCastingInfo',1,true) and source.code:find('UnitChannelInfo',1,true))
    local expected={{'self','RMPlatform'},{'unit','string'},{'kind','string'}}
    for index,arg in ipairs(expected) do assert(source.args[index].name==arg[1] and source.args[index].type==arg[2] and #source.args[index].description>0) end
    assert(source.bindings.remainingSeconds=='builtin:Platform/casting.lua:remainingSeconds' and source.bindings.interruptibility=='builtin:Platform/casting.lua:interruptibility')
    assert(a:InstallCustomFunction('COPY_CAST_OBSERVER',source));local copied=a:ResolveFunctionBinding('COPY_CAST_OBSERVER');assert(type(copied)=='function')
    for _,kind in ipairs({'cast','channel'}) do local result=copied(a.Platform,'target',kind);assert(result.active and result.name=='Arcane Missiles' and result.remainingSeconds==3 and result.interruptible==true) end
    for _,name in ipairs({'remainingSeconds','interruptibility','finite','platform'}) do local binding='builtin:Platform/casting.lua:'..name;assert(a:ResolveFunctionBinding(binding)==a.builtinSourceModules['Platform/casting.lua'](name)) end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.ending=opaque;s.flag=nil
    local record=copied(a.Platform,'target','cast');assert(record.active and record.remainingSeconds==nil and record.remainingReason=='restricted-value' and record.interruptibleReason=='interruptibility-unavailable')
    s.name=opaque;local unavailable,why=copied(a.Platform,'target','cast');assert(unavailable==nil and why=='restricted-value')
    f.env.WOW_PROJECT_ID=1;s.calls={};unavailable,why=copied(a.Platform,'target','cast');assert(unavailable==nil and why=='unsupported-policy' and next(s.calls)==nil)
end)
test('saved original raw callback source and original addon helper APIs remain executable',function()
    local _,a=fixture();local source=assert(a:GetBuiltinConditionSource('CASTING_REMAIN'))
    source.evaluate='if not addon.getCached(cache,UnitExists,value.unit) then return false end;local name,_,_,_,ending=addon.getCached(cache,UnitCastingInfo,value.unit);if name~=nil then return addon.compare(value.operator,ending-(GetTime()*1000),value.value) end;return false'
    local legacy=assert(a:CompileCustomCondition('SAVED_RAW_CAST',source));local v=node('CASTING_REMAIN');v.value=3000;assert(legacy.evaluate(v,{})==true,'stored custom callback was silently rewritten')
    local copied=assert(a:CompileCustomCondition('NEW_CAST',assert(a:GetBuiltinConditionSource('CASTING_REMAIN'))));v.value=3;assert(copied.evaluate(v,{})==true)
    assert(a.getCached==a.Functions.cache.getCached and a.compare==a.Functions.values.compare)
end)
finish()
