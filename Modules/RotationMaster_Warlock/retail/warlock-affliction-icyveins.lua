-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Affliction Warlock, Icy Veins and SimulationCraft's default (Soul Harvester)
-- list: the optimal reference, disabled by default because DoT timers, Nightfall and Shard
-- Instability are hidden in Midnight combat (soul shards stay readable). Haunt before the pull.
-- Seed of Corruption on three or more engaged enemies without your Corruption; Haunt; Agony and
-- Corruption (Wither) under 3 s; Dark Harvest at two or fewer shards; Unstable Affliction at 5
-- shards; Malefic Grasp, then Shadow Bolt, on two Nightfall; Unstable Affliction on Shard
-- Instability or at 4 shards; Drain Soul; Shadow Bolt. Reminders: Summon Darkglare once Dark
-- Harvest is cooling, Malevolence, a Felhunter between pulls unless sacrificed.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return BuiltinConditions.any(BuiltinConditions.negate(dot(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v})end
local function shards(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.affliction.icyveins',revision=7,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'affliction','ranged','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/affliction-warlock-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Affliction Warlock rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warlock_affliction.simc',title='SimulationCraft: Affliction Warlock default list (SH_st)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={265},
  cooldowns={
   block('retail.warlock.upkeep','affiv-'),
   BuiltinConditions.spell('affiv-summon-felhunter',691,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(BuiltinConditions.ownBuff(196099)))),
   BuiltinConditions.spell('affiv-darkglare',205180,BuiltinConditions.all(fight,BuiltinConditions.negate({type='SPELL_AVAIL',spell=1257052}))),
   BuiltinConditions.spell('affiv-malevolence',442726,fight),
  },
  rotation={
   block('retail.warlock.boundaries','affiv-'),
   {id='affiv-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('affiv-pull-haunt',48181),
    {id='affiv-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   BuiltinConditions.spell('affiv-seed',27243,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.negate(dot(146739)),BuiltinConditions.negate(dot(445474)))),
   BuiltinConditions.spell('affiv-haunt',48181),
   BuiltinConditions.spell('affiv-agony',980,expiring(980,3)),
   BuiltinConditions.spell('affiv-wither',445468,expiring(445474,3)),
   BuiltinConditions.spell('affiv-corruption',172,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=445468}),expiring(146739,3))),
   BuiltinConditions.spell('affiv-dark-harvest',1257052,shards('LESSTHANOREQUALS',2)),
   BuiltinConditions.spell('affiv-unstable-capped',1259790,shards('GREATERTHANOREQUALS',5)),
   BuiltinConditions.spell('affiv-nightfall-grasp',1261153,{type='BUFF_STACKS',unit='player',spell=264571,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('affiv-nightfall-bolt',686,{type='BUFF_STACKS',unit='player',spell=264571,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('affiv-unstable-instability',1259790,BuiltinConditions.any(BuiltinConditions.ownBuff(1260269),shards('GREATERTHANOREQUALS',4))),
   BuiltinConditions.spell('affiv-drain-soul',198590),
   BuiltinConditions.spell('affiv-shadow-bolt',686),
  },
 },
}))
