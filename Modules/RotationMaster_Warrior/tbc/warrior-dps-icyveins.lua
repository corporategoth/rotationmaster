-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior melee DPS, levels 1–70, Icy Veins order (alternative DPS variant).
-- Differs from the simulator variant only where Icy Veins differs: Arms (Mortal Strike known) puts
-- Execute first, Fury keeps Bloodthirst above Execute, Whirlwind follows without a rage reserve,
-- and spare rage goes to Hamstring near the cap instead of a Sunder filler.
-- Everything both variants agree on is a shared block (Defaults/blocks/warrior.lua).
-- Left manual: the 2H Slam-after-swing loop, stance dancing, Berserker Rage and consumables.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local execute=function(id)return BuiltinConditions.spell(id,5308,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.dps.icyveins',revision=6,
 blocks={['tbc.warrior.boundaries']=4,['tbc.warrior.upkeep']=1,['tbc.warrior.dps-upkeep']=1,['tbc.warrior.dps-opening']=1,['tbc.warrior.dps-leveling']=1},
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/fury-warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Fury Warrior PvE rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Arms Warrior PvE rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/fury-warrior-leveling-guide',title='Icy Veins: Fury Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=5,disabled=true,
 cooldowns={block('tbc.warrior.upkeep','warrior-dps-'),block('tbc.warrior.dps-upkeep','warrior-dps-')},
 rotation={
 block('tbc.warrior.boundaries','warrior-dps-'),
 block('tbc.warrior.dps-opening','warrior-dps-'),
 {id='warrior-dps-kit',type='branch',conditions={type='OR',value={BuiltinConditions.known(23881),BuiltinConditions.known(12294)}},onTrue={
  {id='warrior-dps-arms',type='branch',conditions=BuiltinConditions.known(12294),onTrue={
   execute('warrior-dps-arms-execute'),
   BuiltinConditions.spell('warrior-dps-mortal-strike',12294),
  },onFalse={
   BuiltinConditions.spell('warrior-dps-bloodthirst',23881),
   execute('warrior-dps-fury-execute'),
  }},
  BuiltinConditions.spell('warrior-dps-whirlwind-after',1680),
 },onFalse={block('tbc.warrior.dps-leveling','warrior-dps-leveling-')}},
 BuiltinConditions.spell('warrior-dps-hamstring',1715,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=90}),
 }},
}))
