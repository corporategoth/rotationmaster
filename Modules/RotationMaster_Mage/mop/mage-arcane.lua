-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Arcane Mage, levels 10–90, in the Arcane specialization
-- (62). simulator' measured list (Hekili matches it): Arcane Blast builds four Arcane
-- Charges; with four, a single Arcane Missiles! proc is spent above 95% mana and Barrage comes out
-- below 90%, so between 90% and 95% it keeps blasting. Arcane Power and Alter Time at four charges
-- with a proc, Missiles never left at two procs, Barrage every four charges with two or more enemies.
-- The guides' rule (Barrage at four charges without a proc, no mana gate) is rm.mop.mage.arcane.icyveins.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function charges(v)return{type='DEBUFF_STACKS',unit='player',spell=36032,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function procs(v)return{type='BUFF_STACKS',unit='player',spell=79683,operator='EQUALS',value=v}end
local function ending()return{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=25}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local MISSILES=79683
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.arcane',revision=7,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-frost']=1,['mop.mage.bombs']=1,['mop.mage.arcane-open']=3,['mop.mage.arcane-aoe-moving']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'arcane','leveling','single-target','aoe','hekili'},
 sources={

  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/MageArcane.simc',title='Hekili (MoP Classic fork): Arcane Mage priority',reviewedAt='2026-10-23',revision='0750b5dd98'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/arcane-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Arcane Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Bomb upkeep, AoE and Alter Time handling, talent rows.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/arcane/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Arcane Mage rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20',notes='Barrage every four charges in cleave; Frost Armor.'},
 },
 body={priority=30,specs={62},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('arcane-armor','mop.mage.armor-frost','arcane-'),
   BuiltinConditions.block('arcane-upkeep','mop.mage.upkeep','arcane-'),
   {id='arcane-mana-gem',type='item',action={36799,81901},conditions=BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.84),charges(2))},
   BuiltinConditions.spell('arcane-power',12042,BuiltinConditions.all(BuiltinConditions.combat(),charges(4),BuiltinConditions.buff(MISSILES))),
   BuiltinConditions.spell('arcane-alter-time',108978,BuiltinConditions.all(BuiltinConditions.combat(),charges(4),BuiltinConditions.buff(MISSILES),BuiltinConditions.buff(12042),BuiltinConditions.negate(BuiltinConditions.buff(110909)),{type='TIME_IN_COMBAT',operator='GREATERTHANOREQUALS',value=10})),
   off('arcane-presence-of-mind',12043,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.buff(110909)))),
  },
  rotation={
   BuiltinConditions.block('arcane-boundaries','mop.mage.boundaries','arcane-'),
   BuiltinConditions.block('arcane-open','mop.mage.arcane-open','arcane-'),
   BuiltinConditions.spell('arcane-missiles-capped',5143,procs(2)),
   BuiltinConditions.block('arcane-aoe-moving','mop.mage.arcane-aoe-moving','arcane-'),
   BuiltinConditions.spell('arcane-end-missiles',5143,BuiltinConditions.all(BuiltinConditions.buff(MISSILES),ending())),
   BuiltinConditions.spell('arcane-end-blast',30451,ending()),
   BuiltinConditions.spell('arcane-blast-proc-high',30451,BuiltinConditions.all(charges(4),procs(1),mana('GREATERTHANOREQUALS',.95))),
   BuiltinConditions.spell('arcane-missiles',5143,BuiltinConditions.all(charges(4),BuiltinConditions.buff(MISSILES))),
   BuiltinConditions.spell('arcane-blast-high',30451,BuiltinConditions.all(charges(4),BuiltinConditions.negate(BuiltinConditions.buff(MISSILES)),mana('GREATERTHANOREQUALS',.95))),
   BuiltinConditions.spell('arcane-barrage',44425,BuiltinConditions.all(charges(4),BuiltinConditions.negate(BuiltinConditions.buff(MISSILES)),mana('LESSTHAN',.9))),
   BuiltinConditions.spell('arcane-blast',30451),
  },
 },
}))
