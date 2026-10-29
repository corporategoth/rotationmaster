-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Fury Warrior, Slayer (SimulationCraft's slayer and slayer_aoe lists): the
-- optimal reference, disabled by default because Enrage, Recklessness and Sudden Death are hidden
-- in Midnight combat. Charge to open. Whirlwind for its buff on two or more engaged enemies;
-- Rampage when Enrage is ending; in Recklessness Rampage, Bladestorm, Execute on Sudden Death,
-- Odyn's Fury; Crushing Blow; Bloodbath; Execute; Odyn's Fury; Raging Blow; Rampage; Bloodthirst;
-- Whirlwind. Rage is secret on Retail, so Rampage waits only for its cost (no 100-rage gates).
-- Reminders: Recklessness, Avatar, Enraged Regeneration.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.fury.slayer',revision=7,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'fury','melee','reference','slayer','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_fury.simc',title='SimulationCraft: Fury Warrior default list (slayer, slayer_aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={72},
  cooldowns={
   block('retail.warrior.upkeep','furysl-'),
   BuiltinConditions.spell('furysl-recklessness',1719,fight),
   BuiltinConditions.spell('furysl-avatar',107574,fight),
   BuiltinConditions.spell('furysl-enraged-regeneration',184364,BuiltinConditions.combat()),
  },
  rotation={
   block('retail.warrior.boundaries','furysl-'),
   block('retail.warrior.charge','furysl-'),
   BuiltinConditions.spell('furysl-whirlwind-buff',190411,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.negate(BuiltinConditions.ownBuff(85739)))),
   BuiltinConditions.spell('furysl-rampage-enrage',184367,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(184362)),{type='BUFF_REMAIN',unit='player',spell=184362,ownbuff=true,operator='LESSTHAN',value=1.5})),
   {id='furysl-reckless',type='branch',conditions=BuiltinConditions.ownBuff(1719),onFalse={},onTrue={
    BuiltinConditions.spell('furysl-reckless-rampage',184367),
    BuiltinConditions.spell('furysl-reckless-bladestorm',446035),
    BuiltinConditions.spell('furysl-reckless-execute',5308,BuiltinConditions.ownBuff(280776)),
    BuiltinConditions.spell('furysl-reckless-odyns-fury',385059),
   }},
   BuiltinConditions.spell('furysl-crushing-blow',335097),
   BuiltinConditions.spell('furysl-bloodbath',335096),
   BuiltinConditions.spell('furysl-execute',5308),
   BuiltinConditions.spell('furysl-odyns-fury',385059),
   BuiltinConditions.spell('furysl-raging-blow',85288),
   BuiltinConditions.spell('furysl-rampage',184367),
   BuiltinConditions.spell('furysl-bloodthirst',23881),
   BuiltinConditions.spell('furysl-whirlwind',190411),
  },
 },
}))
