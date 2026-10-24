-- Classic Era Mage Fire after Warcraft Tavern, levels 10–60; same switch as rm.era.mage.fire at a
-- lower priority, for players who pick it. Combustion goes at the pull on elites and bosses rather
-- than waiting for Scorch stacks; Pyroblast pre-cast; Scorch to five stacks; Fireball; Fire Blast
-- only to reposition. AoE opens with Flamestrike, then Arcane Explosion, Cone of Cold and Blast Wave
-- close, Blizzard at range.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function class(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-fire-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.mage.fire.warcrafttavern',revision=4,
 blocks={['era.mage.boundaries']=2,['era.mage.moving']=1,['era.mage.nova']=1,['era.mage.execute']=1,
  ['era.mage.wand-finish']=1,['era.mage.armor']=1,['era.mage.upkeep']=1},
 nameKey='Default.Era.Mage.Fire.WarcraftTavern.Name',descriptionKey='Default.Era.Mage.Fire.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='MAGE'},
 tags={'fire','raid','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-fire-mage-rotations-cooldowns/',title='Warcraft Tavern: Classic Fire Mage PvE',reviewedAt='2026-10-23'},
 },
 body={
  priority=9,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},any(all({type='TALENT_TREE_POINTS',tree=3,operator='EQUALS',value=0},{type='TALENT_TREE_POINTS',tree=2,operator='GREATERTHANOREQUALS',value=1}),
   {type='PRIMARY_TALENT_TREE',tree=2})}},
  cooldowns={block(P..'armor','era.mage.armor',P),
   spell(P..'combustion',11129,any(class('elite'),class('rareelite'),class('worldboss'))),
   block(P..'upkeep','era.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-pyroblast',11366),spell(P..'pull-fireball',133),stop(P..'pull-stop')}},
   spell(P..'presence-pyroblast',11366,{type='BUFF',unit='player',spell=12043}),
   block(P..'moving','era.mage.moving',P),
   block(P..'nova','era.mage.nova',P),
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-flamestrike',2120,negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
    spell(P..'aoe-explosion',1449,near(3)),
    spell(P..'aoe-cone',120,near(2)),
    spell(P..'aoe-blast-wave',11113,near(2)),
    spell(P..'aoe-blizzard',10)}},
   spell(P..'scorch',2948,all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
    any(negate({type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}),{type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5}))),
   block(P..'execute','era.mage.execute',P),
   spell(P..'execute-scorch',2948,{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3}),
   spell(P..'fireball',133),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
