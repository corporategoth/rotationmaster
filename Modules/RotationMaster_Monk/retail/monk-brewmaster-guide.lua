-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Brewmaster Monk after Icy Veins (optimal reference; SimulationCraft
-- agrees in shape): Blackout Kick, Chi Burst (Master of Harmony), Tiger Palm on Blackout Combo, Keg
-- Smash at full charges or with Empty Barrel, Breath of Fire, Rushing Jade Wind before Exploding
-- Keg, Chi Burst (Shado-Pan), Keg Smash, Rushing Jade Wind and Spinning Crane Kick on packs, Tiger
-- Palm and Expel Harm. Disabled: Blackout Combo, Empty Barrel, charges and Stagger are secret or
-- unreadable in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local harmony=BuiltinConditions.known(1262765)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.brewmaster.guide',revision=7,
 blocks={['retail.monk.boundaries']=3,['retail.monk.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'brewmaster','tank','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Brewmaster Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/monk_brewmaster.simc',title='SimulationCraft default action list: Brewmaster',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same shape; its numeric brew logic is Icy Veins\' advice made exact.'},
 },
 body={priority=10,disabled=true,specs={268},
  cooldowns={
   BuiltinConditions.block('bguide-utility','retail.monk.utility','bguide-'),
   BuiltinConditions.spell('bguide-black-ox-brew',115399,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_CHARGES',spell=119582,operator='LESSTHAN',value=1},BuiltinConditions.negate({type='SPELL_AVAIL',spell=322507}))),
   BuiltinConditions.spell('bguide-invoke-niuzao',132578,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-purifying-brew',119582,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-celestial-brew',322507,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-celestial-infusion',1241059,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-touch-of-death',322109,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('bguide-boundaries','retail.monk.boundaries','bguide-'),
   {id='bguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('bguide-pull-keg-smash',121253),BuiltinConditions.stop('bguide-pull-stop')}},
   BuiltinConditions.spell('bguide-blackout-kick',205523),
   BuiltinConditions.spell('bguide-harmony-chi-burst',123986,harmony),
   BuiltinConditions.spell('bguide-blackout-combo',100780,buff(228563)),
   BuiltinConditions.spell('bguide-keg-smash-charges',121253,BuiltinConditions.any(buff(1265307),{type='SPELL_CHARGES',spell=121253,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('bguide-breath-of-fire',115181),
   BuiltinConditions.spell('bguide-keg-jade-wind',116847,{type='SPELL_AVAIL',spell=325153}),
   BuiltinConditions.spell('bguide-exploding-keg',325153),
   BuiltinConditions.spell('bguide-chi-burst',123986,BuiltinConditions.negate(harmony)),
   BuiltinConditions.spell('bguide-keg-smash',121253),
   {id='bguide-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('bguide-aoe-jade-wind',116847),BuiltinConditions.spell('bguide-aoe-crane-kick',101546)}},
   BuiltinConditions.spell('bguide-tiger-palm',100780),
   BuiltinConditions.spell('bguide-expel-harm',322101),
  },
 },
}))
