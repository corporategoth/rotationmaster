-- Retail (Midnight 12.x) Demon Hunter before a specialization ("No specialization": the game reports the class's
-- initial specialization, ID 1456, from Blizzard's ChrSpecialization data), Blizzard Assisted
-- (recommended): the rotation is Blizzard's Assisted Combat suggestion, the one rotation input an
-- addon can still read in combat, after the shared cast/channel Stop. The shared Demon Hunter reminders
-- ride alongside; each lights only once its spell is known. A specialization's premades take over
-- once one is chosen.
local _,addon=...
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.initial',revision=5,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 nameKey='Default.Retail.DemonHunter.Initial.Name',descriptionKey='Default.Retail.DemonHunter.Initial.Description',
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'leveling','assisted-combat'},
 sources={
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://wago.tools/db2/ChrSpecialization',title='Blizzard client data: ChrSpecialization (the class initial specializations, order index 4)',reviewedAt='2026-10-23',revision='12.1.5',notes='Demon Hunter initial specialization 1456.'},
 },
 body={priority=20,specs={1456},
  cooldowns={
   block('initial-utility','retail.demonhunter.utility','initial-'),
  },
  rotation={
   block('initial-boundaries','retail.demonhunter.boundaries','initial-'),
   {id='initial-assisted',type='assisted',conditions={}},
  },
 },
}))
