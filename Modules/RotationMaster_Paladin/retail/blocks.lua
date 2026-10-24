-- Shared Retail (Midnight) Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.paladin.retribution, .retribution.icyveins, .protection,
-- .protection.icyveins, .protection.wowhead and .holy. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/paladin.md. Every condition here stays readable in Midnight combat except
-- the target's cast, which is secret there: Rebuke lights only where the game lets it be read.
-- Health is secret on Retail, so the defensives are cooldown reminders and Lay on Hands is yours.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling ends advice (Attack continues); no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.boundaries',revision=2,families={'retail'},class='PALADIN',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Paladin premade shares: an aura between pulls when none is up, Rebuke on an
-- interruptible cast.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.upkeep',revision=2,families={'retail'},class='PALADIN',steps={
 spell('devotion-aura',465,all(negate(combat()),negate(any(own(465),own(317920),own(32223))))),
 spell('rebuke',96231,all(combat(),interrupt)),
}}))
-- Protection defensives Assisted Combat never suggests: Ardent Defender and Guardian of Ancient
-- Kings whenever they are ready in combat.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.prot-defensives',revision=2,families={'retail'},class='PALADIN',steps={
 spell('ardent-defender',31850,combat()),
 spell('guardian-of-ancient-kings',86659,combat()),
}}))
-- Protection guide cooldowns (Icy Veins, SimulationCraft, Wowhead): Avenging Wrath or Sentinel,
-- Lightsmith's Holy Bulwark, and Sacred Weapon outside Avenging Wrath.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.prot-cooldowns',revision=1,families={'retail'},class='PALADIN',steps={
 spell('avenging-wrath',31884,fight),
 spell('sentinel',389539,fight),
 spell('holy-bulwark',432459,fight),
 spell('sacred-weapon',432472,all(fight,negate(own(31884)),negate(own(389539)))),
}}))
