-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Priest damage after simulator' Shadow APL, levels 1–60; same switch as
-- rm.era.priest.dps at a lower priority, for raid groups with spare debuff slots. Differs from the
-- default by spending Inner Focus on Devouring Plague (Undead) instead of Mind Blast and casting
-- Devouring Plague in raids too; no Vampiric Embrace. Leveling steps match the default.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local combat={type='COMBAT',unit='player'}
local P='priest-sim-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.dps.simulator',revision=6,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull']=3,['era.priest.pull-shield']=1,
  ['era.priest.moving']=2,['era.priest.wand-finish']=2,['era.priest.pain']=1,['era.priest.filler']=2,['era.priest.wand-fallback']=2,
  ['era.priest.upkeep']=1},
 nameKey='Default.Era.Priest.Dps.Simulator.Name',descriptionKey='Default.Era.Priest.Dps.Simulator.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','raid','single-target'},
 sources={},
 body={
  priority=4,disabled=true,
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),
   -- Inner Focus goes on Devouring Plague; without the racial, on Mind Blast as usual.
   spell(P..'inner-focus',14751,all(combat,any(all(known(2944),{type='SPELL_COOLDOWN',spell=2944,operator='LESSTHANOREQUALS',value=1.5},negate(own(2944))),
    all(negate(known(2944)),{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})))),
   spell(P..'scream',8122,all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}))},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   block(P..'pull','era.priest.pull',P),
   block(P..'moving','era.priest.moving',P),
   block(P..'finish','era.priest.wand-finish',P),
   block(P..'pain','era.priest.pain',P),
   -- Devouring Plague right after Inner Focus (or when Inner Focus is not ready or not learned).
   spell(P..'plague',2944,all(negate(own(2944)),any({type='BUFF',unit='player',spell=14751},negate(known(14751)),{type='SPELL_COOLDOWN',spell=14751,operator='GREATERTHAN',value=1.5}))),
   spell(P..'blast',8092,any({type='GROUP'},{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3})),
   block(P..'filler','era.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
