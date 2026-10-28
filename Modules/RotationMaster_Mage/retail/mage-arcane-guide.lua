-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Arcane Mage after SimulationCraft and Icy Veins (optimal reference): Arcane
-- Missiles on Clearcasting while Arcane Salvo is low, Arcane Barrage at four Arcane Charges with a
-- high Salvo or with Arcane Soul at any charge count, Prismatic Bolt, Arcane Orb below three
-- charges, Arcane Pulse on packs, Arcane Blast, and Arcane Barrage when Blast cannot be cast.
-- Spellslinger (Splintering Sorcery known) uses its own order: Barrage at 20 Salvo, with two or
-- more enemies only at four charges (SimulationCraft's aoe_count). Mana is secret on Retail, so the
-- low-mana Evocation is left to you. Disabled: Salvo and Clearcasting are secret in Midnight combat;
-- only the Arcane Charge tests stay readable.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function salvo(op,v)return{type='BUFF_STACKS',unit='player',spell=1242974,ownbuff=true,operator=op,value=v}end
local function charges(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function last(id)return{type='SPELL_HISTORY',spell=id,operator='EQUALS',value=1}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local clearcasting,soul,surge=buff(263725),buff(451038),buff(365362)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.arcane.guide',revision=8,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 nameKey='Default.Retail.Mage.ArcaneGuide.Name',descriptionKey='Default.Retail.Mage.ArcaneGuide.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'arcane','caster','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/arcane-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Arcane Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_arcane.simc',title='SimulationCraft default action list: Arcane',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={62},
  cooldowns={
   block('aguide-utility','retail.mage.utility','aguide-'),
   spell('aguide-barrier',235450,combat()),
   spell('aguide-arcane-surge',365350,combat()),
   spell('aguide-touch-of-the-magi',321507,all(combat(),any(last(44425),last(1295924)),any(surge,{type='SPELL_COOLDOWN',spell=365350,operator='GREATERTHAN',value=30}))),
   spell('aguide-presence-of-mind',205025,all(combat(),charges('EQUALS',0),last(44425))),
  },
  rotation={
   block('aguide-boundaries','retail.mage.boundaries','aguide-'),
   {id='aguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('aguide-pull-blast',30451),stop('aguide-pull-stop')}},
   {id='aguide-spellslinger',type='branch',conditions={type='SPELL_KNOWN',spell=443739},
    onTrue={
     spell('aguide-ss-prismatic-bolt',1295924),
     spell('aguide-ss-aoe-orb',153626,engaged(3)),
     spell('aguide-ss-barrage',44425,all(salvo('GREATERTHANOREQUALS',20),any(charges('GREATERTHANOREQUALS',4),negate(engaged(2))))),
     spell('aguide-ss-missiles',5143,all(clearcasting,salvo('LESSTHAN',15))),
     spell('aguide-ss-orb',153626,charges('LESSTHAN',3)),
     spell('aguide-ss-pulse',1241462,all(charges('LESSTHAN',3),negate(surge))),
     spell('aguide-ss-blast',30451)},
    onFalse={
     spell('aguide-sf-missiles',5143,all(clearcasting,salvo('LESSTHAN',12))),
     spell('aguide-sf-soulless-bolt',1295924,negate(soul)),
     spell('aguide-sf-barrage',44425,any(all(charges('GREATERTHANOREQUALS',4),any(all(salvo('GREATERTHANOREQUALS',12),clearcasting),salvo('GREATERTHANOREQUALS',25))),soul)),
     spell('aguide-sf-prismatic-bolt',1295924),
     spell('aguide-sf-orb',153626,charges('LESSTHAN',3)),
     spell('aguide-sf-pulse',1241462,any(engaged(3),charges('EQUALS',0))),
     spell('aguide-sf-blast',30451)}},
   spell('aguide-out-of-mana-barrage',44425),
  },
 },
}))
