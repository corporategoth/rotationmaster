-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Priest healer, levels 10–60, selected in a group when Holy or Discipline is the
-- primary talent tree. RM advises on the friendly unit you target: choosing whom to heal, and
-- downranking, stay with you. Emergency Shield and Flash Heal, dispels, Prayer of Healing when
-- three of your party are hurt, the biggest learned heal on a badly hurt target, Renew while
-- moving or on light damage, then Heal rank 3 as the efficient top-up (Icy Veins, Wowhead).
-- Pointed at an enemy it does light damage. Thresholds are RM policy.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local P='priest-heal-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.healer',revision=5,
 blocks={['era.priest.boundaries']=3,['era.priest.enemy-target']=2,['era.priest.dispels']=1,['era.priest.big-heal']=1,['era.priest.renew']=1,
  ['era.priest.friend-fortitude']=1,['era.priest.upkeep']=1,['era.priest.divine-spirit']=1},
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
  cooldowns={BuiltinConditions.block(P..'upkeep','era.priest.upkeep',P),BuiltinConditions.block(P..'spirit','era.priest.divine-spirit',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),
    onFalse={
     BuiltinConditions.block(P..'enemy-target','era.priest.enemy-target',P..'enemy-'),
     BuiltinConditions.spell(P..'enemy-pain',589,BuiltinConditions.all(BuiltinConditions.negate(own(589)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
     BuiltinConditions.spell(P..'enemy-smite',585),
     BuiltinConditions.stop(P..'enemy-stop')},
    onTrue={
     {id=P..'prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
      BuiltinConditions.block(P..'prepull-fortitude','era.priest.friend-fortitude',P..'prepull-'),BuiltinConditions.stop(P..'prepull-stop')}},
     BuiltinConditions.spell(P..'shield',17,BuiltinConditions.all(pct('target','LESSTHAN',.3),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788}))),
     BuiltinConditions.spell(P..'flash',2061,pct('target','LESSTHAN',.4)),
     BuiltinConditions.block(P..'dispels','era.priest.dispels',P),
     BuiltinConditions.spell(P..'prayer-of-healing',596,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=.8,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}),
     BuiltinConditions.block(P..'big','era.priest.big-heal',P),
     BuiltinConditions.block(P..'renew','era.priest.renew',P),
     -- Heal rank 3 is the efficient top-up; before level 28 any learned Heal, else Lesser Heal.
     {id=P..'top-up-r3',type='spell',action=6063,ranked=true,conditions=pct('target','LESSTHAN',.85)},
     BuiltinConditions.spell(P..'top-up',2054,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(6063)),pct('target','LESSTHAN',.85))),
     BuiltinConditions.spell(P..'top-up-lesser',2050,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(2054)),pct('target','LESSTHAN',.85))),
     BuiltinConditions.stop(P..'friend-done')}},
  },
 },
}))
