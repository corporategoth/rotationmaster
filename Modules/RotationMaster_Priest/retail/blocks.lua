-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.priest.shadow, .shadow.icyveins, .discipline, .discipline.wowhead and
-- .holy. A content change needs a block revision bump, every consumer's pin and revision bumped,
-- and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the
-- consumers'; see premade-research retail/priest.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Shadow: casting or channelling ends advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.boundaries',revision=3,families={'retail'},class='PRIEST',steps={
 {id='casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Reminders every Priest premade shares: Power Word: Fortitude (anyone's) between pulls, Silence
-- on an interruptible cast (Shadow; the target's cast is hidden in Midnight combat, so it lights only
-- where it can be read). Health is secret on Retail, so Desperate Prayer is yours.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.upkeep',revision=2,families={'retail'},class='PRIEST',steps={
 spell('fortitude',21562,all(negate(combat()),negate({type='BUFF',unit='player',spell=21562}))),
 spell('silence',15487,all(combat(),interrupt)),
}}))
-- Discipline cooldowns both guides keep on hand: Power Word: Radiance, Evangelism and Ultimate
-- Penitence in combat, Pain Suppression on a friendly target; when to press them is yours.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.disc-cooldowns',revision=1,families={'retail'},class='PRIEST',steps={
 spell('radiance',194509,combat()),
 spell('evangelism',472433,combat()),
 spell('ultimate-penitence',421453,combat()),
 spell('pain-suppression',33206,all(combat(),{type='FRIENDLY',unit='target'})),
}}))
