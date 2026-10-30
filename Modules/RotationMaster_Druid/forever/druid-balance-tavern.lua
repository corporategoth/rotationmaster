-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Balance Druid after Warcraft Tavern's Multi-DoT leveling build, levels 1–60: a
-- player-chosen alternative to rm.forever.druid.balance (same switch, lower priority, off by
-- default). DoT the
-- target, root it once both DoTs run while another enemy is on you, then Wrath; no Starfire
-- (the build skips Eclipse). Tabbing to the next enemy stays with the player.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id,mine)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=mine}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.balance.tavern',revision=6,
 blocks={['forever.druid.boundaries']=3,['forever.druid.upkeep']=1},
 applicability={families={'forever'},actionContext='player',class='DRUID'},
 tags={'balance','leveling','multi-dot','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/balance-druid/',title='Warcraft Tavern: Forever Balance Druid (Multi-DoT build)',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/forever/guides/druid-leveling/',title='Warcraft Tavern: Forever Druid leveling',reviewedAt='2026-10-23'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs and ranks only.'},
 },
 body={priority=5,disabled=true,
  cooldowns={BuiltinConditions.block('dot-upkeep','forever.druid.upkeep','dot-')},
  rotation={
   BuiltinConditions.block('dot-boundaries','forever.druid.boundaries','dot-'),
   stop('dot-target',BuiltinConditions.negate({type='ATTACKABLE',unit='target'}),true),
   {id='dot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={BuiltinConditions.spell('dot-pull-wrath',5176),stop('dot-pull-stop')}},
   BuiltinConditions.spell('dot-moonfire',8921,BuiltinConditions.negate(dot(8921,true))),
   BuiltinConditions.spell('dot-insect-swarm',5570,BuiltinConditions.negate(dot(5570,true))),
   BuiltinConditions.spell('dot-roots',339,BuiltinConditions.all(dot(8921,true),dot(5570,true),BuiltinConditions.negate(dot(339)),
    {type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('dot-wrath',5176),
  },
 },
}))
