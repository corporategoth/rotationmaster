-- Retail (Midnight 12.x) Fire Mage, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Combustion, Blazing Barrier whenever it is ready
-- in combat, Arcane Intellect, Counterspell and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.fire',revision=3,
 blocks={['retail.mage.boundaries']=2,['retail.mage.utility']=2},
 nameKey='Default.Retail.Mage.Fire.Name',descriptionKey='Default.Retail.Mage.Fire.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'fire','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_fire.simc',title='SimulationCraft model of Blizzard Assisted Combat: Fire',reviewedAt='2026-10-23',revision='c5fea93f',notes='Combustion is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='SPECIALIZATION',spec=63},
  cooldowns={
   block('fire-utility','retail.mage.utility','fire-'),
   spell('fire-combustion',190319,combat()),
   spell('fire-barrier',235313,combat()),
  },
  rotation={
   block('fire-boundaries','retail.mage.boundaries','fire-'),
   {id='fire-assisted',type='assisted',conditions={}},
  },
 },
}))
