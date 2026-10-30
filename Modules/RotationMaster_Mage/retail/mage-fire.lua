-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Fire Mage, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Combustion, Blazing Barrier whenever it is ready
-- in combat, Arcane Intellect, Counterspell and racial cooldowns.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.fire',revision=6,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'fire','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_fire.simc',title='SimulationCraft model of Blizzard Assisted Combat: Fire',reviewedAt='2026-10-23',revision='c5fea93f',notes='Combustion is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={63},
  cooldowns={
   BuiltinConditions.block('fire-utility','retail.mage.utility','fire-'),
   BuiltinConditions.spell('fire-combustion',190319,BuiltinConditions.combat()),
   BuiltinConditions.spell('fire-barrier',235313,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('fire-boundaries','retail.mage.boundaries','fire-'),
   {id='fire-assisted',type='assisted',conditions={}},
  },
 },
}))
