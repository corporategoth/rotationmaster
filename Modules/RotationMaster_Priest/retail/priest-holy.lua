-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Holy Priest, Icy Veins raid order. Holy "has no set rotation": who needs
-- healing decides, health is hidden in Midnight combat and RM picks a spell, not a target, so this
-- keeps the Holy Words, Prayer of Mending and procs moving on whatever you target. Friendly
-- target: Sanctify, Serenity, Prayer of Mending, Prayer of Healing on Surge of Light, Benediction,
-- Prayer of Healing on Lightweaver, Flash Heal on Surge of Light, Prayer of Healing in a group,
-- Holy Nova while moving, Flash Heal. Enemy: Chastise, Holy Fire, Holy Nova while moving, Smite.
-- Reminders: Apotheosis, Divine Hymn and Halo in grouped combat, Guardian Spirit on a friendly target
-- (health is secret on Retail, so whether it is dying is your call), Fortitude.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
local grouped=all(combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.holy',revision=6,
 blocks={['retail.priest.upkeep']=2},
 nameKey='Default.Retail.Priest.Holy.Name',descriptionKey='Default.Retail.Priest.Holy.Description',
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'holy','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/holy-priest-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/priest/holy/rotation-cooldowns-pve-healer',title='Wowhead: Holy Priest rotation',reviewedAt='2026-10-23',revision='2026-01-18',notes='Older page; agrees on Holy Words and Prayer of Mending on cooldown.'},
 },
 body={priority=10,specs={257},
  cooldowns={
   block('retail.priest.upkeep','holy-'),
   spell('holy-apotheosis',200183,grouped),
   spell('holy-divine-hymn',64843,grouped),
   spell('holy-halo',120644,combat()),
   spell('holy-guardian-spirit',47788,all(combat(),friend)),
  },
  rotation={
   {id='holy-casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='holy-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    spell('holy-sanctify',34861),
    spell('holy-serenity',2050),
    spell('holy-prayer-of-mending',33076),
    spell('holy-surge-prayer',596,own(114255)),
    spell('holy-benediction',1262763),
    spell('holy-lightweaver-prayer',596,own(390993)),
    spell('holy-surge-flash',2061,own(114255)),
    spell('holy-prayer-of-healing',596,{type='GROUP'}),
    spell('holy-nova-moving',132157,{type='MOVING'}),
    spell('holy-flash-heal',2061),
    {id='holy-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='holy-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
   spell('holy-chastise',88625),
   spell('holy-holy-fire',14914),
   spell('holy-nova-enemy',132157,{type='MOVING'}),
   spell('holy-smite',585),
  },
 },
}))
