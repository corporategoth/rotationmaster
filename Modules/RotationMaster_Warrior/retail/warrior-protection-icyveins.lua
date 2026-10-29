-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Protection Warrior, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Shield Block, Thunder Blast and Colossal Might are
-- hidden in Midnight combat. Charge to open. Ravager, Thunder Blast at two stacks, Demolish at
-- five Colossal Might, Shield Charge, Thunder Blast, Shield Slam, Thunder Clap, Execute, Revenge,
-- Devastate. Reminders: Shield Block when its buff is down and you are tanking, Ignore Pain, Avatar,
-- Demoralizing Shout, Champion's Spear, Shield Wall and Last Stand whenever ready in combat (rage
-- and health are secret on Retail).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local tanking={type='THREAT',unit='target',threat=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.protection.icyveins',revision=7,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'protection','tank','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/protection-warrior-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Protection Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_protection.simc',title='SimulationCraft: Protection Warrior default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={73},
  cooldowns={
   block('retail.warrior.upkeep','protiv-'),
   BuiltinConditions.spell('protiv-shield-block',2565,BuiltinConditions.all(fight,tanking,BuiltinConditions.negate(BuiltinConditions.ownBuff(132404)))),
   BuiltinConditions.spell('protiv-ignore-pain',190456,fight),
   BuiltinConditions.spell('protiv-avatar',107574,fight),
   BuiltinConditions.spell('protiv-demoralizing-shout',1160,fight),
   BuiltinConditions.spell('protiv-champions-spear',376079,fight),
   BuiltinConditions.spell('protiv-shield-wall',871,BuiltinConditions.combat()),
   BuiltinConditions.spell('protiv-last-stand',12975,BuiltinConditions.combat()),
  },
  rotation={
   block('retail.warrior.boundaries','protiv-'),
   block('retail.warrior.charge','protiv-'),
   BuiltinConditions.spell('protiv-ravager',228920),
   BuiltinConditions.spell('protiv-thunder-blast-stacked',435222,{type='BUFF_STACKS',unit='player',spell=435615,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('protiv-demolish',436358,{type='BUFF_STACKS',unit='player',spell=440989,ownbuff=true,operator='GREATERTHANOREQUALS',value=5}),
   BuiltinConditions.spell('protiv-shield-charge',385952),
   BuiltinConditions.spell('protiv-thunder-blast',435222),
   BuiltinConditions.spell('protiv-shield-slam',23922),
   BuiltinConditions.spell('protiv-thunder-clap',6343),
   BuiltinConditions.spell('protiv-execute',163201),
   BuiltinConditions.spell('protiv-revenge',6572),
   BuiltinConditions.spell('protiv-devastate',20243),
  },
 },
}))
