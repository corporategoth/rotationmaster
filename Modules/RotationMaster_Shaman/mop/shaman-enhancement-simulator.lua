-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Enhancement Shaman, simulator "weave everything" variant (player-chosen, off by
-- default): the simulator's P3 Default list. Same switch as the recommended premade (Enhancement specialization). Spends any
-- Maelstrom Weapon stack on Lightning Bolt, Elemental Blast or Chain Lightning whenever the cast finishes before
-- the next main-hand swing (about 2.0 s at one stack down to 0.5 s at four; five is instant); Unleash Elements
-- also whenever Flame Shock is missing; Earth Shock only below two stacks. For players who swing-time their
-- casts. Shared parts: mop/blocks.lua (the pack arm is the recommended premade's).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=53817,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function swing(n)return{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=n}end
local function shock(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
-- The cast finishes before the next swing: an unhasted 2.5 s cast less 20% per Maelstrom Weapon stack.
local fits=BuiltinConditions.any(maelstrom(5),BuiltinConditions.all(maelstrom(4),swing(.5)),BuiltinConditions.all(maelstrom(3),swing(1)),BuiltinConditions.all(maelstrom(2),swing(1.5)),BuiltinConditions.all(maelstrom(1),swing(2)))
local unleashed=BuiltinConditions.ownBuff(73683)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.enhancement.simulator',revision=7,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1,
  ['mop.shaman.enhancement-upkeep']=2,['mop.shaman.enhancement-aoe']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'enhancement','dps','melee','endgame','wowtbc'},
 sources={
 {url='https://wowtbc.gg/mop/class-guides/enhancement-shaman/',title='wowtbc.gg: Enhancement Shaman (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,specs={263},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.lightning-shield','shaman-enh-sim-'),block('mop.shaman.enhancement-upkeep','shaman-enh-sim-'),block('mop.shaman.fire-totems','shaman-enh-sim-'),
  block('mop.shaman.group','shaman-enh-sim-'),
  BuiltinConditions.spell('shaman-enh-sim-shamanistic-rage',30823,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.6})),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-enh-sim-'),
 {id='shaman-enh-sim-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('shaman-enh-sim-pull-unleash',73680),
  {id='shaman-enh-sim-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 block('mop.shaman.enhancement-aoe','shaman-enh-sim-aoe-'),
 BuiltinConditions.spell('shaman-enh-sim-unleash-first',73680,BuiltinConditions.any({type='TALENT',layout='grid',value=16},BuiltinConditions.negate(flame))),
 BuiltinConditions.spell('shaman-enh-sim-elemental-blast',117014,fits),
 BuiltinConditions.spell('shaman-enh-sim-stormstrike',17364),
 BuiltinConditions.spell('shaman-enh-sim-primal-strike',73899,BuiltinConditions.negate(BuiltinConditions.known(17364))),
 BuiltinConditions.spell('shaman-enh-sim-bolt',403,fits),
 BuiltinConditions.spell('shaman-enh-sim-flame-shock-expiring',8050,BuiltinConditions.all(unleashed,BuiltinConditions.any(BuiltinConditions.negate(flame),shock('LESSTHANOREQUALS',2)))),
 BuiltinConditions.spell('shaman-enh-sim-stormblast',115356,BuiltinConditions.ownBuff(114051)),
 BuiltinConditions.spell('shaman-enh-sim-lava-lash',60103),
 BuiltinConditions.spell('shaman-enh-sim-unleash',73680),
 BuiltinConditions.spell('shaman-enh-sim-flame-shock-unleashed',8050,BuiltinConditions.all(unleashed,shock('LESSTHAN',9))),
 BuiltinConditions.spell('shaman-enh-sim-chain',421,fits),
 BuiltinConditions.spell('shaman-enh-sim-flame-shock',8050,BuiltinConditions.any(BuiltinConditions.negate(flame),shock('LESSTHAN',6))),
 BuiltinConditions.spell('shaman-enh-sim-earth-shock',8042,BuiltinConditions.negate(maelstrom(2))),
 }},
}))
