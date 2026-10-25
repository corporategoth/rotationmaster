-- TBC Druid premades: the shipped packs on the real catalog, predicates, readiness and
-- sequence executor; native APIs modeled. Forms are read from their auras.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local H=dofile('tests/fixtures/tbc_hybrid_premades.lua')
local BAL,FER,FWH,RESTO='rm.tbc.druid.balance','rm.tbc.druid.feral.icyveins','rm.tbc.druid.feral.wowhead','rm.tbc.druid.restoration'
local CAT,BEAR,DIRE,TRAVEL=768,5487,9634,783
-- Forms are stances read by spell (FORM form): wear() puts the form IDs of an aura list on the modeled stance
-- bar (s.shift) and the rest on the player as buffs, so a scenario reads as the druid's state.
local FORMS={[CAT]=true,[BEAR]=true,[DIRE]=true,[TRAVEL]=true,[24858]=true,[33891]=true,[1066]=true,[33943]=true,[40120]=true}
local function wear(s,list)local rest={};s.form=0;for _,x in ipairs(list)do if FORMS[x.id]then s.shift(x.id)else rest[#rest+1]=x end end;s.buffs=rest end
local function fixture(level,talents)
 local f,s=H.new('DRUID');s.level=level or 70;s.talents=talents or {0,0,0}
 H.learn(f,s,6603,5176,8921);return f,s,f.addon
end
local function fight(s)s.combat=true;s.target.combat=true end
local function lit(f,s,id)local out={};for k in pairs(H.upkeep(f,s,id))do out[#out+1]=k end;table.sort(out);return table.concat(out,',')end
local function stopped(f,s,id,suppress)local spell,r=H.first(f,s,id);return spell==nil and r.status=='stopped'and(suppress==nil or r.suppressAttack==suppress)end
local CATKIT={CAT,BEAR,DIRE,1082,5221,1079,22568,33876,33878,5215,9005,6785,5217,16857,6807,779,33745,99,22842,29166}

test('four sourced, localized, valid premades replace the caster-only previews',function()
 local f,s,a=fixture()
 for _,id in ipairs({BAL,FER,FWH,RESTO})do
  local r=H.row(a,id);local e=r.envelope
  assert(r.validation.valid and r.validation.supported and r.validation.resolved,id)
  assert(f.translations[r.nameKey]and f.translations[r.descriptionKey],id..' localization')
  assert(#e.sources>0 and e.revision==((id==BAL or id==FWH)and 6 or 5)and r.enabled==(id~=FWH)and e.applicability.class=='DRUID'and e.applicability.maxLevel==nil and e.applicability.families[1]=='tbc')
  assert(a:GetDefaultRotationComposition(id),id..' uses the shared Druid blocks')
 end
 for _,old in ipairs({'rm.tbc.druid.caster.starter','rm.tbc.druid.caster.starter.20-29','rm.tbc.druid.caster.starter.30-39','rm.tbc.druid.caster.starter.40-49'})do assert(not a:GetDefaultRotation(old),old)end
end)
test('auto-select: Balance below 10, without talents and on ties; Feral and Restoration by tree; Icy Veins Feral first',function()
 local f,s,a=fixture(5);assert(H.selected(f,s)==BAL)
 for _,case in ipairs({{15,{0,0,0},BAL},{15,{0,6,0},FER},{15,{0,0,6},RESTO},{40,{31,0,0},BAL},{40,{10,10,0},BAL},{70,{0,47,14},FER},{70,{11,0,50},RESTO}})do
  s.level,s.talents=case[1],case[2];assert(H.selected(f,s)==case[3],table.concat(case[2],'/')..' chose '..tostring(H.selected(f,s)))
 end
 for _,talents in ipairs({{0,0,0},{0,11,0},{11,0,0},{5,5,0}})do s.talents=talents;assert(H.switch(a,FWH)==H.switch(a,FER),'Wowhead Feral shares the Feral switch')end
 -- Wowhead Feral ships disabled: with Icy Veins Feral off the Balance catch-all runs until it is enabled.
 s.level,s.talents=70,{0,47,14};assert(a:SetDefaultRotationEnabled(FER,false));assert(H.selected(f,s)==BAL)
 assert(a:SetDefaultRotationEnabled(FWH,true));assert(H.selected(f,s)==FWH)
end)
test('Balance leveling: Wrath pull, Moonfire, then Wrath; moving only instants',function()
 local f,s=fixture(8)
 assert(H.first(f,s,BAL)==5176,'Wrath pull before Starfire')
 s.moving=true;assert(H.first(f,s,BAL)==8921,'Moonfire while moving')
 s.debuffs={{id=8921}};assert(stopped(f,s,BAL),'nothing else while moving');s.moving=false;s.debuffs={}
 fight(s);s.near=false;assert(H.first(f,s,BAL)==8921);s.debuffs={{id=8921}};assert(H.first(f,s,BAL)==5176)
 s.debuffs={};s.mana=0.2;assert(H.first(f,s,BAL)==5176,'Moonfire is dropped first when mana runs short')
end)
test('Balance at 70: Starfire pull and filler, Faerie Fire in groups, Hurricane, Nature\'s Grace, Wrath in melee',function()
 local f,s=fixture(70,{40,0,21});H.learn(f,s,2912,5570,16914,770,24858,33831,29166,1126,467,16864);s.near=false
 assert(H.first(f,s,BAL)==2912,'Starfire pull from range')
 fight(s);s.debuffs={{id=8921}};assert(H.first(f,s,BAL)==2912)
 s.ttd=5;s.debuffs={};assert(H.first(f,s,BAL)==2912,'no Moonfire on a target about to die');s.ttd=nil
 s.group=true;s.debuffs={{id=8921}};assert(H.first(f,s,BAL)==770,'Faerie Fire in a group');s.debuffs={{id=8921},{id=16857,mine=false}};assert(H.first(f,s,BAL)==2912,'any Faerie Fire counts')
 s.enemies=3;assert(H.first(f,s,BAL)==16914);s.enemies=0
 s.near=true;assert(H.first(f,s,BAL)==5176,'Wrath against a target in melee');wear(s,{{id=16886}});assert(H.first(f,s,BAL)==2912,'Nature\'s Grace goes into Starfire')
 s.moving=true;wear(s,{});assert(H.first(f,s,BAL)==5570,'Insect Swarm while moving')
end)
test('Druid Stop boundaries: casts, channels and travel forms suppress Attack; Cat or Bear stops caster advice',function()
 local f,s=fixture(70,{40,0,21});fight(s)
 s.channel=true;assert(stopped(f,s,BAL,true));s.channel=nil;s.cast=true;assert(stopped(f,s,RESTO,true));s.cast=nil
 wear(s,{{id=TRAVEL}});assert(stopped(f,s,BAL,true)and stopped(f,s,FER,true))
 wear(s,{{id=CAT}});assert(stopped(f,s,BAL,false),'a Balance druid in Cat Form keeps auto-attack')
 wear(s,{});s.target={hostile=false,health=1};assert(stopped(f,s,BAL))
end)
test('Balance upkeep: Mark, Thorns while solo, Omen, Moonkin Form, Force of Nature on a long fight, Innervate',function()
 local f,s=fixture(70,{40,0,21});H.learn(f,s,24858,33831,29166,1126,467,16864)
 assert(lit(f,s,BAL)=='467,1126,16864,24858')
 wear(s,{{id=21849,mine=false},{id=467},{id=16864},{id=24858}});assert(lit(f,s,BAL)=='','Gift of the Wild covers Mark')
 wear(s,{{id=CAT}});s.group=true;assert(lit(f,s,BAL)=='1126,16864','no Moonkin reminder in Cat Form; no Thorns in a group')
 wear(s,{{id=1126},{id=16864},{id=24858}});fight(s);assert(lit(f,s,BAL)=='');s.ttd=30;assert(lit(f,s,BAL)=='33831');s.mana=0.2;assert(lit(f,s,BAL)=='29166,33831')
end)
test('Feral in caster form shifts: Bear before Cat Form is learned, Cat after; caster filler before 10',function()
 local f,s=fixture(15,{0,5,0});fight(s);s.near=true
 assert(H.first(f,s,FER)==8921,'no forms yet: Moonfire');H.learn(f,s,BEAR);assert(H.first(f,s,FER)==BEAR)
 H.learn(f,s,CAT);assert(H.first(f,s,FER)==CAT)
end)
test('Cat: stealth openers, Faerie Fire pull, Rip on a living target, bite-weave, Mangle and positional builders',function()
 local f,s=fixture(70,{0,47,14});H.learn(f,s,unpack(CATKIT));wear(s,{{id=CAT}});s.powerType=3;s.power=60
 s.stealthed=true;f.env.IsStealthed=function()return true end
 assert(H.first(f,s,FER)==9005,'Pounce from stealth');f.env.IsStealthed=function()return false end
 s.near=false;assert(H.first(f,s,FER)==16857,'Faerie Fire (Feral) pull');s.near=true
 fight(s);s.debuffs={{id=16857}};assert(H.first(f,s,FER)==33876,'Mangle when missing')
 s.debuffs={{id=16857},{id=33878,mine=false}};assert(H.first(f,s,FER)==5221,'a bear\'s Mangle counts; Shred from behind')
 s.target.targetsMe=true;assert(H.first(f,s,FER)==33876,'Mangle from the front');s.target.targetsMe=nil
 s.combo=4;assert(H.first(f,s,FER)==1079,'Rip at four points')
 s.ttd=6;assert(H.first(f,s,FER)==5221,'no Rip on a dying target; energy above 57 shreds again');s.power=40;assert(H.first(f,s,FER)==22568,'Bite instead')
 s.ttd=nil;s.debuffs={{id=16857},{id=33878},{id=1079}};assert(H.first(f,s,FER)==22568,'bite-weave while Rip runs')
 wear(s,{{id=CAT},{id=16870}});assert(H.first(f,s,FER)==5221,'Clearcasting goes into Shred, never Bite')
 assert(H.first(f,s,FWH)==5221);wear(s,{{id=CAT}});assert(H.first(f,s,FWH)==5221,'Wowhead never bite-weaves')
 s.ttd=6;assert(H.first(f,s,FWH)==22568,'Wowhead bites a target about to die')
 for _,id in ipairs({5221,1082,33876})do s.usable[id]=false end;s.ttd=nil;s.combo=0;assert(stopped(f,s,FER,false),'wait for energy with auto-attack')
 assert(H.step(H.body(f.addon,FER),'feral-icy-powershift').disabled==true,'powershifting is opt-in')
end)
test('Cat leveling: Claw before Shred and Mangle are learned, Ravage before Pounce',function()
 local f,s=fixture(30,{0,21,0});H.learn(f,s,CAT,1082,1079,5215,6785);wear(s,{{id=CAT}});s.powerType=3;s.power=60
 f.env.IsStealthed=function()return true end;assert(H.first(f,s,FER)==6785);f.env.IsStealthed=function()return false end
 fight(s);assert(H.first(f,s,FER)==1082,'Claw from behind until Shred');s.target.targetsMe=true;assert(H.first(f,s,FER)==1082)
end)
test('Bear: Faerie Fire, Lacerate save, Demoralizing Roar unless Shouted, Swipe for packs, Mangle, Lacerate stacks, filler by source',function()
 local f,s=fixture(70,{0,47,14});H.learn(f,s,unpack(CATKIT));wear(s,{{id=DIRE}});s.powerType=1;s.power=40;fight(s)
 assert(H.first(f,s,FER)==16857);s.debuffs={{id=16857}};assert(H.first(f,s,FER)==99)
 s.debuffs={{id=16857},{id=1160,mine=false}};assert(H.first(f,s,FER)==33878,'a warrior\'s Shout replaces the Roar')
 s.enemies=3;assert(H.first(f,s,FER)==779,'Swipe for three enemies');s.enemies=0
 s.cooldown[33878]=4;assert(H.first(f,s,FER)==33745,'stack Lacerate')
 s.debuffs={{id=16857},{id=1160,mine=false},{id=33745,stacks=5,remain=1}};assert(H.first(f,s,FER)==33745,'save five stacks about to drop')
 s.debuffs[3].remain=10;assert(H.first(f,s,FER)==779 and H.first(f,s,FWH)==33745,'filler: Icy Veins Swipe, Wowhead Lacerate')
end)
test('Feral upkeep: Maul for spare rage, Tiger\'s Fury before a pull, Frenzied Regeneration or Innervate by source',function()
 local f,s=fixture(70,{0,47,14});H.learn(f,s,unpack(CATKIT));wear(s,{{id=1126},{id=DIRE}});s.powerType=1;s.power=60;s.group=true
 assert(lit(f,s,FER)=='');fight(s);assert(lit(f,s,FER)=='6807');s.active=6807;assert(lit(f,s,FER)=='','Maul already queued');s.active=nil
 s.health=0.3;assert(lit(f,s,FER)=='6807,22842'and lit(f,s,FWH)=='6807','Frenzied Regeneration is an Icy Veins cooldown')
 wear(s,{{id=1126},{id=CAT}});s.powerType=3;s.power=100;s.combat=false;assert(lit(f,s,FER)=='5217','Tiger\'s Fury at full energy before a pull')
 fight(s);s.mana=0.2;assert(lit(f,s,FWH)=='29166'and lit(f,s,FER)=='','Innervate is the Wowhead variant\'s')
end)
test('Restoration: Swiftness, Swiftmend, rolling Lifebloom, HoTs, then Regrowth in Tree or Healing Touch',function()
 local f,s=fixture(70,{11,0,50});H.learn(f,s,774,8936,5185,33763,18562,17116,740,33891,20484,29166)
 s.target={hostile=false,health=0.9};wear(s,{{id=33891}})
 assert(H.first(f,s,RESTO)==774,'Rejuvenation out of combat');fight(s)
 assert(H.first(f,s,RESTO)==33763,'Lifebloom in combat');s.targetBuffs={{id=33763,stacks=3,remain=5}}
 assert(H.first(f,s,RESTO)==774);s.targetBuffs[1].remain=1;assert(H.first(f,s,RESTO)==33763,'roll before it blooms')
 s.targetBuffs={{id=33763,stacks=3,remain=5},{id=774}};s.target.health=0.75;assert(H.first(f,s,RESTO)==8936,'Regrowth HoT')
 s.targetBuffs={{id=33763,stacks=3,remain=5},{id=774},{id=8936}};s.target.health=0.6;assert(H.first(f,s,RESTO)==8936,'Regrowth filler in Tree')
 wear(s,{});s.target.health=0.45;assert(H.first(f,s,RESTO)==5185,'Healing Touch outside Tree')
 s.target.health=0.3;assert(H.first(f,s,RESTO)==18562,'Swiftmend a dying target with a HoT')
 wear(s,{{id=17116}});assert(H.first(f,s,RESTO)==5185,'Nature\'s Swiftness Healing Touch')
 wear(s,{{id=33891}});s.target.health=1;assert(stopped(f,s,RESTO,true))
 s.target={hostile=true,health=1,combat=true};assert(H.first(f,s,RESTO)==8921,'solo damage')
end)
test('Restoration upkeep: Tree of Life, Swiftness, Tranquility, Rebirth',function()
 local f,s=fixture(70,{11,0,50});H.learn(f,s,17116,740,33891,20484,1126);wear(s,{{id=1126}});s.target={hostile=false,health=1}
 assert(lit(f,s,RESTO)=='33891');wear(s,{{id=1126},{id=33891}});assert(lit(f,s,RESTO)=='')
 fight(s);s.target.health=0.2;assert(lit(f,s,RESTO)=='17116');s.party={0.5,0.4,0.3};assert(lit(f,s,RESTO)=='740,17116')
 s.target.dead=true;s.target.health=0;s.party={};assert(lit(f,s,RESTO)=='17116,20484')
end)
finish()
