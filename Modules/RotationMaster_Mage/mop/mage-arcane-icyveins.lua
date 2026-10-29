-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Arcane Mage after the guides (Icy Veins, Wowhead, Method, wowtbc.gg),
-- levels 10–90: the same Arcane Blast build, but at four charges Missiles on a proc and otherwise
-- Arcane Barrage, whatever the mana. Off by default; the recommended Arcane premade is
-- rm.mop.mage.arcane (same switch, higher priority).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function charges(v)return{type='DEBUFF_STACKS',unit='player',spell=36032,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local MISSILES=79683
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.arcane.icyveins',revision=7,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-frost']=1,['mop.mage.bombs']=1,['mop.mage.arcane-open']=3,['mop.mage.arcane-aoe-moving']=2},
 nameKey="Barrage at four charges (Icy Veins)",descriptionKey="The guides' Arcane rule (Icy Veins, Wowhead, Method, wowtbc.gg), an alternative to the recommended Arcane premade: at four Arcane Charges, Arcane Missiles if a proc is up, otherwise Arcane Barrage, whatever your mana; Missiles only at four charges. Everything else (Alter Time, bombs, AoE, moving, reminders) matches the recommended one, except that Arcane Power is suggested at four charges without waiting for a proc. Off by default: enable it and disable the recommended Arcane premade, or raise its priority.",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'arcane','leveling','single-target','aoe','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/arcane-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Arcane Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/arcane/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Arcane Mage rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.method.gg/mop-classic/arcane-mage-class-guide-mop-classic',title='Method: MoP Classic Arcane Mage guide',reviewedAt='2026-10-23',notes='Phase 1 text; Missiles only at four charges.'},
  {url='https://wowtbc.gg/mop/class-guides/arcane-mage',title='wowtbc.gg: MoP Classic Arcane Mage PvE guide',reviewedAt='2026-10-23'},
 },
 body={priority=25,disabled=true,specs={62},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('arcaneiv-armor','mop.mage.armor-frost','arcaneiv-'),
   block('arcaneiv-upkeep','mop.mage.upkeep','arcaneiv-'),
   {id='arcaneiv-mana-gem',type='item',action={36799,81901},conditions=all(combat(),mana('LESSTHAN',.84),charges(2))},
   spell('arcaneiv-arcane-power',12042,all(combat(),charges(4))),
   spell('arcaneiv-alter-time',108978,all(combat(),charges(4),buff(12042),negate(buff(110909)))),
  },
  rotation={
   block('arcaneiv-boundaries','mop.mage.boundaries','arcaneiv-'),
   block('arcaneiv-open','mop.mage.arcane-open','arcaneiv-'),
   block('arcaneiv-aoe-moving','mop.mage.arcane-aoe-moving','arcaneiv-'),
   spell('arcaneiv-missiles',5143,all(charges(4),buff(MISSILES))),
   spell('arcaneiv-barrage',44425,all(charges(4),negate({type='BUFF_STACKS',unit='player',spell=145252,operator='GREATERTHANOREQUALS',value=2}))),
   spell('arcaneiv-blast',30451),
  },
 },
}))
