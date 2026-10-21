-- Existing modeled rank samples exercise learned authority, not a40s training schedule.
-- Reuse only the reviewed actual pipeline fixture; all assertions below run real modules.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local inherited=assert(read('tests/defaults_rogue_30_39.lua'):match('^(.-)\ntest%('))
for _,p in ipairs({{'rogue-30-39.lua','rogue-40-49.lua'},{'rm.tbc.rogue.starter.30-39','rm.tbc.rogue.starter.40-49'},{'Rogue.Thirty','Rogue.Forty'},{'30–39','40–49'},{'level or 30','level or 40'}})do
 assert(inherited:find(p[1],1,true));inherited=inherited:gsub(p[1]:gsub('([^%w])','%%%1'),function()return p[2]end)
end
local make,row,body,first,nativePublish,slice=assert(loadstring(inherited..'\nreturn fixture,row,body,first,nativePublish,slice','@rogue-forty-pipeline'))()
local function fixture(...)
 local f,s,n=make(...);f.load('Core/rotation_selection.lua');f.addon.ScheduleTimer=function(_,callback)return callback end;f.addon.ScheduleRepeatingTimer=function()return'modeled-publisher-timer'end;f.addon.CancelTimer=function()end
 s.setLevel=function(level)s.level=level;f.addon:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 return f,s,n
end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.rogue.starter.40-49','rm.tbc.rogue.starter.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('whole40–49 manifest retains exact reviewed30–39 policy after identity and bound normalization',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/rogue-30-39.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID),'missing Rogue40–49 manifest').envelope;local copy=a:CopySettingsData(new)
 assert(new.nameKey=='Default.TBC.Rogue.Forty.Name'and new.descriptionKey=='Default.TBC.Rogue.Forty.Description'and new.applicability.minLevel==40 and new.applicability.maxLevel==49)
 copy.id=OLD;copy.nameKey=old.nameKey;copy.descriptionKey=old.descriptionKey;copy.applicability.minLevel=30;copy.applicability.maxLevel=39
 local count=0;local function normalize(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('rogue-forty-',1,true)==1);v.id=v.id:gsub('rogue%-forty%-','rogue-thirty-');count=count+1 end;for _,child in pairs(v)do normalize(child)end end
 normalize(copy.body);assert(count==11);copy.body.switch.value[2].value=30;copy.body.switch.value[3].value=40;assert(equal(copy,old),'policy changed');assert(row(a).validation.valid and row(a).validation.resolved and row(a).readOnly)
end)
test('39 40 49 50 scope and automatic switch agree without level granting learned Sinister',function()
 local f,s=fixture();local a=f.addon;for _,level in ipairs({39,40,49,50})do s.setLevel(level);clear(a);local yes=level>=40 and level<50;assert(row(a).eligible==yes);assert((a:evaluateConditionResult(body(a).switch).status=='match')==yes)end
 s.setLevel(49);clear(a);s.known[1752]=false;assert(a:evaluateConditionResult(body(a).switch).status=='no-match');f.env.IsSpellKnown=function()return nil end;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
test('generic melee source remains class edition player scoped without talent selection',function()
 for _,case in ipairs({{5,'MAGE'},{2,'ROGUE'},{1,'ROGUE'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 local f,s=fixture();local a=f.addon;assert(row(a).envelope.applicability.specs==nil);f.env.GetTalentTabInfo=function()error('no talent policy')end;assert(a:evaluateConditionResult(body(a).switch).status=='match'and first(a,s)==1752)
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible)
end)
test('level49 retains native learned mapped builder and finisher families without new ranks',function()
 local f,s=fixture();s.setLevel(49);assert(first(f.addon,s)==1752);s.known[1759]=true;assert(first(f.addon,s)==1759);s.mapped[1759]=false;assert(first(f.addon,s)==1752)
 s.points=5;assert(first(f.addon,s)==2098);s.known[6762]=true;assert(first(f.addon,s)==6762);s.mapped[6762]=false;assert(first(f.addon,s)==2098)
end)
test('two point own Slice and five point Eviscerate keep fixed policy and no builder overflow',function()
 local f,s,n=fixture();s.known[5171]=true
 for _,v in ipairs({{0,1752},{1,1752},{2,5171},{4,5171},{5,5171}})do s.points=v[1];assert(first(f.addon,s)==v[2])end
 slice(s,n);for _,v in ipairs({{0,1752},{4,1752},{5,2098}})do s.points=v[1];assert(first(f.addon,s)==v[2])end
 s.mapped[2098]=false;assert(not first(f.addon,s));s.mapped[2098]=true;s.buffs[1].sourceUnit='party1';assert(first(f.addon,s)==5171);s.buffs[1].sourceUnit=nil;assert(first(f.addon,s)==5171)
end)
test('native mapping range cooldown power and usability independently constrain real actions',function()
 for _,mode in ipairs({'mapping','range','cooldown','power','usability'})do local f,s=fixture()
  if mode=='mapping'then s.mapped[1752]=false elseif mode=='range'then s.range[1752]=false elseif mode=='cooldown'then s.cooldown[1752]={startTime=99,duration=30,isEnabled=true,modRate=1}elseif mode=='power'then s.energy=0 else s.usable[1752]=false end
  assert(not first(f.addon,s),mode)
 end
 local f,s=fixture();s.costOverride=1;s.energy=1;assert(first(f.addon,s)==1752,'authored reserve bypassed native reduced cost')
end)
test('stealth cast channel and unavailable native observations suppress the inherited melee advice',function()
 local f,s=fixture();for _,key in ipairs({'stealth','cast','channel'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
 for _,key in ipairs({'stealthError','stealthNil','castError','channelError','pointNil','pointError'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack,key);s[key]=false end
 local opaque={};s.points=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('current target combo transport has no legacy rescue and is fresh after target transitions',function()
 local f,s=fixture();for _,v in ipairs({{5,2098},{0,1752},{3,1752},{5,2098}})do s.points=v[1];assert(first(f.addon,s)==v[2])end;assert(s.comboCalls>0 and s.pointCalls==0)
 f.env.GetComboPoints=nil;f.env.UnitPower=function()error('no unsupported fallback')end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('native Slice attribution unknown aura and no-melee targets do not invent upkeep',function()
 local f,s,n=fixture();s.points=2;s.known[5171]=true;slice(s,n);local opaque={};s.buffs[1].sourceUnit=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack);s.buffs={};s.auraError=true;assert(not first(f.addon,s));s.auraError=false
 for _,key in ipairs({'combat','hostile','exists'})do s[key]=false;assert(not first(f.addon,s));s[key]=true end;s.range[6603]=false;assert(not first(f.addon,s))
end)
test('real initialized publisher auto switches39 to40 to49 to50 and retires unknown learning',function()
 local f,s=fixture();f.load('Defaults/tbc/rogue-30-39.lua');local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a.db.profile.disable_autoswitch=false;a.manualRotation=false
 local function poll()a:UpdateAutoSwitch();a:SwitchRotation();tick()end
 for _,level in ipairs({39,40,49,50,40})do s.setLevel(level);clear(a);poll();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID));assert(a.currentSpell==1752)end end
 s.known[1752]=false;poll();assert(not a.currentRotation and not a.currentSpell);s.known[1752]=true;poll();assert(a.currentSpell==1752);f.env.IsSpellKnown=function()return nil end;poll();assert(not a.currentRotation and not a.currentSpell)
 local seen=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==1752 then seen=true end end;assert(seen and#glow>0)
end)
test('manual source selection preserves stops resource authority and known Attack fallback',function()
 local f,s=fixture();local tick=nativePublish(f,s);local a=f.addon;a.currentRotation=row(a).runtimeKey;a.manualRotation=true
 tick();assert(a.currentSpell==1752);for _,key in ipairs({'stealth','cast','channel','castError','channelError','pointNil'})do s[key]=true;tick();assert(not a.currentSpell,key);s[key]=false;tick();assert(a.currentSpell==1752)end
 s.energy=0;tick();assert(a.currentSpell==6603);s.combat=false;tick();assert(not a.currentSpell)
end)
test('old saved edited source clone remains independent across new adoption profiles and disable',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/rogue-30-39.lua');assert(a:InitializeRotationLibrary());s.setLevel(39);clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Rogue'));a:GetEditableRotation(0,id).rotation[1].id='my-stealth';local saved=a:CopySettingsData(a:GetEditableRotation(0,id));s.setLevel(40);clear(a)
 assert(not a:GetRuntimeRotation(0,id)and equal(saved,a:GetEditableRotation(0,id)));local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Rogue'));a:GetEditableRotation(0,fresh).rotation[1].id='my-forty';assert(body(a).rotation[1].id=='rogue-forty-preserve-stealth')
 local comparison=assert(a:BuildRotationComparison(0,fresh,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 assert(a:SetDefaultRotationEnabled(ID,false)and not row(a).eligible);local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary()and row(a).enabled);a.db.profile=profile;assert(a:InitializeRotationLibrary()and not row(a).enabled);assert(equal(saved,a:GetEditableRotation(0,id)))
end)
finish()
