-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Vengeance Demon Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what Assisted Combat leaves to you: Demon Spikes, Fiery Brand, Fel
-- Devastation and Metamorphosis, plus Disrupt and Blur.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.vengeance',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'vengeance','tank','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/demonhunter_vengeance.simc',title='SimulationCraft model of Blizzard Assisted Combat: Vengeance',reviewedAt='2026-10-23',revision='c5fea93f',notes='Metamorphosis is marked as not part of the in-game Assisted Combat; Demon Spikes, Fiery Brand and Fel Devastation are absent from its list.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DemonHunter',title='MaxDps Demon Hunter (Midnight)',reviewedAt='2026-10-23',revision='238137bc',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={581},
  cooldowns={
   BuiltinConditions.block('vengeance-utility','retail.demonhunter.utility','vengeance-'),
   BuiltinConditions.spell('vengeance-demon-spikes',203720,BuiltinConditions.combat()),
   BuiltinConditions.spell('vengeance-fiery-brand',204021,BuiltinConditions.combat()),
   BuiltinConditions.spell('vengeance-fel-devastation',212084,BuiltinConditions.combat()),
   BuiltinConditions.spell('vengeance-metamorphosis',187827,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('vengeance-boundaries','retail.demonhunter.boundaries','vengeance-'),
   {id='vengeance-assisted',type='assisted',conditions={}},
  },
 },
}))
