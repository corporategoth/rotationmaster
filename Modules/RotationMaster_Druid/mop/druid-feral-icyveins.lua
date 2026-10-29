-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Feral Druid after Icy Veins (and Wowhead's Ferocious Bite rule): the same
-- upkeep and opener as rm.mop.druid.feral, but combo points above 25% target health go only to Rip
-- and Savage Roar: Ferocious Bite only refreshes Rip in execute (or spends before Rip is learned),
-- Rake and Thrash refresh at two and three seconds, Berserk at 90 energy when Tiger's Fury is at
-- least 15 seconds away. Shares the Feral switch at a lower priority and ships disabled.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local clearcasting,berserk=BuiltinConditions.ownBuff(135700),BuiltinConditions.ownBuff(106951)
local worth=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.feral.icyveins',revision=7,
 blocks={['mop.druid.melee-boundaries']=2,['mop.druid.mark']=1,['mop.druid.feral-upkeep']=2,['mop.druid.feral-open']=4,['mop.druid.feral-aoe']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'feral','leveling','single-target','aoe','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/feral-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/feral-druid-leveling',title='Icy Veins: MoP Classic Feral Druid leveling',reviewedAt='2026-10-23',revision='2025-06-22'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20',notes='Ferocious Bite only below 25% with Rip up.'},
 },
 body={priority=20,disabled=true,specs={103},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('fivy-mark','mop.druid.mark','fivy-'),
   BuiltinConditions.block('fivy-upkeep','mop.druid.feral-upkeep','fivy-'),
   BuiltinConditions.spell('fivy-berserk',106952,BuiltinConditions.all(BuiltinConditions.combat(),{type='FORM',form=768},power('GREATERTHANOREQUALS',90),{type='SPELL_COOLDOWN',spell=5217,operator='GREATERTHANOREQUALS',value=15},worth)),
  },
  rotation={
   BuiltinConditions.block('fivy-boundaries','mop.druid.melee-boundaries','fivy-'),
   BuiltinConditions.block('fivy-open','mop.druid.feral-open','fivy-'),
   BuiltinConditions.block('fivy-aoe','mop.druid.feral-aoe','fivy-'),
   {id='fivy-execute',type='branch',conditions=BuiltinConditions.all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25},bleed(1079)),onTrue={
    BuiltinConditions.spell('fivy-execute-bite',22568,cp('GREATERTHANOREQUALS',5))},
   onFalse={
    BuiltinConditions.spell('fivy-rip',1079,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),BuiltinConditions.any(BuiltinConditions.negate(bleed(1079)),remain(1079,'LESSTHANOREQUALS',2))))}},
   BuiltinConditions.spell('fivy-early-bite',22568,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),BuiltinConditions.negate(BuiltinConditions.known(1079)))),
   BuiltinConditions.spell('fivy-rake',1822,BuiltinConditions.any(BuiltinConditions.negate(bleed(1822)),remain(1822,'LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('fivy-thrash',106832,BuiltinConditions.all(clearcasting,BuiltinConditions.any(BuiltinConditions.negate(bleed(106830)),remain(106830,'LESSTHANOREQUALS',3)))),
   BuiltinConditions.spell('fivy-ravage',102545,BuiltinConditions.ownBuff(102543)),
   BuiltinConditions.spell('fivy-shred',5221,BuiltinConditions.all(BuiltinConditions.any(clearcasting,berserk),BuiltinConditions.negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
   BuiltinConditions.spell('fivy-mangle',33917,BuiltinConditions.any(cp('LESSTHAN',5),power('GREATERTHANOREQUALS',90))),
  },
 },
}))
