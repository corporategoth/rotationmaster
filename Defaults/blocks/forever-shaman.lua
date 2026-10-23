-- Shared WoW Forever Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.shaman.enhancement, .enhancement.wowhead, .elemental and .restoration.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and
-- both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/shaman.md.
-- Totem slots: 1 Fire, 2 Earth, 3 Water, 4 Air. IDs are beta data; verify in game.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
-- Manual casts and channels, and Ghost Wolf (any of its three IDs), end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.manual',revision=1,families={'forever'},class='SHAMAN',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='ghost-wolf',type='none',suppress_attack=true,conditions=any(buff(2645),buff(415233),buff(1238640))},
}}))
-- Every Shaman: a shield (Water Shield once talented, else Lightning Shield, refreshed in combat
-- only with half mana) and the Earth Shock interrupt.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.upkeep',revision=1,families={'forever'},class='SHAMAN',steps={
 spell('water-shield',408510,negate(any(buff(408510),buff(324)))),
 spell('lightning-shield',324,all(negate(known(408510)),negate(buff(324)),
  any(negate(combat()),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=.5}))),
 spell('interrupt',8042,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
-- Main-hand imbue (Forever has no Shaman Dual Wield): Windfury once known, else Flametongue,
-- else Rockbiter. A learned better imbue is never replaced by a lower one.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.imbue',revision=1,families={'forever'},class='SHAMAN',steps={
 spell('windfury-weapon',8232,negate({type='WEAPON'})),
 spell('flametongue-weapon',8024,all(negate({type='WEAPON'}),negate(known(8232)))),
 spell('rockbiter-weapon',8017,all(negate({type='WEAPON'}),negate(known(8232)),negate(known(8024)))),
}}))
-- Group buff totems (five-minute raid buffs in Forever), each only while its slot is empty.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.group-totems',revision=1,families={'forever'},class='SHAMAN',steps={
 spell('strength-of-earth',8075,all(combat(),{type='GROUP'},negate(totem(2)))),
 spell('mana-spring',5675,all(combat(),{type='GROUP'},negate(totem(3)))),
 spell('windfury-totem',8512,all(combat(),{type='GROUP'},negate(totem(4)))),
}}))
-- Caster area damage on three engaged enemies: Fire Nova at the Fire totem, then Chain Lightning.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.caster-aoe',revision=1,families={'forever'},class='SHAMAN',steps={
 {id='aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  spell('fire-nova',408341,totem(1)),
  spell('chain-lightning',421),
 }},
}}))
-- Stormcaller / Wavebreaker hybrids: Stormstrike in melee, then Earth Shock into its debuff.
assert(addon:RegisterDefaultBlock({
 id='forever.shaman.stormstrike-hybrid',revision=1,families={'forever'},class='SHAMAN',steps={
 spell('stormstrike',17364,negate({type='BEYOND_MELEE',unit='target'})),
 spell('stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
}}))
