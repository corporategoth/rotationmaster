-- Shared Retail (Midnight 12.x) Monk blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.monk.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Fists of Fury, Celestial Conduit, Spinning Crane Kick, Crackling Jade
-- Lightning, Soothing Mist) end advice.
assert(addon:RegisterDefaultBlock({id='retail.monk.boundaries',revision=2,families={'retail'},class='MONK',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- The healer: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({id='retail.monk.heal-boundaries',revision=1,families={'retail'},class='MONK',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},{type='NOT',value={type='ATTACKABLE',unit='target'}})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Spear Hand Strike on an
-- interruptible cast (enemy casts are secret in Midnight combat, so it lights only where they can be
-- read), and Fortifying Brew and the racial cooldowns whenever they are ready in combat. Health is
-- secret on Retail, so the defensive is a cooldown reminder, not a health trigger.
assert(addon:RegisterDefaultBlock({id='retail.monk.utility',revision=2,families={'retail'},class='MONK',steps={
 spell('spear-hand-strike',116705,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('fortifying-brew',115203,combat()),
 spell('blood-fury',33697,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
