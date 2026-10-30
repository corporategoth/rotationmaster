-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Monk before a specialization (levels 1–9, or a monk who has not picked
-- one): the catch-all, lowest priority, switch always true. Fierce Tiger, Tiger Power from Tiger
-- Palm, Blackout Kick at two Chi, Expel Harm when hurt, Jab. Jab is the opener (no ranged spell yet).
-- RM policy from the 1–9 kit and the Windwalker priority; no guide writes a 1–9 list.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hurt()return{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.8}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.unspecialized',revision=5,
 blocks={['mop.monk.boundaries']=3,['mop.monk.upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'leveling','single-target'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/windwalker-monk-leveling',title='Icy Veins: MoP Classic Windwalker Monk leveling',reviewedAt='2026-10-23',revision='2025-06-17',notes='Early kit (Expel Harm at 7); the 1–9 order is RM policy from the Windwalker priority.'},
  {url='https://www.warcrafttavern.com/mop/guides/monk-leveling-guide/',title='Warcraft Tavern: MoP Monk leveling guide',reviewedAt='2026-10-23'},
 },
 body={priority=0,
  cooldowns={
   BuiltinConditions.spell('monk-tiger-stance',103985,BuiltinConditions.negate({type='FORM',form=103985})),
   BuiltinConditions.block('monk-class','mop.monk.upkeep','monk-'),
  },
  rotation={
   BuiltinConditions.block('monk-boundaries','mop.monk.boundaries','monk-'),
   BuiltinConditions.spell('monk-tiger-palm',100787,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(125359)),{type='BUFF_REMAIN',unit='player',spell=125359,ownbuff=true,operator='LESSTHANOREQUALS',value=2})),
   BuiltinConditions.spell('monk-blackout-kick',100784,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('monk-expel-harm',115072,hurt()),
   BuiltinConditions.spell('monk-expel-harm-early',115129,BuiltinConditions.all(hurt(),BuiltinConditions.negate({type='SPELL_KNOWN',spell=115072}))),
   BuiltinConditions.spell('monk-jab',100780),
  },
 },
}))
