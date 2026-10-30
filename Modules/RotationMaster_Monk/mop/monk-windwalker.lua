-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Windwalker Monk, levels 10–90, in the Windwalker specialization
-- (269). simulator' Phase 5 order, which Wowhead's Phase 5 list mirrors: Touch of
-- Death, Tiger Power, Rising Sun Kick, Chi Wave, Combo Breaker procs, Fists of Fury when the
-- channel will not cap energy, Jab at a two-Chi deficit, Blackout Kick. Cleave and AoE from two
-- engaged enemies. Tigereye Brew is held to 19 stacks (15 with Chi to spend, 10 under Bloodlust).
-- Energy-to-cap tests are POWER thresholds. The SimulationCraft 5.4.8 list is
-- rm.mop.monk.windwalker.simc.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function stacks(op,v)return{type='BUFF_STACKS',unit='player',spell=1247279,ownbuff=true,operator=op,value=v}end
local function rsk(op,v)return{type='DEBUFF_REMAIN',unit='target',spell=130320,owndebuff=true,operator=op,value=v}end
local function enemies(op,v)return{type='THREAT_COUNT',threat=1,operator=op,value=v}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local TEB,RSK=1247275,107428
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))
local tigerPower=BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(125359)),remain(125359,'LESSTHANOREQUALS',1))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.windwalker',revision=7,
 blocks={['mop.monk.boundaries']=3,['mop.monk.upkeep']=1,['mop.monk.windwalker-upkeep']=2,['mop.monk.windwalker-open']=3,['mop.monk.windwalker-tail']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'windwalker','leveling','single-target','aoe','wowhead'},
 sources={

  {url='https://www.wowhead.com/mop-classic/guide/classes/monk/windwalker/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Windwalker Monk rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20',notes='Read from a Wayback snapshot; Tigereye Brew at 19, 15 with Chi or 10 with a burst buff.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/windwalker-monk-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Windwalker Monk rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Fists of Fury gates and Expel Harm instead of Jab when hurt; leveling order.'},
 },
 body={priority=30,specs={269},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('ww-upkeep','mop.monk.windwalker-upkeep','ww-'),
   BuiltinConditions.block('ww-class','mop.monk.upkeep','ww-'),
   BuiltinConditions.spell('ww-tigereye-brew',TEB,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.ownBuff(TEB)),BuiltinConditions.any(stacks('GREATERTHANOREQUALS',19),BuiltinConditions.all(stacks('GREATERTHANOREQUALS',15),chi('GREATERTHANOREQUALS',2)),
    BuiltinConditions.all(stacks('GREATERTHANOREQUALS',10),lust),BuiltinConditions.all(stacks('GREATERTHANOREQUALS',1),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=30})))),
   BuiltinConditions.spell('ww-chi-brew',115399,BuiltinConditions.all(BuiltinConditions.combat(),chi('GREATERTHANOREQUALS',-2),BuiltinConditions.any(BuiltinConditions.ownBuff(TEB),{type='SPELL_CHARGES',spell=115399,operator='EQUALS',value=2}))),
  },
  rotation={
   BuiltinConditions.block('ww-boundaries','mop.monk.boundaries','ww-'),
   BuiltinConditions.block('ww-open','mop.monk.windwalker-open','ww-'),
   {id='ww-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    BuiltinConditions.spell('ww-aoe-jade-wind',116847),
    BuiltinConditions.spell('ww-aoe-rising-sun',RSK,BuiltinConditions.any(enemies('LESSTHAN',3),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=130320,owndebuff=true}),rsk('LESSTHANOREQUALS',1.5))),
    BuiltinConditions.spell('ww-aoe-tiger-palm',100787,tigerPower),
    BuiltinConditions.spell('ww-aoe-crane-kick-refreshed',101546,BuiltinConditions.all(enemies('GREATERTHANOREQUALS',4),rsk('GREATERTHANOREQUALS',2.25))),
    BuiltinConditions.spell('ww-aoe-rising-sun-kick',RSK),
    BuiltinConditions.spell('ww-aoe-crane-kick',101546,enemies('GREATERTHANOREQUALS',3))}},
   BuiltinConditions.spell('ww-tiger-palm',100787,tigerPower),
   BuiltinConditions.spell('ww-rising-sun-kick',RSK),
   BuiltinConditions.spell('ww-chi-wave',115098,energy('LESSTHANOREQUALS',85)),
   BuiltinConditions.spell('ww-combo-kick',100784,BuiltinConditions.ownBuff(116768)),
   BuiltinConditions.spell('ww-fists-of-fury',113656,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(115288)),energy('LESSTHANOREQUALS',50),remain(125359,'GREATERTHANOREQUALS',4),BuiltinConditions.negate({type='MOVING'}),
    BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_KNOWN',spell=RSK}),{type='SPELL_COOLDOWN',spell=RSK,operator='GREATERTHANOREQUALS',value=3}))),
   BuiltinConditions.spell('ww-zen-sphere',124081,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(124081)),energy('LESSTHANOREQUALS',75))),
   BuiltinConditions.spell('ww-combo-palm',100787,BuiltinConditions.ownBuff(118864)),
   BuiltinConditions.spell('ww-chi-burst',123986,energy('LESSTHANOREQUALS',75)),
   BuiltinConditions.block('ww-tail','mop.monk.windwalker-tail','ww-'),
  },
 },
}))
