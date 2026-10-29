-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Feral Druid after Icy Veins and SimulationCraft (optimal reference): Cat
-- Form, Prowl and Rake to open; Chomp; Ferocious Bite on Apex Predator's Craving; at five combo
-- points Primal Wrath on two or more enemies, Rip when missing or in its last 7 seconds, else
-- Ferocious Bite (and nothing else until a finisher is affordable); below five, Rake when missing or
-- in its last 4.5 seconds, Lunar Inspiration Moonfire, Swipe on three or more, Shred. Disabled:
-- bleeds and procs are secret in Midnight combat (combo points stay readable); energy is secret on
-- Retail, so Tiger's Fury is a reminder whenever it is ready in combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function refresh(id,remain)return BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=id,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=remain})end
local fury=buff(5217)
local berserk=BuiltinConditions.any(buff(106951),buff(102543))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.feral.guide',revision=7,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'feral','melee','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/feral-druid-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Feral Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_feral.simc',title='SimulationCraft default action list: Feral',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={103},
  cooldowns={
   BuiltinConditions.block('feguide-utility','retail.druid.utility','feguide-'),
   BuiltinConditions.spell('feguide-skull-bash',106839,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   BuiltinConditions.spell('feguide-survival-instincts',61336,BuiltinConditions.combat()),
   BuiltinConditions.spell('feguide-tigers-fury',5217,BuiltinConditions.combat()),
   BuiltinConditions.spell('feguide-berserk',106951,fury),
   BuiltinConditions.spell('feguide-incarnation',102543,fury),
   BuiltinConditions.spell('feguide-feral-frenzy',274837,BuiltinConditions.all(fury,points('LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('feguide-frantic-frenzy',1243807,BuiltinConditions.all(fury,points('LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('feguide-convoke',391528,BuiltinConditions.all(fury,berserk,{type='DEBUFF',unit='target',spell=1079,owndebuff=true})),
  },
  rotation={
   BuiltinConditions.block('feguide-boundaries','retail.druid.boundaries','feguide-'),
   {id='feguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('feguide-pull-cat-form',768,BuiltinConditions.all(BuiltinConditions.negate(buff(768)),BuiltinConditions.negate(buff(102543)))),
    BuiltinConditions.spell('feguide-pull-prowl',5215,BuiltinConditions.negate({type='STEALTHED'})),
    BuiltinConditions.spell('feguide-pull-rake',1822),
    BuiltinConditions.stop('feguide-pull-stop')}},
   BuiltinConditions.spell('feguide-chomp',1244258),
   BuiltinConditions.spell('feguide-apex-bite',22568,buff(391882)),
   {id='feguide-finish',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
    BuiltinConditions.spell('feguide-primal-wrath',285381,engaged(2)),
    BuiltinConditions.spell('feguide-rip',1079,refresh(1079,7)),
    BuiltinConditions.spell('feguide-bite',22568),
    BuiltinConditions.stop('feguide-pool')}},
   BuiltinConditions.spell('feguide-rake',1822,refresh(155722,4.5)),
   BuiltinConditions.spell('feguide-moonfire',155625,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=155625,owndebuff=true})),
   BuiltinConditions.spell('feguide-swipe',213764,engaged(3)),
   BuiltinConditions.spell('feguide-shred',5221),
  },
 },
}))
