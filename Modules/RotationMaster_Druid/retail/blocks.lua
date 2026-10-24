-- Shared Retail (Midnight 12.x) Druid blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.druid.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
-- Your casts and channels (Convoke the Spirits, Tranquility) end advice.
assert(addon:RegisterDefaultBlock({id='retail.druid.boundaries',revision=1,families={'retail'},class='DRUID',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Mark of the Wild out of combat,
-- and Barkskin and the racial cooldowns whenever they are ready in combat. Health is secret on
-- Retail, so the defensive is a cooldown reminder, not a health trigger.
assert(addon:RegisterDefaultBlock({id='retail.druid.utility',revision=2,families={'retail'},class='DRUID',steps={
 spell('mark-of-the-wild',1126,all(negate(combat()),negate({type='BUFF',unit='player',spell=1126}))),
 spell('barkskin',22812,combat()),
 spell('berserking',26297,combat()),
 spell('ancestral-call',274738,combat()),
}}))
