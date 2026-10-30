-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Havoc Demon Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what Assisted Combat leaves to you: Metamorphosis, The Hunt and
-- Vengeful Retreat (with Inertia or Exergy), which its model marks as outside the assistant, plus
-- Disrupt and Blur.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.havoc',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'havoc','melee','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/demonhunter_havoc.simc',title='SimulationCraft model of Blizzard Assisted Combat: Havoc',reviewedAt='2026-10-23',revision='c5fea93f',notes='Metamorphosis, The Hunt, Vengeful Retreat and Fel Rush are marked as not part of the in-game Assisted Combat.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DemonHunter',title='MaxDps Demon Hunter (Midnight)',reviewedAt='2026-10-23',revision='238137bc',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={577},
  cooldowns={
   BuiltinConditions.block('havoc-utility','retail.demonhunter.utility','havoc-'),
   BuiltinConditions.spell('havoc-metamorphosis',191427,BuiltinConditions.combat()),
   BuiltinConditions.spell('havoc-the-hunt',370965,BuiltinConditions.combat()),
   BuiltinConditions.spell('havoc-vengeful-retreat',198793,BuiltinConditions.any(BuiltinConditions.known(427640),BuiltinConditions.known(206476))),
  },
  rotation={
   BuiltinConditions.block('havoc-boundaries','retail.demonhunter.boundaries','havoc-'),
   {id='havoc-assisted',type='assisted',conditions={}},
  },
 },
}))
