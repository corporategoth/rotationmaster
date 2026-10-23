-- Shared Retail (Midnight 12.x) Demon Hunter blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.demonhunter.* premade. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Eye Beam, Fel Devastation, Void Ray, Collapsing Star) end advice.
assert(addon:RegisterDefaultBlock({id='retail.demonhunter.boundaries',revision=1,families={'retail'},class='DEMONHUNTER',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Disrupt on an interruptible cast
-- and Blur below 35% health. Enemy casts and your health are secret in Midnight combat, so both
-- light only where they can be read.
assert(addon:RegisterDefaultBlock({id='retail.demonhunter.utility',revision=1,families={'retail'},class='DEMONHUNTER',steps={
 spell('disrupt',183752,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('blur',198589,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35})),
}}))
