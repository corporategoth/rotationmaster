-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Warrior melee DPS, Warcraft Tavern's spend-rage list (player-chosen variant).
-- Same switch as the recommended DPS premade, lower priority, off by default. Group and raid play
-- that always spends: five Sunder Armors on every target first, Execute above everything (it can
-- be cast only below 20%), Overpower, Rend (until Bloodthirst), Mortal Strike, Bloodthirst,
-- Whirlwind, Spearing Strike on cooldown, Slam only with Improved Slam (the override that keeps
-- the swing); Heroic Strike or Cleave whenever affordable (rage is secret on Forever, so the
-- 60-rage threshold and the spare-rage Hamstring are left out); Recklessness on cooldown with
-- Death Wish paired to it. No Victory Rush, Demoralizing Shout, Thunder Clap or pack section: the source
-- lists none. Shared parts: Defaults/blocks/forever-warrior.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.dps.warcrafttavern',revision=6,
 blocks={['forever.warrior.boundaries']=3,['forever.warrior.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/forever/guides/arms-warrior/',title='Warcraft Tavern: Forever Arms Warrior',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/forever/guides/fury-warrior/',title='Warcraft Tavern: Forever Fury Warrior',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/forever/guides/warrior-leveling/',title='Warcraft Tavern: Forever Warrior leveling',reviewedAt='2026-10-23'}},
 body={priority=5,disabled=true,
 cooldowns={block('forever.warrior.upkeep','warrior-tavern-'),
  BuiltinConditions.spell('warrior-tavern-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2))),
  BuiltinConditions.spell('warrior-tavern-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2))),
  BuiltinConditions.spell('warrior-tavern-recklessness',1719,BuiltinConditions.combat()),
  BuiltinConditions.spell('warrior-tavern-death-wish',12328,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(1719)),{type='BUFF',unit='player',spell=1719},
   {type='SPELL_COOLDOWN',spell=1719,operator='GREATERTHAN',value=180})))},
 rotation={
 block('forever.warrior.boundaries','warrior-tavern-'),
 BuiltinConditions.spell('warrior-tavern-sunder',7386,BuiltinConditions.negate({type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5})),
 BuiltinConditions.spell('warrior-tavern-execute',5308),
 BuiltinConditions.spell('warrior-tavern-overpower',7384),
 BuiltinConditions.spell('warrior-tavern-rend',772,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(23881)),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}))),
 BuiltinConditions.spell('warrior-tavern-mortal-strike',12294),
 BuiltinConditions.spell('warrior-tavern-bloodthirst',23881),
 BuiltinConditions.spell('warrior-tavern-whirlwind',1680),
 BuiltinConditions.spell('warrior-tavern-spearing-strike',1310222),
 BuiltinConditions.spell('warrior-tavern-improved-slam',1310196,BuiltinConditions.negate({type='MOVING'})),
 }},
}))
