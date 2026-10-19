local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local original=[[        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local enemy = Functions.cache.getCached(cache, UnitIsEnemy, "player", value.unit)
        if enemy then
            local rv = Functions.cache.getCached(cache, UnitThreatSituation, "player", value.unit)
            if rv ~= nil and rv >= value.threat - 1 then
                return true
            else
                return false
            end
        else
            return false
        end]]
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,enemy=true,threat=2,calls={}}
    local function call(key,...)
        s.calls[#s.calls+1]={key,...};if s.throw==key then error('native threat failure') end;return s[key]
    end
    e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end
    e.UnitIsEnemy=function(...) assert(select('#',...)==2);return call('enemy',...) end
    e.UnitThreatSituation=function(...) assert(select('#',...)==2);return call('threat',...) end
    local file=io.open('Platform/threat.lua');if file then file:close();f.load('Platform/threat.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,unit,threshold) return {type=tag or 'THREAT',unit=unit or 'target',threat=threshold or 1} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass unchanged validator')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown threat became actionable')
    end
    local body={rotation={{id='threat',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown threat selected branch') end).status=='unavailable')
end
test('required unknown facts cannot become matches through NOT groups or either branch arm',function()
    for key,api in pairs({exists='UnitExists',enemy='UnitIsEnemy',threat='UnitThreatSituation'}) do
        local modes={'missing','throw','restricted',{},'false'};if key~='threat' then modes[#modes+1]='nil';modes[#modes+1]=0 else modes[#modes+1]=false;modes[#modes+1]=math.huge;modes[#modes+1]=0/0 end
        for _,mode in ipairs(modes) do local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
            if mode=='missing' then f.env[api]=nil elseif mode=='nil' then s[key]=nil elseif mode=='throw' then s.throw=key elseif mode=='restricted' then s[key]=opaque else s[key]=mode end
            unknown(a,node())
        end
    end
end)
test('known optional nil zero false and finite thresholds preserve direct NOT branch controls',function()
    for _,case in ipairs({{true,true,'nil',1,false},{true,true,0,1,true},{true,true,0,2,false},{true,true,1.5,2.5,true},{true,true,-1,1,false},{true,true,9,4,true},{false,true,3,1,false},{true,false,3,1,false}}) do
        local _,a,s=fixture();s.exists=case[1];s.enemy=case[2];s.threat=case[3];if case[3]=='nil' then s.threat=nil end
        local v=node(nil,nil,case[4]);assert(a.conditionDefinitions.THREAT.valid(0,v));assert(a:evaluateConditionResult(v).status==(case[5] and 'match' or 'no-match'))
        assert(a:evaluateConditionResult({type='NOT',value=v}).status==(case[5] and 'no-match' or 'match'))
        local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end)
        assert(selected==(case[5] and 'yes' or 'no'))
    end
end)
test('per pass snapshots isolate unit self and threshold while caching nil reason false and zero',function()
    local _,a,s=fixture();local evaluate=a.conditionDefinitions.THREAT.evaluate;local cache={};s.enemy=nil
    local value,reason=evaluate(node(),cache);assert(value==nil and reason=='unit-data-unavailable' and #s.calls==2)
    s.enemy=true;local again,why=evaluate(node(),cache);assert(again==nil and why==reason and #s.calls==2)
    assert(evaluate(node(),{})==true and #s.calls==5);s.calls={};cache={};s.threat=0
    assert(evaluate(node(nil,nil,1),cache)==true and evaluate(node(nil,nil,2),cache)==false and #s.calls==3)
    s.threat=3;assert(evaluate(node(nil,nil,2),cache)==false and #s.calls==3)
    assert(evaluate(node(nil,'focus',2),cache)==true and #s.calls==6)
    local other=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,a.Platform.GetUnitThreatObservation,other,'target')==3 and #s.calls==9)
    cache={};s.threat=nil;assert(evaluate(node(),cache)==false);s.threat=3;assert(evaluate(node(),cache)==false and #s.calls==12)
    assert(evaluate(node())==true and evaluate(node())==true and #s.calls==18 and next(a.longtermCache)==nil)
end)
test('unsupported policy and transient errors remain unknown and recover next evaluation',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a,node());assert(#s.calls==0) end
    local _,a,s=fixture();s.throw='threat';unknown(a,node());s.throw=nil;assert(a:evaluateConditionResult(node()).status=='match')
end)
test('current editable copies share exact observer calls and support fresh unavailable recovery',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('THREAT'));assert(source.evaluate:find('GetUnitThreatObservation',1,true),'threat source catalog stale')
    local compiled=assert(a:CompileCustomCondition('COPY_THREAT',source));a:RegisterCondition('COPY_THREAT',compiled);local cache={}
    assert(a.conditionDefinitions.THREAT.evaluate(node(),cache)==true and compiled.evaluate(node('COPY_THREAT'),cache)==true and #s.calls==3)
    assert(s.calls[1][2]=='target' and s.calls[2][2]=='player' and s.calls[2][3]=='target' and s.calls[3][2]=='player' and s.calls[3][3]=='target')
    s.enemy=nil;unknown(a,node('COPY_THREAT'));s.enemy=true;s.threat=nil;assert(a:evaluateConditionResult(node('COPY_THREAT')).status=='no-match')
    s.threat=0;assert(a:evaluateConditionResult(node('COPY_THREAT')).status=='match')
end)
test('saved raw callbacks retain optional nil and legacy missing prerequisite behavior unchanged',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('THREAT'));source.evaluate='\n'..original..'\n    '
    local before=a:CopySettingsData(source);local compiled=assert(a:CompileCustomCondition('RAW_THREAT',source));a:RegisterCondition('RAW_THREAT',compiled)
    s.enemy=nil;assert(compiled.evaluate(node(),{})==false and a:evaluateConditionResult({type='NOT',value=node('RAW_THREAT')}).status=='match')
    s.enemy=true;s.threat=nil;assert(compiled.evaluate(node(),{})==false);s.threat=0;assert(compiled.evaluate(node(),{})==true)
    assert(a:SettingsDataEqual(before,source),'saved raw source rewritten')
end)
test('public observer copy resolves real owner and current readability with preserved zero',function()
    local f,a,s=fixture();local id='builtin:Platform/threat.lua:Platform_GetUnitThreatObservation';local record=assert(a.builtinFunctions[id],'public threat observer missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetUnitThreatObservation and a.builtinSourceModules['Platform/threat.lua']('Platform_GetUnitThreatObservation')==a.Platform.GetUnitThreatObservation)
    assert(record.source.args[1].type=='RMPlatform' and record.source.args[2].name=='unit' and #record.source.description>0)
    assert(a:InstallCustomFunction('COPY_UNIT_THREAT',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_UNIT_THREAT');s.threat=0;assert(fn(a.Platform,'focus')==0)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.threat=opaque;local value,why=fn(a.Platform,'target');assert(value==nil and why=='restricted-value')
end)
test('only the exact pet and threat repairs change complete combat bytes and private identities',function()
    local _,a=fixture();local file=assert(io.open('Conditions/combat.lua'));local text=file:read('*a');file:close()
    text=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')(text)
    text=dofile('tests/fixtures/restore_threat_repairs.lua')(text)
    text=dofile('tests/fixtures/restore_pet_repairs.lua')(text)
    assert(a:FunctionSourceHash(text)=='f0ca653e','combat changed beyond PET/PET_NAME/THREAT repairs from4487926')
    for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do
        local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name),'private source identity drifted')
    end
end)
finish()
