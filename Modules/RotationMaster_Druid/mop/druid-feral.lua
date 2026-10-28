-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Feral Druid, levels 10–90, in the Feral specialization (103). wowsims' measured
-- order, which Wowhead's Phase 5 list matches except for Ferocious Bite: Savage Roar never drops,
-- Healing Touch on Predatory Swiftness at four or five combo points for Dream of Cenarius, Rip at
-- five points (Ferocious Bite refreshes it below 25%), Bite at five points while Rip and Roar both
-- have six seconds, Rake, Thrash on Clearcasting, Shred on Clearcasting or Berserk when the target is
-- not facing you, Mangle; Thrash and Swipe at four enemies. Bear- and Wrath-weaving stay manual. The
-- Icy Veins/Wowhead "Bite only in execute" variant is rm.mop.druid.feral.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local lives=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
local clearcasting,berserk=own(135700),own(106951)
local roar6=any({type='BUFF_REMAIN',unit='player',spell=52610,ownbuff=true,operator='GREATERTHANOREQUALS',value=6},
 {type='BUFF_REMAIN',unit='player',spell=127538,ownbuff=true,operator='GREATERTHANOREQUALS',value=6})
local worth=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.feral',revision=7,
 blocks={['mop.druid.melee-boundaries']=2,['mop.druid.mark']=1,['mop.druid.feral-upkeep']=2,['mop.druid.feral-open']=4,['mop.druid.feral-aoe']=2},
 nameKey='Default.MoP.Druid.Feral.Name',descriptionKey='Default.MoP.Druid.Feral.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'feral','leveling','single-target','aoe','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/sim/druid/feral/rotation.go',title='wowsims/mop Feral rotation (default APL)',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.method.gg/mop-classic/feral-druid-class-guide-mop-classic',title='Method: MoP Classic Feral Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Bite at five points when safe.'},
  {url='https://wowtbc.gg/mop/class-guides/feral-druid/',title='wowtbc.gg: MoP Feral Druid',reviewedAt='2026-10-23'},
 },
 body={priority=30,specs={103},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('feral-mark','mop.druid.mark','feral-'),
   block('feral-upkeep','mop.druid.feral-upkeep','feral-'),
   spell('feral-berserk',106952,all(combat(),{type='FORM',form=768},any(own(5217),all(power('GREATERTHANOREQUALS',90),{type='SPELL_COOLDOWN',spell=5217,operator='GREATERTHANOREQUALS',value=15})),worth)),
  },
  rotation={
   block('feral-boundaries','mop.druid.melee-boundaries','feral-'),
   block('feral-open','mop.druid.feral-open','feral-'),
   block('feral-aoe','mop.druid.feral-aoe','feral-'),
   {id='feral-execute',type='branch',conditions=all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25},bleed(1079)),onTrue={
    spell('feral-execute-bite',22568,any(cp('GREATERTHANOREQUALS',5),all(remain(1079,'LESSTHAN',2),cp('GREATERTHANOREQUALS',1))))},
   onFalse={
    spell('feral-rip',1079,all(cp('GREATERTHANOREQUALS',5),lives,any(negate(bleed(1079)),remain(1079,'LESSTHAN',2),all(own(145152),remain(1079,'LESSTHAN',6)))))}},
   spell('feral-bite',22568,all(cp('GREATERTHANOREQUALS',5),negate(clearcasting),any(negate(known(1079)),all(remain(1079,'GREATERTHANOREQUALS',6),roar6)))),
   spell('feral-rake',1822,all(any(negate(bleed(1822)),remain(1822,'LESSTHAN',3)),any(own(52610),own(127538),negate(known(52610))),negate(clearcasting),lives)),
   spell('feral-thrash',106832,all(any(clearcasting,berserk,own(145152),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
    any(negate(bleed(106830)),remain(106830,'LESSTHAN',3)))),
   spell('feral-ravage',102545,own(102543)),
   spell('feral-shred',5221,all(any(clearcasting,berserk),negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
   spell('feral-mangle',33917,any(cp('LESSTHAN',5),power('GREATERTHANOREQUALS',90))),
  },
 },
}))
