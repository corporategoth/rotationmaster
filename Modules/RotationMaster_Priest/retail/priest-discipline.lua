-- Retail (Midnight) Discipline Priest, Atonement damage (Icy Veins Mythic+). Blizzard's Assisted
-- Combat does not cover healers, health is hidden in Midnight combat and RM picks a spell, not a
-- target, so this runs the damage list that heals through Atonement and leaves triage to you.
-- Friendly target: Power Word: Shield (Void Shield), Penance, Flash Heal. Enemy: Shadow Word: Pain
-- when you have not cast it for 12 s (own cast history stays readable; the debuff itself only
-- counts where it can be read), Mind Blast, Penance, Shield, Shadow Word: Death, Void Blast,
-- Smite. Reminders: Radiance, Evangelism, Ultimate Penitence, Pain Suppression, Fortitude.
-- Raid ramps are timed sequences and stay manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.discipline',revision=4,
 blocks={['retail.priest.upkeep']=2,['retail.priest.disc-cooldowns']=1},
 nameKey='Default.Retail.Priest.Discipline.Name',descriptionKey='Default.Retail.Priest.Discipline.Description',
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'discipline','healer','atonement','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/discipline-priest-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Discipline Priest healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=10,switch={type='SPECIALIZATION',spec=256},
  cooldowns={
   block('retail.priest.upkeep','disc-'),
   block('retail.priest.disc-cooldowns','disc-'),
  },
  rotation={
   {id='disc-casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='disc-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    spell('disc-void-shield',1253593),
    spell('disc-shield',17),
    spell('disc-penance-heal',47540),
    spell('disc-flash-heal',2061),
    {id='disc-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='disc-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
   spell('disc-shadow-word-pain',589,any(negate({type='SPELL_HISTORY_TIME',spell=589,operator='LESSTHAN',value=12}),negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}))),
   spell('disc-mind-blast',8092),
   spell('disc-penance',47540),
   spell('disc-void-shield-self',1253593),
   spell('disc-shield-self',17),
   spell('disc-shadow-word-death',32379),
   spell('disc-void-blast',450983),
   spell('disc-smite',585),
  },
 },
}))
