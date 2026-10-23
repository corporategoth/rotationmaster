-- TBC Priest healer after Icy Veins, levels 10–70; same switch as the Wowhead healer premade
-- with a lower priority, so choose or enable it to use it. It follows Icy Veins' order:
-- Shield, Binding Heal, Renew, Flash Heal, Greater Heal (any rank), group heals, and Prayer of
-- Mending last; no pre-pull Prayer of Mending and no fixed top-up rank. You pick the target.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function own(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-heal-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.healer.icyveins',revision=2,
 blocks={['tbc.priest.boundaries']=2,['tbc.priest.dispels']=1,['tbc.priest.group-heal']=1,['tbc.priest.big-heal']=1,
  ['tbc.priest.healer-damage']=1,['tbc.priest.upkeep']=1},
 nameKey='Default.TBC.Priest.HealerIcyVeins.Name',descriptionKey='Default.TBC.Priest.HealerIcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='PRIEST',minLevel=10,maxLevel=70},
 tags={'holy','discipline','healer','icy-veins','dungeon','raid'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/holy-priest-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/holy-priest-leveling-guide',title='Icy Veins: Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/discipline-priest-leveling-guide',title='Icy Veins: Discipline Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 },
 body={
  priority=25,
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
     spell(P..'shield',17,all(pct('target','LESSTHAN',.35),negate({type='DEBUFF',unit='target',spell=6788}))),
     block(P..'dispels','tbc.priest.dispels',P),
     spell(P..'binding',32546,all(pct('player','LESSTHAN',.7),pct('target','LESSTHAN',.7),negate({type='ISSAME',unit='target',otherunit='player'}))),
     spell(P..'renew',139,all(negate(own(139)),pct('target','LESSTHAN',.95))),
     spell(P..'flash',2061,pct('target','LESSTHAN',.5)),
     block(P..'big','tbc.priest.big-heal',P),
     block(P..'group','tbc.priest.group-heal',P),
     spell(P..'mending',33076,{type='COMBAT',unit='player'}),
     stop(P..'friend-done')}},
  },
 },
}))
