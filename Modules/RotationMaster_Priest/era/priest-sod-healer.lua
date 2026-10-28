-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Priest healer, levels 10–60 (Phase 8 runes), selected in a group when Holy or
-- Discipline is the primary talent tree; follows Icy Veins' Discipline and Holy order. RM advises
-- on the friendly unit you target: choosing whom to heal stays with you. Prayer of Mending before
-- the pull and whenever ready, Shield below half health, Penance, instant Flash Heal on Surge of
-- Light, emergency Flash Heal, dispels, Circle of Healing and Prayer of Healing when three of your
-- party are hurt, the biggest learned heal, Renew while moving or on light damage, Heal. Pointed
-- at an enemy: Pain, Void Plague, Penance, Holy Fire, Smite. Thresholds are RM policy.
-- Variant: rm.sod.priest.healer.warcrafttavern (Serendipity loop).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function hurt(health)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-sod-heal-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.healer',revision=5,
 blocks={['era.priest.boundaries']=3,['era.priest.enemy-target']=2,['era.priest.dispels']=1,['era.priest.big-heal']=1,['era.priest.renew']=1,
  ['era.priest.friend-fortitude']=1,['era.priest.upkeep']=1,['era.priest.divine-spirit']=1,['sod.priest.healer-damage']=2,['sod.priest.healer-upkeep']=1},
 nameKey='Default.SoD.Priest.Healer.Name',descriptionKey='Default.SoD.Priest.Healer.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST',rulesets={'season:2'}},
 tags={'holy','discipline','healer','dungeon','raid','season-of-discovery','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/discipline-priest-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Discipline Priest healer',reviewedAt='2026-10-23',revision='2025-04-08',notes='Text describes Phase 4.'},
  {url='https://www.icy-veins.com/wow-classic/holy-priest-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Holy Priest healer',reviewedAt='2026-10-23',revision='2025-04-08',notes='Text describes Phase 4.'},
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/holy-priest-healer/',title='Warcraft Tavern: SoD Holy Priest healer',reviewedAt='2026-10-23',notes='Burst cooldowns and the enemy-target damage only.'},
 },
 body={
  priority=120,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='GROUP'},{type='OR',value={{type='PRIMARY_TALENT_TREE',tree=2},{type='PRIMARY_TALENT_TREE',tree=1}}}}},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'spirit','era.priest.divine-spirit',P),block(P..'sod-upkeep','sod.priest.healer-upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),
    onFalse={block(P..'damage','sod.priest.healer-damage',P)},
    onTrue={
     {id=P..'prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
      spell(P..'prepull-mending',401859),block(P..'prepull-fortitude','era.priest.friend-fortitude',P..'prepull-'),stop(P..'prepull-stop')}},
     spell(P..'shield',17,all(pct('target','LESSTHAN',.5),negate({type='DEBUFF',unit='target',spell=6788}))),
     spell(P..'penance',402174,pct('target','LESSTHAN',.8)),
     spell(P..'mending',401859),
     spell(P..'surge-flash',2061,all({type='BUFF',unit='player',spell=431666},pct('target','LESSTHAN',.9))),
     spell(P..'flash',2061,pct('target','LESSTHAN',.3)),
     block(P..'dispels','era.priest.dispels',P),
     spell(P..'circle',401946,hurt(.8)),
     spell(P..'prayer-of-healing',596,hurt(.8)),
     block(P..'big','era.priest.big-heal',P),
     block(P..'renew','era.priest.renew',P),
     spell(P..'top-up',2054,pct('target','LESSTHAN',.85)),
     spell(P..'top-up-lesser',2050,all(negate({type='SPELL_KNOWN',spell=2054}),pct('target','LESSTHAN',.85))),
     stop(P..'friend-done')}},
  },
 },
}))
