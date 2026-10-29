-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Elemental Shaman, simulator order (alternative premade; same switch, lower priority).
-- The only measured list: Chain Lightning on cooldown even on one target, Earth Shock while
-- Elemental Mastery is up, otherwise Lightning Bolt (simulator also drops to rank 4 below 30% mana,
-- which Rotation Master cannot pin). Same boundaries, interrupt and reminders as the recommended
-- premade (era/blocks.lua). Mana-hungry by design.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.elemental.simulator',revision=5,
 blocks={['era.shaman.manual-target']=2,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.caster-totems']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'dps','ranged','caster','endgame'},
 sources={},
 body={priority=21,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
 cooldowns={
  block('era.shaman.shield','ele-ws-'),
  block('era.shaman.caster-totems','ele-ws-'),
  BuiltinConditions.spell('ele-ws-elemental-mastery',16166,BuiltinConditions.combat()),
  block('era.shaman.self-heal','ele-ws-'),
 },
 rotation={
 block('era.shaman.manual-target','ele-ws-'),
 block('era.shaman.interrupt','ele-ws-'),
 BuiltinConditions.spell('ele-ws-chain-lightning',421),
 BuiltinConditions.spell('ele-ws-mastery-shock',8042,{type='BUFF',unit='player',spell=16166}),
 BuiltinConditions.spell('ele-ws-bolt',403),
 }},
}))
