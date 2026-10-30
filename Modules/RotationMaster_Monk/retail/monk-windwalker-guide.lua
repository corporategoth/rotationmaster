-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Windwalker Monk after Icy Veins (Conduit of the Celestials; Shado-Pan and
-- SimulationCraft differ trivially), optimal reference. Every step keeps Combo Strikes: never the
-- spell you cast last. Disabled: Heart of the Jade Serpent, Zenith, Blackout Kick!, Dance of Chi-Ji,
-- and cooldown times are secret in Midnight combat; only Chi and your own casts stay readable. Energy
-- is secret on Retail, so the Tiger Palm before the energy cap is left out.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
-- Combo Strikes: RM has no rotation-wide "not the previous cast" rule, so each step carries it.
local function strike(id,action,conditions)
 local fresh=BuiltinConditions.negate({type='SPELL_HISTORY',spell=action,operator='EQUALS',value=1})
 return BuiltinConditions.spell(id,action,conditions and BuiltinConditions.all(fresh,conditions)or fresh)
end
local heart=BuiltinConditions.any(buff(443421),buff(443616))
local zenith=buff(1249625)
local bok={type='BUFF_STACKS',unit='player',spell=116768,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.windwalker.guide',revision=6,
 blocks={['retail.monk.boundaries']=3,['retail.monk.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'windwalker','melee','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/windwalker-monk-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Windwalker Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/monk_windwalker.simc',title='SimulationCraft default action list: Windwalker',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same order with more energy and Heart of the Jade Serpent gates.'},
 },
 body={priority=10,disabled=true,specs={269},
  cooldowns={
   BuiltinConditions.block('wguide-utility','retail.monk.utility','wguide-'),
   BuiltinConditions.spell('wguide-touch-of-karma',122470,{type='COMBAT',unit='player'}),
  },
  rotation={
   BuiltinConditions.block('wguide-boundaries','retail.monk.boundaries','wguide-'),
   strike('wguide-grace-dragon-punch',152175,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(123904)),{type='SPELL_COOLDOWN',spell=123904,operator='GREATERTHAN',value=10})),
   strike('wguide-zenith-stomp',1272696,BuiltinConditions.any(chi('LESSTHAN',2),{type='BUFF_REMAIN',unit='player',spell=1249625,ownbuff=true,operator='LESSTHAN',value=2})),
   strike('wguide-conduit-no-heart',443028,BuiltinConditions.negate(heart)),
   strike('wguide-heart-fists',113656,BuiltinConditions.all(buff(443421),{type='BUFF_REMAIN',unit='player',spell=443421,ownbuff=true,operator='LESSTHAN',value=1})),
   strike('wguide-conduit',443028),
   strike('wguide-invoke-xuen',123904),
   strike('wguide-fists-of-fury',113656),
   strike('wguide-dragon-punch',152175),
   strike('wguide-windlord',392983),
   strike('wguide-short-blackout-kick',100784,chi('LESSTHAN',3)),
   strike('wguide-rushing-wind-kick',467307),
   strike('wguide-rising-sun-kick',107428),
   strike('wguide-stacked-blackout-kick',100784,BuiltinConditions.any(bok,zenith)),
   strike('wguide-zenith-crane-kick',101546,BuiltinConditions.any(BuiltinConditions.all(zenith,chi('GREATERTHAN',4)),buff(325202))),
   strike('wguide-touch-of-death',322109),
   strike('wguide-short-tiger-palm',100780,chi('LESSTHAN',2)),
   strike('wguide-proc-blackout-kick',100784,buff(116768)),
   strike('wguide-slicing-winds',1217413),
   strike('wguide-tiger-palm',100780,chi('LESSTHAN',4)),
   strike('wguide-blackout-kick',100784),
  },
 },
}))
