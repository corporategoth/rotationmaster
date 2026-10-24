-- Shared Retail (Midnight 12.x) Hunter blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.hunter.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Aimed Shot, Steady Shot, Rapid Fire) end advice.
assert(addon:RegisterDefaultBlock({id='retail.hunter.boundaries',revision=3,families={'retail'},class='HUNTER',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Counter Shot (Beast Mastery,
-- Marksmanship) or Muzzle (Survival) on an interruptible cast (enemy casts are secret in Midnight
-- combat, so it lights only where they can be read), and Survival of the Fittest and the racial
-- cooldowns whenever they are ready in combat. Health is secret on Retail, so the damage reduction
-- is a cooldown reminder, and the emergency buttons (Exhilaration, Aspect of the Turtle) stay yours.
local interruptible=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultBlock({id='retail.hunter.utility',revision=2,families={'retail'},class='HUNTER',steps={
 spell('counter-shot',147362,interruptible),
 spell('muzzle',187707,interruptible),
 spell('survival-of-the-fittest',264735,combat()),
 spell('blood-fury',20572,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
-- Before the pull: Hunter's Mark on a target that does not carry one.
assert(addon:RegisterDefaultBlock({id='retail.hunter.mark',revision=1,families={'retail'},class='HUNTER',steps={
 spell('hunters-mark',257284,all({type='ATTACKABLE',unit='target'},negate({type='DEBUFF',unit='target',spell=257284}))),
}}))
