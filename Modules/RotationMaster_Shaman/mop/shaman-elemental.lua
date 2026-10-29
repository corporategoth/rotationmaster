-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Elemental Shaman, levels 10-90: Wowhead's Phase 5 order (Icy Veins agrees once
-- its talent steps are removed), with simulator' Flame Shock gate on Earth Shock and its Flame Shock refresh
-- before Ascendance. Selected in the Elemental specialization (262)
-- from level 10 (RM stores MoP rotations per talent group). Out of combat a Lightning Bolt (Lava Burst with Unleashed
-- Fury) opens. Four or more engaged enemies: Magma in melee, free Lava Burst on Lava Surge, Lava Beam in
-- Ascendance, Chain Lightning. On the move: instants only. Otherwise Unleash Elements with Unleashed Fury,
-- Flame Shock when missing or under 3 s, Lava Burst into Flame Shock, Elemental Blast, Earth Shock at six
-- Lightning Shield charges with 6 s of Flame Shock left, Chain Lightning on two, Lightning Bolt. Earthquake
-- ships off. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function shock(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator=op,value=n}end
local function talent(i)return{type='TALENT',layout='grid',value=i}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
local ascended=BuiltinConditions.ownBuff(114050)
-- Flame Shock when missing or about to tick out on a target that will live, or topped up just before Ascendance.
local refresh=BuiltinConditions.any(BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(flame),shock('LESSTHAN',3)),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6})),
 BuiltinConditions.all(shock('LESSTHAN',16),{type='SPELL_KNOWN',spell=114049},{type='SPELL_COOLDOWN',spell=114049,operator='LESSTHAN',value=2}))
local lava=BuiltinConditions.any(shock('GREATERTHAN',2),BuiltinConditions.ownBuff(77762),ascended)
local fulminate=BuiltinConditions.all({type='BUFF_STACKS',unit='player',spell=324,ownbuff=true,operator='GREATERTHANOREQUALS',value=6},shock('GREATERTHANOREQUALS',6))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.elemental',revision=7,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'elemental','dps','caster','ranged','leveling','endgame','wowhead','icy-veins'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/shaman/elemental/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Elemental Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/elemental-shaman-pve-rotation-cooldowns-abilities',title='Icy Veins: Elemental Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-22'},

 {url='https://www.warcrafttavern.com/mop/guides/pve-elemental-shaman-rotation-cooldowns/',title='Warcraft Tavern: Elemental Shaman rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/elemental-shaman/',title='wowtbc.gg: Elemental Shaman (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=30,specs={262},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.lightning-shield','shaman-ele-'),
  BuiltinConditions.spell('shaman-ele-flametongue',8024,BuiltinConditions.negate({type='WEAPON_IMBUE',enchant=5})),
  block('mop.shaman.fire-totems','shaman-ele-'),
  BuiltinConditions.spell('shaman-ele-elemental-mastery',16166,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_KNOWN',spell=114049}),
   {type='SPELL_COOLDOWN',spell=114049,operator='LESSTHAN',value=4},{type='SPELL_COOLDOWN',spell=114049,operator='GREATERTHAN',value=85}))),
  BuiltinConditions.spell('shaman-ele-ascendance',114049,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(ascended),shock('GREATERTHAN',15),BuiltinConditions.negate({type='SPELL_AVAIL',spell=51505}))),
  BuiltinConditions.spell('shaman-ele-ancestral-swiftness',16188,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(ascended))),
  block('mop.shaman.group','shaman-ele-'),
  BuiltinConditions.spell('shaman-ele-thunderstorm',51490,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.15})),
  BuiltinConditions.spell('shaman-ele-shamanistic-rage',30823,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-ele-'),
 {id='shaman-ele-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('shaman-ele-pull-lava',51505,talent(16)),
  BuiltinConditions.spell('shaman-ele-pull-bolt',403),
  {id='shaman-ele-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-ele-aoe',type='branch',conditions=enemies(4),onFalse={},onTrue={
  BuiltinConditions.spell('shaman-ele-magma',8190,BuiltinConditions.all(BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=2894}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=8190}))),
  {id='shaman-ele-earthquake',type='spell',action=61882,ranked=false,disabled=true,conditions=enemies(5)},
  BuiltinConditions.spell('shaman-ele-aoe-surge',51505,BuiltinConditions.ownBuff(77762)),
  BuiltinConditions.spell('shaman-ele-lava-beam',114074,ascended),
  BuiltinConditions.spell('shaman-ele-aoe-chain',421),
  {id='shaman-ele-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-ele-moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(BuiltinConditions.ownBuff(79206))),onFalse={},onTrue={
  BuiltinConditions.spell('shaman-ele-moving-unleash',73680,talent(16)),
  BuiltinConditions.spell('shaman-ele-moving-flame-shock',8050,refresh),
  BuiltinConditions.spell('shaman-ele-moving-lava',51505,BuiltinConditions.any(BuiltinConditions.ownBuff(77762),ascended)),
  BuiltinConditions.spell('shaman-ele-moving-earth-shock',8042,{type='BUFF_STACKS',unit='player',spell=324,ownbuff=true,operator='GREATERTHANOREQUALS',value=6}),
  BuiltinConditions.spell('shaman-ele-moving-bolt',403),
  {id='shaman-ele-moving-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('shaman-ele-unleash',73680,BuiltinConditions.all(talent(16),BuiltinConditions.negate(ascended))),
 BuiltinConditions.spell('shaman-ele-flame-shock',8050,refresh),
 BuiltinConditions.spell('shaman-ele-lava-burst',51505,lava),
 BuiltinConditions.spell('shaman-ele-elemental-blast',117014),
 BuiltinConditions.spell('shaman-ele-earth-shock',8042,fulminate),
 BuiltinConditions.spell('shaman-ele-chain',421,enemies(2)),
 BuiltinConditions.spell('shaman-ele-bolt',403),
 }},
}))
