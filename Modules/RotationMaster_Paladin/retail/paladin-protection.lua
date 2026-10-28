-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Protection Paladin, Blizzard Assisted (recommended). The rotation is Blizzard's
-- Assisted Combat suggestion after the cast and no-target Stops; it already spends Holy Power on
-- Shield of the Righteous. Reminders for what it never suggests: aura, Rebuke, Ardent Defender,
-- Guardian of Ancient Kings, Lay on Hands. Shared parts: Defaults/blocks/retail-paladin.lua.
local _,addon=...
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.protection',revision=6,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2,['retail.paladin.prot-defensives']=2},
 nameKey='Default.Retail.Paladin.Protection.Name',descriptionKey='Default.Retail.Paladin.Protection.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'protection','tank','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/paladin_protection.simc',title='SimulationCraft: Assisted Combat model, Protection Paladin',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Avenging Wrath, Sentinel and Shield of the Righteous are in the suggestion; defensives are not.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Paladin',title='MaxDps Paladin module (Midnight)',reviewedAt='2026-10-23',revision='7bfdb965',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={66},
  cooldowns={
   block('retail.paladin.upkeep','prot-'),
   block('retail.paladin.prot-defensives','prot-'),
  },
  rotation={
   block('retail.paladin.boundaries','prot-'),
   {id='prot-assisted',type='assisted',conditions={}},
  },
 },
}))
