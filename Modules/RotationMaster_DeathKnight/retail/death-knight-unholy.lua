-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Unholy Death Knight, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion (it raises your ghoul and uses Army of the Dead and Dark
-- Transformation itself). Around it, highlights for Mind Freeze, Icebound Fortitude and racial
-- cooldowns.
local _,addon=...
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.unholy',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Unholy. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it raises your ghoul and uses Army of the Dead and Dark Transformation itself); it waits while you cast or channel. Alongside it: Mind Freeze on an interruptible cast, and Icebound Fortitude and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so Mind Freeze lights only where the game shows them; health is hidden on Retail, so when to use Icebound Fortitude is your call.",
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','melee','pet','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/deathknight_unholy.simc',title='SimulationCraft model of Blizzard Assisted Combat: Unholy',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight',title='MaxDps Death Knight (Midnight)',reviewedAt='2026-10-23',revision='95faf1ba',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={252},
  cooldowns={block('unholy-utility','retail.deathknight.utility','unholy-')},
  rotation={
   block('unholy-boundaries','retail.deathknight.boundaries','unholy-'),
   {id='unholy-assisted',type='assisted',conditions={}},
  },
 },
}))
