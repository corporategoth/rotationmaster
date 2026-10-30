-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Hunter ranged DPS, levels 1–70, Wowhead raid shot policy (alternative variant).
-- Same switch and shared blocks as the simulator variant (Defaults/blocks/hunter.lua). Differs where
-- Wowhead differs once Steady Shot is learned: Multi-Shot and Steady Shot after each Auto Shot
-- only (no Arcane Shot filler, no Serpent Sting), Arcane Shot only while moving, and no Aspect of
-- the Viper (Wowhead uses mana potions instead); Hawk is always the aspect reminder.
-- Left manual: melee weaving, pet commands and Misdirection, traps, Volley, Feign Death,
-- ammunition and positioning.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.ranged.wowhead',revision=6,
 blocks={['tbc.hunter.opening']=4,['tbc.hunter.leveling']=2,['tbc.hunter.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','leveling','endgame','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/hunter/dps-rotation-cooldowns-abilities-pve',title='Wowhead: TBC Hunter DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-02-10'},
 {url='https://www.wowhead.com/tbc/guide/classes/hunter/beast-mastery/leveling-tips',title='Wowhead: TBC Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
 {url='https://www.wowhead.com/tbc/guide/classes/hunter/leveling-tips',title='Wowhead: TBC Hunter leveling',reviewedAt='2026-10-23',revision='2026-09-04'}},
 body={priority=5,disabled=true,
 cooldowns={block('tbc.hunter.upkeep','hunter-'),
  BuiltinConditions.spell('hunter-hawk',13165,BuiltinConditions.all(BuiltinConditions.negate(buff(13165)),
   BuiltinConditions.any({type='COMBAT',unit='player'},BuiltinConditions.all(BuiltinConditions.negate(buff(5118)),BuiltinConditions.negate(buff(13159)),BuiltinConditions.negate(buff(20043)),BuiltinConditions.negate(buff(13161))))))},
 rotation={
 block('tbc.hunter.opening','hunter-'),
 {id='hunter-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('hunter-moving-multi-shot',2643),
  BuiltinConditions.spell('hunter-moving-arcane-shot',3044),
  {id='hunter-moving-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='hunter-steady',type='branch',conditions={type='SPELL_KNOWN',spell=34120},onTrue={
  BuiltinConditions.spell('hunter-multi-shot',2643),
  BuiltinConditions.spell('hunter-steady-shot',34120,{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=.5}),
  {id='hunter-wait-auto',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('tbc.hunter.leveling','hunter-leveling-')}},
 }},
}))
