-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Beast Mastery Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion (it calls your pet itself). Around it, highlights for what
-- Assisted Combat leaves to you: Bloodshed, Counter Shot, the defensives and racial cooldowns.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.beastmastery',revision=6,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Beast Mastery. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it calls your pet itself); it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Bloodshed and your racial cooldown in combat, Counter Shot on an interruptible cast, and Survival of the Fittest whenever it is ready in combat. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use your defensives (Exhilaration and Aspect of the Turtle included) is your call. Trinkets, Misdirection and pet care stay with you.",
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'beast-mastery','ranged','pet','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/hunter_beast_mastery.simc',title='SimulationCraft model of Blizzard Assisted Combat: Beast Mastery',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Hunter',title='MaxDps Hunter (Midnight)',reviewedAt='2026-10-23',revision='8800ce72',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={253},
  cooldowns={
   block('bm-utility','retail.hunter.utility','bm-'),
   spell('bm-bloodshed',321530,combat()),
  },
  rotation={
   block('bm-boundaries','retail.hunter.boundaries','bm-'),
   {id='bm-assisted',type='assisted',conditions={}},
  },
 },
}))
