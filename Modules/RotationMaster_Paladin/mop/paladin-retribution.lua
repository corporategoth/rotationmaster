-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Retribution Paladin, levels 10–90, in the Retribution specialization (70).
-- simulator' measured order (Hekili ports it, Wowhead's guide matches it) with Icy Veins' leveling
-- advice: Inquisition kept up at 3 Holy Power, Templar's Verdict at full Holy Power before any
-- generator, Hammer of Wrath > Crusader Strike > Judgment > Exorcism, no pooling in Avenging Wrath,
-- Divine Storm at two or more enemies. The Exorcism-first variant is
-- rm.mop.paladin.retribution.warcrafttavern.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function hp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local INQ,WINGS=84963,31884
-- Holy Power at its maximum (3, or 5 from 85): a deficit below 1.
local capped=hp('LESSTHAN',-1)
local free=any(buff(90174),buff(105809))
local inquisition=any(buff(INQ),negate(known(INQ)))
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.retribution',revision=6,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-truth']=2,['mop.paladin.defensives']=1,['mop.paladin.ret-survival']=1},
 nameKey="Recommended",descriptionKey="Recommended for Retribution, from level 10 in the Retribution specialization. Keeps Inquisition up (cast at 3 Holy Power, refreshed in its last 3 seconds; from 81), spends Templar's Verdict at full Holy Power or on a free proc before generating more, then Hammer of Wrath, Crusader Strike, Judgment and Exorcism, and Templar's Verdict at 3 when nothing else is ready. In Avenging Wrath it spends at once and puts Judgment ahead of Crusader Strike. Two or more enemies on you switch to Divine Storm, with Hammer of the Righteous when four are close. Pulls from range with Judgment or Exorcism, and suggests Word of Glory when you are solo and in danger. Reminders: Seal of Truth when another seal is active or none (Seal of Righteousness is kept), Blessing of Kings or Might, Rebuke, Avenging Wrath and Guardian of Ancient Kings with Inquisition up on elites, Holy Avenger in wings, Execution Sentence and Light's Hammer, and Divine Protection and Lay on Hands when low. Seal of Righteousness for packs and glyph choices stay with you.",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'retribution','leveling','single-target','aoe','hekili','wowhead','icy-veins'},
 sources={

  {url='https://github.com/Smufrik/Hekili/blob/main/MistsOfPandaria/Priorities/PaladinRetribution.simc',title='Hekili MoP Classic: Retribution priority',reviewedAt='2026-10-23',revision='1c11434a',notes='A port of the simulator list; Inquisition at 3 Holy Power or Divine Purpose.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/paladin/retribution/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2025-07-27',notes='Read from a Wayback snapshot; Divine Storm at 2+, Hammer of the Righteous at 4+.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/retribution-paladin-leveling',title='Icy Veins: MoP Classic Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2025-09-23',notes='Word of Glory when in danger; Inquisition only from 81.'},
 },
 body={priority=30,specs={70},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('ret-seal','mop.paladin.seal-truth','ret-'),
   block('ret-upkeep','mop.paladin.upkeep','ret-'),
   spell('ret-avenging-wrath',WINGS,all(combat(),inquisition,any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))),
   spell('ret-guardian',86698,all(combat(),inquisition,any(buff(WINGS),{type='SPELL_AVAIL',spell=WINGS}))),
   spell('ret-holy-avenger',105809,all(buff(WINGS),hp('LESSTHANOREQUALS',2))),
   spell('ret-execution-sentence',114157,all(combat(),inquisition)),
   spell('ret-lights-hammer',114158,all(combat(),inquisition)),
   block('ret-defensives','mop.paladin.defensives','ret-'),
  },
  rotation={
   block('ret-boundaries','mop.paladin.damage-boundaries','ret-'),
   {id='ret-pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
    spell('ret-pull-judgment',20271),spell('ret-pull-exorcism',879),stop('ret-pull-stop')}},
   block('ret-survival','mop.paladin.ret-survival','ret-'),
   spell('ret-inquisition',INQ,all(any(negate(buff(INQ)),{type='BUFF_REMAIN',unit='player',spell=INQ,operator='LESSTHANOREQUALS',value=3}),any(hp('GREATERTHANOREQUALS',3),buff(90174)))),
   {id='ret-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    spell('ret-aoe-divine-storm-spend',53385,any(capped,free,buff(WINGS),buff(144595))),
    spell('ret-aoe-verdict-spend',85256,all(negate(known(53385)),any(capped,free))),
    spell('ret-aoe-hammer-wrath',24275),
    spell('ret-aoe-hammer-righteous',53595,{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=4}),
    spell('ret-aoe-crusader-strike',35395),
    spell('ret-aoe-judgment',20271),
    spell('ret-aoe-exorcism',879),
    spell('ret-aoe-divine-storm',53385),
    spell('ret-aoe-verdict',85256,negate(known(53385))),
    stop('ret-aoe-stop')}},
   spell('ret-verdict-capped',85256,any(capped,free)),
   spell('ret-divine-crusader',53385,buff(144595)),
   spell('ret-hammer-wrath',24275),
   spell('ret-verdict-wings',85256,buff(WINGS)),
   spell('ret-judgment-wings',20271,buff(WINGS)),
   spell('ret-crusader-strike',35395),
   spell('ret-judgment',20271),
   spell('ret-exorcism',879),
   spell('ret-verdict',85256,any({type='BUFF_REMAIN',unit='player',spell=INQ,operator='GREATERTHAN',value=4},negate(known(INQ)))),
   spell('ret-holy-prism',114165),
  },
 },
}))
