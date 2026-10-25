-- Retail (Midnight 12.x) Guardian Druid after SimulationCraft (defensive reference): Ironfur first in
-- Berserk; Thrash kept refreshed and stacked; Maul on Gory Fur; Thrash on packs; Mangle while Red Moon
-- ticks; Red Moon; Mangle; Thrash; Moonfire; Swipe. Rage is secret on Retail, so its rage thresholds
-- (Ironfur at 40, Maul at 90) are left out. Disabled: secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian.simc',revision=5,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.GuardianSimc.Name',descriptionKey='Default.Retail.Druid.GuardianSimc.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'guardian','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_guardian.simc',title='SimulationCraft default action list: Guardian',reviewedAt='2026-10-23',revision='c5fea93f',notes='Heart of the Wild and Feline Potential cat-weaving sub-lists left out.'},
 },
 body={priority=5,disabled=true,specs={104},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('gsimc-utility','retail.druid.utility','gsimc-'),
   spell('gsimc-bear-form',5487,all(negate(combat()),negate(buff(5487)),negate(buff(102558)))),
   spell('gsimc-skull-bash',106839,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   spell('gsimc-frenzied-regeneration',22842,combat()),
   spell('gsimc-survival-instincts',61336,combat()),
   spell('gsimc-berserk',50334,combat()),
   spell('gsimc-incarnation',102558,combat()),
   spell('gsimc-lunar-beam',204066,combat()),
   spell('gsimc-convoke',391528,combat()),
  },
  rotation={
   block('gsimc-boundaries','retail.druid.boundaries','gsimc-'),
   spell('gsimc-ironfur',192081,any(buff(50334),buff(102558))),
   spell('gsimc-thrash-refresh',77758,any(negate(debuff(192090)),{type='DEBUFF_REMAIN',unit='target',spell=192090,owndebuff=true,operator='LESSTHAN',value=4.5},{type='DEBUFF_STACKS',unit='target',spell=192090,owndebuff=true,operator='LESSTHAN',value=3})),
   spell('gsimc-gory-maul',6807,buff(1307881)),
   spell('gsimc-thrash-aoe',77758,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   spell('gsimc-red-moon-mangle',33917,debuff(1252871)),
   spell('gsimc-red-moon',1252871,negate(debuff(1252871))),
   spell('gsimc-mangle',33917),
   spell('gsimc-thrash',77758),
   spell('gsimc-moonfire',8921),
   spell('gsimc-swipe',213771),
  },
 },
}))
