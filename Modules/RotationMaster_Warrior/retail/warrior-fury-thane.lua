-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Fury Warrior, Mountain Thane (SimulationCraft's thane list, Icy Veins): the
-- optimal reference, disabled by default because Enrage, Recklessness, Avatar and Thunder Blast
-- stacks are hidden in Midnight combat (rage is secret on Retail, so there is no 100-rage Rampage).
-- Charge to open. Whirlwind for its buff on two or more engaged enemies; Rampage when Enrage is
-- missing or ending; Bloodbath in Recklessness;
-- Thunder Blast at two stacks; Crushing Blow; Bloodbath; Rampage in Recklessness; Thunder Blast
-- in Avatar; Raging Blow; Thunder Blast; Rampage; Bloodthirst; Execute; Odyn's Fury; Thunder Clap;
-- Whirlwind. Reminders: Recklessness, Avatar, Enraged Regeneration.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.fury.thane',revision=7,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'fury','melee','reference','mountain-thane','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_fury.simc',title='SimulationCraft: Fury Warrior default list (thane, thane_aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Fury Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=4,disabled=true,specs={72},
  cooldowns={
   block('retail.warrior.upkeep','furyth-'),
   BuiltinConditions.spell('furyth-recklessness',1719,fight),
   BuiltinConditions.spell('furyth-avatar',107574,fight),
   BuiltinConditions.spell('furyth-enraged-regeneration',184364,BuiltinConditions.combat()),
  },
  rotation={
   block('retail.warrior.boundaries','furyth-'),
   block('retail.warrior.charge','furyth-'),
   BuiltinConditions.spell('furyth-whirlwind-buff',190411,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.negate(BuiltinConditions.ownBuff(85739)))),
   BuiltinConditions.spell('furyth-rampage-enrage',184367,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(184362)),{type='BUFF_REMAIN',unit='player',spell=184362,ownbuff=true,operator='LESSTHAN',value=1.5})),
   BuiltinConditions.spell('furyth-reckless-bloodbath',335096,BuiltinConditions.ownBuff(1719)),
   BuiltinConditions.spell('furyth-thunder-blast-stacked',435222,{type='BUFF_STACKS',unit='player',spell=435615,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('furyth-crushing-blow',335097),
   BuiltinConditions.spell('furyth-bloodbath',335096),
   BuiltinConditions.spell('furyth-reckless-rampage',184367,BuiltinConditions.ownBuff(1719)),
   BuiltinConditions.spell('furyth-avatar-thunder-blast',435222,BuiltinConditions.ownBuff(107574)),
   BuiltinConditions.spell('furyth-raging-blow',85288),
   BuiltinConditions.spell('furyth-thunder-blast',435222),
   BuiltinConditions.spell('furyth-rampage',184367),
   BuiltinConditions.spell('furyth-bloodthirst',23881),
   BuiltinConditions.spell('furyth-execute',5308),
   BuiltinConditions.spell('furyth-odyns-fury',385059),
   BuiltinConditions.spell('furyth-thunder-clap',6343),
   BuiltinConditions.spell('furyth-whirlwind',190411),
  },
 },
}))
