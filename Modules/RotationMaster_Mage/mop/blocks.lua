-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.mage.arcane, .arcane.icyveins, .fire, .fire.icyveins, .frost and .unspecialized.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Arcane Charges are a debuff the Mage puts on itself in MoP (36032), read with DEBUFF_STACKS; the
-- talent rows are grid TALENT indexes ((tier-1)*3+column): 13 Nether Tempest, 14 Living Bomb,
-- 15 Frost Bomb, 16 Invocation, 17 Rune of Power.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function remain(id,v)return{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=v}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v}end
local function talent(index)return{type='TALENT',layout='grid',value=index}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function charges(v)return{type='DEBUFF_STACKS',unit='player',spell=36032,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function close(yards,n)return{type='DISTANCE_COUNT',enemy=true,distance=yards,operator='GREATERTHANOREQUALS',value=n}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function lives(op,v)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=v}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='MAGE',steps=steps}))end
local MISSILES,ALTER,FLOES,POM=79683,110909,108839,12043
-- Casts and channels (Arcane Missiles, Evocation, Blizzard) and a target that is not attackable end advice.
block('mop.mage.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},3)
-- Every Mage: Brilliance, Counterspell (off the GCD), a Mana Gem in the bags, Mirror Image when the
-- images get their full 30 s, Ice Barrier and Ice Floes when talented, the tier-6 upkeep (Invocation's
-- Evocation, Rune of Power) and, with neither, Evocation for mana. Time Warp and Spellsteal are
-- optional (raids assign Bloodlust).
block('mop.mage.upkeep',{
 BuiltinConditions.spell('brilliance',1459,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(1459)),BuiltinConditions.negate(BuiltinConditions.buff(61316)))),
 BuiltinConditions.spell('counterspell',2139,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('conjure-gem',759,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='CARRYING',item={36799,81901},operator='EQUALS',value=0})),
 BuiltinConditions.spell('mirror-image',55342,BuiltinConditions.all(BuiltinConditions.combat(),lives('GREATERTHANOREQUALS',30))),
 BuiltinConditions.spell('ice-barrier',11426,BuiltinConditions.negate(BuiltinConditions.buff(11426))),
 BuiltinConditions.spell('ice-floes',FLOES,BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(BuiltinConditions.buff(FLOES)))),
 BuiltinConditions.spell('invocation',12051,BuiltinConditions.all(talent(16),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(116257)),remain(116257,3)))),
 BuiltinConditions.spell('rune-of-power',116011,BuiltinConditions.all(talent(17),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(116014)),remain(116014,1.5)))),
 BuiltinConditions.spell('evocation',12051,BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.2),BuiltinConditions.negate(talent(16)),BuiltinConditions.negate(talent(17)),lives('GREATERTHANOREQUALS',30))),
 off('time-warp',80353,BuiltinConditions.all({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},
  BuiltinConditions.negate(BuiltinConditions.buff(80354)),BuiltinConditions.negate(BuiltinConditions.buff(57724)),BuiltinConditions.negate(BuiltinConditions.buff(57723)),BuiltinConditions.negate(BuiltinConditions.buff(95809)))),
 off('spellsteal',30449,{type='STEALABLE',unit='target'}),
})
-- Armor when none is up (an armor you chose is kept): Frost Armor (54), else Molten Armor (34).
local bare=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(7302)),BuiltinConditions.negate(BuiltinConditions.buff(30482)),BuiltinConditions.negate(BuiltinConditions.buff(6117)))
block('mop.mage.armor-frost',{
 BuiltinConditions.spell('frost-armor',7302,bare),
 BuiltinConditions.spell('molten-armor',30482,BuiltinConditions.all(bare,BuiltinConditions.negate(BuiltinConditions.known(7302)))),
})
block('mop.mage.armor-molten',{
 BuiltinConditions.spell('molten-armor',30482,bare),
})
-- Tier-5 bomb, one step per talent (the others are skipped): Living Bomb when missing or on its last
-- tick on a target that lives through three more, Nether Tempest under 1 s, Frost Bomb when missing.
block('mop.mage.bombs',{
 BuiltinConditions.spell('living-bomb',44457,BuiltinConditions.all(talent(14),BuiltinConditions.any(BuiltinConditions.negate(mine(44457)),expiring(44457,3)),lives('GREATERTHANOREQUALS',9))),
 BuiltinConditions.spell('nether-tempest',114923,BuiltinConditions.all(talent(13),BuiltinConditions.any(BuiltinConditions.negate(mine(114923)),expiring(114923,1)))),
 BuiltinConditions.spell('frost-bomb',112948,BuiltinConditions.all(talent(15),BuiltinConditions.negate(mine(112948)))),
})
-- Both Arcane premades: pull with Arcane Blast; Barrage just before Alter Time snaps back (the
-- charges return with it); the bomb; inside Alter Time only Missiles on a proc and Arcane Blast.
block('mop.mage.arcane-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('pull-blast',30451),BuiltinConditions.stop('pull-stop')}},
 BuiltinConditions.spell('alter-barrage',44425,BuiltinConditions.all(BuiltinConditions.buff(ALTER),remain(ALTER,2))),
 {id='bombs',type='block',block='mop.mage.bombs',prefix='bomb-'},
 {id='alter',type='branch',conditions=BuiltinConditions.buff(ALTER),onFalse={},onTrue={
  BuiltinConditions.spell('alter-missiles',5143,BuiltinConditions.buff(MISSILES)),BuiltinConditions.spell('alter-blast',30451),BuiltinConditions.stop('alter-stop')}},
},3)
-- Both Arcane premades: two or more fighting you, Barrage every four charges; five close by, Cone
-- of Cold and Arcane Explosion. On the move (no Ice Floes or Presence of Mind): Barrage at four
-- charges without a proc, Fire Blast, Ice Lance.
block('mop.mage.arcane-aoe-moving',{
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-barrage',44425,charges(4)),
  BuiltinConditions.spell('aoe-cone',120,close(12,4)),
  BuiltinConditions.spell('aoe-explosion',1449,close(10,4))}},
 {id='moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(BuiltinConditions.buff(FLOES)),BuiltinConditions.negate(BuiltinConditions.buff(POM))),onFalse={},onTrue={
  BuiltinConditions.spell('moving-barrage',44425,BuiltinConditions.all(charges(4),BuiltinConditions.negate(BuiltinConditions.buff(MISSILES)))),
  BuiltinConditions.spell('moving-fire-blast',2136),
  BuiltinConditions.spell('moving-ice-lance',30455),
  BuiltinConditions.stop('moving-stop')}},
},2)
-- Both Fire premades: pull with a hard Pyroblast (Frostfire Bolt on the move); Pyroblast under
-- Presence of Mind; inside Alter Time every Pyroblast!; Combustion right after a Pyroblast with
-- Ignite and the Pyroblast DoT up (RM cannot read Ignite's size), or on a target about to die.
block('mop.mage.fire-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-pyroblast',11366,BuiltinConditions.negate({type='MOVING'})),BuiltinConditions.spell('pull-frostfire',44614),BuiltinConditions.stop('pull-stop')}},
 BuiltinConditions.spell('presence-pyroblast',11366,BuiltinConditions.buff(POM)),
 {id='alter',type='branch',conditions=BuiltinConditions.buff(ALTER),onFalse={},onTrue={BuiltinConditions.spell('alter-pyroblast',11366,BuiltinConditions.buff(48108))}},
 BuiltinConditions.spell('combustion',11129,BuiltinConditions.any(BuiltinConditions.all(mine(12654),mine(11366),{type='SPELL_HISTORY_TIME',spell=11366,operator='LESSTHAN',value=1.5}),lives('LESSTHAN',12))),
},3)
-- Both Fire premades: two or more fighting you, Inferno Blast spreads Pyroblast and Ignite; five
-- close by, Cone of Cold and Arcane Explosion. Inferno Blast (Fire Blast before 24) on Heating Up
-- without a Pyroblast!.
block('mop.mage.fire-spend',{
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-spread',108853,BuiltinConditions.all(mine(11366),mine(12654))),
  BuiltinConditions.spell('aoe-cone',120,close(12,4)),
  BuiltinConditions.spell('aoe-explosion',1449,close(10,4))}},
 BuiltinConditions.spell('inferno-blast',108853,BuiltinConditions.all(BuiltinConditions.buff(48107),BuiltinConditions.negate(BuiltinConditions.buff(48108)))),
 BuiltinConditions.spell('fire-blast',2136,BuiltinConditions.all(BuiltinConditions.buff(48107),BuiltinConditions.negate(BuiltinConditions.buff(48108)),BuiltinConditions.negate(BuiltinConditions.known(108853)))),
})
-- Both Fire premades: Scorch on the move (no Ice Floes), Fireball, Frostfire Bolt before 12.
block('mop.mage.fire-filler',{
 {id='moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(BuiltinConditions.buff(FLOES))),onFalse={},onTrue={
  BuiltinConditions.spell('moving-scorch',2948),BuiltinConditions.spell('moving-inferno',108853),BuiltinConditions.spell('moving-fire-blast',2136,BuiltinConditions.negate(BuiltinConditions.known(108853))),
  BuiltinConditions.spell('moving-ice-lance',30455),BuiltinConditions.stop('moving-stop')}},
 BuiltinConditions.spell('fireball',133),
 BuiltinConditions.spell('frostfire',44614,BuiltinConditions.negate(BuiltinConditions.known(133))),
},2)
