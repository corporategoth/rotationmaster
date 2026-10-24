-- Retail (Midnight 12.x) Arcane Mage, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Arcane Surge, Prismatic Barrier whenever it is
-- ready in combat, Arcane Intellect, Counterspell and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.arcane',revision=2,
 blocks={['retail.mage.boundaries']=1,['retail.mage.utility']=2},
 nameKey='Default.Retail.Mage.Arcane.Name',descriptionKey='Default.Retail.Mage.Arcane.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE',specs={62},minLevel=10,maxLevel=90},
 tags={'arcane','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_arcane.simc',title='SimulationCraft model of Blizzard Assisted Combat: Arcane',reviewedAt='2026-10-23',revision='c5fea93f',notes='Arcane Surge is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('arcane-utility','retail.mage.utility','arcane-'),
   spell('arcane-arcane-surge',365350,combat()),
   spell('arcane-barrier',235450,combat()),
  },
  rotation={
   block('arcane-boundaries','retail.mage.boundaries','arcane-'),
   {id='arcane-assisted',type='assisted',conditions={}},
  },
 },
}))
