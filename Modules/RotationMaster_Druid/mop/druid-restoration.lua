-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Restoration Druid, levels 10–90, in the Restoration specialization (105). Wowhead's
-- Phase 5 group healing (Icy Veins, Method, wowtbc and Warcraft Tavern order the same tools): three
-- Lifeblooms on the focus tank, Wild Mushroom kept down, Swiftmend for emergencies and Harmony (and
-- into Wild Growth with Soul of the Forest), Wild Growth on group damage, Regrowth on Clearcasting,
-- Rejuvenation, then Healing Touch and Nourish on what is left. Heals act on your friendly target (or
-- yourself with none); choosing whom to heal is yours. An attackable target gets Moonfire and Wrath.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hot(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function group(pct,n)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=pct,operator='GREATERTHANOREQUALS',value=n}end
local still=BuiltinConditions.negate({type='MOVING'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.restoration',revision=6,
 blocks={['mop.druid.boundaries']=4,['mop.druid.mark']=1,['mop.druid.healer-upkeep']=1,['mop.druid.healer-open']=3},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'restoration','healer','leveling','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/restoration/healer-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Restoration Druid healing',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/restoration-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.method.gg/mop-classic/restoration-druid-class-guide-mop-classic',title='Method: MoP Classic Restoration Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Harmony from a direct heal.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-restoration-druid-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Restoration Druid',reviewedAt='2026-10-23',notes='Damage in downtime.'},
 },
 body={priority=30,specs={105},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('resto-mark','mop.druid.mark','resto-'),
   BuiltinConditions.block('resto-upkeep','mop.druid.healer-upkeep','resto-'),
  },
  rotation={
   BuiltinConditions.block('resto-boundaries','mop.druid.boundaries','resto-'),
   BuiltinConditions.block('resto-open','mop.druid.healer-open','resto-'),
   BuiltinConditions.spell('resto-swiftmend',18562,BuiltinConditions.all(BuiltinConditions.any(hot(774),hot(8936)),BuiltinConditions.any(hurt(.6),BuiltinConditions.negate(BuiltinConditions.ownBuff(100977)),
    BuiltinConditions.all({type='TALENT',layout='grid',value=10},group(.9,3),{type='SPELL_AVAIL',spell=48438})))),
   BuiltinConditions.spell('resto-wild-growth',48438,group(.9,3)),
   BuiltinConditions.spell('resto-swift-touch',5185,BuiltinConditions.ownBuff(132158)),
   BuiltinConditions.spell('resto-regrowth',8936,BuiltinConditions.any(BuiltinConditions.all(hurt(.9),BuiltinConditions.any(BuiltinConditions.ownBuff(16870),{type='FORM',form=33891})),hurt(.35))),
   BuiltinConditions.spell('resto-tree-lifebloom',33763,BuiltinConditions.all({type='FORM',form=33891},BuiltinConditions.negate(hot(33763)))),
   BuiltinConditions.spell('resto-rejuvenation',774,BuiltinConditions.all(BuiltinConditions.negate(hot(774)),hurt(.95))),
   BuiltinConditions.spell('resto-healing-touch',5185,BuiltinConditions.all(hurt(.5),still)),
   BuiltinConditions.spell('resto-nourish',50464,BuiltinConditions.all(hurt(.85),still)),
   BuiltinConditions.stop('resto-heal-stop'),
  },
 },
}))
