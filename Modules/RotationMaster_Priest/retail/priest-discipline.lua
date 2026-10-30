-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Discipline Priest, Atonement damage (Icy Veins Mythic+). Blizzard's Assisted
-- Combat does not cover healers, health is hidden in Midnight combat and RM picks a spell, not a
-- target, so this runs the damage list that heals through Atonement and leaves triage to you.
-- Friendly target: Power Word: Shield (Void Shield), Penance, Flash Heal. Enemy: Shadow Word: Pain
-- when you have not cast it for 12 s (own cast history stays readable; the debuff itself only
-- counts where it can be read), Mind Blast, Penance, Shield, Shadow Word: Death, Void Blast,
-- Smite. Reminders: Radiance, Evangelism, Ultimate Penitence, Pain Suppression, Fortitude.
-- Raid ramps are timed sequences and stay manual.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=BuiltinConditions.all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.discipline',revision=6,
 blocks={['retail.priest.upkeep']=2,['retail.priest.disc-cooldowns']=1},
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'discipline','healer','atonement','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/discipline-priest-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Discipline Priest healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=10,specs={256},
  cooldowns={
   block('retail.priest.upkeep','disc-'),
   block('retail.priest.disc-cooldowns','disc-'),
  },
  rotation={
   {id='disc-casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='disc-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    BuiltinConditions.spell('disc-void-shield',1253593),
    BuiltinConditions.spell('disc-shield',17),
    BuiltinConditions.spell('disc-penance-heal',47540),
    BuiltinConditions.spell('disc-flash-heal',2061),
    {id='disc-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='disc-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
   BuiltinConditions.spell('disc-shadow-word-pain',589,BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=589,operator='LESSTHAN',value=12}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}))),
   BuiltinConditions.spell('disc-mind-blast',8092),
   BuiltinConditions.spell('disc-penance',47540),
   BuiltinConditions.spell('disc-void-shield-self',1253593),
   BuiltinConditions.spell('disc-shield-self',17),
   BuiltinConditions.spell('disc-shadow-word-death',32379),
   BuiltinConditions.spell('disc-void-blast',450983),
   BuiltinConditions.spell('disc-smite',585),
  },
 },
}))
