-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Enhancement Shaman, mana-efficient (Wowhead, with Mobalytics' dungeon list):
-- a player-chosen variant, off by default. Same switch as the recommended Enhancement premade,
-- lower priority.
-- Auto-attack carries the damage. Stormstrike only to fish for Improved Stormstrike's mana
-- regeneration (while that buff is down), no rotational Earth Shock (shocks pull and
-- interrupt), no Maelstrom step, and Searing Totem with Fire Nova on cooldown in groups and on
-- packs. Shared parts: Defaults/blocks/forever-shaman.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local stationary=BuiltinConditions.negate({type='MOVING'})
local ranged={type='BEYOND_MELEE',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.enhancement.wowhead',revision=6,
 blocks={['forever.shaman.manual-target']=2,['forever.shaman.upkeep']=2,['forever.shaman.imbue']=1},
 applicability={families={'forever'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','aoe','wowhead','mobalytics'},
 sources={{url='https://www.wowhead.com/forever/guide/classes/shaman/enhancement/level-30-dps-overview',title='Wowhead: Forever level 30 Enhancement Shaman',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://mobalytics.gg/wow-forever/classes/shaman-leveling-guide',title='Mobalytics: Forever Shaman leveling 1–30 (dungeon list)',reviewedAt='2026-10-23',revision='2026-10-21'}},
 body={priority=5,disabled=true,
 cooldowns={block('forever.shaman.upkeep','shaman-wh-'),block('forever.shaman.imbue','shaman-wh-'),
  BuiltinConditions.spell('shaman-wh-searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM',spell=1}),BuiltinConditions.any({type='GROUP'},enemies(3))))},
 rotation={
 block('forever.shaman.manual-target','shaman-wh-'),
 {id='shaman-wh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('shaman-wh-pull-bolt',403,BuiltinConditions.all(ranged,stationary)),
  BuiltinConditions.spell('shaman-wh-pull-shock',8042),
  {id='shaman-wh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('shaman-wh-fire-nova',408341,BuiltinConditions.all({type='TOTEM',spell=1},BuiltinConditions.any({type='GROUP'},enemies(3)))),
 BuiltinConditions.spell('shaman-wh-stormstrike',17364,BuiltinConditions.negate({type='BUFF',unit='player',spell=1238931})),
 BuiltinConditions.spell('shaman-wh-bolt',403,BuiltinConditions.all(ranged,stationary)),
 }},
}))
