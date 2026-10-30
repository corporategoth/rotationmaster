-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Rogue melee DPS, levels 1–70, simulator order (the recommended variant; Icy Veins agrees).
-- One premade for every spec: the builder follows what is known (Mutilate, Hemorrhage, Backstab,
-- Sinister Strike). Slice and Dice from two points and refreshed in its last two seconds; a
-- two-point Eviscerate on a target about to die; at five points Rupture when it is missing, Blade
-- Flurry is not cleaving and the target will outlive it, else Eviscerate; no builder at five.
-- The Wowhead variant spends every five points on Eviscerate instead. Shared parts:
-- Defaults/blocks/rogue.lua. Left manual: Expose Armor (a raid assignment), Kidney Shot, Feint,
-- Vanish, Sprint, Thistle Tea and positioning.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(n)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.rogue.dps.simulator',revision=6,
 blocks={['tbc.rogue.opening']=4,['tbc.rogue.upkeep']=2,['tbc.rogue.builders']=3},
 applicability={families={'tbc'},actionContext='player',class='ROGUE'},
 tags={'dps','melee','leveling','endgame','icy-veins'},
 sources={
 {url='https://www.icy-veins.com/tbc-classic/rogue-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: TBC Rogue DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/combat-rogue-leveling-guide',title='Icy Veins: Combat Rogue leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://warcrafttavern.com/tbc/guides/pve-subtlety-rogue-rotation-cooldowns-abilities/',title='Warcraft Tavern: Subtlety Rogue PvE rotation (stealth openers)',reviewedAt='2026-10-23'}},
 body={priority=10,
 cooldowns={block('tbc.rogue.upkeep','rogue-')},
 rotation={
 block('tbc.rogue.opening','rogue-'),
 BuiltinConditions.spell('rogue-slice',5171,BuiltinConditions.all(points(2),BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),
  {type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=2}))),
 BuiltinConditions.spell('rogue-kill-shot',2098,BuiltinConditions.all(points(2),BuiltinConditions.lifetime('LESSTHAN',4))),
 {id='rogue-finisher',type='branch',conditions=points(5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-rupture',1943,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1943,anyrank=true,owndebuff=true}),
   BuiltinConditions.negate({type='BUFF',unit='player',spell=13877,anyrank=true,ownbuff=true}),BuiltinConditions.lifetime('GREATERTHAN',16))),
  BuiltinConditions.spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('tbc.rogue.builders','rogue-'),
 }},
}))
