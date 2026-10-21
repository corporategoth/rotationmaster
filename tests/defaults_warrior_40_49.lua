-- Actual native publisher helper with explicitly modeled corroborated queue IDs.
-- Description mirrors never prove native training or learned state.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local prefix=assert(read('tests/defaults_warrior_30_39.lua'):match('^(.-)\ntest%('))
for _,pair in ipairs({{'warrior-30-39.lua','warrior-40-49.lua'},{'rm.tbc.warrior.starter.30-39','rm.tbc.warrior.starter.40-49'},{'Warrior.Thirty','Warrior.Forty'},{'30–39','40–49'},{'level=30','level=40'},{'78,284,285,1608,11564','78,284,285,1608,11564,11565,11566'}})do assert(prefix:find(pair[1],1,true));prefix=prefix:gsub(pair[1]:gsub('([^%w])','%%%1'),function()return pair[2]end)end
local make,body,first,optional,nativePublish,row,allRanks,same=assert(loadstring(prefix..'\nreturn fixture,body,first,optional,nativePublish,row,allRanks,same','@warrior-forty-pipeline'))()
local function fixture(...)local f,s,n=make(...);f.load('Core/rotation_selection.lua');return f,s,n end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite();local ID,OLD='rm.tbc.warrior.starter.40-49','rm.tbc.warrior.starter.30-39'
local function level(f,s,n)s.level=n;f.addon.longtermCache={}end
local function combat()local f,s,n=fixture();s.combat=true;return f,s,n end

test('whole inherited policy differs only by identities bounds and two exact learned-gated queue branches plus citations',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/warrior-30-39.lua');assert(a:InitializeRotationLibrary());local old=assert(a:GetDefaultRotation(OLD)).envelope;local now=assert(a:GetDefaultRotation(ID)).envelope;local copy=a:CopySettingsData(now)
 assert(copy.applicability.minLevel==40 and copy.applicability.maxLevel==49);copy.id=OLD;copy.nameKey=old.nameKey;copy.descriptionKey=old.descriptionKey;copy.applicability.minLevel=30;copy.applicability.maxLevel=39;copy.body.switch.value[2].value=30;copy.body.switch.value[3].value=40
 local list=copy.body.rotation[3].onTrue;assert(#list==9)
 for position,id in ipairs({11565,11566})do local step=list[6+position];assert(same(step,{id='warrior-forty-known-hs-'..id,type='branch',conditions={type='SPELL_KNOWN',spell=id},onFalse={},onTrue={{id='warrior-forty-pending-hs-'..id,type='none',suppress_attack=false,conditions={type='SPELL_ACTIVE',spell=id,ranked=true}}}}))end
 table.remove(list,8);table.remove(list,7);assert(#copy.sources==#old.sources+2);for i=1,#old.sources do assert(same(copy.sources[i],old.sources[i]))end;for i=#copy.sources,#old.sources+1,-1 do table.remove(copy.sources,i)end
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('warrior-forty-',1,true)==1);v.id=v.id:gsub('warrior%-forty%-','warrior-thirty-');count=count+1 end;for _,x in pairs(v)do ids(x)end end;ids(copy.body);assert(count==16 and same(copy,old));assert(row(a).validation.valid and row(a).validation.resolved)
end)
test('four brackets autoswitch disjointly at39 40 49 50 and still require the known78 anchor',function()
 local f,s=fixture();local a=f.addon;for _,path in ipairs({'warrior-starter.lua','warrior-20-29.lua','warrior-30-39.lua'})do f.load('Defaults/tbc/'..path)end;assert(a:InitializeRotationLibrary());nativePublish(f,s);a.ScheduleRepeatingTimer=function()return 'modeled-publisher-timer'end;a.CancelTimer=function()end;a.db.profile.rotations[0]={};assert(a:InitializeRotationLibrary());a.currentRotation=nil;a.manualRotation=false;a.db.profile.disable_autoswitch=false;f.env.GetTalentTabInfo=function()error('no talent gate')end
 for _,n in ipairs({19,20,29,30,39,40,49,50})do level(f,s,n);a:UpdateAutoSwitch();a:SwitchRotation();local found={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then found[#found+1]=r.id end end;assert(#found==(n<50 and 1 or 0));if n>=40 and n<50 then assert(found[1]==ID and a.currentRotation==row(a).runtimeKey)end;assert((a:evaluateConditionResult(body(a).switch).status=='match')==(n>=40 and n<50))end
 level(f,s,40);s.known[78]=false;assert(row(a).eligible and not a:evaluateCondition(body(a).switch));a:UpdateAutoSwitch();a:SwitchRotation();assert(a.currentRotation==nil)
end)
test('class edition context enabled state and profile remain authoritative',function()
 for _,c in ipairs({{5,'PALADIN'},{2,'WARRIOR'},{1,'WARRIOR'}})do local f=fixture(c[1],c[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(r.id~=ID or not r.eligible)end end
 local f=fixture();local a=f.addon;assert(row(a).readOnly);f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible);f.env.C_PetBattles=nil;assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible);local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled);a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
end)
test('nominal40 and48 grant no ranks; actual native learning controls the publisher',function()
 local f,s=combat();local tick=nativePublish(f,s)
 for _,n in ipairs({40,47,48,49})do level(f,s,n);tick();assert(f.addon.currentSpell==78)end
 s.known[11565]=true;tick();assert(f.addon.currentSpell==11565);s.known[11566]=true;tick();assert(f.addon.currentSpell==11566);s.known[11566]=false;tick();assert(f.addon.currentSpell==11565)
end)
test('both added exact queue identities and lower11564 remain protected while higher ranks are known',function()
 local f,s=combat();allRanks(s);local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==11566)
 for _,id in ipairs({11565,11566,11564,78})do s.active=id;tick();assert(f.addon.currentSpell==6603,id);local selected,r=first(f.addon,s);assert(not selected and r.status=='stopped' and not r.suppressAttack)end
 s.active=nil;tick();assert(f.addon.currentSpell==11566)
end)
test('unlearned added ranks are not queried; unknown exact learned queue state suppresses all native publication',function()
 for _,id in ipairs({11565,11566})do local f,s=combat();local base=f.env.C_Spell.IsCurrentSpell;local calls=0;f.env.C_Spell.IsCurrentSpell=function(n)if n==id then calls=calls+1;error('selected exact queue unavailable')end;return base(n)end;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==78 and calls==0);s.known[id]=true;tick();assert(f.addon.currentSpell==nil and calls>0);s.known[id]=false;tick();assert(f.addon.currentSpell==78)end
end)
test('missing spell metadata does not erase learned exact queue guards or infer unknown ranks',function()
 for _,id in ipairs({11565,11566})do local f,s=combat();s.known[id]=true;s.metadataMissing[id]=true;s.active=id;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603);s.active=nil;tick();assert(f.addon.currentSpell==78);s.known[id]=false;s.active=id;tick();assert(f.addon.currentSpell==78)end
end)
test('native readiness mapping cooldown range and power retain learned family fallback',function()
 local f,s=combat();s.known[11565],s.known[11566]=true,true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==11566)
 for _,key in ipairs({'usable','power','range','mapped'})do s[key][11566]=key=='power';if key=='mapped'then local selected=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=selected end;tick();assert(f.addon.currentSpell==11565,key);s[key][11566]=key~='power';if key=='mapped'then local selected=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=selected end;tick();assert(f.addon.currentSpell==11566,key)end
 s.cooldown[11566]={startTime=99,duration=10,isEnabled=true,modRate=1};tick();assert(f.addon.currentSpell==11565)
end)
test('manual casts channels and encountered unreadable observations suppress direct fallback and optional upkeep',function()
 local f,s=combat();s.known[11565],s.known[11549]=true,true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==11565 and f.addon.avail_announced['warrior-forty-battle-shout']==11549)
 for _,key in ipairs({'cast','channel','castError','channelError'})do s[key]=true;tick();assert(f.addon.currentSpell==nil and not f.addon.avail_announced['warrior-forty-battle-shout'],key);s[key]=false;tick();assert(f.addon.currentSpell==11565)end
end)
test('Execute strictly below20 remains before queue checks and Shout uses only inherited ready ranks',function()
 local f,s,n=combat();s.known[11565],s.known[20658],s.known[11549]=true,true,true;local tick=nativePublish(f,s);s.targetHealth=20;tick();assert(f.addon.currentSpell==11565);s.active=11565;s.targetHealth=19;tick();assert(f.addon.currentSpell==20658 and s.active==11565);s.usable[20658]=false;tick();assert(f.addon.currentSpell==6603);assert(optional(f,s)==11549);s.buffs={{spellId=11549,name=n[11549],sourceUnit='party1'}};assert(not optional(f,s))
end)
test('current prefix short-circuit keeps a casting Stop without reaching later unavailable channel',function()
 local f,s=combat();s.cast=true;s.channelError=true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==nil);local id,r=first(f.addon,s);assert(not id and r.status=='stopped' and r.suppressAttack)
end)
test('earlier edited clone and new clone stay independent with separate bracket bounds',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/warrior-30-39.lua');assert(a:InitializeRotationLibrary());level(f,s,39);local old=assert(a:CloneDefaultRotation(0,OLD,'Old Warrior'));a:GetEditableRotation(0,old).rotation[3].onTrue[1].action=999;local snapshot=a:CopySettingsData(a:GetEditableRotation(0,old));level(f,s,40);assert(a:InitializeRotationLibrary());local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Warrior'));assert(same(snapshot,a:GetEditableRotation(0,old)));assert(not a:GetRuntimeRotation(0,old));local v=a:GetEditableRotation(0,fresh);assert(v.rotation[3].onTrue[1].action==5308 and v~=body(a));v.rotation[3].onTrue[1].action=998;assert(body(a).rotation[3].onTrue[1].action==5308)
end)
finish()
