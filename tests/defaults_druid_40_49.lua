-- Existing modeled ranks exercise learned authority, not a40s training schedule.
-- This remains limited humanoid caster advice; no form/build or talent inference.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local inherited=assert(read('tests/defaults_druid_30_39.lua'):match('^(.-)\ntest%('))
for _,p in ipairs({{'druid-caster-30-39.lua','druid-caster-40-49.lua'},{'rm.tbc.druid.caster.starter.30-39','rm.tbc.druid.caster.starter.40-49'},{'Druid.Caster.Thirty','Druid.Caster.Forty'},{'30–39','40–49'},{'level=30','level=40'}})do
 assert(inherited:find(p[1],1,true));inherited=inherited:gsub(p[1]:gsub('([^%w])','%%%1'),function()return p[2]end)
end
local make,row,body,first,nativePublish,own=assert(loadstring(inherited..'\nreturn fixture,row,body,first,nativePublish,own','@druid-forty-pipeline'))()
local function fixture(...)
 local f,s,n=make(...);f.addon.ScheduleTimer=function(_,callback)return callback end;f.addon.ScheduleRepeatingTimer=function()return'modeled-publisher-timer'end;f.addon.CancelTimer=function()end
 s.setLevel=function(level)s.level=level;f.addon:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 return f,s,n
end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.druid.caster.starter.40-49','rm.tbc.druid.caster.starter.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('whole limited caster40–49 manifest exactly inherits30–39 after identities and bounds normalize',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/druid-caster-30-39.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID),'missing Druid40–49 manifest').envelope;local copy=a:CopySettingsData(new)
 assert(new.nameKey=='Default.TBC.Druid.Caster.Forty.Name'and new.descriptionKey=='Default.TBC.Druid.Caster.Forty.Description'and new.applicability.minLevel==40 and new.applicability.maxLevel==49)
 copy.id=OLD;copy.nameKey=old.nameKey;copy.descriptionKey=old.descriptionKey;copy.applicability.minLevel=30;copy.applicability.maxLevel=39
 local count=0;local function normalize(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('druid-caster-forty-',1,true)==1);v.id=v.id:gsub('druid%-caster%-forty%-','druid-caster-thirty-');count=count+1 end;for _,child in pairs(v)do normalize(child)end end
 normalize(copy.body);assert(count==9);copy.body.switch.value[2].value=30;copy.body.switch.value[3].value=40;assert(equal(copy,old),'caster policy changed');assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
end)
test('39 40 49 50 source and auto gate stay bounded and level grants no Wrath',function()
 local f,s=fixture();local a=f.addon;for _,level in ipairs({39,40,49,50})do s.setLevel(level);clear(a);local yes=level>=40 and level<50;assert(row(a).eligible==yes);assert((a:evaluateConditionResult(body(a).switch).status=='match')==yes)end
 s.setLevel(49);clear(a);s.known[5176]=false;assert(a:evaluateConditionResult(body(a).switch).status=='no-match');f.env.IsSpellKnown=function()return nil end;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
test('limited caster scope remains class edition player only without Balance talent or form grants',function()
 for _,case in ipairs({{5,'MAGE'},{2,'DRUID'},{1,'DRUID'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 local f,s=fixture();local a=f.addon;assert(row(a).envelope.applicability.specs==nil);f.env.GetTalentTabInfo=function()error('no Balance talent gate')end;assert(a:evaluateConditionResult(body(a).switch).status=='match'and first(a,s)==5176)
 local actions={[5176]=true,[8921]=true,[2912]=true};for _,r in ipairs(assert(a.RotationData.IndexRotationSteps(body(a))).rows)do if r.step.action then assert(actions[r.step.action]and r.step.ranked==false)end end
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible)
end)
test('level49 retains learned mapped Moonfire Starfire Wrath without new ranks',function()
 local f,s,n=fixture();s.setLevel(49);assert(first(f.addon,s)==5176);s.known[5179]=true;assert(first(f.addon,s)==5179);s.mapped[5179]=false;assert(first(f.addon,s)==5176)
 s.known[2912],s.known[8949]=true,true;assert(first(f.addon,s)==8949);s.mapped[8949]=false;assert(first(f.addon,s)==2912);s.known[8921],s.known[8927]=true,true;assert(first(f.addon,s)==8927);own(s,n,8926);assert(first(f.addon,s)==2912)
end)
test('every nonzero form remains manual regardless of slot topology and unknown form fails closed',function()
 for _,forms in ipairs({{768},{1066,768},{783,5487,1066},{5487,1066,768,783}})do local f,s=fixture();s.forms=forms;s.known[2912]=true;assert(first(f.addon,s)==2912);for slot=1,#forms do s.form=slot;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)end end
 for _,mode in ipairs({'nil','error'})do local f,s=fixture();if mode=='nil'then s.form=nil else s.formError=true end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)end
end)
test('manual cast channel and unknown observations suppress replacement caster advice',function()
 local f,s=fixture();s.known[8921],s.known[2912]=true,true;for _,key in ipairs({'casting','channel'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack);s[key]=false end
 for _,key in ipairs({'UnitCastingInfo','UnitChannelInfo'})do local old=f.env[key];f.env[key]=function()error('unknown native state')end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack);f.env[key]=old end
end)
test('moving humanoid may maintain own missing Moonfire but never starts stationary fillers',function()
 local f,s,n=fixture();s.known[2912]=true;s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.known[8921]=true;assert(first(f.addon,s)==8921);own(s,n,8921);assert(not first(f.addon,s));s.moving=false;assert(first(f.addon,s)==2912)
end)
test('own localized Moonfire crossrank and absent attribution retain inherited priority and unknown policy',function()
 local f,s,n=fixture();s.known[8921],s.known[8927],s.known[2912]=true,true,true;own(s,n,8926);assert(first(f.addon,s)==2912);s.debuffs[1].sourceUnit='party1';assert(first(f.addon,s)==8927);s.debuffs[1].sourceUnit=nil;assert(first(f.addon,s)==8927)
 s.auraError=true;assert(first(f.addon,s)==2912,'unknown DoT incorrectly manufactured need or blocked independent filler')
 local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==2912 then return nil end;return known(id)end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('native mapping range cooldown power usability each block Starfire while Wrath stays independent',function()
 for _,mode in ipairs({'mapping','range','cooldown','power','usability'})do local f,s=fixture();s.known[2912]=true
  if mode=='mapping'then s.mapped[2912]=false elseif mode=='range'then s.range[2912]=false elseif mode=='cooldown'then s.cooldown[2912]={startTime=99,duration=30,isEnabled=true,modRate=1}elseif mode=='power'then s.power[2912]=true else s.usable[2912]=false end
  assert(first(f.addon,s)==5176,mode)
 end
 local f,s=fixture();f.env.C_Spell.IsSpellUsable=function()return nil,nil end;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('initialized publisher switches39 to40 to49 to50 and clears unknown learned context',function()
 local f,s=fixture();f.load('Defaults/tbc/druid-caster-30-39.lua');local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a.db.profile.disable_autoswitch=false;a.manualRotation=false
 local function poll()a:UpdateAutoSwitch();a:SwitchRotation();tick()end
 for _,level in ipairs({39,40,49,50,40})do s.setLevel(level);clear(a);poll();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID));assert(a.currentSpell==5176)end end
 s.known[5176]=false;poll();assert(not a.currentRotation and not a.currentSpell);s.known[5176]=true;poll();assert(a.currentSpell==5176);f.env.IsSpellKnown=function()return nil end;poll();assert(not a.currentRotation and not a.currentSpell)
 local seen=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==5176 then seen=true end;assert(m[6]~=6603)end;assert(seen and#glow>0)
end)
test('manual builtin retains forms cast channel and readiness retirement without implicit melee',function()
 local f,s=fixture();s.known[2912]=true;local tick=nativePublish(f,s);local a=f.addon;a.currentRotation=row(a).runtimeKey;a.manualRotation=true;tick();assert(a.currentSpell==2912)
 for _,key in ipairs({'casting','channel','form'})do if key=='form'then s.forms={768};s.form=1 else s[key]=true end;tick();assert(not a.currentSpell,key);s.form=0;s.casting=false;s.channel=false;tick();assert(a.currentSpell==2912)end
 f.env.C_Spell.IsSpellUsable=function()return nil,nil end;tick();assert(not a.currentSpell)
end)
test('old saved edited caster clone remains independent across new adoption profile and disable',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/druid-caster-30-39.lua');assert(a:InitializeRotationLibrary());s.setLevel(39);clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old caster'));a:GetEditableRotation(0,id).rotation[1].onTrue[1].onTrue[2].action=5176;local saved=a:CopySettingsData(a:GetEditableRotation(0,id));s.setLevel(40);clear(a)
 assert(not a:GetRuntimeRotation(0,id)and equal(saved,a:GetEditableRotation(0,id)));local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty caster'));a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].onTrue[2].action=5176;assert(body(a).rotation[1].onTrue[1].onTrue[2].action==8921)
 local comparison=assert(a:BuildRotationComparison(0,fresh,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 assert(a:SetDefaultRotationEnabled(ID,false)and not row(a).eligible);local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary()and row(a).enabled);a.db.profile=profile;assert(a:InitializeRotationLibrary()and not row(a).enabled);assert(equal(saved,a:GetEditableRotation(0,id)))
end)
finish()
