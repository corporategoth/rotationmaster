-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid bear tank, simulator P7 "cat weave": off by default (expert, needs Savage
-- Roar from gear as well as Lacerate). Leaves Bear for Cat to keep Rake and Savage Roar up, then
-- returns to Dire Bear and plays the tank list. Same switch as rm.sod.druid.tank at a lower priority.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
local rake={type='DEBUFF',unit='target',spell=1822,anyrank=true,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.tank.simulator',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['sod.druid.maul']=2,['sod.druid.tank-cooldowns']=2,['sod.druid.bear']=2,['sod.druid.tank-humanoid']=2},
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','endgame','feral','tank','melee','single-target'},
 sources={},
 body={priority=139,disabled=true,switch=rune(414644),
  cooldowns={BuiltinConditions.block('sod-tank-ws-upkeep','era.druid.upkeep','sod-tank-ws-'),BuiltinConditions.block('sod-tank-ws-maul','sod.druid.maul','sod-tank-ws-'),BuiltinConditions.block('sod-tank-ws-cooldowns','sod.druid.tank-cooldowns','sod-tank-ws-')},
  rotation={
   BuiltinConditions.block('sod-tank-ws-boundaries','era.druid.boundaries','sod-tank-ws-'),
   {id='sod-tank-ws-cat',type='branch',conditions=BuiltinConditions.form(768),onFalse={},onTrue={
    {id='sod-tank-ws-cat-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
    spell('sod-tank-ws-savage-roar',407988,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(407988)),cp('GREATERTHANOREQUALS',2))),
    spell('sod-tank-ws-tigers-fury',417045,BuiltinConditions.negate(rake),true),
    spell('sod-tank-ws-mangle',407993,BuiltinConditions.all(BuiltinConditions.known(407988),BuiltinConditions.negate(BuiltinConditions.ownBuff(407988)),cp('LESSTHAN',2)),true),
    spell('sod-tank-ws-rake',1822,BuiltinConditions.negate(rake)),
    spell('sod-tank-ws-cat-dire-bear-form',9634),
    spell('sod-tank-ws-cat-bear-form',5487),
    {id='sod-tank-ws-cat-wait',type='stop',conditions={}}}},
   {id='sod-tank-ws-bear',type='branch',conditions=BuiltinConditions.any(BuiltinConditions.form(5487),BuiltinConditions.form(9634)),onFalse={},onTrue={
    spell('sod-tank-ws-cat-form',768,BuiltinConditions.all(BuiltinConditions.known(407988),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate(rake))),
    BuiltinConditions.block('sod-tank-ws-bear-section','sod.druid.bear','sod-tank-ws-bear-')}},
   BuiltinConditions.block('sod-tank-ws-humanoid','sod.druid.tank-humanoid','sod-tank-ws-'),
  },
 },
}))
