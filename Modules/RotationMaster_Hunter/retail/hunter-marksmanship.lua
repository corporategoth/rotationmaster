-- Retail (Midnight 12.x) Marksmanship Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion. Around it, highlights for what Assisted Combat leaves to
-- you: Trueshot, Counter Shot, the defensives and racial cooldowns.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.marksmanship',revision=5,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2},
 nameKey='Default.Retail.Hunter.Marksmanship.Name',descriptionKey='Default.Retail.Hunter.Marksmanship.Description',
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'marksmanship','ranged','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/hunter_marksmanship.simc',title='SimulationCraft model of Blizzard Assisted Combat: Marksmanship',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Trueshot, racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Hunter',title='MaxDps Hunter (Midnight)',reviewedAt='2026-10-23',revision='8800ce72',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={254},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('mm-utility','retail.hunter.utility','mm-'),
   spell('mm-trueshot',288613,combat()),
  },
  rotation={
   block('mm-boundaries','retail.hunter.boundaries','mm-'),
   {id='mm-assisted',type='assisted',conditions={}},
  },
 },
}))
