-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Druid blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.druid.unspecialized, .balance, .feral, .feral.icyveins, .guardian, .restoration
-- and .restoration.wowhead. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read by their spell (FORM form: Cat 768, Bear 5487, travel 783/1066/33943/40120, Moonkin
-- 24858, Tree of Life 33891), never the shapeshift index, which shifts as forms are learned. Actions name the spellbook IDs (Mangle 33917, Thrash 106832, Swipe 106785,
-- Berserk 106952); buffs and debuffs name the form's own aura.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function swing(id,conditions)return{id=id,type='stop',conditions=conditions or{}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='DRUID',steps=steps}))end
local CAT,BEAR=768,5487
local travelling=BuiltinConditions.any(BuiltinConditions.form(783),BuiltinConditions.form(1066),BuiltinConditions.form(33943),BuiltinConditions.form(40120))
local hurt=function(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local group=function(pct,n,yards)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=yards or 40,healthoperator='LESSTHAN',health=pct,operator='GREATERTHANOREQUALS',value=n}end
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local roar=BuiltinConditions.any(BuiltinConditions.ownBuff(52610),BuiltinConditions.ownBuff(127538))
-- A target worth a DoT: elite, above 30% health, or forecast to live six seconds (the forecast alone
-- is unavailable early in a fight).
local lives=BuiltinConditions.any(elite,{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
-- Casts and channels (Astral Communion, Hurricane, Tranquility) and travel forms end advice.
block('mop.druid.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},travelling)),
},4)
-- Feral, Guardian and the catch-all: the boundaries above, or no attackable target, end advice (one Stop).
block('mop.druid.melee-boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},travelling,BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},2)
-- Damage and tank premades: nothing to do without an attackable target.
block('mop.druid.target',{
 BuiltinConditions.stop('target',BuiltinConditions.negate({type='ATTACKABLE',unit='target'})),
},2)
-- Every specialization: Mark of the Wild between pulls when no equivalent stat buff is up.
block('mop.druid.mark',{
 BuiltinConditions.spell('mark',1126,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.buff(1126)),BuiltinConditions.negate(BuiltinConditions.buff(20217)),BuiltinConditions.negate(BuiltinConditions.buff(115921)),BuiltinConditions.negate(BuiltinConditions.buff(90363)))),
})
-- Both Feral premades: Tiger's Fury below 35 energy outside Berserk, Incarnation with Berserk,
-- Force of Nature with Tiger's Fury or at three charges, Nature's Vigil, Nature's Swiftness for a
-- Dream of Cenarius heal, interrupts and defensives. Heart of the Wild's Wrath weave stays manual.
block('mop.druid.feral-upkeep',{
 BuiltinConditions.spell('tigers-fury',5217,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.form(CAT),power('LESSTHAN',35),BuiltinConditions.negate(BuiltinConditions.ownBuff(106951)))),
 BuiltinConditions.spell('incarnation',102543,BuiltinConditions.ownBuff(106951)),
 BuiltinConditions.spell('force-of-nature',102703,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='SPELL_CHARGES',spell=102703,operator='EQUALS',value=3},BuiltinConditions.ownBuff(5217)))),
 BuiltinConditions.spell('natures-vigil',124974,BuiltinConditions.any(BuiltinConditions.ownBuff(106951),BuiltinConditions.ownBuff(5217))),
 BuiltinConditions.spell('natures-swiftness',132158,BuiltinConditions.all(talent(17),BuiltinConditions.negate(BuiltinConditions.ownBuff(69369)),cp('GREATERTHANOREQUALS',4))),
 BuiltinConditions.spell('skull-bash',106839,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('survival-instincts',61336,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.4))),
 BuiltinConditions.spell('barkskin',22812,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.6))),
 off('heart-of-the-wild',108288,BuiltinConditions.combat()),
},2)
-- Both Feral premades: a short Bear arm (Might of Ursoc, off-tanking), Cat Form (Dream of Cenarius
-- Healing Touch first before a pull), the stealth opener, then Savage Roar, Faerie Fire on elites
-- without full Weakened Armor, and Healing Touch on Predatory Swiftness for Dream of Cenarius (or
-- below half health).
block('mop.druid.feral-open',{
 {id='bear',type='branch',conditions=BuiltinConditions.form(BEAR),onFalse={},onTrue={
  BuiltinConditions.spell('bear-thrash',106832,BuiltinConditions.negate(bleed(77758))),
  BuiltinConditions.spell('bear-mangle',33917),
  BuiltinConditions.spell('bear-lacerate',33745),
  BuiltinConditions.spell('bear-maul',6807,power('GREATERTHANOREQUALS',60)),
  swing('bear-stop')}},
 {id='cat',type='branch',conditions=BuiltinConditions.form(CAT),onTrue={},onFalse={
  BuiltinConditions.spell('cat-dream',5185,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),talent(17),BuiltinConditions.negate(BuiltinConditions.ownBuff(145152)))),
  BuiltinConditions.spell('cat-form',768),
  BuiltinConditions.stop('cat-stop')}},
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-roar',52610,BuiltinConditions.negate(roar)),
  BuiltinConditions.spell('pull-prowl',5215,BuiltinConditions.negate({type='STEALTHED'})),
  BuiltinConditions.spell('pull-ravage',6785,{type='STEALTHED'}),
  BuiltinConditions.spell('pull-pounce',9005,BuiltinConditions.all({type='STEALTHED'},BuiltinConditions.negate({type='SPELL_KNOWN',spell=6785}))),
  BuiltinConditions.spell('pull-rake',1822),
  swing('pull-stop')}},
 BuiltinConditions.spell('roar',52610,BuiltinConditions.all(cp('GREATERTHANOREQUALS',1),BuiltinConditions.any(BuiltinConditions.negate(roar),
  BuiltinConditions.all(BuiltinConditions.ownBuff(52610),{type='BUFF_REMAIN',unit='player',spell=52610,ownbuff=true,operator='LESSTHANOREQUALS',value=3}),
  BuiltinConditions.all(BuiltinConditions.ownBuff(127538),{type='BUFF_REMAIN',unit='player',spell=127538,ownbuff=true,operator='LESSTHANOREQUALS',value=3})))),
 BuiltinConditions.spell('faerie-fire',770,BuiltinConditions.all(elite,{type='DEBUFF_STACKS',unit='target',spell=113746,operator='LESSTHAN',value=3})),
 BuiltinConditions.spell('swift-touch',5185,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.ownBuff(69369),BuiltinConditions.ownBuff(132158)),BuiltinConditions.any(
  BuiltinConditions.all(talent(17),BuiltinConditions.any(cp('GREATERTHANOREQUALS',4),{type='BUFF_REMAIN',unit='player',spell=69369,ownbuff=true,operator='LESSTHANOREQUALS',value=2}),
   BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(106951)),cp('EQUALS',5))),
  health('LESSTHAN',.5)))),
},4)
-- Both Feral premades: four or more enemies on you, Thrash then Swipe.
block('mop.druid.feral-aoe',{
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  BuiltinConditions.spell('aoe-thrash',106832,BuiltinConditions.any(BuiltinConditions.negate(bleed(106830)),remain(106830,'LESSTHAN',3))),
  BuiltinConditions.spell('aoe-swipe',106785),
  swing('aoe-stop')}},
},2)
-- Both Restoration premades: group cooldowns, the focus tank's Lifebloom and Ironbark, mana and
-- dispels. Tranquility and Genesis are raid assignments and ship off.
block('mop.druid.healer-upkeep',{
 BuiltinConditions.spell('lifebloom-focus',33763,BuiltinConditions.all({type='FRIENDLY',unit='focus'},BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='focus',spell=33763,ownbuff=true}),
  {type='BUFF_STACKS',unit='focus',spell=33763,ownbuff=true,operator='LESSTHAN',value=3},
  {type='BUFF_REMAIN',unit='focus',spell=33763,ownbuff=true,operator='LESSTHAN',value=4}))),
 off('mushroom',145205,BuiltinConditions.combat()),
 BuiltinConditions.spell('bloom',102791,group(.7,4)),
 BuiltinConditions.spell('ironbark',102342,BuiltinConditions.all({type='FRIENDLY',unit='focus'},{type='HEALTHPCT',unit='focus',operator='LESSTHAN',value=.6})),
 BuiltinConditions.spell('natures-swiftness',132158,BuiltinConditions.all({type='FRIENDLY',unit='target'},hurt(.35))),
 BuiltinConditions.spell('force-of-nature',102693,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(group(.9,3),{type='SPELL_CHARGES',spell=102693,operator='EQUALS',value=3}))),
 BuiltinConditions.spell('tree-of-life',33891,group(.75,4)),
 BuiltinConditions.spell('natures-vigil',124974,group(.75,4)),
 off('tranquility',740,group(.5,5)),
 off('genesis',145518,group(.6,4)),
 BuiltinConditions.spell('innervate',29166,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8})),
 BuiltinConditions.spell('natures-cure',88423,BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.any({type='DISPELLABLE',unit='target',debufftype='Magic'},
  {type='DISPELLABLE',unit='target',debufftype='Curse'},{type='DISPELLABLE',unit='target',debufftype='Poison'}))),
 BuiltinConditions.spell('cenarion-ward',102351,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='focus'})),
 BuiltinConditions.spell('barkskin',22812,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.6))),
})
-- Both Restoration premades: Cat or Bear is your choice (no heals), damage on an attackable target
-- while soloing, then heal the friendly target (or yourself with none).
block('mop.druid.healer-open',{
 swing('forms',BuiltinConditions.any(BuiltinConditions.form(CAT),BuiltinConditions.form(BEAR))),
 {id='hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
  BuiltinConditions.spell('hostile-moonfire',8921,BuiltinConditions.all(BuiltinConditions.negate(bleed(8921)),lives)),
  BuiltinConditions.spell('hostile-wrath',5176),
  BuiltinConditions.stop('hostile-stop')}},
 BuiltinConditions.stop('enemy',{type='ENEMY',unit='target'}),
},3)
