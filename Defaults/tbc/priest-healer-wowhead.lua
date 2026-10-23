-- TBC Priest healer after Wowhead, levels 10–70, selected in a group when Holy or Discipline is
-- the primary talent tree; the default healer premade. RM advises on the friendly unit you
-- target: choosing whom to heal stays with you. Prayer of Mending before every pull and
-- whenever ready, Renew, emergency Shield, dispels, group heals, Binding/Flash/Greater Heal,
-- and Greater Heal rank 1 as the cheap top-up. Health thresholds are RM policy.
-- The Icy Veins variant is rm.tbc.priest.healer.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function own(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-heal-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.healer.wowhead',revision=1,
 blocks={['tbc.priest.boundaries']=1,['tbc.priest.dispels']=1,['tbc.priest.group-heal']=1,['tbc.priest.big-heal']=1,
  ['tbc.priest.healer-damage']=1,['tbc.priest.upkeep']=1},
 nameKey='Default.TBC.Priest.HealerWowhead.Name',descriptionKey='Default.TBC.Priest.HealerWowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='PRIEST',minLevel=10,maxLevel=70},
 tags={'holy','discipline','healer','wowhead','dungeon','raid'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/priest/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Priest healing rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
 },
 body={
  priority=30,
  switch={type='AND',value={{type='GROUP'},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
   {type='OR',value={{type='PRIMARY_TALENT_TREE',tree=2},{type='PRIMARY_TALENT_TREE',tree=1}}}}},
  cooldowns={block(P..'upkeep','tbc.priest.upkeep',P),
   spell(P..'divine-spirit',14752,all(negate({type='COMBAT',unit='player'}),negate({type='BUFF',unit='player',spell=14752,anyrank=true}),negate({type='BUFF',unit='player',spell=27681,anyrank=true}))),
   spell(P..'inner-focus',14751,all({type='COMBAT',unit='player'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8})),
   spell(P..'pain-suppression',33206,all({type='COMBAT',unit='player'},{type='FRIENDLY',unit='target'},pct('target','LESSTHAN',.25)))},
  rotation={
   block(P..'boundaries','tbc.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),
    onFalse={block(P..'damage','tbc.priest.healer-damage',P)},
    onTrue={
     {id=P..'prepull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
      spell(P..'prepull-mending',33076),spell(P..'prepull-renew',139,negate(own(139))),stop(P..'prepull-stop')}},
     spell(P..'shield',17,all(pct('target','LESSTHAN',.35),negate({type='DEBUFF',unit='target',spell=6788}))),
     block(P..'dispels','tbc.priest.dispels',P),
     spell(P..'mending',33076),
     block(P..'group','tbc.priest.group-heal',P),
     spell(P..'binding',32546,all(pct('player','LESSTHAN',.7),pct('target','LESSTHAN',.7),negate({type='ISSAME',unit='target',otherunit='player'}))),
     spell(P..'flash',2061,pct('target','LESSTHAN',.5)),
     spell(P..'renew',139,all(negate(own(139)),pct('target','LESSTHAN',.95))),
     block(P..'big','tbc.priest.big-heal',P),
     {id=P..'top-up',type='spell',action=2060,ranked=true,conditions=pct('target','LESSTHAN',.9)},
     stop(P..'friend-done')}},
  },
 },
}))
