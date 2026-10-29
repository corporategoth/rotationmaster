-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Enhancement Shaman, simulator "weave everything" variant (player-chosen, off by
-- default): the simulator's P3 Default list. Same switch as the recommended premade (Enhancement specialization). Spends any
-- Maelstrom Weapon stack on Lightning Bolt, Elemental Blast or Chain Lightning whenever the cast finishes before
-- the next main-hand swing (about 2.0 s at one stack down to 0.5 s at four; five is instant); Unleash Elements
-- also whenever Flame Shock is missing; Earth Shock only below two stacks. For players who swing-time their
-- casts. Shared parts: mop/blocks.lua (the pack arm is the recommended premade's).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=53817,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function swing(n)return{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=n}end
local function shock(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
-- The cast finishes before the next swing: an unhasted 2.5 s cast less 20% per Maelstrom Weapon stack.
local fits=any(maelstrom(5),all(maelstrom(4),swing(.5)),all(maelstrom(3),swing(1)),all(maelstrom(2),swing(1.5)),all(maelstrom(1),swing(2)))
local unleashed=own(73683)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.enhancement.simulator',revision=7,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1,
  ['mop.shaman.enhancement-upkeep']=2,['mop.shaman.enhancement-aoe']=1},
 nameKey="Weave every stack (simulator)",descriptionKey="Off by default; same switch as the recommended Enhancement premade, so enable it and disable that one to use it. The simulator's list for players who time casts between swings: Lightning Bolt, Elemental Blast or Chain Lightning on any number of Maelstrom Weapon stacks whenever the cast finishes before your next main-hand swing, Unleash Elements also whenever Flame Shock is missing, and Earth Shock only below two stacks. Reminders as the recommended premade.",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'enhancement','dps','melee','endgame','wowtbc'},
 sources={
 {url='https://wowtbc.gg/mop/class-guides/enhancement-shaman/',title='wowtbc.gg: Enhancement Shaman (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,specs={263},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.lightning-shield','shaman-enh-sim-'),block('mop.shaman.enhancement-upkeep','shaman-enh-sim-'),block('mop.shaman.fire-totems','shaman-enh-sim-'),
  block('mop.shaman.group','shaman-enh-sim-'),
  spell('shaman-enh-sim-shamanistic-rage',30823,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.6})),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-enh-sim-'),
 {id='shaman-enh-sim-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('shaman-enh-sim-pull-unleash',73680),
  {id='shaman-enh-sim-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 block('mop.shaman.enhancement-aoe','shaman-enh-sim-aoe-'),
 spell('shaman-enh-sim-unleash-first',73680,any({type='TALENT',layout='grid',value=16},negate(flame))),
 spell('shaman-enh-sim-elemental-blast',117014,fits),
 spell('shaman-enh-sim-stormstrike',17364),
 spell('shaman-enh-sim-primal-strike',73899,negate(known(17364))),
 spell('shaman-enh-sim-bolt',403,fits),
 spell('shaman-enh-sim-flame-shock-expiring',8050,all(unleashed,any(negate(flame),shock('LESSTHANOREQUALS',2)))),
 spell('shaman-enh-sim-stormblast',115356,own(114051)),
 spell('shaman-enh-sim-lava-lash',60103),
 spell('shaman-enh-sim-unleash',73680),
 spell('shaman-enh-sim-flame-shock-unleashed',8050,all(unleashed,shock('LESSTHAN',9))),
 spell('shaman-enh-sim-chain',421,fits),
 spell('shaman-enh-sim-flame-shock',8050,any(negate(flame),shock('LESSTHAN',6))),
 spell('shaman-enh-sim-earth-shock',8042,negate(maelstrom(2))),
 }},
}))
