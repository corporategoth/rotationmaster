-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Brewmaster Monk after Icy Veins (optimal reference; SimulationCraft
-- agrees in shape): Blackout Kick, Chi Burst (Master of Harmony), Tiger Palm on Blackout Combo, Keg
-- Smash at full charges or with Empty Barrel, Breath of Fire, Rushing Jade Wind before Exploding
-- Keg, Chi Burst (Shado-Pan), Keg Smash, Rushing Jade Wind and Spinning Crane Kick on packs, Tiger
-- Palm and Expel Harm. Disabled: Blackout Combo, Empty Barrel, charges and Stagger are secret or
-- unreadable in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local harmony=known(1262765)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.brewmaster.guide',revision=7,
 blocks={['retail.monk.boundaries']=3,['retail.monk.utility']=2},
 nameKey="Reference (Icy Veins)",descriptionKey="Reference only, off by default: Icy Veins' Brewmaster priority (SimulationCraft agrees in shape). Blackout Combo, Empty Barrel and charges are hidden in Midnight combat, so it cannot run there. Pulls with Keg Smash. Blackout Kick; Chi Burst (Master of Harmony); Tiger Palm on Blackout Combo; Keg Smash at full charges or with Empty Barrel; Breath of Fire; Rushing Jade Wind before Exploding Keg; Chi Burst (Shado-Pan); Keg Smash; Rushing Jade Wind and Spinning Crane Kick on three or more enemies; Tiger Palm; Expel Harm. Reminders: Black Ox Brew once Purifying and Celestial Brew are spent, Invoke Niuzao, Purifying Brew, Celestial Brew or Infusion, Touch of Death, plus the utility reminders.",
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'brewmaster','tank','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Brewmaster Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/monk_brewmaster.simc',title='SimulationCraft default action list: Brewmaster',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same shape; its numeric brew logic is Icy Veins\' advice made exact.'},
 },
 body={priority=10,disabled=true,specs={268},
  cooldowns={
   block('bguide-utility','retail.monk.utility','bguide-'),
   spell('bguide-black-ox-brew',115399,all(combat(),{type='SPELL_CHARGES',spell=119582,operator='LESSTHAN',value=1},negate({type='SPELL_AVAIL',spell=322507}))),
   spell('bguide-invoke-niuzao',132578,combat()),
   spell('bguide-purifying-brew',119582,combat()),
   spell('bguide-celestial-brew',322507,combat()),
   spell('bguide-celestial-infusion',1241059,combat()),
   spell('bguide-touch-of-death',322109,combat()),
  },
  rotation={
   block('bguide-boundaries','retail.monk.boundaries','bguide-'),
   {id='bguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('bguide-pull-keg-smash',121253),stop('bguide-pull-stop')}},
   spell('bguide-blackout-kick',205523),
   spell('bguide-harmony-chi-burst',123986,harmony),
   spell('bguide-blackout-combo',100780,buff(228563)),
   spell('bguide-keg-smash-charges',121253,any(buff(1265307),{type='SPELL_CHARGES',spell=121253,operator='GREATERTHANOREQUALS',value=2})),
   spell('bguide-breath-of-fire',115181),
   spell('bguide-keg-jade-wind',116847,{type='SPELL_AVAIL',spell=325153}),
   spell('bguide-exploding-keg',325153),
   spell('bguide-chi-burst',123986,negate(harmony)),
   spell('bguide-keg-smash',121253),
   {id='bguide-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('bguide-aoe-jade-wind',116847),spell('bguide-aoe-crane-kick',101546)}},
   spell('bguide-tiger-palm',100780),
   spell('bguide-expel-harm',322101),
  },
 },
}))
