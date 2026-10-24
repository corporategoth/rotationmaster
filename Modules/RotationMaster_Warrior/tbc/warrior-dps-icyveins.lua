-- TBC Warrior melee DPS, levels 1–70, Icy Veins order (alternative DPS variant).
-- Differs from the wowsims variant only where Icy Veins differs: Arms (Mortal Strike known) puts
-- Execute first, Fury keeps Bloodthirst above Execute, Whirlwind follows without a rage reserve,
-- and spare rage goes to Hamstring near the cap instead of a Sunder filler.
-- Everything both variants agree on is a shared block (Defaults/blocks/warrior.lua).
-- Left manual: the 2H Slam-after-swing loop, stance dancing, Berserker Rage and consumables.
local _,addon=...
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local execute=function(id)return spell(id,5308,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.dps.icyveins',revision=4,
 blocks={['tbc.warrior.boundaries']=3,['tbc.warrior.upkeep']=1,['tbc.warrior.dps-upkeep']=1,['tbc.warrior.dps-opening']=1,['tbc.warrior.dps-leveling']=1},
 nameKey='Default.TBC.Warrior.DPS.IcyVeins.Name',descriptionKey='Default.TBC.Warrior.DPS.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/fury-warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Fury Warrior PvE rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Arms Warrior PvE rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/fury-warrior-leveling-guide',title='Icy Veins: Fury Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('tbc.warrior.upkeep','warrior-dps-'),block('tbc.warrior.dps-upkeep','warrior-dps-')},
 rotation={
 block('tbc.warrior.boundaries','warrior-dps-'),
 block('tbc.warrior.dps-opening','warrior-dps-'),
 {id='warrior-dps-kit',type='branch',conditions={type='OR',value={known(23881),known(12294)}},onTrue={
  {id='warrior-dps-arms',type='branch',conditions=known(12294),onTrue={
   execute('warrior-dps-arms-execute'),
   spell('warrior-dps-mortal-strike',12294),
  },onFalse={
   spell('warrior-dps-bloodthirst',23881),
   execute('warrior-dps-fury-execute'),
  }},
  spell('warrior-dps-whirlwind-after',1680),
 },onFalse={block('tbc.warrior.dps-leveling','warrior-dps-leveling-')}},
 spell('warrior-dps-hamstring',1715,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=90}),
 }},
}))
