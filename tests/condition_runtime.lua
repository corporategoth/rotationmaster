-- Actual compiler, condition callbacks, providers and event frame; no timing.
if jit then jit.off();jit.flush()end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(configure)
 local f=F.new(5,1,'SHAMAN');local a,e=f.addon,f.env;local s={level=50,combat=false,levelReads=0,timers={},frames={}}
 e.UnitExists=function(unit)return unit=='player'or unit=='target'end
 e.UnitLevel=function()s.levelReads=s.levelReads+1;return s.level end
 e.UnitAffectingCombat=function()return s.combat end;e.UnitHasVehicleUI=function()return false end
 e.UnitAura=function(_,index)if s.onAura then s.onAura(index)end;local aura=s.auras and s.auras[index];if aura then return aura.name,nil,1,nil,0,0,'player',false,nil,aura.id end end
 e.GetSpellInfo=function()if not s.missingSpell then return s.spellName or'Lightning Shield' end end
 e.GetWeaponEnchantInfo=function()return s.enchant==true end
 a.currentSpec=0;a.currentRotation='active';a.enabledState=true;a.longtermCache={}
 a.ScheduleTimer=function(_,fn,delay)s.timers[#s.timers+1]=fn;return #s.timers end
 e.CreateFrame=function()
  local x={events={},scripts={}};s.frames[#s.frames+1]=x
  function x:RegisterEvent(event)if event~=s.rejectedEvent then self.events[event]=true end;if s.onRegister then s.onRegister(event)end end
  function x:UnregisterEvent(event)self.events[event]=nil end
  function x:IsEventRegistered(event)return self.events[event]==true end
  function x:UnregisterAllEvents()self.events={}end
  function x:SetScript(event,fn)self.scripts[event]=fn end
  function x:GetScript(event)return self.scripts[event]end
  return x
 end
 s.fire=function(event,...)for _,frame in ipairs(s.frames)do if frame.events[event]and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event,...)end end end
 s.flush=function()local q=s.timers;s.timers={};for _,fn in ipairs(q)do fn()end end
 if configure then configure(f,s)end
 f.load('Platform/spells.lua');f.load('Platform/auras.lua')
 f.load('Data/builtin_sources.lua');f.load('Core/conditions.lua')
 local file=io.open('Core/condition_runtime.lua');if file then file:close();f.load('Core/condition_runtime.lua')end
 f.load('Core/level_conditions.lua');f.load('Core/aura_conditions.lua')
 if s.configureSource then s.configureSource(f,s)end
 for _,path in ipairs({'Conditions/character.lua','Conditions/combat.lua','Conditions/buffs.lua','Conditions/weapon.lua','Conditions/range.lua','Conditions/known_spell.lua'})do f.load(path)end
 local consume=a.ConsumeConditionRuntime;assert(type(consume)=='function','compiled condition registry is not installed')
 local prepare,retire,opaque=consume(a);assert(type(prepare)=='function'and type(retire)=='function'and type(opaque)=='function')
 return f,s,prepare,retire,opaque
end
local function body(root)return{rotation={{id='one',type='spell',action=403,conditions=root}},cooldowns={}}end
local function level(n)return{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function countCalls(fn,work)local n=0;debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then n=n+1 end end,'c');local ok,why=pcall(work);debug.sethook();assert(ok,why);return n end

test('active allstable subtree compiles once and reuses reached level results until notification',function()
 local f,s,prepare=fixture();local a=f.addon;local root={type='AND',value={level(40),{type='NOT',value=level(60)}}};local b=body(root);local token={}
 local native=a.conditionDefinitions.LEVEL.evaluate;local n=countCalls(native,function()
  for _=1,5 do local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='match')end
 end);assert(n==2,'stable leaves were re-evaluated '..n);s.level=60;s.fire('UNIT_LEVEL','player')
 local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='no-match')
end)
test('mixed owned volatile subtree remains fresh and ordered every poll',function()
 local f,s,prepare=fixture();local a=f.addon;local root={type='AND',value={level(40),{type='COMBAT',unit='player'}}};local b=body(root);local token={};local session=assert(prepare(a,b,token,function()return true end))
 assert(session:EvaluateResult(root).status=='no-match');s.combat=true;session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='match')
 s.combat=false;assert(session:EvaluateResult(root).status=='no-match')
end)
test('unavailable facts stay dirty and NOT does not turn unknown into permission',function()
 local f,s,prepare=fixture();local a=f.addon;local root={type='NOT',value=level(40)};local b=body(root);local token={};s.level=nil
 local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='unavailable')
 s.level=50;assert(session:EvaluateResult(root).status=='no-match')
end)
test('levelup invalidates immediately and deferred rewarm never retains old native level',function()
 local f,s,prepare=fixture();local a=f.addon;local root=level(51);local b=body(root);local token={};local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='no-match')
 s.fire('PLAYER_LEVEL_UP',51);assert(session:EvaluateResult(root).status=='no-match');s.level=51;s.flush();assert(session:EvaluateResult(root).status=='match')
end)
test('new plan token retires old root results and old session cannot authorize evaluation',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};local first=assert(prepare(a,b,token,function()return true end));assert(first:EvaluateBool(root))
 local second=assert(prepare(a,b,{},function()return true end));assert(not first:IsCurrent());assert(first:EvaluateResult(root).status=='unavailable');assert(second:EvaluateBool(root));retire(a);assert(not second:IsCurrent())
end)
test('unknown or custom callback inputs retain wholeplan compatibility and can be mutated normally',function()
 local f,s,prepare=fixture();local a=f.addon;a:RegisterCondition('CUSTOM',{valid=function()return true end,evaluate=function(v)v.changed=true;return true end})
 local node={type='CUSTOM'};assert(prepare(a,body(node),{},function()return true end)==nil)
 assert(a:evaluateCondition(node));assert(node.changed==true)
end)
test('public evaluator and provider replacements retain compatibility dispatch',function()
 local f,s,prepare=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};assert(prepare(a,b,token,function()return true end))
 local original=a.evaluateConditionResult;a.evaluateConditionResult=function()return{status='no-match'}end;assert(prepare(a,b,token,function()return true end)==nil);a.evaluateConditionResult=original
 local native=f.env.UnitLevel;f.env.UnitLevel=function()return 5 end;assert(prepare(a,b,token,function()return true end)==nil);f.env.UnitLevel=native
 assert(prepare(a,b,token,function()return true end))
end)
test('unreached invalid graph shapes fall back instead of eagerly changing short circuit outcomes',function()
 local f,s,prepare=fixture();local a=f.addon;local loop={type='NOT'};loop.value=loop;local root={type='OR',value={level(40),loop}}
 assert(prepare(a,body(root),{},function()return true end)==nil);assert(a:evaluateConditionResult(root).status=='match')
end)

local function buff()return{type='BUFF',unit='player',spell=324,anyrank=true,ownbuff=true}end
test('real Shaman player BUFF presence reuses reached fact and validator until aura or metadata notification',function()
 local f,s,prepare=fixture();local a=f.addon;s.auras={{name='Lightning Shield',id=324}}
 local root=buff();local b=body(root);local token={};local native=a.conditionDefinitions.BUFF.evaluate
 local evaluations=countCalls(native,function()for _=1,5 do assert(prepare(a,b,token,function()return true end)):EvaluateBool(root)end end)
 assert(evaluations==1,'aura evaluated '..evaluations)
 s.auras={};s.fire('UNIT_AURA','target');assert(prepare(a,b,token,function()return true end)):EvaluateBool(root)
 s.fire('UNIT_AURA','player');assert(not assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
 s.auras={{name='Lightning Shield',id=999}};s.fire('SPELL_DATA_LOAD_RESULT',324,true);assert(assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
 s.spellName='Other';s.fire('SPELLS_CHANGED');assert(not assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
end)
test('source owned volatile Shaman trees validate each reached configuration once but observe every poll',function()
 local f,s,prepare=fixture();local a=f.addon;local root={type='AND',value={{type='WEAPON'},{type='ATTACKABLE',unit='target'}}};local b=body(root);local token={}
 local valid=a.conditionDefinitions.WEAPON.valid;local evaluate=a.conditionDefinitions.WEAPON.evaluate
 local validations=countCalls(valid,function()for _=1,5 do assert(prepare(a,b,token,function()return true end)):EvaluateBool(root)end end)
 assert(validations==1,'pure validator repeated '..validations)
 local observations=countCalls(evaluate,function()for _=1,5 do assert(prepare(a,b,token,function()return true end)):EvaluateBool(root)end end)
 assert(observations==5,'volatile weapon observation skipped')
end)
test('an aura notification during native observation prevents committing old fact or ancestor',function()
 local f,s,prepare=fixture();local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root={type='NOT',value=buff()};local b=body(root);local token={};local session=assert(prepare(a,b,token,function()return true end))
 s.onAura=function()s.onAura=nil;s.fire('UNIT_AURA','player')end
 assert(not session:EvaluateBool(root));s.auras={};assert(session:EvaluateBool(root))
end)
test('unknown aura identity stays dirty and existential later match wins without promoting unknown',function()
 local f,s,prepare=fixture();local a=f.addon;s.auras={{name='Unknown'}}
 local root=buff();local session=assert(prepare(a,body(root),{},function()return true end));assert(session:EvaluateResult(root).status=='unavailable')
 s.auras[2]={name='Lightning Shield',id=324};assert(session:EvaluateBool(root))
 s.auras[2]=nil;s.fire('UNIT_AURA','player');assert(session:EvaluateResult(root).status=='unavailable')
end)
test('missing event support makes that provider fresh while source config validation still compiles',function()
 local f,s,prepare=fixture(function(_,state)state.rejectedEvent='UNIT_AURA'end);local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root=buff();local b=body(root);local token={}
 local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateBool(root));s.auras={};assert(not session:EvaluateBool(root))
end)
test('restricted policy never crosspoll caches aura facts',function()
 local f,s,prepare=fixture(function(f,state)f.env.C_Secrets={HasSecretRestrictions=function()return true end};f.env.issecretvalue=function()return false end;f.env.canaccessvalue=function()return true end end)
 local a=f.addon;local root=buff();local b=body(root);local token={};s.auras={{name='Lightning Shield',id=324}};local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateBool(root));s.auras={};assert(not session:EvaluateBool(root))
end)
test('public aura helper cannot receive private body through the compiled path',function()
 local f,s,prepare=fixture();local a=f.addon;local root=buff();local touched=false
 a.EvaluateAuraCondition=function(_,v)touched=true;v.mutated=true;return true end
 assert(prepare(a,body(root),{},function()return true end)==nil);assert(not touched);assert(a:evaluateCondition(root));assert(touched and root.mutated)
end)
test('boundary replacement of a native namespace method declines and restoration starts fresh',function()
 local f,s,prepare=fixture(function(f,state)f.env.C_UnitAuras={GetAuraDataByIndex=function()return state.rawAura end}end);local a=f.addon
 s.rawAura={name='Lightning Shield',spellId=324,sourceUnit='player'};local root=buff();local b=body(root);local token={};assert(assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
 local old=f.env.C_UnitAuras.GetAuraDataByIndex;f.env.C_UnitAuras.GetAuraDataByIndex=function()return nil end;assert(prepare(a,b,token,function()return true end)==nil)
 f.env.C_UnitAuras.GetAuraDataByIndex=old;s.rawAura=nil;assert(not assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
end)
test('lease expiry and retirement unsubscribe without authorizing stale callbacks',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=level(40);local alive=true;local session=assert(prepare(a,body(root),{},function()return alive end));assert(session:EvaluateBool(root));alive=false;assert(session:EvaluateResult(root).status=='unavailable');retire(a)
 for _,frame in ipairs(s.frames)do assert(next(frame.events)==nil and frame.scripts.OnEvent==nil)end
end)
test('structural compilation preserves empty, disabled, ordered OR and NOT public truth',function()
 local f,s,prepare=fixture();local a=f.addon
 for _,root in ipairs({{type='AND',value={}},{type='OR',value={}},{type='NOT',value={type='OR'}},{type='COMBAT',unit='player',disabled=true},{type='OR',value={level(40),{type='COMBAT',unit='player'}}}})do
  local expected=a:evaluateConditionResult(root);local session=assert(prepare(a,body(root),{},function()return true end));assert(session:EvaluateResult(root).status==expected.status)
 end
end)
test('sparse and overdeep skipped trees retain public compatibility instead of eager failure',function()
 local f,s,prepare=fixture();local a=f.addon;local deep=level(40);for _=1,66 do deep={type='NOT',value=deep}end
 for _,bad in ipairs({{type='AND',value={[2]=level(40)}},deep,{type='OR',value=false}})do
  local root={type='OR',value={level(40),bad}};assert(prepare(a,body(root),{},function()return true end)==nil);assert(a:evaluateConditionResult(root).status=='match')
 end
end)
test('actual shipped Shaman idle action and cooldown trees compile without LEVEL and cache only player aura',function()
 local f,s,prepare=fixture(function(f,state)f.env.UnitExists=function(unit)return unit=='player'end end);local a=f.addon;local pack
 a.RegisterDefaultRotation=function(_,value)pack=value;return true end;f.load('Defaults/tbc/shaman-starter.lua');local b=assert(pack).body;local token={}
 local validCalls,auraCalls=0,0
 local watched={};for _,tag in ipairs({'COMBAT','ATTACKABLE','WEAPON','BUFF'})do watched[a.conditionDefinitions[tag].valid]=true end
 local aura=a.conditionDefinitions.BUFF.evaluate
 debug.sethook(function(event)if event=='call'then local fn=debug.getinfo(2,'f').func;if watched[fn]then validCalls=validCalls+1 end;if fn==aura then auraCalls=auraCalls+1 end end end,'c')
 local ok,reason=pcall(function()
  for _=1,5 do
   local session=assert(prepare(a,b,token,function()return true end))
   assert(not session:EvaluateBool(b.rotation[1].conditions));assert(session:EvaluateBool(b.rotation[2].conditions))
   for _,step in ipairs(b.cooldowns)do assert(session:EvaluateBool(step.conditions))end
  end
 end);debug.sethook();assert(ok,reason)
 assert(validCalls==5,'expected first reached validations only, got '..validCalls);assert(auraCalls==1,'BUFF did not reuse notification fact')
 s.fire('UNIT_AURA','player');s.auras={{name='Lightning Shield',id=324}};local session=assert(prepare(a,b,token,function()return true end));assert(not session:EvaluateBool(b.cooldowns[2].conditions))
end)
test('diagnostic override declines before private callback invocation and keeps the ordinary error boundary',function()
 local diagnostics={Call=function(_,_,run)return pcall(run)end,ObserveReportedErrors=function()end}
 local f,s,prepare=fixture(function(f)f.addon.Diagnostics=diagnostics end);local a=f.addon;local root={type='WEAPON'};local b=body(root);local token={};assert(prepare(a,b,token,function()return true end))
 local old=diagnostics.Call;diagnostics.Call=function(_,_,run)return pcall(run)end;assert(prepare(a,b,token,function()return true end)==nil);diagnostics.Call=old
 assert(prepare(a,b,token,function()return true end));diagnostics.ObserveReportedErrors=function()end;assert(prepare(a,b,token,function()return true end)==nil)
end)
test('changing condition authority during a callback expires the lease before the next private leaf',function()
 local alive=true;local seen=0
 local f,s,prepare=fixture(function(f)f.env.GetWeaponEnchantInfo=function()alive=false;return true end end);local a=f.addon
 local root={type='AND',value={{type='WEAPON'},{type='COMBAT',unit='player'}}};local session=assert(prepare(a,body(root),{},function()return alive end))
 local calls=countCalls(a.conditionDefinitions.COMBAT.evaluate,function()assert(session:EvaluateResult(root).status=='unavailable')end);assert(calls==0)
end)
test('failed frame creation cannot silently enable crosspoll provider reuse',function()
 local f,s,prepare=fixture(function(f)f.env.CreateFrame=function()error('not available')end end);local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root=buff();local session=assert(prepare(a,body(root),{},function()return true end));assert(session:EvaluateBool(root));s.auras={};assert(not session:EvaluateBool(root))
end)
test('old opaque continuation cannot invalidate a newer active graph or nested lease',function()
 local f,s,prepare,retire,opaque=fixture();local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root=buff();local b=body(root);local token={};local outerAlive=true
 local outer=assert(prepare(a,b,token,function()return outerAlive end));assert(outer:EvaluateBool(root));outerAlive=false
 local nested=assert(prepare(a,b,token,function()return true end));assert(nested:EvaluateBool(root));s.auras={}
 assert(not outer:AfterOpaque());assert(not opaque(a,outer));assert(nested:EvaluateBool(root),'stale continuation dirtied nested fact')
 assert(nested:AfterOpaque());assert(nested:EvaluateBool(root),'unchanged publisher dirtied fact');s.fire('UNIT_AURA','player');assert(not nested:EvaluateBool(root))
end)
test('security policy transition and world changes retire stable observations conservatively',function()
 local restricted=false
 local f,s,prepare=fixture(function(f)f.env.C_Secrets={HasSecretRestrictions=function()return restricted end};f.env.issecretvalue=function()return false end;f.env.canaccessvalue=function()return true end end);local a=f.addon;local root=buff();local b=body(root);local token={};s.auras={{name='Lightning Shield',id=324}};local first=assert(prepare(a,b,token,function()return true end));assert(first:EvaluateBool(root))
 s.auras={};restricted=true;local second=assert(prepare(a,b,token,function()return true end));assert(not first:IsCurrent());assert(not second:EvaluateBool(root));s.auras={{name='Lightning Shield',id=324}};assert(second:EvaluateBool(root))
 restricted=false;local third=assert(prepare(a,b,token,function()return true end));assert(third:EvaluateBool(root));s.auras={};s.fire('PLAYER_ENTERING_WORLD');assert(not third:EvaluateBool(root))
end)
test('unchanged primitive publication heartbeats preserve notification cache across polls',function()
 local f,s,prepare=fixture();local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root=buff();local b=body(root);local token={};local beats=0
 local callbacks={function(id)assert(id==324);beats=beats+1 end,function(id)assert(id==324);beats=beats+1 end}
 local reads=countCalls(a.conditionDefinitions.BUFF.evaluate,function()
  for _=1,5 do local session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateBool(root));for _,notify in ipairs(callbacks)do notify(324);assert(session:AfterOpaque())end end
 end);assert(beats==10 and reads==1,'publication defeated notification reuse')
end)
test('runtime diagnostic is a detached scalar count snapshot including actual reuse and fallback',function()
 local f,s,prepare=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};local before=a:GetConditionRuntimeDiagnostic();assert(not before.active)
 for _=1,3 do assert(assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))end
 local after=a:GetConditionRuntimeDiagnostic();assert(after.compiles-before.compiles==1 and after.validatorCalls-before.validatorCalls==1 and after.leafEvaluations-before.leafEvaluations==1 and after.stableHits-before.stableHits==2 and after.active)
 for _,value in pairs(after)do assert(type(value)=='number'or type(value)=='boolean')end
 after.compiles=999;assert(a:GetConditionRuntimeDiagnostic().compiles~=999)
 assert(prepare(a,body({type='CUSTOM'}),{},function()return true end)==nil);assert(a:GetConditionRuntimeDiagnostic().legacyFallback==before.legacyFallback+1)
end)
test('capability callback reentry cannot let an old Prepare retire the newer activation',function()
 local f,s,prepare=fixture(function(f,state)f.env.C_Secrets={HasSecretRestrictions=function()if state.duringSecurity then state.duringSecurity()end;return false end};f.env.issecretvalue=function()return false end;f.env.canaccessvalue=function()return true end end)
 local a=f.addon;local root=buff();local b=body(root);local oldToken={};local outerAlive=true;local first=assert(prepare(a,b,oldToken,function()return outerAlive end));local nested
 s.duringSecurity=function()s.duringSecurity=nil;outerAlive=false;nested=assert(prepare(a,b,{},function()return true end))end
 assert(prepare(a,b,oldToken,function()return outerAlive end)==nil);assert(nested:IsCurrent());assert(not first:IsCurrent())
end)
test('event-registration reentry cleans only the old owned frame and preserves the newer graph',function()
 local f,s,prepare=fixture();local a=f.addon;local root=level(40);local b=body(root);local alive=true;local nested
 s.onRegister=function()s.onRegister=nil;alive=false;nested=assert(prepare(a,b,{},function()return true end))end
 assert(prepare(a,b,{},function()return alive end)==nil);assert(nested:IsCurrent());assert(next(s.frames[1].events)==nil and s.frames[1].scripts.OnEvent==nil);assert(nested:EvaluateBool(root))
end)
test('namespace accessors decline before executing getters during authority checks',function()
 local f,s,prepare=fixture(function(f,state)f.env.C_UnitAuras={GetAuraDataByIndex=function()return state.rawAura end}end);local a=f.addon;s.rawAura={name='Lightning Shield',spellId=324,sourceUnit='player'};local root=buff();local b=body(root);local token={};assert(assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
 local native=f.env.C_UnitAuras.GetAuraDataByIndex;f.env.C_UnitAuras.GetAuraDataByIndex=nil;local reads=0
 setmetatable(f.env.C_UnitAuras,{__index=function()reads=reads+1;s.rawAura=nil;return native end})
 assert(prepare(a,b,token,function()return true end)==nil and reads==0,'authority executed a provider accessor')
 assert(a:evaluateCondition(root)==false and reads>0,'public getter route did not remain available')
end)
test('literal callback witness rejects a registration wrapper even when it restores the public registration method',function()
 for _,stage in ipairs({'valid','evaluate'})do
  local calls=0
  local f,s,prepare=fixture(function(_,state)state.configureSource=function(f)
   local a=f.addon;local original=a.RegisterCondition
   a.RegisterCondition=function(self,tag,definition)
    if tag=='BUFF'then
     local callback=definition[stage];definition[stage]=function(...)calls=calls+1;return callback(...)end
     self.RegisterCondition=original
    end
    return original(self,tag,definition)
   end
  end end)
  local root=buff();assert(prepare(f.addon,body(root),{},function()return true end)==nil and calls==0);f.addon:evaluateCondition(root);assert(calls==1)
 end
end)
test('real callback quarantine and explicit reset retire and recover a previously clean fact',function()
 local f,s,prepare=fixture(function(f)f.load('Diagnostics/errors.lua')end);local a=f.addon;local root=level(40);local b=body(root);local token={};local first=assert(prepare(a,b,token,function()return true end));assert(first:EvaluateBool(root))
 local bad=level('not numeric');assert(a:evaluateConditionResult(bad).status=='unavailable');assert(a:evaluateConditionResult(root).status=='unavailable')
 assert(not first:IsCurrent()and first:EvaluateResult(root).status=='unavailable');assert(prepare(a,b,token,function()return true end)==nil)
 a:ResetConditionQuarantine(a.conditionDefinitions.LEVEL);local recovered=assert(prepare(a,b,token,function()return true end));assert(recovered:EvaluateBool(root))
end)
test('legacy cleanup retires the latest expired poll but never a newer nested session',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};local alive=true;local prior=assert(prepare(a,b,token,function()return alive end));assert(prior:EvaluateBool(root));alive=false
 assert(retire(a,prior));assert(not prior:IsCurrent());for _,frame in ipairs(s.frames)do assert(next(frame.events)==nil)end
 local outer=assert(prepare(a,b,token,function()return true end));local nested=assert(prepare(a,b,token,function()return true end));assert(not retire(a,outer));assert(not retire(a,false));assert(nested:IsCurrent());assert(retire(a,nested));assert(retire(a,false))
end)
test('retirement is idempotent after an opaque boundary already retired the old graph',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=buff();local session=assert(prepare(a,body(root),{},function()return true end));a.EvaluateAuraCondition=function()return false end
 assert(not session:AfterOpaque());assert(retire(a,session));assert(retire(a,session));assert(retire(a,false));assert(not retire({},session))
end)
test('cheap root and cache fences retain full authority only at actual callback and opaque boundaries',function()
 local f,s,prepare=fixture();local a=f.addon;local root=level(40);local full=0
 local session=assert(prepare(a,body(root),{},function()return true end,function()full=full+1;return true end));local before=full
 assert(session:EvaluateBool(root));assert(full-before==2,'validator/evaluator full boundary was lost or repeated '..(full-before))
 before=full;assert(session:EvaluateBool(root));assert(full==before,'cached fact called full authority')
 assert(session:AfterOpaque());assert(full==before+1,'environment boundary lost full authority')
end)
test('a failed full postcallback fence cannot be replaced by a live cheap lease',function()
 local allowed=true
 local f,s,prepare=fixture(function(f)f.env.GetWeaponEnchantInfo=function()allowed=false;return true end end)
 local root={type='WEAPON'};local b=body(root);local later={type='COMBAT',unit='player'};b.cooldowns={{conditions=later}}
 local session=assert(prepare(f.addon,b,{},function()return true end,function()return allowed end))
 assert(session:EvaluateResult(root).status=='unavailable','raw authority change survived actual provider callback')
 local calls=countCalls(f.addon.conditionDefinitions.COMBAT.evaluate,function()assert(session:EvaluateResult(later).status=='unavailable')end)
 assert(calls==0 and not session:IsCurrent(),'rejected session ran a later independent root')
end)
test('cached fact checks its provider before returning without another Prepare',function()
 local f,s,prepare=fixture();local a=f.addon;s.auras={{name='Lightning Shield',id=324}};local root=buff()
 local session=assert(prepare(a,body(root),{},function()return true end));assert(session:EvaluateBool(root));local called=false
 a.EvaluateAuraCondition=function(_,value)called=true;value.ESCAPED=true;return true end
 assert(session:EvaluateResult(root).status=='unavailable','cached fact survived public provider replacement')
 assert(not called and not root.ESCAPED,'private input escaped through replaced helper')
end)
test('cached parent certifies only its consulted short circuit providers',function()
 local f,s,prepare=fixture();local a=f.addon;local root={type='OR',value={level(40),buff()}};local called=false
 local session=assert(prepare(a,body(root),{},function()return true end));assert(session:EvaluateBool(root))
 a.EvaluateAuraCondition=function()called=true;return false end
 assert(session:EvaluateBool(root),'unreached provider replacement invalidated an independent cached branch');assert(not called)
end)
test('actual Diagnostics observer cannot replace helper between source proof and private dispatch',function()
 local f,s,prepare=fixture(function(f,state)
  local handler=function()end
  f.env.geterrorhandler=function()if state.observe then state.observe()end;return handler end
  f.env.seterrorhandler=function(value)handler=value end
  f.load('Diagnostics/errors.lua')
 end)
 local a=f.addon;local root=buff();local session=assert(prepare(a,body(root),{},function()return true end));local observations=0;local called=false
 s.observe=function()
  observations=observations+1
  if observations==2 then s.observe=nil;a.EvaluateAuraCondition=function(_,value)called=true;value.ESCAPED=true;return true end end
 end
 assert(session:EvaluateResult(root).status=='unavailable','observer replacement reached private callback')
 assert(not called and not root.ESCAPED,'Diagnostics observer exposed private input')
end)
test('Prepare full rejection cannot publish an uncleanable latest session',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};local allowed=true
 local first=assert(prepare(a,b,token,function()return true end,function()return allowed end));assert(first:EvaluateBool(root))
 allowed=false;assert(prepare(a,b,token,function()return true end,function()return allowed end)==nil)
 assert(retire(a,first),'failed Prepare left a newer cleanup identity');assert(retire(a,false))
end)
test('Prepare full callback reentry never retires the newer graph',function()
 local f,s,prepare,retire=fixture();local a=f.addon;local root=level(40);local b=body(root);local token={};local alive=true;local nested
 local function full()
  alive=false;nested=assert(prepare(a,b,{},function()return true end));return false
 end
 assert(prepare(a,b,token,function()return alive end,full)==nil)
 assert(nested and nested:IsCurrent()and nested:EvaluateBool(root));assert(not retire(a,false))
end)
for _,name in ipairs({'Call','ObserveReportedErrors'})do
 test('same Diagnostic '..name..' function with a changed environment cannot certify cached private input',function()
  local f,s,prepare=fixture(function(f)f.load('Diagnostics/errors.lua')end);local a=f.addon;local root={type='NOT',value=buff()};local b=body(root);local token={}
  assert(assert(prepare(a,b,token,function()return true end)):EvaluateBool(root))
  local fn=a.Diagnostics[name];local environment=getfenv(fn);local calls=0;local replacement
  if name=='Call'then
   local original=environment.select or select;replacement=setmetatable({select=function(...)calls=calls+1;return original(...)end},{__index=environment})
  else
   local original=environment.type or type;replacement=setmetatable({type=function(...)calls=calls+1;return original(...)end},{__index=environment})
  end
  setfenv(fn,replacement);assert(a.Diagnostics[name]==fn)
  local session=prepare(a,b,token,function()return true end);local hooks=calls
  assert(a:evaluateCondition(root)and calls>hooks,'ordinary Diagnostic environment was not exercised')
  assert(session==nil,'changed Diagnostic environment retained cached private admission')
 end)
end
finish()
