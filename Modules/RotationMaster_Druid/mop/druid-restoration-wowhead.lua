-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Restoration Druid for tank healing, after Wowhead's single-target
-- scenario (Method's single-target block agrees): keep the tank targeted. Lifebloom on it, Rejuvenation kept on your
-- target, Regrowth for heavy damage, Nourish for light damage, Healing Touch once Lifebloom and
-- Rejuvenation are already rolling, Swiftmend to keep the target topped. Direct heals replace Wild
-- Growth and Rejuvenation spreading. Shares the Restoration switch at a lower priority and ships
-- disabled.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hot(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local still=BuiltinConditions.negate({type='MOVING'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.restoration.wowhead',revision=6,
 blocks={['mop.druid.boundaries']=4,['mop.druid.mark']=1,['mop.druid.healer-upkeep']=1,['mop.druid.healer-open']=3},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'restoration','healer','tank-healing','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/restoration/healer-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Restoration Druid healing (single-target scenario)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.method.gg/mop-classic/restoration-druid-class-guide-mop-classic',title='Method: MoP Classic Restoration Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Same single-target block.'},
 },
 body={priority=20,disabled=true,specs={105},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('rtank-mark','mop.druid.mark','rtank-'),
   BuiltinConditions.block('rtank-upkeep','mop.druid.healer-upkeep','rtank-'),
  },
  rotation={
   BuiltinConditions.block('rtank-boundaries','mop.druid.boundaries','rtank-'),
   BuiltinConditions.block('rtank-open','mop.druid.healer-open','rtank-'),
   BuiltinConditions.spell('rtank-lifebloom',33763,BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.any(BuiltinConditions.negate(hot(33763)),
    {type='BUFF_STACKS',unit='target',spell=33763,ownbuff=true,operator='LESSTHAN',value=3},
    {type='BUFF_REMAIN',unit='target',spell=33763,ownbuff=true,operator='LESSTHAN',value=4}))),
   BuiltinConditions.spell('rtank-rejuvenation',774,BuiltinConditions.all({type='COMBAT',unit='player'},BuiltinConditions.negate(hot(774)))),
   BuiltinConditions.spell('rtank-swift-touch',5185,BuiltinConditions.ownBuff(132158)),
   BuiltinConditions.spell('rtank-regrowth',8936,hurt(.6)),
   BuiltinConditions.spell('rtank-healing-touch',5185,BuiltinConditions.all(hot(33763),hot(774),hurt(.5),still)),
   BuiltinConditions.spell('rtank-nourish',50464,BuiltinConditions.all(hurt(.9),still)),
   BuiltinConditions.spell('rtank-swiftmend',18562,BuiltinConditions.all(BuiltinConditions.any(hot(774),hot(8936)),hurt(.9))),
   BuiltinConditions.stop('rtank-heal-stop'),
  },
 },
}))
