-- Classic Era Priest healer, levels 10–60, selected in a group when Holy or Discipline is the
-- primary talent tree. RM advises on the friendly unit you target: choosing whom to heal, and
-- downranking, stay with you. Emergency Shield and Flash Heal, dispels, Prayer of Healing when
-- three of your party are hurt, the biggest learned heal on a badly hurt target, Renew while
-- moving or on light damage, then Heal rank 3 as the efficient top-up (Icy Veins, Wowhead).
-- Pointed at an enemy it does light damage. Thresholds are RM policy.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-heal-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.healer',revision=4,
 blocks={['era.priest.boundaries']=3,['era.priest.enemy-target']=2,['era.priest.dispels']=1,['era.priest.big-heal']=1,['era.priest.renew']=1,
  ['era.priest.friend-fortitude']=1,['era.priest.upkeep']=1,['era.priest.divine-spirit']=1},
 nameKey='Default.Era.Priest.Healer.Name',descriptionKey='Default.Era.Priest.Healer.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'holy','discipline','healer','dungeon','raid','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/priest-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Priest healer rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/holy-priest-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/priest/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Priest healer rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 },
 body={
  priority=20,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='GROUP'},{type='OR',value={{type='PRIMARY_TALENT_TREE',tree=2},{type='PRIMARY_TALENT_TREE',tree=1}}}}},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'spirit','era.priest.divine-spirit',P)},
  rotation={
   block(P..'boundaries','era.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),
    onFalse={
     block(P..'enemy-target','era.priest.enemy-target',P..'enemy-'),
     spell(P..'enemy-pain',589,all(negate(own(589)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
     spell(P..'enemy-smite',585),
     stop(P..'enemy-stop')},
    onTrue={
     {id=P..'prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
      block(P..'prepull-fortitude','era.priest.friend-fortitude',P..'prepull-'),stop(P..'prepull-stop')}},
     spell(P..'shield',17,all(pct('target','LESSTHAN',.3),negate({type='DEBUFF',unit='target',spell=6788}))),
     spell(P..'flash',2061,pct('target','LESSTHAN',.4)),
     block(P..'dispels','era.priest.dispels',P),
     spell(P..'prayer-of-healing',596,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=.8,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}),
     block(P..'big','era.priest.big-heal',P),
     block(P..'renew','era.priest.renew',P),
     -- Heal rank 3 is the efficient top-up; before level 28 any learned Heal, else Lesser Heal.
     {id=P..'top-up-r3',type='spell',action=6063,ranked=true,conditions=pct('target','LESSTHAN',.85)},
     spell(P..'top-up',2054,all(negate(known(6063)),pct('target','LESSTHAN',.85))),
     spell(P..'top-up-lesser',2050,all(negate(known(2054)),pct('target','LESSTHAN',.85))),
     stop(P..'friend-done')}},
  },
 },
}))
