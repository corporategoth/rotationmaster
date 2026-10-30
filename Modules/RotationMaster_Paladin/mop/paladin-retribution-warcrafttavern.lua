-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Retribution Paladin after Warcraft Tavern, levels 10–90: an alternative
-- to rm.mop.paladin.retribution, off by default (same switch, lower priority). Exorcism first and on
-- every Art of War reset; Inquisition at any Holy Power when it is missing and refreshed at 3 in its
-- last 20 seconds; Crusader Strike, Judgment, Templar's Verdict, Hammer of Wrath (first with
-- Sanctified Wrath in wings). Avenging Wrath and Guardian are kept for elites. Its Seal of
-- Righteousness on any cleave stays your call: the shared seal upkeep keeps a Righteousness you chose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local INQ,WINGS=84963,31884
local inquisition=BuiltinConditions.any(BuiltinConditions.buff(INQ),BuiltinConditions.negate(BuiltinConditions.known(INQ)))
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.retribution.warcrafttavern',revision=6,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-truth']=2,['mop.paladin.defensives']=1,['mop.paladin.ret-survival']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'retribution','leveling','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/pve-retribution-paladin-dps-rotations-cooldowns/',title='Warcraft Tavern: MoP Retribution Paladin rotation',reviewedAt='2026-10-23'},
 },
 body={priority=20,disabled=true,specs={70},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('rettav-seal','mop.paladin.seal-truth','rettav-'),
   BuiltinConditions.block('rettav-upkeep','mop.paladin.upkeep','rettav-'),
   BuiltinConditions.spell('rettav-avenging-wrath',WINGS,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
   BuiltinConditions.spell('rettav-guardian',86698,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
   BuiltinConditions.spell('rettav-holy-avenger',105809,BuiltinConditions.buff(WINGS)),
   BuiltinConditions.block('rettav-defensives','mop.paladin.defensives','rettav-'),
  },
  rotation={
   BuiltinConditions.block('rettav-boundaries','mop.paladin.damage-boundaries','rettav-'),
   {id='rettav-pull',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
    BuiltinConditions.spell('rettav-pull-exorcism',879),BuiltinConditions.spell('rettav-pull-judgment',20271),BuiltinConditions.stop('rettav-pull-stop')}},
   BuiltinConditions.block('rettav-survival','mop.paladin.ret-survival','rettav-'),
   BuiltinConditions.spell('rettav-sanctified-hammer',24275,BuiltinConditions.all({type='TALENT',layout='grid',value=14},BuiltinConditions.buff(WINGS))),
   BuiltinConditions.spell('rettav-exorcism',879),
   BuiltinConditions.spell('rettav-inquisition',INQ,BuiltinConditions.negate(BuiltinConditions.buff(INQ))),
   BuiltinConditions.spell('rettav-inquisition-refresh',INQ,BuiltinConditions.all({type='BUFF_REMAIN',unit='player',spell=INQ,operator='LESSTHAN',value=20},{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3})),
   BuiltinConditions.spell('rettav-execution-sentence',114157,inquisition),
   {id='rettav-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    BuiltinConditions.spell('rettav-aoe-crusader-strike',35395),
    BuiltinConditions.spell('rettav-aoe-lights-hammer',114158),
    BuiltinConditions.spell('rettav-aoe-judgment',20271),
    BuiltinConditions.spell('rettav-aoe-divine-storm',53385),
    BuiltinConditions.spell('rettav-aoe-verdict',85256,BuiltinConditions.negate(BuiltinConditions.known(53385))),
    BuiltinConditions.spell('rettav-aoe-hammer-wrath',24275),
    BuiltinConditions.stop('rettav-aoe-stop')}},
   BuiltinConditions.spell('rettav-crusader-strike',35395),
   BuiltinConditions.spell('rettav-judgment',20271),
   BuiltinConditions.spell('rettav-verdict',85256),
   BuiltinConditions.spell('rettav-hammer-wrath',24275),
  },
 },
}))
