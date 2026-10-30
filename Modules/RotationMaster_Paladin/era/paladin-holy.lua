-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Holy (Icy Veins and Wowhead agree): heals act on your friendly target, choosing the
-- rank by missing health: Holy Light for big deficits (rank 6 for most), Flash of Light (rank 4 for
-- small ones), Holy Shock while moving, Cleanse first. With an enemy in melee range: Seal of Wisdom
-- and, outside raids, Judgement. Selected for the Holy tree in a group; a soloing Holy Paladin
-- melees with the Retribution premade. Choosing whom to heal stays with you.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function exact(id,action,conditions)return{id=id,type='spell',action=action,ranked=true,conditions=conditions or{}}end
local function noSeal()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return BuiltinConditions.negate({type='OR',value=out})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.holy',revision=5,
 blocks={['era.paladin.holy-upkeep']=2,['era.paladin.boundaries']=2,['era.paladin.cleanse']=1},
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','holy','healer','dungeon','raid','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/holy-paladin-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Holy Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.wowhead.com/classic/guide/classes/paladin/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Holy Paladin rotation',reviewedAt='2026-10-23',revision='2025-03-20'}},
 body={priority=10,switch=BuiltinConditions.all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='GROUP'},{type='PRIMARY_TALENT_TREE',tree=1}),
  cooldowns={BuiltinConditions.block('holy-upkeep','era.paladin.holy-upkeep','holy-')},
  rotation={
   BuiltinConditions.block('holy-boundaries','era.paladin.boundaries','holy-'),
   {id='holy-friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.block('holy-cleanse','era.paladin.cleanse','holy-'),
    BuiltinConditions.spell('holy-moving-shock',20473,BuiltinConditions.all({type='MOVING'},hurt(0.8))),
    BuiltinConditions.spell('holy-light-max',635,hurt(0.4)),
    exact('holy-light-rank6',3472,hurt(0.65)),
    BuiltinConditions.spell('holy-flash-max',19750,hurt(0.85)),
    exact('holy-flash-rank4',19941,hurt(0.95)),
    {id='holy-friend-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='holy-hostile',type='branch',conditions=BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.spell('holy-seal-wisdom',20166,noSeal()),
    BuiltinConditions.spell('holy-judgement',20271,BuiltinConditions.negate({type='GROUP',raid=true})),
    {id='holy-hostile-stop',type='stop',conditions={}},
   }},
   {id='holy-idle-stop',type='stop',suppress_attack=true,conditions={}},
  },
 },
}))
