-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Fury Warrior, Blizzard Assisted (recommended). Midnight hides rage, Enrage,
-- procs, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick stays
-- readable, so the rotation is that suggestion after the cast and no-target Stops. Reminders for
-- what it leaves out (SimulationCraft's assisted_combat/warrior_fury.simc): Recklessness, Avatar
-- and Champion's Spear in combat, Battle Shout between pulls, Pummel, Enraged Regeneration.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.fury',revision=6,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1},
 nameKey='Default.Retail.Warrior.Fury.Name',descriptionKey='Default.Retail.Warrior.Fury.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'fury','melee','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/warrior_fury.simc',title='SimulationCraft: Assisted Combat model, Fury Warrior',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Warrior',title='MaxDps Warrior module (Midnight)',reviewedAt='2026-10-23',revision='c3bf773f37',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={72},
  cooldowns={
   block('retail.warrior.upkeep','fury-'),
   spell('fury-recklessness',1719,fight),
   spell('fury-avatar',107574,fight),
   spell('fury-champions-spear',376079,fight),
   spell('fury-enraged-regeneration',184364,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','fury-'),
   {id='fury-assisted',type='assisted',conditions={}},
  },
 },
}))
