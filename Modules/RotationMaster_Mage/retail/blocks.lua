-- Shared Retail (Midnight 12.x) Mage blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.mage.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Arcane Missiles, Ray of Frost, Evocation) end advice.
assert(addon:RegisterDefaultBlock({id='retail.mage.boundaries',revision=3,families={'retail'},class='MAGE',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Arcane Intellect out of combat
-- (readable there; in combat the buff is hidden), Counterspell on an interruptible cast (enemy casts
-- are secret in Midnight combat, so it lights only where they can be read), and the racial cooldowns
-- in combat. Health is secret on Retail, so Ice Block, an emergency button, stays yours.
assert(addon:RegisterDefaultBlock({id='retail.mage.utility',revision=2,families={'retail'},class='MAGE',steps={
 spell('arcane-intellect',1459,all(negate(combat()),negate({type='BUFF',unit='player',spell=1459}))),
 spell('counterspell',2139,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('blood-fury',33702,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
