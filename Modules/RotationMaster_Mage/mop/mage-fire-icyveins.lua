-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Fire Mage after Icy Veins, Method and wowtbc.gg, levels 10–90: hold
-- Pyroblast! until a Heating Up joins it, then cast both (Fireball, then the instant Pyroblast); spend
-- it alone only before it expires. Otherwise as rm.mop.mage.fire, the recommended Fire premade (same
-- switch, higher priority). Off by default.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local PYRO,HEAT,ALTER=48108,48107,110909
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.fire.icyveins',revision=7,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-molten']=1,['mop.mage.bombs']=1,['mop.mage.fire-open']=3,['mop.mage.fire-spend']=1,['mop.mage.fire-filler']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'fire','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/fire-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Fire Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.method.gg/mop-classic/fire-mage-class-guide-mop-classic',title='Method: MoP Classic Fire Mage guide',reviewedAt='2026-10-23',notes='Phase 1 text.'},
  {url='https://wowtbc.gg/mop/class-guides/fire-mage',title='wowtbc.gg: MoP Classic Fire Mage PvE guide',reviewedAt='2026-10-23'},
 },
 body={priority=25,disabled=true,specs={63},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('fireiv-armor','mop.mage.armor-molten','fireiv-'),
   BuiltinConditions.block('fireiv-upkeep','mop.mage.upkeep','fireiv-'),
   {id='fireiv-mana-gem',type='item',action={36799,81901},conditions=BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.84),BuiltinConditions.negate(BuiltinConditions.buff(ALTER)))},
   BuiltinConditions.spell('fireiv-presence-of-mind',12043,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.buff(ALTER)),BuiltinConditions.negate(BuiltinConditions.buff(PYRO)))),
   BuiltinConditions.spell('fireiv-alter-time',108978,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.buff(PYRO),BuiltinConditions.buff(HEAT),BuiltinConditions.negate(BuiltinConditions.buff(ALTER)))),
  },
  rotation={
   BuiltinConditions.block('fireiv-boundaries','mop.mage.boundaries','fireiv-'),
   BuiltinConditions.block('fireiv-open','mop.mage.fire-open','fireiv-'),
   BuiltinConditions.spell('fireiv-pyroblast',11366,BuiltinConditions.all(BuiltinConditions.buff(PYRO),BuiltinConditions.any(BuiltinConditions.buff(HEAT),{type='BUFF_REMAIN',unit='player',spell=PYRO,operator='LESSTHAN',value=3}))),
   BuiltinConditions.block('fireiv-bombs','mop.mage.bombs','fireiv-'),
   BuiltinConditions.block('fireiv-spend','mop.mage.fire-spend','fireiv-'),
   BuiltinConditions.block('fireiv-filler','mop.mage.fire-filler','fireiv-'),
  },
 },
}))
