-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Feral Druid, levels 10–90, in the Feral specialization (103). simulator' measured
-- order, which Wowhead's Phase 5 list matches except for Ferocious Bite: Savage Roar never drops,
-- Healing Touch on Predatory Swiftness at four or five combo points for Dream of Cenarius, Rip at
-- five points (Ferocious Bite refreshes it below 25%), Bite at five points while Rip and Roar both
-- have six seconds, Rake, Thrash on Clearcasting, Shred on Clearcasting or Berserk when the target is
-- not facing you, Mangle; Thrash and Swipe at four enemies. Bear- and Wrath-weaving stay manual. The
-- Icy Veins/Wowhead "Bite only in execute" variant is rm.mop.druid.feral.icyveins.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local lives=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
local clearcasting,berserk=BuiltinConditions.ownBuff(135700),BuiltinConditions.ownBuff(106951)
local roar6=BuiltinConditions.any({type='BUFF_REMAIN',unit='player',spell=52610,ownbuff=true,operator='GREATERTHANOREQUALS',value=6},
 {type='BUFF_REMAIN',unit='player',spell=127538,ownbuff=true,operator='GREATERTHANOREQUALS',value=6})
local worth=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.feral',revision=7,
 blocks={['mop.druid.melee-boundaries']=2,['mop.druid.mark']=1,['mop.druid.feral-upkeep']=2,['mop.druid.feral-open']=4,['mop.druid.feral-aoe']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'feral','leveling','single-target','aoe','wowhead'},
 sources={

  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.method.gg/mop-classic/feral-druid-class-guide-mop-classic',title='Method: MoP Classic Feral Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Bite at five points when safe.'},
  {url='https://wowtbc.gg/mop/class-guides/feral-druid/',title='wowtbc.gg: MoP Feral Druid',reviewedAt='2026-10-23'},
 },
 body={priority=30,specs={103},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('feral-mark','mop.druid.mark','feral-'),
   BuiltinConditions.block('feral-upkeep','mop.druid.feral-upkeep','feral-'),
   BuiltinConditions.spell('feral-berserk',106952,BuiltinConditions.all(BuiltinConditions.combat(),{type='FORM',form=768},BuiltinConditions.any(BuiltinConditions.ownBuff(5217),BuiltinConditions.all(power('GREATERTHANOREQUALS',90),{type='SPELL_COOLDOWN',spell=5217,operator='GREATERTHANOREQUALS',value=15})),worth)),
  },
  rotation={
   BuiltinConditions.block('feral-boundaries','mop.druid.melee-boundaries','feral-'),
   BuiltinConditions.block('feral-open','mop.druid.feral-open','feral-'),
   BuiltinConditions.block('feral-aoe','mop.druid.feral-aoe','feral-'),
   {id='feral-execute',type='branch',conditions=BuiltinConditions.all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25},bleed(1079)),onTrue={
    BuiltinConditions.spell('feral-execute-bite',22568,BuiltinConditions.any(cp('GREATERTHANOREQUALS',5),BuiltinConditions.all(remain(1079,'LESSTHAN',2),cp('GREATERTHANOREQUALS',1))))},
   onFalse={
    BuiltinConditions.spell('feral-rip',1079,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),lives,BuiltinConditions.any(BuiltinConditions.negate(bleed(1079)),remain(1079,'LESSTHAN',2),BuiltinConditions.all(BuiltinConditions.ownBuff(145152),remain(1079,'LESSTHAN',6)))))}},
   BuiltinConditions.spell('feral-bite',22568,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),BuiltinConditions.negate(clearcasting),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(1079)),BuiltinConditions.all(remain(1079,'GREATERTHANOREQUALS',6),roar6)))),
   BuiltinConditions.spell('feral-rake',1822,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(bleed(1822)),remain(1822,'LESSTHAN',3)),BuiltinConditions.any(BuiltinConditions.ownBuff(52610),BuiltinConditions.ownBuff(127538),BuiltinConditions.negate(BuiltinConditions.known(52610))),BuiltinConditions.negate(clearcasting),lives)),
   BuiltinConditions.spell('feral-thrash',106832,BuiltinConditions.all(BuiltinConditions.any(clearcasting,berserk,BuiltinConditions.ownBuff(145152),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
    BuiltinConditions.any(BuiltinConditions.negate(bleed(106830)),remain(106830,'LESSTHAN',3)))),
   BuiltinConditions.spell('feral-ravage',102545,BuiltinConditions.ownBuff(102543)),
   BuiltinConditions.spell('feral-shred',5221,BuiltinConditions.all(BuiltinConditions.any(clearcasting,berserk),BuiltinConditions.negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
   BuiltinConditions.spell('feral-mangle',33917,BuiltinConditions.any(cp('LESSTHAN',5),power('GREATERTHANOREQUALS',90))),
  },
 },
}))
