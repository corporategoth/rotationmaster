-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Warrior melee DPS, levels 1–60, Arms and Fury (the recommended vanilla DPS premade and
-- the catch-all for any warrior outside Defensive Stance; also Hardcore and Self-Found). simulator
-- order with Icy Veins' three-target area threshold and Wowhead's leveling gates: Charge to pull;
-- Intercept a distant target; Whirlwind (Thunder Clap before it) on three engaged enemies;
-- Execute first below 20%; Sunder to five on bosses with no Expose Armor; Bloodthirst; Mortal
-- Strike; Slam right after a two-hander swing with Improved Slam; Whirlwind while keeping rage for
-- the main strike; Overpower; Rend until the main strike is learned; Sunder on healthy targets;
-- Hamstring near the rage cap. Shared parts: era/blocks.lua. Left manual: stance dancing; the
-- Hardcore emergency buttons (Intimidating Shout, Retaliation) are listed off.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function sunders(op,n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return BuiltinConditions.all(BuiltinConditions.known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local strike=BuiltinConditions.any(BuiltinConditions.known(12294),BuiltinConditions.known(23881))
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
local immune=BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='MECHANICAL'},{type='CREATURE',unit='target',value='ELEMENTAL'})
local near={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warrior.dps',revision=5,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1,['era.warrior.aoe-strikes']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins','wowhead'},
 sources={
 {url='https://www.icy-veins.com/wow-classic/warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warrior DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/classic-warrior-leveling-guide',title='Icy Veins: Classic Warrior leveling guide',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/hardcore-warrior-class-overview',title='Icy Veins: Hardcore Warrior overview (emergency buttons)',reviewedAt='2026-10-23',revision='2023-05-14'},
 {url='https://www.wowhead.com/classic/guide/classes/warrior/fury/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Fury Warrior DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 {url='https://www.wowhead.com/classic/guide/classes/warrior/arms/leveling-tips',title='Wowhead: Classic Arms Warrior leveling tips',reviewedAt='2026-10-23',revision='2024-12-27'}},
 body={priority=10,
 cooldowns={block('era.warrior.upkeep','warrior-dps-'),
  BuiltinConditions.spell('warrior-dps-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),BuiltinConditions.any(rage('GREATERTHANOREQUALS',40),
   BuiltinConditions.all(target('LESSTHAN',.2),rage('GREATERTHANOREQUALS',30)),BuiltinConditions.all(BuiltinConditions.negate(strike),BuiltinConditions.negate(BuiltinConditions.known(1680)),rage('GREATERTHANOREQUALS',20))))),
  BuiltinConditions.spell('warrior-dps-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),BuiltinConditions.any(rage('GREATERTHANOREQUALS',40),target('LESSTHAN',.2)))),
  BuiltinConditions.spell('warrior-dps-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),rage('LESSTHAN',80),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  BuiltinConditions.spell('warrior-dps-sweeping-strikes',12292,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2))),
  BuiltinConditions.spell('warrior-dps-death-wish',12328,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(boss),target('LESSTHAN',.2),BuiltinConditions.lifetime('LESSTHANOREQUALS',30)))),
  BuiltinConditions.spell('warrior-dps-recklessness',1719,BuiltinConditions.all(BuiltinConditions.combat(),boss,BuiltinConditions.any({type='BUFF',unit='player',spell=12328},BuiltinConditions.lifetime('LESSTHANOREQUALS',15)))),
  optional(BuiltinConditions.spell('warrior-dps-intimidating-shout',5246,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3},near))),
  optional(BuiltinConditions.spell('warrior-dps-retaliation',20230,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4},
   {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3}))),
 },
 rotation={
 block('era.warrior.boundaries','warrior-dps-'),
 BuiltinConditions.spell('warrior-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 {id='warrior-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={block('era.warrior.aoe-strikes','warrior-dps-')}},
 BuiltinConditions.spell('warrior-dps-execute',5308,target('LESSTHAN',.2)),
 BuiltinConditions.spell('warrior-dps-boss-sunder',7386,BuiltinConditions.all(boss,BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),sunders('LESSTHAN',5)),
  BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8647,anyrank=true}))),
 BuiltinConditions.spell('warrior-dps-bloodthirst',23881),
 BuiltinConditions.spell('warrior-dps-mortal-strike',12294),
 BuiltinConditions.spell('warrior-dps-slam',1464,BuiltinConditions.all({type='TALENT',layout='tree',tree=2,talent=12,operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.negate({type='MOVING'}),
  {type='SWING_TIME_REMAIN',offhand=false,operator='GREATERTHANOREQUALS',value=2.5})),
 BuiltinConditions.spell('warrior-dps-whirlwind',1680,BuiltinConditions.any(BuiltinConditions.negate(strike),cooling(12294,1.5),cooling(23881,1.5),rage('GREATERTHANOREQUALS',55))),
 BuiltinConditions.spell('warrior-dps-overpower',7384),
 BuiltinConditions.spell('warrior-dps-rend',772,BuiltinConditions.all(BuiltinConditions.negate(strike),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}),target('GREATERTHAN',.3),BuiltinConditions.negate(immune))),
 BuiltinConditions.spell('warrior-dps-sunder',7386,BuiltinConditions.all(target('GREATERTHANOREQUALS',.6),rage('GREATERTHANOREQUALS',25),
  BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),sunders('LESSTHAN',5)))),
 BuiltinConditions.spell('warrior-dps-hamstring',1715,BuiltinConditions.all(rage('GREATERTHANOREQUALS',80),strike,BuiltinConditions.any(cooling(12294,0),cooling(23881,0)),
  BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(1680)),cooling(1680,0)))),
 }},
}))
