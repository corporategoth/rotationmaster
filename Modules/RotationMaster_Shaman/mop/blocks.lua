-- Shared Mists of Pandaria Classic Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.shaman.{unspecialized,elemental,enhancement,enhancement.wowsims,enhancement.icyveins,
-- restoration,restoration.hekili}. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are
-- the consumers'; see premade-research progression/shaman.md. Totem slots: 1 Fire, 2 Earth, 3 Water, 4 Air.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function imbue(enchant,offhand)return{type='WEAPON_IMBUE',enchant=enchant,offhand=offhand or nil}end
local function stacks(id,n)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local lust=any(buff(2825),buff(32182))
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
-- Manual casts and channels, and Ghost Wolf, end advice with Attack suppressed.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.manual',revision=2,families={'progression'},class='SHAMAN',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},own(2645))},
}}))
-- Damage premades: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.manual-target',revision=1,families={'progression'},class='SHAMAN',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},own(2645),negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Lightning Shield whenever your own is missing (every damage dealer and the catch-all).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.lightning-shield',revision=1,families={'progression'},class='SHAMAN',steps={
 spell('lightning-shield',324,negate(own(324))),
}}))
-- Every specialization: Wind Shear, Stormlash under any Bloodlust/Heroism in a group, your own Bloodlust on a
-- group boss while nobody is Sated/Exhausted, Astral Shift when low.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.group',revision=1,families={'progression'},class='SHAMAN',steps={
 spell('wind-shear',57994,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('stormlash',120668,all(combat(),{type='GROUP'},lust)),
 spell('bloodlust',2825,all(combat(),{type='GROUP'},classified('worldboss'),negate({type='DEBUFF',unit='player',spell=57724}),
  negate({type='DEBUFF',unit='player',spell=57723}),negate({type='DEBUFF',unit='player',spell=80354}),negate({type='DEBUFF',unit='player',spell=95809}))),
 spell('astral-shift',108271,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35})),
}}))
-- Damage dealers' fire totems: Searing while the fire slot is empty (never over Fire Elemental or Magma); Fire
-- Elemental on an elite or boss, under Bloodlust, or on cooldown with Primal Elementalist; Earth Elemental
-- (off by default) on a boss without Fire Elemental.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.fire-totems',revision=1,families={'progression'},class='SHAMAN',steps={
 spell('searing-totem',3599,all(combat(),{type='ATTACKABLE',unit='target'},negate({type='TOTEM',spell=1}))),
 spell('fire-elemental',2894,all(combat(),any(classified('worldboss'),classified('elite'),lust,{type='TALENT',layout='grid',value=17}))),
 {id='earth-elemental',type='spell',action=2062,ranked=false,disabled=true,conditions=all(combat(),classified('worldboss'),negate({type='TOTEM_SPELL',spell=2894}))},
}}))
-- Enhancement upkeep for every source: Windfury on the main hand (Flametongue before Windfury is learned),
-- Flametongue on an off-hand weapon (read by item type) once the main hand is done; Feral Spirit; Ascendance right after
-- Stormstrike; Elemental Mastery when Ascendance or Fire Elemental is just about ready or far away;
-- Ancestral Swiftness for an instant spender when Maelstrom Weapon is low.
local function sync(id)return any(negate(known(id)),{type='SPELL_COOLDOWN',spell=id,operator='LESSTHAN',value=4},{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=85})end
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.enhancement-upkeep',revision=2,families={'progression'},class='SHAMAN',steps={
 spell('windfury-weapon',8232,negate(imbue(283))),
 spell('flametongue-main',8024,all(negate(known(8232)),negate(imbue(5)))),
 spell('flametongue-off',8024,all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},negate(imbue(5,true)),
  any(imbue(283),all(negate(known(8232)),imbue(5))))),
 spell('feral-spirit',51533,combat()),
 spell('ascendance',114049,all(combat(),negate(own(114051)),{type='SPELL_COOLDOWN',spell=17364,operator='GREATERTHANOREQUALS',value=3})),
 spell('elemental-mastery',16166,all(combat(),any(sync(114049),sync(2894)))),
 spell('ancestral-swiftness',16188,all(combat(),negate(stacks(53817,2)))),
}}))
-- The Wowhead/wowsims Enhancement pack arm (two or more engaged enemies; rejoins the single-target list):
-- Magma at six instead of Searing, Fire Nova at four once Lava Lash has spread Flame Shock, Chain Lightning at
-- five Maelstrom Weapon (three when it finishes before the next swing), Lava Lash on a Flame Shocked target.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.enhancement-aoe',revision=1,families={'progression'},class='SHAMAN',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  spell('magma-totem',8190,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=6},negate({type='TOTEM_SPELL',spell=2894}),negate({type='TOTEM_SPELL',spell=8190}))),
  spell('fire-nova',1535,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},flame)),
  spell('chain-lightning',421,any(stacks(53817,5),all(stacks(53817,3),{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=1.1}))),
  spell('lava-lash',60103,flame),
 }},
}}))
-- Restoration upkeep for every source: Water Shield (Lightning Shield before 20), Earthliving on the main hand,
-- Earth Shield on your focus.
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.restoration-upkeep',revision=1,families={'progression'},class='SHAMAN',steps={
 spell('water-shield',52127,all(negate(own(52127)),negate(own(324)))),
 spell('lightning-shield',324,all(negate(known(52127)),negate(own(324)))),
 spell('earthliving',51730,negate(imbue(3345))),
 spell('earth-shield-focus',974,all({type='FRIENDLY',unit='focus'},negate({type='BUFF',unit='focus',spell=974,ownbuff=true}))),
}}))
-- Restoration damage on an attackable target (solo levelling and quiet moments): Flame Shock on a target that
-- will live, Lava Burst into it, Elemental Blast, Lightning Bolt (Telluric Currents returns mana).
assert(addon:RegisterDefaultBlock({
 id='mop.shaman.restoration-damage',revision=1,families={'progression'},class='SHAMAN',steps={
 spell('flame-shock',8050,all(negate(flame),any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6}))),
 spell('lava-burst',51505,{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator='GREATERTHAN',value=2}),
 spell('elemental-blast',117014),
 spell('lightning-bolt',403),
}}))
