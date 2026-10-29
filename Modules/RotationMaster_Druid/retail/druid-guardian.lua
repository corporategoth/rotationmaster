-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Guardian Druid, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, which plays for damage only. Around it, highlights for what Assisted
-- Combat leaves to you: Berserk (or Incarnation), Convoke the Spirits, Ironfur whenever it is ready,
-- Frenzied Regeneration, Survival Instincts, Skull Bash, Bear Form between pulls, Mark of the Wild,
-- Barkskin and racial cooldowns.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'guardian','tank','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/druid_guardian.simc',title='SimulationCraft model of Blizzard Assisted Combat: Guardian',reviewedAt='2026-10-23',revision='c5fea93f',notes='Berserk and Convoke the Spirits are marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Druid',title='MaxDps Druid (Midnight)',reviewedAt='2026-10-23',revision='01642676',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={104},
  cooldowns={
   BuiltinConditions.block('guardian-utility','retail.druid.utility','guardian-'),
   BuiltinConditions.spell('guardian-skull-bash',106839,interrupt),
   BuiltinConditions.spell('guardian-berserk',50334,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-incarnation',102558,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-convoke',391528,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-ironfur',192081,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-frenzied-regeneration',22842,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-survival-instincts',61336,BuiltinConditions.combat()),
   BuiltinConditions.spell('guardian-bear-form',5487,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=5487}),BuiltinConditions.negate({type='BUFF',unit='player',spell=102558}))),
  },
  rotation={
   BuiltinConditions.block('guardian-boundaries','retail.druid.boundaries','guardian-'),
   {id='guardian-assisted',type='assisted',conditions={}},
  },
 },
}))
