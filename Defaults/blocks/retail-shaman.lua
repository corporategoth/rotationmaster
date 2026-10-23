-- Shared Retail (Midnight) Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.shaman.elemental, .elemental.icyveins, .enhancement,
-- .enhancement.stormbringer, .enhancement.totemic and .restoration. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/shaman.md. Shields are read between pulls.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
local rest=negate(combat())
-- Elemental and Enhancement: casting or channelling ends advice; no attackable target too.
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.boundaries',revision=1,families={'retail'},class='SHAMAN',steps={
 {id='casting',type='none',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Shaman premade shares: Skyfury (anyone's) between pulls, Wind Shear on an
-- interruptible cast, Astral Shift below 40% health (the last two light only where Midnight lets
-- the target's cast and health be read).
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.upkeep',revision=1,families={'retail'},class='SHAMAN',steps={
 spell('skyfury',462854,all(rest,negate({type='BUFF',unit='player',spell=462854}))),
 spell('wind-shear',57994,all(combat(),interrupt)),
 spell('astral-shift',108271,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4})),
}}))
-- Elemental and Enhancement between pulls: Lightning Shield. Retail has no weapon-imbue
-- condition (WEAPON is a Classic-family condition), so Flametongue, Windfury and Thunderstrike
-- Ward are left to Blizzard's suggestion, which keeps them itself.
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.lightning-shield',revision=1,families={'retail'},class='SHAMAN',steps={
 spell('lightning-shield',192106,all(rest,negate(own(192106)))),
}}))
