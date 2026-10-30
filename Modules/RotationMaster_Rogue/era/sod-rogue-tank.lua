-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Rogue tank, levels 1–60, chosen when the Just a Flesh Wound rune (which teaches
-- Tease) is engraved.
-- simulator/sod Phase 6 Main Gauche order with Icy Veins, Zockify and Warcraft Tavern: Riposte, Main
-- Gauche on cooldown, Blade Dance from one point and refreshed from three, Slice and Dice from
-- three (refreshed from four), Fan of Knives, Crimson Tempest and Blunderbuss on three engaged
-- enemies, Blunderbuss while Blade Dance is up, Eviscerate at five with both buffs up, Poisoned
-- Knife at low energy, builder Saber Slash, Mutilate or Sinister Strike. Reminders: Tease when
-- the target is not on you, Kick, Evasion, Blade Flurry, Adrenaline Rush, Thistle Tea, poisons.
-- Shared parts: era/blocks.lua. Left manual: Shadowstep, Sebacious Poison duty and positioning.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function remain(id,n)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHAN',value=n}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local instant={8928,8927,8926,6950,6949,6947}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.tank',revision=6,
 blocks={['era.rogue.boundaries']=3},
 applicability={families={'era'},actionContext='player',class='ROGUE',rulesets={'season:2'}},
 tags={'tank','melee','endgame','aoe','season-of-discovery','icy-veins','zockify','warcraft-tavern'},
 sources={
 {url='https://www.icy-veins.com/wow-classic/combat-rogue-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Combat Rogue tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.zockify.com/wowclassic/rogue/tank/',title='Zockify: SoD Rogue tank (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-10'},
 {url='https://www.warcrafttavern.com/wow-classic-sod/guides/combat-rogue-tank/',title='Warcraft Tavern: SoD Combat Rogue tank (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=60,switch={type='RUNE_ENGRAVED',spell=400014},
 cooldowns={
  item('rogue-tank-mainhand-poison',instant,BuiltinConditions.negate({type='WEAPON'})),
  item('rogue-tank-offhand-poison',instant,BuiltinConditions.all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},BuiltinConditions.negate({type='WEAPON',offhand=true}))),
  BuiltinConditions.spell('rogue-tank-tease',410412,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(tanked))),
  BuiltinConditions.spell('rogue-tank-tease-alt',1219355,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(tanked))),
  BuiltinConditions.spell('rogue-tank-kick',1766,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
  BuiltinConditions.spell('rogue-tank-evasion',5277,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
  BuiltinConditions.spell('rogue-tank-blade-flurry',13877,BuiltinConditions.all(BuiltinConditions.combat(),own(5171))),
  BuiltinConditions.spell('rogue-tank-adrenaline-rush',13750,BuiltinConditions.combat()),
  item('rogue-tank-thistle-tea',{7676},BuiltinConditions.all(BuiltinConditions.combat(),energy('LESSTHANOREQUALS',10))),
 },
 rotation={
 block('era.rogue.boundaries','rogue-tank-'),
 BuiltinConditions.spell('rogue-tank-riposte',14251),
 BuiltinConditions.spell('rogue-tank-main-gauche',424919),
 BuiltinConditions.spell('rogue-tank-blade-dance',400012,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(own(400012)))),
 BuiltinConditions.spell('rogue-tank-blade-dance-refresh',400012,BuiltinConditions.all(points('GREATERTHANOREQUALS',3),remain(400012,2))),
 BuiltinConditions.spell('rogue-tank-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',3),BuiltinConditions.negate(own(5171)))),
 BuiltinConditions.spell('rogue-tank-slice-refresh',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',4),remain(5171,1))),
 {id='rogue-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('rogue-tank-aoe-fan-of-knives',409240),
  BuiltinConditions.spell('rogue-tank-aoe-crimson-tempest',412096,BuiltinConditions.all(points('GREATERTHANOREQUALS',4),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=436611,owndebuff=true}))),
  BuiltinConditions.spell('rogue-tank-aoe-blunderbuss',436564),
 }},
 BuiltinConditions.spell('rogue-tank-blunderbuss',436564,BuiltinConditions.all(own(400012),energy('LESSTHAN',70),points('LESSTHAN',4))),
 BuiltinConditions.spell('rogue-tank-kill-shot',2098,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',3))),
 {id='rogue-tank-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-tank-eviscerate',2098,BuiltinConditions.all(own(400012),own(5171))),
  {id='rogue-tank-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-tank-poisoned-knife',425012,energy('LESSTHANOREQUALS',30)),
 BuiltinConditions.spell('rogue-tank-saber-slash',424785),
 BuiltinConditions.spell('rogue-tank-mutilate',399956),
 BuiltinConditions.spell('rogue-tank-sinister',1752),
 }},
}))
