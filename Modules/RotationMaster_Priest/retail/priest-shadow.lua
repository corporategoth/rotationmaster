-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Shadow Priest, Blizzard Assisted (recommended). Midnight hides DoTs, buffs,
-- cooldown times and health from addons in combat; Blizzard's Assisted Combat pick stays readable,
-- so the rotation is that suggestion (it keeps Fortitude, Shadowform, both DoTs and Voidform
-- itself, and never clips Mind Flay) after the cast and no-target Stops. Reminders for what it
-- leaves out (SimulationCraft's assisted_combat/priest_shadow.simc): Power Infusion during
-- Voidform, Shadowform and Fortitude between pulls, Silence.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.shadow',revision=6,
 blocks={['retail.priest.boundaries']=3,['retail.priest.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'shadow','ranged','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/priest_shadow.simc',title='SimulationCraft: Assisted Combat model, Shadow Priest',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Power Infusion during Voidform is in its cooldowns list, not the suggestion.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Priest',title='MaxDps Priest module (Midnight)',reviewedAt='2026-10-23',revision='0ecad695',notes='No priority in Midnight: the Assisted Combat spell plus cooldown glows.'},
 },
 body={priority=10,specs={258},
  cooldowns={
   block('retail.priest.upkeep','shadow-'),
   BuiltinConditions.spell('shadow-shadowform',232698,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.ownBuff(232698)),BuiltinConditions.negate(BuiltinConditions.ownBuff(194249)))),
   BuiltinConditions.spell('shadow-power-infusion',10060,BuiltinConditions.all(fight,{type='SPELL_HISTORY_TIME',spell=228260,operator='LESSTHAN',value=20})),
  },
  rotation={
   block('retail.priest.boundaries','shadow-'),
   {id='shadow-assisted',type='assisted',conditions={}},
  },
 },
}))
