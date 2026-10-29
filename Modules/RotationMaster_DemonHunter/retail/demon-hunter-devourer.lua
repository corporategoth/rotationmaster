-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Devourer Demon Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what Assisted Combat leaves to you: Void Metamorphosis, The Hunt and
-- Voidblade, which its model marks as outside the assistant, plus Disrupt and Blur.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.devourer',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Devourer. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel Void Ray. Alongside it, reminders for what the assistant leaves to you: Void Metamorphosis, The Hunt and Voidblade whenever they are ready in combat, Disrupt on an interruptible cast, and Blur whenever it is ready in combat. Enemy casts are hidden in combat, so Disrupt lights only where the game shows them; health is hidden on Retail, so when to use Blur is your call.",
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'devourer','ranged','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/demonhunter_devourer.simc',title='SimulationCraft model of Blizzard Assisted Combat: Devourer',reviewedAt='2026-10-23',revision='c5fea93f',notes='Metamorphosis, The Hunt and Voidblade are marked as not part of the in-game Assisted Combat.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DemonHunter',title='MaxDps Demon Hunter (Midnight)',reviewedAt='2026-10-23',revision='238137bc',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={1480},
  cooldowns={
   block('devourer-utility','retail.demonhunter.utility','devourer-'),
   spell('devourer-void-metamorphosis',1217605,combat()),
   spell('devourer-the-hunt',1246167,combat()),
   spell('devourer-voidblade',1245412,combat()),
  },
  rotation={
   block('devourer-boundaries','retail.demonhunter.boundaries','devourer-'),
   {id='devourer-assisted',type='assisted',conditions={}},
  },
 },
}))
