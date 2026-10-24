-- Shared WoW Forever Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.warlock.dps, .dps.icyveins and .dps.wowhead. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/warlock.md.
-- RM cannot read Forever talents, so trees are told apart by talent-taught actives: Conflagrate
-- (Destruction, 16 points), Fel Domination (Demonology, 16), Incinerate stands in for Shadow
-- and Flame 5/5. IDs are beta data; verify in game.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function shards(op,v)return{type='CARRYING',item={6265},operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function fire()return any(known(1293817),known(412758))end
local firestones,spellstones={13701,13700,13699,1254},{13603,13602,5522}
-- Demonic Sacrifice buffs (renamed in Forever); keep them only with Demonic Pact, whose proxy is
-- Soul Link known at 40+ (Pact is passive).
local function sacrificed()return any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return all(known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
-- Manual casts and channels (Drain Life, Drain Soul, Wrack, Hellfire, Rain of Fire, Health
-- Funnel) run to the end; no advice against a target that is not yours to pull.
assert(addon:RegisterDefaultBlock({id='forever.warlock.boundaries',revision=2,families={'forever'},class='WARLOCK',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'})))))),
}}))
-- Independent reminders every source shares: armor, Soul Link, the Demonology sacrifice with
-- Pact, and the weapon stone (Firestone for a Fire build, else Spellstone). Health is secret on
-- Forever, so Health Funnel is the player's call.
assert(addon:RegisterDefaultBlock({id='forever.warlock.upkeep',revision=2,families={'forever'},class='WARLOCK',steps={
 spell('demon-armor',706,negate(any(buff(706),buff(687)))),
 spell('demon-skin',687,all(negate(known(706)),negate(any(buff(706),buff(687))))),
 spell('fel-domination',18708,all(combat(),negate({type='PET'}),any(negate(sacrificed()),pact()))),
 spell('demonic-sacrifice',18788,all({type='PET'},pact(),negate(sacrificed()))),
 spell('soul-link',19028,all({type='PET'},negate(buff(25228)))),
 item('firestone',firestones,all(negate({type='WEAPON'}),fire())),
 item('spellstone',spellstones,all(negate({type='WEAPON'}),negate(fire()))),
 spell('create-firestone',6366,all(negate(combat()),fire(),{type='CARRYING',item=firestones,operator='LESSTHAN',value=1})),
 spell('create-spellstone',2362,all(negate(combat()),negate(fire()),{type='CARRYING',item=spellstones,operator='LESSTHAN',value=1})),
}}))
-- Procs expire, so first: Nightfall's Shadow Trance (instant Shadow Bolt) and Decimation (Soul
-- Fire). Then the Demonology core: keep Demonic Brand on the target with Searing Pain.
assert(addon:RegisterDefaultBlock({id='forever.warlock.procs',revision=1,families={'forever'},class='WARLOCK',steps={
 spell('shadow-trance',686,buff(17941)),
 spell('decimation',6353,buff(440873)),
 spell('demonic-brand',5676,all(any(known(1293695),known(18708)),negate(own(1293696)))),
}}))
-- Moving: instants only, then stop. Corruption is left out because RM cannot see whether
-- Improved Corruption has made it instant.
assert(addon:RegisterDefaultBlock({id='forever.warlock.moving',revision=2,families={'forever'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-agony',980,all(negate(own(980)),negate(own(603)),negate(own(1324473)))),
  spell('moving-siphon',18265,negate(own(18265))),
  spell('moving-conflagrate',1293817,own(348)),
  spell('moving-shadowburn',17877,shards('GREATERTHANOREQUALS',2)),
  stop('moving-stop'),
 }},
}}))
-- Three or more engaged enemies: Hellfire in a group (health is secret on Forever, so watch your
-- own), Rain of Fire, and
-- Corruption and Agony on the current target; the single-target priority then continues.
assert(addon:RegisterDefaultBlock({id='forever.warlock.aoe',revision=2,families={'forever'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('hellfire',1949,{type='GROUP'}),
  spell('rain-of-fire',5740),
  spell('aoe-corruption',172,negate(own(172))),
  spell('aoe-agony',980,all(negate(own(980)),negate(own(603)),negate(own(1324473)))),
 }},
}}))
-- Solo wand filler: keep an active wand going rather than suggesting a spell over it.
assert(addon:RegisterDefaultBlock({id='forever.warlock.wand',revision=1,families={'forever'},class='WARLOCK',steps={
 stop('wanding',{type='SPELL_AUTOREPEAT',spell=5019}),
 spell('wand',5019),
}}))
