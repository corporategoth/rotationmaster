-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid Balance, levels 1-60, and the SoD default for every Druid no other SoD
-- premade fits. After simulator P6 with Wowhead's Phase 8 thresholds: Starsurge whenever its buff is
-- down, Hurricane on six or more (four with the Gale Winds rune), Insect Swarm only on the move, Sunfire and Moonfire on
-- targets that live, Starfire only when empowered (Starsurge or Lunar Eclipse), Wrath filler.
-- In Cat or Bear Form it plays the SoD Feral sections.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function moving()return{type='MOVING'}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function ttd(v)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=v}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.balance',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['sod.druid.maul']=2,['sod.druid.balance-cooldowns']=1,
  ['sod.druid.forms']=2,['sod.druid.cat']=2,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.bear']=2,
  ['sod.druid.caster-pull']=3},
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','balance','caster','single-target','aoe','wowhead'},
 sources={

  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Balance Druid rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-11'},
  {url='https://www.icy-veins.com/wow-classic/balance-druid-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={priority=103,
  cooldowns={BuiltinConditions.block('sod-balance-upkeep','era.druid.upkeep','sod-balance-'),BuiltinConditions.block('sod-balance-caster','era.druid.caster-cooldowns','sod-balance-'),
   BuiltinConditions.block('sod-balance-maul','sod.druid.maul','sod-balance-'),BuiltinConditions.block('sod-balance-cooldowns','sod.druid.balance-cooldowns','sod-balance-')},
  rotation={
   BuiltinConditions.block('sod-balance-boundaries','era.druid.boundaries','sod-balance-'),
   BuiltinConditions.block('sod-balance-forms','sod.druid.forms','sod-balance-'),
   BuiltinConditions.block('sod-balance-pull','sod.druid.caster-pull','sod-balance-pull-'),
   spell('sod-balance-starsurge',417157,BuiltinConditions.negate({type='BUFF',unit='player',spell=417157,ownbuff=true}),true),
   -- Gale Winds (passive) makes Hurricane free of cooldown and twice as strong: worth it from four.
   {id='sod-balance-aoe',type='branch',conditions=BuiltinConditions.any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=6},
    BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},{type='RUNE_ENGRAVED',spell=417135})),onFalse={},onTrue={
    spell('sod-balance-hurricane',16914,BuiltinConditions.negate(moving()))}},
   {id='sod-balance-moving',type='branch',conditions=moving(),onFalse={},onTrue={
    spell('sod-balance-moving-insect-swarm',5570,BuiltinConditions.negate(mine(5570))),spell('sod-balance-moving-sunfire',414684,BuiltinConditions.negate(mine(414684)),true),
    spell('sod-balance-moving-moonfire',8921,BuiltinConditions.negate(mine(8921))),{id='sod-balance-moving-stop',type='stop',suppress_attack=true,conditions={}}}},
   spell('sod-balance-sunfire',414684,BuiltinConditions.all(BuiltinConditions.negate(mine(414684)),ttd(8)),true),
   spell('sod-balance-moonfire',8921,BuiltinConditions.all(BuiltinConditions.negate(mine(8921)),ttd(8))),
   spell('sod-balance-starfire',2912,BuiltinConditions.any({type='BUFF',unit='player',spell=417157,ownbuff=true},{type='BUFF',unit='player',spell=408255,anyrank=true})),
   spell('sod-balance-wrath',5176),
   {id='sod-balance-dry',type='stop',conditions={}},
  },
 },
}))
