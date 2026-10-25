-- Retail (Midnight 12.x) Devastation Evoker, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what simc's model of it leaves to you: Dragonrage, Deep Breath and Tip
-- the Scales in combat, plus Quell, Obsidian Scales, Blessing of the Bronze and Source of Magic.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.devastation',revision=5,
 blocks={['retail.evoker.boundaries']=3,['retail.evoker.utility']=2},
 nameKey='Default.Retail.Evoker.Devastation.Name',descriptionKey='Default.Retail.Evoker.Devastation.Description',
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'devastation','ranged','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/evoker_devastation.simc',title='SimulationCraft model of Blizzard Assisted Combat: Devastation',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Deep Breath, Dragonrage, Tip the Scales) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Evoker',title='MaxDps Evoker (Midnight)',reviewedAt='2026-10-23',revision='a63a8438',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={1467},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('dev-utility','retail.evoker.utility','dev-'),
   spell('dev-dragonrage',375087,combat()),
   spell('dev-deep-breath',357210,combat()),
   spell('dev-tip-the-scales',370553,combat()),
  },
  rotation={
   block('dev-boundaries','retail.evoker.boundaries','dev-'),
   {id='dev-assisted',type='assisted',conditions={}},
  },
 },
}))
