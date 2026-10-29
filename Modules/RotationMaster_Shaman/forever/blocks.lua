-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.shaman.enhancement, .enhancement.wowhead, .elemental and .restoration.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and
-- both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/shaman.md.
-- Totem slots: 1 Fire, 2 Earth, 3 Water, 4 Air. IDs are beta data; verify in game.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
-- Manual casts and channels, and Ghost Wolf (any of its three IDs), end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.manual',revision=3,families={'forever'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645),buff(415233),buff(1238640))},
}}))
-- Damage premades: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.manual-target',revision=2,families={'forever'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645),buff(415233),buff(1238640),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Every Shaman: a shield (Water Shield once talented, else Lightning Shield; mana is secret on
-- Forever, so it is refreshed in combat too) and the Earth Shock interrupt.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.upkeep',revision=2,families={'forever'},class='SHAMAN',steps={
 BuiltinConditions.spell('water-shield',408510,BuiltinConditions.negate(BuiltinConditions.any(buff(408510),buff(324)))),
 BuiltinConditions.spell('lightning-shield',324,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(408510)),BuiltinConditions.negate(buff(324)))),
 BuiltinConditions.spell('interrupt',8042,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
-- Main-hand imbue (Forever has no Shaman Dual Wield): Windfury once known, else Flametongue,
-- else Rockbiter. A learned better imbue is never replaced by a lower one.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.imbue',revision=1,families={'forever'},class='SHAMAN',steps={
 BuiltinConditions.spell('windfury-weapon',8232,BuiltinConditions.negate({type='WEAPON'})),
 BuiltinConditions.spell('flametongue-weapon',8024,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.negate(BuiltinConditions.known(8232)))),
 BuiltinConditions.spell('rockbiter-weapon',8017,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.negate(BuiltinConditions.known(8232)),BuiltinConditions.negate(BuiltinConditions.known(8024)))),
}}))
-- Group buff totems (five-minute raid buffs in Forever), each only while its slot is empty.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.group-totems',revision=1,families={'forever'},class='SHAMAN',steps={
 BuiltinConditions.spell('strength-of-earth',8075,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(2)))),
 BuiltinConditions.spell('mana-spring',5675,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(3)))),
 BuiltinConditions.spell('windfury-totem',8512,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(4)))),
}}))
-- Caster area damage on three engaged enemies: Fire Nova at the Fire totem, then Chain Lightning.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.caster-aoe',revision=1,families={'forever'},class='SHAMAN',steps={
 {id='aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  BuiltinConditions.spell('fire-nova',408341,totem(1)),
  BuiltinConditions.spell('chain-lightning',421),
 }},
}}))
-- Stormcaller / Wavebreaker hybrids: Stormstrike in melee, then Earth Shock into its debuff.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.stormstrike-hybrid',revision=1,families={'forever'},class='SHAMAN',steps={
 BuiltinConditions.spell('stormstrike',17364,BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'})),
 BuiltinConditions.spell('stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
}}))
