-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.paladin.retribution, .retribution.warcrafttavern, .protection,
-- .protection.simulator, .holy and .unspecialized. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Seals are stances in MoP, read by spell (FORM form: Command 105361, Truth 31801, Righteousness 20154,
-- Insight 20165), so the stance-bar order the seals were learned in does not matter. The wanted seal is
-- asked for whenever another is up (Seal of Command left over from levelling, say), except Seal of
-- Righteousness, the deliberate choice for packs, which is kept.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='PALADIN',steps=steps}))end
local function sealed(id)return{type='FORM',form=id}end
local enemies=function(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
-- Casts and channels end advice; damage and tank premades take the variant that also stops on a
-- target that is not attackable (one Stop).
block('mop.paladin.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
},3)
block('mop.paladin.damage-boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},2)
-- Every premade: Rebuke an interruptible cast (off the global cooldown); Blessing of Kings out of
-- combat when neither Kings nor Might is up, Blessing of Might when another paladin's Kings is.
block('mop.paladin.upkeep',{
 BuiltinConditions.spell('rebuke',96231,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('kings',20217,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.buff(20217)),BuiltinConditions.negate(BuiltinConditions.buff(19740)))),
 BuiltinConditions.spell('might',19740,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.buff(20217),BuiltinConditions.negate(BuiltinConditions.ownBuff(20217)),BuiltinConditions.negate(BuiltinConditions.buff(19740)))),
})
-- Damage seal: Seal of Truth once learned (24), Seal of Command before.
block('mop.paladin.seal-truth',{
 BuiltinConditions.spell('seal-truth',31801,BuiltinConditions.all(BuiltinConditions.negate(sealed(31801)),BuiltinConditions.negate(sealed(20154)))),
 BuiltinConditions.spell('seal-command',105361,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(31801)),BuiltinConditions.negate(sealed(105361)))),
},2)
-- Tank and healer seal: Seal of Insight (32), else Truth, else Command while leveling.
block('mop.paladin.seal-insight',{
 BuiltinConditions.spell('seal-insight',20165,BuiltinConditions.all(BuiltinConditions.negate(sealed(20165)),BuiltinConditions.negate(sealed(20154)))),
 BuiltinConditions.spell('seal-truth',31801,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20165)),BuiltinConditions.negate(sealed(31801)))),
 BuiltinConditions.spell('seal-command',105361,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20165)),BuiltinConditions.negate(BuiltinConditions.known(31801)),BuiltinConditions.negate(sealed(105361)))),
},2)
-- Solo damage defensives: Divine Protection below 60%, Lay on Hands below 20% without Forbearance.
block('mop.paladin.defensives',{
 BuiltinConditions.spell('divine-protection',498,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),health('LESSTHAN',.6))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.2),BuiltinConditions.negate({type='DEBUFF',unit='player',spell=25771}))),
})
-- Both Retribution premades: Word of Glory when solo and in danger (usable from 1 Holy Power).
block('mop.paladin.ret-survival',{
 BuiltinConditions.spell('word-of-glory',85673,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),health('LESSTHAN',.35))),
})
-- Both Protection premades: Righteous Fury, seal and tank defensives by health (RM cannot see
-- incoming damage; time to die on the player is the proxy for Guardian).
block('mop.paladin.prot-upkeep',{
 BuiltinConditions.spell('righteous-fury',25780,BuiltinConditions.negate(BuiltinConditions.buff(25780))),
 {id='seal',type='block',block='mop.paladin.seal-insight',prefix='seal-'},
 BuiltinConditions.spell('guardian',86659,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(health('LESSTHAN',.5),{type='TT_HEALTH',unit='player',health=0,operator='LESSTHAN',value=6}))),
 BuiltinConditions.spell('ardent-defender',31850,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35),BuiltinConditions.negate(BuiltinConditions.buff(86659)))),
 BuiltinConditions.spell('divine-protection',498,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.7))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.25),BuiltinConditions.negate({type='DEBUFF',unit='player',spell=25771}))),
})
-- Both Protection premades: pull with Avenger's Shield (Judgment from range), then Sanctified
-- Wrath's Judgment in wings.
block('mop.paladin.prot-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-avengers-shield',31935),BuiltinConditions.spell('pull-judgment',20271,{type='BEYOND_MELEE',unit='target'}),BuiltinConditions.stop('pull-stop')}},
 BuiltinConditions.spell('wings-judgment',20271,BuiltinConditions.all({type='TALENT',layout='grid',value=14},BuiltinConditions.buff(31884))),
},4)
-- Both Protection premades: three or more enemies on you (Icy Veins' AoE order), then stop.
block('mop.paladin.prot-aoe',{
 {id='aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-avengers-shield',31935),
  BuiltinConditions.spell('aoe-consecration',26573),
  BuiltinConditions.spell('aoe-hammer-righteous',53595),
  BuiltinConditions.spell('aoe-judgment',20271),
  BuiltinConditions.spell('aoe-holy-wrath',119072),
  BuiltinConditions.spell('aoe-lights-hammer',114158),
  BuiltinConditions.spell('aoe-execution-sentence',114157),
  BuiltinConditions.spell('aoe-holy-prism',114165),
  BuiltinConditions.spell('aoe-hammer-wrath',24275),
  BuiltinConditions.stop('aoe-stop')}},
},2)
