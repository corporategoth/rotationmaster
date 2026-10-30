-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Restoration, from level 10 when Restoration is the primary talent tree. After
-- Icy Veins and Wowhead: acts on the current friendly target (choosing whom to heal and downranking
-- beyond rank 4 Healing Touch stay with you). Nature's Swiftness Healing Touch, Swiftmend in an
-- emergency, Rejuvenation and Regrowth kept rolling, Regrowth spam with Improved Regrowth, Healing
-- Touch at full rank for heavy damage or Nature's Grace, rank 4 otherwise. On an enemy: Moonfire,
-- Insect Swarm, Wrath.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function hp(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.restoration',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.heal-cooldowns']=1,['era.druid.resto-damage']=2},
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','restoration','healer','group','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/restoration-druid-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/restoration-druid-leveling-talent-build-from-1-to-60',title='Icy Veins: Restoration Druid leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/druid/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={BuiltinConditions.block('era-resto-upkeep','era.druid.upkeep','era-resto-'),BuiltinConditions.block('era-resto-cooldowns','era.druid.heal-cooldowns','era-resto-')},
  rotation={
   BuiltinConditions.block('era-resto-boundaries','era.druid.boundaries','era-resto-'),
   {id='era-resto-feral-form',type='stop',conditions=BuiltinConditions.any(BuiltinConditions.form(768),BuiltinConditions.form(5487),BuiltinConditions.form(9634))},
   {id='era-resto-heal',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('era-resto-swiftness',5185,BuiltinConditions.ownBuff(17116)),
    spell('era-resto-swiftmend',18562,BuiltinConditions.all(hp(.4),BuiltinConditions.any(hot(774),hot(8936)))),
    spell('era-resto-rejuvenation',774,BuiltinConditions.all(BuiltinConditions.negate(hot(774)),BuiltinConditions.any({type='COMBAT',unit='player'},hp(.95)))),
    spell('era-resto-regrowth',8936,BuiltinConditions.all(BuiltinConditions.negate(hot(8936)),hp(.8))),
    {id='era-resto-regrowth-build',type='branch',conditions={type='TALENT',layout='tree',tree=3,talent=14,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
     spell('era-resto-regrowth-spam',8936,hp(.75))}},
    spell('era-resto-big-touch',5185,BuiltinConditions.any(hp(.45),BuiltinConditions.ownBuff(16886))),
    spell('era-resto-touch-rank4',5188,hp(.85),true),
    spell('era-resto-touch',5185,hp(.85)),
    {id='era-resto-heal-stop',type='stop',suppress_attack=true,conditions={}}}},
   BuiltinConditions.block('era-resto-damage','era.druid.resto-damage','era-resto-enemy-'),
   {id='era-resto-stop',type='stop',suppress_attack=true,conditions={}},
  },
 },
}))
