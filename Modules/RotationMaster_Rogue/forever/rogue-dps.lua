-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Rogue melee DPS, levels 1–60, every specialization (the recommended premade).
-- Forever stores one slot per class and RM cannot read Forever talents, so the spec follows
-- the talent-taught spell that is known: Mutilate/Venom (Assassination), Hemorrhage
-- (Subtlety), otherwise Combat and leveling. Slice and Dice from three points (refreshed in
-- its last second from four), Venom, group Expose Armor, then five points on Rupture
-- (Subtlety, long fights) or Eviscerate; no builder past five. Shared parts:
-- Defaults/blocks/forever-rogue.lua. Left manual: Vanish, Sprint, Kidney Shot, Gouge, Blind,
-- Sap and positioning. Built from the level-30 beta guides; level 31–60 is planned, not played.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function owned(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big={type='OR',value={{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'}}}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.rogue.dps',revision=5,
 blocks={['forever.rogue.boundaries']=3,['forever.rogue.stealth-fallback']=3,['forever.rogue.reactive']=1,['forever.rogue.expose-armor']=1,['forever.rogue.upkeep']=2},
 nameKey='Default.Forever.Rogue.DPS.Name',descriptionKey='Default.Forever.Rogue.DPS.Description',
 applicability={families={'forever'},actionContext='player',class='ROGUE'},
 tags={'dps','melee','leveling','endgame','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-forever/assassination-rogue-melee-dps-pve-guide',title='Icy Veins: Forever Assassination Rogue PvE guide',reviewedAt='2026-10-23',revision='2026-10-19'},
 {url='https://www.icy-veins.com/wow-forever/combat-rogue-leveling',title='Icy Veins: Forever Combat Rogue leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/subtlety-rogue-melee-dps-pve-guide',title='Icy Veins: Forever Subtlety Rogue PvE guide',reviewedAt='2026-10-23',revision='2026-10-08'},
 {url='https://www.wowhead.com/forever/guide/classes/rogue/assassination/level-30-dps-overview',title='Wowhead: Forever level 30 Assassination Rogue',reviewedAt='2026-10-23',revision='2026-10-06'},
 {url='https://www.wowhead.com/forever/guide/classes/rogue/subtlety/dps-abilities',title='Wowhead: Forever Subtlety Rogue abilities',reviewedAt='2026-10-23',revision='2026-10-08'},
 {url='https://www.warcrafttavern.com/forever/guides/assassination-rogue/',title='Warcraft Tavern: Forever Assassination Rogue',reviewedAt='2026-10-23'},
 {url='https://worldofwarcraft.blizzard.com/en-us/news/24310968',title='Blizzard: Forever class deep dives, Rogue and Warlock',reviewedAt='2026-10-23',revision='2026-10-07'}},
 body={priority=10,
 cooldowns={block('forever.rogue.upkeep','rogue-'),
  spell('rogue-preparation',14185,all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=30},{type='SPELL_COOLDOWN',spell=5277,operator='GREATERTHAN',value=30}))},
 rotation={
 block('forever.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  spell('rogue-premeditation',14183,points('LESSTHANOREQUALS',3)),
  spell('rogue-cheap-shot',1833,negate({type='GROUP'})),
  spell('rogue-group-garrote',703,all(known(16511),{type='GROUP'},big)),
  block('forever.rogue.stealth-fallback','rogue-stealth-'),
 }},
 block('forever.rogue.reactive','rogue-'),
 spell('rogue-slice',5171,all(negate(own(5171)),points('GREATERTHANOREQUALS',3))),
 spell('rogue-venom',1310703,all(negate(own(1310703)),points('GREATERTHANOREQUALS',4))),
 block('forever.rogue.expose-armor','rogue-'),
 spell('rogue-slice-refresh',5171,all(points('GREATERTHANOREQUALS',4),{type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=1})),
 {id='rogue-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-rupture',1943,all(known(16511),negate(known(1310707)),negate(owned(1943)),any(big,{type='GROUP'}))),
  spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-hemorrhage-debuff',16511,all(known(1943),negate(owned(16511)))),
 spell('rogue-ghostly-strike',14278),
 {id='rogue-assassination',type='branch',conditions=known(1310707),onFalse={},onTrue={
  spell('rogue-mutilate',1310707,points('LESSTHANOREQUALS',3)),
  spell('rogue-fifth-point',1752,points('GREATERTHANOREQUALS',4)),
  {id='rogue-mutilate-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-hemorrhage',16511),
 spell('rogue-backstab',53,negate({type='THREAT',unit='target',threat=3})),
 spell('rogue-sinister',1752),
 }},
}))
