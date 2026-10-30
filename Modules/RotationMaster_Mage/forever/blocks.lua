-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.mage.frost, rm.forever.mage.fire, rm.forever.mage.fire.icyveins and
-- rm.forever.mage.arcane. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local fingers=BuiltinConditions.any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
-- Fingers of Frost while a Frostbolt is still casting: Ice Lance now (cancel, or batch it as the
-- bolt lands; the guides differ, the highlight serves both).
assert(addon:RegisterDefaultBlock({id='forever.mage.lance-batch',revision=1,families={'forever'},class='MAGE',steps={
 BuiltinConditions.spell('lance-batch',1312002,BuiltinConditions.all({type='CASTING',unit='player'},fingers)),
}}))
-- Casts and channels (Missiles, Blizzard, Evocation) and a target that is not attackable end advice.
assert(addon:RegisterDefaultBlock({id='forever.mage.boundaries',revision=3,families={'forever'},class='MAGE',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
}}))
-- Frostbolt once learned (level 4); Fireball only before it.
assert(addon:RegisterDefaultBlock({id='forever.mage.frostbolt',revision=1,families={'forever'},class='MAGE',steps={
 BuiltinConditions.spell('frostbolt',116),
 BuiltinConditions.spell('fireball',133,BuiltinConditions.negate(BuiltinConditions.known(116))),
}}))
-- Solo with no spell castable before it (mana is secret on Forever; an unaffordable spell is not
-- ready): wand, never toggling an active wand off. Casters never melee.
assert(addon:RegisterDefaultBlock({id='forever.mage.wand',revision=3,families={'forever'},class='MAGE',steps={
 {id='wand',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  BuiltinConditions.stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  BuiltinConditions.spell('shoot',5019)}},
 BuiltinConditions.stop('exhausted'),
}}))
-- Fire on the move: Fire Blast, then Ice Lance for a Frost-dipping hybrid.
assert(addon:RegisterDefaultBlock({id='forever.mage.fire-moving',revision=2,families={'forever'},class='MAGE',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-fire-blast',2136),BuiltinConditions.spell('moving-ice-lance',1312002),BuiltinConditions.stop('moving-stop')}},
}}))
-- Fire packs (four or more fighting you): Flamestrike unless your burn is already down (it no longer
-- stacks), Blast Wave, Arcane Explosion.
assert(addon:RegisterDefaultBlock({id='forever.mage.fire-aoe',revision=1,families={'forever'},class='MAGE',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  BuiltinConditions.spell('aoe-flamestrike',2120,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
  BuiltinConditions.spell('aoe-blast-wave',11113),
  BuiltinConditions.spell('aoe-arcane-explosion',1449)}},
}}))
-- Independent reminders for every Mage premade. Armor: none of Frost, Ice or Mage Armor up, then
-- Ice (Frost before 30) solo and Mage Armor in a group; an armor already up is your choice. Mana is
-- secret on Forever, so Evocation is the player's call.
local bare=BuiltinConditions.all(BuiltinConditions.negate(buff(168)),BuiltinConditions.negate(buff(7302)),BuiltinConditions.negate(buff(6117)))
local group={type='GROUP'}
assert(addon:RegisterDefaultBlock({id='forever.mage.upkeep',revision=2,families={'forever'},class='MAGE',steps={
 BuiltinConditions.spell('intellect',1459,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(1459)),BuiltinConditions.negate(buff(23028)))),
 BuiltinConditions.spell('mage-armor',6117,BuiltinConditions.all(bare,group)),
 BuiltinConditions.spell('ice-armor',7302,BuiltinConditions.all(bare,BuiltinConditions.any(BuiltinConditions.negate(group),BuiltinConditions.negate(BuiltinConditions.known(6117))))),
 BuiltinConditions.spell('frost-armor',168,BuiltinConditions.all(bare,BuiltinConditions.negate(BuiltinConditions.known(7302)),BuiltinConditions.any(BuiltinConditions.negate(group),BuiltinConditions.negate(BuiltinConditions.known(6117))))),
 BuiltinConditions.spell('ice-barrier',11426,BuiltinConditions.negate(buff(11426))),
 BuiltinConditions.spell('counterspell',2139,{type='CAST_INTERRUPTABLE',unit='target'}),
 BuiltinConditions.spell('remove-curse',475,{type='DISPELLABLE',unit='player',debufftype='Curse'}),
 BuiltinConditions.spell('frost-nova',122,BuiltinConditions.all(BuiltinConditions.combat(),{type='DISTANCE',unit='target',value=8},BuiltinConditions.negate({type='CLASSIFICATION',unit='target',value='worldboss'}))),
}}))
