-- Shared Classic Era Shaman blocks, vanilla and Season of Discovery (Built In composition;
-- authoring-time only). Consumers: rm.era.shaman.enhancement, .enhancement.warcrafttavern,
-- .elemental, .elemental.wowsims, .restoration, .restoration.warcrafttavern and
-- rm.sod.shaman.enhancement, .elemental, .restoration, .tank. A content change needs a block
-- revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/shaman.md. Totem slots: 1 Fire,
-- 2 Earth, 3 Water, 4 Air. IDs are Era 1.15.9 client data and SoD rune spells; verify in game.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
-- A fight worth a totem: a group, an elite or boss, or a target forecast to live 20 seconds.
local long=any({type='GROUP'},big,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20})
-- Manual casts and channels, and Ghost Wolf, end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.manual',revision=2,families={'era'},class='SHAMAN',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645))},
}}))
-- Damage premades: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.manual-target',revision=1,families={'era'},class='SHAMAN',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},buff(2645),negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Earth Shock interrupts an interruptible cast or channel (every source).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.interrupt',revision=1,families={'era'},class='SHAMAN',steps={
 spell('interrupt',8042,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
-- A shield: Water Shield once engraved (Season of Discovery), otherwise Lightning Shield.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.shield',revision=1,families={'era'},class='SHAMAN',steps={
 spell('water-shield',408510,negate(any(buff(408510),buff(324)))),
 spell('lightning-shield',324,all(negate(known(408510)),negate(buff(324)))),
}}))
-- Solo healing: Healing Wave between pulls when below 60%, and in combat an emergency Lesser
-- Healing Wave (Healing Wave before it is learned) below 30%.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.self-heal',revision=1,families={'era'},class='SHAMAN',steps={
 spell('heal-after-pull',331,all(negate(combat()),negate({type='ATTACKABLE',unit='target'}),health('player','LESSTHAN',.6))),
 spell('emergency-lesser-wave',8004,all(combat(),negate({type='GROUP'}),health('player','LESSTHAN',.3))),
 spell('emergency-wave',331,all(combat(),negate({type='GROUP'}),negate(known(8004)),health('player','LESSTHAN',.3))),
}}))
-- Melee totems, each while its slot is empty in combat: Strength of Earth and Searing on long
-- fights, Windfury Totem in a group (Grace of Air solo), Mana Spring in a group (Healing Stream
-- solo on long fights).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.melee-totems',revision=1,families={'era'},class='SHAMAN',steps={
 spell('strength-of-earth',8075,all(combat(),negate(totem(2)),long)),
 spell('searing-totem',3599,all(combat(),negate(totem(1)),enemies('LESSTHAN',3),long)),
 spell('windfury-totem',8512,all(combat(),{type='GROUP'},negate(totem(4)))),
 spell('grace-of-air',8835,all(combat(),negate({type='GROUP'}),negate(totem(4)),long)),
 spell('mana-spring',5675,all(combat(),{type='GROUP'},negate(totem(3)))),
 spell('healing-stream',5394,all(combat(),negate({type='GROUP'}),negate(totem(3)),long)),
}}))
-- Caster totems in combat: Searing on one enemy for a long fight, Magma on packs, Mana Spring in a
-- group (Healing Stream solo on long fights).
assert(addon:RegisterDefaultBlock({
 id='era.shaman.caster-totems',revision=1,families={'era'},class='SHAMAN',steps={
 spell('searing-totem',3599,all(combat(),negate(totem(1)),enemies('LESSTHAN',2),long)),
 spell('magma-totem',8190,all(combat(),negate(totem(1)),enemies('GREATERTHANOREQUALS',2))),
 spell('mana-spring',5675,all(combat(),{type='GROUP'},negate(totem(3)))),
 spell('healing-stream',5394,all(combat(),negate({type='GROUP'}),negate(totem(3)),long)),
}}))
-- Cleansing a friendly target: Cure Poison, Cure Disease.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.cures',revision=1,families={'era'},class='SHAMAN',steps={
 spell('cure-poison',526,{type='DISPELLABLE',unit='target',debufftype='Poison'}),
 spell('cure-disease',2870,{type='DISPELLABLE',unit='target',debufftype='Disease'}),
}}))
-- A healer's damage on a hostile target (leveling): no target stops; Earth Shock interrupts;
-- Chain Lightning on packs; Flame Shock when yours is missing; Lightning Bolt from range while
-- standing; then melee.
assert(addon:RegisterDefaultBlock({
 id='era.shaman.healer-damage',revision=1,families={'era'},class='SHAMAN',steps={
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 spell('interrupt',8042,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('chain-lightning',421,enemies('GREATERTHANOREQUALS',2)),
 spell('flame-shock',8050,all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),any(big,health('target','GREATERTHAN',.5)))),
 spell('lightning-bolt',403,all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))),
}}))
