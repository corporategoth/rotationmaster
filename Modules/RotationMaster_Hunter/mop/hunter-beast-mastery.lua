-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Beast Mastery Hunter, levels 10–90, in the Beast Mastery
-- specialization (253). Wowhead's Phase 5 order, which the simulator APL matches, with
-- simulator' Beast Cleave and pack Kill Command gates and Hekili's Bestial Wrath focus floor: Kill
-- Shot, Kill Command (held in the 3 s before Bestial Wrath), talents, Focus Fire at five Frenzy
-- outside Bestial Wrath, Serpent Sting kept up by Cobra Shot, Arcane Shot as a focus dump, Cobra
-- or Steady Shot. Two or more enemies: Multi-Shot keeps Beast Cleave up.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function petbuff(id)return{type='BUFF',unit='pet',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function cooldown(id,op,v)return{type='SPELL_COOLDOWN',spell=id,operator=op,value=v}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local WRATH=19574
local wrath=petbuff(WRATH)
local worth=all(combat(),any(classified('elite'),classified('rareelite'),classified('worldboss'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))
-- Rapid Fire, Stampede and racials inside Bestial Wrath, or when it is more than 15 s away.
local window=all(worth,any(negate(known(WRATH)),wrath,cooldown(WRATH,'GREATERTHAN',15)))
local frenzy=any({type='BUFF_STACKS',unit='pet',spell=19615,operator='GREATERTHANOREQUALS',value=5},
 all({type='BUFF_STACKS',unit='pet',spell=19615,operator='GREATERTHANOREQUALS',value=4},{type='BUFF_REMAIN',unit='pet',spell=19615,operator='LESSTHAN',value=3}))
local focusFire=all(negate(wrath),frenzy)
local thrill=buff(34720)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.beastmastery',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1,['mop.hunter.filler']=2},
 nameKey='Default.MoP.Hunter.BeastMastery.Name',descriptionKey='Default.MoP.Hunter.BeastMastery.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'beast-mastery','leveling','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/beast-mastery/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Beast Mastery Hunter rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/beast-mastery/dps-leveling-talent-builds-tips',title='Wowhead: MoP Classic Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-06-29'},

  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/HunterBeastMastery.simc',title='Hekili MoP Classic Beast Mastery priority',reviewedAt='2026-10-23',revision='0750b5dd98',notes='Bestial Wrath at 50 focus; no Focus Fire during Bestial Wrath.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/beast-mastery-hunter-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Beast Mastery Hunter rotation',reviewedAt='2026-10-23',revision='2026-05-29',notes='Same abilities; Kill Command before Kill Shot.'},
 },
 body={priority=10,specs={253},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('bm-pet','mop.hunter.pet','bm-'),
   block('bm-aspect','mop.hunter.aspect','bm-'),
   block('bm-utility','mop.hunter.utility','bm-'),
   spell('bm-bestial-wrath',WRATH,all(worth,{type='PET'},cooldown(34026,'LESSTHAN',1),focus('GREATERTHANOREQUALS',50))),
   spell('bm-rapid-fire',3045,all(window,negate(buff(3045)))),
   spell('bm-stampede',121818,window),
   spell('bm-blood-fury',20572,window),
   spell('bm-berserking',26297,window),
  },
  rotation={
   block('bm-boundaries','mop.hunter.boundaries','bm-'),
   {id='bm-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    block('bm-pull-mark','mop.hunter.mark','bm-pull-'),
    spell('bm-pull-kill-command',34026),
    spell('bm-pull-arcane',3044),
    stop('bm-pull-stop')}},
   {id='bm-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    spell('bm-aoe-beast-cleave',2643,any(negate(petbuff(118455)),{type='BUFF_REMAIN',unit='pet',spell=118455,operator='LESSTHAN',value=1})),
    spell('bm-aoe-kill-shot',53351),
    spell('bm-aoe-kill-command',34026,any(enemies('LESSTHANOREQUALS',2),focus('GREATERTHANOREQUALS',80),wrath)),
    spell('bm-aoe-explosive-trap',13813,enemies('GREATERTHANOREQUALS',3)),
    block('bm-aoe-shots','mop.hunter.talent-shots','bm-aoe-'),
    spell('bm-aoe-serpent-sting',1978,all(negate({type='DEBUFF',unit='target',spell=118253,owndebuff=true}),enemies('LESSTHANOREQUALS',4))),
    spell('bm-aoe-focus-fire',82692,focusFire),
    spell('bm-aoe-multi-shot',2643,any(focus('GREATERTHANOREQUALS',70),wrath,thrill)),
    block('bm-aoe-filler','mop.hunter.filler','bm-aoe-')}},
   spell('bm-kill-shot',53351),
   spell('bm-kill-command',34026,any(negate(known(WRATH)),cooldown(WRATH,'EQUALS',0),cooldown(WRATH,'GREATERTHANOREQUALS',3))),
   block('bm-talents','mop.hunter.talents','bm-'),
   block('bm-shots','mop.hunter.talent-shots','bm-'),
   spell('bm-focus-fire',82692,focusFire),
   block('bm-serpent','mop.hunter.serpent','bm-'),
   spell('bm-arcane',3044,any(focus('GREATERTHANOREQUALS',80),wrath,all(thrill,focus('GREATERTHANOREQUALS',60)))),
   block('bm-filler','mop.hunter.filler','bm-'),
  },
 },
}))
