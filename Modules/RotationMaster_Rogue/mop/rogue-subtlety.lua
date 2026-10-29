-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Subtlety Rogue, levels 10-90 (the recommended variant): simulator' Phase 5 order with Shadow
-- Focus, which Wowhead's Phase 5 page agrees with. Selected in the Subtlety specialization (261) from
-- level 10. In Stealth or Shadow Dance: Premeditation, Slice and Dice before
-- the pull, five-point finishers in combat, Ambush, Garrote. Three or more engaged enemies: Slice and Dice, Crimson
-- Tempest, Eviscerate, Fan of Knives. One target: Slice and Dice; at five points Slice and Dice and Rupture refreshes
-- under 2 s and Eviscerate while both last; Marked for Death; Hemorrhage for its bleed; Backstab with a dagger when the
-- target is not on you, else Hemorrhage. Reminders: Shadow Dance at 75 energy with both buffs up, Vanish when Find Weakness is ending,
-- Preparation, Shadow Blades outside the windows. Shared parts: mop/blocks.lua; Warcraft Tavern's Subterfuge play is
-- its own premade.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=own(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local hidden={type='STEALTHED'}
local worth=any(boss,lifetime('GREATERTHAN',8))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.subtlety',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.subtlety-builders']=2},
 nameKey="Recommended",descriptionKey="Recommended for Subtlety with Shadow Focus, from level 10 to 90 (simulator and Wowhead for Phase 5). In Stealth or Shadow Dance: Premeditation, Slice and Dice before the pull, finishers at five points, Ambush, Garrote. Outside: Slice and Dice; at five points Slice and Dice and Rupture when they are about to drop, Eviscerate while both last; Marked for Death; Hemorrhage to keep its bleed; Backstab (with a dagger) when the target is not attacking you, otherwise Hemorrhage. Against three or more enemies: Slice and Dice, Crimson Tempest, Eviscerate and Fan of Knives. Solo it adds Recuperate and Kidney Shot. Reminders: poisons, Kick, Shadow Dance at 75 energy with Slice and Dice and Rupture up, Vanish when Find Weakness is ending, Preparation, Shadow Blades outside Dance and Stealth, Shadowstep, Evasion solo. Left to you: standing behind the target (RM cannot see facing), Tricks of the Trade and Expose Armor (listed but off).",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'subtlety','dps','melee','leveling','endgame','wowhead','icy-veins'},
 sources={
 {url='https://www.wowhead.com/mop-classic/guide/classes/rogue/subtlety/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Subtlety Rogue rotation (MoP Classic, Phase 5)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/subtlety-rogue-leveling',title='Icy Veins: Subtlety Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=30,specs={261},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  spell('rogue-subtlety-shadow-dance',51713,all(combat(),negate(hidden),energy('GREATERTHANOREQUALS',75),sliced,mine(1943),worth)),
  spell('rogue-subtlety-vanish',1856,all(combat(),negate(hidden),negate(own(51713)),points('LESSTHAN',3),energy('GREATERTHANOREQUALS',60),
   any(negate(mine(91021)),remain(91021,'LESSTHANOREQUALS',1.5)),any(negate(known(51713)),{type='SPELL_COOLDOWN',spell=51713,operator='GREATERTHANOREQUALS',value=5}))),
  spell('rogue-subtlety-preparation',14185,all(combat(),negate(hidden),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
  spell('rogue-subtlety-shadow-blades',121471,all(combat(),sliced,negate(own(51713)),negate(hidden))),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 {id='rogue-subtlety-window',type='branch',conditions=any(hidden,own(51713)),onFalse={},onTrue={
  spell('rogue-subtlety-premeditation',14183,points('LESSTHANOREQUALS',3)),
  spell('rogue-subtlety-prepull-slice',5171,all(negate(combat()),points('GREATERTHANOREQUALS',1),negate(sliced))),
  {id='rogue-subtlety-window-finisher',type='branch',conditions=all(combat(),points('GREATERTHANOREQUALS',5)),onFalse={},onTrue={
   spell('rogue-subtlety-window-slice',5171,any(negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2))),
   spell('rogue-subtlety-window-rupture',1943,any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2))),
   spell('rogue-subtlety-window-eviscerate',2098),
  }},
  spell('rogue-subtlety-ambush',8676,any(points('LESSTHANOREQUALS',4),all({type='TALENT',layout='grid',value=18},any(negate(own(115189)),{type='BUFF_STACKS',unit='player',spell=115189,ownbuff=true,operator='LESSTHAN',value=3})))),
  spell('rogue-subtlety-garrote',703),
  {id='rogue-subtlety-window-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-subtlety-aoe',type='branch',conditions=all(enemies('GREATERTHANOREQUALS',3),known(51723)),onFalse={},onTrue={
  spell('rogue-subtlety-aoe-slice',5171,all(points('GREATERTHANOREQUALS',1),any(negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2)))),
  spell('rogue-subtlety-crimson-tempest',121411,all(points('GREATERTHANOREQUALS',5),any(negate(mine(122233)),remain(122233,'LESSTHANOREQUALS',2)))),
  spell('rogue-subtlety-aoe-eviscerate',2098,points('GREATERTHANOREQUALS',5)),
  spell('rogue-subtlety-fan',51723),
  {id='rogue-subtlety-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-subtlety-slice',5171,all(points('GREATERTHANOREQUALS',1),negate(sliced))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-subtlety-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-subtlety-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  spell('rogue-subtlety-rupture',1943,all(any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),worth)),
  spell('rogue-subtlety-eviscerate',2098,any(negate(known(1943)),negate(mine(1943)),all(remain(1943,'GREATERTHANOREQUALS',4),buffRemain(5171,'GREATERTHANOREQUALS',4)))),
  {id='rogue-subtlety-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-subtlety-dying',2098,all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',4))),
 block('mop.rogue.subtlety-builders','rogue-'),
 spell('rogue-subtlety-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
