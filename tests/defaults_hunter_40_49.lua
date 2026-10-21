-- The inherited fixture models already evidenced sample IDs only, not a40s spellbook or trainer schedule.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local inherited=assert(read('tests/defaults_hunter_30_39.lua'):match('^(.-)\ntest%('))
local changes={{'hunter-30-39.lua','hunter-40-49.lua'},{'rm.tbc.hunter.starter.30-39','rm.tbc.hunter.starter.40-49'},{'Hunter.Thirty','Hunter.Forty'},{'Hunter30–39','Hunter40–49'},{'level=30','level=40'}}
for _,pair in ipairs(changes)do local found=inherited:find(pair[1],1,true);assert(found,'inherited fixture anchor missing '..pair[1]);local from=pair[1]:gsub('([^%w])','%%%1');inherited=inherited:gsub(from,function()return pair[2]end)end
local fixture,first,optional,nativePublish,own,row,ready,body=assert(loadstring(inherited..'\nreturn fixture,first,optional,nativePublish,own,row,ready,body','@hunter-forty-native-fixture'))()
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID='rm.tbc.hunter.starter.40-49'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end

test('new source has separate40–49 identity and exactly the inherited eight-row bounded graph',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/hunter-30-39.lua');assert(a:InitializeRotationLibrary());local old=assert(a:GetDefaultRotation('rm.tbc.hunter.starter.30-39')).envelope
 local new=assert(a:GetDefaultRotation(ID)).envelope;assert(new.applicability.minLevel==40 and new.applicability.maxLevel==49 and new.applicability.class=='HUNTER')
 local b=a:CopySettingsData(new.body);local count=0;local function normalize(v)if type(v)~='table'then return end
  if v.id then assert(v.id:find('hunter-forty-',1,true)==1);v.id=v.id:gsub('hunter%-forty%-','hunter-thirty-');count=count+1 end
  for _,child in pairs(v)do normalize(child)end
 end;normalize(b);assert(count==8);b.switch.value[2].value=30;b.switch.value[3].value=40;assert(equal(b,old.body),'inherited policy changed beyond stable IDs/bounds')
 assert(new.id~=old.id and row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
end)
test('39/40/49/50 bounds use current class and level without granting talents or spells',function()
 local f,s=fixture();local a=f.addon;f.env.GetTalentTabInfo=function()error('generic subset queried talents')end
 for _,level in ipairs({39,40,49,50})do s.level=level;a.longtermCache.conditionPlayerLevel=nil
  assert(row(a).eligible==(level>=40 and level<50));assert((not not a:evaluateCondition(body(a).switch))==(level>=40 and level<50))
 end
 s.level=49;s.known={};assert(not a:evaluateCondition(body(a).switch));s.known[75]=true;s.repeatActive=true;assert(not first(a,s),'level granted a damage family')
end)
test('actual learned mapped and ready inherited family samples remain authoritative at49',function()
 local f,s,n=fixture();s.level=49;assert(first(f.addon,s)==75);s.repeatActive=true;assert(not first(f.addon,s))
 s.known[1978]=true;assert(first(f.addon,s)==1978);s.known[13551]=true;assert(first(f.addon,s)==13551)
 s.mapped[13551]=false;assert(first(f.addon,s)==1978);own(s,n,1978);s.known[3044],s.known[14283]=true,true;assert(first(f.addon,s)==14283)
 s.mapped[14283]=false;assert(first(f.addon,s)==3044);s.power[3044]=true;assert(not first(f.addon,s))
end)
test('inactive stationary Auto start is distinct from active or unknown repeat state',function()
 local f,s=fixture();assert(first(f.addon,s)==75);s.repeatActive=true;assert(not first(f.addon,s),'off toggle proposed')
 s.known[3044]=true;assert(first(f.addon,s)==3044);s.repeatError=true;local id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
end)
test('movement casts channels and exhausted priority suppress unsafe Auto or implicit melee',function()
 local f,s=fixture();s.moving=true;local id,result=first(f.addon,s);assert(not id and result.suppressAttack)
 s.known[3044]=true;assert(first(f.addon,s)==3044)
 for _,kind in ipairs({'casting','channel'})do s[kind]=true;id,result=first(f.addon,s);assert(not id and result.suppressAttack);s[kind]=false end
 s.known[3044]=false;id,result=first(f.addon,s);assert(not id and result.suppressAttack)
end)
test('own Scorpid is preserved and nil or other caster is never inferred own',function()
 local f,s,n=fixture();ready(s);own(s,n,3043);assert(first(f.addon,s)==14283)
 own(s,n,3043,'party1');assert(first(f.addon,s)==13551);s.debuffs={{spellId=3043,name=n[3043]}};assert(first(f.addon,s)==13551)
 own(s,n,13551);assert(first(f.addon,s)==14283);s.auraError=true;assert(first(f.addon,s)==14283)
end)
test('native restricted or missing readiness cannot manufacture ammo deadzone range or own Sting data',function()
 for _,kind in ipairs({'usable','range','repeat','aura'})do local f,s=fixture();ready(s);local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  if kind=='usable'then f.env.C_Spell.IsSpellUsable=function()return opaque,opaque end
  elseif kind=='range'then f.env.C_Spell.IsSpellInRange=function()return nil end
  elseif kind=='repeat'then f.env.C_Spell.IsAutoRepeatSpell=function()return opaque end
  else s.auraError=true;s.usable[3044],s.usable[14283]=false,false end
  local id,r=first(f.addon,s);assert(not id and r.suppressAttack,kind)
 end
end)
test('native cooldown resource readiness range and mapping can leave every shot unavailable',function()
 local f,s,n=fixture();ready(s);own(s,n,13551);s.cooldown[14283]={startTime=90,duration=30,isEnabled=true,modRate=1};s.power[3044]=true
 local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.power[3044]=false;assert(first(f.addon,s)==3044)
 s.range[3044]=false;assert(not first(f.addon,s));s.range[3044]=true;s.mapped[3044]=false;assert(not first(f.addon,s))
end)
test('optional Hawk respects manual Monkey Cheetah or current Hawk and native availability',function()
 local f,s,n=fixture();assert(not optional(f,s));s.known[13165],s.known[14319]=true,true;assert(optional(f,s)==14319)
 for _,id in ipairs({13163,5118,14318,14319})do s.buffs={{spellId=id,name=n[id],sourceUnit='player'}};assert(not optional(f,s))end
 s.buffs={};s.auraError=true;assert(not optional(f,s));s.auraError=false;s.usable[13165],s.usable[14319]=false,false;assert(not optional(f,s))
end)
test('target and edition class context exclusions do not broaden source applicability',function()
 for _,case in ipairs({{1,'HUNTER'},{2,'HUNTER'},{5,'MAGE'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==75)
 for _,kind in ipairs({'friendly','dead','missing'})do s.hostile=kind~='friendly';s.dead=kind=='dead';s.exists=kind~='missing';assert(not first(f.addon,s))end
end)
test('initialized main publisher transitions through Auto Sting Arcane empty and recovery without melee',function()
 local f,s,n=fixture();ready(s);s.repeatActive=false;local tick,_,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==75)
 s.repeatActive=true;tick();assert(f.addon.currentSpell==13551);own(s,n,3043);tick();assert(f.addon.currentSpell==14283)
 s.range[14283],s.range[3044]=false,false;tick();assert(f.addon.currentSpell==nil);s.range[3044]=true;tick();assert(f.addon.currentSpell==3044)
 s.casting=true;tick();assert(f.addon.currentSpell==nil);s.casting=false;s.channel=true;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603,'implicit melee escaped inherited subset')end
end)
test('initialized publisher preserves chosen aspects and refuses unknown repeat without stale output',function()
 local f,s,n=fixture();ready(s);s.known[13165],s.known[14319]=true,true;s.buffs={{spellId=5118,name=n[5118],sourceUnit='player'}};local tick=nativePublish(f,s);tick()
 assert(not f.addon.avail_announced['hunter-forty-hawk']);s.buffs={};tick();assert(f.addon.avail_announced['hunter-forty-hawk']==14319)
 s.repeatError=true;tick();assert(f.addon.currentSpell==nil);s.repeatError=false;tick();assert(f.addon.currentSpell==13551)
end)
test('four Hunter brackets remain disjoint across current level changes',function()
 local f,s=fixture();local a=f.addon;for _,path in ipairs({'hunter-starter','hunter-20-29','hunter-30-39'})do f.load('Defaults/tbc/'..path..'.lua')end;assert(a:InitializeRotationLibrary())
 for _,level in ipairs({19,20,29,30,39,40,49,50})do s.level=level;a.longtermCache.conditionPlayerLevel=nil;local wanted=level==19 and'rm.tbc.hunter.starter'or level<30 and'rm.tbc.hunter.starter.20-29'or level<40 and'rm.tbc.hunter.starter.30-39'or level<50 and ID or nil
  local found={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then found[#found+1]=r.id end end;assert(#found==(wanted and 1 or 0));if wanted then assert(found[1]==wanted)end
 end
end)
test('old saved30–39 clones survive new source adoption and fresh40–49 clones remain independent',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/hunter-30-39.lua');assert(a:InitializeRotationLibrary());s.level=39
 local old=assert(a:CloneDefaultRotation(0,'rm.tbc.hunter.starter.30-39','Old local Hunter'));local clone=a:GetEditableRotation(0,old);clone.rotation[1].onTrue[3].action=3044;local before=a:CopySettingsData(clone)
 s.level=40;assert(a:InitializeRotationLibrary());local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty local Hunter'));assert(a:GetEditableRotation(0,fresh).rotation[1].onTrue[3].action==1978);assert(equal(a:GetEditableRotation(0,old),before))
 a:GetEditableRotation(0,fresh).rotation[1].onTrue[3].action=3044;assert(body(a).rotation[1].onTrue[3].action==1978);assert(equal(a:GetEditableRotation(0,old),before))
end)
test('disabled source profile replacement vehicle and pet battle remain actual runtime boundaries',function()
 local f=fixture();local a=f.addon;assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible and not a:GetRuntimeRotation(0,row(a).runtimeKey))
 local prior=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled);a.db.profile=prior;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
 assert(a:SetDefaultRotationEnabled(ID,true));f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible)
end)
test('initialized publisher clears prior positive output outside40–49 and resumes inside',function()
 local f,s=fixture();local a=f.addon;local tick=nativePublish(f,s);a.currentRotation=row(a).runtimeKey;tick();assert(a.currentSpell==75)
 for _,level in ipairs({39,40,49,50,40})do s.level=level;a.longtermCache.conditionPlayerLevel=nil;a.currentRotation=row(a).runtimeKey;tick();assert(a.currentSpell==((level>=40 and level<50)and 75 or nil),tostring(level))end
end)
finish()
