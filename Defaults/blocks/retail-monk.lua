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
assert(addon:RegisterDefaultBlock({id='retail.monk.boundaries',revision=1,families={'retail'},class='MONK',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Spear Hand Strike on an
-- interruptible cast, Fortifying Brew below 35% health, and the racial cooldowns in combat. Enemy
-- casts and your health are secret in Midnight combat, so the first two light only where they can
-- be read.
assert(addon:RegisterDefaultBlock({id='retail.monk.utility',revision=1,families={'retail'},class='MONK',steps={
 spell('spear-hand-strike',116705,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('fortifying-brew',115203,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35})),
 spell('blood-fury',33697,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
