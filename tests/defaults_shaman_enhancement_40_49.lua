-- Inherit reviewed native-pipeline helpers and rank samples, not a new40s
-- spellbook, trainer schedule, talent build, priority or native acceptance.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local original=assert(read('tests/defaults_shaman_enhancement_30_39.lua'):match('^(.-)\n%-%- Removing'))
local inherited=original
for _,pair in ipairs({{'shaman-enhancement-30-39.lua','shaman-enhancement-40-49.lua'},{'Shaman.Enhancement30','Shaman.Enhancement40'},{'30–39','40–49'},{'level=30','level=40'}})do
 assert(inherited:find(pair[1],1,true),'inherited fixture anchor '..pair[1]);inherited=inherited:gsub(pair[1]:gsub('([^%w])','%%%1'),function()return pair[2]end)
end
local oldRow="local function row(a)local r=a:ListDefaultRotations(0)[1];assert(r,'missing Shaman Enhancement40–49 preview');return r end"
local newRow="local function row(a)for _,r in ipairs(a:ListDefaultRotations(0))do if r.id=='rm.tbc.shaman.enhancement.40-49'then return r end end;error('missing Shaman Enhancement40–49 preview')end"
assert(inherited:find(oldRow,1,true));inherited=inherited:gsub(oldRow:gsub('([^%w])','%%%1'),function()return newRow end)
local fixture,row,body,switch,first,upkeep,nativePublish=assert(loadstring(inherited..'\nreturn fixture,row,body,switch,first,upkeep,nativePublish','@shaman-forty-pipeline'))()
local oldFixture,oldPublish=assert(loadstring(original..'\nreturn fixture,nativePublish','@shaman-thirty-comparison'))()
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.shaman.enhancement.40-49','rm.tbc.shaman.enhancement.30-39'
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function clear(a)a.longtermCache={}end

test('whole seven-row40–49 manifest equals reviewed30–39 after only identities and bounds normalize',function()
 local f=fixture();local a=f.addon;f.load('Defaults/tbc/shaman-enhancement-30-39.lua');assert(a:InitializeRotationLibrary())
 local old=assert(a:GetDefaultRotation(OLD)).envelope;local new=assert(a:GetDefaultRotation(ID)).envelope;local normalized=a:CopySettingsData(new)
 assert(new.applicability.minLevel==40 and new.applicability.maxLevel==49 and new.nameKey=='Default.TBC.Shaman.Enhancement40.Name')
 normalized.id=OLD;normalized.nameKey=old.nameKey;normalized.descriptionKey=old.descriptionKey;normalized.applicability.minLevel=30;normalized.applicability.maxLevel=39
 local count=0;local function ids(v)if type(v)~='table'then return end;if v.id then assert(v.id:find('shaman-enhancement40-',1,true)==1);v.id=v.id:gsub('shaman%-enhancement40%-','shaman-enhancement30-');count=count+1 end;for _,child in pairs(v)do ids(child)end end
 ids(normalized.body);assert(count==7);normalized.body.switch.value[3].value=30;normalized.body.switch.value[4].value=40
 assert(equal(normalized,old),'reviewed policy changed');assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
end)
test('source eligibility and automatic gate agree at39 40 49 50 without teaching Bolt',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({39,40,49,50})do s.setLevel(level);clear(a);local yes=level>=40 and level<50;assert(row(a).eligible==yes);assert((switch(a).status=='match')==yes)end
 s.setLevel(49);s.known[403]=false;clear(a);assert(switch(a).status=='no-match');s.knownErrorID=403;assert(switch(a).status=='unavailable')
end)
test('unique positive Enhancement still gates selection and unknown facts cannot select it',function()
 local f,s=fixture();local a=f.addon
 for _,case in ipairs({{{0,21,0},'match'},{{5,16,0},'match'},{{21,0,0},'no-match'},{{0,0,21},'no-match'},{{10,10,0},'unavailable'},{{0,0,0},'unavailable'}})do s.talents=case[1];assert(switch(a).status==case[2])end
 s.talents={0,21,0};s.talentError=true;assert(switch(a).status=='unavailable');s.talentError=false;local opaque={};s.talents={0,21,opaque};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(switch(a).status=='unavailable')
end)
test('level49 never grants a new rank and actual learned mapped ready family remains authoritative',function()
 local f,s=fixture();local a=f.addon;s.setLevel(49);assert(first(a,s)==8042);s.known[10412]=true;assert(first(a,s)==10412)
 s.mapped[10412]=false;assert(first(a,s)==8042);s.power[8042]=true;assert(not first(a,s));s.power={};s.usable[8042]=false;assert(not first(a,s))
 s.usable={};s.range[8042]=false;assert(not first(a,s));s.range={};s.cooldown[8042]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(not first(a,s))
 s.cooldown={};s.combat=false;s.known[6041],s.known[10391]=true,true;assert(first(a,s)==10391);s.power[10391]=true;assert(first(a,s)==6041)
end)
test('learned Windfury owns preference while unavailable and every manual mainhand enchant is preserved',function()
 local f,s=fixture();local a=f.addon;assert(upkeep(a,s)=='8017,324');s.known[8232]=true;assert(upkeep(a,s)=='8232,324')
 for _,kind in ipairs({'mapped','usable','power','cooldown'})do
  s.mapped={};s.usable={};s.power={};s.cooldown={};if kind=='power'then s.power[8232]=true elseif kind=='cooldown'then s.cooldown[8232]={startTime=90,duration=30,isEnabled=true,modRate=1}else s[kind][8232]=false end
  assert(upkeep(a,s)=='324',kind)
 end
 s.cooldown={};s.enchanted=true;assert(upkeep(a,s)=='324');s.enchanted=1;assert(upkeep(a,s)=='324');s.enchanted=false;s.enchantError=true;assert(upkeep(a,s)=='324')
 s.enchantError=false;s.knownErrorID=8232;assert(upkeep(a,s)=='324')
end)
test('self Shield stays independent and does not mistake foreign or unavailable aura facts for own absence',function()
 local f,s,n=fixture();local a=f.addon;s.known[945],s.known[16314]=true,true;assert(upkeep(a,s)=='16314,945')
 s.buffs={{spellId=945,name=n[945],sourceUnit='player'}};assert(upkeep(a,s)=='16314');s.buffs[1].sourceUnit='party1';assert(upkeep(a,s)=='16314,945');s.auraError=true;assert(upkeep(a,s)=='16314')
end)
test('stationary ranged fallback and unengaged peaceful pull boundaries remain unchanged',function()
 local f,s=fixture();local a=f.addon;s.usable[8042]=false;assert(not first(a,s));s.near=false;assert(first(a,s)==403)
 s.moving=true;assert(not first(a,s));s.moving=false;s.combat=false;s.targetCombat=true;assert(not first(a,s));s.targetCombat=false;assert(first(a,s)==403);s.hostile=false;assert(not first(a,s))
end)
test('edition class vehicle and pet battle applicability remain independent of Enhancement points',function()
 for _,case in ipairs({{5,'MAGE'},{2,'SHAMAN'},{1,'SHAMAN'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 for _,kind in ipairs({'vehicle','petbattle'})do local f,s=fixture();s[kind]=true;assert(not row(f.addon).eligible)end
end)
test('old30–39 clones and source snapshots remain independent through new40–49 adoption',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/shaman-enhancement-30-39.lua');assert(a:InitializeRotationLibrary());s.setLevel(39)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Enhancement clone'));local old=a:GetEditableRotation(0,id);old.rotation[1].action=974;local saved=a:CopySettingsData(old)
 s.setLevel(40);clear(a);assert(a:InitializeRotationLibrary());assert(equal(a:GetEditableRotation(0,id),saved));assert(not a:GetRuntimeRotation(0,id))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Enhancement clone'));a:GetEditableRotation(0,fresh).rotation[1].action=974;assert(body(a).rotation[1].action==403);assert(equal(a:GetEditableRotation(0,id),saved))
end)
test('initialized publisher auto selects39 to40 to49 to50 and retires respec or unknown allocation',function()
 local f,s=fixture();f.load('Defaults/tbc/shaman-enhancement-30-39.lua');local tick,glow,messages=nativePublish(f,s);local a=f.addon;a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a:UpdateAutoSwitch()
 for _,level in ipairs({39,40,49,50,40})do s.setLevel(level);clear(a);a.manualRotation=false;tick();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentSpell==8042);assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID))end end
 s.talents={21,0,0};tick();assert(not a.currentRotation and not a.currentSpell);s.talents={0,21,0};tick();assert(a.currentSpell==8042);s.talentError=true;tick();assert(not a.currentRotation and not a.currentSpell);s.talentError=false;tick();assert(a.currentSpell==8042)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==8042 then found=true end end;assert(found and#glow>0)
end)
test('initialized publisher preserves independent optional reminders and real damage readiness',function()
 local f,s=fixture();s.known[8232]=true;local tick,_,messages=nativePublish(f,s);local a=f.addon;tick();assert(a.currentSpell==8042)
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_COOLDOWN_UPDATE'then seen[m[6]]=true end end;assert(seen[8232]and seen[324])
 s.enchanted=true;s.known[10412]=true;tick();assert(a.currentSpell==10412);s.usable[10412],s.usable[8042]=false,false;tick();assert(a.currentSpell~=10412 and a.currentSpell~=8042)
end)
test('manual selection retains reviewed cast channel and allocation bypass semantics without bypassing readiness',function()
 for _,kind in ipairs({'cast','channel'})do
  local f,s=fixture();local tick=nativePublish(f,s);local a=f.addon;s.talents={21,0,0};s[kind]=true;a.currentRotation='RM-BUILTIN:'..ID;a.manualRotation=true;tick()
  local g,t=oldFixture();local oldTick=oldPublish(g,t);t.talents={21,0,0};t[kind]=true;g.addon.currentRotation='RM-BUILTIN:'..OLD;g.addon.manualRotation=true;oldTick()
  assert(a.currentSpell==g.addon.currentSpell and a.currentRotation=='RM-BUILTIN:'..ID,'manual semantics changed: '..kind)
  s.usable[8042]=false;tick();assert(a.currentSpell~=8042,'manual selection bypassed readiness')
 end
end)
finish()
