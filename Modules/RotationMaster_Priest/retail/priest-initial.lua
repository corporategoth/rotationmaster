-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Priest before a specialization ("No specialization": the game reports the class's
-- initial specialization, ID 1452, from Blizzard's ChrSpecialization data), Blizzard Assisted
-- (recommended): the rotation is Blizzard's Assisted Combat suggestion, the one rotation input an
-- addon can still read in combat, after the shared Stop (a cast, a channel or no attackable
-- target). The shared Priest reminders ride alongside; each lights only once its spell is known.
-- A specialization's premades take over once one is chosen.
local _,addon=...
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.initial',revision=5,
 blocks={['retail.priest.boundaries']=3,['retail.priest.upkeep']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended before you choose a specialization (while the game reports the Priest's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Priest premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over.",
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'leveling','assisted-combat'},
 sources={
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://wago.tools/db2/ChrSpecialization',title='Blizzard client data: ChrSpecialization (the class initial specializations, order index 4)',reviewedAt='2026-10-23',revision='12.1.5',notes='Priest initial specialization 1452.'},
 },
 body={priority=10,specs={1452},
  cooldowns={
   block('retail.priest.upkeep','initial-'),
  },
  rotation={
   block('retail.priest.boundaries','initial-'),
   {id='initial-assisted',type='assisted',conditions={}},
  },
 },
}))
