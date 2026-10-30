-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Unholy Death Knight, rune-cap and Shadow Infusion pooling (simulator
-- default APL as far as RM can read it; wowtbc.gg, Method and MaxDps agree). Off by default, same
-- switch as rm.mop.deathknight.unholy: Death Coil rebuilds Shadow Infusion while Dark Transformation
-- is down, Scourge Strike first when both Unholy or both Death runes are up, Festering Strike first
-- when both Blood and both Frost runes are up. Snapshot and trinket timing are left out.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,n)return{type='RUNE',rune=kind,operator='EQUALS',value=n}end
local function remain(id)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=3}end
local infusion={type='BUFF_STACKS',unit='pet',spell=91342,operator='GREATERTHANOREQUALS',value=5}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.unholy.simulator',revision=5,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.unholy-upkeep']=2,['mop.deathknight.unholy-open']=2,
  ['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','single-target','aoe'},
 sources={

  {url='https://wowtbc.gg/mop/class-guides/unholy-death-knight/',title='wowtbc.gg: MoP Unholy Death Knight',reviewedAt='2026-10-23',notes='Death Coil to five stacks while Dark Transformation is down; rune-pair order.'},
  {url='https://www.method.gg/mop-classic/unholy-death-knight-class-guide-mop-classic',title='Method: MoP Classic Unholy Death Knight',reviewedAt='2026-10-23',revision='2025-07-22'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight/blob/95faf1baa6e91b0d5e32480227e35f54409dcfc2/Specialization/Mop/Unholy.lua',title='MaxDps-DeathKnight MoP Unholy',reviewedAt='2026-10-23',revision='95faf1baa6',notes='Same rune-pair rule; IDs not used.'},
 },
 body={priority=5,disabled=true,switch=BuiltinConditions.known(47541),
  cooldowns={
   BuiltinConditions.block('ucap-upkeep','mop.deathknight.unholy-upkeep','ucap-'),
   BuiltinConditions.block('ucap-class','mop.deathknight.upkeep','ucap-'),
  },
  rotation={
   BuiltinConditions.block('ucap-boundaries','mop.deathknight.boundaries','ucap-'),
   BuiltinConditions.block('ucap-open','mop.deathknight.unholy-open','ucap-'),
   BuiltinConditions.spell('ucap-plague-leech',123693,BuiltinConditions.all(BuiltinConditions.any(remain(55095),remain(55078)),{type='SPELL_AVAIL',spell=77575})),
   BuiltinConditions.spell('ucap-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=10}),
   BuiltinConditions.spell('ucap-soul-reaper',130736,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   BuiltinConditions.spell('ucap-dark-transformation',63560,infusion),
   BuiltinConditions.spell('ucap-death-coil-infusion',47541,BuiltinConditions.all(BuiltinConditions.known(63560),BuiltinConditions.negate({type='BUFF',unit='pet',spell=63560}),BuiltinConditions.negate(infusion))),
   BuiltinConditions.spell('ucap-death-coil-cap',47541,rp('GREATERTHANOREQUALS',90)),
   BuiltinConditions.spell('ucap-scourge-capped',55090,BuiltinConditions.any(rune(3,2),rune(4,2))),
   BuiltinConditions.spell('ucap-festering-capped',85948,BuiltinConditions.all(rune(1,2),rune(2,2))),
   BuiltinConditions.spell('ucap-sudden-doom',47541,BuiltinConditions.buff(81340)),
   BuiltinConditions.spell('ucap-scourge-strike',55090),
   BuiltinConditions.spell('ucap-festering-strike',85948),
   BuiltinConditions.spell('ucap-blood-strike',45902,BuiltinConditions.negate(BuiltinConditions.known(85948))),
   BuiltinConditions.spell('ucap-death-coil',47541,rp('GREATERTHANOREQUALS',40)),
   BuiltinConditions.spell('ucap-horn-filler',57330),
  },
 },
}))
