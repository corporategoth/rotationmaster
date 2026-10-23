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
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling (Drain Soul, Malefic Grasp, Channel Demonfire run to the end) ends
-- advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.warlock.boundaries',revision=1,families={'retail'},class='WARLOCK',steps={
 {id='casting',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Warlock premade shares: your demon's interrupt (Command Demon becomes Spell
-- Lock or Axe Toss) on an interruptible cast, Dark Pact below half health, Unending Resolve below
-- a third (these light only where Midnight lets the target's cast and health be read).
assert(addon:RegisterDefaultBlock({
 id='retail.warlock.upkeep',revision=1,families={'retail'},class='WARLOCK',steps={
 spell('command-demon',119898,all(combat(),interrupt)),
 spell('dark-pact',108416,all(combat(),health('LESSTHAN',.5))),
 spell('unending-resolve',104773,all(combat(),health('LESSTHAN',.35))),
}}))
