-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.arcane',revision=6,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Arcane. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Arcane Surge in combat, Arcane Intellect out of combat, Counterspell on an interruptible cast, Prismatic Barrier whenever it is ready in combat, and your racial cooldown in combat. Enemy casts are hidden in combat, so Counterspell lights only where the game shows them; health is hidden on Retail, so Ice Block and other emergency buttons are your call. Mirror Image, Alter Time, Blink and trinkets stay with you.",
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'arcane','caster','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/mage_arcane.simc',title='SimulationCraft model of Blizzard Assisted Combat: Arcane',reviewedAt='2026-10-23',revision='c5fea93f',notes='Arcane Surge is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Mage',title='MaxDps Mage (Midnight)',reviewedAt='2026-10-23',revision='886c8e27',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={62},
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
