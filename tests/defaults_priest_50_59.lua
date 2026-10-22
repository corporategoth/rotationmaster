-- Literal50–59 continuation: real registrar/sequence/readiness/initialized publisher.
-- Inherited rank samples are not a50s trainer schedule, complete build or native acceptance.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.priest.shadow.50-59','rm.tbc.priest.shadow.40-49'
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function replace(s,old,new)local out,at,count={},1,0;while true do local a,b=s:find(old,at,true);if not a then out[#out+1]=s:sub(at);break end;out[#out+1]=s:sub(at,a-1)..new;at=b+1;count=count+1 end;assert(count>0,'missing fixture anchor '..old);return table.concat(out)end
local function once(s,old,new)local a,b=assert(s:find(old,1,true));assert(not s:find(old,b+1,true));return s:sub(1,a-1)..new..s:sub(b+1)end
local inherited=assert(read('tests/defaults_priest_30_39.lua'):match('^(.-)\ntest%('))
for _,pair in ipairs({{'priest-30-39.lua','priest-50-59.lua'},{'rm.tbc.priest.shadow.30-39',ID},{'Priest.Shadow30','Priest.Shadow50'},{'30–39','50–59'},{'level=30','level=50'}})do inherited=replace(inherited,pair[1],pair[2])end
local baseFixture,row,body,first,optional,nativePublish,pain,entered=assert(loadstring(inherited..'\nreturn fixture,row,body,first,optional,nativePublish,pain,entered','@priest-fifty-pipeline'))()
-- The older fixture predates init.lua's cold unit-state installer; load the real
-- dependency here, without changing the historical fixture or its existing tests.
local function fixture(...)local f,s,n=baseFixture(...);f.load('Core/unit_state_conditions.lua');return f,s,n end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('whole source is literal reviewed40policy with identities labels and bounds only',function()
 local expected=read('Defaults/tbc/priest-40-49.lua')
 for _,pair in ipairs({{'40–49','50–59'},{OLD,ID},{'Priest.Shadow40','Priest.Shadow50'},{'priest-shadow40-','priest-shadow50-'}})do expected=replace(expected,pair[1],pair[2])end
 expected=once(expected,'minLevel=40,maxLevel=49','minLevel=50,maxLevel=59')
 expected=once(expected,"operator='GREATERTHANOREQUALS',value=40","operator='GREATERTHANOREQUALS',value=50")
 expected=once(expected,"operator='LESSTHAN',value=50","operator='LESSTHAN',value=60")
 assert(read(arg[1]or'Defaults/tbc/priest-50-59.lua')==expected,'inherited source policy changed')
end)
test('separate50–59 manifest is exactly the reviewed whole40–49 policy after ID and bound normalization',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/priest-40-49.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID)).envelope;local normalized=a:CopySettingsData(new)
 assert(new.applicability.minLevel==50 and new.applicability.maxLevel==59 and new.nameKey=='Default.TBC.Priest.Shadow50.Name')
 normalized.id=OLD;normalized.nameKey=old.nameKey;normalized.descriptionKey=old.descriptionKey;normalized.applicability.minLevel=40;normalized.applicability.maxLevel=49
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('priest-shadow50-',1,true)==1);v.id=v.id:gsub('priest%-shadow50%-','priest-shadow40-');count=count+1 end;for _,child in pairs(v)do ids(child)end end
 ids(normalized.body);assert(count==12);normalized.body.switch.value[3].value=40;normalized.body.switch.value[4].value=50
 assert(equal(normalized,old),'inherited manifest/policy changed');assert(row(a).validation.valid and row(a).validation.resolved and row(a).readOnly)
end)
test('49/50/59/60 source eligibility and automatic gate agree without granting learned Smite',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({49,50,59,60})do s.level=level;clear(a);local yes=level>=50 and level<60;assert(row(a).eligible==yes);assert((a:evaluateConditionResult(body(a).switch).status=='match')==yes)end
 s.level=59;s.known={};clear(a);assert(a:evaluateConditionResult(body(a).switch).status=='no-match')
end)
test('Shadow allocation must remain unique positive for auto selection with unknown native points unavailable',function()
 local f,s=fixture();local a=f.addon
 for _,points in ipairs({{0,0,31},{5,0,26},{31,0,0},{0,31,0},{5,0,5},{0,0,0}})do s.talents=points;local r=a:evaluateConditionResult(body(a).switch);local want=points[3]>points[1]and points[3]>points[2]and points[3]>0;assert((r.status=='match')==want)end
 s.talents={0,0,31};s.talentError=true;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable');s.talentError=false
 local opaque={};s.talents={0,0,opaque};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
test('level59 never trains Flay or a rank; actual learned mapped families retain authority',function()
 local f,s,n=fixture();s.level=59;assert(first(f.addon,s)==585);s.known[6060]=true;assert(first(f.addon,s)==6060)
 entered(s,n);s.known[15407],s.known[17312]=true,true;assert(first(f.addon,s)==17312);s.mapped[17312]=false;assert(first(f.addon,s)==15407)
 s.known[15407],s.known[17312]=false,false;assert(first(f.addon,s)==6060)
end)
test('mapping range power usability and cooldown can each refuse Flay without altering inherited priority',function()
 for _,mode in ipairs({'mapping','range','power','usability','cooldown'})do local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true
  if mode=='mapping'then s.mapped[15407]=false elseif mode=='range'then s.range[15407]=false elseif mode=='power'then s.power[15407]=true elseif mode=='usability'then s.usable[15407]=false else s.cooldown[15407]={startTime=99,duration=30,isEnabled=true,modRate=1}end
  assert(first(f.addon,s)==5019,mode)
 end
end)
test('inherited own Pain half-health opener channel and active wand boundaries remain intact',function()
 local f,s,n=fixture();s.known[8092],s.known[589],s.known[15407],s.known[5019]=true,true,true,true;assert(first(f.addon,s)==8092)
 s.combat=true;assert(first(f.addon,s)==589);pain(s,n,'party1');assert(first(f.addon,s)==589);pain(s,n);assert(first(f.addon,s)==15407)
 s.repeatActive=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.repeatActive=false;s.targetHealth=50;assert(first(f.addon,s)==5019)
 s.channel=true;id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.channel=false;s.channelError=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('native unusability can block Holy fallback; this pack never automates Shadowform',function()
 local f,s,n=fixture();entered(s,n);s.usable[585]=false;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.usable[585]=true;assert(first(f.addon,s)==585)
 for _,entry in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do assert(entry.step.action~=15473)end
end)
test('self Inner Fire remains optional and its unavailable or existing aura is preserved',function()
 local f,s,n=fixture();assert(not optional(f,s));s.known[588],s.known[602]=true,true;assert(optional(f,s)==602)
 s.buffs={{spellId=602,name=n[602],sourceUnit='player'}};assert(not optional(f,s));s.buffs={};s.auraError=true;assert(not optional(f,s))
end)
test('source class edition vehicle and pet battle boundaries remain independent of Shadow allocation',function()
 for _,case in ipairs({{5,'MAGE'},{2,'PRIEST'},{1,'PRIEST'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 for _,kind in ipairs({'vehicle','petbattle'})do local f=fixture();if kind=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end;assert(not row(f.addon).eligible)end
end)
test('old40–49 saved clone survives new adoption and source snapshots remain independent',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/priest-40-49.lua');assert(a:InitializeRotationLibrary());s.level=49;clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Shadow clone'));local old=a:GetEditableRotation(0,id);old.rotation[1].onTrue[2].action=585;local saved=a:CopySettingsData(old)
 s.level=50;clear(a);assert(a:InitializeRotationLibrary());assert(not a:GetRuntimeRotation(0,id));assert(equal(a:GetEditableRotation(0,id),saved))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Fifty Shadow clone'));a:GetEditableRotation(0,fresh).rotation[1].onTrue[2].action=585;assert(body(a).rotation[1].onTrue[2].action==8092);assert(equal(a:GetEditableRotation(0,id),saved))
end)
test('initialized real publisher auto switches49→50→59→60 and recovers across Shadow changes',function()
 local f,s,n=fixture();f.load('Defaults/tbc/priest-40-49.lua');entered(s,n);s.known[15407],s.known[17312]=true,true;local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a:UpdateAutoSwitch()
 for _,level in ipairs({49,50,59,60,50})do s.level=level;clear(a);a.manualRotation=false;a:UpdateAutoSwitch();tick();if level==60 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentSpell==17312);assert(a.currentRotation=='RM-BUILTIN:'..(level<50 and OLD or ID))end end
 s.talents={31,0,0};tick();assert(not a.currentRotation and not a.currentSpell);s.talents={0,0,31};tick();assert(a.currentSpell==17312)
 s.talentError=true;tick();assert(not a.currentRotation and not a.currentSpell);s.talentError=false;tick();assert(a.currentSpell==17312)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==17312 then found=true end;assert(m[6]~=6603)end;assert(found and#glow>0)
end)
test('manual builtin selection preserves existing allocation-bypass and cast semantics but native readiness still governs',function()
 local f,s,n=fixture();entered(s,n);s.known[15407]=true;local tick=nativePublish(f,s);local a=f.addon;s.talents={31,0,0};a.currentRotation=row(a).runtimeKey;a.manualRotation=true
 f.env.UnitCastingInfo=function()return'Manual cast'end;tick();assert(a.currentSpell==15407,'manual selection unexpectedly gained talent/cast Stop gate')
 s.channel=true;tick();assert(not a.currentSpell);s.channel=false;s.usable[15407],s.usable[585]=false,false;tick();assert(not a.currentSpell)
end)

test('unknown learned branch stops while unavailable health skips Flay and retains existing wand fallback',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true;s.flayKnownNil=true
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.flayKnownNil=false;s.flayKnownError=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.flayKnownError=false;s.healthError=true;assert(first(f.addon,s)==5019,'unknown row health keeps inherited ready wand fallback')
 s.healthError=false;s.channel=true;id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.channel=false;assert(first(f.addon,s)==15407,'inherited filler may recommend another Flay after a channel')
 s.knownError=true;assert(f.addon:evaluateConditionResult(body(f.addon).switch).status=='unavailable')
end)
test('manual Inner Fire from other casters remains untouched and readiness does not invent upkeep',function()
 for _,caster in ipairs({'player','party1'})do local f,s,n=fixture();s.known[588],s.known[602]=true,true
  s.buffs={{spellId=602,name=n[602],sourceUnit=caster}};assert(not optional(f,s))
 end
 for _,mode in ipairs({'mapping','power','usability','cooldown'})do local f,s=fixture();s.known[588],s.known[602]=true,true
  for _,id in ipairs({588,602})do if mode=='mapping'then s.mapped[id]=false elseif mode=='power'then s.power[id]=true elseif mode=='usability'then s.usable[id]=false else s.cooldown[id]={startTime=99,duration=30,isEnabled=true,modRate=1}end end
  assert(not optional(f,s),mode)
 end
end)
test('target engagement and movement preserve inherited no attack boundary',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==585)
 s.targetCombat=false;s.combat=false;s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.moving=false;s.hostile=false;assert(not first(f.addon,s));s.hostile=true;s.dead=true;assert(not first(f.addon,s));s.dead=false;s.exists=false;assert(not first(f.addon,s))
end)
test('unavailable player level cannot establish source or switch eligibility',function()
 local f,s=fixture();local a=f.addon;s.level=nil;clear(a)
 assert(not row(a).eligible and a:evaluateConditionResult(body(a).switch).status=='unavailable')
 s.level=50;clear(a);assert(row(a).eligible and a:evaluateConditionResult(body(a).switch).status=='match')
 f.env.UnitLevel=function()error('level unavailable')end;clear(a)
 assert(not row(a).eligible and a:evaluateConditionResult(body(a).switch).status=='unavailable')
 local opaque={};f.env.UnitLevel=function()return opaque end;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;clear(a)
 assert(not row(a).eligible and a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
finish()
