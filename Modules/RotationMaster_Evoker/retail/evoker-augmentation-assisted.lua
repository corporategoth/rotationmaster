-- Retail (Midnight 12.x) Augmentation Evoker, Blizzard Assisted (alternative to the Icy Veins Ebon
-- Might premade, lower priority): the rotation is Blizzard's Assisted Combat suggestion, which recasts
-- Ebon Might only after it falls off. Highlights for what simc's model of it leaves to you: Breath of
-- Eons, Deep Breath, Tip the Scales and Time Skip in combat, plus the Evoker utility reminders.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.augmentation.assisted',revision=2,
 blocks={['retail.evoker.boundaries']=1,['retail.evoker.utility']=2},
 nameKey='Default.Retail.Evoker.AugmentationAssisted.Name',descriptionKey='Default.Retail.Evoker.AugmentationAssisted.Description',
 applicability={families={'retail'},actionContext='player',class='EVOKER',specs={1473},minLevel=10,maxLevel=90},
 tags={'augmentation','ranged','support','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/evoker_augmentation.simc',title='SimulationCraft model of Blizzard Assisted Combat: Augmentation',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Breath of Eons, Deep Breath, Tip the Scales, Time Skip) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Evoker',title='MaxDps Evoker (Midnight)',reviewedAt='2026-10-23',revision='a63a8438',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('augac-utility','retail.evoker.utility','augac-'),
   spell('augac-breath-of-eons',403631,combat()),
   spell('augac-deep-breath',357210,combat()),
   spell('augac-tip-the-scales',370553,combat()),
   spell('augac-time-skip',404977,combat()),
  },
  rotation={
   block('augac-boundaries','retail.evoker.boundaries','augac-'),
   {id='augac-assisted',type='assisted',conditions={}},
  },
 },
}))
