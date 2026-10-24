-- Shared Mists of Pandaria Classic Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.mage.arcane, .arcane.icyveins, .fire, .fire.icyveins, .frost and .unspecialized.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Arcane Charges are a debuff the Mage puts on itself in MoP (36032), read with DEBUFF_STACKS; the
-- talent rows are grid TALENT indexes ((tier-1)*3+column): 13 Nether Tempest, 14 Living Bomb,
-- 15 Frost Bomb, 16 Invocation, 17 Rune of Power.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function remain(id,v)return{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=v}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v}end
local function talent(index)return{type='TALENT',layout='grid',value=index}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function charges(v)return{type='DEBUFF_STACKS',unit='player',spell=36032,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function close(yards,n)return{type='DISTANCE_COUNT',enemy=true,distance=yards,operator='GREATERTHANOREQUALS',value=n}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function lives(op,v)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='MAGE',steps=steps}))end
local MISSILES,ALTER,FLOES,POM=79683,110909,108839,12043
-- Casts and channels (Arcane Missiles, Evocation, Blizzard) and a target that is not attackable end advice.
block('mop.mage.boundaries',{
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))),
},3)
-- Every Mage: Brilliance, Counterspell (off the GCD), a Mana Gem in the bags, Mirror Image when the
-- images get their full 30 s, Ice Barrier and Ice Floes when talented, the tier-6 upkeep (Invocation's
-- Evocation, Rune of Power) and, with neither, Evocation for mana. Time Warp and Spellsteal are
-- optional (raids assign Bloodlust).
block('mop.mage.upkeep',{
 spell('brilliance',1459,all(negate(buff(1459)),negate(buff(61316)))),
 spell('counterspell',2139,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('conjure-gem',759,all(negate(combat()),{type='CARRYING',item={36799,81901},operator='EQUALS',value=0})),
 spell('mirror-image',55342,all(combat(),lives('GREATERTHANOREQUALS',30))),
 spell('ice-barrier',11426,negate(buff(11426))),
 spell('ice-floes',FLOES,all({type='MOVING'},negate(buff(FLOES)))),
 spell('invocation',12051,all(talent(16),any(negate(buff(116257)),remain(116257,3)))),
 spell('rune-of-power',116011,all(talent(17),any(negate(buff(116014)),remain(116014,1.5)))),
 spell('evocation',12051,all(combat(),mana('LESSTHAN',.2),negate(talent(16)),negate(talent(17)),lives('GREATERTHANOREQUALS',30))),
 off('time-warp',80353,all({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},
  negate(buff(80354)),negate(buff(57724)),negate(buff(57723)),negate(buff(95809)))),
 off('spellsteal',30449,{type='STEALABLE',unit='target'}),
})
-- Armor when none is up (an armor you chose is kept): Frost Armor (54), else Molten Armor (34).
local bare=all(negate(buff(7302)),negate(buff(30482)),negate(buff(6117)))
block('mop.mage.armor-frost',{
 spell('frost-armor',7302,bare),
 spell('molten-armor',30482,all(bare,negate(known(7302)))),
})
block('mop.mage.armor-molten',{
 spell('molten-armor',30482,bare),
})
-- Tier-5 bomb, one step per talent (the others are skipped): Living Bomb when missing or on its last
-- tick on a target that lives through three more, Nether Tempest under 1 s, Frost Bomb when missing.
block('mop.mage.bombs',{
 spell('living-bomb',44457,all(talent(14),any(negate(mine(44457)),expiring(44457,3)),lives('GREATERTHANOREQUALS',9))),
 spell('nether-tempest',114923,all(talent(13),any(negate(mine(114923)),expiring(114923,1)))),
 spell('frost-bomb',112948,all(talent(15),negate(mine(112948)))),
})
-- Both Arcane premades: pull with Arcane Blast; Barrage just before Alter Time snaps back (the
-- charges return with it); the bomb; inside Alter Time only Missiles on a proc and Arcane Blast.
block('mop.mage.arcane-open',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('pull-blast',30451),stop('pull-stop')}},
 spell('alter-barrage',44425,all(buff(ALTER),remain(ALTER,2))),
 {id='bombs',type='block',block='mop.mage.bombs',prefix='bomb-'},
 {id='alter',type='branch',conditions=buff(ALTER),onFalse={},onTrue={
  spell('alter-missiles',5143,buff(MISSILES)),spell('alter-blast',30451),stop('alter-stop')}},
},3)
-- Both Arcane premades: two or more fighting you, Barrage every four charges; five close by, Cone
-- of Cold and Arcane Explosion. On the move (no Ice Floes or Presence of Mind): Barrage at four
-- charges without a proc, Fire Blast, Ice Lance.
block('mop.mage.arcane-aoe-moving',{
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  spell('aoe-barrage',44425,charges(4)),
  spell('aoe-cone',120,close(12,4)),
  spell('aoe-explosion',1449,close(10,4))}},
 {id='moving',type='branch',conditions=all({type='MOVING'},negate(buff(FLOES)),negate(buff(POM))),onFalse={},onTrue={
  spell('moving-barrage',44425,all(charges(4),negate(buff(MISSILES)))),
  spell('moving-fire-blast',2136),
  spell('moving-ice-lance',30455),
  stop('moving-stop')}},
},2)
-- Both Fire premades: pull with a hard Pyroblast (Frostfire Bolt on the move); Pyroblast under
-- Presence of Mind; inside Alter Time every Pyroblast!; Combustion right after a Pyroblast with
-- Ignite and the Pyroblast DoT up (RM cannot read Ignite's size), or on a target about to die.
block('mop.mage.fire-open',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-pyroblast',11366,negate({type='MOVING'})),spell('pull-frostfire',44614),stop('pull-stop')}},
 spell('presence-pyroblast',11366,buff(POM)),
 {id='alter',type='branch',conditions=buff(ALTER),onFalse={},onTrue={spell('alter-pyroblast',11366,buff(48108))}},
 spell('combustion',11129,any(all(mine(12654),mine(11366),{type='SPELL_HISTORY_TIME',spell=11366,operator='LESSTHAN',value=1.5}),lives('LESSTHAN',12))),
},3)
-- Both Fire premades: two or more fighting you, Inferno Blast spreads Pyroblast and Ignite; five
-- close by, Cone of Cold and Arcane Explosion. Inferno Blast (Fire Blast before 24) on Heating Up
-- without a Pyroblast!.
block('mop.mage.fire-spend',{
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  spell('aoe-spread',108853,all(mine(11366),mine(12654))),
  spell('aoe-cone',120,close(12,4)),
  spell('aoe-explosion',1449,close(10,4))}},
 spell('inferno-blast',108853,all(buff(48107),negate(buff(48108)))),
 spell('fire-blast',2136,all(buff(48107),negate(buff(48108)),negate(known(108853)))),
})
-- Both Fire premades: Scorch on the move (no Ice Floes), Fireball, Frostfire Bolt before 12.
block('mop.mage.fire-filler',{
 {id='moving',type='branch',conditions=all({type='MOVING'},negate(buff(FLOES))),onFalse={},onTrue={
  spell('moving-scorch',2948),spell('moving-inferno',108853),spell('moving-fire-blast',2136,negate(known(108853))),
  spell('moving-ice-lance',30455),stop('moving-stop')}},
 spell('fireball',133),
 spell('frostfire',44614,negate(known(133))),
},2)
