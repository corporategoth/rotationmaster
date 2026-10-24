-- Mists of Pandaria Classic Mage premades: switches, priorities, boundaries and reminders through the
-- real catalog, predicates, composition and sequence executor on a modeled 5.5.4 client.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/mop_premade_model_a.lua')
local ARCANE,ARCANEIV,FIRE,FIREIV,FROST,BASE='rm.mop.mage.arcane','rm.mop.mage.arcane.icyveins','rm.mop.mage.fire','rm.mop.mage.fire.icyveins','rm.mop.mage.frost','rm.mop.mage.unspecialized'
local BLAST,BARRAGE,MISSILES,PROC,CHARGE,AP,ALTER,ALTERBUFF=30451,44425,5143,79683,36032,12042,108978,110909
local PYRO,PYROBUFF,HEAT,FIREBALL,INFERNO,FIREBLAST,SCORCH,COMBUST=11366,48108,48107,133,108853,2136,2948,11129
local ELEMENTAL,FROSTBOLT,LANCE,FINGERS,BRAIN,FFB,ORB,ICYVEINS=31687,116,30455,44544,57761,44614,84714,12472
local function mage(level)
 local f,s=M.new('mage');local a=f.addon
 s.setLevel(level or 90);s.targetRange={28,30};s.powerType=0
 s.ranged(BLAST,BARRAGE,MISSILES,PYRO,FIREBALL,INFERNO,FIREBLAST,SCORCH,FROSTBOLT,LANCE,FFB,ORB,1449,120,10,44457,114923,112948,2139,30449)
 return a,s,f
end
local function charges(s,n)s.debuff('player',CHARGE,{applications=n})end
test('the Mage premades are Mists only, from 1 (catch-all) or 10 to 90, and never on Wrath',function()
 M.scope('mage',{BASE},1);M.scope('mage',{ARCANE,FIRE,FROST},10)
 local a=mage();local rows=M.rows(a)
 for _,id in ipairs({ARCANEIV,FIREIV})do
  local scope=rows[id].applicability
  assert(rows[id].envelope.body.disabled and rows[id].eligibilityReason=='disabled','source variants ship disabled: '..id)
  assert(scope.families[1]=='progression'and scope.minExpansion==4 and scope.maxExpansion==4 and scope.minLevel==10 and scope.maxLevel==90,id)
  assert(a:SetDefaultRotationEnabled(id,true)and M.row(a,id).eligible,id..' enabled is eligible')
 end
 assert(not rows[ARCANE].envelope.body.disabled and not rows[FIRE].envelope.body.disabled and not rows[FROST].envelope.body.disabled)
end)
test('switch: the catch-all owns 1-9 and an unspecialized Mage; each specialization picks its premade; variants share it',function()
 local a,s=mage(1);s.learn(FFB);assert(M.selected(a)==BASE,'level 1')
 s.specID(62);assert(M.selected(a)==BASE,'levels 1-9 stay in the catch-all');s.spec=nil
 s.setLevel(10);s.learn(BLAST,PYRO,ELEMENTAL);assert(M.selected(a)==BASE,'level 10 without a spec')
 assert(M.switch(a,FIRE)=='unavailable'and M.switch(a,ARCANE)=='unavailable'and M.switch(a,FROST)=='unavailable','no specialization: unavailable, never a match')
 s.specID(62);assert(M.selected(a)==ARCANE,'Arcane')
 assert(M.switch(a,ARCANEIV)=='match','the Icy Veins Arcane variant shares the switch')
 s.specID(63);assert(M.selected(a)==FIRE,'Fire');assert(M.switch(a,FIREIV)=='match')
 s.specID(64);assert(M.selected(a)==FROST,'Frost')
 s.setLevel(90);assert(M.selected(a)==FROST,'level 90 Frost')
 assert(M.switch(a,FIRE)=='no-match'and M.switch(a,ARCANE)=='no-match','another specialization is a plain no-match')
 s.known={};s.spec=nil;assert(M.selected(a)==BASE,'nothing learned still gets a premade')
end)
test('every premade: casting, channelling and no attackable target stop advice',function()
 local a,s=mage();s.learn(FFB,BLAST,PYRO,FIREBALL,FROSTBOLT)
 for _,id in ipairs({BASE,ARCANE,ARCANEIV,FIRE,FIREIV,FROST})do
  s.cast=true;M.expect(a,s,id,nil,'stopped',id..' casting');s.cast=false
  s.channel=true;M.expect(a,s,id,nil,'stopped',id..' channelling');s.channel=false
  s.hostile=false;M.expect(a,s,id,nil,'stopped',id..' no target');s.hostile=true
 end
end)
test('unspecialized: pull, Frostfire Bolt, Fire Blast to finish or moving, Arcane Explosion on packs, Frost Nova',function()
 local a,s=mage(5);s.learn(FFB,FIREBLAST,122,2139)
 s.combat=false;local r=M.expect(a,s,BASE,FFB,nil,'pull');s.cast=true;M.expect(a,s,BASE,nil,'stopped');s.cast=false;s.combat=true
 M.expect(a,s,BASE,FFB,nil,'filler')
 s.health.target=10;M.expect(a,s,BASE,FIREBLAST,nil,'finish');s.health.target=100
 s.moving=true;M.expect(a,s,BASE,FIREBLAST,nil,'moving');s.moving=false
 s.setLevel(20);s.learn(1449);s.near(3);M.expect(a,s,BASE,1449,nil,'three in melee: Arcane Explosion')
 s.near(3,{28,30});M.expect(a,s,BASE,FFB,nil,'three at range: Frostfire Bolt');s.near(0)
 s.targetRange={0,5};s.targetTarget='player';local lit=M.upkeep(a,s,BASE);assert(lit[122],'Frost Nova when the mob reaches you')
 s.targetTarget='party1';lit=M.upkeep(a,s,BASE);assert(not lit[122],'not when it is on someone else')
end)
test('reminders: armor choice, Brilliance, gem, Counterspell, Mirror Image, tier 6 and Ice Floes',function()
 local a,s,f=mage();s.learn(BLAST,7302,30482,1459,759,2139,55342,12051,116011,108839)
 -- One bag slot holding s.bag (an item ID) or nothing.
 -- Mists has no NUM_TOTAL_EQUIPPED_BAG_SLOTS (Retail/Forever); NUM_BAG_SLOTS=0 is the backpack alone.
 f.env.NUM_BAG_SLOTS=0
 f.env.C_Container={GetContainerNumSlots=function()return 1 end,GetContainerItemInfo=function()if s.bag then return{itemID=s.bag,stackCount=1}end end}
 s.combat=false;local lit=M.upkeep(a,s,ARCANE)
 assert(lit[7302]and not lit[30482]and lit[1459]and lit[759],'Frost Armor, Brilliance, Conjure Mana Gem')
 s.buff('player',30482);lit=M.upkeep(a,s,ARCANE);assert(not lit[7302],'a chosen armor is kept');s.clearAuras()
 s.bag=81901;a.longtermCache={};lit=M.upkeep(a,s,ARCANE);assert(not lit[759],'a Brilliant Mana Gem in the bags');s.bag=nil
 s.forget(7302);lit=M.upkeep(a,s,ARCANE);assert(lit[30482],'Molten Armor before Frost Armor')
 s.learn(PYRO);lit=M.upkeep(a,s,FIRE);assert(lit[30482],'Fire wears Molten Armor')
 assert(not lit[116011]and not lit[12051],'no tier 6, full mana: no Evocation or Rune')
 s.talents[17]=true;lit=M.upkeep(a,s,FIRE);assert(lit[116011],'Rune of Power when standing outside it')
 s.buff('player',116014,{expirationTime=110});lit=M.upkeep(a,s,FIRE);assert(not lit[116011],'standing in the rune');s.clearAuras()
 s.talents[17]=nil;s.talents[16]=true;lit=M.upkeep(a,s,FIRE);assert(lit[12051],'Invocation: Evocation for Invoker\'s Energy')
 s.buff('player',116257,{expirationTime=130});lit=M.upkeep(a,s,FIRE);assert(not lit[12051],'Invoker\'s Energy up');s.clearAuras();s.talents[16]=nil
 s.combat=true;s.cast=true;lit=M.upkeep(a,s,FIRE);assert(not lit[2139],'nothing to interrupt')
 s.moving=true;lit=M.upkeep(a,s,FIRE);assert(lit[108839],'Ice Floes on the move')
end)
test('Arcane: pull, build, mana-gated four-charge spend, capped procs, Alter Time, AoE, moving',function()
 local a,s=mage(10);s.learn(BLAST)
 s.combat=false;M.expect(a,s,ARCANE,BLAST,nil,'pull: Arcane Blast');s.combat=true
 charges(s,4);M.expect(a,s,ARCANE,BLAST,nil,'level 10: Arcane Blast only')
 s.setLevel(90);s.learn(BARRAGE,MISSILES,1449,120,2136,LANCE)
 M.expect(a,s,ARCANE,BLAST,nil,'four charges, full mana: keep blasting')
 s.mana.player=92;M.expect(a,s,ARCANE,BLAST,nil,'four charges at 92%: hysteresis band')
 s.mana.player=80;M.expect(a,s,ARCANE,BARRAGE,nil,'four charges below 90%: Barrage')
 s.buff('player',PROC,{applications=1});M.expect(a,s,ARCANE,MISSILES,nil,'one proc below 95%: Missiles')
 s.mana.player=100;M.expect(a,s,ARCANE,BLAST,nil,'one proc above 95%: Arcane Blast')
 s.clearAuras();charges(s,1);s.buff('player',PROC,{applications=2});M.expect(a,s,ARCANE,MISSILES,nil,'two procs at any charge count')
 s.clearAuras();charges(s,2);M.expect(a,s,ARCANE,BLAST,nil,'building')
 s.buff('player',ALTERBUFF,{expirationTime=110});s.buff('player',PROC,{applications=1});M.expect(a,s,ARCANE,MISSILES,nil,'Alter Time: Missiles on a proc')
 s.clearAuras();s.buff('player',ALTERBUFF,{expirationTime=110});M.expect(a,s,ARCANE,BLAST,nil,'Alter Time: Arcane Blast')
 s.clearAuras();s.buff('player',ALTERBUFF,{expirationTime=101});M.expect(a,s,ARCANE,BARRAGE,nil,'Barrage before Alter Time ends')
 s.clearAuras();charges(s,4);s.near(2,{28,30});M.expect(a,s,ARCANE,BARRAGE,nil,'cleave: Barrage at four charges')
 s.clearAuras();charges(s,1);s.near(5);s.targetRange={0,5};M.expect(a,s,ARCANE,120,nil,'five in melee: Cone of Cold');s.cooling(120,5)
 M.expect(a,s,ARCANE,1449,nil,'then Arcane Explosion');s.near(0);s.cooldown={};s.targetRange={28,30}
 s.moving=true;M.expect(a,s,ARCANE,2136,nil,'moving: Fire Blast');s.cooling(2136,5);M.expect(a,s,ARCANE,LANCE,nil,'moving: Ice Lance')
 s.buff('player',108839);M.expect(a,s,ARCANE,BLAST,nil,'Ice Floes: keep casting');s.clearAuras();s.moving=false;s.cooldown={}
 s.talents[13]=true;s.learn(114923);M.expect(a,s,ARCANE,114923,nil,'Nether Tempest missing')
 s.debuff('target',114923,{expirationTime=110});M.expect(a,s,ARCANE,BLAST,nil,'Nether Tempest up')
 s.clearAuras();s.talents[13]=nil;s.talents[15]=true;s.learn(112948);M.expect(a,s,ARCANE,112948,nil,'Frost Bomb')
 s.learn(AP,ALTER);charges(s,4);s.buff('player',PROC);local lit=M.upkeep(a,s,ARCANE);assert(lit[AP],'Arcane Power at four charges with a proc')
 assert(not lit[ALTER],'no Alter Time before Arcane Power')
end)
test('Arcane Icy Veins variant: Barrage at four charges without a proc whatever the mana',function()
 local a,s=mage();s.learn(BLAST,BARRAGE,MISSILES)
 charges(s,4);M.expect(a,s,ARCANEIV,BARRAGE,nil,'full mana: Barrage');M.expect(a,s,ARCANE,BLAST,nil,'the recommended one keeps blasting')
 s.buff('player',PROC,{applications=1});M.expect(a,s,ARCANEIV,MISSILES,nil,'proc: Missiles')
 s.clearAuras();charges(s,2);s.buff('player',PROC,{applications=2});M.expect(a,s,ARCANEIV,BLAST,nil,'never Missiles below four charges')
 s.clearAuras();charges(s,4);s.buff('player',145252,{applications=2});M.expect(a,s,ARCANEIV,BLAST,nil,'two Profound Magic stacks: blast')
end)
test('Fire: pull, Heating Up, Pyroblast! pooled before Combustion, Combustion after a Pyroblast, AoE spread, moving',function()
 local a,s=mage(10);s.learn(PYRO,FFB,FIREBLAST)
 s.combat=false;M.expect(a,s,FIRE,PYRO,nil,'pull: Pyroblast');s.moving=true;M.expect(a,s,FIRE,FFB,nil,'moving pull: Frostfire Bolt');s.moving=false;s.combat=true
 M.expect(a,s,FIRE,FFB,nil,'level 10 filler: Frostfire Bolt')
 s.buff('player',HEAT);M.expect(a,s,FIRE,FIREBLAST,nil,'Heating Up before 24: Fire Blast')
 s.setLevel(90);s.learn(FIREBALL,INFERNO,SCORCH,LANCE);M.expect(a,s,FIRE,INFERNO,nil,'Heating Up: Inferno Blast')
 s.clearAuras();M.expect(a,s,FIRE,FIREBALL,nil,'Fireball')
 s.buff('player',PYROBUFF,{expirationTime=115});M.expect(a,s,FIRE,PYRO,nil,'Pyroblast! without Combustion learned')
 s.learn(COMBUST);M.expect(a,s,FIRE,PYRO,nil,'Combustion ready but no DoT: refresh it')
 s.debuff('target',PYRO,{expirationTime=110});M.expect(a,s,FIRE,FIREBALL,nil,'Combustion ready, DoT up: pool with Fireball')
 s.buff('player',HEAT);M.expect(a,s,FIRE,PYRO,nil,'pooled Pyroblast! with Heating Up')
 s.clearAuras();s.debuff('target',PYRO,{expirationTime=110});s.buff('player',PYROBUFF,{expirationTime=102});M.expect(a,s,FIRE,PYRO,nil,'Pyroblast! about to expire')
 s.clearAuras();s.cooling(COMBUST,30);s.debuff('target',PYRO,{expirationTime=110});s.buff('player',PYROBUFF,{expirationTime=115});M.expect(a,s,FIRE,PYRO,nil,'Combustion cooling: at once')
 s.clearAuras();s.cooldown={};s.debuff('target',PYRO,{expirationTime=110});s.debuff('target',12654);s.history(PYRO,0.5)
 M.expect(a,s,FIRE,COMBUST,nil,'Combustion right after a Pyroblast with Ignite');a.spellHistory={}
 M.expect(a,s,FIRE,FIREBALL,nil,'no recent Pyroblast: no Combustion')
 s.near(3,{28,30});M.expect(a,s,FIRE,INFERNO,nil,'cleave: Inferno Blast spreads');s.near(0);s.clearAuras()
 s.buff('player',12043);M.expect(a,s,FIRE,PYRO,nil,'Presence of Mind: Pyroblast');s.clearAuras()
 s.moving=true;M.expect(a,s,FIRE,SCORCH,nil,'moving: Scorch');s.buff('player',108839);M.expect(a,s,FIRE,FIREBALL,nil,'Ice Floes: keep casting')
end)
test('Fire Icy Veins variant: hold Pyroblast! for Heating Up',function()
 local a,s=mage();s.learn(PYRO,FIREBALL,INFERNO)
 s.buff('player',PYROBUFF,{expirationTime=115});M.expect(a,s,FIREIV,FIREBALL,nil,'Pyroblast! alone is held');M.expect(a,s,FIRE,PYRO,nil,'the recommended one fires it')
 s.buff('player',HEAT);M.expect(a,s,FIREIV,PYRO,nil,'both procs: Pyroblast')
 s.clearAuras();s.buff('player',PYROBUFF,{expirationTime=102});M.expect(a,s,FIREIV,PYRO,nil,'about to expire')
 s.clearAuras();s.buff('player',HEAT);M.expect(a,s,FIREIV,INFERNO,nil,'Heating Up alone: Inferno Blast')
end)
test('Frost: pull, capped Fingers, Brain Freeze, Orb, Ice Lance, Alter Time hold, AoE, moving, levels 10-11',function()
 local a,s=mage(10);s.learn(ELEMENTAL,FFB,FIREBLAST)
 s.combat=false;M.expect(a,s,FROST,FFB,nil,'level 10 pull: Frostfire Bolt');s.combat=true
 M.expect(a,s,FROST,FFB,nil,'level 10 filler');s.setLevel(90);s.learn(FROSTBOLT,LANCE,ORB,120,1449,10)
 s.combat=false;M.expect(a,s,FROST,FROSTBOLT,nil,'pull: Frostbolt');s.combat=true
 M.expect(a,s,FROST,ORB,nil,'Frozen Orb');s.cooling(ORB,30);M.expect(a,s,FROST,FROSTBOLT,nil,'Frostbolt')
 s.buff('player',FINGERS,{applications=1,expirationTime=115});M.expect(a,s,FROST,LANCE,nil,'one Fingers: Ice Lance')
 s.buff('player',BRAIN,{expirationTime=115});M.expect(a,s,FROST,FFB,nil,'Brain Freeze before one Fingers')
 s.clearAuras();s.buff('player',BRAIN,{expirationTime=115});s.buff('player',FINGERS,{applications=2,expirationTime=115});M.expect(a,s,FROST,LANCE,nil,'two Fingers first')
 s.learn(ALTER);s.clearAuras();s.buff('player',BRAIN,{expirationTime=115});M.expect(a,s,FROST,FROSTBOLT,nil,'Alter Time ready: hold Brain Freeze')
 s.clearAuras();s.buff('player',BRAIN,{expirationTime=102});M.expect(a,s,FROST,FFB,nil,'but not into its last 3 s')
 s.clearAuras();s.cooling(ALTER,40);s.buff('player',BRAIN,{expirationTime=115});M.expect(a,s,FROST,FFB,nil,'Alter Time far away: spend')
 s.clearAuras();s.cooldown={};s.cooling(ALTER,40);s.near(5);s.targetRange={0,5};M.expect(a,s,FROST,ORB,nil,'AoE: Frozen Orb');s.cooling(ORB,30)
 M.expect(a,s,FROST,120,nil,'five close: Cone of Cold');s.cooling(120,8);M.expect(a,s,FROST,1449,nil,'five in melee: Arcane Explosion')
 s.targetRange={28,30};s.near(4,{28,30});M.expect(a,s,FROST,10,nil,'four standing at range: Blizzard')
 s.near(2,{28,30});M.expect(a,s,FROST,FROSTBOLT,nil,'two: single-target fall-through');s.near(0)
 s.moving=true;M.expect(a,s,FROST,LANCE,nil,'moving: Ice Lance');s.cooling(LANCE,1);M.expect(a,s,FROST,FIREBLAST,nil,'moving: Fire Blast')
 s.cooling(FIREBLAST,5);M.expect(a,s,FROST,nil,'stopped','moving with nothing instant')
end)
test('Frost reminders: Water Elemental, Icy Veins cadence, Alter Time with Icy Veins, Freeze on non-bosses',function()
 local a,s,f=mage();s.learn(ELEMENTAL,ICYVEINS,ALTER);local petKnown={[33395]=true}
 local base=f.env.C_SpellBook.IsSpellKnown;f.env.C_SpellBook.IsSpellKnown=function(id,bank)if bank==1 then return petKnown[id]==true end;return base(id,bank)end
 local lit=M.upkeep(a,s,FROST);assert(lit[ELEMENTAL]and lit[ICYVEINS],'no pet: summon; Alter Time ready: Icy Veins')
 s.pet=true;lit=M.upkeep(a,s,FROST);assert(not lit[ELEMENTAL]and lit[33395],'pet up; Freeze for Fingers')
 s.classification='worldboss';lit=M.upkeep(a,s,FROST);assert(not lit[33395],'no Freeze on a boss');s.classification='normal'
 s.cooling(ALTER,30);lit=M.upkeep(a,s,FROST);assert(not lit[ICYVEINS],'Alter Time 30 s away: hold Icy Veins')
 s.cooldown={};s.buff('player',ICYVEINS);s.buff('player',FINGERS,{applications=2});lit=M.upkeep(a,s,FROST);assert(lit[ALTER]and not lit[33395],'Alter Time at two Fingers in Icy Veins')
end)
finish()
