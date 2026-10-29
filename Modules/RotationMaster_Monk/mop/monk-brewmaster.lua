-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Brewmaster Monk, levels 10–90, in the Brewmaster specialization
-- (268). simulator' Phase 5 Generic order with Wowhead's
-- Shuffle-first purify rule: Shuffle through Blackout Kick, Keg Smash under the Chi cap, Expel
-- Harm when hurt, Jab at 80 energy, Tiger Power, Tiger Palm filler; Breath of Fire and Spinning
-- Crane Kick on packs only while Shuffle is safe. Purifying Brew, Elusive Brew, Guard and Chi Brew
-- are off the global cooldown, so they are reminders. Before Brewmaster Training (34) Tiger Palm
-- costs Chi, so a last Jab builds it. The damage-first list is
-- rm.mop.monk.brewmaster.offensive.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function talent(i)return{type='TALENT',layout='grid',value=i}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local SHUFFLE,KEG=115307,121253
local stagger=function(id)return{type='DEBUFF',unit='player',spell=id}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.brewmaster',revision=7,
 blocks={['mop.monk.boundaries']=3,['mop.monk.upkeep']=1,['mop.monk.brewmaster-upkeep']=2,['mop.monk.brewmaster-pull']=3},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'brewmaster','tank','leveling','single-target','aoe','wowhead'},
 sources={

  {url='https://www.wowhead.com/mop-classic/guide/classes/monk/brewmaster/tank-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Brewmaster Monk rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20',notes='Read from a Wayback snapshot; Shuffle before Purifying Brew.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/brewmaster-monk-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Brewmaster Monk rotation',reviewedAt='2026-10-23',revision='2025-07-09',notes='Elusive Brew from six stacks, Breath of Fire only with Shuffle safe; leveling equals the cap rotation.'},
 },
 body={priority=30,specs={268},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('brew-upkeep','mop.monk.brewmaster-upkeep','brew-'),
   BuiltinConditions.block('brew-class','mop.monk.upkeep','brew-'),
   BuiltinConditions.spell('brew-purifying',119582,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(stagger(124273),BuiltinConditions.all(stagger(124274),remain(SHUFFLE,'GREATERTHANOREQUALS',3))))),
   BuiltinConditions.spell('brew-guard',115295,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.ownBuff(118636),remain(SHUFFLE,'GREATERTHAN',2),BuiltinConditions.any(chi('GREATERTHANOREQUALS',3),health('LESSTHAN',.7)))),
   BuiltinConditions.spell('brew-chi-brew',115399,BuiltinConditions.all(BuiltinConditions.combat(),chi('LESSTHANOREQUALS',1),{type='SPELL_COOLDOWN',spell=KEG,operator='GREATERTHANOREQUALS',value=1.5},
    BuiltinConditions.negate({type='BUFF_STACKS',unit='player',spell=128939,ownbuff=true,operator='GREATERTHAN',value=10}))),
   BuiltinConditions.spell('brew-dampen-harm',122278,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.5))),
   BuiltinConditions.spell('brew-diffuse-magic',122783,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.5))),
   off('brew-statue',115315,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=115315,operator='LESSTHAN',value=900}))),
  },
  rotation={
   BuiltinConditions.block('brew-boundaries','mop.monk.boundaries','brew-'),
   BuiltinConditions.block('brew-pull','mop.monk.brewmaster-pull','brew-'),
   BuiltinConditions.spell('brew-shuffle-kick',100784,BuiltinConditions.negate(BuiltinConditions.ownBuff(SHUFFLE))),
   BuiltinConditions.spell('brew-desperate-expel',115072,health('LESSTHAN',.35)),
   BuiltinConditions.spell('brew-touch-of-death',115080),
   BuiltinConditions.spell('brew-keg-smash',KEG,chi('GREATERTHANOREQUALS',-2)),
   {id='brew-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('brew-aoe-jade-wind',116847,chi('GREATERTHANOREQUALS',-1)),
    BuiltinConditions.spell('brew-aoe-breath',115181,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=123725,owndebuff=true}),remain(SHUFFLE,'GREATERTHANOREQUALS',6))),
    BuiltinConditions.spell('brew-aoe-crane-kick',101546,BuiltinConditions.all(BuiltinConditions.negate(talent(16)),energy('GREATERTHANOREQUALS',70),chi('GREATERTHANOREQUALS',-1),remain(SHUFFLE,'GREATERTHAN',2)))}},
   BuiltinConditions.spell('brew-expel-harm',115072,BuiltinConditions.all(health('LESSTHAN',.95),chi('GREATERTHANOREQUALS',-1))),
   BuiltinConditions.spell('brew-shuffle-jab',100780,BuiltinConditions.all(remain(SHUFFLE,'LESSTHANOREQUALS',2),chi('LESSTHANOREQUALS',1))),
   BuiltinConditions.spell('brew-blackout-kick',100784,BuiltinConditions.any(remain(SHUFFLE,'LESSTHANOREQUALS',2),BuiltinConditions.all({type='SPELL_COOLDOWN',spell=KEG,operator='LESSTHANOREQUALS',value=2},chi('LESSTHANOREQUALS',-1)))),
   BuiltinConditions.spell('brew-jab',100780,BuiltinConditions.all(energy('GREATERTHANOREQUALS',80),chi('GREATERTHANOREQUALS',-1))),
   BuiltinConditions.spell('brew-tiger-palm',100787,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(125359)),remain(125359,'LESSTHANOREQUALS',1.5))),
   BuiltinConditions.spell('brew-spend-kick',100784,chi('GREATERTHANOREQUALS',3)),
   BuiltinConditions.spell('brew-chi-wave',115098),
   BuiltinConditions.spell('brew-zen-sphere',124081,BuiltinConditions.negate(BuiltinConditions.ownBuff(124081))),
   BuiltinConditions.spell('brew-chi-burst',123986),
   BuiltinConditions.spell('brew-palm-filler',100787),
   BuiltinConditions.spell('brew-jab-filler',100780,chi('GREATERTHANOREQUALS',-1)),
   BuiltinConditions.spell('brew-jade-lightning',117952,{type='BEYOND_MELEE',unit='target'}),
  },
 },
}))
