-- Actual packaged condition callbacks and graph compiler; no timing/native claim.
if jit then jit.off();jit.flush()end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local prefix=assert(read('tests/condition_runtime.lua'):match('^(.-)\ntest%('))
local baseFixture,countCalls=assert(loadstring(prefix..'\nreturn fixture,countCalls','@condition-runtime-coverage-fixture'))()
local modules={'Conditions/debuffs.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/spell.lua'}
local function fixture(configure)
 local f,s,prepare=baseFixture(configure);local a=f.addon
 for _,path in ipairs(modules)do f.load(path)end
 return f,s,prepare
end
local function body(roots)local rows={};for i,root in ipairs(roots)do rows[i]={id='step'..i,type='spell',action=403,conditions=root}end;return{rotation=rows,cooldowns={}}end
local function roots()return{
 {type='DEBUFF',unit='player',spell=324},
 {type='CASTING',unit='player'},
 {type='CHANNELING',unit='player'},
 {type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},
 {type='SPELL_ACTIVE',spell=403,ranked=false},
 {type='SPELL_AUTOREPEAT',spell=75,ranked=false},
 {type='POINT',unit='player',operator='GREATERTHAN',value=1},
 {type='FORM',value=0},
 {type='STEALTHED'},
}end
local function nativeModel(f,s)
 local a=f.addon;s.cast=false;s.channel=false;s.health=25;s.point=0;s.form=0;s.stealth=false;s.current=false;s.autorepeat=false;s.spellValid=true;s.validCalls=0
 a.Platform.GetUnitCastObservation=function(_,unit,mode)assert(type(unit)=='string');return{active=mode=='cast'and s.cast or s.channel}end
 a.Platform.GetUnitHealthObservation=function(_,unit)assert(type(unit)=='string');return{exists=true,current=s.health,maximum=100}end
 a.IsConditionSpellID=function(id)s.validCalls=s.validCalls+1;return s.spellValid and type(id)=='number'and id>0 end
 a.Widget_GetSpellId=function(_,id)return id end
 a.Platform.IsCurrentSpell=function(_,id)assert(type(id)=='number');return s.current end
 a.Platform.IsAutoRepeatActive=function(_,id)assert(type(id)=='number');return s.autorepeat end
 a.GetConditionPointResourceV2=function(_,unit)assert(type(unit)=='string');return 0,nil,'unit-power' end
 a.Platform.GetUnitPointPowerObservation=function(_,unit)assert(type(unit)=='string');return s.point end
 a.Platform.GetPlayerFormObservation=function()return s.form end
 a.Platform.GetPlayerFlagObservation=function(_,kind)assert(kind=='stealthed');return s.stealth end
end
test('all nine high-frequency packaged volatile tags admit one mixed graph',function()
 local f,s,prepare=fixture();nativeModel(f,s);local a=f.addon;local list=roots();local session=assert(prepare(a,body(list),{},function()return true end),'new packaged tags rejected whole graph')
 for _,root in ipairs(list)do assert(session:EvaluateResult(root).status~='unavailable',root.type..' unavailable')end
 assert(a:GetConditionRuntimeDiagnostic().legacyFallback==0)
end)
test('volatile state changes remain fresh without any notification event',function()
 local f,s,prepare=fixture();nativeModel(f,s);local a=f.addon;local list=roots();local b=body(list);local token={};local session=assert(prepare(a,b,token,function()return true end))
 local expected={'no-match','no-match','no-match','match','no-match','no-match','no-match','match','no-match'}
 for i,root in ipairs(list)do assert(session:EvaluateResult(root).status==expected[i],root.type)end
 s.auras={{id=324,name='Lightning Shield'}};s.cast=true;s.channel=true;s.health=75;s.current=true;s.autorepeat=true;s.point=3;s.form=1;s.stealth=true
 session=assert(prepare(a,b,token,function()return true end))
 for i,root in ipairs(list)do assert(session:EvaluateResult(root).status~='unavailable',root.type);assert(session:EvaluateResult(root).status~=expected[i],root.type..' stale without event')end
 assert(a:GetConditionRuntimeDiagnostic().stableHits==0,'new volatile facts were cached')
end)
test('public-dependent spell validators stay live instead of being cached as structural',function()
 local f,s,prepare=fixture();nativeModel(f,s);local a=f.addon;local root=roots()[5];local b=body({root});local token={};local session=assert(prepare(a,b,token,function()return true end))
 assert(session:EvaluateResult(root).status=='no-match');assert(s.validCalls==1)
 s.spellValid=false;session=assert(prepare(a,b,token,function()return true end));assert(session:EvaluateResult(root).status=='unavailable'and s.validCalls==2,'public validation dependency was cached')
end)
test('configuration-only validators are amortized while reached volatile evaluators still run',function()
 local f,s,prepare=fixture();nativeModel(f,s);local a=f.addon;local list=roots();local b=body(list);local token={}
 for _,index in ipairs({1,2,3,4,7,9})do
  local root=list[index];local definition=a.conditionDefinitions[root.type]
  local n=countCalls(definition.valid,function()for i=1,3 do local session=assert(prepare(a,b,token,function()return true end));session:EvaluateResult(root)end end)
  assert(n==1,root.type..' validator calls='..n)
  n=countCalls(definition.evaluate,function()for i=1,3 do local session=assert(prepare(a,b,token,function()return true end));session:EvaluateResult(root)end end)
  assert(n==3,root.type..' volatile evaluator calls='..n)
 end
end)
test('form validator remains sensitive to native available-form changes',function()
 local f,s,prepare=fixture(function(f,s)s.forms=1;f.env.UnitClass=function()return'Druid','DRUID'end;f.env.GetNumShapeshiftForms=function()return s.forms end end)
 nativeModel(f,s);local a=f.addon;local root={type='FORM',value=1};local b=body({root});local token={};s.form=1
 assert(assert(prepare(a,b,token,function()return true end)):EvaluateResult(root).status=='match')
 s.forms=0;assert(assert(prepare(a,b,token,function()return true end)):EvaluateResult(root).status=='unavailable','native-dependent FORM validation was cached')
end)
test('replacing the whole-node aura helper declines before private inputs escape',function()
 local f,_,prepare=fixture();local a=f.addon;local root=roots()[1];local b=body({root});local token={};assert(prepare(a,b,token,function()return true end))
 local calls=0;a.EvaluateAuraCondition=function(_,value)calls=calls+1;value.borrowed=true;return true end
 assert(prepare(a,b,token,function()return true end)==nil and calls==0 and root.borrowed==nil)
 assert(a:evaluateConditionResult(root).status=='match'and calls==1 and root.borrowed,'compatibility callback lost mutable public input')
end)
test('registration wrappers cannot certify modified literal callbacks as stock conditions',function()
 local f,_,prepare=fixture(function(f,s)s.configureSource=function()
  local a=f.addon;local original=a.RegisterCondition
  a.RegisterCondition=function(self,tag,definition)if tag=='DEBUFF'then definition.valid=function(_,v)v.wrapper=true;return true end end;return original(self,tag,definition)end
 end end)
 local a=f.addon;local root=roots()[1];assert(prepare(a,body({root}),{},function()return true end)==nil,'modified literal callback enrolled')
 a:evaluateConditionResult(root);assert(root.wrapper,'ordinary wrapped validator did not execute')
end)
test('custom replacements retain complete compatibility dispatch and mutable inputs',function()
 local f,_,prepare=fixture();local a=f.addon;local root=roots()[2]
 a:RegisterCondition('CASTING',{valid=function()return true end,evaluate=function(value)value.changed=true;return true end})
 assert(prepare(a,body({root}),{},function()return true end)==nil);assert(a:evaluateConditionResult(root).status=='match'and root.changed)
end)
test('every existing TBC pack action and cooldown graph compiles without changing pack data',function()
 local f,_,prepare=fixture();local a=f.addon;local loaded={}
 -- Built In composition: compile the expanded graphs registration actually consumes.
 for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Core/rotation_library.lua'})do f.load(path)end
 a.RegisterDefaultRotation=function(_,envelope)loaded[#loaded+1]=assert(a:ExpandDefaultRotation(envelope));return true end
 for path in io.lines('RotationMaster.toc')do if path:match('^Defaults/.*%.lua$')then f.load(path)end end
 local census=36
 census=census+21 -- WoW Forever Druid/Hunter/Mage/Paladin/Priest premades
 assert(#loaded==census,'pack census changed: '..#loaded)
 -- The Forever premades read conditions the compiled runtime does not declare (MANAPCT,
 -- THREAT_COUNT, ISSAME, CLASSIFICATION...), so they run on the legacy evaluator.
 local legacy=0
 for _,envelope in ipairs(loaded)do
  if envelope.id:match('^rm%.forever%.')then
   assert(prepare(a,envelope.body,{},function()return true end)==nil,envelope.id..' unexpectedly compiled');legacy=legacy+1
  else assert(prepare(a,envelope.body,{},function()return true end),envelope.id..' rejected compiler')end
 end
 assert(legacy==21)
 assert(a:GetConditionRuntimeDiagnostic().compiles==census-legacy and a:GetConditionRuntimeDiagnostic().legacyFallback==legacy)
end)
finish()
