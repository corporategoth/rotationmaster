-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Destruction Warlock, SimulationCraft's default list: the optimal reference,
-- disabled by default because Immolate, Backdraft, charges and cooldown timings are hidden in
-- Midnight combat (soul shards stay readable). Before the pull Soul Fire, Incinerate. Three or
-- more engaged enemies: Rain of Fire at 3+ shards, Cataclysm. Then Soul Fire at 4 shards or
-- fewer, Chaos Bolt only at 5 (to avoid capping), Conflagrate at two charges, Conflagrate below
-- 4 shards without Backdraft, Summon Infernal, Malevolence, Wither or Immolate in its last 30%,
-- Ruination, Cataclysm, Infernal Bolt at 3 shards or fewer, Incinerate.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return BuiltinConditions.any(BuiltinConditions.negate(dot(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v})end
local function shards(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.destruction.simc',revision=7,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'destruction','ranged','reference','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warlock_destruction.simc',title='SimulationCraft: Destruction Warlock default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={267},
  cooldowns={
   block('retail.warlock.upkeep','destrosc-'),
   BuiltinConditions.spell('destrosc-summon-imp',688,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(BuiltinConditions.ownBuff(196099)))),
  },
  rotation={
   block('retail.warlock.boundaries','destrosc-'),
   {id='destrosc-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('destrosc-pull-soul-fire',6353),
    BuiltinConditions.spell('destrosc-pull-incinerate',29722),
    {id='destrosc-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='destrosc-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('destrosc-aoe-rain-of-fire',5740,shards('GREATERTHANOREQUALS',3)),
    BuiltinConditions.spell('destrosc-aoe-cataclysm',152108),
   }},
   BuiltinConditions.spell('destrosc-soul-fire',6353,shards('LESSTHANOREQUALS',4)),
   BuiltinConditions.spell('destrosc-chaos-bolt-capped',116858,shards('GREATERTHANOREQUALS',5)),
   BuiltinConditions.spell('destrosc-conflagrate-capped',17962,{type='SPELL_CHARGES',spell=17962,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('destrosc-conflagrate',17962,BuiltinConditions.all(shards('LESSTHAN',4),BuiltinConditions.negate(BuiltinConditions.ownBuff(117828)))),
   BuiltinConditions.spell('destrosc-summon-infernal',1122),
   BuiltinConditions.spell('destrosc-malevolence',442726),
   BuiltinConditions.spell('destrosc-wither',445468,expiring(445474,5.4)),
   BuiltinConditions.spell('destrosc-immolate',348,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=445468}),expiring(157736,5.4))),
   BuiltinConditions.spell('destrosc-ruination',434635),
   BuiltinConditions.spell('destrosc-cataclysm',152108),
   BuiltinConditions.spell('destrosc-infernal-bolt',434506,shards('LESSTHANOREQUALS',3)),
   BuiltinConditions.spell('destrosc-incinerate',29722),
  },
 },
}))
