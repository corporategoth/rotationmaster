-- WoW Forever Shaman premades: Restoration, Elemental, Enhancement (recommended default) and
-- Enhancement mana-efficient (Wowhead). Real predicates, catalog, composition, sequence and
-- publisher under a synthetic probe-policy Forever context; WoW observations are modeled in
-- tests/fixtures/forever_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/forever_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local RESTO,ELE,ENH,WH='rm.forever.shaman.restoration','rm.forever.shaman.elemental','rm.forever.shaman.enhancement','rm.forever.shaman.enhancement.wowhead'
local function shaman(level,...)
 local f,s=M.fixture('SHAMAN',{level=level});M.know(s,6603,403,331,8017)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.range[6603]=true
 return f,s
end
local leveling={8042,324,8050,8024,3599,408341,5730}
local deep={17364,408510,8190,8232,8075,5675,8512,425336}
local function first(f,s,id)return(M.first(f,s,id))end
local function cd(s,id)s.cooldown[id]={startTime=99,duration=6,isEnabled=true,modRate=1}end

test('the deep talent spell picks the premade: Mana Tide, then Lava Burst, else Enhancement at any level',function()
 local f,s=shaman(1)
 for _,level in ipairs({1,30,60})do s.level=level;assert(M.selected(f,s)==ENH,'level '..level)end
 M.know(s,408490);assert(M.selected(f,s)==ELE);M.know(s,16190);assert(M.selected(f,s)==RESTO,'Mana Tide outranks Lava Burst')
 s.known[408490]=false;assert(M.selected(f,s)==RESTO);s.known[16190]=false
 local a=f.addon;assert(a:SetDefaultRotationEnabled(ENH,false));assert(M.selected(f,s)==WH,'the Wowhead variant runs only when chosen')
 s.level=24;M.know(s,408490);assert(M.selected(f,s)==WH,'Elemental starts at 25 (30, or 25 with Legacy points)')
end)

test('on the real restricted Forever client the premades are listed but incomplete, never auto-selected',function()
 local f,s=M.fixture('SHAMAN',{restricted=true});local support=dofile('tests/fixtures/client_support.lua');support.install(f);M.know(s,6603,403,16190)
 local rows=f.addon:ListDefaultRotations(0);assert(#rows==4)
 for _,row in ipairs(rows)do assert(row.readOnly and row.builtin,row.id);support.incomplete(row)end
 local poll,selected=M.publisher(f,s);poll();assert(selected()==nil)
end)

test('casts, channels and Ghost Wolf stop with Attack suppressed; a missing target ends advice',function()
 for _,id in ipairs({ENH,WH,ELE})do local f,s=shaman(40,leveling,deep,{408490})
  for _,key in ipairs({'cast','channel'})do s[key]=true;local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
  for _,wolf in ipairs({2645,415233,1238640})do s.buffs={{id=wolf}};local x,r=M.first(f,s,id);assert(not x and r.suppressAttack,'Ghost Wolf '..wolf)end
  s.buffs={};s.hostile=false;local x,r=M.first(f,s,id);assert(not x and r.suppressAttack);s.hostile=true;assert(first(f,s,id),id)
 end
 local f,s=shaman(40,{16190,408521});s.friend,s.hostile=true,false;s.cast=true;local x,r=M.first(f,s,RESTO);assert(not x and r.suppressAttack)
end)

test('out of combat only a stationary ranged Lightning Bolt pull is offered, then advice stops',function()
 for _,id in ipairs({ENH,WH})do local f,s=shaman(10,leveling);s.combat=false
  local x,r=M.first(f,s,id);assert(id==WH and x==8042 or not x and r.status=='stopped','in melee range: no Bolt pull (Wowhead shocks)')
  s.range[6603]=false;assert(first(f,s,id)==403);s.moving=true;assert(first(f,s,id)~=403)
 end
 local f,s=shaman(10,leveling);s.combat=false;s.range[6603]=false;s.nopower[403]=true;assert(first(f,s,WH)==8042,'Wowhead: or a shock')
end)

test('Enhancement while leveling: Earth Shock on cooldown, melee, Lightning Bolt only out of reach',function()
 local f,s=shaman(8,{8042});assert(first(f,s,ENH)==8042);cd(s,8042);local x,r=M.first(f,s,ENH);assert(not x and r.status=='complete','melee: Attack')
 s.range[6603]=false;assert(first(f,s,ENH)==403);s.moving=true;assert(first(f,s,ENH)==nil)
end)

test('Enhancement with the full kit: Stormstrike, Maelstrom Bolt, Stormstrike Earth Shock, mana floor',function()
 local f,s=shaman(40,leveling,deep);assert(first(f,s,ENH)==17364);cd(s,17364)
 s.buffs={{id=408505,stacks=4}};assert(first(f,s,ENH)==8042);s.buffs[1].stacks=5;assert(first(f,s,ENH)==403,'five Maelstrom stacks')
 s.buffs={};s.debuffs={{id=17364}};assert(first(f,s,ENH)==8042);s.debuffs={}
 s.mana=35;local x,r=M.first(f,s,ENH);assert(not x and r.status=='stopped'and not r.suppressAttack,'below 40% mana: melee only')
 s.debuffs={{id=17364}};assert(first(f,s,ENH)==8042,'a Stormstrike debuff is still spent');s.debuffs={}
 s.mana=100;s.group=true;s.ttd=30;assert(first(f,s,ENH)==8050,'group: Flame Shock on a target that lives');s.debuffs={{id=8050}};assert(first(f,s,ENH)==8042)
end)

test('single target vs packs: Fire Nova at a Fire totem and Flame Shock on three engaged enemies',function()
 local f,s=shaman(40,leveling,deep);cd(s,17364);cd(s,8042);s.enemies={0,0,0}
 assert(first(f,s,ENH)==8050,'no Fire totem: Flame Shock');s.totems[1]=20;assert(first(f,s,ENH)==408341)
 s.enemies={0,0};local x,r=M.first(f,s,ENH);assert(not x and r.status=='complete','two enemies: single target')
 s.enemies={0,0,0};assert(first(f,s,WH)==408341,'Wowhead: Fire Nova on packs');s.totems[1]=nil;s.group=true;assert(first(f,s,WH)~=408341)
 s.totems[1]=20;s.enemies={};assert(first(f,s,WH)==408341,'Wowhead: and in groups')
end)

test('Wowhead variant: Stormstrike only to fish for the mana buff, never a rotational Earth Shock',function()
 local f,s=shaman(40,leveling,deep);assert(first(f,s,WH)==17364);s.buffs={{id=1238931}};local x,r=M.first(f,s,WH);assert(not x and r.status=='complete')
 s.debuffs={{id=17364}};assert(first(f,s,WH)==nil,'no Earth Shock into the debuff')
 local u=M.upkeep(f,s,WH);assert(not u['shaman-wh-searing-totem']);s.group=true;assert(M.upkeep(f,s,WH)['shaman-wh-searing-totem']==3599)
end)

test('Enhancement reminders: imbue preference, shields, interrupt, totems, Rage of the Farseer, Stoneclaw and heals',function()
 local f,s=shaman(10,leveling);local u=M.upkeep(f,s,ENH);assert(u['shaman-enh-flametongue-weapon']==8024 and not u['shaman-enh-rockbiter-weapon'],'Flametongue once known')
 s.known[8024]=false;assert(M.upkeep(f,s,ENH)['shaman-enh-rockbiter-weapon']==8017);s.known[8024]=true;M.know(s,8232);s.usable[8232]=false
 u=M.upkeep(f,s,ENH);assert(not u['shaman-enh-flametongue-weapon']and not u['shaman-enh-windfury-weapon'],'an unusable Windfury never licenses a lower imbue')
 s.usable[8232]=nil;assert(M.upkeep(f,s,ENH)['shaman-enh-windfury-weapon']==8232);s.mainEnchant=true;assert(not M.upkeep(f,s,ENH)['shaman-enh-windfury-weapon'])
 assert(M.upkeep(f,s,ENH)['shaman-enh-lightning-shield']==324);s.mana=40;assert(not M.upkeep(f,s,ENH)['shaman-enh-lightning-shield'],'in combat only with half mana')
 s.combat=false;assert(M.upkeep(f,s,ENH)['shaman-enh-lightning-shield']);s.combat=true;s.mana=100
 M.know(s,408510);u=M.upkeep(f,s,ENH);assert(u['shaman-enh-water-shield']==408510 and not u['shaman-enh-lightning-shield'])
 s.buffs={{id=324}};assert(not M.upkeep(f,s,ENH)['shaman-enh-water-shield'],'a shield is up')
 assert(not u['shaman-enh-interrupt']);s.targetCast='Heal';assert(M.upkeep(f,s,ENH)['shaman-enh-interrupt']==8042)
 assert(not u['shaman-enh-searing-totem']);s.classification='elite';assert(M.upkeep(f,s,ENH)['shaman-enh-searing-totem']==3599);s.totems[1]=20
 assert(not M.upkeep(f,s,ENH)['shaman-enh-searing-totem']);s.totems[1]=nil;s.classification='normal';s.ttd=25;assert(M.upkeep(f,s,ENH)['shaman-enh-searing-totem'])
 M.know(s,8190);s.enemies={0,0,0};u=M.upkeep(f,s,ENH);assert(u['shaman-enh-magma-totem']==8190 and not u['shaman-enh-searing-totem'])
 s.mana=40;u=M.upkeep(f,s,ENH);assert(not u['shaman-enh-magma-totem']and u['shaman-enh-searing-totem'],'Magma only with half mana')
 assert(u['shaman-enh-stoneclaw-totem']==5730);s.group=true;assert(not M.upkeep(f,s,ENH)['shaman-enh-stoneclaw-totem'])
 M.know(s,8075,5675,8512);u=M.upkeep(f,s,ENH);assert(u['shaman-enh-strength-of-earth']and u['shaman-enh-mana-spring']and u['shaman-enh-windfury-totem'])
 s.totems[2]=200;assert(not M.upkeep(f,s,ENH)['shaman-enh-strength-of-earth']);s.group=false
 M.know(s,425336);assert(M.upkeep(f,s,ENH)['shaman-enh-rage-of-the-farseer']);s.enemies={}
 s.health=30;assert(M.upkeep(f,s,ENH)['shaman-enh-healing-wave']==331);s.health=60;assert(not M.upkeep(f,s,ENH)['shaman-enh-healing-wave'])
 s.combat=false;assert(M.upkeep(f,s,ENH)['shaman-enh-healing-wave'],'top up between pulls')
end)

test('Elemental: pull, instants while moving, packs, Flame Shock on long targets, Lava Burst, hybrid Stormstrike, mana floor',function()
 local f,s=shaman(40,leveling,{408490,421,16166});s.combat=false;assert(first(f,s,ELE)==403);s.moving=true
 local x,r=M.first(f,s,ELE);assert(not x and r.suppressAttack,'moving: no pull cast');s.moving=false;s.combat=true
 assert(first(f,s,ELE)==408490,'solo normal mob: no Flame Shock');s.classification='elite';assert(first(f,s,ELE)==8050);s.debuffs={{id=8050}}
 assert(first(f,s,ELE)==408490);cd(s,408490);assert(first(f,s,ELE)==403)
 s.moving=true;assert(first(f,s,ELE)==nil,'moving: Flame Shock is up, target is not dying');s.ttd=2;assert(first(f,s,ELE)==8042);s.debuffs={};assert(first(f,s,ELE)==8050)
 s.moving=false;s.ttd=nil;s.debuffs={{id=8050}};s.enemies={0,0,0};assert(first(f,s,ELE)==421,'no Fire totem: Chain Lightning');s.totems[1]=20;assert(first(f,s,ELE)==408341)
 s.enemies={};M.know(s,17364);assert(first(f,s,ELE)==17364,'Stormcaller hybrid in melee');s.range[6603]=false;assert(first(f,s,ELE)==403);s.range[6603]=true;cd(s,17364)
 s.group=true;s.buffs={{id=16246}};assert(first(f,s,ELE)==408341,'Clearcasting Fire Nova in a group');s.group=false
 s.mana=20;local y,q=M.first(f,s,ELE);assert(not y and q.status=='stopped'and not q.suppressAttack,'melee to save mana');s.range[6603]=false;assert(first(f,s,ELE)==403)
 local u=M.upkeep(f,s,ELE);assert(u['shaman-ele-elemental-mastery']==16166)
end)

test('Restoration heals the friendly target and helps with damage otherwise',function()
 local f,s=shaman(40,leveling,{16190,408521,16188,8004,1064,526,2870,17364});s.friend,s.hostile=true,false;s.targetHealth=95
 local x,r=M.first(f,s,RESTO);assert(not x and r.status=='stopped'and r.suppressAttack,'nobody needs healing')
 s.targetHealth=80;assert(first(f,s,RESTO)==408521);s.targetBuffs={{id=408521}};assert(first(f,s,RESTO)==331)
 s.targetBuffs[1].source='party1';assert(first(f,s,RESTO)==408521,'another Shaman\'s Riptide');s.targetBuffs={{id=408521}}
 s.targetHealth=35;assert(first(f,s,RESTO)==8004);s.targetHealth=20;assert(first(f,s,RESTO)==16188);s.buffs={{id=16188}};assert(first(f,s,RESTO)==331,'instant Healing Wave')
 s.buffs={};s.debuffs={{id=1,dispel='Poison',source='nameplate1'}};s.targetHealth=100;assert(first(f,s,RESTO)==526);s.debuffs[1].dispel='Disease';assert(first(f,s,RESTO)==2870)
 s.friend,s.hostile,s.debuffs=false,true,{};assert(first(f,s,RESTO)==17364,'Wavebreaker: Stormstrike');cd(s,17364);s.debuffs={{id=17364}};assert(first(f,s,RESTO)==8042)
 s.debuffs={};s.classification='elite';assert(first(f,s,RESTO)==8050);s.debuffs={{id=8050}};assert(first(f,s,RESTO)==403)
 s.hostile=false;local y,q=M.first(f,s,RESTO);assert(not y and q.suppressAttack)
 local u=M.upkeep(f,s,RESTO);assert(not u['shaman-resto-mana-tide']);s.group,s.mana=true,50;assert(M.upkeep(f,s,RESTO)['shaman-resto-mana-tide']==16190)
end)

test('real publisher auto-selects by talent spell and highlights',function()
 local f,s=shaman(40,leveling,deep);local poll,selected,glow=M.publisher(f,s)
 poll();assert(selected()==ENH and f.addon.currentSpell==17364);M.know(s,408490);poll();assert(selected()==ELE);assert(#glow>0)
end)
finish()
