-- Shared Mists of Pandaria Classic Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.paladin.retribution, .retribution.warcrafttavern, .protection,
-- .protection.wowsims, .holy and .unspecialized. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Seals are stances in MoP, read by spell (FORM form: Command 105361, Truth 31801, Righteousness 20154,
-- Insight 20165), so the stance-bar order the seals were learned in does not matter. The wanted seal is
-- asked for whenever another is up (Seal of Command left over from levelling, say), except Seal of
-- Righteousness, the deliberate choice for packs, which is kept.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='PALADIN',steps=steps}))end
local function sealed(id)return{type='FORM',form=id}end
local enemies=function(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
-- Casts and channels end advice; damage premades also stop on a target that is not attackable.
block('mop.paladin.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
})
-- Every premade: Rebuke an interruptible cast (off the global cooldown); Blessing of Kings out of
-- combat when neither Kings nor Might is up, Blessing of Might when another paladin's Kings is.
block('mop.paladin.upkeep',{
 spell('rebuke',96231,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('kings',20217,all(negate(combat()),negate(buff(20217)),negate(buff(19740)))),
 spell('might',19740,all(negate(combat()),buff(20217),negate(own(20217)),negate(buff(19740)))),
})
-- Damage seal: Seal of Truth once learned (24), Seal of Command before.
block('mop.paladin.seal-truth',{
 spell('seal-truth',31801,all(negate(sealed(31801)),negate(sealed(20154)))),
 spell('seal-command',105361,all(negate(known(31801)),negate(sealed(105361)))),
},2)
-- Tank and healer seal: Seal of Insight (32), else Truth, else Command while leveling.
block('mop.paladin.seal-insight',{
 spell('seal-insight',20165,all(negate(sealed(20165)),negate(sealed(20154)))),
 spell('seal-truth',31801,all(negate(known(20165)),negate(sealed(31801)))),
 spell('seal-command',105361,all(negate(known(20165)),negate(known(31801)),negate(sealed(105361)))),
},2)
-- Solo damage defensives: Divine Protection below 60%, Lay on Hands below 20% without Forbearance.
block('mop.paladin.defensives',{
 spell('divine-protection',498,all(combat(),negate({type='GROUP'}),health('LESSTHAN',.6))),
 spell('lay-on-hands',633,all(combat(),health('LESSTHAN',.2),negate({type='DEBUFF',unit='player',spell=25771}))),
})
-- Both Retribution premades: Word of Glory when solo and in danger (usable from 1 Holy Power).
block('mop.paladin.ret-survival',{
 spell('word-of-glory',85673,all(negate({type='GROUP'}),health('LESSTHAN',.35))),
})
-- Both Protection premades: Righteous Fury, seal and tank defensives by health (RM cannot see
-- incoming damage; time to die on the player is the proxy for Guardian).
block('mop.paladin.prot-upkeep',{
 spell('righteous-fury',25780,negate(buff(25780))),
 {id='seal',type='block',block='mop.paladin.seal-insight',prefix='seal-'},
 spell('guardian',86659,all(combat(),any(health('LESSTHAN',.5),{type='TT_HEALTH',unit='player',health=0,operator='LESSTHAN',value=6}))),
 spell('ardent-defender',31850,all(combat(),health('LESSTHAN',.35),negate(buff(86659)))),
 spell('divine-protection',498,all(combat(),health('LESSTHAN',.7))),
 spell('lay-on-hands',633,all(combat(),health('LESSTHAN',.25),negate({type='DEBUFF',unit='player',spell=25771}))),
})
-- Both Protection premades: pull with Avenger's Shield (Judgment from range), then Sanctified
-- Wrath's Judgment in wings.
block('mop.paladin.prot-open',{
 stop('target',negate({type='ATTACKABLE',unit='target'})),
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-avengers-shield',31935),spell('pull-judgment',20271,{type='BEYOND_MELEE',unit='target'}),stop('pull-stop')}},
 spell('wings-judgment',20271,all({type='TALENT',layout='grid',value=14},buff(31884))),
},2)
-- Both Protection premades: three or more enemies on you (Icy Veins' AoE order), then stop.
block('mop.paladin.prot-aoe',{
 {id='aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  spell('aoe-avengers-shield',31935),
  spell('aoe-consecration',26573),
  spell('aoe-hammer-righteous',53595),
  spell('aoe-judgment',20271),
  spell('aoe-holy-wrath',119072),
  spell('aoe-lights-hammer',114158),
  spell('aoe-execution-sentence',114157),
  spell('aoe-holy-prism',114165),
  spell('aoe-hammer-wrath',24275),
  stop('aoe-stop')}},
})
