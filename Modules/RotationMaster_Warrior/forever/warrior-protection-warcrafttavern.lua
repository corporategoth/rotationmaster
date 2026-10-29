-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Protection Warrior, Warcraft Tavern's debuff-upkeep list (player-chosen variant).
-- Same switch as the recommended tank (Defensive Stance), lower priority, off by default. Keeps
-- Thunder Clap, Demoralizing Shout (on casters too) and five Sunder Armors on every target first,
-- then Revenge, Rend and Shield Slam last; Heroic Strike or Cleave whenever affordable (rage is
-- secret on Forever, so the 60-rage threshold is left out). No Shield Block,
-- Victory Rush or defensive reminders: the source leaves them out. Shared parts:
-- Defaults/blocks/forever-warrior.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.protection.warcrafttavern',revision=6,
 blocks={['forever.warrior.boundaries']=3,['forever.warrior.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/forever/guides/protection-warrior/',title='Warcraft Tavern: Forever Protection Warrior',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/forever/guides/warrior-leveling/',title='Warcraft Tavern: Forever Warrior leveling (level 30 Protection)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',value=2}}},
 cooldowns={block('forever.warrior.upkeep','warrior-tavern-prot-'),
  BuiltinConditions.spell('warrior-tavern-prot-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2))),
  BuiltinConditions.spell('warrior-tavern-prot-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2)))},
 rotation={
 block('forever.warrior.boundaries','warrior-tavern-prot-'),
 BuiltinConditions.spell('warrior-tavern-prot-thunder-clap',6343,BuiltinConditions.negate(debuff(6343))),
 BuiltinConditions.spell('warrior-tavern-prot-demoralizing-shout',1160,BuiltinConditions.negate(debuff(1160))),
 BuiltinConditions.spell('warrior-tavern-prot-sunder',7386,BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5}),
  {type='DEBUFF_REMAIN',unit='target',spell=7386,anyrank=true,operator='LESSTHAN',value=3})),
 BuiltinConditions.spell('warrior-tavern-prot-revenge',6572),
 BuiltinConditions.spell('warrior-tavern-prot-rend',772,BuiltinConditions.negate(debuff(772,true))),
 BuiltinConditions.spell('warrior-tavern-prot-shield-slam',23922),
 }},
}))
