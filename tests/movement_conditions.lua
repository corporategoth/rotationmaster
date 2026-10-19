local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local originalBody='\n        return (Functions.cache.getCached(cache, GetUnitSpeed, "player") ~= 0)\n    '
local repairedBody='\n        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetPlayerMovementObservation,addon.Platform)\n        if not record then return nil,reason end\n        return record.speed~=0\n    '
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env;local s={speed=0,calls=0}
    e.GetUnitSpeed=function(...) assert(select('#',...)==1 and (...)=='player');s.calls=s.calls+1;if s.throw then error('native failed') end;return s.speed end
    e.UnitExists=function() error('MOVING invented an existence dependency') end
    local file=io.open('Platform/player_movement.lua');if file then file:close();f.load('Platform/player_movement.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function unknown(a,tag)
    local v={type=tag or 'MOVING'}
    for _,node in ipairs({v,{type='NOT',value=v},{type='NOT',value={type='NOT',value=v}},{type='AND',value={v}},{type='OR',value={v}}}) do assert(a:evaluateConditionResult(node).status=='unavailable',v.type..' unavailable speed became known') end
    local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(node) return a:evaluateConditionResult(node) end,function() error('unavailable movement emitted branch') end).status=='unavailable')
end
local function clone(a)
    local source=assert(a:GetBuiltinConditionSource('MOVING'));assert(source.evaluate==repairedBody,'movement source catalog is stale')
    a:RegisterCondition('COPY_MOVING',assert(a:CompileCustomCondition('COPY_MOVING',source)))
end
test('missing failed nil secret and malformed movement stay unavailable through the actual Boolean and branch engine',function()
    for _,mode in ipairs({'missing','throw','nil','secret','negative','nan','infinite','string','boolean'}) do local f,a,s=fixture();local secret={};f.env.canaccessvalue=function(v) return not rawequal(v,secret) end
        if mode=='missing' then f.env.GetUnitSpeed=nil elseif mode=='throw' then s.throw=true elseif mode=='nil' then s.speed=nil elseif mode=='secret' then s.speed=secret elseif mode=='negative' then s.speed=-1 elseif mode=='nan' then s.speed=0/0 elseif mode=='infinite' then s.speed=math.huge elseif mode=='string' then s.speed='0' else s.speed=false end
        unknown(a)
    end
end)
test('stationary and fractional movement preserve positive negative and branch meanings',function()
    local _,a,s=fixture()
    for _,case in ipairs({{0,'no-match','match','no'},{.125,'match','no-match','yes'},{7,'match','no-match','yes'}}) do s.speed=case[1];local v={type='MOVING'}
        assert(a:evaluateConditionResult(v).status==case[2] and a:evaluateConditionResult({type='NOT',value=v}).status==case[3]);assert(a:evaluateConditionResult({type='NOT',value={type='NOT',value=v}}).status==case[2])
        local emitted;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        assert(a:EvaluateRotationSequence(body,function(node) return a:evaluateConditionResult(node) end,function(node) emitted=node.id end).status=='complete' and emitted==case[4])
    end
end)
test('whole observations and unavailable tuples cache only within a pass and recover on fresh passes',function()
    local _,a,s=fixture();local cache={};s.speed=nil
    local value,why=a.conditionDefinitions.MOVING.evaluate({},cache);assert(value==nil and why=='movement-data-unavailable');s.speed=1
    value,why=a.conditionDefinitions.MOVING.evaluate({},cache);assert(value==nil and why=='movement-data-unavailable' and s.calls==1)
    assert(a.conditionDefinitions.MOVING.evaluate({},{})==true and s.calls==2)
    local rawBefore=s.calls;assert(a:evaluateConditionResult({type='AND',value={{type='MOVING'},{type='MOVING'}}}).status=='match' and s.calls==rawBefore+1)
    s.speed=0;assert(a:evaluateConditionResult({type='MOVING'}).status=='no-match' and s.calls==rawBefore+2)
end)
test('restricted and unknown client policies stay unavailable without observing speed',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);unknown(a);assert(s.calls==0) end
end)
test('fresh editable condition copies use normalized movement while saved raw callback behavior remains executable',function()
    local _,a,s=fixture();clone(a);s.speed=nil;unknown(a,'COPY_MOVING')
    s.speed=.5;assert(a:evaluateConditionResult({type='COPY_MOVING'}).status=='match');s.speed=0;assert(a:evaluateConditionResult({type='COPY_MOVING'}).status=='no-match')
    local source=a:GetBuiltinConditionSource('MOVING');source.evaluate='return addon.getCached(cache,GetUnitSpeed,"player")~=0';source.bindings['Functions.cache.getCached']=nil
    a:RegisterCondition('SAVED_RAW_MOVING',assert(a:CompileCustomCondition('SAVED_RAW_MOVING',source)));s.speed=nil
    assert(a:evaluateConditionResult({type='SAVED_RAW_MOVING'}).status=='match','saved raw source was silently changed');unknown(a)
end)
test('public observer source clones preserve the native boundary and actual helper identity',function()
    local f,a,s=fixture();local id='builtin:Platform/player_movement.lua:Platform_GetPlayerMovementObservation';local record=assert(a.builtinFunctions[id],'movement public helper metadata missing')
    assert(record.source.args[1].type=='RMPlatform' and #record.source.args==1 and record.source.description~='')
    assert(a:InstallCustomFunction('COPY_MOVEMENT_OBSERVER',record.source));local fn=assert(a:ResolveFunctionBinding('COPY_MOVEMENT_OBSERVER'));s.speed=.25;assert(fn(a.Platform).speed==.25)
    local secret={};f.env.issecretvalue=function(v) return rawequal(v,secret) end;s.speed=secret;local r,why=fn(a.Platform);assert(r==nil and why=='restricted-value')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetPlayerMovementObservation and a.builtinSourceModules['Platform/player_movement.lua']('Platform_GetPlayerMovementObservation')==a.Platform.GetPlayerMovementObservation)
end)
test('only the explicit MOVING evaluator changes while all original module bytes and private values retain their identities',function()
    local f,a=fixture();local file=assert(io.open('Conditions/combat.lua'));local source=file:read('*a');file:close();source=dofile('tests/fixtures/restore_combat_time_repairs.lua')(source);source=dofile('tests/fixtures/restore_form_repairs.lua')(source);source=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')(source);source=dofile('tests/fixtures/restore_threat_repairs.lua')(source);source=dofile('tests/fixtures/restore_pet_repairs.lua')(source);source=dofile('tests/fixtures/restore_player_flag_repairs.lua')(source,{'stealthed','control'});source=dofile('tests/fixtures/restore_unit_flag_repairs.lua')(source);source=dofile('tests/fixtures/restore_retired_gui_getter.lua')(source)
    local start=assert(source:find(repairedBody,1,true),'repaired MOVING body missing');assert(not source:find(repairedBody,start+1,true),'movement repair changed multiple bodies')
    source=source:sub(1,start-1)..originalBody..source:sub(start+#repairedBody)
    -- The separate attackability suite pins its whole-file inverse against the
    -- movement checkpoint. Restore only that exact approved evaluator here.
    local attackBody='\n        return Functions.cache.getCached(cache, addon.Platform.GetUnitAttackabilityObservation, addon.Platform, value.unit)\n    '
    local attackStart=assert(source:find(attackBody,1,true),'approved ATTACKABLE repair missing')
    assert(not source:find(attackBody,attackStart+1,true),'attackability repair changed multiple bodies')
    local rawAttack='\n        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end\n        return Functions.cache.getCached(cache, UnitCanAttack, "player", value.unit) and\n               not Functions.cache.getCached(cache, UnitIsDead, value.unit)\n    '
    source=source:sub(1,attackStart-1)..rawAttack..source:sub(attackStart+#attackBody)
    assert(a:FunctionSourceHash(source)=='2d740cba','combat module changed beyond the approved movement and attackability repairs')
    for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name)) end
    assert(not a.builtinFunctions['builtin:Conditions/combat.lua:AceGUI'] and a:ResolveFunctionBinding('builtin:Conditions/combat.lua:AceGUI')==nil)
end)
finish()
