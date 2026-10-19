local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local kinds={STEALTHED='stealthed',INCONTROL='control',OUTDOORS='outdoors'}
local apis={stealthed='IsStealthed',control='HasFullControl',outdoors='IsOutdoors'}
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={stealthed=true,control=true,outdoors=true,calls={}}
    for kind,api in pairs(apis) do local selected=kind;e[api]=function(...)
        assert(select('#',...)==0);s.calls[#s.calls+1]=selected;if s.throw==selected then error('native player flag failure') end;return s[selected]
    end end
    local file=io.open('Platform/player_flags.lua');if file then file:close();f.load('Platform/player_flags.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Conditions/misc.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function unknown(a,tag)
    local v={type=tag};assert(a.conditionDefinitions[tag].valid(0,v))
    for _,node in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(node);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown flag became actionable')
    end
    local body={rotation={{id='flag',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown flag selected an arm') end).status=='unavailable')
end
test('required unknown flags stay unavailable under NOT groups and both branch arms',function()
    for tag,kind in pairs(kinds) do for _,mode in ipairs({'missing','nil','throw','restricted',0,1,'false'}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then f.env[apis[kind]]=nil elseif mode=='nil' then s[kind]=nil elseif mode=='throw' then s.throw=kind elseif mode=='restricted' then s[kind]=opaque else s[kind]=mode end
        unknown(a,tag)
    end end
end)
test('known true and false preserve exact NOT and branch selection controls',function()
    for tag,kind in pairs(kinds) do for _,flag in ipairs({true,false}) do local _,a,s=fixture();s[kind]=flag
        assert(a:evaluateConditionResult({type=tag}).status==(flag and 'match' or 'no-match'))
        assert(a:evaluateConditionResult({type='NOT',value={type=tag}}).status==(flag and 'no-match' or 'match'))
        local selected;local body={rotation={{id='flag',type='branch',conditions={type=tag},onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function(v) selected=v.id;return true end);assert(selected==(flag and 'yes' or 'no') and #s.calls==3)
    end end
end)
test('complete per-kind cache snapshots preserve false nil reasons and fresh uncached recovery',function()
    local _,a,s=fixture();local evaluate=a.conditionDefinitions.STEALTHED.evaluate;local cache={};s.stealthed=nil
    local value,why=evaluate({},cache);assert(value==nil and why=='player-flag-unavailable' and #s.calls==1)
    s.stealthed=true;local again,reason=evaluate({},cache);assert(again==nil and reason==why and #s.calls==1)
    assert(evaluate({},{})==true and #s.calls==2);s.calls={};cache={};s.stealthed=false
    assert(evaluate({},cache)==false);s.stealthed=true;assert(evaluate({},cache)==false and #s.calls==1)
    assert(a.conditionDefinitions.INCONTROL.evaluate({},cache)==true and a.conditionDefinitions.OUTDOORS.evaluate({},cache)==true and #s.calls==3)
    assert(evaluate({})==true and evaluate({})==true and #s.calls==5 and next(a.longtermCache)==nil)
end)
test('unsupported policies and transient errors stay unknown without permanent quarantine',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);for tag in pairs(kinds) do unknown(a,tag) end;assert(#s.calls==0) end
    for tag,kind in pairs(kinds) do local _,a,s=fixture();s.throw=kind;unknown(a,tag);s.throw=nil;assert(a:evaluateConditionResult({type=tag}).status=='match') end
end)
test('current editable copies share normalized kind snapshots and recover with native state',function()
    local _,a,s=fixture()
    for tag,kind in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('GetPlayerFlagObservation',1,true),'player flag source catalog stale')
        local compiled=assert(a:CompileCustomCondition('COPY_'..tag,source));a:RegisterCondition('COPY_'..tag,compiled);local cache={};s.calls={}
        assert(a.conditionDefinitions[tag].evaluate({},cache)==true and compiled.evaluate({},cache)==true and #s.calls==1 and s.calls[1]==kind)
        s[kind]=nil;unknown(a,'COPY_'..tag);s[kind]=false;assert(a:evaluateConditionResult({type='COPY_'..tag}).status=='no-match');s[kind]=true
    end
end)
test('saved raw callbacks retain original nil behavior and source bytes',function()
    local _,a,s=fixture()
    for tag,kind in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate='\n        return Functions.cache.getCached(cache, '..apis[kind]..')\n    '
        local before=a:CopySettingsData(source);local compiled=assert(a:CompileCustomCondition('RAW_'..tag,source));a:RegisterCondition('RAW_'..tag,compiled)
        s[kind]=nil;local value,why=compiled.evaluate({},{});assert(value==nil and why==nil and a:SettingsDataEqual(before,source))
        assert(a:evaluateConditionResult({type='NOT',value={type='RAW_'..tag}}).status=='match');s[kind]=true
    end
end)
test('public observer clone resolves actual owner and live readability policy',function()
    local f,a,s=fixture();local id='builtin:Platform/player_flags.lua:Platform_GetPlayerFlagObservation';local record=assert(a.builtinFunctions[id],'public player observer missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetPlayerFlagObservation and a.builtinSourceModules['Platform/player_flags.lua']('Platform_GetPlayerFlagObservation')==a.Platform.GetPlayerFlagObservation)
    assert(record.source.args[1].type=='RMPlatform' and record.source.args[2].name=='kind' and #record.source.description>0)
    assert(a:InstallCustomFunction('COPY_PLAYER_FLAG',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_PLAYER_FLAG');assert(fn(a.Platform,'outdoors')==true)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.outdoors=opaque;local value,why=fn(a.Platform,'outdoors');assert(value==nil and why=='restricted-value')
end)
test('only three exact evaluator bodies change while complete modules and private sources remain intact',function()
    local _,a=fixture()
    for _,case in ipairs({{'combat','024d794b',{'stealthed','control'}},{'misc','81c86e93',{'outdoors'}}}) do
        local file=assert(io.open('Conditions/'..case[1]..'.lua'));local text=file:read('*a');file:close()
        if case[1]=='combat' then text=dofile('tests/fixtures/restore_threat_repairs.lua')(text);text=dofile('tests/fixtures/restore_pet_repairs.lua')(text) end
        for _,kind in ipairs(case[3]) do local repaired='        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "'..kind..'")'
            local first=assert(text:find(repaired,1,true),'exact player flag repair missing');assert(not text:find(repaired,first+1,true))
            text=text:sub(1,first-1)..'        return Functions.cache.getCached(cache, '..apis[kind]..')'..text:sub(first+#repaired)
        end
        assert(a:FunctionSourceHash(text)==case[2],case[1]..' changed beyond exact player flag callbacks from742794c')
    end
    for module,pins in pairs({['Conditions/combat.lua']={color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'},['Conditions/misc.lua']={color='89a5436e',helpers='3ab28a24'}}) do
        for name,hash in pairs(pins) do local id='builtin:'..module..':'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules[module](name),'private source identity drifted') end
    end
end)
finish()
