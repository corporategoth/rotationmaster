-- Retail (Midnight) Protection Warrior, Blizzard Assisted (recommended). Midnight hides rage,
-- Shield Block, procs, cooldown times and health from addons in combat; Blizzard's Assisted
-- Combat pick stays readable, so the rotation is that suggestion after the cast and no-target
-- Stops. Assisted Combat never casts Shield Block or Ignore Pain, so both are reminders whenever
-- they are usable and your target is attacking you (rage is hidden, so Ignore Pain prompts often).
-- Other reminders (SimulationCraft's assisted_combat/warrior_protection.simc): Avatar,
-- Demoralizing Shout, Champion's Spear, Shield Wall and Last Stand when ready, Taunt on a grouped
-- target attacking someone else, Battle Shout, Pummel.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.protection',revision=6,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1},
 nameKey='Default.Retail.Warrior.Protection.Name',descriptionKey='Default.Retail.Warrior.Protection.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'protection','tank','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/warrior_protection.simc',title='SimulationCraft: Assisted Combat model, Protection Warrior',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Warrior',title='MaxDps Warrior module (Midnight)',reviewedAt='2026-10-23',revision='c3bf773f37',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={73},
  cooldowns={
   block('retail.warrior.upkeep','prot-'),
   spell('prot-shield-block',2565,all(fight,{type='THREAT',unit='target',threat=3})),
   spell('prot-ignore-pain',190456,all(fight,{type='THREAT',unit='target',threat=3})),
   spell('prot-avatar',107574,fight),
   spell('prot-demoralizing-shout',1160,fight),
   spell('prot-champions-spear',376079,fight),
   spell('prot-shield-wall',871,combat()),
   spell('prot-last-stand',12975,combat()),
   spell('prot-taunt',355,all(fight,{type='GROUP'},{type='COMBAT',unit='target'},{type='NOT',value={type='THREAT',unit='target',threat=3}})),
  },
  rotation={
   block('retail.warrior.boundaries','prot-'),
   {id='prot-assisted',type='assisted',conditions={}},
  },
 },
}))
