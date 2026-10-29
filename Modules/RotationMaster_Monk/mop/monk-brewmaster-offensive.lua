-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Brewmaster Monk, damage-first, after simulator' "Offensive" APL (Phase 5).
-- Same switch as rm.mop.monk.brewmaster, lower priority and off by default: no routine Purifying
-- Brew or Guard (Purifying Brew only on the tier-15 Purifier proc), Rushing Jade Wind before Keg
-- Smash, Chi spent on Blackout Kick for damage. Only for an overgeared tank or a damage race.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function keg(op,v)return{type='SPELL_COOLDOWN',spell=121253,operator=op,value=v}end
local SHUFFLE=115307
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.brewmaster.offensive',revision=7,
 blocks={['mop.monk.boundaries']=3,['mop.monk.upkeep']=1,['mop.monk.brewmaster-upkeep']=2,['mop.monk.brewmaster-pull']=3},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'brewmaster','tank','single-target'},
 sources={},
 body={priority=20,disabled=true,specs={268},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('brewo-upkeep','mop.monk.brewmaster-upkeep','brewo-'),
   BuiltinConditions.block('brewo-class','mop.monk.upkeep','brewo-'),
   BuiltinConditions.spell('brewo-purifier',119582,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.ownBuff(138237))),
   BuiltinConditions.spell('brewo-chi-brew',115399,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(chi('EQUALS',0),BuiltinConditions.all(chi('LESSTHANOREQUALS',2),keg('GREATERTHANOREQUALS',2),keg('LESSTHANOREQUALS',7),energy('LESSTHAN',80))))),
  },
  rotation={
   BuiltinConditions.block('brewo-boundaries','mop.monk.boundaries','brewo-'),
   BuiltinConditions.block('brewo-pull','mop.monk.brewmaster-pull','brewo-'),
   BuiltinConditions.spell('brewo-touch-of-death',115080),
   BuiltinConditions.spell('brewo-cap-kick',100784,BuiltinConditions.all(keg('LESSTHANOREQUALS',1.5),chi('LESSTHANOREQUALS',-1))),
   BuiltinConditions.spell('brewo-jade-wind',116847),
   BuiltinConditions.spell('brewo-keg-smash',121253),
   BuiltinConditions.spell('brewo-shuffle-kick',100784,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(SHUFFLE)),remain(SHUFFLE,'LESSTHANOREQUALS',1.5),BuiltinConditions.all(keg('LESSTHANOREQUALS',2),chi('LESSTHANOREQUALS',-1)))),
   BuiltinConditions.spell('brewo-tiger-palm',100787,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(125359)),remain(125359,'LESSTHANOREQUALS',1.5))),
   BuiltinConditions.spell('brewo-chi-wave',115098),
   BuiltinConditions.spell('brewo-chi-burst',123986),
   BuiltinConditions.spell('brewo-zen-sphere',124081,BuiltinConditions.negate(BuiltinConditions.ownBuff(124081))),
   BuiltinConditions.spell('brewo-spend-kick',100784,chi('LESSTHANOREQUALS',-1)),
   BuiltinConditions.spell('brewo-jab',100780,BuiltinConditions.all(energy('GREATERTHANOREQUALS',80),chi('GREATERTHANOREQUALS',-1))),
   BuiltinConditions.spell('brewo-palm-filler',100787),
   BuiltinConditions.spell('brewo-jab-filler',100780,chi('GREATERTHANOREQUALS',-1)),
  },
 },
}))
