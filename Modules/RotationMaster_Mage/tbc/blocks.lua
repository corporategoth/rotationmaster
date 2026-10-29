-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.mage.frost, rm.tbc.mage.fire.icyveins, rm.tbc.mage.fire.wowhead and
-- rm.tbc.mage.arcane. A content change needs a block revision bump, every consumer's pin
-- and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id,anyrank)return{type='BUFF',unit='player',spell=id,anyrank=anyrank}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
-- Casts, channels (Missiles, Blizzard, Evocation) and a target that is not ours to pull end advice.
assert(addon:RegisterDefaultBlock({id='tbc.mage.boundaries',revision=3,families={'tbc'},class='MAGE',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'})))))),
}}))
-- Frostbolt is the filler once learned (level 4); Fireball only before that.
assert(addon:RegisterDefaultBlock({id='tbc.mage.frostbolt',revision=1,families={'tbc'},class='MAGE',steps={
 {id='frostbolt-known',type='branch',conditions=BuiltinConditions.known(116),onTrue={BuiltinConditions.spell('frostbolt',116)},onFalse={BuiltinConditions.spell('fireball',133)}},
}}))
-- Out of spells: wand, never toggling an active wand off; casters never melee.
assert(addon:RegisterDefaultBlock({id='tbc.mage.wand-finish',revision=2,families={'tbc'},class='MAGE',steps={
 {id='wand-known',type='branch',conditions=BuiltinConditions.known(5019),onFalse={},onTrue={
  BuiltinConditions.stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  BuiltinConditions.spell('shoot',5019)}},
 BuiltinConditions.stop('exhausted'),
}}))
-- Instants while moving (Fire and Arcane): Fire Blast, then Ice Lance.
assert(addon:RegisterDefaultBlock({id='tbc.mage.moving-fire-blast',revision=2,families={'tbc'},class='MAGE',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={BuiltinConditions.spell('fire-blast',2136),BuiltinConditions.spell('ice-lance',30455),BuiltinConditions.stop('moving-stop')}},
}}))
-- Fire AoE: Blast Wave and Dragon's Breath when ready, Flamestrike when its burn is not on the target.
assert(addon:RegisterDefaultBlock({id='tbc.mage.fire-aoe',revision=1,families={'tbc'},class='MAGE',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('blast-wave',11113),BuiltinConditions.spell('dragons-breath',31661),
  BuiltinConditions.spell('flamestrike',2120,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true}))}},
}}))
-- Improved Scorch (Fire talent 10) keeps five Fire Vulnerability stacks, refreshed before 5.5 s.
assert(addon:RegisterDefaultBlock({id='tbc.mage.improved-scorch',revision=1,families={'tbc'},class='MAGE',steps={
 BuiltinConditions.spell('scorch',2948,BuiltinConditions.all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
  BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=22959}),
   {type='DEBUFF_STACKS',unit='target',spell=22959,operator='LESSTHAN',value=5},
   {type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5.5}))),
}}))
-- Armor: any armor already up is the player's choice. With none up and learning readable,
-- offer the preferred learned armor; an unready preferred armor never licenses a lower one.
local function missing(id)return BuiltinConditions.negate(buff(id,true))end
local function readable(id)return BuiltinConditions.any(BuiltinConditions.known(id),BuiltinConditions.negate(BuiltinConditions.known(id)))end
local function armor(...)return BuiltinConditions.all(missing(168),missing(7302),missing(6117),missing(30482),
 readable(168),readable(7302),readable(6117),...)end
assert(addon:RegisterDefaultBlock({id='tbc.mage.armor',revision=1,families={'tbc'},class='MAGE',steps={
 BuiltinConditions.spell('mage-armor',6117,armor(BuiltinConditions.known(6117))),
 BuiltinConditions.spell('ice-armor',7302,armor(BuiltinConditions.negate(BuiltinConditions.known(6117)),BuiltinConditions.known(7302))),
 BuiltinConditions.spell('frost-armor',168,armor(BuiltinConditions.negate(BuiltinConditions.known(6117)),BuiltinConditions.negate(BuiltinConditions.known(7302)),BuiltinConditions.known(168))),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.mage.armor-molten',revision=1,families={'tbc'},class='MAGE',steps={
 BuiltinConditions.spell('molten-armor',30482,armor(readable(30482),BuiltinConditions.known(30482))),
 BuiltinConditions.spell('mage-armor',6117,armor(readable(30482),BuiltinConditions.negate(BuiltinConditions.known(30482)),BuiltinConditions.known(6117))),
 BuiltinConditions.spell('ice-armor',7302,armor(readable(30482),BuiltinConditions.negate(BuiltinConditions.known(30482)),BuiltinConditions.negate(BuiltinConditions.known(6117)),BuiltinConditions.known(7302))),
 BuiltinConditions.spell('frost-armor',168,armor(readable(30482),BuiltinConditions.negate(BuiltinConditions.known(30482)),BuiltinConditions.negate(BuiltinConditions.known(6117)),BuiltinConditions.negate(BuiltinConditions.known(7302)),BuiltinConditions.known(168))),
}}))
-- Independent reminders shared by every Mage premade. Talent cooldowns need the talent
-- learned (native readiness), so a spec that lacks one never sees it.
local lust=BuiltinConditions.any(buff(2825),buff(32182))
assert(addon:RegisterDefaultBlock({id='tbc.mage.upkeep',revision=1,families={'tbc'},class='MAGE',steps={
 BuiltinConditions.spell('intellect',1459,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(1459),missing(23028))),
 {id='mana-gem',type='item',action={22044,8008,8007,5513,5514},conditions=BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.75))},
 BuiltinConditions.spell('evocation',12051,BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.2),BuiltinConditions.negate(buff(12042)),BuiltinConditions.negate(buff(12472)),BuiltinConditions.negate(lust))),
 BuiltinConditions.spell('counterspell',2139,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('spellsteal',30449,{type='STEALABLE',unit='target'}),
 BuiltinConditions.spell('remove-curse',475,BuiltinConditions.all({type='FRIENDLY',unit='target'},{type='DISPELLABLE',unit='target',debufftype='Curse'})),
 BuiltinConditions.spell('ice-barrier',11426,BuiltinConditions.all(BuiltinConditions.negate(buff(11426,true)),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.combat()),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.6}))),
 BuiltinConditions.spell('mana-shield',1463,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},missing(1463),missing(11426))),
 BuiltinConditions.spell('icy-veins',12472,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(12472)))),
 BuiltinConditions.spell('cold-snap',11958,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(12472)),{type='SPELL_COOLDOWN',spell=12472,operator='GREATERTHAN',value=20})),
 BuiltinConditions.spell('water-elemental',31687,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='PET'}))),
 BuiltinConditions.spell('arcane-power',12042,BuiltinConditions.all(BuiltinConditions.combat(),mana('GREATERTHAN',.4))),
 BuiltinConditions.spell('presence-of-mind',12043,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(buff(12042),{type='MOVING'}))),
 BuiltinConditions.spell('combustion',11129,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},
  {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=200}))),
}}))
