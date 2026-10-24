-- Shared WoW Forever Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.paladin.retribution, rm.forever.paladin.protection,
-- rm.forever.paladin.protection.icyveins, rm.forever.paladin.holy and rm.forever.paladin.holy.wowhead.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Forever Judgement does not consume the seal and is off the global cooldown.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id,unit)return{type='BUFF',unit=unit or'player',spell=id,anyrank=true,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function remain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='GREATERTHANOREQUALS',value=3}end
local friendly={type='FRIENDLY',unit='target'}
assert(addon:RegisterDefaultBlock({id='forever.paladin.boundaries',revision=1,families={'forever'},class='PALADIN',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- No aura of yours: Retribution Aura once learned, else Devotion. No Blessing of yours on you:
-- Kings once learned, else Might. Any aura or Blessing you already chose is kept.
assert(addon:RegisterDefaultBlock({id='forever.paladin.aura-blessing',revision=1,families={'forever'},class='PALADIN',steps={
 spell('retribution-aura',7294,all(negate(own(465)),negate(own(7294)),negate(own(19746)))),
 spell('devotion-aura',465,all(negate(own(465)),negate(own(7294)),negate(own(19746)),negate(known(7294)))),
 spell('kings',20217,all(negate(own(20217)),negate(own(19740)),negate(own(19742)))),
 spell('might',19740,all(negate(own(20217)),negate(own(19740)),negate(own(19742)),negate(known(20217)))),
}}))
-- The damage seal: Seal of Command with a slow (3.0 s or more) weapon, else Righteousness.
assert(addon:RegisterDefaultBlock({id='forever.paladin.main-seal',revision=1,families={'forever'},class='PALADIN',steps={
 spell('seal-command',20375,{type='SWING_TIME',operator='GREATERTHANOREQUALS',value=3}),
 spell('seal-righteousness',20154),
}}))
-- Dispels on the friendly target: Cleanse (Magic, Poison, Disease), Purify before it.
local function dispel(kind)return{type='DISPELLABLE',unit='target',debufftype=kind}end
assert(addon:RegisterDefaultBlock({id='forever.paladin.dispel',revision=1,families={'forever'},class='PALADIN',steps={
 spell('cleanse',4987,any(dispel('Magic'),dispel('Poison'),dispel('Disease'))),
 spell('purify',1152,all(negate(known(4987)),any(dispel('Poison'),dispel('Disease')))),
}}))
-- Tank taunt: the target is fighting and not attacking you. Judgement with Seal of Fury taunts;
-- Swift Judgement resets it when it is cooling.
assert(addon:RegisterDefaultBlock({id='forever.paladin.taunt',revision=2,families={'forever'},class='PALADIN',steps={
 {id='taunt',type='branch',conditions=all({type='COMBAT',unit='target'},negate({type='THREAT',unit='target',threat=3})),onFalse={},onTrue={
  spell('taunt-judgement',20271,own(1311649)),
  spell('taunt-swift-judgement',1310994)}},
}}))
-- Tank reminders: Righteous Fury, Seal of Fury (missing or under 3 s), Holy Shield while tanking.
-- Health is secret on Forever, so Templar's Bulwark and Lay on Hands are the player's call.
assert(addon:RegisterDefaultBlock({id='forever.paladin.tank-upkeep',revision=2,families={'forever'},class='PALADIN',steps={
 spell('righteous-fury',25780,negate(own(25780))),
 spell('seal-fury',1311649,negate(remain(1311649))),
 spell('holy-shield',20925,all(combat(),negate(own(20925)),{type='THREAT',unit='target',threat=3})),
}}))
-- Healer reminders: Seal of Light when you have no seal, Divine Favor in combat on a friendly
-- target. Health is secret on Forever, so Lay on Hands is the player's call.
local seals=any(own(20165),own(20166),own(20154),own(20375),own(21082),own(20164),own(1311649))
assert(addon:RegisterDefaultBlock({id='forever.paladin.healer-upkeep',revision=2,families={'forever'},class='PALADIN',steps={
 spell('seal-light',20165,negate(seals)),
 spell('divine-favor',20216,all(combat(),friendly)),
}}))
