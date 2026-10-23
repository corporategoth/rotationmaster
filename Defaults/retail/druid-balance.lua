-- Retail (Midnight 12.x) Balance Druid, Blizzard Assisted (recommended): the rotation is Blizzard's
-- Assisted Combat suggestion, the one rotation input an addon can still read in combat. Around it,
-- highlights for what Assisted Combat leaves to you: Celestial Alignment (or Incarnation), Solar Beam,
-- Moonkin Form between pulls, Mark of the Wild, Barkskin and racial cooldowns.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(v)return all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=v})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.balance',revision=1,
 blocks={['retail.druid.boundaries']=1,['retail.druid.utility']=1},
 nameKey='Default.Retail.Druid.Balance.Name',descriptionKey='Default.Retail.Druid.Balance.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID',specs={102},minLevel=10,maxLevel=90},
 tags={'balance','ranged','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/druid_balance.simc',title='SimulationCraft model of Blizzard Assisted Combat: Balance',reviewedAt='2026-10-23',revision='c5fea93f',notes='Celestial Alignment is marked as outside the in-game Assisted Combat; its cooldowns list adds racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Druid',title='MaxDps Druid (Midnight)',reviewedAt='2026-10-23',revision='01642676',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('balance-utility','retail.druid.utility','balance-'),
   spell('balance-solar-beam',78675,interrupt),
   spell('balance-celestial-alignment',194223,combat()),
   spell('balance-incarnation',102560,combat()),
   spell('balance-moonkin-form',24858,all(negate(combat()),negate({type='BUFF',unit='player',spell=24858}),negate({type='BUFF',unit='player',spell=102560}))),
  },
  rotation={
   block('balance-boundaries','retail.druid.boundaries','balance-'),
   {id='balance-assisted',type='assisted',conditions={}},
  },
 },
}))
