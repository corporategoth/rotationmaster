-- Reuse reviewed rank samples/native pipeline, not a fabricated40s spellbook.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local prefix=assert(read('tests/defaults_paladin_30_39.lua'):match('^(.-)\ntest%('))
for _,pair in ipairs({{'paladin-30-39.lua','paladin-40-49.lua'},{'rm.tbc.paladin.starter.30-39','rm.tbc.paladin.starter.40-49'},{'Paladin.Thirty','Paladin.Forty'},{'30–39','40–49'},{'level=30','level=40'}})do assert(prefix:find(pair[1],1,true));prefix=prefix:gsub(pair[1]:gsub('([^%w])','%%%1'),function()return pair[2]end)end
local make,sourceRow,body,first,available,own,buff,nativePublish=assert(loadstring(prefix..'\nreturn fixture,sourceRow,body,first,available,own,buff,nativePublish','@paladin-forty-pipeline'))()
local function fixture(...)local f,s,n=make(...);f.load('Core/rotation_selection.lua');return f,s,n end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite();local ID,OLD='rm.tbc.paladin.starter.40-49','rm.tbc.paladin.starter.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function level(f,s,value)s.level=value;f.addon.longtermCache={}end
local function ready()local f,s,n=fixture();s.combat=true;s.known[20271]=true;own(s,n,20288);return f,s,n end

test('whole three-row40–49 source equals30–39 after only IDs keys and bounds normalize',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/paladin-30-39.lua');assert(a:InitializeRotationLibrary());local old=assert(a:GetDefaultRotation(OLD)).envelope;local current=assert(a:GetDefaultRotation(ID)).envelope;local copy=a:CopySettingsData(current)
 assert(current.applicability.minLevel==40 and current.applicability.maxLevel==49);copy.id=OLD;copy.nameKey=old.nameKey;copy.descriptionKey=old.descriptionKey;copy.applicability.minLevel=30;copy.applicability.maxLevel=39;copy.body.switch.value[1].value=30;copy.body.switch.value[2].value=40
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('paladin-forty-',1,true)==1);v.id=v.id:gsub('paladin%-forty%-','paladin-thirty-');count=count+1 end;for _,child in pairs(v)do ids(child)end end;ids(copy.body);assert(count==3 and equal(copy,old));assert(sourceRow(a).validation.valid and sourceRow(a).validation.resolved)
end)
test('39 40 49 50 bracket boundaries agree with literal level-only switch without a talent or learned gate',function()
 local f,s=fixture();f.env.GetTalentTabInfo=function()error('no talent gate')end;s.known={}
 for _,value in ipairs({39,40,49,50})do level(f,s,value);local yes=value>=40 and value<50;assert(sourceRow(f.addon).eligible==yes);assert((f.addon:evaluateConditionResult(body(f.addon).switch).status=='match')==yes)end
end)
test('four source brackets switch disjointly and level-up retires the previous selected bracket',function()
 local f,s=fixture();local a=f.addon;for _,path in ipairs({'paladin-starter.lua','paladin-20-29.lua','paladin-30-39.lua'})do f.load('Defaults/tbc/'..path)end;assert(a:InitializeRotationLibrary());nativePublish(f,s);a.db.profile.rotations[0]={};assert(a:InitializeRotationLibrary());a.currentRotation=nil;a.manualRotation=false;a.db.profile.disable_autoswitch=false
 for _,value in ipairs({19,20,29,30,39,40,49,50})do level(f,s,value);a:UpdateAutoSwitch();a:SwitchRotation();local chosen={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then chosen[#chosen+1]=r.id end end;assert(#chosen==(value<50 and 1 or 0));if value>=40 and value<50 then assert(chosen[1]==ID and a.currentRotation==sourceRow(a).runtimeKey)end end
end)
test('class edition context enable and profile boundaries remain source-owned',function()
 for _,case in ipairs({{5,'WARRIOR'},{2,'PALADIN'},{1,'PALADIN'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(r.id~=ID or not r.eligible)end end
 local f=fixture();local a=f.addon;assert(sourceRow(a).readOnly);f.env.UnitHasVehicleUI=function()return true end;assert(not sourceRow(a).eligible);f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles={IsInBattle=function()return true end};assert(not sourceRow(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not sourceRow(a).eligible);local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(sourceRow(a).enabled);a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(not sourceRow(a).enabled)
end)
test('actual publisher requires affirmative own Righteousness and real learned Judgement',function()
 local f,s,n=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271);s.known[20271]=false;tick();assert(f.addon.currentSpell==6603);s.known[20271]=true
 for _,owner in ipairs({'party1','target'})do s.buffs[1].sourceUnit=owner;tick();assert(f.addon.currentSpell==6603)end;s.buffs[1].sourceUnit=nil;tick();assert(f.addon.currentSpell==6603);s.buffs[1].sourceUnit='player';tick();assert(f.addon.currentSpell==20271)
end)
test('manual conflicting seals and overlap preserve melee fallback without Judgement or upkeep',function()
 local f,s,n=ready();local tick=nativePublish(f,s)
 for _,id in ipairs({21082,20162,20305,20375,20164,20165,20166})do own(s,n,id);buff(s,n,20288);tick();assert(f.addon.currentSpell==6603 and not next(f.addon.avail_announced),id)end
 assert(#body(f.addon).cooldowns==0 and #available(f,s)==0)
end)
test('native readiness resources cooldown range and mappings independently recover on40–49 data',function()
 local f,s=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 for _,key in ipairs({'usable','power','range','mapped'})do s[key][20271]=key=='power';if key=='mapped'then local selected=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=selected end;tick();assert(f.addon.currentSpell==6603,key);s[key][20271]=key~='power';if key=='mapped'then local selected=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=selected end;tick();assert(f.addon.currentSpell==20271,key)end
 s.cooldown[20271]={startTime=99,duration=10,isEnabled=true,modRate=1};tick();assert(f.addon.currentSpell==6603);s.cooldown={};tick();assert(f.addon.currentSpell==20271)
end)
test('manual casts and channels stop Judgement and implicit melee in the inherited combat branch',function()
 local f,s=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 for _,key in ipairs({'casting','channel'})do s[key]=true;tick();assert(f.addon.currentSpell==nil);s[key]=false;tick();assert(f.addon.currentSpell==20271)end
end)
test('encountered unknown cast or channel suppresses all advice without inventing a fallback',function()
 local f,s=ready();local tick=nativePublish(f,s);tick();local cast,channel=f.env.UnitCastingInfo,f.env.UnitChannelInfo
 f.env.UnitCastingInfo=function()error('unknown cast')end;tick();assert(f.addon.currentSpell==nil);f.env.UnitCastingInfo=cast
 f.env.UnitChannelInfo=function()error('unknown channel')end;tick();assert(f.addon.currentSpell==nil);f.env.UnitChannelInfo=channel;tick();assert(f.addon.currentSpell==20271)
end)
test('unknown aura ownership or readiness never authorizes Judgement while melee still requires native facts',function()
 local f,s=ready();local tick=nativePublish(f,s);tick();s.auraError=true;tick();assert(f.addon.currentSpell==6603);s.auraError=false
 local old=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==20271 then return nil end;return old(id)end;tick();assert(f.addon.currentSpell==6603)
 s.activeError=true;tick();assert(f.addon.currentSpell==nil)
end)
test('current short-circuit source preserves known casting Stop even when a later channel read would fail',function()
 local f,s=ready();s.casting=true;f.env.UnitChannelInfo=function()error('must be skipped after casting match')end;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==nil);assert(first(f.addon,s)==nil)
end)
test('old edited30–39 clone stays independent while a fresh40–49 clone retains new bracket',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/paladin-30-39.lua');assert(a:InitializeRotationLibrary());level(f,s,39);local old=assert(a:CloneDefaultRotation(0,OLD,'Old Paladin'));local edited=a:GetEditableRotation(0,old);edited.rotation[1].onTrue[2].action=999;local before=a:CopySettingsData(edited)
 level(f,s,40);assert(a:InitializeRotationLibrary());local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Paladin'));assert(equal(before,a:GetEditableRotation(0,old)));assert(not a:GetRuntimeRotation(0,old));local view=a:GetEditableRotation(0,fresh);assert(view.rotation[1].onTrue[2].action==20271);assert(view~=body(a) and view.rotation~=body(a).rotation);view.rotation[1].onTrue[2].action=998;assert(body(a).rotation[1].onTrue[2].action==20271)
end)
finish()
