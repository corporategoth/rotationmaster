-- Shared WoW Forever Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.priest.dps, rm.forever.priest.dps.mobalytics and rm.forever.priest.healer.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local shadowform={type='BUFF',unit='player',spell=15473}
-- Casts end advice. Channels too, except Mind Flay in Shadowform with Mind Blast ready (the only
-- Shadowform channel): Mind Blast should not wait for the Flay to finish (Mobalytics).
assert(addon:RegisterDefaultBlock({id='forever.priest.boundaries',revision=1,families={'forever'},class='PRIEST',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',all({type='CHANNELING',unit='player'},negate(all(shadowform,{type='SPELL_AVAIL',spell=8092})))),
}}))
-- Out-of-combat buffs on yourself: Inner Fire, Fortitude and Divine Spirit (unless the Prayer
-- versions are up), and the Undead and Troll self-buffs when known.
assert(addon:RegisterDefaultBlock({id='forever.priest.upkeep',revision=1,families={'forever'},class='PRIEST',steps={
 spell('inner-fire',588,negate(buff(588))),
 spell('fortitude',1243,all(negate(combat()),negate(buff(1243)),negate(buff(21562)))),
 spell('divine-spirit',14752,all(negate(combat()),negate(buff(14752)),negate(buff(27681)))),
 spell('touch-of-weakness',2652,all(negate(combat()),negate(buff(2652)))),
 spell('shadowguard',18137,all(negate(combat()),negate(buff(18137)))),
}}))
-- Damage-dealer reminders: Vampiric Embrace on a fight that hurts or in a group, Inner Focus with
-- Mind Blast, Silence on interruptible casts, Dark Sacrifice, Elune's Light; Psychic Scream (it can
-- pull more mobs) is off by default.
assert(addon:RegisterDefaultBlock({id='forever.priest.dps-upkeep',revision=1,families={'forever'},class='PRIEST',steps={
 spell('vampiric-embrace',15286,all(combat(),{type='ATTACKABLE',unit='target'},negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),
  any({type='GROUP'},health('player','LESSTHAN',.8)))),
 spell('inner-focus',14751,all(combat(),{type='SPELL_AVAIL',spell=8092})),
 spell('silence',15487,{type='CAST_INTERRUPTABLE',unit='target'}),
 spell('dark-sacrifice',1277324,all(mana('LESSTHAN',.4),health('player','GREATERTHAN',.6))),
 {id='psychic-scream',type='spell',action=8122,ranked=false,disabled=true,conditions=all(combat(),
  {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2},health('player','LESSTHAN',.4))},
 spell('elunes-light',1259799,all(combat(),health('target','GREATERTHAN',.5))),
}}))
-- Wand: never toggle a running wand off (Shoot is a toggle).
assert(addon:RegisterDefaultBlock({id='forever.priest.wand',revision=1,families={'forever'},class='PRIEST',steps={
 stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
 spell('shoot',5019),
}}))
