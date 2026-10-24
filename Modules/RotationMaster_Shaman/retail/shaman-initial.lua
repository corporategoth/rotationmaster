-- Retail (Midnight 12.x) Shaman before a specialization (levels 1-9; the game reports the class's
-- initial specialization, ID 1444, from Blizzard's ChrSpecialization data), Blizzard Assisted
-- (recommended): the rotation is Blizzard's Assisted Combat suggestion, the one rotation input an
-- addon can still read in combat, after the shared cast/channel Stops. The shared Shaman reminders
-- ride alongside; each lights only once its spell is known. A specialization's premades take over
-- once one is chosen.
local _,addon=...
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.initial',revision=2,
 blocks={['retail.shaman.boundaries']=1,['retail.shaman.upkeep']=2},
 nameKey='Default.Retail.Shaman.Initial.Name',descriptionKey='Default.Retail.Shaman.Initial.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'leveling','assisted-combat'},
 sources={
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://wago.tools/db2/ChrSpecialization',title='Blizzard client data: ChrSpecialization (the class initial specializations, order index 4)',reviewedAt='2026-10-23',revision='12.1.5',notes='Shaman initial specialization 1444.'},
 },
 body={priority=10,switch={type='SPECIALIZATION',spec=1444},
  cooldowns={
   block('retail.shaman.upkeep','initial-'),
  },
  rotation={
   block('retail.shaman.boundaries','initial-'),
   {id='initial-assisted',type='assisted',conditions={}},
  },
 },
}))
