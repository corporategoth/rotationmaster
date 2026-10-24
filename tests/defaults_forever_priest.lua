-- WoW Forever Priest premades: switches, priorities, boundaries and reminders through the real
-- catalog, predicates, composition and sequence executor on a modeled Forever client (probe policy;
-- the last test keeps the real restricted policy).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/forever_premade_model.lua')
local DPS,DOT,HEAL='rm.forever.priest.dps','rm.forever.priest.dps.mobalytics','rm.forever.priest.healer'
local unpack=unpack or table.unpack
local function priest(level)
 local f,s=M.new('priest');local a=f.addon
 s.setLevel(level or 60);s.targetRange={25,28}
 s.ranged(585,589,8092,2944,1309595,15407,14914,402174,5019,15237,17,139,2061,2054,2050,2060,596,401937,401859,527,552,528)
 return a,s,f
end
local shadowKit={585,589,8092,2944,1309595,15407,15473,17,5019,2061,2054}
test('the Priest premades load, validate and declare Forever only',function()
 local a=priest();local rows=M.rows(a)
 for _,id in ipairs({DPS,DOT,HEAL})do
  local row=assert(rows[id],id);local scope=row.applicability
  assert(row.readOnly and row.builtin and scope.families[1]=='forever'and #scope.families==1 and scope.class=='PRIEST'and scope.maxLevel==60,id)
  local variant=id==DOT
  assert(row.eligible==not variant,id..(variant and ' variant is not off by default' or ' not eligible on the probe Forever context'))
  assert((row.envelope.body.disabled==true)==variant,id..' disabled flag')
 end
end)
test('switch by talent tree (1 Discipline, 2 Holy, 3 Shadow): damage by default; a grouped Discipline or Holy Priest without Shadowform heals',function()
 local a,s=priest(1);s.learn(585);assert(M.selected(a)==DPS,'level 1')
 s.setLevel(20);s.setTrees({0,11,0});s.learn(15237);assert(M.selected(a)==DPS,'solo Holy levels as damage')
 s.group=true;assert(M.selected(a)==HEAL,'grouped Holy main tree heals')
 s.setTrees({11,0,0});s.known[15237]=nil;assert(M.selected(a)==HEAL,'a Discipline healer at 20, before Penance, heals')
 s.setTrees({0,0,11});s.learn(1316995);assert(M.selected(a)==DPS,'Shadow main tree with a Penance known stays damage')
 s.setTrees({5,5,0});assert(M.selected(a)==DPS,'a tie stays damage')
 s.setTrees({0,21,0});s.learn(15473);assert(M.selected(a)==DPS,'Shadowform known: never the healer')
 assert(M.switch(a,DOT)=='match','the Mobalytics variant shares the catch-all switch')
 s.known={};s.group=false;s.setTrees({0,0,0});assert(M.selected(a)==DPS,'a Priest with nothing learned still gets a premade')
end)
test('damage: boundaries, Shadowform, the pull; no solo emergency branch (health is secret)',function()
 local a,s=priest();s.learn(unpack(shadowKit))
 s.cast=true;M.expect(a,s,DPS,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,DPS,nil,'stopped','channelling');s.buff('player',15473);M.expect(a,s,DPS,8092,nil,'clip Mind Flay for Mind Blast in Shadowform')
 s.cooling(8092,5);M.expect(a,s,DPS,nil,'stopped','keep channelling while Mind Blast cools');s.cooldown={};s.channel=false;s.clearAuras()
 M.expect(a,s,DPS,15473,nil,'Shadowform when learned and off');s.buff('player',15473)
 s.combat=false;M.expect(a,s,DPS,17,nil,'solo pull: Shield');s.debuff('player',6788);M.expect(a,s,DPS,8092,nil,'then Mind Blast')
 s.known[15473]=nil;s.learn(14914);s.clearAuras();s.debuff('player',6788);M.expect(a,s,DPS,14914,nil,'no Shadowform talent: Holy Fire pull');s.combat=true
 s.clearAuras();s.health.player=30;M.expect(a,s,DPS,8092,nil,'health is secret: no emergency Shield or heal, the priority runs')
end)
test('damage: DoTs, Mind Blast, solo wand and Shadowform filler',function()
 local a,s=priest(30);s.learn(585,589,8092,2944,15407,5019,1309595)
 M.expect(a,s,DPS,8092,nil,'Mind Blast');s.cooling(8092,6)
 M.expect(a,s,DPS,589,nil,'own Pain');s.debuff('target',589)
 M.expect(a,s,DPS,2944,nil,'own Plague');s.debuff('target',2944)
 M.expect(a,s,DPS,5019,nil,'solo: the wand after the DoTs (mana is secret, so no solo Mind Flay)');s.repeatActive=true;local r=M.expect(a,s,DPS,nil,'stopped','wand running');s.repeatActive=false
 s.health.target=15;s.cooldown={};M.expect(a,s,DPS,8092,nil,'target health is secret: no execute, Mind Blast at any health');s.cooling(8092,6)
 s.health.target=100;s.clearAuras();s.mana.player=30;s.debuff('target',589);M.expect(a,s,DPS,2944,nil,'Plague at any mana');s.debuff('target',2944)
 s.learn(15473);s.buff('player',15473);M.expect(a,s,DPS,15407,nil,'Shadowform filler: Mind Flay')
 s.moving=true;s.clearAuras();s.buff('player',15473);M.expect(a,s,DPS,589,nil,'moving: Pain')
end)
test('damage: Discipline Holy Fire into Penance, Holy Nova on packs, group filler',function()
 local a,s=priest(30);s.learn(585,589,8092,14914,402174,15237,15407);s.debuff('target',589);s.cooling(8092,6)
 M.expect(a,s,DPS,14914,nil,'Penance known: Holy Fire first');s.debuff('target',14914)
 M.expect(a,s,DPS,402174,nil,'Penance on the burning target');s.cooling(402174,8)
 s.near(3);s.buff('player',1284536);s.mana.player=40;M.expect(a,s,DPS,15237,nil,'Holy Nova on Holy Purpose');s.near(0);s.clearAuras();s.debuff('target',589);s.debuff('target',14914)
 s.group=true;M.expect(a,s,DPS,15407,nil,'group: Mind Flay')
end)
test('damage reminders: buffs out of combat, Vampiric Embrace, Silence',function()
 local a,s=priest();s.learn(588,1243,14752,15286,15487,8122)
 s.combat=false;local lit=M.upkeep(a,s,DPS);assert(lit[588]and lit[1243]and lit[14752],'Inner Fire, Fortitude, Divine Spirit')
 s.buff('player',21562);lit=M.upkeep(a,s,DPS);assert(not lit[1243],'Prayer of Fortitude counts')
 s.combat=true;s.health.player=70;lit=M.upkeep(a,s,DPS);assert(lit[15286]and not lit[14752]and not lit[8122],'Vampiric Embrace when hurt; Scream is opt-in')
 s.debuff('target',15286);lit=M.upkeep(a,s,DPS);assert(not lit[15286],'Embrace already on')
end)
test('Mobalytics variant: Blast and Holy Fire only on tough mobs, DoTs then wand',function()
 local a,s=priest(30);s.learn(585,589,8092,2944,14914,5019,17,139);s.targetLevel=30
 s.combat=false;M.expect(a,s,DOT,589,nil,'pull a normal mob with Pain');s.targetLevel=32;M.expect(a,s,DOT,14914,nil,'tough mob: Holy Fire');s.targetLevel=30;s.combat=true
 M.expect(a,s,DOT,589,nil,'Pain');s.debuff('target',589);M.expect(a,s,DOT,2944,nil,'Plague');s.debuff('target',2944)
 M.expect(a,s,DOT,5019,nil,'then the wand, no Mind Blast');M.expect(a,s,DPS,8092,nil,'the default premade recasts Mind Blast')
 s.combat=false;s.clearAuras();local lit=M.upkeep(a,s,DOT);assert(lit[17]and lit[139],'Shield and Renew between pulls')
 s.combat=true;s.learn(15473,15407);s.buff('player',15473);s.debuff('target',589);s.debuff('target',2944);M.expect(a,s,DOT,8092,nil,'Shadowform: Mind Blast')
 s.cooling(8092,6);M.expect(a,s,DOT,15407,nil,'Shadowform: Mind Flay')
end)
test('healer: pre-pull, dispels, single-target order on your target (health is secret)',function()
 local a,s=priest(50);s.learn(17,401859,139,402174,2061,527,552,596,15237,401937,2054,2060)
 s.members(100,100,100,100);s.hostile=false;s.friendly=true
 s.combat=false;M.expect(a,s,HEAL,17,nil,'pre-pull Shield');s.debuff('target',6788,{sourceUnit='player'});M.expect(a,s,HEAL,401859,nil,'Prayer of Mending')
 s.cooling(401859,8);M.expect(a,s,HEAL,139,nil,'Renew');s.combat=true;s.clearAuras();s.cooldown={}
 s.health.target=30;M.expect(a,s,HEAL,401859,nil,'no emergency branch: Prayer of Mending in combat');s.cooling(401859,8)
 s.debuff('target',1,{dispelName='Magic'});M.expect(a,s,HEAL,527,nil,'Dispel Magic');s.clearAuras()
 s.members(60,50,65,100);s.buff('player',1284536);M.expect(a,s,HEAL,15237,nil,'Holy Purpose: Holy Nova (no Prayer of Healing: health is secret)');s.clearAuras()
 M.expect(a,s,HEAL,402174,nil,'Penance');s.cooling(402174,8)
 M.expect(a,s,HEAL,139,nil,'Renew when missing');s.buff('target',139)
 M.expect(a,s,HEAL,2054,nil,'Heal as the filler (no Binding, Greater or Flash Heal)')
 s.usable[2054]=false;local r=M.expect(a,s,HEAL,nil,'stopped','nothing castable');assert(r.suppressAttack);s.usable[2054]=nil
 s.friendly=false;s.hostile=true;s.learn(589,585);M.expect(a,s,HEAL,589,nil,'enemy: Pain')
end)
test('on the real restricted Forever client every Priest premade is complete and the right one auto-selects',function()
 M.checkRestricted('priest',{DPS,DOT,HEAL},function(s)s.learn(585)end,DPS)
end)
finish()
