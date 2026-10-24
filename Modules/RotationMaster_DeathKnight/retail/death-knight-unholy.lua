-- Retail (Midnight 12.x) Unholy Death Knight, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion (it raises your ghoul and uses Army of the Dead and Dark
-- Transformation itself). Around it, highlights for Mind Freeze, Icebound Fortitude and racial
-- cooldowns.
local _,addon=...
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.unholy',revision=4,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.Unholy.Name',descriptionKey='Default.Retail.DeathKnight.Unholy.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','melee','pet','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/deathknight_unholy.simc',title='SimulationCraft model of Blizzard Assisted Combat: Unholy',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight',title='MaxDps Death Knight (Midnight)',reviewedAt='2026-10-23',revision='95faf1ba',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='SPECIALIZATION',spec=252},
  cooldowns={block('unholy-utility','retail.deathknight.utility','unholy-')},
  rotation={
   block('unholy-boundaries','retail.deathknight.boundaries','unholy-'),
   {id='unholy-assisted',type='assisted',conditions={}},
  },
 },
}))
