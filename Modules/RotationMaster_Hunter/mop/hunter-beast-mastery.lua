-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Beast Mastery Hunter, levels 10–90, in the Beast Mastery
-- specialization (253). Wowhead's Phase 5 order, which the simulator APL matches, with
-- simulator' Beast Cleave and pack Kill Command gates and Hekili's Bestial Wrath focus floor: Kill
-- Shot, Kill Command (held in the 3 s before Bestial Wrath), talents, Focus Fire at five Frenzy
-- outside Bestial Wrath, Serpent Sting kept up by Cobra Shot, Arcane Shot as a focus dump, Cobra
-- or Steady Shot. Two or more enemies: Multi-Shot keeps Beast Cleave up.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function petbuff(id)return{type='BUFF',unit='pet',spell=id}end
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function cooldown(id,op,v)return{type='SPELL_COOLDOWN',spell=id,operator=op,value=v}end
local WRATH=19574
local wrath=petbuff(WRATH)
local worth=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('elite'),BuiltinConditions.classified('rareelite'),BuiltinConditions.classified('worldboss'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))
-- Rapid Fire, Stampede and racials inside Bestial Wrath, or when it is more than 15 s away.
local window=BuiltinConditions.all(worth,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(WRATH)),wrath,cooldown(WRATH,'GREATERTHAN',15)))
local frenzy=BuiltinConditions.any({type='BUFF_STACKS',unit='pet',spell=19615,operator='GREATERTHANOREQUALS',value=5},
 BuiltinConditions.all({type='BUFF_STACKS',unit='pet',spell=19615,operator='GREATERTHANOREQUALS',value=4},{type='BUFF_REMAIN',unit='pet',spell=19615,operator='LESSTHAN',value=3}))
local focusFire=BuiltinConditions.all(BuiltinConditions.negate(wrath),frenzy)
local thrill=BuiltinConditions.buff(34720)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.beastmastery',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1,['mop.hunter.filler']=2},
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
   BuiltinConditions.block('bm-pet','mop.hunter.pet','bm-'),
   BuiltinConditions.block('bm-aspect','mop.hunter.aspect','bm-'),
   BuiltinConditions.block('bm-utility','mop.hunter.utility','bm-'),
   BuiltinConditions.spell('bm-bestial-wrath',WRATH,BuiltinConditions.all(worth,{type='PET'},cooldown(34026,'LESSTHAN',1),focus('GREATERTHANOREQUALS',50))),
   BuiltinConditions.spell('bm-rapid-fire',3045,BuiltinConditions.all(window,BuiltinConditions.negate(BuiltinConditions.buff(3045)))),
   BuiltinConditions.spell('bm-stampede',121818,window),
   BuiltinConditions.spell('bm-blood-fury',20572,window),
   BuiltinConditions.spell('bm-berserking',26297,window),
  },
  rotation={
   BuiltinConditions.block('bm-boundaries','mop.hunter.boundaries','bm-'),
   {id='bm-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.block('bm-pull-mark','mop.hunter.mark','bm-pull-'),
    BuiltinConditions.spell('bm-pull-kill-command',34026),
    BuiltinConditions.spell('bm-pull-arcane',3044),
    BuiltinConditions.stop('bm-pull-stop')}},
   {id='bm-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    BuiltinConditions.spell('bm-aoe-beast-cleave',2643,BuiltinConditions.any(BuiltinConditions.negate(petbuff(118455)),{type='BUFF_REMAIN',unit='pet',spell=118455,operator='LESSTHAN',value=1})),
    BuiltinConditions.spell('bm-aoe-kill-shot',53351),
    BuiltinConditions.spell('bm-aoe-kill-command',34026,BuiltinConditions.any(enemies('LESSTHANOREQUALS',2),focus('GREATERTHANOREQUALS',80),wrath)),
    BuiltinConditions.spell('bm-aoe-explosive-trap',13813,enemies('GREATERTHANOREQUALS',3)),
    BuiltinConditions.block('bm-aoe-shots','mop.hunter.talent-shots','bm-aoe-'),
    BuiltinConditions.spell('bm-aoe-serpent-sting',1978,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=118253,owndebuff=true}),enemies('LESSTHANOREQUALS',4))),
    BuiltinConditions.spell('bm-aoe-focus-fire',82692,focusFire),
    BuiltinConditions.spell('bm-aoe-multi-shot',2643,BuiltinConditions.any(focus('GREATERTHANOREQUALS',70),wrath,thrill)),
    BuiltinConditions.block('bm-aoe-filler','mop.hunter.filler','bm-aoe-')}},
   BuiltinConditions.spell('bm-kill-shot',53351),
   BuiltinConditions.spell('bm-kill-command',34026,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(WRATH)),cooldown(WRATH,'EQUALS',0),cooldown(WRATH,'GREATERTHANOREQUALS',3))),
   BuiltinConditions.block('bm-talents','mop.hunter.talents','bm-'),
   BuiltinConditions.block('bm-shots','mop.hunter.talent-shots','bm-'),
   BuiltinConditions.spell('bm-focus-fire',82692,focusFire),
   BuiltinConditions.block('bm-serpent','mop.hunter.serpent','bm-'),
   BuiltinConditions.spell('bm-arcane',3044,BuiltinConditions.any(focus('GREATERTHANOREQUALS',80),wrath,BuiltinConditions.all(thrill,focus('GREATERTHANOREQUALS',60)))),
   BuiltinConditions.block('bm-filler','mop.hunter.filler','bm-'),
  },
 },
}))
