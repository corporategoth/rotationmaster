-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Frost Death Knight, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion. Around it, highlights for what Assisted Combat leaves to
-- you: Breath of Sindragosa, Raise Dead, Mind Freeze, Icebound Fortitude and racial cooldowns.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.frost',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','melee','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/deathknight_frost.simc',title='SimulationCraft model of Blizzard Assisted Combat: Frost',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Breath of Sindragosa, Raise Dead, racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight',title='MaxDps Death Knight (Midnight)',reviewedAt='2026-10-23',revision='95faf1ba',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={251},
  cooldowns={
   BuiltinConditions.block('frost-utility','retail.deathknight.utility','frost-'),
   BuiltinConditions.spell('frost-breath-of-sindragosa',152279,BuiltinConditions.combat()),
   BuiltinConditions.spell('frost-raise-dead',46585,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('frost-boundaries','retail.deathknight.boundaries','frost-'),
   {id='frost-assisted',type='assisted',conditions={}},
  },
 },
}))
