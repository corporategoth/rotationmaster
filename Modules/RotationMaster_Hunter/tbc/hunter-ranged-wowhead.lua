-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Hunter ranged DPS, levels 1–70, Wowhead raid shot policy (alternative variant).
-- Same switch and shared blocks as the simulator variant (Defaults/blocks/hunter.lua). Differs where
-- Wowhead differs once Steady Shot is learned: Multi-Shot and Steady Shot after each Auto Shot
-- only (no Arcane Shot filler, no Serpent Sting), Arcane Shot only while moving, and no Aspect of
-- the Viper (Wowhead uses mana potions instead); Hawk is always the aspect reminder.
-- Left manual: melee weaving, pet commands and Misdirection, traps, Volley, Feign Death,
-- ammunition and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.ranged.wowhead',revision=6,
 blocks={['tbc.hunter.opening']=4,['tbc.hunter.leveling']=2,['tbc.hunter.upkeep']=1},
 nameKey="Ranged DPS (Wowhead)",descriptionKey="Levels 1–70, every spec, following Wowhead's raid advice. Same pull, melee, leveling shots, multi-target Multi-Shot and reminders as the simulator version, but once Steady Shot is learned it only offers Multi-Shot and Steady Shot after each Auto Shot: no Arcane Shot filler (except while moving), no Serpent Sting and no Aspect of the Viper reminder. Pet commands, Misdirection, traps, Volley, melee weaving and Feign Death stay with you. An alternative to the recommended simulator ranged premade, off by default: enable it and disable that one, or raise its priority.",
 applicability={families={'tbc'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','leveling','endgame','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/hunter/dps-rotation-cooldowns-abilities-pve',title='Wowhead: TBC Hunter DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-02-10'},
 {url='https://www.wowhead.com/tbc/guide/classes/hunter/beast-mastery/leveling-tips',title='Wowhead: TBC Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
 {url='https://www.wowhead.com/tbc/guide/classes/hunter/leveling-tips',title='Wowhead: TBC Hunter leveling',reviewedAt='2026-10-23',revision='2026-09-04'}},
 body={priority=5,disabled=true,
 cooldowns={block('tbc.hunter.upkeep','hunter-'),
  spell('hunter-hawk',13165,all(negate(buff(13165)),
   any({type='COMBAT',unit='player'},all(negate(buff(5118)),negate(buff(13159)),negate(buff(20043)),negate(buff(13161))))))},
 rotation={
 block('tbc.hunter.opening','hunter-'),
 {id='hunter-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('hunter-moving-multi-shot',2643),
  spell('hunter-moving-arcane-shot',3044),
  {id='hunter-moving-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='hunter-steady',type='branch',conditions={type='SPELL_KNOWN',spell=34120},onTrue={
  spell('hunter-multi-shot',2643),
  spell('hunter-steady-shot',34120,{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=.5}),
  {id='hunter-wait-auto',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('tbc.hunter.leveling','hunter-leveling-')}},
 }},
}))
