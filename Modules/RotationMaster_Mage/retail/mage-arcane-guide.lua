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
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function salvo(op,v)return{type='BUFF_STACKS',unit='player',spell=1242974,ownbuff=true,operator=op,value=v}end
local function charges(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function last(id)return{type='SPELL_HISTORY',spell=id,operator='EQUALS',value=1}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local clearcasting,soul,surge=buff(263725),buff(451038),buff(365362)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.arcane.guide',revision=8,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'arcane','caster','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/arcane-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Arcane Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_arcane.simc',title='SimulationCraft default action list: Arcane',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={62},
  cooldowns={
   BuiltinConditions.block('aguide-utility','retail.mage.utility','aguide-'),
   BuiltinConditions.spell('aguide-barrier',235450,BuiltinConditions.combat()),
   BuiltinConditions.spell('aguide-arcane-surge',365350,BuiltinConditions.combat()),
   BuiltinConditions.spell('aguide-touch-of-the-magi',321507,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(last(44425),last(1295924)),BuiltinConditions.any(surge,{type='SPELL_COOLDOWN',spell=365350,operator='GREATERTHAN',value=30}))),
   BuiltinConditions.spell('aguide-presence-of-mind',205025,BuiltinConditions.all(BuiltinConditions.combat(),charges('EQUALS',0),last(44425))),
  },
  rotation={
   BuiltinConditions.block('aguide-boundaries','retail.mage.boundaries','aguide-'),
   {id='aguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('aguide-pull-blast',30451),BuiltinConditions.stop('aguide-pull-stop')}},
   {id='aguide-spellslinger',type='branch',conditions={type='SPELL_KNOWN',spell=443739},
    onTrue={
     BuiltinConditions.spell('aguide-ss-prismatic-bolt',1295924),
     BuiltinConditions.spell('aguide-ss-aoe-orb',153626,engaged(3)),
     BuiltinConditions.spell('aguide-ss-barrage',44425,BuiltinConditions.all(salvo('GREATERTHANOREQUALS',20),BuiltinConditions.any(charges('GREATERTHANOREQUALS',4),BuiltinConditions.negate(engaged(2))))),
     BuiltinConditions.spell('aguide-ss-missiles',5143,BuiltinConditions.all(clearcasting,salvo('LESSTHAN',15))),
     BuiltinConditions.spell('aguide-ss-orb',153626,charges('LESSTHAN',3)),
     BuiltinConditions.spell('aguide-ss-pulse',1241462,BuiltinConditions.all(charges('LESSTHAN',3),BuiltinConditions.negate(surge))),
     BuiltinConditions.spell('aguide-ss-blast',30451)},
    onFalse={
     BuiltinConditions.spell('aguide-sf-missiles',5143,BuiltinConditions.all(clearcasting,salvo('LESSTHAN',12))),
     BuiltinConditions.spell('aguide-sf-soulless-bolt',1295924,BuiltinConditions.negate(soul)),
     BuiltinConditions.spell('aguide-sf-barrage',44425,BuiltinConditions.any(BuiltinConditions.all(charges('GREATERTHANOREQUALS',4),BuiltinConditions.any(BuiltinConditions.all(salvo('GREATERTHANOREQUALS',12),clearcasting),salvo('GREATERTHANOREQUALS',25))),soul)),
     BuiltinConditions.spell('aguide-sf-prismatic-bolt',1295924),
     BuiltinConditions.spell('aguide-sf-orb',153626,charges('LESSTHAN',3)),
     BuiltinConditions.spell('aguide-sf-pulse',1241462,BuiltinConditions.any(engaged(3),charges('EQUALS',0))),
     BuiltinConditions.spell('aguide-sf-blast',30451)}},
   BuiltinConditions.spell('aguide-out-of-mana-barrage',44425),
  },
 },
}))
