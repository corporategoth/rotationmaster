-- Shared TBC Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.paladin.retribution.*, rm.tbc.paladin.protection.* and
-- rm.tbc.paladin.holy*. A content change needs a revision bump, every consumer's
-- `blocks` pin and revision bumped, and ledger rows in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function list(ids,make)local out={};for i,id in ipairs(ids)do out[i]=make(id)end;return{type='OR',value=out}end
-- Any aura you chose (Devotion, Retribution, Concentration, Sanctity, Crusader, resistances). Auras are stances,
-- read by spell (any rank), never by stance-bar index, which moves as auras are learned.
local function noAura()return negate(list({465,7294,19746,20218,32223,19876,19888,19891},function(id)return{type='FORM',form=id}end))end
-- Any blessing from anyone: normal and Greater Might, Wisdom, Kings, Salvation, Sanctuary, Light.
local function noBlessing()return negate(list({19740,19742,20217,1038,20911,19977,25782,25894,25898,25895,25899,25890},
 function(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end))end
local function paladin(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'tbc'},class='PALADIN',steps=steps}))end
paladin('tbc.paladin.boundaries',{
 {id='casting',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
})
paladin('tbc.paladin.melee-opening',{
 {id='boundaries',type='block',block='tbc.paladin.boundaries'},
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
})
-- Retribution upkeep (Icy Veins, Wowhead): Sanctity, else Retribution, else Devotion
-- Aura; Wisdom, else Might, on yourself; top off after a fight; Avenging Wrath on a
-- target that lives, never under Forbearance.
paladin('tbc.paladin.ret-upkeep',{
 {id='sanctity-aura',type='spell',action=20218,ranked=false,conditions=noAura()},
 {id='retribution-aura',type='spell',action=7294,ranked=false,conditions=all(negate(known(20218)),noAura())},
 {id='devotion-aura',type='spell',action=465,ranked=false,conditions=all(negate(known(20218)),negate(known(7294)),noAura())},
 {id='blessing-of-wisdom',type='spell',action=19742,ranked=false,conditions=noBlessing()},
 {id='blessing-of-might',type='spell',action=19740,ranked=false,conditions=all(negate(known(19742)),noBlessing())},
 {id='flash-of-light',type='spell',action=19750,ranked=false,conditions=all(negate(combat()),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.7})},
 {id='holy-light',type='spell',action=635,ranked=false,conditions=all(negate(known(19750)),negate(combat()),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.7})},
 {id='avenging-wrath',type='spell',action=31884,ranked=false,conditions=all(combat(),negate({type='DEBUFF',unit='player',spell=25771}),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})},
},2)
-- Tank upkeep (Icy Veins, Wowhead): Righteous Fury, Devotion unless you chose another
-- aura, Sanctuary, else Kings, else Wisdom, and Lay on Hands as the last resort.
paladin('tbc.paladin.tank-upkeep',{
 {id='righteous-fury',type='spell',action=25780,ranked=false,conditions=negate(own(25780))},
 {id='devotion-aura',type='spell',action=465,ranked=false,conditions=noAura()},
 {id='blessing-of-sanctuary',type='spell',action=20911,ranked=false,conditions=noBlessing()},
 {id='blessing-of-kings',type='spell',action=20217,ranked=false,conditions=all(negate(known(20911)),noBlessing())},
 {id='blessing-of-wisdom',type='spell',action=19742,ranked=false,conditions=all(negate(known(20911)),negate(known(20217)),noBlessing())},
 {id='lay-on-hands',type='spell',action=633,ranked=false,conditions=all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.15})},
},2)
-- Healer upkeep (Icy Veins, Wowhead): Concentration Aura, Wisdom, Divine Illumination
-- once mana is spent, Divine Favor in combat.
paladin('tbc.paladin.holy-upkeep',{
 {id='concentration-aura',type='spell',action=19746,ranked=false,conditions=noAura()},
 {id='blessing-of-wisdom',type='spell',action=19742,ranked=false,conditions=noBlessing()},
 {id='divine-illumination',type='spell',action=31842,ranked=false,conditions=all(combat(),mana('LESSTHAN',0.8))},
 {id='divine-favor',type='spell',action=20216,ranked=false,conditions=combat()},
},2)
-- A healer targeting an enemy keeps Judgement of Wisdom or Light on it when nobody has.
paladin('tbc.paladin.holy-hostile',{
 {id='judgement',type='spell',action=20271,ranked=false,conditions=all(any(own(20166),own(20165)),
  negate(any({type='DEBUFF',unit='target',spell=20186,anyrank=true},{type='DEBUFF',unit='target',spell=20185,anyrank=true})))},
 {id='seal-of-wisdom',type='spell',action=20166,ranked=false,conditions=all(negate(any(own(20166),own(20165))),
  negate(any({type='DEBUFF',unit='target',spell=20186,anyrank=true},{type='DEBUFF',unit='target',spell=20185,anyrank=true})))},
 {id='hostile-stop',type='none',suppress_attack=true,conditions={}},
})
-- Healer emergencies and utility both Holy sources agree on: Lay on Hands, else Holy
-- Shock, for a dying target; Cleanse (Purify before 42); Holy Shock while moving.
paladin('tbc.paladin.holy-emergency',{
 {id='enemy',type='none',suppress_attack=true,conditions={type='ENEMY',unit='target'}},
 {id='lay-on-hands',type='spell',action=633,ranked=false,conditions=all(combat(),hurt(0.2))},
 {id='emergency-shock',type='spell',action=20473,ranked=false,conditions=hurt(0.2)},
 {id='cleanse',type='spell',action=4987,ranked=false,conditions=any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'})},
 {id='purify',type='spell',action=1152,ranked=false,conditions=all(negate(known(4987)),any({type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'}))},
 {id='moving-shock',type='spell',action=20473,ranked=false,conditions=all({type='MOVING'},hurt(0.9))},
})
