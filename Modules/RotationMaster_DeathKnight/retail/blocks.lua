-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Death Knight blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.deathknight.* premade. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
-- Your casts, channels and empowers (Consumption) end advice.
assert(addon:RegisterDefaultBlock({id='retail.deathknight.boundaries',revision=3,families={'retail'},class='DEATHKNIGHT',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Mind Freeze on an interruptible
-- cast (enemy casts are secret in Midnight combat, so it lights only where they can be read), and
-- Icebound Fortitude and the racial cooldowns whenever they are ready in combat. Health is secret
-- on Retail, so the defensive is a cooldown reminder, not a health trigger.
assert(addon:RegisterDefaultBlock({id='retail.deathknight.utility',revision=2,families={'retail'},class='DEATHKNIGHT',steps={
 spell('mind-freeze',47528,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('icebound-fortitude',48792,combat()),
 spell('blood-fury',20572,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
