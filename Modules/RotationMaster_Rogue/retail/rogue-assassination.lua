-- Retail (Midnight) Assassination Rogue, Blizzard Assisted (recommended). Midnight hides bleeds,
-- buffs, energy, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick
-- stays readable, so the rotation is that suggestion (it handles the stealth opener, bleeds and
-- Envenom) after the cast and no-target Stops. Reminders for what it leaves out (SimulationCraft's
-- assisted_combat/rogue_assassination.simc): poisons and Stealth between pulls, Kick, and Vanish
-- whenever you are out of stealth in combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.assassination',revision=3,
 blocks={['retail.rogue.boundaries']=1,['retail.rogue.upkeep']=2},
 nameKey='Default.Retail.Rogue.Assassination.Name',descriptionKey='Default.Retail.Rogue.Assassination.Description',
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'assassination','melee','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/rogue_assassination.simc',title='SimulationCraft: Assisted Combat model, Assassination Rogue',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Rogue',title='MaxDps Rogue module (Midnight)',reviewedAt='2026-10-23',revision='6145c857',notes='No priority in Midnight: the Assisted Combat spell plus cooldown and defensive glows.'},
 },
 body={priority=10,switch={type='SPECIALIZATION',spec=259},
  cooldowns={
   block('retail.rogue.upkeep','assa-'),
   spell('assa-vanish',1856,all(fight,negate({type='STEALTHED'}))),
  },
  rotation={
   block('retail.rogue.boundaries','assa-'),
   {id='assa-assisted',type='assisted',conditions={}},
  },
 },
}))
