-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.warlock.affliction, .affliction.icyveins, .demonology,
-- .demonology.icyveins, .destruction, .destruction.simc and .destruction.icyveins. A content
-- change needs a block revision bump, every consumer's pin and revision bumped, and both recorded
-- in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/warlock.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling (Drain Soul, Malefic Grasp, Channel Demonfire run to the end) ends
-- advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.warlock.boundaries',revision=3,families={'retail'},class='WARLOCK',steps={
 {id='casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Reminders every Warlock premade shares: your demon's interrupt (Command Demon becomes Spell
-- Lock or Axe Toss) on an interruptible cast (it lights only where Midnight lets the target's cast be
-- read), Dark Pact and Unending Resolve whenever they are ready in combat (health is secret on
-- Retail, so these are cooldown reminders).
assert(addon:RegisterDefaultBlock({
 id='retail.warlock.upkeep',revision=2,families={'retail'},class='WARLOCK',steps={
 spell('command-demon',119898,all(combat(),interrupt)),
 spell('dark-pact',108416,combat()),
 spell('unending-resolve',104773,combat()),
}}))
