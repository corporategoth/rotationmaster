-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Affliction Warlock, Blizzard Assisted (recommended). Midnight hides DoTs,
-- procs, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick stays
-- readable, so the rotation is that suggestion (it keeps Agony and Corruption, spends shards on
-- Unstable Affliction and handles Grimoire of Sacrifice) after the cast and no-target Stops.
-- Reminders for what it leaves out (SimulationCraft's assisted_combat/warlock_affliction.simc):
-- Summon Darkglare in combat, a Felhunter between pulls unless you sacrificed it, Command Demon,
-- Dark Pact, Unending Resolve.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.affliction',revision=6,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Affliction in Midnight. In combat the game now hides your DoTs, procs, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation, which keeps Agony and Corruption, spends shards on Unstable Affliction and handles Grimoire of Sacrifice), and stops while you cast, channel or have no enemy targeted. Reminders for what it leaves out: Summon Darkglare in combat, a Felhunter between pulls unless you sacrificed your demon, Command Demon on an interruptible cast (it lights only where the game lets the cast be read), Dark Pact and Unending Resolve whenever they are ready in combat (health is hidden on Retail, so when to use them is your call).",
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'affliction','ranged','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/warlock_affliction.simc',title='SimulationCraft: Assisted Combat model, Affliction Warlock',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Warlock',title='MaxDps Warlock module (Midnight)',reviewedAt='2026-10-23',revision='432c75e0dd',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={265},
  cooldowns={
   block('retail.warlock.upkeep','aff-'),
   spell('aff-summon-felhunter',691,all(negate(combat()),negate({type='PET'}),negate({type='BUFF',unit='player',spell=196099,ownbuff=true}))),
   spell('aff-darkglare',205180,fight),
  },
  rotation={
   block('retail.warlock.boundaries','aff-'),
   {id='aff-assisted',type='assisted',conditions={}},
  },
 },
}))
