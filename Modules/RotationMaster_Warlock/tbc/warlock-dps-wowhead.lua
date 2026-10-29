-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warlock after Wowhead's guides, levels 1–70; same switch as the Icy Veins premade with a
-- lower priority, shipped disabled: enable it to use it. It differs where Wowhead differs:
-- solo it drain-tanks (Drain Life as the filler once DoTs are up, no wand) and keeps Immolate
-- and Siphon Life for tough (elite) mobs; in a group Immolate always goes on, after
-- Corruption and Siphon Life.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function refresh(id)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function pct(kind,op,v)return{type=kind,unit='player',operator=op,value=v}end
local function class(v)return{type='CLASSIFICATION',unit='target',value=v}end
local tough=BuiltinConditions.any(class('elite'),class('rareelite'),class('worldboss'))
local P='warlock-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warlock.dps.wowhead',revision=6,
 blocks={['tbc.warlock.boundaries']=3,['tbc.warlock.procs']=1,['tbc.warlock.moving']=2,['tbc.warlock.curse']=2,['tbc.warlock.aoe']=1,
  ['tbc.warlock.finishers']=1,['tbc.warlock.filler']=2,['tbc.warlock.armor']=1,['tbc.warlock.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='WARLOCK'},
 tags={'affliction','demonology','destruction','wowhead','leveling','raid','single-target','aoe','drain-tank'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/affliction/leveling-tips',title='Wowhead: Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-01'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/demonology/leveling-tips',title='Wowhead: Demonology Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/destruction/leveling-tips',title='Wowhead: Destruction Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Warlock DPS rotation',reviewedAt='2026-10-23',revision='2026-02-10'},

 },
 body={
  priority=5,disabled=true,
  switch={type='SPELL_KNOWN',spell=686},
  cooldowns={BuiltinConditions.block(P..'armor','tbc.warlock.armor',P),BuiltinConditions.block(P..'upkeep','tbc.warlock.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','tbc.warlock.boundaries',P),
   BuiltinConditions.block(P..'procs','tbc.warlock.procs',P),
   BuiltinConditions.block(P..'moving','tbc.warlock.moving',P),
   BuiltinConditions.block(P..'aoe','tbc.warlock.aoe',P),
   {id=P..'dying',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),
    onTrue={BuiltinConditions.block(P..'finishers','tbc.warlock.finishers',P)},
    onFalse={
     BuiltinConditions.block(P..'curse','tbc.warlock.curse',P),
     BuiltinConditions.spell(P..'unstable',30108,refresh(30108)),
     BuiltinConditions.spell(P..'corruption',172,BuiltinConditions.all(BuiltinConditions.negate(own(172)),BuiltinConditions.any({type='TALENT',layout='tree',tree=1,talent=2,operator='GREATERTHANOREQUALS',value=1},
      {type='TALENT_TREE_POINTS',tree=3,operator='LESSTHAN',value=31}))),
     BuiltinConditions.spell(P..'siphon',18265,BuiltinConditions.all(BuiltinConditions.negate(own(18265)),BuiltinConditions.any({type='DEBUFF',unit='target',spell=17800},BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),tough)))),
     BuiltinConditions.spell(P..'immolate',348,BuiltinConditions.all(refresh(348),BuiltinConditions.any({type='GROUP'},tough))),
    }},
   {id=P..'solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'solo-tap',1454,BuiltinConditions.all(pct('MANAPCT','LESSTHAN',.5),pct('HEALTHPCT','GREATERTHAN',.6))),
    BuiltinConditions.spell(P..'drain-life',689)}},
   BuiltinConditions.block(P..'filler','tbc.warlock.filler',P),
  },
 },
}))
