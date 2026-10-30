-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Elemental Shaman, Blizzard Assisted (recommended). Midnight hides Flame Shock,
-- buffs, Maelstrom, cooldown times and health from addons in combat; Blizzard's Assisted Combat
-- pick stays readable, so the rotation is that suggestion after the cast and no-target Stops.
-- Reminders for what it leaves out (SimulationCraft's assisted_combat/shaman_elemental.simc and
-- the research): Ascendance, Fire or Storm Elemental and Nature's Swiftness in combat,
-- Spiritwalker's Grace while moving, Lightning Shield and Skyfury between pulls, Wind Shear,
-- Astral Shift.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.elemental',revision=6,
 blocks={['retail.shaman.boundaries']=2,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'elemental','ranged','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/shaman_elemental.simc',title='SimulationCraft: Assisted Combat model, Elemental Shaman',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Ascendance is in its cooldowns list.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Shaman',title='MaxDps Shaman module (Midnight)',reviewedAt='2026-10-23',revision='d3ad3b9b10',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={262},
  cooldowns={
   block('retail.shaman.upkeep','ele-'),
   block('retail.shaman.lightning-shield','ele-'),
   BuiltinConditions.spell('ele-ascendance',114050,fight),
   BuiltinConditions.spell('ele-fire-elemental',198067,fight),
   BuiltinConditions.spell('ele-storm-elemental',192249,fight),
   BuiltinConditions.spell('ele-natures-swiftness',378081,fight),
   BuiltinConditions.spell('ele-spiritwalkers-grace',79206,BuiltinConditions.all(fight,{type='MOVING'})),
  },
  rotation={
   block('retail.shaman.boundaries','ele-'),
   {id='ele-assisted',type='assisted',conditions={}},
  },
 },
}))
