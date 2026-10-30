-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Monk blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.monk.brewmaster, .brewmaster.offensive, .windwalker, .windwalker.simc,
-- .mistweaver and .unspecialized. A content change needs a block revision bump, every consumer's
-- pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Chi is POINT (a negative value is the deficit from the maximum, so Ascension's fifth Chi needs no
-- talent test); energy is POWER. Stances are read by spell (FORM form), never by stance-bar index,
-- which moves with the order stances were learned.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function stacks(id,op,v)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='MONK',steps=steps}))end
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local beyond={type='BEYOND_MELEE',unit='target'}
-- Casts and channels (Fists of Fury, Spinning Crane Kick, Crackling Jade Lightning, Zen
-- Meditation) and a target that is not attackable end advice.
block('mop.monk.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},3)
-- Every specialization: Legacy of the Emperor when no stats buff from anyone is up, Spear Hand
-- Strike on an interruptible cast.
block('mop.monk.upkeep',{
 BuiltinConditions.spell('legacy',115921,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.buff(117666)),BuiltinConditions.negate(BuiltinConditions.buff(20217)),BuiltinConditions.negate(BuiltinConditions.buff(1126)),BuiltinConditions.negate(BuiltinConditions.buff(90363)))),
 BuiltinConditions.spell('spear-hand',116705,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
})
-- Both Brewmaster premades: Sturdy Ox, Elusive Brew from six stacks when its dodge buff is down,
-- Xuen on elites or long fights, Fortifying Brew when low.
block('mop.monk.brewmaster-upkeep',{
 BuiltinConditions.spell('ox-stance',115069,BuiltinConditions.negate({type='FORM',form=115069})),
 BuiltinConditions.spell('elusive-brew',115308,BuiltinConditions.all(BuiltinConditions.combat(),stacks(128939,'GREATERTHANOREQUALS',6),BuiltinConditions.negate(BuiltinConditions.ownBuff(115308)))),
 BuiltinConditions.spell('xuen',123904,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=45}))),
 BuiltinConditions.spell('fortifying-brew',115203,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
},2)
-- Both Brewmaster premades open from range: Chi Wave, a thrown Dizzying Haze or Clash, Keg Smash,
-- then let the auto attack start.
block('mop.monk.brewmaster-pull',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-chi-wave',115098),
  BuiltinConditions.spell('pull-dizzying-haze',115180,beyond),
  BuiltinConditions.spell('pull-clash',122057,beyond),
  BuiltinConditions.spell('pull-keg-smash',121253),
  {id='pull-stop',type='stop',conditions={}}}},
},3)
-- Both Windwalker premades: Fierce Tiger, Legacy of the White Tiger, Energizing Brew when its
-- energy fits, Xuen, Storm, Earth, and Fire at two or more enemies (cast it on the other target
-- yourself), Touch of Karma and defensives when low.
block('mop.monk.windwalker-upkeep',{
 BuiltinConditions.spell('tiger-stance',103985,BuiltinConditions.negate({type='FORM',form=103985})),
 BuiltinConditions.spell('white-tiger',116781,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.buff(116781)))),
 BuiltinConditions.spell('energizing-brew',115288,BuiltinConditions.all(BuiltinConditions.combat(),energy('LESSTHANOREQUALS',40),BuiltinConditions.negate(BuiltinConditions.ownBuff(115288)))),
 BuiltinConditions.spell('xuen',123904,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 BuiltinConditions.spell('storm-earth-fire',137639,BuiltinConditions.all(BuiltinConditions.combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.negate(BuiltinConditions.ownBuff(138228)))),
 BuiltinConditions.spell('touch-of-karma',122470,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.6),{type='ISSAME',unit='targettarget',otherunit='player'})),
 BuiltinConditions.spell('fortifying-brew',115203,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
 BuiltinConditions.spell('dampen-harm',122278,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.6),BuiltinConditions.negate(BuiltinConditions.ownBuff(122470)))),
 BuiltinConditions.spell('diffuse-magic',122783,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.6),BuiltinConditions.negate(BuiltinConditions.ownBuff(122470)))),
},2)
-- Both Windwalker premades: pre-cast Chi Wave or Chi Burst from range, then Touch of Death on sight.
block('mop.monk.windwalker-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-chi-wave',115098),
  BuiltinConditions.spell('pull-chi-burst',123986),
  {id='pull-stop',type='stop',conditions={}}}},
 BuiltinConditions.spell('touch-of-death',115080),
},3)
-- Windwalker talent spenders shared by both premades' single-target lists.
block('mop.monk.windwalker-tail',{
 BuiltinConditions.spell('expel-harm',115072,BuiltinConditions.all(health('LESSTHAN',.9),chi('GREATERTHANOREQUALS',-2))),
 BuiltinConditions.spell('jab',100780,chi('GREATERTHANOREQUALS',-2)),
 BuiltinConditions.spell('blackout-kick',100784,BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_KNOWN',spell=107428}),{type='SPELL_COOLDOWN',spell=107428,operator='GREATERTHANOREQUALS',value=2},chi('GREATERTHANOREQUALS',4))),
 BuiltinConditions.spell('jade-lightning',117952,beyond),
})
