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
local BuiltinConditions=addon.BuiltInConditionHelpers
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function hurt(health)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}end
local P='priest-sod-heal-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.healer',revision=5,
 blocks={['era.priest.boundaries']=3,['era.priest.enemy-target']=2,['era.priest.dispels']=1,['era.priest.big-heal']=1,['era.priest.renew']=1,
  ['era.priest.friend-fortitude']=1,['era.priest.upkeep']=1,['era.priest.divine-spirit']=1,['sod.priest.healer-damage']=2,['sod.priest.healer-upkeep']=1},
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
  cooldowns={BuiltinConditions.block(P..'upkeep','era.priest.upkeep',P),BuiltinConditions.block(P..'spirit','era.priest.divine-spirit',P),BuiltinConditions.block(P..'sod-upkeep','sod.priest.healer-upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),
    onFalse={BuiltinConditions.block(P..'damage','sod.priest.healer-damage',P)},
    onTrue={
     {id=P..'prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
      BuiltinConditions.spell(P..'prepull-mending',401859),BuiltinConditions.block(P..'prepull-fortitude','era.priest.friend-fortitude',P..'prepull-'),BuiltinConditions.stop(P..'prepull-stop')}},
     BuiltinConditions.spell(P..'shield',17,BuiltinConditions.all(pct('target','LESSTHAN',.5),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788}))),
     BuiltinConditions.spell(P..'penance',402174,pct('target','LESSTHAN',.8)),
     BuiltinConditions.spell(P..'mending',401859),
     BuiltinConditions.spell(P..'surge-flash',2061,BuiltinConditions.all({type='BUFF',unit='player',spell=431666},pct('target','LESSTHAN',.9))),
     BuiltinConditions.spell(P..'flash',2061,pct('target','LESSTHAN',.3)),
     BuiltinConditions.block(P..'dispels','era.priest.dispels',P),
     BuiltinConditions.spell(P..'circle',401946,hurt(.8)),
     BuiltinConditions.spell(P..'prayer-of-healing',596,hurt(.8)),
     BuiltinConditions.block(P..'big','era.priest.big-heal',P),
     BuiltinConditions.block(P..'renew','era.priest.renew',P),
     BuiltinConditions.spell(P..'top-up',2054,pct('target','LESSTHAN',.85)),
     BuiltinConditions.spell(P..'top-up-lesser',2050,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=2054}),pct('target','LESSTHAN',.85))),
     BuiltinConditions.stop(P..'friend-done')}},
  },
 },
}))
