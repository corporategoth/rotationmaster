local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local inverse,oldBody,newBody=dofile('tests/fixtures/restore_combat_time_repairs.lua')
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local catalogText=read('Data/builtin_sources.lua')
local function fixture(project)
    local f=F.new(project or 11,2,'MAGE');local a,e=f.addon,f.env
    local s={now=100,clockCalls=0};a.combatStart=95
    e.GetTime=function(...) assert(select('#',...)==0);s.clockCalls=s.clockCalls+1;return s.now end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    local chunk=assert(loadstring(catalogText,'@combat-time-catalog-snapshot'));setfenv(chunk,e);chunk('rotationmaster',a);f.load('Core/builtin_sources.lua')
    e.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(operator,value,tag) return {type=tag or 'TIME_IN_COMBAT',operator=operator or 'NOTEQUALS',value=value or 0} end
local function branch(a,guard)
    local selected
    local body={rotation={{id='guard',type='branch',conditions=guard,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    local result=a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(row) selected=row.id;return true end)
    return result,selected
end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'invalid combat time test node')
    for _,guard in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(guard)
        assert(result.status=='unavailable' and result.reason~='condition-callback-error',tostring(result.status)..':'..tostring(result.reason))
    end
    for _,guard in ipairs({v,{type='NOT',value=v}}) do local result,selected=branch(a,guard);assert(result.status=='unavailable' and selected==nil,'unknown clock selected branch') end
    assert(#a.Diagnostics:GetReports()==0,'invalid time observation quarantined the callback')
end

test('present malformed nonfinite and unreadable stored start remain unknown through logical wrappers and branches',function()
    for _,bad in ipairs({false,true,'95',{},0/0,math.huge,-math.huge}) do local _,a=fixture();a.combatStart=bad;unknown(a,node()) end
    local f,a=fixture();local opaque=setmetatable({},{__sub=function() error('unreadable start used in arithmetic') end})
    a.combatStart=opaque;f.env.canaccessvalue=function(value) return not rawequal(value,opaque) end;unknown(a,node())
end)
test('required supplied evaluation clock is readable finite numeric before arithmetic',function()
    for _,bad in ipairs({false,true,'100',{},0/0,math.huge,-math.huge}) do local _,a,s=fixture();s.now=bad;unknown(a,node()) end
    local f,a,s=fixture();local opaque=setmetatable({},{__sub=function() error('unreadable current time used in arithmetic') end})
    s.now=opaque;f.env.canaccessvalue=function(value) return not rawequal(value,opaque) end;unknown(a,node())
    s.now=nil;unknown(a,node())
end)
test('finite subtraction overflow and unreadable derived elapsed remain unknown',function()
    for _,pair in ipairs({{-1e308,1e308},{1e308,-1e308}}) do local _,a,s=fixture();a.combatStart=pair[1];s.now=pair[2];unknown(a,node()) end
    local f,a=fixture();f.env.canaccessvalue=function(value) return value~=5 end;unknown(a,node())
end)
test('readable nil alone is known absence and skips supplied time without native or cache work',function()
    local f,a=fixture();local evaluate=a.conditionDefinitions.TIME_IN_COMBAT.evaluate;a.combatStart=nil
    local opaque={};f.env.canaccessvalue=function(value) assert(not rawequal(value,opaque),'absent start consumed supplied time');return true end
    f.env.GetTime=function() error('callback queried a fresh clock') end
    local cache=setmetatable({},{__index=function() error('cache read') end,__newindex=function() error('cache write') end})
    assert(evaluate(node(),cache,opaque)==false and evaluate(node(),nil,nil)==false)
    f.env.GetTime=function() return nil end
    assert(a:evaluateConditionResult(node()).status=='no-match' and a:evaluateConditionResult({type='NOT',value=node()}).status=='match')
    local result,selected=branch(a,node());assert(result.status=='complete' and selected=='no')
    result,selected=branch(a,{type='NOT',value=node()});assert(result.status=='complete' and selected=='yes')
end)
test('zero signed fractional and negative elapsed preserve every comparison and threshold validator',function()
    local _,a,s=fixture()
    for _,pair in ipairs({{0,0},{-10.25,-5.5},{95.5,100.25},{101.5,100},{-1.25,-2.75}}) do
        a.combatStart=pair[1];s.now=pair[2]
        for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE'}) do
            local v=node(operator,2);local expected=a.Functions.values.compare(operator,pair[2]-pair[1],2)
            assert(a.conditionDefinitions.TIME_IN_COMBAT.valid(0,v))
            assert(a:evaluateConditionResult(v).status==(expected and 'match' or 'no-match'))
            local result,selected=branch(a,v);assert(result.status=='complete' and selected==(expected and 'yes' or 'no'))
        end
    end
    a.combatStart=95;s.now=100;local v=node('NOTEQUALS',math.huge)
    assert(a.conditionDefinitions.TIME_IN_COMBAT.valid(0,v) and a:evaluateConditionResult(v).status=='match','configured threshold scope changed')
end)
test('live state and supplied clock recover in the same cache without new native calls or policy gates',function()
    for _,project in ipairs({1,2,5,11,14,18,19,999}) do
        local f,a=fixture(project);local evaluate=a.conditionDefinitions.TIME_IN_COMBAT.evaluate
        f.env.GetTime=function() error('callback sampled native clock') end
        a.Platform.GetClientInfo=function() error('local time condition queried client policy') end
        local cache={retained={}};local retained=cache.retained;a.combatStart=0/0
        local value,why=evaluate(node(),cache,100);assert(value==nil and type(why)=='string')
        a.combatStart=95;assert(evaluate(node('EQUALS',5),cache,100));a.combatStart=96;assert(evaluate(node('EQUALS',4),cache,100));assert(evaluate(node('EQUALS',5),cache,101))
        local count=0;for _ in pairs(cache) do count=count+1 end;assert(count==1 and cache.retained==retained,'elapsed polluted cache')
    end
end)
test('actual engine retains one zeroarg sample and observation recovery without quarantine',function()
    local _,a,s=fixture();s.now=0/0;unknown(a,node());local before=s.clockCalls;s.now=100
    assert(a:evaluateConditionResult(node('EQUALS',5)).status=='match' and s.clockCalls==before+1,'engine sample count changed')
    a.combatStart=0/0;unknown(a,node());a.combatStart=95;assert(a:evaluateConditionResult(node('EQUALS',5)).status=='match')
    assert(#a.Diagnostics:GetReports()==0)
end)
test('current editable clone repairs observations while raw saved source remains exact and keeps prior behavior',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('TIME_IN_COMBAT'))
    assert(source.evaluate==newBody,'TIME_IN_COMBAT catalog pending');local before=a:CopySettingsData(source)
    a:RegisterCondition('COPY_COMBAT_TIME',assert(a:CompileCustomCondition('COPY_COMBAT_TIME',source)))
    a.combatStart=0/0;unknown(a,node(nil,nil,'COPY_COMBAT_TIME'));a.combatStart=95;s.now=100
    assert(a:evaluateConditionResult(node('EQUALS',5,'COPY_COMBAT_TIME')).status=='match')
    local old=a:CopySettingsData(source);old.evaluate=oldBody;local stored=a:CopySettingsData(old);a.db.global.custom_conditions={RAW_TIME=old}
    a:RegisterCondition('RAW_COMBAT_TIME',assert(a:CompileCustomCondition('RAW_COMBAT_TIME',old)))
    a.combatStart=0/0;assert(a:evaluateConditionResult(node(nil,nil,'RAW_COMBAT_TIME')).status=='match')
    assert(a:SettingsDataEqual(source,before) and a:SettingsDataEqual(old,stored) and a.db.global.custom_conditions.RAW_TIME==old,'saved code rewritten')
    local restored=a:CopySettingsData(source);restored.evaluate=inverse(restored.evaluate,true)
    assert(a:FunctionSourceHash(restored)=='81aec83c','export metadata or bindings changed beyond callback')
end)
test('strict one evaluator inverse preserves whole combat source and all private records and getters',function()
    local _,a=fixture();local text=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(dofile('tests/fixtures/restore_form_presentation_repairs.lua')(dofile('tests/fixtures/restore_form_localization.lua')(read('Conditions/combat.lua'))));text=dofile('tests/fixtures/restore_threat_count_repairs.lua')(text)
    assert(a:FunctionSourceHash(inverse(text))=='380252c0','combat changed beyond TIME_IN_COMBAT.evaluate')
    assert(inverse(newBody,true)==oldBody and not pcall(inverse,oldBody,true) and not pcall(inverse,newBody..' ',true))
    assert(not pcall(inverse,text..text),'duplicate repair accepted')
    for name,hash in pairs({character_class='d17cf4c1',color='dbda383d',helpers='9e28e933'}) do
        local id='builtin:Conditions/combat.lua:'..name
        assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/combat.lua'](name)),'private identity changed '..name)
    end
end)
finish()
