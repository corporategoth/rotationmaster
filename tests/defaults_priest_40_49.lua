-- Inherit the reviewed real pipeline fixture; modeled ranks are existing samples,
-- not a new40s spellbook, talent build, trainer schedule or native acceptance.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local inherited=assert(read('tests/defaults_priest_30_39.lua'):match('^(.-)\ntest%('))
for _,pair in ipairs({{'priest-30-39.lua','priest-40-49.lua'},{'rm.tbc.priest.shadow.30-39','rm.tbc.priest.shadow.40-49'},{'Priest.Shadow30','Priest.Shadow40'},{'30–39','40–49'},{'level=30','level=40'}})do
 assert(inherited:find(pair[1],1,true),'missing inherited fixture anchor '..pair[1]);inherited=inherited:gsub(pair[1]:gsub('([^%w])','%%%1'),function()return pair[2]end)
end
local fixture,row,body,first,optional,nativePublish,pain,entered=assert(loadstring(inherited..'\nreturn fixture,row,body,first,optional,nativePublish,pain,entered','@priest-forty-pipeline'))()
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.priest.shadow.40-49','rm.tbc.priest.shadow.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('separate40–49 manifest is exactly the reviewed whole30–39 policy after ID and bound normalization',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/priest-30-39.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID)).envelope;local normalized=a:CopySettingsData(new)
 assert(new.applicability.minLevel==40 and new.applicability.maxLevel==49 and new.nameKey=='Default.TBC.Priest.Shadow40.Name')
 normalized.id=OLD;normalized.nameKey=old.nameKey;normalized.descriptionKey=old.descriptionKey;normalized.applicability.minLevel=30;normalized.applicability.maxLevel=39
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('priest-shadow40-',1,true)==1);v.id=v.id:gsub('priest%-shadow40%-','priest-shadow30-');count=count+1 end;for _,child in pairs(v)do ids(child)end end
 ids(normalized.body);assert(count==12);normalized.body.switch.value[3].value=30;normalized.body.switch.value[4].value=40
 assert(equal(normalized,old),'inherited manifest/policy changed');assert(row(a).validation.valid and row(a).validation.resolved and row(a).readOnly)
end)
test('39/40/49/50 source eligibility and automatic gate agree without granting learned Smite',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({39,40,49,50})do s.level=level;clear(a);local yes=level>=40 and level<50;assert(row(a).eligible==yes);assert((a:evaluateConditionResult(body(a).switch).status=='match')==yes)end
 s.level=49;s.known={};clear(a);assert(a:evaluateConditionResult(body(a).switch).status=='no-match')
end)
test('Shadow allocation must remain unique positive for auto selection with unknown native points unavailable',function()
 local f,s=fixture();local a=f.addon
 for _,points in ipairs({{0,0,31},{5,0,26},{31,0,0},{0,31,0},{5,0,5},{0,0,0}})do s.talents=points;local r=a:evaluateConditionResult(body(a).switch);local want=points[3]>points[1]and points[3]>points[2]and points[3]>0;assert((r.status=='match')==want)end
 s.talents={0,0,31};s.talentError=true;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable');s.talentError=false
 local opaque={};s.talents={0,0,opaque};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
test('level49 never trains Flay or a rank; actual learned mapped families retain authority',function()
 local f,s,n=fixture();s.level=49;assert(first(f.addon,s)==585);s.known[6060]=true;assert(first(f.addon,s)==6060)
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
test('old30–39 saved clone survives new adoption and source snapshots remain independent',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/priest-30-39.lua');assert(a:InitializeRotationLibrary());s.level=39;clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Shadow clone'));local old=a:GetEditableRotation(0,id);old.rotation[1].onTrue[2].action=585;local saved=a:CopySettingsData(old)
 s.level=40;clear(a);assert(a:InitializeRotationLibrary());assert(not a:GetRuntimeRotation(0,id));assert(equal(a:GetEditableRotation(0,id),saved))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Shadow clone'));a:GetEditableRotation(0,fresh).rotation[1].onTrue[2].action=585;assert(body(a).rotation[1].onTrue[2].action==8092);assert(equal(a:GetEditableRotation(0,id),saved))
end)
test('initialized real publisher auto switches39→40→49→50 and recovers across Shadow changes',function()
 local f,s,n=fixture();f.load('Defaults/tbc/priest-30-39.lua');entered(s,n);s.known[15407],s.known[17312]=true,true;local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a:UpdateAutoSwitch()
 for _,level in ipairs({39,40,49,50,40})do s.level=level;clear(a);a.manualRotation=false;tick();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentSpell==17312);assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID))end end
 s.talents={31,0,0};tick();assert(not a.currentRotation and not a.currentSpell);s.talents={0,0,31};tick();assert(a.currentSpell==17312)
 s.talentError=true;tick();assert(not a.currentRotation and not a.currentSpell);s.talentError=false;tick();assert(a.currentSpell==17312)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==17312 then found=true end;assert(m[6]~=6603)end;assert(found and#glow>0)
end)
test('manual builtin selection preserves existing allocation-bypass and cast semantics but native readiness still governs',function()
 local f,s,n=fixture();entered(s,n);s.known[15407]=true;local tick=nativePublish(f,s);local a=f.addon;s.talents={31,0,0};a.currentRotation=row(a).runtimeKey;a.manualRotation=true
 f.env.UnitCastingInfo=function()return'Manual cast'end;tick();assert(a.currentSpell==15407,'manual selection unexpectedly gained talent/cast Stop gate')
 s.channel=true;tick();assert(not a.currentSpell);s.channel=false;s.usable[15407],s.usable[585]=false,false;tick();assert(not a.currentSpell)
end)
finish()
