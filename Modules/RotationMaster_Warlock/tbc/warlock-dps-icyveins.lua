-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warlock, every talent tree, levels 1–70; the default Warlock premade. One loop for all
-- trees: curse, the tree's DoTs, one filler, Life Tap. Differences come from learned spells
-- and talents (Unstable Affliction, Siphon Life, Incinerate, Seed, sacrifice buffs).
-- Solo it wands and drains when hurt (Icy Veins); in a group Immolate is cast only by a
-- Destruction build or when a Fire Mage's Improved Scorch is up (Icy Veins, MaxDps), and Siphon
-- Life in a raid only under Improved Shadow Bolt (Wowhead, simulator). Cast-time DoTs are
-- refreshed about one cast before they expire (Wowhead). Thresholds are RM policy.
-- The Wowhead drain-tank variant is rm.tbc.warlock.dps.wowhead.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function refresh(id)return any(negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function pct(kind,op,v)return{type=kind,unit='player',operator=op,value=v}end
local function destruction(op)return{type='TALENT_TREE_POINTS',tree=3,operator=op,value=31}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='warlock-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warlock.dps.icyveins',revision=5,
 blocks={['tbc.warlock.boundaries']=3,['tbc.warlock.procs']=1,['tbc.warlock.moving']=2,['tbc.warlock.curse']=2,['tbc.warlock.aoe']=1,
  ['tbc.warlock.finishers']=1,['tbc.warlock.filler']=2,['tbc.warlock.armor']=1,['tbc.warlock.upkeep']=1},
 nameKey='Default.TBC.Warlock.DpsIcyVeins.Name',descriptionKey='Default.TBC.Warlock.DpsIcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='WARLOCK'},
 tags={'affliction','demonology','destruction','icy-veins','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/affliction-warlock-leveling-guide',title='Icy Veins: Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/warlock-leveling-guide',title='Icy Veins: Warlock leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/affliction-warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Affliction Warlock rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/demonology-warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Demonology Warlock rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/destruction-warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Destruction Warlock rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/warlock/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Warlock DPS rotation (Siphon Life and refresh timing)',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://github.com/kaminaris/MaxDps-Warlock/tree/432c75e0dd45802eabaeee3cb472513392b9b83d/Specialization/TBC',title='MaxDps-Warlock TBC modules',reviewedAt='2026-10-23',revision='432c75e'},
  
  
 },
 body={
  priority=10,
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
     spell(P..'immolate',348,all(refresh(348),any(all(negate({type='GROUP'}),pct('MANAPCT','GREATERTHAN',.4)),
      {type='DEBUFF',unit='target',spell=22959},destruction('GREATERTHANOREQUALS')))),
     spell(P..'corruption',172,all(negate(own(172)),any({type='TALENT',layout='tree',tree=1,talent=2,operator='GREATERTHANOREQUALS',value=1},destruction('LESSTHAN')))),
     spell(P..'siphon',18265,all(negate(own(18265)),any(negate({type='GROUP',raid=true}),{type='DEBUFF',unit='target',spell=17800}))),
    }},
   {id=P..'solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    spell(P..'drain-life',689,pct('HEALTHPCT','LESSTHAN',.6)),
    spell(P..'solo-tap',1454,all(pct('MANAPCT','LESSTHAN',.35),pct('HEALTHPCT','GREATERTHAN',.65))),
    -- Wand when healthy, except deep Destruction builds, which fill with spells.
    {id=P..'wand',type='branch',conditions=all({type='SPELL_KNOWN',spell=5019},{type='TALENT_TREE_POINTS',tree=3,operator='LESSTHAN',value=21}),onFalse={},onTrue={
     stop(P..'wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell(P..'shoot',5019)}}}},
   block(P..'filler','tbc.warlock.filler',P),
  },
 },
}))
