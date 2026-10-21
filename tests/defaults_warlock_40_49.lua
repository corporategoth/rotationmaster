-- Reuse reviewed actual-pipeline helpers/rank samples, not a new40s spellbook,
-- trainer schedule, build, optimal priority or native gameplay acceptance.
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local inherited=assert(read('tests/defaults_warlock_30_39.lua'):match('^(.-)\ntest%('))
for _,pair in ipairs({{'warlock-30-39.lua','warlock-40-49.lua'},{'rm.tbc.warlock.starter.30-39','rm.tbc.warlock.starter.40-49'},{'Warlock.Thirties','Warlock.Forties'},{'30–39','40–49'},{'s.level=30','s.level=40'}})do
 assert(inherited:find(pair[1],1,true),'inherited fixture anchor '..pair[1]);inherited=inherited:gsub(pair[1]:gsub('([^%w])','%%%1'),function()return pair[2]end)
end
local make,row,body,first,dots,optional,nativePublish=assert(loadstring(inherited..'\nreturn fixture,row,body,first,dots,optional,nativePublish','@warlock-forty-pipeline'))()
local function fixture(...)
 local f,s,n=make(...);f.load('Core/rotation_selection.lua')
 f.addon.ScheduleTimer=function(_,callback)return callback end
 s.setLevel=function(level)s.level=level;f.addon:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 return f,s,n
end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.warlock.starter.40-49','rm.tbc.warlock.starter.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('complete fourteen-row40–49 manifest is reviewed30–39 after only identities and bounds normalize',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/warlock-30-39.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID)).envelope;local normalized=a:CopySettingsData(new)
 assert(new.applicability.minLevel==40 and new.applicability.maxLevel==49 and new.nameKey=='Default.TBC.Warlock.Forties.Name')
 normalized.id=OLD;normalized.nameKey=old.nameKey;normalized.descriptionKey=old.descriptionKey;normalized.applicability.minLevel=30;normalized.applicability.maxLevel=39
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('warlock-forties-',1,true)==1);v.id=v.id:gsub('warlock%-forties%-','warlock-thirties-');count=count+1 end;for _,child in pairs(v)do ids(child)end end
 ids(normalized.body);assert(count==14);normalized.body.switch.value[2].value=30;normalized.body.switch.value[3].value=40
 assert(equal(normalized,old),'reviewed manifest policy changed');assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
end)
test('39 40 49 50 source and switch boundaries agree and never grant learned Bolt',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({39,40,49,50})do s.setLevel(level);clear(a);local yes=level>=40 and level<50;assert(row(a).eligible==yes);assert((a:evaluateConditionResult(body(a).switch).status=='match')==yes)end
 s.setLevel(49);s.known[686]=false;clear(a);assert(a:evaluateConditionResult(body(a).switch).status=='no-match')
 local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==686 then return nil end;return known(id)end;assert(a:evaluateConditionResult(body(a).switch).status=='unavailable')
end)
test('class edition context and specialization scope stay explicit without an invented Affliction gate',function()
 for _,case in ipairs({{5,'MAGE'},{2,'WARLOCK'},{1,'WARLOCK'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 for _,kind in ipairs({'vehicle','petbattle'})do local f=fixture();if kind=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end;assert(not row(f.addon).eligible)end
 local f=fixture();local a=f.addon;assert(row(a).envelope.applicability.specs==nil)
 for _,number in ipairs({0,1,2})do local found=false;for _,r in ipairs(a:ListDefaultRotations(number))do if r.id==ID then found=true;assert(r.eligible)end end;assert(found)end
 local calls=0;f.env.GetNumTalentTabs=function()calls=calls+1;error('no allocation observed')end
 f.env.C_SpecializationInfo={GetSpecializationInfo=function()calls=calls+1;error('no allocation observed')end}
 assert(a:evaluateConditionResult(body(a).switch).status=='match'and calls==0,'Affliction became a talent requirement')
end)
test('level49 adds no rank or Siphon and retains owned DoT order with actual trained families',function()
 local f,s,n=fixture();local a=f.addon;s.setLevel(49);s.known[172],s.known[980]=true,true
 assert(first(a,s)==348);s.known[2941]=true;assert(first(a,s)==2941)
 s.debuffs={{spellId=2941,name=n[2941],sourceUnit='player'}};assert(first(a,s)==172);s.debuffs[#s.debuffs+1]={spellId=7648,name=n[7648],sourceUnit='player'};assert(first(a,s)==980)
 dots(s,n);assert(first(a,s)==686);s.known[7641]=true;assert(first(a,s)==7641);s.mapped[7641]=false;assert(first(a,s)==686)
 s.known[18265],s.known[18879]=true,true;assert(first(a,s)==18879);s.mapped[18879]=false;assert(first(a,s)==18265)
end)
test('optional learned Siphon never bypasses mapping power cooldown usability range or unknown facts',function()
 for _,kind in ipairs({'mapping','power','cooldown','usability','range'})do local f,s,n=fixture();s.known[18265]=true;dots(s,n)
  if kind=='mapping'then s.mapped[18265]=false elseif kind=='power'then s.power[18265]=true elseif kind=='cooldown'then s.cooldown[18265]={startTime=99,duration=30,isEnabled=true,modRate=1}elseif kind=='usability'then s.usable[18265]=false else s.range[18265]=false end
  assert(first(f.addon,s)==686,kind)
 end
 local f,s,n=fixture();dots(s,n);s.known[18265]=true;s.auraError=true;assert(first(f.addon,s)==686);s.auraError=false;s.metadataMissing[18265]=true;assert(first(f.addon,s)==686)
 f,s,n=fixture();dots(s,n);local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==18265 or id==18879 then return nil end;return known(id)end;assert(first(f.addon,s)==686)
end)
test('localized own Siphon is maintained while foreign attribution never satisfies it',function()
 local f,s,n=fixture();s.known[18265]=true;dots(s,n,true);assert(first(f.addon,s)==686)
 s.debuffs[4].sourceUnit='party1';assert(first(f.addon,s)==18265);s.debuffs[4].sourceUnit='player';s.debuffs[4].name='Other name';assert(first(f.addon,s)==18265)
 s.moving=true;s.debuffs={};assert(first(f.addon,s)==18265,'existing instant Siphon predicate changed')
end)
test('active or unavailable channel stops ready damage and suppresses implicit attack',function()
 local f,s=fixture();s.channel=true;local id,result=first(f.addon,s);assert(not id and result.status=='stopped'and result.suppressAttack)
 f.env.UnitChannelInfo=function()error('channel unavailable')end;id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
end)
test('inherited70percent drain and active or unavailable wand guards keep their ordering',function()
 local f,s,n=fixture();local a=f.addon;dots(s,n,true);s.known[18265],s.known[689],s.known[5019]=true,true,true;s.combat=true;s.health=69;s.repeatActive=true
 assert(first(a,s)==689);s.health=70;local id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack)
 s.repeatError=true;id,result=first(a,s);assert(not id and result.status=='unavailable'and result.suppressAttack);s.known[5019]=false;assert(first(a,s)==686)
end)
test('target pull motion and exhausted ranged choices never create implicit melee advice',function()
 local f,s=fixture();local a=f.addon;s.targetCombat=true;assert(not first(a,s));s.combat=true;assert(first(a,s)==348)
 s.hostile=false;assert(not first(a,s));s.hostile=true;s.dead=true;assert(not first(a,s));s.dead=false;s.exists=false;assert(not first(a,s));s.exists=true
 s.moving=true;local id,result=first(a,s);assert(not id and result.suppressAttack);s.moving=false;s.mapped[348],s.mapped[686]=false,false;id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack)
end)
test('learned Demon Armor owns preference even unready and preserves any active family aura',function()
 for _,kind in ipairs({'mapping','power','cooldown','usability'})do local f,s=fixture();s.known[706]=true
  if kind=='mapping'then s.mapped[706]=false elseif kind=='power'then s.power[706]=true elseif kind=='cooldown'then s.cooldown[706]={startTime=99,duration=30,isEnabled=true,modRate=1}else s.usable[706]=false end
  assert(#optional(f,s)==0,kind);assert(first(f.addon,s)==348)
 end
 local f,s,n=fixture();assert(optional(f,s)[1]==687);s.known[706],s.known[1086]=true,true;assert(optional(f,s)[1]==1086)
 s.buffs={{spellId=1086,name=n[1086],sourceUnit='party1'}};assert(#optional(f,s)==0);s.buffs={};s.auraError=true;assert(#optional(f,s)==0)
 s.auraError=false;local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==706 then return nil end;return known(id)end;assert(#optional(f,s)==0)
end)
test('initialized publisher auto selects39 to40 to49 to50 and retires unknown or unlearned Bolt',function()
 local f,s=fixture();f.load('Defaults/tbc/warlock-30-39.lua');local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a.db.profile.disable_autoswitch=false;a.manualRotation=false
 local function poll()a:UpdateAutoSwitch();a:SwitchRotation();tick()end
 for _,level in ipairs({39,40,49,50,40})do s.setLevel(level);clear(a);poll();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID));assert(a.currentSpell==348)end end
 s.known[686]=false;poll();assert(not a.currentRotation and not a.currentSpell);s.known[686]=true;poll();assert(a.currentSpell==348)
 local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==686 then return nil end;return known(id)end;poll();assert(not a.currentRotation and not a.currentSpell)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==348 then found=true end;assert(m[6]~=6603)end;assert(found and#glow>0)
end)
test('initialized Siphon rank and independent Armor publication honor maintenance and readiness',function()
 local f,s,n=fixture();s.known[18265],s.known[18879],s.known[706]=true,true,true;dots(s,n);local tick,glow,messages=nativePublish(f,s);local a=f.addon;tick();assert(a.currentSpell==18879)
 assert(a.avail_announced['warlock-forties-armor']==706 and a.avail_announced['warlock-forties-skin']==nil)
 dots(s,n,true);tick();assert(a.currentSpell==686);s.buffs={{spellId=706,name=n[706],sourceUnit='player'}};tick();assert(a.avail_announced['warlock-forties-armor']==nil)
 s.channel=true;tick();assert(not a.currentSpell);local found=false;for _,call in ipairs(glow)do if call[1]==18879 then found=true end end;assert(found and#messages>0)
end)
test('manual selection retains cast next-action policy but channel and readiness remain authoritative',function()
 local f,s=fixture();local tick=nativePublish(f,s);local a=f.addon;a.currentRotation='RM-BUILTIN:'..ID;a.manualRotation=true;s.known[686]=false;s.casting=true;tick();assert(a.currentSpell==348,'new cast or learned-switch Stop was invented')
 s.channel=true;tick();assert(not a.currentSpell);s.channel=false;local channel=f.env.UnitChannelInfo;f.env.UnitChannelInfo=function()error('unavailable')end;tick();assert(not a.currentSpell)
 f.env.UnitChannelInfo=channel;s.mapped[348],s.mapped[686]=false,false;a:Fetch();tick();assert(not a.currentSpell,'manual selection bypassed readiness or exhausted Stop')
end)
test('saved30–39 clones and readonly sources stay independent through new40–49 adoption',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/warlock-30-39.lua');assert(a:InitializeRotationLibrary());s.setLevel(39);clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Warlock clone'));local old=a:GetEditableRotation(0,id);old.rotation[1].onTrue[1].suppress_attack=false;local saved=a:CopySettingsData(old)
 s.setLevel(40);clear(a);assert(not a:GetRuntimeRotation(0,id));assert(equal(a:GetEditableRotation(0,id),saved))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Warlock clone'));a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].suppress_attack=false;assert(body(a).rotation[1].onTrue[1].suppress_attack);assert(equal(a:GetEditableRotation(0,id),saved))
end)
finish()
