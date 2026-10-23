-- Retail (Midnight) Enhancement Shaman, Blizzard Assisted (recommended). Midnight hides Flame
-- Shock, procs, cooldown times and health from addons in combat; Blizzard's Assisted Combat pick
-- stays readable, so the rotation is that suggestion after the cast and no-target Stops.
-- Reminders for what it leaves out (SimulationCraft's assisted_combat/shaman_enhancement.simc):
-- Ascendance, Doom Winds and Feral Spirit in combat, Lightning Shield and Skyfury between pulls,
-- Wind Shear, Astral Shift.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.enhancement',revision=1,
 blocks={['retail.shaman.boundaries']=1,['retail.shaman.upkeep']=1,['retail.shaman.lightning-shield']=1},
 nameKey='Default.Retail.Shaman.Enhancement.Name',descriptionKey='Default.Retail.Shaman.Enhancement.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN',specs={263},minLevel=10,maxLevel=90},
 tags={'enhancement','melee','assisted-combat','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/shaman_enhancement.simc',title='SimulationCraft: Assisted Combat model, Enhancement Shaman',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Ascendance and Doom Winds are in its cooldowns list.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/e7aa82019dc298e0351c7159d60c2a9b916b9b67/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Shaman',title='MaxDps Shaman module (Midnight)',reviewedAt='2026-10-23',revision='d3ad3b9b10',notes='No priority in Midnight: the Assisted Combat spell plus a permanent Doom Winds glow and defensive and interrupt glows.'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('retail.shaman.upkeep','enh-'),
   block('retail.shaman.lightning-shield','enh-'),
   spell('enh-ascendance',114051,fight),
   spell('enh-doom-winds',384352,fight),
   spell('enh-feral-spirit',51533,fight),
  },
  rotation={
   block('retail.shaman.boundaries','enh-'),
   {id='enh-assisted',type='assisted',conditions={}},
  },
 },
}))
