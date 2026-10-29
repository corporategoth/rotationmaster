-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid Balance after Wowhead's Phase 8 guide: Wrath to open, Starsurge on
-- cooldown, Hurricane on six or more, Insect Swarm only on the move, Sunfire and Moonfire kept up,
-- Wrath while your Sunfire has under 5 seconds with Elune's Fires engraved (it extends it), Starfire on Lunar
-- Eclipse, Wrath filler. Same switch as rm.sod.druid.balance at a lower priority.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function moving()return{type='MOVING'}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.balance.wowhead',revision=7,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['sod.druid.maul']=2,['sod.druid.balance-cooldowns']=1,
  ['sod.druid.forms']=2,['sod.druid.cat']=2,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.bear']=2},
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','endgame','balance','caster','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Balance Druid rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-11'},
 },
 body={priority=102,disabled=true,
  cooldowns={BuiltinConditions.block('sod-balance-wh-upkeep','era.druid.upkeep','sod-balance-wh-'),BuiltinConditions.block('sod-balance-wh-caster','era.druid.caster-cooldowns','sod-balance-wh-'),
   BuiltinConditions.block('sod-balance-wh-maul','sod.druid.maul','sod-balance-wh-'),BuiltinConditions.block('sod-balance-wh-cooldowns','sod.druid.balance-cooldowns','sod-balance-wh-')},
  rotation={
   BuiltinConditions.block('sod-balance-wh-boundaries','era.druid.boundaries','sod-balance-wh-'),
   BuiltinConditions.block('sod-balance-wh-forms','sod.druid.forms','sod-balance-wh-'),
   BuiltinConditions.stop('sod-balance-wh-no-target',BuiltinConditions.negate({type='ATTACKABLE',unit='target'})),
   {id='sod-balance-wh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    spell('sod-balance-wh-pull-wrath',5176,BuiltinConditions.negate(moving())),spell('sod-balance-wh-pull-starsurge',417157,{},true),spell('sod-balance-wh-pull-sunfire',414684,{},true),
    spell('sod-balance-wh-pull-moonfire',8921),BuiltinConditions.stop('sod-balance-wh-pull-stop')}},
   spell('sod-balance-wh-starsurge',417157,{},true),
   {id='sod-balance-wh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=6},onFalse={},onTrue={
    spell('sod-balance-wh-hurricane',16914,BuiltinConditions.negate(moving())),BuiltinConditions.stop('sod-balance-wh-aoe-stop')}},
   {id='sod-balance-wh-moving',type='branch',conditions=moving(),onFalse={},onTrue={
    spell('sod-balance-wh-moving-insect-swarm',5570,BuiltinConditions.negate(mine(5570))),BuiltinConditions.stop('sod-balance-wh-moving-stop')}},
   spell('sod-balance-wh-sunfire',414684,BuiltinConditions.negate(mine(414684)),true),
   spell('sod-balance-wh-moonfire',8921,BuiltinConditions.negate(mine(8921))),
   spell('sod-balance-wh-extend',5176,BuiltinConditions.all({type='RUNE_ENGRAVED',spell=414719},{type='RUNE_ENGRAVED',spell=414684},{type='DEBUFF_REMAIN',unit='target',spell=414684,anyrank=true,owndebuff=true,operator='LESSTHAN',value=5})),
   spell('sod-balance-wh-starfire',2912,{type='BUFF',unit='player',spell=408255,anyrank=true}),
   spell('sod-balance-wh-wrath',5176),
   {id='sod-balance-wh-dry',type='stop',conditions={}},
  },
 },
}))
