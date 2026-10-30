-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Blood Death Knight, health-reactive (simulator Iron Juggernaut and Sha
-- APLs, readable parts only). Off by default, same switch as rm.mop.deathknight.blood: Death Strike
-- below 70% health, to restore or refresh Blood Shield, or before the Frost and Unholy runes cap,
-- rather than on every rune; Heart Strike also spends a lone Blood rune when the Frost and Unholy
-- runes are more than a second away. No AoE branch: the simulator tanks single bosses.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local FEVER,PLAGUE=55095,55078
local shield={type='BUFF',unit='player',spell=77535,ownbuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.blood.simulator',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.blood-upkeep']=2,['mop.deathknight.blood-pull']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','single-target'},
 sources={},
 body={priority=25,disabled=true,specs={250},
  cooldowns={
   BuiltinConditions.block('bsim-upkeep','mop.deathknight.blood-upkeep','bsim-'),
   BuiltinConditions.block('bsim-class','mop.deathknight.upkeep','bsim-'),
  },
  rotation={
   BuiltinConditions.block('bsim-boundaries','mop.deathknight.boundaries','bsim-'),
   BuiltinConditions.block('bsim-pull','mop.deathknight.blood-pull','bsim-'),
   BuiltinConditions.spell('bsim-death-strike-reactive',49998,BuiltinConditions.any({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7},
    BuiltinConditions.all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=80},BuiltinConditions.any(BuiltinConditions.negate(shield),{type='BUFF_REMAIN',unit='player',spell=77535,ownbuff=true,operator='LESSTHAN',value=3})))),
   BuiltinConditions.spell('bsim-death-strike-runes',49998,BuiltinConditions.all(rune(2,'EQUALS',2),rune(3,'EQUALS',2))),
   BuiltinConditions.spell('bsim-rune-strike-cap',56815,rp('GREATERTHANOREQUALS',90)),
   BuiltinConditions.spell('bsim-death-coil-cap',47541,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(56815)),rp('GREATERTHANOREQUALS',80))),
   BuiltinConditions.spell('bsim-soul-reaper',114866,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   BuiltinConditions.spell('bsim-heart-strike-capped',55050,rune(1,'EQUALS',2)),
   BuiltinConditions.spell('bsim-blood-strike-capped',45902,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(55050)),rune(1,'EQUALS',2))),
   BuiltinConditions.spell('bsim-outbreak',77575,BuiltinConditions.any(BuiltinConditions.negate(disease(FEVER)),BuiltinConditions.negate(disease(PLAGUE)))),
   BuiltinConditions.spell('bsim-icy-touch',45477,BuiltinConditions.negate(disease(FEVER))),
   BuiltinConditions.spell('bsim-plague-strike',45462,BuiltinConditions.negate(disease(PLAGUE))),
   BuiltinConditions.spell('bsim-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
   BuiltinConditions.spell('bsim-scourge-boil',48721,BuiltinConditions.buff(81141)),
   BuiltinConditions.spell('bsim-scourge-decay',43265,BuiltinConditions.buff(81141)),
   BuiltinConditions.spell('bsim-heart-strike',55050,BuiltinConditions.all({type='RUNE_COOLDOWN',rune=2,operator='GREATERTHAN',value=1},{type='RUNE_COOLDOWN',rune=3,operator='GREATERTHAN',value=1})),
   BuiltinConditions.spell('bsim-blood-strike',45902,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(55050)),{type='RUNE_COOLDOWN',rune=2,operator='GREATERTHAN',value=1},{type='RUNE_COOLDOWN',rune=3,operator='GREATERTHAN',value=1})),
   BuiltinConditions.spell('bsim-rune-strike',56815),
   BuiltinConditions.spell('bsim-horn-filler',57330),
  },
 },
}))
