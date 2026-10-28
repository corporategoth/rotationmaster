-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Priest healer after Warcraft Tavern's Holy and Discipline guides (Phase 4),
-- levels 10–60; same switch as rm.sod.priest.healer at a lower priority, for players who pick it.
-- Built for the Serendipity and Soul Warding runes: Prayer of Mending on cooldown, Shield on anyone
-- who can take it (with Soul Warding engraved; else below half health), Penance on heavy damage,
-- Circle of Healing for three hurt, Renew on minor damage, Greater Heal or Prayer of Healing at three
-- Serendipity stacks, and Flash Heal on minor injuries to build those stacks (with Serendipity
-- engraved; else only below 30%).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function hurt(health)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local serendipity={type='BUFF_STACKS',unit='player',spell=413247,operator='GREATERTHANOREQUALS',value=3}
local function any(...)return{type='OR',value={...}}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local P='priest-sod-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.healer.warcrafttavern',revision=7,
 blocks={['era.priest.boundaries']=3,['era.priest.enemy-target']=2,['era.priest.dispels']=1,['era.priest.big-heal']=1,
  ['era.priest.friend-fortitude']=1,['era.priest.upkeep']=1,['era.priest.divine-spirit']=1,['sod.priest.healer-damage']=2,['sod.priest.healer-upkeep']=1},
 nameKey='Default.SoD.Priest.Healer.WarcraftTavern.Name',descriptionKey='Default.SoD.Priest.Healer.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST',rulesets={'season:2'}},
 tags={'holy','discipline','healer','dungeon','raid','season-of-discovery','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/holy-priest-healer/',title='Warcraft Tavern: SoD Holy Priest healer',reviewedAt='2026-10-23',notes='Phase 4 text.'},
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/discipline-priest-healer/',title='Warcraft Tavern: SoD Discipline Priest healer',reviewedAt='2026-10-23',notes='Phase 4 text.'},
 },
 body={
  priority=115,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='GROUP'},{type='OR',value={{type='PRIMARY_TALENT_TREE',tree=2},{type='PRIMARY_TALENT_TREE',tree=1}}}}},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'spirit','era.priest.divine-spirit',P),block(P..'sod-upkeep','sod.priest.healer-upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),
    onFalse={block(P..'damage','sod.priest.healer-damage',P)},
    onTrue={
     {id=P..'prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
      spell(P..'prepull-mending',401859),block(P..'prepull-fortitude','era.priest.friend-fortitude',P..'prepull-'),stop(P..'prepull-stop')}},
     spell(P..'mending',401859),
     spell(P..'shield',17,all(negate({type='DEBUFF',unit='target',spell=6788}),any(rune(402000),pct('target','LESSTHAN',.5)))),
     spell(P..'penance',402174,pct('target','LESSTHAN',.7)),
     block(P..'dispels','era.priest.dispels',P),
     spell(P..'circle',401946,hurt(.8)),
     spell(P..'serendipity-prayer',596,all(serendipity,hurt(.8))),
     spell(P..'serendipity-greater',2060,all(serendipity,pct('target','LESSTHAN',.7))),
     spell(P..'renew',139,all(negate({type='BUFF',unit='target',spell=139,anyrank=true,ownbuff=true}),pct('target','LESSTHAN',.95))),
     block(P..'big','era.priest.big-heal',P),
     spell(P..'flash',2061,any(all(rune(413248),pct('target','LESSTHAN',.9)),pct('target','LESSTHAN',.3))),
     stop(P..'friend-done')}},
  },
 },
}))
