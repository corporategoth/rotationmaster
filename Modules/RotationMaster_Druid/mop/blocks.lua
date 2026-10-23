-- Shared Mists of Pandaria Classic Druid blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.druid.unspecialized, .balance, .feral, .feral.icyveins, .guardian, .restoration
-- and .restoration.wowhead. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read by their spell (FORM form: Cat 768, Bear 5487, travel 783/1066/33943/40120, Moonkin
-- 24858, Tree of Life 33891), never the shapeshift index, which shifts as forms are learned. Actions name the spellbook IDs (Mangle 33917, Thrash 106832, Swipe 106785,
-- Berserk 106952); buffs and debuffs name the form's own aura.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function form(id)return{type='FORM',form=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function swing(id,conditions)return{id=id,type='none',conditions=conditions or{}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='DRUID',steps=steps}))end
local CAT,BEAR=768,5487
local travelling=any(form(783),form(1066),form(33943),form(40120))
local hurt=function(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local group=function(pct,n,yards)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=yards or 40,healthoperator='LESSTHAN',health=pct,operator='GREATERTHANOREQUALS',value=n}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local roar=any(own(52610),own(127538))
-- A target worth a DoT: elite, above 30% health, or forecast to live six seconds (the forecast alone
-- is unavailable early in a fight).
local lives=any(elite,{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
-- Casts and channels (Astral Communion, Hurricane, Tranquility) and travel forms end advice.
block('mop.druid.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('travel',travelling),
},2)
-- Damage and tank premades: nothing to do without an attackable target.
block('mop.druid.target',{
 stop('target',negate({type='ATTACKABLE',unit='target'})),
})
-- Every specialization: Mark of the Wild between pulls when no equivalent stat buff is up.
block('mop.druid.mark',{
 spell('mark',1126,all(negate(combat()),negate(buff(1126)),negate(buff(20217)),negate(buff(115921)),negate(buff(90363)))),
})
-- Both Feral premades: Tiger's Fury below 35 energy outside Berserk, Incarnation with Berserk,
-- Force of Nature with Tiger's Fury or at three charges, Nature's Vigil, Nature's Swiftness for a
-- Dream of Cenarius heal, interrupts and defensives. Heart of the Wild's Wrath weave stays manual.
block('mop.druid.feral-upkeep',{
 spell('tigers-fury',5217,all(combat(),form(CAT),power('LESSTHAN',35),negate(own(106951)))),
 spell('incarnation',102543,own(106951)),
 spell('force-of-nature',102703,all(combat(),any({type='SPELL_CHARGES',spell=102703,operator='EQUALS',value=3},own(5217)))),
 spell('natures-vigil',124974,any(own(106951),own(5217))),
 spell('natures-swiftness',132158,all(talent(17),negate(own(69369)),cp('GREATERTHANOREQUALS',4))),
 spell('skull-bash',106839,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('survival-instincts',61336,all(combat(),health('LESSTHAN',.4))),
 spell('barkskin',22812,all(combat(),health('LESSTHAN',.6))),
 off('heart-of-the-wild',108288,combat()),
},2)
-- Both Feral premades: a short Bear arm (Might of Ursoc, off-tanking), Cat Form (Dream of Cenarius
-- Healing Touch first before a pull), the stealth opener, then Savage Roar, Faerie Fire on elites
-- without full Weakened Armor, and Healing Touch on Predatory Swiftness for Dream of Cenarius (or
-- below half health).
block('mop.druid.feral-open',{
 {id='bear',type='branch',conditions=form(BEAR),onFalse={},onTrue={
  spell('bear-thrash',106832,negate(bleed(77758))),
  spell('bear-mangle',33917),
  spell('bear-lacerate',33745),
  spell('bear-maul',6807,power('GREATERTHANOREQUALS',60)),
  swing('bear-stop')}},
 {id='cat',type='branch',conditions=form(CAT),onTrue={},onFalse={
  spell('cat-dream',5185,all(negate(combat()),talent(17),negate(own(145152)))),
  spell('cat-form',768),
  stop('cat-stop')}},
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-roar',52610,negate(roar)),
  spell('pull-prowl',5215,negate({type='STEALTHED'})),
  spell('pull-ravage',6785,{type='STEALTHED'}),
  spell('pull-pounce',9005,all({type='STEALTHED'},negate({type='SPELL_KNOWN',spell=6785}))),
  spell('pull-rake',1822),
  swing('pull-stop')}},
 spell('roar',52610,all(cp('GREATERTHANOREQUALS',1),any(negate(roar),
  all(own(52610),{type='BUFF_REMAIN',unit='player',spell=52610,ownbuff=true,operator='LESSTHANOREQUALS',value=3}),
  all(own(127538),{type='BUFF_REMAIN',unit='player',spell=127538,ownbuff=true,operator='LESSTHANOREQUALS',value=3})))),
 spell('faerie-fire',770,all(elite,{type='DEBUFF_STACKS',unit='target',spell=113746,operator='LESSTHAN',value=3})),
 spell('swift-touch',5185,all(any(own(69369),own(132158)),any(
  all(talent(17),any(cp('GREATERTHANOREQUALS',4),{type='BUFF_REMAIN',unit='player',spell=69369,ownbuff=true,operator='LESSTHANOREQUALS',value=2}),
   any(negate(own(106951)),cp('EQUALS',5))),
  health('LESSTHAN',.5)))),
},3)
-- Both Feral premades: four or more enemies on you, Thrash then Swipe.
block('mop.druid.feral-aoe',{
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  spell('aoe-thrash',106832,any(negate(bleed(106830)),remain(106830,'LESSTHAN',3))),
  spell('aoe-swipe',106785),
  swing('aoe-stop')}},
})
-- Both Restoration premades: group cooldowns, the focus tank's Lifebloom and Ironbark, mana and
-- dispels. Tranquility and Genesis are raid assignments and ship off.
block('mop.druid.healer-upkeep',{
 spell('lifebloom-focus',33763,all({type='FRIENDLY',unit='focus'},any(negate({type='BUFF',unit='focus',spell=33763,ownbuff=true}),
  {type='BUFF_STACKS',unit='focus',spell=33763,ownbuff=true,operator='LESSTHAN',value=3},
  {type='BUFF_REMAIN',unit='focus',spell=33763,ownbuff=true,operator='LESSTHAN',value=4}))),
 off('mushroom',145205,combat()),
 spell('bloom',102791,group(.7,4)),
 spell('ironbark',102342,all({type='FRIENDLY',unit='focus'},{type='HEALTHPCT',unit='focus',operator='LESSTHAN',value=.6})),
 spell('natures-swiftness',132158,all({type='FRIENDLY',unit='target'},hurt(.35))),
 spell('force-of-nature',102693,all(combat(),any(group(.9,3),{type='SPELL_CHARGES',spell=102693,operator='EQUALS',value=3}))),
 spell('tree-of-life',33891,group(.75,4)),
 spell('natures-vigil',124974,group(.75,4)),
 off('tranquility',740,group(.5,5)),
 off('genesis',145518,group(.6,4)),
 spell('innervate',29166,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8})),
 spell('natures-cure',88423,all({type='FRIENDLY',unit='target'},any({type='DISPELLABLE',unit='target',debufftype='Magic'},
  {type='DISPELLABLE',unit='target',debufftype='Curse'},{type='DISPELLABLE',unit='target',debufftype='Poison'}))),
 spell('cenarion-ward',102351,all(combat(),{type='FRIENDLY',unit='focus'})),
 spell('barkskin',22812,all(combat(),health('LESSTHAN',.6))),
})
-- Both Restoration premades: Cat or Bear is your choice (no heals), damage on an attackable target
-- while soloing, then heal the friendly target (or yourself with none).
block('mop.druid.healer-open',{
 swing('forms',any(form(CAT),form(BEAR))),
 {id='hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
  spell('hostile-moonfire',8921,all(negate(bleed(8921)),lives)),
  spell('hostile-wrath',5176),
  stop('hostile-stop')}},
 stop('enemy',{type='ENEMY',unit='target'}),
},2)
