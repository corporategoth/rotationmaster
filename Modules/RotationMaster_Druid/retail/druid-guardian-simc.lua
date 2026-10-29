-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Guardian Druid after SimulationCraft (defensive reference): Ironfur first in
-- Berserk; Thrash kept refreshed and stacked; Maul on Gory Fur; Thrash on packs; Mangle while Red Moon
-- ticks; Red Moon; Mangle; Thrash; Moonfire; Swipe. Rage is secret on Retail, so its rage thresholds
-- (Ironfur at 40, Maul at 90) are left out. Disabled: secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian.simc',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'guardian','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_guardian.simc',title='SimulationCraft default action list: Guardian',reviewedAt='2026-10-23',revision='c5fea93f',notes='Heart of the Wild and Feline Potential cat-weaving sub-lists left out.'},
 },
 body={priority=5,disabled=true,specs={104},
  cooldowns={
   BuiltinConditions.block('gsimc-utility','retail.druid.utility','gsimc-'),
   BuiltinConditions.spell('gsimc-bear-form',5487,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(5487)),BuiltinConditions.negate(buff(102558)))),
   BuiltinConditions.spell('gsimc-skull-bash',106839,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   BuiltinConditions.spell('gsimc-frenzied-regeneration',22842,BuiltinConditions.combat()),
   BuiltinConditions.spell('gsimc-survival-instincts',61336,BuiltinConditions.combat()),
   BuiltinConditions.spell('gsimc-berserk',50334,BuiltinConditions.combat()),
   BuiltinConditions.spell('gsimc-incarnation',102558,BuiltinConditions.combat()),
   BuiltinConditions.spell('gsimc-lunar-beam',204066,BuiltinConditions.combat()),
   BuiltinConditions.spell('gsimc-convoke',391528,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('gsimc-boundaries','retail.druid.boundaries','gsimc-'),
   BuiltinConditions.spell('gsimc-ironfur',192081,BuiltinConditions.any(buff(50334),buff(102558))),
   BuiltinConditions.spell('gsimc-thrash-refresh',77758,BuiltinConditions.any(BuiltinConditions.negate(debuff(192090)),{type='DEBUFF_REMAIN',unit='target',spell=192090,owndebuff=true,operator='LESSTHAN',value=4.5},{type='DEBUFF_STACKS',unit='target',spell=192090,owndebuff=true,operator='LESSTHAN',value=3})),
   BuiltinConditions.spell('gsimc-gory-maul',6807,buff(1307881)),
   BuiltinConditions.spell('gsimc-thrash-aoe',77758,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   BuiltinConditions.spell('gsimc-red-moon-mangle',33917,debuff(1252871)),
   BuiltinConditions.spell('gsimc-red-moon',1252871,BuiltinConditions.negate(debuff(1252871))),
   BuiltinConditions.spell('gsimc-mangle',33917),
   BuiltinConditions.spell('gsimc-thrash',77758),
   BuiltinConditions.spell('gsimc-moonfire',8921),
   BuiltinConditions.spell('gsimc-swipe',213771),
  },
 },
}))
