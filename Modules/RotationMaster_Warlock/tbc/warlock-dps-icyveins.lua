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
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function refresh(id)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function pct(kind,op,v)return{type=kind,unit='player',operator=op,value=v}end
local function destruction(op)return{type='TALENT_TREE_POINTS',tree=3,operator=op,value=31}end
local P='warlock-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warlock.dps.icyveins',revision=5,
 blocks={['tbc.warlock.boundaries']=3,['tbc.warlock.procs']=1,['tbc.warlock.moving']=2,['tbc.warlock.curse']=2,['tbc.warlock.aoe']=1,
  ['tbc.warlock.finishers']=1,['tbc.warlock.filler']=2,['tbc.warlock.armor']=1,['tbc.warlock.upkeep']=1},
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
     BuiltinConditions.spell(P..'immolate',348,BuiltinConditions.all(refresh(348),BuiltinConditions.any(BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),pct('MANAPCT','GREATERTHAN',.4)),
      {type='DEBUFF',unit='target',spell=22959},destruction('GREATERTHANOREQUALS')))),
     BuiltinConditions.spell(P..'corruption',172,BuiltinConditions.all(BuiltinConditions.negate(own(172)),BuiltinConditions.any({type='TALENT',layout='tree',tree=1,talent=2,operator='GREATERTHANOREQUALS',value=1},destruction('LESSTHAN')))),
     BuiltinConditions.spell(P..'siphon',18265,BuiltinConditions.all(BuiltinConditions.negate(own(18265)),BuiltinConditions.any(BuiltinConditions.negate({type='GROUP',raid=true}),{type='DEBUFF',unit='target',spell=17800}))),
    }},
   {id=P..'solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'drain-life',689,pct('HEALTHPCT','LESSTHAN',.6)),
    BuiltinConditions.spell(P..'solo-tap',1454,BuiltinConditions.all(pct('MANAPCT','LESSTHAN',.35),pct('HEALTHPCT','GREATERTHAN',.65))),
    -- Wand when healthy, except deep Destruction builds, which fill with spells.
    {id=P..'wand',type='branch',conditions=BuiltinConditions.all({type='SPELL_KNOWN',spell=5019},{type='TALENT_TREE_POINTS',tree=3,operator='LESSTHAN',value=21}),onFalse={},onTrue={
     BuiltinConditions.stop(P..'wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),BuiltinConditions.spell(P..'shoot',5019)}}}},
   BuiltinConditions.block(P..'filler','tbc.warlock.filler',P),
  },
 },
}))
