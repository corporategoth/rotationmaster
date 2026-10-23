-- Shared Retail (Midnight 12.x) Hunter blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.hunter.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(v)return all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=v})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Aimed Shot, Steady Shot, Rapid Fire) end advice.
assert(addon:RegisterDefaultBlock({id='retail.hunter.boundaries',revision=1,families={'retail'},class='HUNTER',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Counter Shot (Beast Mastery,
-- Marksmanship) or Muzzle (Survival) on an interruptible cast, Survival of the Fittest below 50%,
-- Exhilaration below 35% and Aspect of the Turtle below 20% health, and the racial cooldowns in
-- combat. Enemy casts and your health are secret in Midnight combat, so the interrupt and the
-- defensives light only where they can be read.
local interruptible=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultBlock({id='retail.hunter.utility',revision=1,families={'retail'},class='HUNTER',steps={
 spell('counter-shot',147362,interruptible),
 spell('muzzle',187707,interruptible),
 spell('survival-of-the-fittest',264735,health(.5)),
 spell('exhilaration',109304,health(.35)),
 spell('aspect-of-the-turtle',186265,health(.2)),
 spell('blood-fury',20572,combat()),
 spell('berserking',26297,combat()),
 spell('fireblood',265221,combat()),
 spell('ancestral-call',274738,combat()),
}}))
-- Before the pull: Hunter's Mark on a target that does not carry one.
assert(addon:RegisterDefaultBlock({id='retail.hunter.mark',revision=1,families={'retail'},class='HUNTER',steps={
 spell('hunters-mark',257284,all({type='ATTACKABLE',unit='target'},negate({type='DEBUFF',unit='target',spell=257284}))),
}}))
