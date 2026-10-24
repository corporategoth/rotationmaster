-- Shared Retail (Midnight 12.x) Evoker blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.evoker.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts, channels (Disintegrate) and empowers (Fire Breath, Eternity Surge, Upheaval, Dream
-- Breath: the game reports an empower as a channel) end advice.
assert(addon:RegisterDefaultBlock({id='retail.evoker.boundaries',revision=1,families={'retail'},class='EVOKER',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Quell on an interruptible cast,
-- Obsidian Scales whenever it is ready in combat, and out of combat Blessing of the Bronze when it is
-- missing and Source of Magic on a friendly target in your group. Enemy casts are secret in Midnight
-- combat, so Quell lights only where they can be read; health is secret on Retail, so the defensive
-- is a cooldown reminder. Dracthyr have no racial cooldown to add.
assert(addon:RegisterDefaultBlock({id='retail.evoker.utility',revision=2,families={'retail'},class='EVOKER',steps={
 spell('quell',351338,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('obsidian-scales',363916,combat()),
 spell('blessing-of-the-bronze',364342,all(negate(combat()),negate({type='BUFF',unit='player',spell=381748}))),
 spell('source-of-magic',369459,all(negate(combat()),{type='GROUP'},{type='FRIENDLY',unit='target'},negate({type='BUFF',unit='target',spell=369459,ownbuff=true}))),
}}))
