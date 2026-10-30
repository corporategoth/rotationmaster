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
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=BuiltinConditions.all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'}))
local grouped=BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.holy',revision=6,
 blocks={['retail.priest.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'holy','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/holy-priest-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/priest/holy/rotation-cooldowns-pve-healer',title='Wowhead: Holy Priest rotation',reviewedAt='2026-10-23',revision='2026-01-18',notes='Older page; agrees on Holy Words and Prayer of Mending on cooldown.'},
 },
 body={priority=10,specs={257},
  cooldowns={
   block('retail.priest.upkeep','holy-'),
   BuiltinConditions.spell('holy-apotheosis',200183,grouped),
   BuiltinConditions.spell('holy-divine-hymn',64843,grouped),
   BuiltinConditions.spell('holy-halo',120644,BuiltinConditions.combat()),
   BuiltinConditions.spell('holy-guardian-spirit',47788,BuiltinConditions.all(BuiltinConditions.combat(),friend)),
  },
  rotation={
   {id='holy-casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='holy-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    BuiltinConditions.spell('holy-sanctify',34861),
    BuiltinConditions.spell('holy-serenity',2050),
    BuiltinConditions.spell('holy-prayer-of-mending',33076),
    BuiltinConditions.spell('holy-surge-prayer',596,BuiltinConditions.ownBuff(114255)),
    BuiltinConditions.spell('holy-benediction',1262763),
    BuiltinConditions.spell('holy-lightweaver-prayer',596,BuiltinConditions.ownBuff(390993)),
    BuiltinConditions.spell('holy-surge-flash',2061,BuiltinConditions.ownBuff(114255)),
    BuiltinConditions.spell('holy-prayer-of-healing',596,{type='GROUP'}),
    BuiltinConditions.spell('holy-nova-moving',132157,{type='MOVING'}),
    BuiltinConditions.spell('holy-flash-heal',2061),
    {id='holy-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='holy-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
   BuiltinConditions.spell('holy-chastise',88625),
   BuiltinConditions.spell('holy-holy-fire',14914),
   BuiltinConditions.spell('holy-nova-enemy',132157,{type='MOVING'}),
   BuiltinConditions.spell('holy-smite',585),
  },
 },
}))
