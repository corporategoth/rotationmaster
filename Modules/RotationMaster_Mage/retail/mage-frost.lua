-- Retail (Midnight 12.x) Frost Mage, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Ice Barrier whenever it is ready in combat, Summon
-- Water Elemental when you have none, Arcane Intellect, Counterspell and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.frost',revision=5,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 nameKey='Default.Retail.Mage.Frost.Name',descriptionKey='Default.Retail.Mage.Frost.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'frost','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_frost.simc',title='SimulationCraft model of Blizzard Assisted Combat: Frost',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={64},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('frost-utility','retail.mage.utility','frost-'),
   spell('frost-barrier',11426,combat()),
   spell('frost-water-elemental',31687,negate({type='PET'})),
  },
  rotation={
   block('frost-boundaries','retail.mage.boundaries','frost-'),
   {id='frost-assisted',type='assisted',conditions={}},
  },
 },
}))
