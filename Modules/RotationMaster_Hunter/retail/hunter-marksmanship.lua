-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Marksmanship Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion. Around it, highlights for what Assisted Combat leaves to
-- you: Trueshot, Counter Shot, the defensives and racial cooldowns.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.marksmanship',revision=6,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'marksmanship','ranged','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/hunter_marksmanship.simc',title='SimulationCraft model of Blizzard Assisted Combat: Marksmanship',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Trueshot, racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Hunter',title='MaxDps Hunter (Midnight)',reviewedAt='2026-10-23',revision='8800ce72',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={254},
  cooldowns={
   BuiltinConditions.block('mm-utility','retail.hunter.utility','mm-'),
   BuiltinConditions.spell('mm-trueshot',288613,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('mm-boundaries','retail.hunter.boundaries','mm-'),
   {id='mm-assisted',type='assisted',conditions={}},
  },
 },
}))
