-- Shared Retail (Midnight 12.x) Death Knight blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.deathknight.* premade. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts, channels and empowers (Consumption) end advice.
assert(addon:RegisterDefaultBlock({id='retail.deathknight.boundaries',revision=1,families={'retail'},class='DEATHKNIGHT',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Mind Freeze on an interruptible
-- cast, Icebound Fortitude below 35% health, and the racial cooldowns in combat. Enemy casts and
-- your health are secret in Midnight combat, so the first two light only where they can be read.
assert(addon:RegisterDefaultBlock({id='retail.deathknight.utility',revision=1,families={'retail'},class='DEATHKNIGHT',steps={
 spell('mind-freeze',47528,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('icebound-fortitude',48792,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35})),
 spell('blood-fury',20572,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
