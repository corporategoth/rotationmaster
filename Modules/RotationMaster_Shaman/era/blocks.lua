-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era Shaman blocks, vanilla and Season of Discovery (Built In composition;
-- authoring-time only). Consumers: rm.era.shaman.enhancement, .enhancement.warcrafttavern,
-- .elemental, .elemental.simulator, .restoration, .restoration.warcrafttavern and
-- rm.sod.shaman.enhancement, .elemental, .restoration, .tank. A content change needs a block
-- revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/shaman.md. Totem slots: 1 Fire,
-- 2 Earth, 3 Water, 4 Air. IDs are Era 1.15.9 client data and SoD rune spells; verify in game.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
-- A fight worth a totem: a group, an elite or boss, or a target forecast to live 20 seconds.
local long=BuiltinConditions.any({type='GROUP'},big,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20})
-- Manual casts and channels, and Ghost Wolf, end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.manual',revision=3,families={'era'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645))},
}}))
-- Damage premades: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.manual-target',revision=2,families={'era'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Earth Shock interrupts an interruptible cast or channel (every source).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.interrupt',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('interrupt',8042,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
-- A shield: Water Shield once engraved (Season of Discovery), otherwise Lightning Shield.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.shield',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('water-shield',408510,BuiltinConditions.negate(BuiltinConditions.any(buff(408510),buff(324)))),
 BuiltinConditions.spell('lightning-shield',324,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(408510)),BuiltinConditions.negate(buff(324)))),
}}))
-- Solo healing: Healing Wave between pulls when below 60%, and in combat an emergency Lesser
-- Healing Wave (Healing Wave before it is learned) below 30%.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.self-heal',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('heal-after-pull',331,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}),health('player','LESSTHAN',.6))),
 BuiltinConditions.spell('emergency-lesser-wave',8004,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),health('player','LESSTHAN',.3))),
 BuiltinConditions.spell('emergency-wave',331,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(BuiltinConditions.known(8004)),health('player','LESSTHAN',.3))),
}}))
-- Melee totems, each while its slot is empty in combat: Strength of Earth and Searing on long
-- fights, Windfury Totem in a group (Grace of Air solo), Mana Spring in a group (Healing Stream
-- solo on long fights).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.melee-totems',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('strength-of-earth',8075,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(2)),long)),
 BuiltinConditions.spell('searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)),enemies('LESSTHAN',3),long)),
 BuiltinConditions.spell('windfury-totem',8512,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(4)))),
 BuiltinConditions.spell('grace-of-air',8835,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(totem(4)),long)),
 BuiltinConditions.spell('mana-spring',5675,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(3)))),
 BuiltinConditions.spell('healing-stream',5394,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(totem(3)),long)),
}}))
-- Caster totems in combat: Searing on one enemy for a long fight, Magma on packs, Mana Spring in a
-- group (Healing Stream solo on long fights).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.caster-totems',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)),enemies('LESSTHAN',2),long)),
 BuiltinConditions.spell('magma-totem',8190,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)),enemies('GREATERTHANOREQUALS',2))),
 BuiltinConditions.spell('mana-spring',5675,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(3)))),
 BuiltinConditions.spell('healing-stream',5394,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(totem(3)),long)),
}}))
-- Cleansing a friendly target: Cure Poison, Cure Disease.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.cures',revision=1,families={'era'},class='SHAMAN',steps={
 BuiltinConditions.spell('cure-poison',526,{type='DISPELLABLE',unit='target',debufftype='Poison'}),
 BuiltinConditions.spell('cure-disease',2870,{type='DISPELLABLE',unit='target',debufftype='Disease'}),
}}))
-- A healer's damage on a hostile target (leveling): no target stops; Earth Shock interrupts;
-- Chain Lightning on packs; Flame Shock when yours is missing; Lightning Bolt from range while
-- standing; then melee.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.healer-damage',revision=2,families={'era'},class='SHAMAN',steps={
 {id='no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 BuiltinConditions.spell('interrupt',8042,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('chain-lightning',421,enemies('GREATERTHANOREQUALS',2)),
 BuiltinConditions.spell('flame-shock',8050,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),BuiltinConditions.any(big,health('target','GREATERTHAN',.5)))),
 BuiltinConditions.spell('lightning-bolt',403,BuiltinConditions.all({type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))),
}}))
