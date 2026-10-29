-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Demonology Warlock, Blizzard Assisted (recommended). Midnight hides Demonic
-- Core, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick stays
-- readable, so the rotation is that suggestion (Dreadstalkers, Hand of Gul'dan, Demonbolt, Power
-- Siphon, Tyrant) after the cast and no-target Stops. Reminders for what it leaves out
-- (SimulationCraft's assisted_combat/warlock_demonology.simc and the guides): Summon Demonic
-- Tyrant while your Dreadstalkers are out (cast in the last 12 s), the Grimoires and Summon
-- Doomguard in combat, a Felguard between pulls, Command Demon, Dark Pact, Unending Resolve.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.demonology',revision=6,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 nameKey="Blizzard Assisted",descriptionKey="Recommended for Demonology in Midnight. Shows Blizzard's Assisted Combat suggestion (Call Dreadstalkers, Hand of Gul'dan, Demonbolt, Power Siphon and Tyrant), and stops while you cast, channel or have no enemy targeted. Reminders for what it leaves out: Summon Demonic Tyrant while the Dreadstalkers you called in the last 12 seconds are out, Grimoire: Imp Lord, Grimoire: Fel Ravager and Summon Doomguard in combat, a Felguard between pulls, Command Demon, Dark Pact, Unending Resolve.",
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'demonology','ranged','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/warlock_demonology.simc',title='SimulationCraft: Assisted Combat model, Demonology Warlock',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Warlock',title='MaxDps Warlock module (Midnight)',reviewedAt='2026-10-23',revision='432c75e0dd',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
  {url='https://www.icy-veins.com/wow/demonology-warlock-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Demonology Warlock rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Grimoires and Summon Doomguard, which the Assisted Combat model never casts.'},
 },
 body={priority=10,specs={266},
  cooldowns={
   block('retail.warlock.upkeep','demo-'),
   spell('demo-summon-felguard',30146,all(negate(combat()),negate({type='PET'}))),
   spell('demo-tyrant',265187,all(fight,{type='SPELL_HISTORY_TIME',spell=104316,operator='LESSTHAN',value=12})),
   spell('demo-imp-lord',1276452,fight),
   spell('demo-fel-ravager',1276467,fight),
   spell('demo-doomguard',1276672,fight),
  },
  rotation={
   block('retail.warlock.boundaries','demo-'),
   {id='demo-assisted',type='assisted',conditions={}},
  },
 },
}))
