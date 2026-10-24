-- Retail (Midnight 12.x) Guardian Druid, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, which plays for damage only. Around it, highlights for what Assisted
-- Combat leaves to you: Berserk (or Incarnation), Convoke the Spirits, Ironfur whenever it is ready,
-- Frenzied Regeneration, Survival Instincts, Skull Bash, Bear Form between pulls, Mark of the Wild,
-- Barkskin and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian',revision=3,
 blocks={['retail.druid.boundaries']=2,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.Guardian.Name',descriptionKey='Default.Retail.Druid.Guardian.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'guardian','tank','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/druid_guardian.simc',title='SimulationCraft model of Blizzard Assisted Combat: Guardian',reviewedAt='2026-10-23',revision='c5fea93f',notes='Berserk and Convoke the Spirits are marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Druid',title='MaxDps Druid (Midnight)',reviewedAt='2026-10-23',revision='01642676',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='SPECIALIZATION',spec=104},
  cooldowns={
   block('guardian-utility','retail.druid.utility','guardian-'),
   spell('guardian-skull-bash',106839,interrupt),
   spell('guardian-berserk',50334,combat()),
   spell('guardian-incarnation',102558,combat()),
   spell('guardian-convoke',391528,combat()),
   spell('guardian-ironfur',192081,combat()),
   spell('guardian-frenzied-regeneration',22842,combat()),
   spell('guardian-survival-instincts',61336,combat()),
   spell('guardian-bear-form',5487,all(negate(combat()),negate({type='BUFF',unit='player',spell=5487}),negate({type='BUFF',unit='player',spell=102558}))),
  },
  rotation={
   block('guardian-boundaries','retail.druid.boundaries','guardian-'),
   {id='guardian-assisted',type='assisted',conditions={}},
  },
 },
}))
