-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.shaman.{unspecialized,elemental,enhancement,enhancement.simulator,enhancement.icyveins,
-- restoration,restoration.hekili}. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are
-- the consumers'; see premade-research progression/shaman.md. Totem slots: 1 Fire, 2 Earth, 3 Water, 4 Air.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function imbue(enchant,offhand)return{type='WEAPON_IMBUE',enchant=enchant,offhand=offhand or nil}end
local function stacks(id,n)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182))
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
-- Manual casts and channels, and Ghost Wolf, end advice with Attack suppressed.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.manual',revision=3,families={'progression'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.ownBuff(2645))},
}}))
-- Damage premades: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.manual-target',revision=2,families={'progression'},class='SHAMAN',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.ownBuff(2645),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Lightning Shield whenever your own is missing (every damage dealer and the catch-all).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.lightning-shield',revision=1,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('lightning-shield',324,BuiltinConditions.negate(BuiltinConditions.ownBuff(324))),
}}))
-- Every specialization: Wind Shear, Stormlash under any Bloodlust/Heroism in a group, your own Bloodlust on a
-- group boss while nobody is Sated/Exhausted, Astral Shift when low.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.group',revision=1,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('wind-shear',57994,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('stormlash',120668,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},lust)),
 BuiltinConditions.spell('bloodlust',2825,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.classified('worldboss'),BuiltinConditions.negate({type='DEBUFF',unit='player',spell=57724}),
  BuiltinConditions.negate({type='DEBUFF',unit='player',spell=57723}),BuiltinConditions.negate({type='DEBUFF',unit='player',spell=80354}),BuiltinConditions.negate({type='DEBUFF',unit='player',spell=95809}))),
 BuiltinConditions.spell('astral-shift',108271,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35})),
}}))
-- Damage dealers' fire totems: Searing while the fire slot is empty (never over Fire Elemental or Magma); Fire
-- Elemental on an elite or boss, under Bloodlust, or on cooldown with Primal Elementalist; Earth Elemental
-- (off by default) on a boss without Fire Elemental.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.fire-totems',revision=1,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='TOTEM',spell=1}))),
 BuiltinConditions.spell('fire-elemental',2894,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),lust,{type='TALENT',layout='grid',value=17}))),
 {id='earth-elemental',type='spell',action=2062,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.classified('worldboss'),BuiltinConditions.negate({type='TOTEM_SPELL',spell=2894}))},
}}))
-- Enhancement upkeep for every source: Windfury on the main hand (Flametongue before Windfury is learned),
-- Flametongue on an off-hand weapon (read by item type) once the main hand is done; Feral Spirit; Ascendance right after
-- Stormstrike; Elemental Mastery when Ascendance or Fire Elemental is just about ready or far away;
-- Ancestral Swiftness for an instant spender when Maelstrom Weapon is low.
local function sync(id)return BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(id)),{type='SPELL_COOLDOWN',spell=id,operator='LESSTHAN',value=4},{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=85})end
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.enhancement-upkeep',revision=2,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('windfury-weapon',8232,BuiltinConditions.negate(imbue(283))),
 BuiltinConditions.spell('flametongue-main',8024,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(8232)),BuiltinConditions.negate(imbue(5)))),
 BuiltinConditions.spell('flametongue-off',8024,BuiltinConditions.all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},BuiltinConditions.negate(imbue(5,true)),
  BuiltinConditions.any(imbue(283),BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(8232)),imbue(5))))),
 BuiltinConditions.spell('feral-spirit',51533,BuiltinConditions.combat()),
 BuiltinConditions.spell('ascendance',114049,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.ownBuff(114051)),{type='SPELL_COOLDOWN',spell=17364,operator='GREATERTHANOREQUALS',value=3})),
 BuiltinConditions.spell('elemental-mastery',16166,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(sync(114049),sync(2894)))),
 BuiltinConditions.spell('ancestral-swiftness',16188,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(stacks(53817,2)))),
}}))
-- The Wowhead/simulator Enhancement pack arm (two or more engaged enemies; rejoins the single-target list):
-- Magma at six instead of Searing, Fire Nova at four once Lava Lash has spread Flame Shock, Chain Lightning at
-- five Maelstrom Weapon (three when it finishes before the next swing), Lava Lash on a Flame Shocked target.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.enhancement-aoe',revision=1,families={'progression'},class='SHAMAN',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  BuiltinConditions.spell('magma-totem',8190,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=6},BuiltinConditions.negate({type='TOTEM_SPELL',spell=2894}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=8190}))),
  BuiltinConditions.spell('fire-nova',1535,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},flame)),
  BuiltinConditions.spell('chain-lightning',421,BuiltinConditions.any(stacks(53817,5),BuiltinConditions.all(stacks(53817,3),{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=1.1}))),
  BuiltinConditions.spell('lava-lash',60103,flame),
 }},
}}))
-- Restoration upkeep for every source: Water Shield (Lightning Shield before 20), Earthliving on the main hand,
-- Earth Shield on your focus.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.restoration-upkeep',revision=1,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('water-shield',52127,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(52127)),BuiltinConditions.negate(BuiltinConditions.ownBuff(324)))),
 BuiltinConditions.spell('lightning-shield',324,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(52127)),BuiltinConditions.negate(BuiltinConditions.ownBuff(324)))),
 BuiltinConditions.spell('earthliving',51730,BuiltinConditions.negate(imbue(3345))),
 BuiltinConditions.spell('earth-shield-focus',974,BuiltinConditions.all({type='FRIENDLY',unit='focus'},BuiltinConditions.negate({type='BUFF',unit='focus',spell=974,ownbuff=true}))),
}}))
-- Restoration damage on an attackable target (solo levelling and quiet moments): Flame Shock on a target that
-- will live, Lava Burst into it, Elemental Blast, Lightning Bolt (Telluric Currents returns mana).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.restoration-damage',revision=1,families={'progression'},class='SHAMAN',steps={
 BuiltinConditions.spell('flame-shock',8050,BuiltinConditions.all(BuiltinConditions.negate(flame),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6}))),
 BuiltinConditions.spell('lava-burst',51505,{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator='GREATERTHAN',value=2}),
 BuiltinConditions.spell('elemental-blast',117014),
 BuiltinConditions.spell('lightning-bolt',403),
}}))
