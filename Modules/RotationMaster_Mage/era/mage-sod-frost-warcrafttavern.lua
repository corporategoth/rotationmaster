-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Mage Frost after Warcraft Tavern's Phase 4 Fire-rune build (Overheat, Hot
-- Streak, Brain Freeze), levels 10–60; same switch as rm.sod.mage.frost at a lower priority, for
-- players who pick it. Pyroblast opens; Hot Streak Pyroblast; Living Bomb kept up; Improved Scorch
-- to five stacks when talented; Balefire Bolt only on Brain Freeze (never at four of its stacks);
-- Frostfire Bolt. Overheat's Fire Blast, Icy Veins and Frozen Orb under Icy Veins are reminders.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local P='mage-sfrost-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.frost.warcrafttavern',revision=7,
 blocks={['era.mage.boundaries']=3,['era.mage.wand-finish']=2,['sod.mage.balefire-brain-freeze']=1,
  ['sod.mage.living-bomb']=1,['sod.mage.overheat']=2,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'frost','fire','raid','single-target','season-of-discovery','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/frost-mage-dps/',title='Warcraft Tavern: SoD Frost Mage DPS (Phase 4)',reviewedAt='2026-10-23'},
 },
 body={
  priority=102,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={BuiltinConditions.block(P..'armor','sod.mage.armor',P),BuiltinConditions.block(P..'overheat','sod.mage.overheat',P),
   BuiltinConditions.spell(P..'frozen-orb',440802,BuiltinConditions.all({type='COMBAT',unit='player'},{type='BUFF',unit='player',spell=425121})),
   BuiltinConditions.block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-pyroblast',11366),BuiltinConditions.spell(P..'pull-frostfire',401502),BuiltinConditions.spell(P..'pull-frostbolt',116),stop(P..'pull-stop')}},
   BuiltinConditions.spell(P..'hot-streak',11366,{type='BUFF',unit='player',spell=48108}),
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell(P..'moving-living-bomb',400613,BuiltinConditions.negate(own(400613))),BuiltinConditions.spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell(P..'aoe-living-bomb',400613,BuiltinConditions.negate(own(400613))),
    BuiltinConditions.spell(P..'aoe-cone',120,near(2)),
    BuiltinConditions.spell(P..'aoe-blizzard',10)}},
   BuiltinConditions.block(P..'living-bomb','sod.mage.living-bomb',P),
   BuiltinConditions.spell(P..'scorch',2948,BuiltinConditions.all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
    BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}),{type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5}))),
   BuiltinConditions.block(P..'balefire-proc','sod.mage.balefire-brain-freeze',P),
   BuiltinConditions.spell(P..'frostfire',401502),
   BuiltinConditions.spell(P..'frostbolt',116),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
