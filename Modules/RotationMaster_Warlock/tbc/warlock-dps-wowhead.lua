-- TBC Warlock after Wowhead's guides, levels 1–70; same switch as the Icy Veins premade with a
-- lower priority, so choose or enable it to use it. It differs where Wowhead differs:
-- solo it drain-tanks (Drain Life as the filler once DoTs are up, no wand) and keeps Immolate
-- and Siphon Life for tough (elite) mobs; in a group Immolate always goes on, after
-- Corruption and Siphon Life.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function refresh(id)return any(negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function pct(kind,op,v)return{type=kind,unit='player',operator=op,value=v}end
local function class(v)return{type='CLASSIFICATION',unit='target',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local tough=any(class('elite'),class('rareelite'),class('worldboss'))
local P='warlock-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warlock.dps.wowhead',revision=3,
 blocks={['tbc.warlock.boundaries']=2,['tbc.warlock.procs']=1,['tbc.warlock.moving']=1,['tbc.warlock.curse']=2,['tbc.warlock.aoe']=1,
  ['tbc.warlock.finishers']=1,['tbc.warlock.filler']=1,['tbc.warlock.armor']=1,['tbc.warlock.upkeep']=1},
 nameKey='Default.TBC.Warlock.DpsWowhead.Name',descriptionKey='Default.TBC.Warlock.DpsWowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='WARLOCK'},
 tags={'affliction','demonology','destruction','wowhead','leveling','raid','single-target','aoe','drain-tank'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/affliction/leveling-tips',title='Wowhead: Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-01'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/demonology/leveling-tips',title='Wowhead: Demonology Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/destruction/leveling-tips',title='Wowhead: Destruction Warlock leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Warlock DPS rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/ui/core/talents/warlock.ts',title='wowsims TBC Warlock talent layout',reviewedAt='2026-10-23',revision='3301fca',notes='Talent positions only.'},
 },
 body={
  priority=5,
  switch={type='SPELL_KNOWN',spell=686},
  cooldowns={block(P..'armor','tbc.warlock.armor',P),block(P..'upkeep','tbc.warlock.upkeep',P)},
  rotation={
   block(P..'boundaries','tbc.warlock.boundaries',P),
   block(P..'procs','tbc.warlock.procs',P),
   block(P..'moving','tbc.warlock.moving',P),
   block(P..'aoe','tbc.warlock.aoe',P),
   {id=P..'dying',type='branch',conditions=all(negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),
    onTrue={block(P..'finishers','tbc.warlock.finishers',P)},
    onFalse={
     block(P..'curse','tbc.warlock.curse',P),
     spell(P..'unstable',30108,refresh(30108)),
     spell(P..'corruption',172,all(negate(own(172)),any({type='TALENT',layout='tree',tree=1,talent=2,operator='GREATERTHANOREQUALS',value=1},
      {type='TALENT_TREE_POINTS',tree=3,operator='LESSTHAN',value=31}))),
     spell(P..'siphon',18265,all(negate(own(18265)),any({type='DEBUFF',unit='target',spell=17800},all(negate({type='GROUP'}),tough)))),
     spell(P..'immolate',348,all(refresh(348),any({type='GROUP'},tough))),
    }},
   {id=P..'solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    spell(P..'solo-tap',1454,all(pct('MANAPCT','LESSTHAN',.5),pct('HEALTHPCT','GREATERTHAN',.6))),
    spell(P..'drain-life',689)}},
   block(P..'filler','tbc.warlock.filler',P),
  },
 },
}))
