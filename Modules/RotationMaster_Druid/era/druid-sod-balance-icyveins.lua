-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid Balance after Icy Veins: Insect Swarm kept up with Moonfire and Sunfire,
-- Hurricane on four or more (for Gale Winds), Starfire when Starsurge empowers it, Wrath filler.
-- Same switch as rm.sod.druid.balance at a lower priority.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function moving()return{type='MOVING'}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.balance.icyveins',revision=7,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['sod.druid.maul']=2,['sod.druid.balance-cooldowns']=1,
  ['sod.druid.forms']=2,['sod.druid.cat']=2,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.bear']=2,
  ['sod.druid.caster-pull']=3},
 nameKey='Default.SoD.Druid.Balance.IcyVeins.Name',descriptionKey='Default.SoD.Druid.Balance.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','endgame','balance','caster','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/balance-druid-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://www.icy-veins.com/wow-classic/balance-druid-dps-season-of-discovery-pve-spec-builds-talents',title='Icy Veins: SoD Balance Druid runes',reviewedAt='2026-10-23',revision='2026-07-18'},
 },
 body={priority=101,disabled=true,
  cooldowns={ref('sod-balance-iv-upkeep','era.druid.upkeep','sod-balance-iv-'),ref('sod-balance-iv-caster','era.druid.caster-cooldowns','sod-balance-iv-'),
   ref('sod-balance-iv-maul','sod.druid.maul','sod-balance-iv-'),ref('sod-balance-iv-cooldowns','sod.druid.balance-cooldowns','sod-balance-iv-')},
  rotation={
   ref('sod-balance-iv-boundaries','era.druid.boundaries','sod-balance-iv-'),
   ref('sod-balance-iv-forms','sod.druid.forms','sod-balance-iv-'),
   ref('sod-balance-iv-pull','sod.druid.caster-pull','sod-balance-iv-pull-'),
   spell('sod-balance-iv-starsurge',417157,{},true),
   {id='sod-balance-iv-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
    spell('sod-balance-iv-hurricane',16914,negate(moving())),{id='sod-balance-iv-aoe-stop',type='stop',suppress_attack=true,conditions={}}}},
   spell('sod-balance-iv-starfire',2912,{type='AND',value={{type='BUFF',unit='player',spell=417157,ownbuff=true},negate(moving())}}),
   spell('sod-balance-iv-moonfire',8921,negate(mine(8921))),
   spell('sod-balance-iv-sunfire',414684,negate(mine(414684)),true),
   spell('sod-balance-iv-insect-swarm',5570,negate(mine(5570))),
   spell('sod-balance-iv-wrath',5176,negate(moving())),
   {id='sod-balance-iv-dry',type='stop',conditions={}},
  },
 },
}))
