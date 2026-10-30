-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.paladin.retribution, rm.forever.paladin.protection,
-- rm.forever.paladin.protection.icyveins, rm.forever.paladin.holy and rm.forever.paladin.holy.wowhead.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Forever Judgement does not consume the seal and is off the global cooldown.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id,unit)return{type='BUFF',unit=unit or'player',spell=id,anyrank=true,ownbuff=true}end
local function remain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='GREATERTHANOREQUALS',value=3}end
local friendly={type='FRIENDLY',unit='target'}
assert(addon:RegisterDefaultBlock({id='forever.paladin.boundaries',revision=3,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- No aura of yours: Retribution Aura once learned, else Devotion. No Blessing of yours on you:
-- Kings once learned, else Might. Any aura or Blessing you already chose is kept.
assert(addon:RegisterDefaultBlock({id='forever.paladin.aura-blessing',revision=1,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.spell('retribution-aura',7294,BuiltinConditions.all(BuiltinConditions.negate(own(465)),BuiltinConditions.negate(own(7294)),BuiltinConditions.negate(own(19746)))),
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(own(465)),BuiltinConditions.negate(own(7294)),BuiltinConditions.negate(own(19746)),BuiltinConditions.negate(BuiltinConditions.known(7294)))),
 BuiltinConditions.spell('kings',20217,BuiltinConditions.all(BuiltinConditions.negate(own(20217)),BuiltinConditions.negate(own(19740)),BuiltinConditions.negate(own(19742)))),
 BuiltinConditions.spell('might',19740,BuiltinConditions.all(BuiltinConditions.negate(own(20217)),BuiltinConditions.negate(own(19740)),BuiltinConditions.negate(own(19742)),BuiltinConditions.negate(BuiltinConditions.known(20217)))),
}}))
-- The damage seal: Seal of Command with a slow (3.0 s or more) weapon, else Righteousness.
assert(addon:RegisterDefaultBlock({id='forever.paladin.main-seal',revision=1,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.spell('seal-command',20375,{type='SWING_TIME',operator='GREATERTHANOREQUALS',value=3}),
 BuiltinConditions.spell('seal-righteousness',20154),
}}))
-- Dispels on the friendly target: Cleanse (Magic, Poison, Disease), Purify before it.
local function dispel(kind)return{type='DISPELLABLE',unit='target',debufftype=kind}end
assert(addon:RegisterDefaultBlock({id='forever.paladin.dispel',revision=1,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.spell('cleanse',4987,BuiltinConditions.any(dispel('Magic'),dispel('Poison'),dispel('Disease'))),
 BuiltinConditions.spell('purify',1152,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(4987)),BuiltinConditions.any(dispel('Poison'),dispel('Disease')))),
}}))
-- Tank taunt: the target is fighting and not attacking you. Judgement with Seal of Fury taunts;
-- Swift Judgement resets it when it is cooling.
assert(addon:RegisterDefaultBlock({id='forever.paladin.taunt',revision=2,families={'forever'},class='PALADIN',steps={
 {id='taunt',type='branch',conditions=BuiltinConditions.all({type='COMBAT',unit='target'},BuiltinConditions.negate({type='THREAT',unit='target',threat=3})),onFalse={},onTrue={
  BuiltinConditions.spell('taunt-judgement',20271,own(1311649)),
  BuiltinConditions.spell('taunt-swift-judgement',1310994)}},
}}))
-- Tank reminders: Righteous Fury, Seal of Fury (missing or under 3 s), Holy Shield while tanking.
-- Health is secret on Forever, so Templar's Bulwark and Lay on Hands are the player's call.
assert(addon:RegisterDefaultBlock({id='forever.paladin.tank-upkeep',revision=2,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.spell('righteous-fury',25780,BuiltinConditions.negate(own(25780))),
 BuiltinConditions.spell('seal-fury',1311649,BuiltinConditions.negate(remain(1311649))),
 BuiltinConditions.spell('holy-shield',20925,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(own(20925)),{type='THREAT',unit='target',threat=3})),
}}))
-- Healer reminders: Seal of Light when you have no seal, Divine Favor in combat on a friendly
-- target. Health is secret on Forever, so Lay on Hands is the player's call.
local seals=BuiltinConditions.any(own(20165),own(20166),own(20154),own(20375),own(21082),own(20164),own(1311649))
assert(addon:RegisterDefaultBlock({id='forever.paladin.healer-upkeep',revision=2,families={'forever'},class='PALADIN',steps={
 BuiltinConditions.spell('seal-light',20165,BuiltinConditions.negate(seals)),
 BuiltinConditions.spell('divine-favor',20216,BuiltinConditions.all(BuiltinConditions.combat(),friendly)),
}}))
