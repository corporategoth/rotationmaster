-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Hunter ranged DPS, levels 1–70, simulator/rotationtools shot timing (the recommended variant).
-- One premade for every spec: spec spells (Aimed Shot, Bestial Wrath, Trueshot Aura, Readiness,
-- Silencing Shot) are offered once known. Before Steady Shot: own sting, then mana-gated shots.
-- From Steady Shot: Multi-Shot when ready, Steady Shot straight after an Auto Shot, Arcane Shot
-- when a Steady would clip the next Auto, Serpent Sting only solo or while moving (Icy Veins).
-- Viper below 20% mana in combat, back to Hawk at 50%. The Wowhead variant drops Arcane/Sting/Viper.
-- Shared parts: Defaults/blocks/hunter.lua. Left manual: melee weaving, pet commands and
-- Misdirection, traps, Volley, Feign Death, ammunition and positioning.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local stingless=BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.ranged.simulator',revision=5,
 blocks={['tbc.hunter.opening']=4,['tbc.hunter.leveling']=2,['tbc.hunter.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','leveling','endgame','icy-veins'},
 sources={
 {url='https://diziet559.github.io/rotationtools/',title='diziet559 rotationtools: TBC Hunter shot rotations',reviewedAt='2026-10-23',revision='2bd1759b0e0d04bea7b4bb3a4dc356f484423ced'},
 {url='https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Beast Mastery Hunter rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/hunter-leveling-guide',title='Icy Veins: Hunter leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=10,
 cooldowns={block('tbc.hunter.upkeep','hunter-'),
  BuiltinConditions.spell('hunter-viper',34074,BuiltinConditions.all({type='COMBAT',unit='player'},mana('LESSTHAN',.2),BuiltinConditions.negate(buff(34074)))),
  BuiltinConditions.spell('hunter-hawk',13165,BuiltinConditions.all(BuiltinConditions.negate(buff(13165)),BuiltinConditions.any(BuiltinConditions.negate(buff(34074)),mana('GREATERTHANOREQUALS',.5)),
   BuiltinConditions.any({type='COMBAT',unit='player'},BuiltinConditions.all(BuiltinConditions.negate(buff(5118)),BuiltinConditions.negate(buff(13159)),BuiltinConditions.negate(buff(20043)),BuiltinConditions.negate(buff(13161))))))},
 rotation={
 block('tbc.hunter.opening','hunter-'),
 {id='hunter-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('hunter-moving-multi-shot',2643),
  BuiltinConditions.spell('hunter-moving-arcane-shot',3044),
  BuiltinConditions.spell('hunter-moving-serpent-sting',1978,stingless),
  {id='hunter-moving-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='hunter-steady',type='branch',conditions={type='SPELL_KNOWN',spell=34120},onTrue={
  BuiltinConditions.spell('hunter-multi-shot',2643),
  BuiltinConditions.spell('hunter-steady-shot',34120,{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=.5}),
  BuiltinConditions.spell('hunter-arcane-shot',3044,BuiltinConditions.any(mana('GREATERTHAN',.5),BuiltinConditions.negate({type='SPELL_KNOWN',spell=34074}))),
  BuiltinConditions.spell('hunter-serpent-sting',1978,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),stingless,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3})),
  {id='hunter-wait-auto',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('tbc.hunter.leveling','hunter-leveling-')}},
 }},
}))
