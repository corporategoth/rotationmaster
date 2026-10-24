-- TBC Paladin premades: the shipped packs on the real catalog, predicates, readiness and
-- sequence executor; native APIs modeled.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local H=dofile('tests/fixtures/tbc_hybrid_premades.lua')
local RET,RIV,TWIST='rm.tbc.paladin.retribution.wowhead','rm.tbc.paladin.retribution.icyveins','rm.tbc.paladin.retribution.twist'
local PROT,PIV,HOLY,HWH='rm.tbc.paladin.protection.wowhead','rm.tbc.paladin.protection.icyveins','rm.tbc.paladin.holy','rm.tbc.paladin.holy.wowhead'
local SOR,CRUSADER,COMMAND,BLOOD,WISDOM,JUDGE,CS=21084,21082,20375,31892,20166,20271,35395
local function fixture(level,talents)
 local f,s=H.new('PALADIN');s.level=level or 70;s.talents=talents or {0,0,0}
 H.learn(f,s,6603,SOR,JUDGE,465,635);return f,s,f.addon
end
local function holyLight(id)return id==635 or id==1042 or id==27136 end
local function fight(s)s.combat=true;s.target.combat=true end
local function lit(f,s,id)local out={};for k in pairs(H.upkeep(f,s,id))do out[#out+1]=k end;table.sort(out);return table.concat(out,',')end
local function stopped(f,s,id,suppress)local spell,r=H.first(f,s,id);return spell==nil and r.status=='stopped'and(suppress==nil or r.suppressAttack==suppress)end
local RET70={CRUSADER,COMMAND,BLOOD,WISDOM,CS,26573,879,24275,20218,7294,19742,19740,19750,31884,20473}

test('seven sourced, localized, valid premades replace the manual seal/aura previews; twisting is opt-in',function()
 local f,s,a=fixture()
 for _,id in ipairs({RET,RIV,TWIST,PROT,PIV,HOLY,HWH})do
  local r=H.row(a,id);local e=r.envelope
  assert(r.validation.valid and r.validation.supported and r.validation.resolved,id)
  assert(f.translations[r.nameKey]and f.translations[r.descriptionKey],id..' localization')
  assert(#e.sources>0 and e.revision==((id==HOLY or id==HWH)and 3 or 4)and e.applicability.class=='PALADIN'and e.applicability.maxLevel==nil and e.applicability.families[1]=='tbc')
  assert(a:GetDefaultRotationComposition(id),id..' uses the shared Paladin blocks')
  assert(r.enabled==(id~=TWIST),id..' default enable state')
 end
 for _,old in ipairs({'rm.tbc.paladin.starter','rm.tbc.paladin.starter.20-29','rm.tbc.paladin.starter.30-39','rm.tbc.paladin.starter.40-49'})do assert(not a:GetDefaultRotation(old),old)end
end)
test('auto-select: Retribution by default, Protection by tree or Righteous Fury, Holy in a group, twisting when enabled',function()
 local f,s,a=fixture(5);assert(H.selected(f,s)==RET)
 for _,case in ipairs({{15,{0,0,0},false,RET},{15,{0,6,0},false,PROT},{15,{6,0,0},false,RET},{15,{6,0,0},true,HOLY},{40,{0,0,31},true,RET},{40,{10,10,0},false,RET},{70,{0,41,20},false,PROT},{70,{41,20,0},true,HOLY}})do
  s.level,s.talents,s.group=case[1],case[2],case[3];assert(H.selected(f,s)==case[4],table.concat(case[2],'/')..' chose '..tostring(H.selected(f,s)))
 end
 s.level,s.talents,s.group=30,{21,0,0},true;s.buffs={{id=25780}};assert(H.selected(f,s)==PROT,'Righteous Fury means tanking, whatever the tree')
 s.buffs={};s.talents={0,0,0};s.buffs={{id=25780}};assert(H.selected(f,s)==PROT,'even before talents');s.buffs={}
 for _,t in ipairs({{0,0,0},{0,11,0},{11,0,0},{0,0,11}})do s.talents=t
  assert(H.switch(a,RIV)==H.switch(a,RET)and H.switch(a,PIV)==H.switch(a,PROT)and H.switch(a,HWH)==H.switch(a,HOLY))
 end
 s.level,s.talents,s.group=70,{5,11,45},false;H.learn(f,s,COMMAND,BLOOD)
 assert(H.selected(f,s)==RET and H.switch(a,TWIST)=='match','twisting stays off until enabled')
 assert(a:SetDefaultRotationEnabled(TWIST,true));assert(H.selected(f,s)==TWIST)
 -- The real auto-switch filter reads the runtime body: enabling a pack that ships
 -- disabled must clear the flag there too, or it is never auto-selected.
 local key;for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==TWIST then key=r.runtimeKey end end
 local body=assert(a:GetRuntimeRotations(0)[key],'enabled twist pack is not runnable')
 assert(not body.disabled,'enabled twist pack still carries the shipped disabled flag')
 if a.GetOrderedAutoSwitchRotations then local found=false;for _,id in ipairs(a:GetOrderedAutoSwitchRotations(0,a:GetRuntimeRotations(0)))do found=found or id==key end;assert(found,'auto-switch ignores the enabled twist pack')end
 s.known[BLOOD]=nil;assert(H.selected(f,s)==RET,'twisting needs Blood or Martyr')
 assert(a:SetDefaultRotationEnabled(RET,false));assert(H.selected(f,s)==RIV)
end)
test('Retribution (Wowhead & wowsims) leveling: Crusader opener, Righteousness, Judgement of Righteousness',function()
 local f,s=fixture(10);H.learn(f,s,CRUSADER);fight(s)
 assert(H.first(f,s,RET)==CRUSADER,'open with the Crusader seal');s.buffs={{id=CRUSADER}};assert(H.first(f,s,RET)==JUDGE)
 s.buffs={};s.debuffs={{id=21183,mine=false}};assert(H.first(f,s,RET)==SOR,'then the main seal')
 s.buffs={{id=SOR}};assert(H.first(f,s,RET)==JUDGE);s.mana=0.2;assert(H.first(f,s,RET)==nil,'Judgement waits for mana: melee')
 s.mana=1;s.debuffs={};s.ttd=4;assert(H.first(f,s,RET)==JUDGE,'no opener on a target about to die')
end)
test('Retribution (Wowhead & wowsims) at 70: Blood, Crusader Strike, selective Judgement, Exorcism, Consecration',function()
 local f,s=fixture(70,{5,11,45});H.learn(f,s,unpack(RET70));fight(s);s.debuffs={{id=21183,mine=false}}
 assert(H.first(f,s,RET)==BLOOD,'best seal')
 s.buffs={{id=BLOOD}};assert(H.first(f,s,RET)==CS);s.cooldown[CS]=5;assert(H.first(f,s,RET)==JUDGE)
 s.buffs={{id=COMMAND}};assert(H.first(f,s,RET)==nil,'Command is not judged');s.debuffs[2]={id=853,mine=false};assert(H.first(f,s,RET)==JUDGE,'unless the target is stunned')
 s.debuffs={{id=21183,mine=false}};s.target.creature=6;assert(H.first(f,s,RET)==879,'Exorcism on Undead');s.target.creature=7
 s.enemies=3;assert(H.first(f,s,RET)==26573);s.mana=0.4;assert(H.first(f,s,RET)==nil,'Consecration needs mana')
 s.mana=0.5;s.debuffs={};s.buffs={{id=BLOOD}};assert(H.first(f,s,RET)==WISDOM,'Wisdom opener when mana is low')
 s.usable[24275]=true;s.mana=1;s.debuffs={{id=21183,mine=false}};s.enemies=0;s.cooldown[JUDGE]=5;assert(H.first(f,s,RET)==nil,'no Hammer of Wrath')
end)
test('Retribution (Icy Veins): Crusader opener only, Command with a slow weapon, Hammer and Judgement on cooldown',function()
 local f,s=fixture(40,{0,10,31});H.learn(f,s,CRUSADER,COMMAND,WISDOM,CS,26573,24275,20473);fight(s);s.mana=0.5
 assert(H.first(f,s,RIV)==CRUSADER and H.first(f,s,RET)==WISDOM,'opener differs by source')
 s.debuffs={{id=21183,mine=false}};assert(H.first(f,s,RIV)==COMMAND,'slow weapon: Command');s.speed=2.6;assert(H.first(f,s,RIV)==SOR,'fast weapon: Righteousness')
 s.buffs={{id=COMMAND}};s.cooldown[CS]=5;assert(H.first(f,s,RIV)==24275,'Hammer of Wrath on cooldown');s.usable[24275]=false
 assert(H.first(f,s,RIV)==JUDGE and H.first(f,s,RET)==nil,'Icy Veins judges Command too')
 s.cooldown[JUDGE]=5;s.enemies=2;assert(H.first(f,s,RIV)==26573 and H.first(f,s,RET)==nil,'Consecration from two enemies')
 s.enemies=0;assert(H.first(f,s,RIV)==20473,'offensive Holy Shock')
end)
test('Paladin Stop boundaries and Retribution upkeep',function()
 local f,s=fixture(70,{5,11,45});H.learn(f,s,unpack(RET70));fight(s)
 s.cast=true;assert(stopped(f,s,RET,true));s.cast=nil;s.target={hostile=false,health=1};assert(stopped(f,s,RET,false))
 s.target={hostile=true,health=1};s.combat=false
 assert(lit(f,s,RET)=='19742,20218','Sanctity and Wisdom');s.buffs={{id=465},{id=20217,mine=false}};assert(lit(f,s,RET)=='20218','a Devotion Aura buff is not your aura (stance)')
 s.shift(465);assert(lit(f,s,RET)=='','your aura and anyone\'s blessing are respected')
 s.bar={27149,20218};s.form=1;assert(lit(f,s,RET)=='','any rank of an aura you chose, wherever it sits on the bar');s.bar={465};s.form=0
 s.known[20218]=nil;s.buffs={};assert(lit(f,s,RET)=='7294,19742');s.health=0.5;s.shift(7294);s.buffs={{id=19742}};assert(lit(f,s,RET)=='19750','heal after the fight')
 fight(s);s.health=1;s.ttd=30;assert(lit(f,s,RET)=='31884');s.playerDebuffs={{id=25771}};assert(lit(f,s,RET)=='','never under Forbearance')
end)
test('seal twisting: opener, Command early, Blood in the last 0.4 s, hold, Crusader Strike anchor, low-mana fallback',function()
 local f,s,a=fixture(70,{5,11,45});H.learn(f,s,unpack(RET70));assert(a:SetDefaultRotationEnabled(TWIST,true))
 assert(H.first(f,s,TWIST)==CRUSADER);s.buffs={{id=CRUSADER}};assert(H.first(f,s,TWIST)==JUDGE)
 s.buffs={};s.debuffs={{id=21183,mine=false}};assert(H.first(f,s,TWIST)==COMMAND,'rank-1 Command before the pull')
 assert(H.step(H.body(a,TWIST),'twist-command').ranked==true)
 s.buffs={{id=COMMAND}};assert(stopped(f,s,TWIST,false))
 fight(s);s.swing=2;assert(stopped(f,s,TWIST,false),'hold Command until the swing window');s.swing=0.3;assert(H.first(f,s,TWIST)==BLOOD,'complete the twist')
 s.buffs={{id=BLOOD}};s.swing=3;assert(H.first(f,s,TWIST)==CS)
 s.cooldown[CS]=5;assert(H.first(f,s,TWIST)==JUDGE,'judge Blood, then prepare Command');s.cooldown[JUDGE]=8;assert(H.first(f,s,TWIST)==COMMAND)
 s.swing=1;assert(H.first(f,s,TWIST)==26573,'no time to twist: only a filler')
 s.buffs={};s.mana=0.1;assert(H.first(f,s,TWIST)==BLOOD,'low mana: roll Blood');s.buffs={{id=BLOOD}};s.cooldown={};assert(H.first(f,s,TWIST)==CS)
end)
test('Protection (Wowhead & wowsims): pull, crushing targets, Consecration, Exorcism, Judgement, Holy Shield, Avenger\'s Shield',function()
 local f,s=fixture(70,{0,41,20});H.learn(f,s,WISDOM,26573,879,20925,31935,2812,24275,25780)
 assert(H.first(f,s,PROT)==SOR,'seal first');s.buffs={{id=SOR}};assert(H.first(f,s,PROT)==20925,'Holy Shield before the pull')
 s.buffs={{id=SOR},{id=20925}};assert(H.first(f,s,PROT)==31935,'Avenger\'s Shield pull');s.cooldown[31935]=30;assert(H.first(f,s,PROT)==JUDGE)
 s.cooldown[JUDGE]=8;assert(stopped(f,s,PROT,false));s.cooldown={}
 fight(s);s.usable[24275]=false;assert(H.first(f,s,PROT)==26573);s.cooldown[26573]=8;assert(H.first(f,s,PROT)==JUDGE)
 s.target.creature=3;assert(H.first(f,s,PROT)==879,'Exorcism on Demons before Judgement');s.target.creature=7
 s.cooldown[JUDGE]=8;assert(H.first(f,s,PROT)==31935);s.target.classification='worldboss';assert(H.first(f,s,PROT)==nil and H.first(f,s,PIV)==31935,'no Avenger\'s Shield on a crushing target')
 s.buffs={{id=SOR}};s.cooldown={};assert(H.first(f,s,PROT)==20925 and H.first(f,s,PIV)~=20925,'crushing target: Holy Shield first')
 s.target.classification='normal';s.target.level=73;assert(H.first(f,s,PROT)==20925,'three levels above you crushes too')
 s.target.level=70;s.buffs={};s.enemies=3;s.mana=0.4;assert(H.first(f,s,PROT)==WISDOM)
 s.mana=0.8;assert(H.first(f,s,PROT)==SOR and H.first(f,s,PIV)==WISDOM,'Wowhead keeps Righteousness while mana lasts')
end)
test('Protection (Icy Veins): Crusader judgement when missing, Consecration first, Holy Shield after Judgement',function()
 local f,s=fixture(70,{0,41,20});H.learn(f,s,CRUSADER,WISDOM,26573,20925,31935,24275);fight(s)
 assert(H.first(f,s,PIV)==CRUSADER);s.debuffs={{id=21183,mine=false}};assert(H.first(f,s,PIV)==SOR)
 s.buffs={{id=SOR}};assert(H.first(f,s,PIV)==26573);s.cooldown[26573]=8;assert(H.first(f,s,PIV)==JUDGE)
 s.cooldown[JUDGE]=8;assert(H.first(f,s,PIV)==20925);s.buffs={{id=SOR},{id=20925}};assert(H.first(f,s,PIV)==31935)
end)
test('tank upkeep: Righteous Fury, Devotion, Sanctuary or Kings, Lay on Hands; Avenging Wrath from Wowhead',function()
 local f,s=fixture(70,{0,41,20});H.learn(f,s,25780,20911,20217,19742,633,31884)
 assert(lit(f,s,PROT)=='465,20911,25780');s.known[20911]=nil;assert(lit(f,s,PIV)=='465,20217,25780')
 s.shift(7294);s.buffs={{id=25780},{id=25899,mine=false}};assert(lit(f,s,PROT)=='')
 fight(s);s.health=0.1;assert(lit(f,s,PROT)=='633,31884'and lit(f,s,PIV)=='633')
end)
test('Holy: emergencies, Cleanse, Holy Shock while moving, Holy Light by damage, Light\'s Grace, Flash of Light; Judgement on enemies',function()
 local f,s,a=fixture(70,{41,20,0});H.learn(f,s,1042,19750,20473,633,4987,1152,WISDOM,19746,31842,20216,19742);s.group=true
 s.target={hostile=false,health=0.85};assert(H.first(f,s,HOLY)==19750 and holyLight(H.first(f,s,HWH)),'small deficit: Flash; Wowhead: Holy Light')
 s.target.health=0.95;assert(H.first(f,s,HWH)==19750 and stopped(f,s,HOLY,true))
 s.target.health=0.75;assert(H.first(f,s,HOLY)==1042,'rank-5 Holy Light for Light\'s Grace');s.buffs={{id=31834}};assert(H.first(f,s,HOLY)==19750)
 s.target.health=0.4;assert(holyLight(H.first(f,s,HOLY)),'Holy Light for heavy damage')
 assert(H.step(H.body(a,HOLY),'holy-light-grace').ranked==true)
 s.moving=true;s.target.health=0.85;assert(H.first(f,s,HOLY)==20473);s.moving=false
 s.debuffs={{id=1,dispel='Magic'}};assert(H.first(f,s,HOLY)==4987);s.known[4987]=nil;assert(H.first(f,s,HOLY)==19750,'Purify cannot remove Magic')
 s.debuffs={{id=1,dispel='Disease'}};assert(H.first(f,s,HOLY)==1152);s.debuffs={}
 fight(s);s.target.health=0.15;assert(H.first(f,s,HOLY)==633);s.cooldown[633]=600;assert(H.first(f,s,HOLY)==20473)
 s.target={hostile=true,health=1};s.buffs={};assert(H.first(f,s,HOLY)==WISDOM);s.buffs={{id=WISDOM}};assert(H.first(f,s,HOLY)==JUDGE)
 s.debuffs={{id=20186,mine=false}};assert(stopped(f,s,HOLY,true),'someone keeps Judgement of Wisdom up')
 s.target={hostile=false,health=1};s.buffs={};s.mana=0.5;assert(lit(f,s,HOLY)=='19742,19746,20216,31842');s.mana=0.9;assert(lit(f,s,HWH)=='19742,19746,20216')
end)
finish()
