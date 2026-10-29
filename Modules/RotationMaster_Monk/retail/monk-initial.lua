-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Monk before a specialization ("No specialization": the game reports the class's
-- initial specialization, ID 1450, from Blizzard's ChrSpecialization data), Blizzard Assisted
-- (recommended): the rotation is Blizzard's Assisted Combat suggestion, the one rotation input an
-- addon can still read in combat, after the shared cast/channel Stop. The shared Monk reminders
-- ride alongside; each lights only once its spell is known. A specialization's premades take over
-- once one is chosen.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.initial',revision=5,
 blocks={['retail.monk.boundaries']=3,['retail.monk.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'leveling','assisted-combat'},
 sources={
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://wago.tools/db2/ChrSpecialization',title='Blizzard client data: ChrSpecialization (the class initial specializations, order index 4)',reviewedAt='2026-10-23',revision='12.1.5',notes='Monk initial specialization 1450.'},
 },
 body={priority=20,specs={1450},
  cooldowns={
   BuiltinConditions.block('initial-utility','retail.monk.utility','initial-'),
  },
  rotation={
   BuiltinConditions.block('initial-boundaries','retail.monk.boundaries','initial-'),
   {id='initial-assisted',type='assisted',conditions={}},
  },
 },
}))
