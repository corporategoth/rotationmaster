-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Subtlety Rogue with Subterfuge (Warcraft Tavern): selected instead of the recommended
-- Subtlety premade when the tier-1 talent is Subterfuge (grid TALENT 2), which RM can read. Premeditation and Slice and
-- Dice before the pull; in Stealth, Shadow Dance or the Subterfuge linger: finishers at five points, then Ambush as
-- often as it lands. Two or three engaged enemies keep Rupture up and spend five points on Crimson Tempest instead of
-- Eviscerate; four or more add Fan of Knives. One target: Slice and Dice, Rupture, Eviscerate, Hemorrhage for its
-- bleed, Backstab with a dagger when the target is not on you, else Hemorrhage. Shadow Dance and Vanish are reminders with Slice and
-- Dice up and 60 energy (Tavern times them to trinket procs, which RM cannot generalise). Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=BuiltinConditions.ownBuff(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local hidden={type='STEALTHED'}
local worth=BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',8))
local ruptureDue=BuiltinConditions.any(BuiltinConditions.negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.subtlety.warcrafttavern',revision=7,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.subtlety-builders']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'subtlety','dps','melee','leveling','endgame','subterfuge','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-subtlety-rogue-dps-rotations-cooldowns/',title='Warcraft Tavern: Subtlety Rogue rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-subtlety-rogue-dps-talents-builds-glyphs/',title='Warcraft Tavern: Subtlety Rogue talents (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=35,specs={261},switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=15},{type='TALENT',layout='grid',value=2}}},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  BuiltinConditions.spell('rogue-subtlety-wt-shadow-dance',51713,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),sliced,energy('GREATERTHANOREQUALS',60))),
  BuiltinConditions.spell('rogue-subtlety-wt-vanish',1856,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),BuiltinConditions.negate(BuiltinConditions.ownBuff(51713)),BuiltinConditions.negate(BuiltinConditions.ownBuff(115192)),sliced,energy('GREATERTHANOREQUALS',60))),
  BuiltinConditions.spell('rogue-subtlety-wt-preparation',14185,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
  BuiltinConditions.spell('rogue-subtlety-wt-shadow-blades',121471,BuiltinConditions.all(BuiltinConditions.combat(),sliced,BuiltinConditions.negate(BuiltinConditions.ownBuff(51713)),BuiltinConditions.negate(hidden))),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 {id='rogue-subtlety-wt-window',type='branch',conditions=BuiltinConditions.any(hidden,BuiltinConditions.ownBuff(51713),BuiltinConditions.ownBuff(115192)),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-wt-premeditation',14183,points('LESSTHANOREQUALS',3)),
  BuiltinConditions.spell('rogue-subtlety-wt-prepull-slice',5171,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
  {id='rogue-subtlety-wt-window-finisher',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.combat(),points('GREATERTHANOREQUALS',5)),onFalse={},onTrue={
   BuiltinConditions.spell('rogue-subtlety-wt-window-slice',5171,BuiltinConditions.any(BuiltinConditions.negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('rogue-subtlety-wt-window-rupture',1943,ruptureDue),
   BuiltinConditions.spell('rogue-subtlety-wt-window-eviscerate',2098),
  }},
  BuiltinConditions.spell('rogue-subtlety-wt-ambush',8676),
  {id='rogue-subtlety-wt-window-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-subtlety-wt-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-wt-aoe-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.any(BuiltinConditions.negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2)))),
  BuiltinConditions.spell('rogue-subtlety-wt-aoe-rupture',1943,BuiltinConditions.all(points('GREATERTHANOREQUALS',5),BuiltinConditions.negate(mine(1943)),worth)),
  BuiltinConditions.spell('rogue-subtlety-wt-crimson-tempest',121411,points('GREATERTHANOREQUALS',5)),
  BuiltinConditions.spell('rogue-subtlety-wt-fan',51723,enemies('GREATERTHANOREQUALS',4)),
  {id='rogue-subtlety-wt-aoe-stop',type='stop',suppress_attack=false,conditions=enemies('GREATERTHANOREQUALS',4)},
 }},
 BuiltinConditions.spell('rogue-subtlety-wt-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-subtlety-wt-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-wt-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  BuiltinConditions.spell('rogue-subtlety-wt-rupture',1943,BuiltinConditions.all(ruptureDue,worth)),
  BuiltinConditions.spell('rogue-subtlety-wt-eviscerate',2098),
  {id='rogue-subtlety-wt-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-subtlety-wt-dying',2098,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',4))),
 block('mop.rogue.subtlety-builders','rogue-'),
 BuiltinConditions.spell('rogue-subtlety-wt-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
