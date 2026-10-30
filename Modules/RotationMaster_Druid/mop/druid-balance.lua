-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Balance Druid, levels 10–90, in the Balance specialization (102). Wowhead's Phase 5
-- list (close to simulator): Moonfire and Sunfire kept up and refreshed inside the matching Eclipse,
-- Starfall in Lunar, Starsurge on Shooting Stars and on cooldown, Hurricane or Astral Storm at five
-- enemies, Starfire in and after Lunar, Wrath in and after Solar. RM cannot read Eclipse energy or
-- its direction, so the filler follows the two Eclipse buffs and, between them, whether Starfire was
-- one of your last three casts. Incarnation at an Eclipse's start, Celestial Alignment as it ends.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local SOLAR,LUNAR,CA,INCARNATION,GRACE,DREAM=48517,48518,112071,102560,16886,145151
local solar,lunar,aligned=BuiltinConditions.ownBuff(SOLAR),BuiltinConditions.ownBuff(LUNAR),BuiltinConditions.ownBuff(CA)
local eclipse=BuiltinConditions.any(lunar,solar)
local worth=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=25})
local dream=BuiltinConditions.all(talent(17),BuiltinConditions.negate(BuiltinConditions.ownBuff(DREAM)),BuiltinConditions.negate(aligned))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.balance',revision=7,
 blocks={['mop.druid.boundaries']=4,['mop.druid.target']=2,['mop.druid.mark']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'balance','leveling','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},

  {url='https://www.icy-veins.com/mists-of-pandaria-classic/balance-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22',notes='Same list; Innervate at 70% mana.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-balance-druid-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Balance Druid',reviewedAt='2026-10-23',notes='Astral Storm in Lunar for AoE.'},
 },
 body={priority=30,specs={102},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('balance-mark','mop.druid.mark','balance-'),
   BuiltinConditions.spell('balance-moonkin',24858,BuiltinConditions.negate(BuiltinConditions.any(BuiltinConditions.form(24858),BuiltinConditions.form(768),BuiltinConditions.form(5487),BuiltinConditions.form(783),BuiltinConditions.form(1066),BuiltinConditions.form(33943),BuiltinConditions.form(40120)))),
   BuiltinConditions.spell('balance-incarnation',INCARNATION,BuiltinConditions.all(BuiltinConditions.combat(),eclipse,BuiltinConditions.any({type='SPELL_AVAIL',spell=CA},BuiltinConditions.negate(BuiltinConditions.known(CA))),worth)),
   BuiltinConditions.spell('balance-alignment',CA,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(lunar),BuiltinConditions.negate(solar),BuiltinConditions.any(BuiltinConditions.negate(talent(11)),BuiltinConditions.ownBuff(INCARNATION),
    {type='SPELL_COOLDOWN',spell=INCARNATION,operator='GREATERTHAN',value=45}),worth)),
   BuiltinConditions.spell('balance-natures-vigil',124974,BuiltinConditions.any(BuiltinConditions.ownBuff(INCARNATION),aligned,BuiltinConditions.all(BuiltinConditions.negate(talent(11)),eclipse))),
   BuiltinConditions.spell('balance-force-of-nature',33831,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='BUFF_REMAIN',unit='player',spell=GRACE,ownbuff=true,operator='GREATERTHANOREQUALS',value=13},
    {type='SPELL_CHARGES',spell=33831,operator='EQUALS',value=3}))),
   BuiltinConditions.spell('balance-natures-swiftness',132158,dream),
   BuiltinConditions.spell('balance-innervate',29166,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.7})),
   BuiltinConditions.spell('balance-solar-beam',78675,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   BuiltinConditions.spell('balance-barkskin',22812,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.5))),
   BuiltinConditions.spell('balance-renewal',108238,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.4))),
   off('balance-detonate',88751,BuiltinConditions.any(solar,aligned)),
  },
  rotation={
   BuiltinConditions.block('balance-boundaries','mop.druid.boundaries','balance-'),
   {id='balance-forms',type='stop',conditions=BuiltinConditions.any(BuiltinConditions.form(768),BuiltinConditions.form(5487))},
   BuiltinConditions.block('balance-target','mop.druid.target','balance-'),
   {id='balance-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('balance-pull-dream',5185,BuiltinConditions.all(talent(17),BuiltinConditions.negate(BuiltinConditions.ownBuff(DREAM)))),
    BuiltinConditions.spell('balance-pull-moonfire',8921,{type='MOVING'}),
    BuiltinConditions.spell('balance-pull-wrath',5176),
    BuiltinConditions.stop('balance-pull-stop')}},
   BuiltinConditions.spell('balance-astral-communion',127663,BuiltinConditions.all(talent(10),BuiltinConditions.ownBuff(145138),BuiltinConditions.negate(lunar),BuiltinConditions.negate(solar))),
   BuiltinConditions.spell('balance-dream',5185,dream),
   BuiltinConditions.spell('balance-moonfire',8921,BuiltinConditions.any(BuiltinConditions.negate(dot(8921)),remain(8921,'LESSTHAN',2),BuiltinConditions.all(lunar,BuiltinConditions.ownBuff(GRACE),remain(8921,'LESSTHAN',6)),BuiltinConditions.all(aligned,remain(8921,'LESSTHAN',6)))),
   BuiltinConditions.spell('balance-sunfire',93402,BuiltinConditions.all(BuiltinConditions.negate(aligned),BuiltinConditions.any(BuiltinConditions.negate(dot(93402)),remain(93402,'LESSTHAN',2),BuiltinConditions.all(solar,BuiltinConditions.ownBuff(GRACE),remain(93402,'LESSTHAN',6))))),
   BuiltinConditions.spell('balance-starfall',48505,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(48505)),BuiltinConditions.any(lunar,aligned),
    BuiltinConditions.negate(BuiltinConditions.all(talent(11),{type='SPELL_COOLDOWN',spell=INCARNATION,operator='LESSTHAN',value=35},BuiltinConditions.negate(BuiltinConditions.ownBuff(INCARNATION)))))),
   BuiltinConditions.spell('balance-shooting-stars',78674,BuiltinConditions.ownBuff(93400)),
   BuiltinConditions.spell('balance-starsurge',78674),
   {id='balance-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=5},onFalse={},onTrue={
    BuiltinConditions.spell('balance-aoe-hurricane',16914,solar),
    BuiltinConditions.spell('balance-aoe-astral-storm',106996,lunar)}},
   {id='balance-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('balance-moving-moonfire',8921,BuiltinConditions.any(lunar,BuiltinConditions.negate(solar))),
    BuiltinConditions.spell('balance-moving-sunfire',93402),
    BuiltinConditions.stop('balance-moving-stop')}},
   BuiltinConditions.spell('balance-lunar-starfire',2912,BuiltinConditions.any(lunar,aligned)),
   BuiltinConditions.spell('balance-solar-wrath',5176,solar),
   BuiltinConditions.spell('balance-toward-solar',2912,{type='SPELL_HISTORY',spell=2912,operator='LESSTHANOREQUALS',value=3}),
   BuiltinConditions.spell('balance-wrath',5176),
  },
 },
}))
