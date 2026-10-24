-- Season of Discovery Mage Frost after Warcraft Tavern's Phase 4 Fire-rune build (Overheat, Hot
-- Streak, Brain Freeze), levels 10–60; same switch as rm.sod.mage.frost at a lower priority, for
-- players who pick it. Pyroblast opens; Hot Streak Pyroblast; Living Bomb kept up; Improved Scorch
-- to five stacks when talented; Balefire Bolt only on Brain Freeze (never at four of its stacks);
-- Frostfire Bolt. Overheat's Fire Blast, Icy Veins and Frozen Orb under Icy Veins are reminders.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-sfrost-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.frost.warcrafttavern',revision=5,
 blocks={['era.mage.boundaries']=2,['era.mage.wand-finish']=1,['sod.mage.balefire-brain-freeze']=1,
  ['sod.mage.living-bomb']=1,['sod.mage.overheat']=2,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 nameKey='Default.SoD.Mage.Frost.WarcraftTavern.Name',descriptionKey='Default.SoD.Mage.Frost.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'frost','fire','raid','single-target','season-of-discovery','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/frost-mage-dps/',title='Warcraft Tavern: SoD Frost Mage DPS (Phase 4)',reviewedAt='2026-10-23'},
 },
 body={
  priority=102,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={block(P..'armor','sod.mage.armor',P),block(P..'overheat','sod.mage.overheat',P),
   spell(P..'frozen-orb',440802,all({type='COMBAT',unit='player'},{type='BUFF',unit='player',spell=425121})),
   block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-pyroblast',11366),spell(P..'pull-frostfire',401502),spell(P..'pull-frostbolt',116),stop(P..'pull-stop')}},
   spell(P..'hot-streak',11366,{type='BUFF',unit='player',spell=48108}),
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell(P..'moving-living-bomb',400613,negate(own(400613))),spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-living-bomb',400613,negate(own(400613))),
    spell(P..'aoe-cone',120,near(2)),
    spell(P..'aoe-blizzard',10)}},
   block(P..'living-bomb','sod.mage.living-bomb',P),
   spell(P..'scorch',2948,all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
    any(negate({type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}),{type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5}))),
   block(P..'balefire-proc','sod.mage.balefire-brain-freeze',P),
   spell(P..'frostfire',401502),
   spell(P..'frostbolt',116),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
