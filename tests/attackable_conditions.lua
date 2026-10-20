local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local raw=[[if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitCanAttack, "player", value.unit) and
               not Functions.cache.getCached(cache, UnitIsDead, value.unit)]]
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,attack=true,dead=false,calls={}}
    local function call(key,...) s.calls[#s.calls+1]={key,...};if s.throw==key then error('native failure') end;return s[key] end
    e.UnitExists=function(...) return call('exists',...) end
    e.UnitCanAttack=function(...) return call('attack',...) end
    e.UnitIsDead=function(...) return call('dead',...) end
    e.UnitIsDeadOrGhost=function() error('ghost query must not run') end
    local file=io.open('Platform/unit_attackability.lua');if file then file:close();f.load('Platform/unit_attackability.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag) return {type=tag or 'ATTACKABLE',unit='target'} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unavailable fixtures require valid condition fields')
    assert(a:evaluateConditionResult(v).reason~='invalid-condition-fields','fixture must reach native observation rather than fail schema validation')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={{type='NOT',value=v}}},{type='OR',value={v}}}) do assert(a:evaluateConditionResult(value).status=='unavailable','unreadable attackability became known') end
    local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unavailable attackability selected a branch') end).status=='unavailable')
end
local function clone(a)
    local source=assert(a:GetBuiltinConditionSource('ATTACKABLE'));assert(source.evaluate:find('addon.Platform.GetUnitAttackabilityObservation',1,true),'attackability source catalog is stale')
    a:RegisterCondition('COPY_ATTACKABLE',assert(a:CompileCustomCondition('COPY_ATTACKABLE',source)))
end
local function stage(f,s,key,mode)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    if mode=='missing' then f.env[({exists='UnitExists',attack='UnitCanAttack',dead='UnitIsDead'})[key]]=nil
    elseif mode=='throw' then s.throw=key elseif mode=='restricted' then s[key]=opaque elseif mode=='nil' then s[key]=nil else s[key]=mode end
end
test('required missing nil failed malformed and restricted facts stay unavailable through NOT groups and branches',function()
    for _,key in ipairs({'exists','attack','dead'}) do for _,mode in ipairs({'missing','nil','throw','restricted',0,1,'false'}) do
        local f,a,s=fixture();stage(f,s,key,mode);unknown(a,node())
    end end
end)
test('alive absent unattackable and dead facts retain positive and false branch behavior',function()
    local _,a,s=fixture();assert(a:evaluateConditionResult(node()).status=='match');assert(a:evaluateConditionResult({type='NOT',value=node()}).status=='no-match')
    for _,key in ipairs({'exists','attack','dead'}) do s.exists=true;s.attack=true;s.dead=false;s[key]=key=='dead';s.calls={}
        assert(a:evaluateConditionResult(node()).status=='no-match' and a:evaluateConditionResult({type='NOT',value=node()}).status=='match')
        local selected;local body={rotation={{id='guard',type='branch',conditions=node(),onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function(v) selected=v.id;return true end);assert(selected=='no')
        local perEval=key=='exists' and 1 or key=='attack' and 2 or 3;assert(#s.calls==perEval*3)
    end
end)
test('per-pass tuples preserve false and nil reasons and recover only on fresh observations',function()
    local _,a,s=fixture();local evaluate=a.conditionDefinitions.ATTACKABLE.evaluate;local cache={};s.dead=nil
    local v,why=evaluate(node(),cache);assert(v==nil and why=='death-data-unavailable' and #s.calls==3)
    s.dead=false;local again,reason=evaluate(node(),cache);assert(again==nil and reason==why and #s.calls==3)
    assert(evaluate(node(),{})==true and #s.calls==6)
    cache={};s.attack=false;s.calls={};v,why=evaluate(node(),cache);assert(v==false and why==nil and #s.calls==2)
    s.attack=true;assert(evaluate(node(),cache)==false and #s.calls==2 and evaluate(node(),{})==true)
end)
test('restricted and unsupported client policies do not query native state or authorize NOT',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a,node());assert(#s.calls==0) end
end)
test('current editable clones share canonical snapshot identity exact actor and next-pass recovery',function()
    local _,a,s=fixture();clone(a);local cache={};local v=node();v.unit='vehicle';local copied=node('COPY_ATTACKABLE');copied.unit='vehicle'
    assert(a.conditionDefinitions.ATTACKABLE.evaluate(v,cache)==true and a.conditionDefinitions.COPY_ATTACKABLE.evaluate(copied,cache)==true and #s.calls==3)
    assert(s.calls[1][2]=='vehicle' and s.calls[2][2]=='player' and s.calls[2][3]=='vehicle' and s.calls[3][2]=='vehicle')
    copied.unit='target';s.dead=nil;unknown(a,copied);s.dead=false;assert(a:evaluateConditionResult(copied).status=='match')
    s.attack=false;assert(a:evaluateConditionResult(copied).status=='no-match')
end)
test('old saved raw callbacks keep exact nil behavior and native APIs rather than being rewritten',function()
    local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('ATTACKABLE'));source.evaluate=raw
    local copy=assert(a:CompileCustomCondition('SAVED_RAW_ATTACKABLE',source));assert(copy.evaluate(node(),{})==true)
    s.dead=nil;assert(copy.evaluate(node(),{})==true);s.exists=nil;assert(copy.evaluate(node(),{})==false)
    s.exists=true;s.attack=nil;assert(copy.evaluate(node(),{})==nil)
end)
test('public observer source clone resolves actual method and uses live readability guards',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_attackability.lua:Platform_GetUnitAttackabilityObservation';local record=assert(a.builtinFunctions[id],'attackability public helper catalog missing')
    local source=a:CopySettingsData(record.source);assert(#source.description>0 and source.args[1].type=='RMPlatform' and source.args[2].name=='unit')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetUnitAttackabilityObservation and a.builtinSourceModules['Platform/unit_attackability.lua']('Platform_GetUnitAttackabilityObservation')==a.Platform.GetUnitAttackabilityObservation)
    assert(a:InstallCustomFunction('ATTACKABILITY_OBSERVER_COPY',source));local fn=a:ResolveFunctionBinding('ATTACKABILITY_OBSERVER_COPY');assert(fn(a.Platform,'target')==true)
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.dead=opaque;local v,why=fn(a.Platform,'target');assert(v==nil and why=='restricted-value')
    s.attack=false;assert(fn(a.Platform,'target')==false)
end)
test('only the exact ATTACKABLE evaluator changes from the movement checkpoint with private bindings intact',function()
    local f,a=fixture();local file=assert(io.open('Conditions/combat.lua'));local source=file:read('*a');file:close();source=dofile('tests/fixtures/restore_threat_count_repairs.lua')(dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(source));source=dofile('tests/fixtures/restore_combat_time_repairs.lua')(source);source=dofile('tests/fixtures/restore_form_repairs.lua')(source);source=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')(source);source=dofile('tests/fixtures/restore_threat_repairs.lua')(source);source=dofile('tests/fixtures/restore_pet_repairs.lua')(source);source=dofile('tests/fixtures/restore_player_flag_repairs.lua')(source,{'stealthed','control'});source=dofile('tests/fixtures/restore_unit_flag_repairs.lua')(source);source=dofile('tests/fixtures/restore_retired_gui_getter.lua')(source)
    local repaired=[[    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitAttackabilityObservation, addon.Platform, value.unit)
    end,]]
    local original=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitCanAttack, "player", value.unit) and
               not Functions.cache.getCached(cache, UnitIsDead, value.unit)
    end,]]
    local start=assert(source:find(repaired,1,true),'exact repaired ATTACKABLE body missing')
    assert(not source:find(repaired,start+1,true),'approved attackability repair appears more than once')
    source=source:sub(1,start-1)..original..source:sub(start+#repaired)
    -- Frozen Conditions/combat.lua at movement checkpoint 8e3892c. Restoring
    -- only ATTACKABLE must preserve MOVING and every other byte, including UI.
    assert(a:FunctionSourceHash(source)=='e33bf6d4','combat module changed beyond the approved attackability evaluator')
    for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do
        local id='builtin:Conditions/combat.lua:'..name
        assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash,'private source identity changed: '..name)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name),'private source getter changed: '..name)
    end
    assert(not a.builtinFunctions['builtin:Conditions/combat.lua:AceGUI'] and a:ResolveFunctionBinding('builtin:Conditions/combat.lua:AceGUI')==nil)
end)
finish()
