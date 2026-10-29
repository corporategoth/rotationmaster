-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era Rogue blocks, vanilla and Season of Discovery (Built In composition;
-- authoring-time only). Consumers: rm.era.rogue.dps, .dps.warcrafttavern, .dps.simulator and
-- rm.sod.rogue.dps, .dps.icyveins, .dps.zockify, .tank. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/rogue.md. IDs are Era 1.15.9
-- client data and SoD rune spells; verify in game. Ambush and Backstab need a dagger in the main hand
-- (weapon subclass 15); the off-hand poison needs an off-hand weapon (read by item type).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
-- Season of Discovery runes: engraved, by the spell the rune teaches (passive runes too).
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function optional(step)step.disabled=true;return step end
local behind=negate({type='ISSAME',unit='targettarget',otherunit='player'})
local sliced={type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}
local raid={type='INSTANCE',value='raid'}
local hurt={type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
-- Elite or boss target, or a second enemy fighting you: worth Blade Flurry / Adrenaline Rush.
local worth=any(classified('worldboss'),classified('elite'),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Instant Poison VI..I, Deadly Poison V..I (the best carried rank is used).
local instant={8928,8927,8926,6950,6949,6947}
local offhand={20844,8985,8984,2893,2892}
for _,id in ipairs(instant)do offhand[#offhand+1]=id end
local dualWield={type='WEAPON_TYPE',slot='offhand',kind='weapon'}
local dagger={type='WEAPON_TYPE',slot='mainhand',subclass=15}
-- Boundaries: manual casts/channels (bandages) and no attackable target end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.boundaries',revision=3,families={'era'},class='ROGUE',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Vanilla stealth opener: Premeditation, Ambush from behind with a dagger, Cheap Shot solo, Garrote outside
-- raids, else Sinister Strike; then stop so Attack does not break Stealth.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.opener',revision=3,families={'era'},class='ROGUE',steps={
 spell('premeditation',14183,points('LESSTHANOREQUALS',3)),
 spell('ambush',8676,all(dagger,behind)),
 spell('cheap-shot',1833,negate({type='GROUP'})),
 spell('garrote',703,negate(raid)),
 spell('stealth-sinister',1752),
 {id='stealth-stop',type='stop',suppress_attack=true,conditions={}},
}}))
-- Vanilla reminders: poisons per weapon, Kick, Thistle Tea, Blade Flurry and Adrenaline Rush with
-- Slice and Dice up on elites or packs, Cold Blood for a five-point finisher, Evasion when hurt.
-- Off by default: Vanish for threat, Gouge, Preparation and the racials.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.upkeep',revision=2,families={'era'},class='ROGUE',steps={
 item('mainhand-poison',instant,negate({type='WEAPON'})),
 item('offhand-poison',offhand,all(dualWield,negate({type='WEAPON',offhand=true}))),
 spell('kick',1766,interrupt),
 item('thistle-tea',{7676},all(combat(),energy('LESSTHANOREQUALS',30),points('LESSTHAN',5),negate({type='BUFF',unit='player',spell=13750}))),
 spell('blade-flurry',13877,all(combat(),sliced,worth)),
 spell('adrenaline-rush',13750,all(combat(),sliced,worth)),
 spell('cold-blood',14177,all(combat(),points('GREATERTHANOREQUALS',5))),
 spell('evasion',5277,all(combat(),negate({type='GROUP'}),hurt,tanked)),
 optional(spell('vanish',1856,all(combat(),{type='GROUP'},negate(tanked),{type='THREAT',unit='target',threat=2}))),
 optional(spell('gouge',1776,all(combat(),negate({type='GROUP'}),hurt,tanked))),
 optional(spell('preparation',14185,all(combat(),hurt,{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=30},{type='SPELL_COOLDOWN',spell=5277,operator='GREATERTHAN',value=30}))),
 optional(spell('blood-fury',20572,all(combat(),sliced,worth))),
 optional(spell('berserking',26297,all(combat(),sliced,worth))),
}}))
-- Vanilla builders by what is known: Ghostly Strike and Hemorrhage outside raids (a debuff slot),
-- Backstab (dagger) when the target is not facing you. Each consumer adds its own Sinister Strike.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.builders',revision=2,families={'era'},class='ROGUE',steps={
 spell('ghostly-strike',14278,negate(raid)),
 spell('hemorrhage',16511,negate(raid)),
 spell('backstab',53,all(dagger,behind)),
}}))
-- Improved Expose Armor 2/2 duty (tree 1, talent 8: verify the index in game): in a group, on an elite
-- or boss nobody Sunders (and, in SoD, nobody keeps Sebacious Poison on), Expose Armor at five
-- points when yours is missing or ending; five points and fifteen seconds or less left: pool.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.expose-armor',revision=2,families={'era'},class='ROGUE',steps={
 {id='expose-duty',type='branch',conditions=all({type='GROUP'},any(classified('worldboss'),classified('elite')),
  {type='TALENT',layout='tree',tree=1,talent=8,operator='GREATERTHANOREQUALS',value=2},
  negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),negate({type='DEBUFF',unit='target',spell=439462})),onFalse={},onTrue={
  spell('expose-armor',8647,all(points('GREATERTHANOREQUALS',5),any(negate({type='DEBUFF',unit='target',spell=8647,anyrank=true,owndebuff=true}),
   {type='DEBUFF_REMAIN',unit='target',spell=8647,anyrank=true,owndebuff=true,operator='LESSTHAN',value=3}))),
  {id='expose-pool',type='stop',suppress_attack=false,conditions=all(points('GREATERTHANOREQUALS',5),
   {type='DEBUFF_REMAIN',unit='target',spell=8647,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=15})},
 }},
}}))
-- Season of Discovery reminders: a temporary enchant on each weapon (any poison, stone or Wild
-- Strikes counts; Instant/Deadly Poison offered), Kick, Thistle Tea, Blade Flurry and Adrenaline
-- Rush with Slice and Dice up, Cold Blood at five, Evasion solo when hurt; with the Master of
-- Subtlety rune (passive, 425096) engraved, Vanish to renew it and Preparation once Vanish is spent.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.sod-upkeep',revision=3,families={'era'},class='ROGUE',steps={
 item('sod-mainhand-poison',instant,negate({type='WEAPON'})),
 item('sod-offhand-poison',offhand,all(dualWield,negate({type='WEAPON',offhand=true}))),
 spell('sod-kick',1766,interrupt),
 item('sod-thistle-tea',{7676},all(combat(),energy('LESSTHANOREQUALS',20),points('LESSTHAN',5))),
 spell('sod-blade-flurry',13877,all(combat(),sliced,worth)),
 spell('sod-adrenaline-rush',13750,all(combat(),sliced,worth)),
 spell('sod-cold-blood',14177,all(combat(),points('GREATERTHANOREQUALS',5))),
 spell('sod-evasion',5277,all(combat(),negate({type='GROUP'}),hurt,tanked)),
 spell('sod-vanish',1856,all(combat(),{type='GROUP'},rune(425096),negate(tanked),points('GREATERTHANOREQUALS',5),negate({type='BUFF',unit='player',spell=425096}))),
 spell('sod-preparation',14185,all(combat(),{type='GROUP'},rune(425096),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=30})),
}}))
-- Season of Discovery stealth opener: Shadowstrike, Garrote in a group (Carnage, Master of
-- Subtlety), Ambush for a Backstab build, Cheap Shot solo; then stop without breaking Stealth.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.sod-opener',revision=4,families={'era'},class='ROGUE',steps={
 spell('shadowstrike',399985),
 spell('group-garrote',703,{type='GROUP'}),
 spell('ambush',8676,all(dagger,negate(rune(399956)),negate(rune(424785)))),
 spell('cheap-shot',1833,negate({type='GROUP'})),
 spell('stealth-sinister',1752,all(negate(rune(399956)),negate(rune(424785)))),
 spell('stealth-mutilate',399956),
 spell('stealth-saber-slash',424785),
 {id='stealth-stop',type='stop',suppress_attack=true,conditions={}},
}}))
-- Season of Discovery builders by the engraved glove rune: Mutilate (two points, so not past
-- three), Saber Slash, Backstab when not faced or with the Cutthroat rune (passive, 462708: no
-- positional), else Sinister Strike.
assert(addon:RegisterDefaultBlock({
 id='era.rogue.sod-builders',revision=3,families={'era'},class='ROGUE',steps={
 spell('mutilate',399956,points('LESSTHANOREQUALS',3)),
 spell('saber-slash',424785),
 spell('backstab',53,all(dagger,points('LESSTHANOREQUALS',4),any(behind,rune(462708)))),
 spell('sinister',1752),
}}))
