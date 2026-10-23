-- Shared WoW Forever Druid blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.druid.balance, rm.forever.druid.balance.tavern, rm.forever.druid.feral,
-- rm.forever.druid.restoration and rm.forever.druid.restoration.icyveins. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read from their auras (the shapeshift-bar index moves as forms are learned).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function aura(id)return{type='BUFF',unit='player',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local healthy={type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.2}
-- Casts and channels (Starfire, Hurricane, Tranquility, Healing Touch) and travel forms end advice.
assert(addon:RegisterDefaultBlock({id='forever.druid.boundaries',revision=1,families={'forever'},class='DRUID',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('travel',any(aura(783),aura(1066))),
}}))
-- Out of combat: Mark of the Wild unless Mark or Gift is up; Thorns on yourself while solo
-- (in a group it belongs on the tank, by hand). Omen of Clarity is passive on Forever.
assert(addon:RegisterDefaultBlock({id='forever.druid.upkeep',revision=1,families={'forever'},class='DRUID',steps={
 spell('mark',1126,all(negate(combat()),negate(buff(1126)),negate(buff(21849)))),
 spell('thorns',467,all(negate(combat()),negate({type='GROUP'}),negate(buff(467)))),
}}))
-- Your own Moonfire, then your own Insect Swarm (Balance talent), never on a target nearly dead.
-- DoTs do not snapshot on Forever, so a running one is never refreshed early.
assert(addon:RegisterDefaultBlock({id='forever.druid.dots',revision=1,families={'forever'},class='DRUID',steps={
 spell('moonfire',8921,all(negate(dot(8921)),healthy)),
 spell('insect-swarm',5570,all(negate(dot(5570)),healthy)),
}}))
-- A healer's spare-time damage on a hostile target: the DoTs, then Wrath; nothing else.
assert(addon:RegisterDefaultBlock({id='forever.druid.spare-damage',revision=1,families={'forever'},class='DRUID',steps={
 {id='dots',type='block',block='forever.druid.dots',prefix='spare-'},
 spell('wrath',5176),
 stop('done'),
}}))
-- Healer reminders: Innervate, Nature's Swiftness on a dying target, Tranquility when the party
-- is hurt, curse and poison removal on the friendly target.
local friendly={type='FRIENDLY',unit='target'}
local function dispel(kind)return all(friendly,{type='DISPELLABLE',unit='target',debufftype=kind})end
assert(addon:RegisterDefaultBlock({id='forever.druid.healer-upkeep',revision=1,families={'forever'},class='DRUID',steps={
 spell('swiftness',17116,all(combat(),friendly,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.3})),
 spell('tranquility',740,all(combat(),{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=20,healthoperator='LESSTHAN',health=.6,operator='GREATERTHANOREQUALS',value=3})),
 spell('remove-curse',2782,dispel('Curse')),
 spell('abolish-poison',2893,dispel('Poison')),
 spell('cure-poison',8946,all(negate({type='SPELL_KNOWN',spell=2893}),dispel('Poison'))),
}}))
