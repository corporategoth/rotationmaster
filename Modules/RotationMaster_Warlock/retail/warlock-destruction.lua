-- Retail (Midnight) Destruction Warlock, Blizzard Assisted (recommended). Midnight hides
-- Immolate, Backdraft, cooldown times and health from addons in combat; Blizzard's Assisted
-- Combat pick stays readable, so the rotation is that suggestion (Immolate or Wither, Conflagrate,
-- Chaos Bolt, Rain of Fire, Soul Fire, Malevolence) after the cast and no-target Stops. Reminders
-- for what it leaves out (SimulationCraft's assisted_combat/warlock_destruction.simc): Summon
-- Infernal in combat, an Imp between pulls unless you sacrificed it, Command Demon, Dark Pact,
-- Unending Resolve. Havoc on a second target stays manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.destruction',revision=6,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 nameKey='Default.Retail.Warlock.Destruction.Name',descriptionKey='Default.Retail.Warlock.Destruction.Description',
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'destruction','ranged','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/warlock_destruction.simc',title='SimulationCraft: Assisted Combat model, Destruction Warlock',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Warlock',title='MaxDps Warlock module (Midnight)',reviewedAt='2026-10-23',revision='432c75e0dd',notes='No priority in Midnight: the Assisted Combat spell plus cooldown, defensive and interrupt glows.'},
 },
 body={priority=10,specs={267},
  cooldowns={
   block('retail.warlock.upkeep','destro-'),
   spell('destro-summon-imp',688,all(negate(combat()),negate({type='PET'}),negate({type='BUFF',unit='player',spell=196099,ownbuff=true}))),
   spell('destro-summon-infernal',1122,fight),
  },
  rotation={
   block('retail.warlock.boundaries','destro-'),
   {id='destro-assisted',type='assisted',conditions={}},
  },
 },
}))
