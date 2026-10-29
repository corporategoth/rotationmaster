-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Assassination Rogue, Blizzard Assisted (recommended). Midnight hides bleeds,
-- buffs, energy, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick
-- stays readable, so the rotation is that suggestion (it handles the stealth opener, bleeds and
-- Envenom) after the cast and no-target Stops. Reminders for what it leaves out (SimulationCraft's
-- assisted_combat/rogue_assassination.simc): poisons and Stealth between pulls, Kick, and Vanish
-- whenever you are out of stealth in combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.assassination',revision=6,
 blocks={['retail.rogue.boundaries']=2,['retail.rogue.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'assassination','melee','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/rogue_assassination.simc',title='SimulationCraft: Assisted Combat model, Assassination Rogue',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Rogue',title='MaxDps Rogue module (Midnight)',reviewedAt='2026-10-23',revision='6145c857',notes='No priority in Midnight: the Assisted Combat spell plus cooldown and defensive glows.'},
 },
 body={priority=10,specs={259},
  cooldowns={
   block('retail.rogue.upkeep','assa-'),
   BuiltinConditions.spell('assa-vanish',1856,BuiltinConditions.all(fight,BuiltinConditions.negate({type='STEALTHED'}))),
  },
  rotation={
   block('retail.rogue.boundaries','assa-'),
   {id='assa-assisted',type='assisted',conditions={}},
  },
 },
}))
