-- Retail (Midnight) Retribution Paladin, Blizzard Assisted (recommended). Midnight hides buffs,
-- debuffs, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick stays
-- readable, so the rotation is that suggestion, after the cast and no-target Stops. Reminders for
-- what it never suggests (SimulationCraft's model of it, assisted_combat/paladin_retribution.simc):
-- aura, Rebuke, defensives. Shared parts: Defaults/blocks/retail-paladin.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.retribution',revision=5,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2},
 nameKey='Default.Retail.Paladin.Retribution.Name',descriptionKey='Default.Retail.Paladin.Retribution.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'retribution','melee','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/paladin_retribution.simc',title='SimulationCraft: Assisted Combat model, Retribution Paladin',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='What Blizzard\'s one-button rotation suggests; its cooldowns list is racials, items and potions only.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Paladin',title='MaxDps Paladin module (Midnight)',reviewedAt='2026-10-23',revision='7bfdb965',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={70},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('retail.paladin.upkeep','ret-'),
   spell('ret-divine-protection',403876,combat()),
  },
  rotation={
   block('retail.paladin.boundaries','ret-'),
   {id='ret-assisted',type='assisted',conditions={}},
  },
 },
}))
