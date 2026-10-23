-- Shared Retail (Midnight) Rogue blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.rogue.assassination, .assassination.icyveins, .outlaw, .outlaw.icyveins,
-- .subtlety and .subtlety.icyveins. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/rogue.md. Retail poisons are buffs on you, read between pulls.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
local lethal=any(own(2823),own(315584),own(8679),own(381664))
-- Casting or channelling ends advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.rogue.boundaries',revision=1,families={'retail'},class='ROGUE',steps={
 {id='casting',type='none',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Rogue premade shares. Between pulls: a lethal poison (Deadly, else Instant;
-- Wound or Amplifying count), a non-lethal one (Crippling; Atrophic or Numbing count), Stealth on
-- an enemy target. In combat: Kick on an interruptible cast, Crimson Vial below half health (both
-- light only where Midnight lets the target's cast and health be read).
assert(addon:RegisterDefaultBlock({
 id='retail.rogue.upkeep',revision=1,families={'retail'},class='ROGUE',steps={
 spell('deadly-poison',2823,all(negate(combat()),negate(lethal))),
 spell('instant-poison',315584,all(negate(combat()),negate(lethal),negate({type='SPELL_KNOWN',spell=2823}))),
 spell('crippling-poison',3408,all(negate(combat()),negate(any(own(3408),own(381637),own(5761))))),
 spell('stealth',1784,all(negate(combat()),{type='ATTACKABLE',unit='target'},negate({type='STEALTHED'}))),
 spell('kick',1766,all(combat(),interrupt)),
 spell('crimson-vial',185311,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
}}))
