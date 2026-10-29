-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Frost Mage, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Ice Barrier whenever it is ready in combat, Summon
-- Water Elemental when you have none, Arcane Intellect, Counterspell and racial cooldowns.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.frost',revision=6,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'frost','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_frost.simc',title='SimulationCraft model of Blizzard Assisted Combat: Frost',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={64},
  cooldowns={
   BuiltinConditions.block('frost-utility','retail.mage.utility','frost-'),
   BuiltinConditions.spell('frost-barrier',11426,BuiltinConditions.combat()),
   BuiltinConditions.spell('frost-water-elemental',31687,BuiltinConditions.negate({type='PET'})),
  },
  rotation={
   BuiltinConditions.block('frost-boundaries','retail.mage.boundaries','frost-'),
   {id='frost-assisted',type='assisted',conditions={}},
  },
 },
}))
