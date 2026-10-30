-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Frost Mage, levels 10–90, in the Frost specialization
-- (64). simulator' order, which Method and wowtbc.gg share: Ice Lance at two Fingers of
-- Frost, Frostfire Bolt on Brain Freeze, the bomb, Frozen Orb, Ice Lance on one Fingers of Frost,
-- Frostbolt. From 87 a proc is held for Alter Time when it is less than 10 s away (spent anyway in
-- its last 3 s). Freeze is a highlight for the Water Elemental's ground-targeted root.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function fingers(op,v)return{type='BUFF_STACKS',unit='player',spell=44544,operator=op,value=v}end
local function close(yards,n)return{type='DISTANCE_COUNT',enemy=true,distance=yards,operator='GREATERTHANOREQUALS',value=n}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local ALTER,FLOES=108978,108839
-- Hold a proc for Alter Time only when it is learned, less than 10 s away and the proc has 3 s left.
local function spend(proc)return BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(ALTER)),{type='SPELL_COOLDOWN',spell=ALTER,operator='GREATERTHANOREQUALS',value=10},
 {type='BUFF_REMAIN',unit='player',spell=proc,operator='LESSTHAN',value=3})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.frost',revision=7,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-frost']=1,['mop.mage.bombs']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'frost','leveling','single-target','aoe','method'},
 sources={

  {url='https://www.method.gg/mop-classic/frost-mage-class-guide-mop-classic',title='Method: MoP Classic Frost Mage guide',reviewedAt='2026-10-23',notes='Phase 1 text.'},
  {url='https://wowtbc.gg/mop/class-guides/frost-mage',title='wowtbc.gg: MoP Classic Frost Mage PvE guide',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Frost Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Freeze on rootable targets, AoE and Blizzard, talent rows.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/frost/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Frost Mage rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
 },
 body={priority=30,specs={64},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.spell('frost-water-elemental',31687,BuiltinConditions.negate({type='PET'})),
   BuiltinConditions.block('frost-armor','mop.mage.armor-frost','frost-'),
   BuiltinConditions.block('frost-upkeep','mop.mage.upkeep','frost-'),
   {id='frost-mana-gem',type='item',action={36799,81901},conditions=BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.84),BuiltinConditions.negate(BuiltinConditions.buff(110909)))},
   BuiltinConditions.spell('frost-icy-veins',12472,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(ALTER)),{type='SPELL_AVAIL',spell=ALTER},{type='SPELL_COOLDOWN',spell=ALTER,operator='GREATERTHANOREQUALS',value=75}))),
   BuiltinConditions.spell('frost-alter-time',ALTER,BuiltinConditions.all(BuiltinConditions.combat(),fingers('GREATERTHANOREQUALS',2),BuiltinConditions.any(BuiltinConditions.buff(12472),BuiltinConditions.buff(131078)),BuiltinConditions.negate(BuiltinConditions.buff(110909)))),
   {id='frost-freeze',type='pet',action=33395,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(44544)),fingers('LESSTHAN',2)),BuiltinConditions.negate({type='CLASSIFICATION',unit='target',value='worldboss'}))},
   off('frost-presence-of-mind',12043,BuiltinConditions.combat()),
   off('frost-cold-snap',11958,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
  },
  rotation={
   BuiltinConditions.block('frost-boundaries','mop.mage.boundaries','frost-'),
   {id='frost-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('frost-pull-frostbolt',116),BuiltinConditions.spell('frost-pull-frostfire',44614),BuiltinConditions.stop('frost-pull-stop')}},
   BuiltinConditions.spell('frost-lance-capped',30455,fingers('GREATERTHANOREQUALS',2)),
   BuiltinConditions.spell('frost-brain-freeze',44614,BuiltinConditions.all(BuiltinConditions.buff(57761),spend(57761))),
   BuiltinConditions.block('frost-bombs','mop.mage.bombs','frost-'),
   {id='frost-aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
    BuiltinConditions.spell('frost-aoe-orb',84714),
    BuiltinConditions.spell('frost-aoe-cone',120,close(12,4)),
    BuiltinConditions.spell('frost-aoe-explosion',1449,close(10,5)),
    BuiltinConditions.spell('frost-aoe-blizzard',10,BuiltinConditions.all(enemies(4),BuiltinConditions.negate({type='MOVING'})))}},
   BuiltinConditions.spell('frost-orb',84714),
   BuiltinConditions.spell('frost-lance',30455,BuiltinConditions.all(BuiltinConditions.buff(44544),spend(44544))),
   {id='frost-moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(BuiltinConditions.buff(FLOES))),onFalse={},onTrue={
    BuiltinConditions.spell('frost-moving-lance',30455),BuiltinConditions.spell('frost-moving-fire-blast',2136),BuiltinConditions.stop('frost-moving-stop')}},
   BuiltinConditions.spell('frost-frostbolt',116),
   BuiltinConditions.spell('frost-frostfire',44614,BuiltinConditions.negate(BuiltinConditions.known(116))),
  },
 },
}))
