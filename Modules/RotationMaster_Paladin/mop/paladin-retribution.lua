-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Retribution Paladin, levels 10–90, in the Retribution specialization (70).
-- simulator' measured order (Hekili ports it, Wowhead's guide matches it) with Icy Veins' leveling
-- advice: Inquisition kept up at 3 Holy Power, Templar's Verdict at full Holy Power before any
-- generator, Hammer of Wrath > Crusader Strike > Judgment > Exorcism, no pooling in Avenging Wrath,
-- Divine Storm at two or more enemies. The Exorcism-first variant is
-- rm.mop.paladin.retribution.warcrafttavern.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local INQ,WINGS=84963,31884
-- Holy Power at its maximum (3, or 5 from 85): a deficit below 1.
local capped=hp('LESSTHAN',-1)
local free=BuiltinConditions.any(BuiltinConditions.buff(90174),BuiltinConditions.buff(105809))
local inquisition=BuiltinConditions.any(BuiltinConditions.buff(INQ),BuiltinConditions.negate(BuiltinConditions.known(INQ)))
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.retribution',revision=6,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-truth']=2,['mop.paladin.defensives']=1,['mop.paladin.ret-survival']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'retribution','leveling','single-target','aoe','hekili','wowhead','icy-veins'},
 sources={

  {url='https://github.com/Smufrik/Hekili/blob/main/MistsOfPandaria/Priorities/PaladinRetribution.simc',title='Hekili MoP Classic: Retribution priority',reviewedAt='2026-10-23',revision='1c11434a',notes='A port of the simulator list; Inquisition at 3 Holy Power or Divine Purpose.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/paladin/retribution/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2025-07-27',notes='Read from a Wayback snapshot; Divine Storm at 2+, Hammer of the Righteous at 4+.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/retribution-paladin-leveling',title='Icy Veins: MoP Classic Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2025-09-23',notes='Word of Glory when in danger; Inquisition only from 81.'},
 },
 body={priority=30,specs={70},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('ret-seal','mop.paladin.seal-truth','ret-'),
   BuiltinConditions.block('ret-upkeep','mop.paladin.upkeep','ret-'),
   BuiltinConditions.spell('ret-avenging-wrath',WINGS,BuiltinConditions.all(BuiltinConditions.combat(),inquisition,BuiltinConditions.any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))),
   BuiltinConditions.spell('ret-guardian',86698,BuiltinConditions.all(BuiltinConditions.combat(),inquisition,BuiltinConditions.any(BuiltinConditions.buff(WINGS),{type='SPELL_AVAIL',spell=WINGS}))),
   BuiltinConditions.spell('ret-holy-avenger',105809,BuiltinConditions.all(BuiltinConditions.buff(WINGS),hp('LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('ret-execution-sentence',114157,BuiltinConditions.all(BuiltinConditions.combat(),inquisition)),
   BuiltinConditions.spell('ret-lights-hammer',114158,BuiltinConditions.all(BuiltinConditions.combat(),inquisition)),
   BuiltinConditions.block('ret-defensives','mop.paladin.defensives','ret-'),
  },
  rotation={
   BuiltinConditions.block('ret-boundaries','mop.paladin.damage-boundaries','ret-'),
   {id='ret-pull',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
    BuiltinConditions.spell('ret-pull-judgment',20271),BuiltinConditions.spell('ret-pull-exorcism',879),BuiltinConditions.stop('ret-pull-stop')}},
   BuiltinConditions.block('ret-survival','mop.paladin.ret-survival','ret-'),
   BuiltinConditions.spell('ret-inquisition',INQ,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(INQ)),{type='BUFF_REMAIN',unit='player',spell=INQ,operator='LESSTHANOREQUALS',value=3}),BuiltinConditions.any(hp('GREATERTHANOREQUALS',3),BuiltinConditions.buff(90174)))),
   {id='ret-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    BuiltinConditions.spell('ret-aoe-divine-storm-spend',53385,BuiltinConditions.any(capped,free,BuiltinConditions.buff(WINGS),BuiltinConditions.buff(144595))),
    BuiltinConditions.spell('ret-aoe-verdict-spend',85256,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(53385)),BuiltinConditions.any(capped,free))),
    BuiltinConditions.spell('ret-aoe-hammer-wrath',24275),
    BuiltinConditions.spell('ret-aoe-hammer-righteous',53595,{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=4}),
    BuiltinConditions.spell('ret-aoe-crusader-strike',35395),
    BuiltinConditions.spell('ret-aoe-judgment',20271),
    BuiltinConditions.spell('ret-aoe-exorcism',879),
    BuiltinConditions.spell('ret-aoe-divine-storm',53385),
    BuiltinConditions.spell('ret-aoe-verdict',85256,BuiltinConditions.negate(BuiltinConditions.known(53385))),
    BuiltinConditions.stop('ret-aoe-stop')}},
   BuiltinConditions.spell('ret-verdict-capped',85256,BuiltinConditions.any(capped,free)),
   BuiltinConditions.spell('ret-divine-crusader',53385,BuiltinConditions.buff(144595)),
   BuiltinConditions.spell('ret-hammer-wrath',24275),
   BuiltinConditions.spell('ret-verdict-wings',85256,BuiltinConditions.buff(WINGS)),
   BuiltinConditions.spell('ret-judgment-wings',20271,BuiltinConditions.buff(WINGS)),
   BuiltinConditions.spell('ret-crusader-strike',35395),
   BuiltinConditions.spell('ret-judgment',20271),
   BuiltinConditions.spell('ret-exorcism',879),
   BuiltinConditions.spell('ret-verdict',85256,BuiltinConditions.any({type='BUFF_REMAIN',unit='player',spell=INQ,operator='GREATERTHAN',value=4},BuiltinConditions.negate(BuiltinConditions.known(INQ)))),
   BuiltinConditions.spell('ret-holy-prism',114165),
  },
 },
}))
