-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Priest healer after Icy Veins, levels 10–70; same switch as the Wowhead healer premade
-- with a lower priority, shipped disabled: enable it to use it. It follows Icy Veins' order:
-- Shield, Binding Heal, Renew, Flash Heal, Greater Heal (any rank), group heals, and Prayer of
-- Mending last; no pre-pull Prayer of Mending and no fixed top-up rank. You pick the target.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function pct(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function own(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local P='priest-heal-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.healer.icyveins',revision=6,
 blocks={['tbc.priest.boundaries']=4,['tbc.priest.dispels']=1,['tbc.priest.group-heal']=1,['tbc.priest.big-heal']=1,
  ['tbc.priest.healer-damage']=2,['tbc.priest.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='PRIEST'},
 tags={'holy','discipline','healer','icy-veins','dungeon','raid'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/holy-priest-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/holy-priest-leveling-guide',title='Icy Veins: Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/discipline-priest-leveling-guide',title='Icy Veins: Discipline Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 },
 body={
  priority=25,disabled=true,
  switch={type='AND',value={{type='GROUP'},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
   {type='OR',value={{type='PRIMARY_TALENT_TREE',tree=2},{type='PRIMARY_TALENT_TREE',tree=1}}}}},
  cooldowns={BuiltinConditions.block(P..'upkeep','tbc.priest.upkeep',P),
   BuiltinConditions.spell(P..'divine-spirit',14752,BuiltinConditions.all(BuiltinConditions.negate({type='COMBAT',unit='player'}),BuiltinConditions.negate({type='BUFF',unit='player',spell=14752,anyrank=true}),BuiltinConditions.negate({type='BUFF',unit='player',spell=27681,anyrank=true}))),
   BuiltinConditions.spell(P..'inner-focus',14751,BuiltinConditions.all({type='COMBAT',unit='player'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8})),
   BuiltinConditions.spell(P..'pain-suppression',33206,BuiltinConditions.all({type='COMBAT',unit='player'},{type='FRIENDLY',unit='target'},pct('target','LESSTHAN',.25)))},
  rotation={
   BuiltinConditions.block(P..'boundaries','tbc.priest.boundaries',P),
   {id=P..'friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),
    onFalse={BuiltinConditions.block(P..'damage','tbc.priest.healer-damage',P)},
    onTrue={
     BuiltinConditions.spell(P..'shield',17,BuiltinConditions.all(pct('target','LESSTHAN',.35),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788}))),
     BuiltinConditions.block(P..'dispels','tbc.priest.dispels',P),
     BuiltinConditions.spell(P..'binding',32546,BuiltinConditions.all(pct('player','LESSTHAN',.7),pct('target','LESSTHAN',.7),BuiltinConditions.negate({type='ISSAME',unit='target',otherunit='player'}))),
     BuiltinConditions.spell(P..'renew',139,BuiltinConditions.all(BuiltinConditions.negate(own(139)),pct('target','LESSTHAN',.95))),
     BuiltinConditions.spell(P..'flash',2061,pct('target','LESSTHAN',.5)),
     BuiltinConditions.block(P..'big','tbc.priest.big-heal',P),
     BuiltinConditions.block(P..'group','tbc.priest.group-heal',P),
     BuiltinConditions.spell(P..'mending',33076,{type='COMBAT',unit='player'}),
     BuiltinConditions.stop(P..'friend-done')}},
  },
 },
}))
