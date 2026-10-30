-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Feral Druid (Cat and Bear in one premade, by form), levels 10–60. Selected with 11 Feral
-- Combat points or Feral as the main talent tree, or by being in Cat, Bear or Dire Bear Form, so an
-- untalented Druid who shifts gets the form's list. Icy Veins' Feral leveling
-- order as the spine, with Warcraft Tavern's Faerie Fire and Demoralizing Roar and Ferocious Bite
-- only once Rip runs. In caster form it suggests Cat Form (else Bear). Health, energy, rage and mana
-- are secret on Forever, so bleeds go on every target, Maul is queued whenever it is affordable,
-- Enrage is used whenever it is ready, and powershifting, Frenzied Regeneration and the caster
-- Regrowth are left to the player.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Balance, 2 Feral Combat, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},
 {type='PRIMARY_TALENT_TREE',tree=n}}}end
local function aura(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function dot(id,mine)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=mine}end
local function enemies(n)return{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=n}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local cat,bear=aura(768),BuiltinConditions.any(aura(5487),aura(9634))
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local faerie=BuiltinConditions.negate(dot(770))
local catSection={
 {id='feral-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  BuiltinConditions.spell('feral-ravage',6785),BuiltinConditions.spell('feral-opener-shred',5221),stop('feral-stealth-stop')}},
 BuiltinConditions.spell('feral-cat-faerie-fire',770,BuiltinConditions.all(faerie,BuiltinConditions.any(BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),{type='GROUP'}))),
 {id='feral-finisher',type='branch',conditions={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  BuiltinConditions.spell('feral-rip',1079,BuiltinConditions.negate(dot(1079,true))),
  -- Reached only with Rip running; Clearcasting goes to Shred.
  BuiltinConditions.spell('feral-bite',22568,BuiltinConditions.negate(aura(16870)))}},
 BuiltinConditions.spell('feral-rake',1822,BuiltinConditions.negate(dot(1822,true))),
 -- Behind the target, approximated by "it is not attacking me" (RM cannot see facing).
 {id='feral-behind',type='branch',conditions={type='THREAT',unit='target',threat=3},
  onFalse={BuiltinConditions.spell('feral-shred',5221)},onTrue={BuiltinConditions.spell('feral-claw',1082)}},
 stop('feral-cat-pool',nil,true),
}
local bearSection={
 {id='feral-bear-range',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onFalse={},onTrue={
  BuiltinConditions.spell('feral-bear-pull-faerie-fire',770,faerie),BuiltinConditions.spell('feral-charge',16979),stop('feral-bear-range-stop',nil,true)}},
 BuiltinConditions.spell('feral-demoralizing-roar',99,BuiltinConditions.all(BuiltinConditions.negate(dot(99)),BuiltinConditions.negate(dot(1160)),BuiltinConditions.any(enemies(2),{type='GROUP'}))),
 BuiltinConditions.spell('feral-bear-faerie-fire',770,faerie),
 BuiltinConditions.spell('feral-primal-bite',407995),
 {id='feral-bear-aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={BuiltinConditions.spell('feral-aoe-swipe',779),stop('feral-aoe-stop',nil,true)}},
 BuiltinConditions.spell('feral-lacerate',414644),
 BuiltinConditions.spell('feral-swipe',779),
 stop('feral-bear-done',nil,true),
}
local casterSection={
 BuiltinConditions.spell('feral-cat-form',768),
 BuiltinConditions.spell('feral-bear-form',5487,BuiltinConditions.negate(BuiltinConditions.known(768))),
 stop('feral-caster-stop'),
}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.feral',revision=7,
 blocks={['forever.druid.boundaries']=3,['forever.druid.upkeep']=1},
 applicability={families={'forever'},actionContext='player',class='DRUID'},
 tags={'feral','cat','bear','tank','melee','leveling','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/feral-druid-leveling',title='Icy Veins: Forever Feral Druid leveling',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://www.icy-veins.com/wow-forever/feral-druid-melee-dps-and-tank-pve-guide',title='Icy Veins: Forever Feral Druid PvE (DPS and tank)',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://www.warcrafttavern.com/forever/guides/druid-leveling/',title='Warcraft Tavern: Forever Druid leveling',reviewedAt='2026-10-23',notes='Faerie Fire pull and upkeep; Demoralizing Roar.'},
  {url='https://conquestcapped.com/guides/wow-forever/wow-forever-druid-overview/',title='conquestcapped: WoW Forever Druid overview',reviewedAt='2026-10-23',revision='2026-10-19',notes='Ferocious Bite as a finisher.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Shifting Power, Primal Bite, Berserk; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and GCDs only.'},
 },
 body={priority=20,
  -- 11 Feral points (Feral Charge's tier) first: readable, so a talented feral never waits on an aura
  -- read; then the forms; then Feral as the main tree before its first talent spell, last so a tie
  -- (unavailable) cannot hide a form.
  switch=BuiltinConditions.all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},BuiltinConditions.any({type='TALENT_TREE_POINTS',tree=2,operator='GREATERTHANOREQUALS',value=11},
   aura(768),aura(5487),aura(9634),tree(2,1))),
  cooldowns={
   BuiltinConditions.block('feral-upkeep','forever.druid.upkeep','feral-'),
   BuiltinConditions.spell('feral-maul',6807,BuiltinConditions.all(bear,BuiltinConditions.combat(),BuiltinConditions.negate({type='SPELL_ACTIVE',spell=6807}))),
   BuiltinConditions.spell('feral-enrage',5229,BuiltinConditions.all(bear,BuiltinConditions.combat())),
   BuiltinConditions.spell('feral-berserk',417141,BuiltinConditions.all(BuiltinConditions.any(cat,bear),BuiltinConditions.combat(),BuiltinConditions.any(enemies(3),elite))),
   BuiltinConditions.spell('feral-innervate',29166,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}))),
  },
  rotation={
   BuiltinConditions.block('feral-boundaries','forever.druid.boundaries','feral-'),
   stop('feral-target',BuiltinConditions.negate({type='ATTACKABLE',unit='target'}),true),
   {id='feral-cat',type='branch',conditions=cat,onTrue=catSection,onFalse={
    {id='feral-bear',type='branch',conditions=bear,onTrue=bearSection,onFalse=casterSection}}},
  },
 },
}))
