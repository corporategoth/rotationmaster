-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior melee DPS, levels 1–70, simulator/Wowhead order (the recommended DPS variant).
-- Arms and Fury share one priority: talents decide Mortal Strike vs Bloodthirst by spell known.
-- Execute is a filler after Bloodthirst/Mortal Strike/Whirlwind, as simulator measured and Wowhead
-- says TBC changed; the Icy Veins variant keeps Execute first. Boundaries, reminders, the
-- multi-target arm, the pre-talent leveling arm and Sunder are shared blocks (Defaults/blocks/warrior.lua).
-- Left manual: the 2H Slam-after-swing loop (no time-since-swing condition), stance dancing,
-- Berserker Rage, raid Sunder assignment, consumables and pulls other than Charge.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.dps.simulator',revision=5,
 blocks={['tbc.warrior.boundaries']=4,['tbc.warrior.upkeep']=1,['tbc.warrior.dps-upkeep']=1,['tbc.warrior.dps-opening']=1,['tbc.warrior.dps-leveling']=1,['tbc.warrior.sunder']=1},
 nameKey="Melee DPS (simulator)",descriptionKey="Levels 1–70, Arms or Fury. Charges to pull, then Victory Rush, Intercept, Rampage, and Whirlwind when two or more enemies fight you (Thunder Clap before it is learned). With Bloodthirst or Mortal Strike: that strike, Whirlwind with rage to spare, Execute, Overpower. Before them: Whirlwind, Execute, Overpower, Rend. Spare rage goes to Devastate or Sunder Armor, then Hamstring. Reminds you of Battle Shout, Bloodrage, Heroic Strike or Cleave as rage dumps, Sweeping Strikes, Death Wish, Recklessness and interrupts. Slam timing, stance dancing and Berserker Rage stay with you.",
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','wowhead'},
 sources={
 {url='https://www.wowhead.com/tbc/guide/classes/warrior/dps-rotation-cooldowns-abilities-pve',title='Wowhead: TBC Warrior DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-06-11'},
 {url='https://www.wowhead.com/tbc/guide/classes/warrior/leveling-tips',title='Wowhead: TBC Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-17'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling (shared pre-talent arm)',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=10,
 cooldowns={block('tbc.warrior.upkeep','warrior-dps-'),block('tbc.warrior.dps-upkeep','warrior-dps-')},
 rotation={
 block('tbc.warrior.boundaries','warrior-dps-'),
 block('tbc.warrior.dps-opening','warrior-dps-'),
 {id='warrior-dps-kit',type='branch',conditions={type='OR',value={known(23881),known(12294)}},onTrue={
  spell('warrior-dps-bloodthirst',23881),
  spell('warrior-dps-mortal-strike',12294),
  spell('warrior-dps-whirlwind-spare',1680,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=55}),
  spell('warrior-dps-execute',5308,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),
  spell('warrior-dps-overpower',7384),
 },onFalse={block('tbc.warrior.dps-leveling','warrior-dps-leveling-')}},
 {id='warrior-dps-spare-rage',type='branch',conditions={type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=50},onFalse={},onTrue={
  block('tbc.warrior.sunder','warrior-dps-filler-'),
 }},
 spell('warrior-dps-hamstring',1715,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=75}),
 }},
}))
