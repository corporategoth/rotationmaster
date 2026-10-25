-- Retail (Midnight 12.x) Feral Druid, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion. Around it, highlights for what Assisted Combat leaves to you: Berserk
-- (or Incarnation), Skull Bash, Survival Instincts, Cat Form between pulls, Mark of the Wild, Barkskin and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.feral',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.Feral.Name',descriptionKey='Default.Retail.Druid.Feral.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'feral','melee','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/druid_feral.simc',title='SimulationCraft model of Blizzard Assisted Combat: Feral',reviewedAt='2026-10-23',revision='c5fea93f',notes='Berserk is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Druid',title='MaxDps Druid (Midnight)',reviewedAt='2026-10-23',revision='01642676',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={103},
  cooldowns={
   block('feral-utility','retail.druid.utility','feral-'),
   spell('feral-skull-bash',106839,interrupt),
   spell('feral-berserk',106951,combat()),
   spell('feral-incarnation',102543,combat()),
   spell('feral-survival-instincts',61336,combat()),
   spell('feral-cat-form',768,all(negate(combat()),negate({type='BUFF',unit='player',spell=768}),negate({type='BUFF',unit='player',spell=102543}))),
  },
  rotation={
   block('feral-boundaries','retail.druid.boundaries','feral-'),
   {id='feral-assisted',type='assisted',conditions={}},
  },
 },
}))
