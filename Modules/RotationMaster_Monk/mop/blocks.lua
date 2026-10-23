-- Shared Mists of Pandaria Classic Monk blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.monk.brewmaster, .brewmaster.offensive, .windwalker, .windwalker.simc,
-- .mistweaver and .unspecialized. A content change needs a block revision bump, every consumer's
-- pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Chi is POINT (a negative value is the deficit from the maximum, so Ascension's fifth Chi needs no
-- talent test); energy is POWER. Stances are read by spell (FORM form), never by stance-bar index,
-- which moves with the order stances were learned.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function stacks(id,op,v)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='MONK',steps=steps}))end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local beyond={type='BEYOND_MELEE',unit='target'}
-- Casts and channels (Fists of Fury, Spinning Crane Kick, Crackling Jade Lightning, Zen
-- Meditation) and a target that is not attackable end advice.
block('mop.monk.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('target',negate({type='ATTACKABLE',unit='target'})),
})
-- Every specialization: Legacy of the Emperor when no stats buff from anyone is up, Spear Hand
-- Strike on an interruptible cast.
block('mop.monk.upkeep',{
 spell('legacy',115921,all(negate(combat()),negate(buff(117666)),negate(buff(20217)),negate(buff(1126)),negate(buff(90363)))),
 spell('spear-hand',116705,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
})
-- Both Brewmaster premades: Sturdy Ox, Elusive Brew from six stacks when its dodge buff is down,
-- Xuen on elites or long fights, Fortifying Brew when low.
block('mop.monk.brewmaster-upkeep',{
 spell('ox-stance',115069,negate({type='FORM',form=115069})),
 spell('elusive-brew',115308,all(combat(),stacks(128939,'GREATERTHANOREQUALS',6),negate(own(115308)))),
 spell('xuen',123904,all(combat(),any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=45}))),
 spell('fortifying-brew',115203,all(combat(),health('LESSTHAN',.35))),
},2)
-- Both Brewmaster premades open from range: Chi Wave, a thrown Dizzying Haze or Clash, Keg Smash,
-- then let the auto attack start.
block('mop.monk.brewmaster-pull',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-chi-wave',115098),
  spell('pull-dizzying-haze',115180,beyond),
  spell('pull-clash',122057,beyond),
  spell('pull-keg-smash',121253),
  {id='pull-stop',type='none',conditions={}}}},
},2)
-- Both Windwalker premades: Fierce Tiger, Legacy of the White Tiger, Energizing Brew when its
-- energy fits, Xuen, Storm, Earth, and Fire at two or more enemies (cast it on the other target
-- yourself), Touch of Karma and defensives when low.
block('mop.monk.windwalker-upkeep',{
 spell('tiger-stance',103985,negate({type='FORM',form=103985})),
 spell('white-tiger',116781,all(negate(combat()),negate(buff(116781)))),
 spell('energizing-brew',115288,all(combat(),energy('LESSTHANOREQUALS',40),negate(own(115288)))),
 spell('xuen',123904,all(combat(),any(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 spell('storm-earth-fire',137639,all(combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},negate(own(138228)))),
 spell('touch-of-karma',122470,all(combat(),health('LESSTHAN',.6),{type='ISSAME',unit='targettarget',otherunit='player'})),
 spell('fortifying-brew',115203,all(combat(),health('LESSTHAN',.35))),
 spell('dampen-harm',122278,all(combat(),health('LESSTHAN',.6),negate(own(122470)))),
 spell('diffuse-magic',122783,all(combat(),health('LESSTHAN',.6),negate(own(122470)))),
},2)
-- Both Windwalker premades: pre-cast Chi Wave or Chi Burst from range, then Touch of Death on sight.
block('mop.monk.windwalker-open',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-chi-wave',115098),
  spell('pull-chi-burst',123986),
  {id='pull-stop',type='none',conditions={}}}},
 spell('touch-of-death',115080),
},2)
-- Windwalker talent spenders shared by both premades' single-target lists.
block('mop.monk.windwalker-tail',{
 spell('expel-harm',115072,all(health('LESSTHAN',.9),chi('GREATERTHANOREQUALS',-2))),
 spell('jab',100780,chi('GREATERTHANOREQUALS',-2)),
 spell('blackout-kick',100784,any(negate({type='SPELL_KNOWN',spell=107428}),{type='SPELL_COOLDOWN',spell=107428,operator='GREATERTHANOREQUALS',value=2},chi('GREATERTHANOREQUALS',4))),
 spell('jade-lightning',117952,beyond),
})
