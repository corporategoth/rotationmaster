-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Mage Fire after Warcraft Tavern, levels 10–60; same switch as rm.era.mage.fire at a
-- lower priority, for players who pick it. Combustion goes at the pull on elites and bosses rather
-- than waiting for Scorch stacks; Pyroblast pre-cast; Scorch to five stacks; Fireball; Fire Blast
-- only to reposition. AoE opens with Flamestrike, then Arcane Explosion, Cone of Cold and Blast Wave
-- close, Blizzard at range.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function class(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local P='mage-fire-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.mage.fire.warcrafttavern',revision=6,
 blocks={['era.mage.boundaries']=3,['era.mage.moving']=2,['era.mage.nova']=1,['era.mage.execute']=2,
  ['era.mage.wand-finish']=2,['era.mage.armor']=1,['era.mage.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='MAGE'},
 tags={'fire','raid','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-fire-mage-rotations-cooldowns/',title='Warcraft Tavern: Classic Fire Mage PvE',reviewedAt='2026-10-23'},
 },
 body={
  priority=9,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},BuiltinConditions.any(BuiltinConditions.all({type='TALENT_TREE_POINTS',tree=3,operator='EQUALS',value=0},{type='TALENT_TREE_POINTS',tree=2,operator='GREATERTHANOREQUALS',value=1}),
   {type='PRIMARY_TALENT_TREE',tree=2})}},
  cooldowns={BuiltinConditions.block(P..'armor','era.mage.armor',P),
   BuiltinConditions.spell(P..'combustion',11129,BuiltinConditions.any(class('elite'),class('rareelite'),class('worldboss'))),
   BuiltinConditions.block(P..'upkeep','era.mage.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-pyroblast',11366),BuiltinConditions.spell(P..'pull-fireball',133),stop(P..'pull-stop')}},
   BuiltinConditions.spell(P..'presence-pyroblast',11366,{type='BUFF',unit='player',spell=12043}),
   BuiltinConditions.block(P..'moving','era.mage.moving',P),
   BuiltinConditions.block(P..'nova','era.mage.nova',P),
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell(P..'aoe-flamestrike',2120,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
    BuiltinConditions.spell(P..'aoe-explosion',1449,near(3)),
    BuiltinConditions.spell(P..'aoe-cone',120,near(2)),
    BuiltinConditions.spell(P..'aoe-blast-wave',11113,near(2)),
    BuiltinConditions.spell(P..'aoe-blizzard',10)}},
   BuiltinConditions.spell(P..'scorch',2948,BuiltinConditions.all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
    BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}),{type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5}))),
   BuiltinConditions.block(P..'execute','era.mage.execute',P),
   BuiltinConditions.spell(P..'execute-scorch',2948,{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3}),
   BuiltinConditions.spell(P..'fireball',133),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
