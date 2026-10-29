-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Rogue blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.rogue.{assassination,assassination.icyveins,combat,combat.icyveins,combat.hekili,subtlety,
-- subtlety.warcrafttavern,unspecialized}. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the
-- consumers'; see premade-research progression/rogue.md. MoP poisons are player auras, not weapon enchants (the
-- 5.5.4 SpellItemEnchantment table has none), so poison upkeep reads BUFF. Backstab and Dispatch need a dagger in
-- the main hand (5.5.4 tooltips), read as weapon subclass 15; Ambush and Mutilate do not.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local sliced=BuiltinConditions.ownBuff(5171)
local enemies=function(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
-- Manual casts and channels (a poison takes three seconds) and no attackable target end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.boundaries',revision=3,families={'progression'},class='ROGUE',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Out of combat with a target and not stealthed (the opener Branch comes first): Stealth, then stop; Attack still
-- shows when Stealth is not ready, so a body pull works.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.out-of-combat',revision=3,families={'progression'},class='ROGUE',steps={
 {id='ooc',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('ooc-stealth',1784),
  {id='ooc-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Solo levelling (Icy Veins): Recuperate at three points when hurt, Kidney Shot when low and the mob is on you.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.solo',revision=2,families={'progression'},class='ROGUE',steps={
 {id='solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  BuiltinConditions.spell('recuperate',73651,BuiltinConditions.all(points('GREATERTHANOREQUALS',3),health('LESSTHAN',.9),BuiltinConditions.negate(BuiltinConditions.ownBuff(73651)))),
  BuiltinConditions.spell('kidney-shot',408,BuiltinConditions.all(points('GREATERTHANOREQUALS',3),health('LESSTHAN',.4),tanked)),
 }},
}}))
-- Independent reminders every spec shares: Deadly Poison when no lethal poison is up (and topped up out of combat
-- under ten minutes), Leeching Poison when talented else Crippling when no non-lethal poison is up (a manual
-- Mind-numbing or Paralytic choice is kept), Kick, Shadowstep from range, Evasion solo when low. Tricks of the
-- Trade (needs a target macro) and Expose Armor (a raid assignment) ship off.
local nonlethal=BuiltinConditions.any(BuiltinConditions.ownBuff(108211),BuiltinConditions.ownBuff(3408),BuiltinConditions.ownBuff(5761),BuiltinConditions.ownBuff(108215))
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.upkeep',revision=1,families={'progression'},class='ROGUE',steps={
 BuiltinConditions.spell('lethal-poison',2823,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(2823)),BuiltinConditions.negate(BuiltinConditions.ownBuff(8679)))),
 BuiltinConditions.spell('lethal-refresh',2823,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BUFF_REMAIN',unit='player',spell=2823,ownbuff=true,operator='LESSTHAN',value=600})),
 BuiltinConditions.spell('leeching-poison',108211,BuiltinConditions.negate(nonlethal)),
 BuiltinConditions.spell('crippling-poison',3408,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(108211)),BuiltinConditions.negate(nonlethal))),
 BuiltinConditions.spell('kick',1766,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('shadowstep',36554,BuiltinConditions.all(BuiltinConditions.combat(),{type='BEYOND_MELEE',unit='target'})),
 BuiltinConditions.spell('evasion',5277,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),health('LESSTHAN',.4),tanked)),
 off('tricks',57934,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})),
 off('expose-armor',8647,BuiltinConditions.all({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=113746}))),
}}))
-- Assassination stealth opener: Cheap Shot on a solo pull, Dispatch on Blindside with a dagger, Mutilate (raid and
-- after Vanish).
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.assassination-opener',revision=3,families={'progression'},class='ROGUE',steps={
 {id='stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  BuiltinConditions.spell('stealth-cheap-shot',1833,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(BuiltinConditions.combat()))),
  BuiltinConditions.spell('stealth-dispatch',111240,BuiltinConditions.all({type='WEAPON_TYPE',slot='mainhand',subclass=15},BuiltinConditions.ownBuff(121153))),
  BuiltinConditions.spell('stealth-mutilate',1329),
  {id='stealth-stop',type='stop',suppress_attack=true,conditions={}},
 }},
}}))
-- Combat stealth opener: Cheap Shot on a solo pull, Ambush (opener and after Vanish), Revealing Strike when Ambush
-- cannot land.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.combat-opener',revision=2,families={'progression'},class='ROGUE',steps={
 {id='stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  BuiltinConditions.spell('stealth-cheap-shot',1833,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(BuiltinConditions.combat()))),
  BuiltinConditions.spell('stealth-ambush',8676),
  BuiltinConditions.spell('stealth-revealing-strike',84617),
  {id='stealth-stop',type='stop',suppress_attack=true,conditions={}},
 }},
}}))
-- Combat reminders: Blade Flurry on at two or more engaged enemies and off below; Adrenaline Rush under 35 energy;
-- Shadow Blades inside Adrenaline Rush; Killing Spree with Slice and Dice, outside Adrenaline Rush, under 50 energy;
-- Vanish for an Ambush in Deep Insight at 50 energy or less; Preparation when Vanish is cooling down in Deep Insight.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.combat-upkeep',revision=1,families={'progression'},class='ROGUE',steps={
 BuiltinConditions.spell('blade-flurry-on',13877,BuiltinConditions.all(enemies('GREATERTHANOREQUALS',2),BuiltinConditions.negate(BuiltinConditions.ownBuff(13877)))),
 BuiltinConditions.spell('blade-flurry-off',13877,BuiltinConditions.all(enemies('LESSTHAN',2),BuiltinConditions.ownBuff(13877))),
 BuiltinConditions.spell('adrenaline-rush',13750,BuiltinConditions.all(BuiltinConditions.combat(),{type='POWER',unit='player',operator='LESSTHAN',value=35})),
 BuiltinConditions.spell('shadow-blades',121471,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.ownBuff(13750))),
 BuiltinConditions.spell('killing-spree',51690,BuiltinConditions.all(BuiltinConditions.combat(),sliced,BuiltinConditions.negate(BuiltinConditions.ownBuff(13750)),{type='POWER',unit='player',operator='LESSTHAN',value=50})),
 BuiltinConditions.spell('vanish',1856,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='STEALTHED'}),BuiltinConditions.ownBuff(84747),{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=50})),
 BuiltinConditions.spell('preparation',14185,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.ownBuff(84747),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
}}))
-- Combat at eight or more engaged enemies (Wowhead, Icy Veins): Slice and Dice, Crimson Tempest when the pack will
-- live 12 s, Fan of Knives; the single-target list is not reached.
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.combat-aoe',revision=2,families={'progression'},class='ROGUE',steps={
 {id='aoe',type='branch',conditions=BuiltinConditions.all(enemies('GREATERTHANOREQUALS',8),BuiltinConditions.known(51723)),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.any(BuiltinConditions.negate(sliced),{type='BUFF_REMAIN',unit='player',spell=5171,ownbuff=true,operator='LESSTHAN',value=2}))),
  BuiltinConditions.spell('aoe-crimson-tempest',121411,BuiltinConditions.all(points('GREATERTHANOREQUALS',5),BuiltinConditions.lifetime('GREATERTHAN',12))),
  BuiltinConditions.spell('aoe-fan',51723),
  {id='aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Subtlety builders: Marked for Death at no points, Hemorrhage to keep its bleed, Backstab with a dagger when the
-- target is not on you (the "behind" proxy), Hemorrhage from the front (and the only builder before 40).
assert(addon:RegisterDefaultBlock({
 id='mop.rogue.subtlety-builders',revision=2,families={'progression'},class='ROGUE',steps={
 BuiltinConditions.spell('marked-for-death',137619,points('LESSTHANOREQUALS',0)),
 BuiltinConditions.spell('hemorrhage-bleed',16511,BuiltinConditions.any(BuiltinConditions.negate(mine(89775)),remain(89775,'LESSTHANOREQUALS',3))),
 BuiltinConditions.spell('backstab',53,BuiltinConditions.all({type='WEAPON_TYPE',slot='mainhand',subclass=15},BuiltinConditions.negate(tanked))),
 BuiltinConditions.spell('hemorrhage',16511),
}}))
