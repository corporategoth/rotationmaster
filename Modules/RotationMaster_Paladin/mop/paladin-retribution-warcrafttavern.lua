-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Retribution Paladin after Warcraft Tavern, levels 10–90: an alternative
-- to rm.mop.paladin.retribution, off by default (same switch, lower priority). Exorcism first and on
-- every Art of War reset; Inquisition at any Holy Power when it is missing and refreshed at 3 in its
-- last 20 seconds; Crusader Strike, Judgment, Templar's Verdict, Hammer of Wrath (first with
-- Sanctified Wrath in wings). Avenging Wrath and Guardian are kept for elites. Its Seal of
-- Righteousness on any cleave stays your call: the shared seal upkeep keeps a Righteousness you chose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local INQ,WINGS=84963,31884
local inquisition=any(buff(INQ),negate(known(INQ)))
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.retribution.warcrafttavern',revision=6,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-truth']=2,['mop.paladin.defensives']=1,['mop.paladin.ret-survival']=1},
 nameKey='Default.MoP.Paladin.Retribution.WarcraftTavern.Name',descriptionKey='Default.MoP.Paladin.Retribution.WarcraftTavern.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'retribution','leveling','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/pve-retribution-paladin-dps-rotations-cooldowns/',title='Warcraft Tavern: MoP Retribution Paladin rotation',reviewedAt='2026-10-23'},
 },
 body={priority=20,disabled=true,specs={70},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('rettav-seal','mop.paladin.seal-truth','rettav-'),
   block('rettav-upkeep','mop.paladin.upkeep','rettav-'),
   spell('rettav-avenging-wrath',WINGS,all(combat(),elite)),
   spell('rettav-guardian',86698,all(combat(),elite)),
   spell('rettav-holy-avenger',105809,buff(WINGS)),
   block('rettav-defensives','mop.paladin.defensives','rettav-'),
  },
  rotation={
   block('rettav-boundaries','mop.paladin.damage-boundaries','rettav-'),
   {id='rettav-pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
    spell('rettav-pull-exorcism',879),spell('rettav-pull-judgment',20271),stop('rettav-pull-stop')}},
   block('rettav-survival','mop.paladin.ret-survival','rettav-'),
   spell('rettav-sanctified-hammer',24275,all({type='TALENT',layout='grid',value=14},buff(WINGS))),
   spell('rettav-exorcism',879),
   spell('rettav-inquisition',INQ,negate(buff(INQ))),
   spell('rettav-inquisition-refresh',INQ,all({type='BUFF_REMAIN',unit='player',spell=INQ,operator='LESSTHAN',value=20},{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3})),
   spell('rettav-execution-sentence',114157,inquisition),
   {id='rettav-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    spell('rettav-aoe-crusader-strike',35395),
    spell('rettav-aoe-lights-hammer',114158),
    spell('rettav-aoe-judgment',20271),
    spell('rettav-aoe-divine-storm',53385),
    spell('rettav-aoe-verdict',85256,negate(known(53385))),
    spell('rettav-aoe-hammer-wrath',24275),
    stop('rettav-aoe-stop')}},
   spell('rettav-crusader-strike',35395),
   spell('rettav-judgment',20271),
   spell('rettav-verdict',85256),
   spell('rettav-hammer-wrath',24275),
  },
 },
}))
