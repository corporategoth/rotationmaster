-- WoW Forever Warlock premades: all trees (recommended), Icy Veins and Wowhead. Real predicates,
-- catalog, composition, sequence and publisher under a synthetic probe-policy Forever context;
-- WoW observations are modeled in tests/fixtures/forever_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/forever_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local DPS,IV,WH='rm.forever.warlock.dps','rm.forever.warlock.dps.icyveins','rm.forever.warlock.dps.wowhead'
local function warlock(level,...)
 local f,s=M.fixture('WARLOCK',{level=level});M.know(s,686,348,687,688,5019)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.targettarget='pet';s.pet=true
 return f,s
end
local kit={172,980,1454,1120,697,689,5676,712,706,5740,440892,1949,755}
local function first(f,s,id)return(M.first(f,s,id))end
local function dots(s,...)s.debuffs={};for _,id in ipairs({...})do s.debuffs[#s.debuffs+1]={id=id,expires=120}end end

test('one recommended premade for every tree at every level; the source variants rank below it',function()
 local f,s=warlock(1)
 for _,level in ipairs({1,30,60})do s.level=level;assert(M.selected(f,s)==DPS,'level '..level)end
 M.know(s,1293817,18708,18265);assert(M.selected(f,s)==DPS)
 local a=f.addon;assert(a:SetDefaultRotationEnabled(DPS,false));assert(M.selected(f,s)==IV);assert(a:SetDefaultRotationEnabled(IV,false));assert(M.selected(f,s)==WH)
 for _,src in ipairs(a:GetDefaultRotation(IV).envelope.sources)do assert(src.url:find('icy%-veins'),src.url)end
 for _,src in ipairs(a:GetDefaultRotation(WH).envelope.sources)do assert(src.url:find('wowhead'),src.url)end
end)

test('on the real restricted Forever client the premades are listed but never auto-selected',function()
 local f,s=M.fixture('WARLOCK',{restricted=true});M.know(s,686)
 local rows=f.addon:ListDefaultRotations(0);assert(#rows==3)
 for _,row in ipairs(rows)do assert(row.readOnly and row.builtin and not row.eligible,row.id)end
 local poll,selected=M.publisher(f,s);poll();assert(selected()==nil)
end)

test('casts, channels, a missing target and someone else\'s fight stop with Attack suppressed',function()
 for _,id in ipairs({DPS,IV,WH})do local f,s=warlock(30,kit)
  for _,key in ipairs({'cast','channel'})do s[key]=true;local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
  s.hostile=false;local x,r=M.first(f,s,id);assert(not x and r.suppressAttack);s.hostile=true
  s.combat=false;s.targetCombat=true;x,r=M.first(f,s,id);assert(not x and r.suppressAttack,'another player\'s mob');s.combat=true
  assert(first(f,s,id),id)
 end
end)

test('pull out of combat: Immolate then Agony (Destruction precasts Shadow Bolt; Wowhead opens Corruption), then stop',function()
 local f,s=warlock(10,kit);s.combat,s.targetCombat=false,false;assert(first(f,s,DPS)==348);dots(s,348);assert(first(f,s,DPS)==980)
 dots(s,348,980);local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped'and r.suppressAttack)
 dots(s);assert(first(f,s,WH)==172,'Wowhead: Corruption, no Immolate');dots(s,172);assert(first(f,s,WH)==980);dots(s,172,980);assert(first(f,s,WH)==nil)
 M.know(s,1293817);dots(s);assert(first(f,s,DPS)==686,'Destruction precast');assert(first(f,s,IV)==686);assert(first(f,s,WH)==172)
 s.known[1293817]=false;M.know(s,18708);assert(first(f,s,IV)==nil,'Icy Veins Demonology: send the pet, no Immolate')
end)

test('recommended single target: Bane, Curse, DoTs, then the solo health-gated filler',function()
 local f,s=warlock(30,kit);assert(first(f,s,DPS)==980);dots(s,980);assert(first(f,s,DPS)==348);dots(s,980,348);assert(first(f,s,DPS)==172)
 dots(s,980,348,172);assert(first(f,s,DPS)==5019,'solo at full health: the wand');s.autorepeat=true;local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped','keep wanding')
 s.autorepeat=false;s.health=60;assert(first(f,s,DPS)==689,'Drain Life when hurt');s.health=100
 s.group=true;assert(first(f,s,DPS)==440892,'group: Curse of the Elements');s.debuffs[4]={id=440892,source='party1'};assert(first(f,s,DPS)==686,'group filler: Shadow Bolt')
 s.group=false;s.debuffs[4]=nil;s.classification='elite';assert(first(f,s,DPS)==440892);s.debuffs[4]={id=704};assert(first(f,s,DPS)==5019,'your own curse already there')
 s.mana=20;s.health=90;s.debuffs[4]=nil;s.classification='normal';assert(first(f,s,DPS)==1454,'Life Tap with health to spare')
end)

test('procs and Demonology: Shadow Trance, Decimation Soul Fire and Demonic Brand come first',function()
 local f,s=warlock(50,kit,{6353,18708});dots(s,980,348,172);s.buffs={{id=17941}};assert(first(f,s,DPS)==686);s.buffs={{id=440873}};assert(first(f,s,DPS)==6353)
 s.buffs={};assert(first(f,s,DPS)==5676,'Fel Domination known: brand the target');s.debuffs[4]={id=1293696};assert(first(f,s,DPS)==5019)
 s.health=80;assert(first(f,s,DPS)==689,'Demonology solo filler: Drain Life below 90%');assert(first(f,s,WH)==689)
end)

test('Affliction and Destruction: Siphon Life on long targets, Wrack, Conflagrate before Immolate ends, Shadowburn',function()
 local f,s=warlock(40,kit,{18265,1316697});dots(s,980,348,172);assert(first(f,s,DPS)==1316697,'solo Wrack at high health');s.classification='elite'
 assert(first(f,s,DPS)==440892);s.debuffs[4]={id=440892};assert(first(f,s,DPS)==18265);s.debuffs[5]={id=18265}
 s.health=80;assert(first(f,s,DPS)==1316697);s.cooldown[1316697]={startTime=99,duration=30,isEnabled=true,modRate=1};assert(first(f,s,DPS)==689)
 local g,t=warlock(40,kit,{1293817,17877});dots(t,980,348,172,440892);t.group=true;assert(first(g,t,DPS)==686)
 t.debuffs[2].expires=102;assert(first(g,t,DPS)==1293817,'Conflagrate in the last seconds of Immolate');t.debuffs[2].expires=120
 M.know(t,412758);assert(first(g,t,DPS)==1293817,'Incinerate known: Conflagrate on cooldown');t.cooldown[1293817]={startTime=99,duration=10,isEnabled=true,modRate=1}
 assert(first(g,t,DPS)==412758);t.items[6265]=3;assert(first(g,t,DPS)==17877,'Shadowburn on cooldown with shards')
 dots(t,980,348,440892);assert(first(g,t,DPS)==17877,'Destruction skips Corruption in a group');t.group=false;assert(first(g,t,DPS)==172)
end)

test('execute below 20%: Drain Soul for shards, Shadowburn, Conflagrate, wand, then no new DoTs',function()
 local f,s=warlock(30,kit,{17877});s.targetHealth=15;assert(first(f,s,DPS)==1120);s.items[6265]=3;assert(first(f,s,DPS)==17877)
 s.cooldown[17877]={startTime=99,duration=15,isEnabled=true,modRate=1};assert(first(f,s,DPS)==5019);s.group=true
 local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped'and r.suppressAttack,'no new DoTs on a dying target')
end)

test('moving: instants only, then stop; packs: Hellfire in a group, Rain of Fire, DoTs on the target',function()
 local f,s=warlock(30,kit);s.moving=true;assert(first(f,s,DPS)==980);dots(s,980);s.mana=50;assert(first(f,s,DPS)==1454)
 s.mana=100;local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped'and r.suppressAttack,'no cast while moving')
 s.moving=false;dots(s,980,348,172);s.enemies={0,0,0};assert(first(f,s,DPS)==5740);s.group=true;assert(first(f,s,DPS)==1949,'Hellfire with a group')
 s.health=40;assert(first(f,s,DPS)==5740);s.enemies={0,0};s.group=false;s.health=100;assert(first(f,s,DPS)==5019,'two enemies: single target')
 s.enemies={0,0,0};assert(first(f,s,WH)~=5740,'Wowhead has no pack section')
end)

test('Icy Veins variant: wand first, Agony and Corruption only on targets that live, Havoc on packs',function()
 local f,s=warlock(30,kit,{18265});dots(s,348);assert(first(f,s,IV)==172,'normal mob: no Agony or Siphon Life');dots(s,348,172)
 assert(first(f,s,IV)==5019);s.health=80;assert(first(f,s,IV)==5019,'Drain Life only below 60%');s.health=50;assert(first(f,s,IV)==689)
 s.health=100;s.ttd=30;assert(first(f,s,IV)==980);dots(s,348,172,980);assert(first(f,s,IV)==18265)
 local g,t=warlock(40,kit,{1293817,1225228});dots(t,348,980);t.classification='elite';t.enemies={0,0,0};t.debuffs[3]={id=440892}
 assert(first(g,t,IV)==1225228,'Bane of Havoc on the durable enemy of a pack');t.debuffs[4]={id=1324473};assert(first(g,t,IV)==5740)
end)

test('Wowhead variant: drain-tank Affliction and Demonology, three-DoT Destruction',function()
 local f,s=warlock(30,kit);dots(s,172,980);assert(first(f,s,WH)==5019,'full health: wand');s.health=95;assert(first(f,s,WH)==689,'Drain Life until the mob dies')
 s.mana=20;assert(first(f,s,WH)==1454,'Life Tap when mana is low');s.mana=100
 M.know(s,18708);dots(s,172,1293696);assert(first(f,s,WH)==689,'Demonology Agonies only big targets');s.classification='elite';assert(first(f,s,WH)==440892)
 local g,t=warlock(30,kit,{1293817});dots(t,172,980);assert(first(g,t,WH)==348);dots(t,172,980,348);assert(first(g,t,WH)==5019,'Destruction: wand solo')
 t.debuffs[3].expires=102;assert(first(g,t,WH)==1293817)
end)

test('reminders: armor, pets by source, Fel Domination, Soul Link, Health Funnel, stones, sacrifice and Havoc',function()
 local f,s=warlock(30,kit,{19028,18708,18788,1225228,18288,6366,2362});s.pet=false;local u=M.upkeep(f,s,DPS)
 assert(u['warlock-demon-armor']==706 and not u['warlock-demon-skin'],'Demon Armor once known')
 assert(not u['warlock-summon-succubus'],'no summon in combat');assert(u['warlock-fel-domination']==18708);s.buffs={{id=18708}};u=M.upkeep(f,s,DPS)
 assert(u['warlock-summon-succubus']==712 and not u['warlock-summon-voidwalker']);u=M.upkeep(f,s,IV);assert(u['warlock-iv-summon-voidwalker']==697 and not u['warlock-iv-summon-succubus'])
 M.know(s,1293817);assert(M.upkeep(f,s,WH)['warlock-wh-summon-destro-voidwalker']==697);s.known[1293817]=false
 s.buffs={{id=706},{id=18792}};s.combat=false;assert(not M.upkeep(f,s,DPS)['warlock-summon-succubus'],'sacrificed without Pact: stay petless')
 s.level=40;assert(M.upkeep(f,s,DPS)['warlock-summon-succubus'],'Demonic Pact: summon another demon')
 s.pet=true;s.buffs={{id=706}};u=M.upkeep(f,s,DPS);assert(u['warlock-demonic-sacrifice']==18788 and u['warlock-soul-link']==19028)
 s.buffs[2]={id=25228};assert(not M.upkeep(f,s,DPS)['warlock-soul-link']);s.petHealth=20;assert(M.upkeep(f,s,DPS)['warlock-health-funnel']==755)
 u=M.upkeep(f,s,DPS);assert(u['warlock-spellstone']and not u['warlock-firestone']);M.know(s,1293817);u=M.upkeep(f,s,DPS);assert(u['warlock-firestone']and u['warlock-create-firestone'])
 s.mainEnchant=true;assert(not M.upkeep(f,s,DPS)['warlock-firestone']);s.items[1254]=1;assert(not M.upkeep(f,s,DPS)['warlock-create-firestone'])
 s.combat=true;s.enemies={0,0};assert(M.upkeep(f,s,DPS)['warlock-havoc-reminder']==1225228);s.classification='elite';assert(M.upkeep(f,s,DPS)['warlock-amplify-curse']==18288)
 s.classification='normal';assert(M.upkeep(f,s,WH)['warlock-wh-amplify-curse'],'Wowhead: on every cooldown')
end)

test('real publisher auto-selects the recommended premade and highlights',function()
 local f,s=warlock(30,kit);local poll,selected,glow=M.publisher(f,s)
 poll();assert(selected()==DPS and f.addon.currentSpell==980);dots(s,980,348,172);poll();assert(f.addon.currentSpell==5019);assert(#glow>0)
end)
finish()
