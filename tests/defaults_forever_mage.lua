-- WoW Forever Mage premades: switches, priorities, boundaries and reminders through the real
-- catalog, predicates, composition and sequence executor on a modeled Forever client (probe policy;
-- the last test keeps the real restricted policy).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/forever_premade_model.lua')
local FROST,FIRE,IVFIRE,ARCANE='rm.forever.mage.frost','rm.forever.mage.fire','rm.forever.mage.fire.icyveins','rm.forever.mage.arcane'
local function mage(level)
 local f,s=M.new('mage');local a=f.addon
 s.setLevel(level or 60);s.targetRange={28,30}
 s.ranged(133,116,2136,5143,1312002,2948,11366,401502,400574,1326079,5019,2139)
 return a,s,f
end
test('the Mage premades load, validate and declare Forever only',function()
 local a=mage();local rows=M.rows(a)
 for _,id in ipairs({FROST,FIRE,IVFIRE,ARCANE})do
  local row=assert(rows[id],id);local scope=row.applicability
  assert(row.readOnly and row.builtin and scope.families[1]=='forever'and #scope.families==1 and scope.class=='MAGE'and scope.maxLevel==60,id)
  assert(row.eligible,id..' not eligible on the probe Forever context')
 end
end)
test('switch: Frost until a talent spell; Pyroblast is Fire; Arcane Blast without Ice Lance is Arcane',function()
 local a,s=mage(1);s.learn(133);assert(M.selected(a)==FROST,'level 1')
 s.setLevel(20);s.learn(116,1312002);assert(M.selected(a)==FROST,'Ice Lance is Frost')
 s.learn(400574);assert(M.selected(a)==FROST,'Missile-Barrage-first Frost with Arcane Blast and Ice Lance stays Frost')
 s.known[1312002]=nil;assert(M.selected(a)==ARCANE,'Arcane Blast alone is Arcane')
 s.known[400574]=nil;s.learn(1239700);assert(M.selected(a)==ARCANE,'Arcane Blast rank 5 alone is Arcane')
 s.learn(18809);assert(M.selected(a)==FIRE,'Pyroblast (any rank) wins over Arcane')
 assert(M.switch(a,IVFIRE)=='match','the Icy Veins Fire variant shares the Fire switch')
 s.known={};assert(M.selected(a)==FROST,'a Mage with nothing learned still gets a premade')
end)
test('Frost: boundaries, proc batch, pull and early ranks',function()
 local a,s=mage(3);s.learn(133);M.expect(a,s,FROST,133,nil,'levels 1-3: Fireball')
 s.setLevel(60);s.learn(116,1312002,2136,5143,120,10,1449)
 s.cast=true;M.expect(a,s,FROST,nil,'stopped','casting')
 s.buff('player',400669);M.expect(a,s,FROST,1312002,nil,'Fingers of Frost during a cast: Ice Lance');s.clearAuras();s.cast=false
 s.channel=true;M.expect(a,s,FROST,nil,'stopped','channelling');s.channel=false
 s.hostile=false;M.expect(a,s,FROST,nil,'stopped','no hostile target');s.hostile=true
 s.combat=false;M.expect(a,s,FROST,116,nil,'pull: Frostbolt');s.combat=true
 M.expect(a,s,FROST,116,nil,'Frostbolt filler')
end)
test('Frost: Ice Lance procs and freezes, Winter\'s Chill Cone, Missile Barrage, moving, finisher, wand',function()
 local a,s=mage();s.learn(116,1312002,2136,5143,120,5019)
 s.buff('player',400670);M.expect(a,s,FROST,1312002,nil,'Fingers of Frost (newer aura)');s.clearAuras()
 s.debuff('target',12494,{sourceUnit='party1'});M.expect(a,s,FROST,1312002,nil,'Frostbite from anyone freezes');s.clearAuras()
 s.debuff('target',12579,{applications=5});M.expect(a,s,FROST,116,nil,'five Winter\'s Chill but out of Cone range')
 s.targetRange={5,8};M.expect(a,s,FROST,120,nil,'five Winter\'s Chill in range: Cone of Cold');s.clearAuras();s.targetRange={28,30}
 s.buff('player',400589);M.expect(a,s,FROST,5143,nil,'Missile Barrage');s.clearAuras()
 s.moving=true;M.expect(a,s,FROST,1312002,nil,'moving: Ice Lance');s.cooling(1312002,1);M.expect(a,s,FROST,2136,nil,'moving: Fire Blast')
 s.cooling(2136,3);M.expect(a,s,FROST,nil,'stopped','moving: nothing castable');s.cooldown={};s.moving=false
 s.health.target=10;M.expect(a,s,FROST,2136,nil,'finish with Fire Blast');s.health.target=100
 s.mana.player=10;s.usable[116]=false;M.expect(a,s,FROST,5019,nil,'wand when out of mana solo')
 s.repeatActive=true;local r=M.expect(a,s,FROST,nil,'stopped','wand already running');assert(r.suppressAttack)
 s.group=true;s.repeatActive=false;r=M.expect(a,s,FROST,nil,'stopped','no wand advice in a group');assert(r.suppressAttack)
end)
test('Frost: AoE tiers, optional Tavern AoE off',function()
 local a,s=mage();s.learn(116,120,10,1449,2120)
 s.near(3);M.expect(a,s,FROST,120,nil,'three: Cone of Cold');s.cooling(120,5)
 M.expect(a,s,FROST,116,nil,'three, Cone cooling: single target')
 s.near(5);M.expect(a,s,FROST,10,nil,'five, target at range: Blizzard')
 s.targetRange={0,5};M.expect(a,s,FROST,1449,nil,'five with the target on you: Arcane Explosion')
end)
test('Frost and Mage reminders: intellect, armor choice, Ice Barrier, Nova, Counterspell',function()
 local a,s=mage();s.learn(1459,168,7302,6117,11426,12051,2139,122,475,12472)
 s.combat=false;local lit=M.upkeep(a,s,FROST);assert(lit[1459]and lit[7302]and not lit[6117]and not lit[168]and lit[11426],'solo: Ice Armor')
 s.group=true;lit=M.upkeep(a,s,FROST);assert(lit[6117]and not lit[7302],'group: Mage Armor')
 s.buff('player',7302);lit=M.upkeep(a,s,FROST);assert(not lit[6117],'an armor you chose is kept')
 s.group=false;s.clearAuras();s.known[7302]=nil;lit=M.upkeep(a,s,FROST);assert(lit[168],'Frost Armor before Ice Armor')
 s.combat=true;s.targetRange={0,5};lit=M.upkeep(a,s,FROST);assert(lit[122]and not lit[1459],'Frost Nova when the mob reaches you')
 s.classification='worldboss';lit=M.upkeep(a,s,FROST);assert(not lit[122],'no Frost Nova on a boss')
 s.mana.player=10;lit=M.upkeep(a,s,FROST);assert(lit[12051],'Evocation when drained')
end)
test('Fire: Heating Up Pyroblast, Fire Blast, Scorch refresh, Frostfire before Fireball, AoE',function()
 local a,s=mage();s.learn(11366,133,2136,2948,401502,2120,11113,1449,1312002)
 s.combat=false;M.expect(a,s,FIRE,401502,nil,'pull a normal mob: Frostfire Bolt')
 s.classification='elite';M.expect(a,s,FIRE,11366,nil,'pull an elite: Pyroblast');s.combat=true
 s.buff('player',400625,{applications=3});M.expect(a,s,FIRE,11366,nil,'three Heating Up: Pyroblast');s.clearAuras()
 M.expect(a,s,FIRE,2136,nil,'Fire Blast on cooldown');s.cooling(2136,5)
 M.expect(a,s,FIRE,401502,nil,'no Scorch stacks started by default')
 s.debuff('target',22959,{applications=3});M.expect(a,s,FIRE,2948,nil,'your Fire Vulnerability below five: Scorch')
 s.clearAuras();s.debuff('target',22959,{applications=5,expirationTime=120,duration=30});M.expect(a,s,FIRE,401502,nil,'five fresh stacks: filler')
 s.clearAuras();s.debuff('target',22959,{applications=5,expirationTime=103,duration=30});M.expect(a,s,FIRE,2948,nil,'refresh before it drops')
 s.clearAuras();s.classification='normal';s.known[401502]=nil;M.expect(a,s,FIRE,133,nil,'Fireball before Frostfire Bolt')
 s.buff('player',400669);M.expect(a,s,FIRE,1312002,nil,'hybrid: Ice Lance on Fingers of Frost');s.clearAuras()
 s.near(4);M.expect(a,s,FIRE,2120,nil,'four: Flamestrike');s.debuff('target',2120);M.expect(a,s,FIRE,11113,nil,'burning: Blast Wave')
 s.near(0);s.clearAuras();s.moving=true;s.cooldown={};M.expect(a,s,FIRE,2136,nil,'moving: Fire Blast')
end)
test('Icy Veins Fire: Pyroblast pull, Fire Blast only to finish or on Wake of Fire, Scorch close',function()
 local a,s=mage();s.learn(11366,133,2136,2948,401502)
 s.combat=false;M.expect(a,s,IVFIRE,11366,nil,'pull: Pyroblast');s.combat=true
 s.buff('player',400625,{applications=3});M.expect(a,s,IVFIRE,401502,nil,'no Heating Up step, no routine Fire Blast');s.clearAuras()
 s.buff('player',1312934);M.expect(a,s,IVFIRE,2136,nil,'Wake of Fire: Fire Blast');s.clearAuras()
 s.health.target=15;M.expect(a,s,IVFIRE,2136,nil,'low target: Fire Blast');s.cooling(2136,5);M.expect(a,s,IVFIRE,2948,nil,'low target: Scorch')
 s.health.target=100;s.targetRange={5,8};M.expect(a,s,IVFIRE,2948,nil,'mob closing: Scorch')
end)
test('Arcane: Barrage, Clearcasting, stack caps by target, Arcane Wrath, filler, Fire Blast fallback',function()
 local a,s=mage();s.learn(400574,1326079,5143,116,133,401502,2136,1449)
 s.combat=false;M.expect(a,s,ARCANE,116,nil,'solo pull: Frostbolt');s.group=true;M.expect(a,s,ARCANE,400574,nil,'group pull: Arcane Blast');s.group=false;s.combat=true
 M.expect(a,s,ARCANE,400574,nil,'build stacks')
 s.buff('player',400573,{applications=2});M.expect(a,s,ARCANE,401502,nil,'two stacks on a normal mob: filler')
 s.classification='elite';M.expect(a,s,ARCANE,400574,nil,'elite: keep building')
 s.clearAuras();s.buff('player',400573,{applications=3});M.expect(a,s,ARCANE,1326079,nil,'three stacks: Arcane Wrath')
 s.cooling(1326079,4);M.expect(a,s,ARCANE,400574,nil,'Wrath cooling, elite, below four');s.classification='normal'
 s.mana.player=30;s.clearAuras();M.expect(a,s,ARCANE,401502,nil,'below 35% mana: no Arcane Blast')
 s.buff('player',12536);M.expect(a,s,ARCANE,400574,nil,'Clearcasting: Arcane Blast')
 s.buff('player',1326083);M.expect(a,s,ARCANE,5143,nil,'Missile Barrage first');s.clearAuras();s.mana.player=100
 s.known[1326079]=nil;s.buff('player',400573,{applications=2});M.expect(a,s,ARCANE,2136,nil,'no Arcane Wrath: Fire Blast spends the stacks')
 s.clearAuras();s.near(3);M.expect(a,s,ARCANE,1449,nil,'three near: Arcane Explosion')
 s.near(0);s.moving=true;M.expect(a,s,ARCANE,2136,nil,'moving: Fire Blast')
 s.learn(12043,12042);s.moving=false;s.classification='elite';local lit=M.upkeep(a,s,ARCANE);assert(lit[12043]and lit[12042],'Presence of Mind and Arcane Power on elites')
end)
test('on the real restricted Forever client the Mage premades are listed but never auto-selected',function()
 local f,s=M.new('mage',{policy='restricted'});local a=f.addon;s.learn(133,11366)
 local rows=M.rows(a)
 for _,id in ipairs({FROST,FIRE,IVFIRE,ARCANE})do
  assert(rows[id]and rows[id].readOnly,id..' not listed');assert(not rows[id].eligible and rows[id].eligibilityReason=='restricted-or-unsupported-client',id)
 end
 assert(next(a:GetRuntimeRotations(0))==nil and M.selected(a)==nil,'a restricted client auto-selected a packaged rotation')
end)
finish()
