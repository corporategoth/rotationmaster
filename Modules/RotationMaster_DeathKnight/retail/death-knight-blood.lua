-- Retail (Midnight 12.x) Blood Death Knight, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what Assisted Combat leaves to you: Vampiric Blood, Raise Dead, Mind
-- Freeze, Icebound Fortitude and racial cooldowns.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.blood',revision=2,
 blocks={['retail.deathknight.boundaries']=1,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.Blood.Name',descriptionKey='Default.Retail.DeathKnight.Blood.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT',specs={250},minLevel=8,maxLevel=90},
 tags={'blood','tank','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/deathknight_blood.simc',title='SimulationCraft model of Blizzard Assisted Combat: Blood',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Vampiric Blood, Raise Dead, racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight',title='MaxDps Death Knight (Midnight)',reviewedAt='2026-10-23',revision='95faf1ba',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=8},
  cooldowns={
   block('blood-utility','retail.deathknight.utility','blood-'),
   spell('blood-vampiric-blood',55233,combat()),
   spell('blood-raise-dead',46585,combat()),
  },
  rotation={
   block('blood-boundaries','retail.deathknight.boundaries','blood-'),
   {id='blood-assisted',type='assisted',conditions={}},
  },
 },
}))
