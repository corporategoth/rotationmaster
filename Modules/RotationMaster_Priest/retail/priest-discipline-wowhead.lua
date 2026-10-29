-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Discipline Priest, Wowhead's Oracle Mythic+ order: a reference, disabled by
-- default (a Season 1 page; Shadow Word: Pain upkeep reads the hidden debuff). Shadow Word: Pain
-- kept up, Shadow Word: Death on cooldown, Penance, Mind Blast, Smite; on a friendly target
-- Penance first. Same reminders as the Icy Veins premade.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.discipline.wowhead',revision=6,
 blocks={['retail.priest.upkeep']=2,['retail.priest.disc-cooldowns']=1},
 nameKey="Death first reference (Wowhead)",descriptionKey="Reference only, off by default: Wowhead's Season 1 Oracle order, which keeps Shadow Word: Pain up by reading the debuff that Midnight hides in combat. Shadow Word: Pain, Shadow Word: Death on cooldown, Penance, Mind Blast, Smite; Penance first on a friendly target. Same reminders as the Icy Veins premade.",
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'discipline','healer','atonement','reference','wowhead'},
 sources={
  {url='https://www.wowhead.com/guide/classes/priest/discipline/rotation-cooldowns-pve-healer',title='Wowhead: Discipline Priest rotation (Season 1)',reviewedAt='2026-10-23',revision='2026-03-09'},
 },
 body={priority=5,disabled=true,specs={256},
  cooldowns={
   block('retail.priest.upkeep','discwh-'),
   block('retail.priest.disc-cooldowns','discwh-'),
  },
  rotation={
   {id='discwh-casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='discwh-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    spell('discwh-penance-heal',47540),
    spell('discwh-shield',17),
    spell('discwh-flash-heal',2061),
    {id='discwh-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='discwh-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
   spell('discwh-shadow-word-pain',589,any(negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=589,owndebuff=true,operator='LESSTHAN',value=4.8})),
   spell('discwh-shadow-word-death',32379),
   spell('discwh-penance',47540),
   spell('discwh-mind-blast',8092),
   spell('discwh-smite',585),
  },
 },
}))
