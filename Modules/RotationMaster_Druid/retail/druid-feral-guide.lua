-- Retail (Midnight 12.x) Feral Druid after Icy Veins and SimulationCraft (optimal reference): Cat
-- Form, Prowl and Rake to open; Chomp; Ferocious Bite on Apex Predator's Craving; at five combo
-- points Primal Wrath on two or more enemies, Rip when missing or in its last 7 seconds, else
-- Ferocious Bite (and nothing else until a finisher is affordable); below five, Rake when missing or
-- in its last 4.5 seconds, Lunar Inspiration Moonfire, Swipe on three or more, Shred. Disabled:
-- bleeds and procs are secret in Midnight combat (combo points stay readable); energy is secret on
-- Retail, so Tiger's Fury is a reminder whenever it is ready in combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function refresh(id,remain)return any(negate({type='DEBUFF',unit='target',spell=id,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=remain})end
local fury=buff(5217)
local berserk=any(buff(106951),buff(102543))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.feral.guide',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.FeralGuide.Name',descriptionKey='Default.Retail.Druid.FeralGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'feral','melee','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/feral-druid-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Feral Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_feral.simc',title='SimulationCraft default action list: Feral',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={103},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('feguide-utility','retail.druid.utility','feguide-'),
   spell('feguide-skull-bash',106839,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   spell('feguide-survival-instincts',61336,combat()),
   spell('feguide-tigers-fury',5217,combat()),
   spell('feguide-berserk',106951,fury),
   spell('feguide-incarnation',102543,fury),
   spell('feguide-feral-frenzy',274837,all(fury,points('LESSTHANOREQUALS',2))),
   spell('feguide-frantic-frenzy',1243807,all(fury,points('LESSTHANOREQUALS',2))),
   spell('feguide-convoke',391528,all(fury,berserk,{type='DEBUFF',unit='target',spell=1079,owndebuff=true})),
  },
  rotation={
   block('feguide-boundaries','retail.druid.boundaries','feguide-'),
   {id='feguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('feguide-pull-cat-form',768,all(negate(buff(768)),negate(buff(102543)))),
    spell('feguide-pull-prowl',5215,negate({type='STEALTHED'})),
    spell('feguide-pull-rake',1822),
    stop('feguide-pull-stop')}},
   spell('feguide-chomp',1244258),
   spell('feguide-apex-bite',22568,buff(391882)),
   {id='feguide-finish',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
    spell('feguide-primal-wrath',285381,engaged(2)),
    spell('feguide-rip',1079,refresh(1079,7)),
    spell('feguide-bite',22568),
    stop('feguide-pool')}},
   spell('feguide-rake',1822,refresh(155722,4.5)),
   spell('feguide-moonfire',155625,negate({type='DEBUFF',unit='target',spell=155625,owndebuff=true})),
   spell('feguide-swipe',213764,engaged(3)),
   spell('feguide-shred',5221),
  },
 },
}))
