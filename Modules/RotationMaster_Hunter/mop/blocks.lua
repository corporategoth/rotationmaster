-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.hunter.beastmastery, .marksmanship, .marksmanship.icyveins, .survival and
-- .unspecialized. A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- MoP removed hunter melee weapons, so every Stop suppresses the implicit auto-attack (Attack or Auto Shot).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function focus(op,v,unit)return{type='POWER',unit=unit or'player',operator=op,value=v}end
local function lives(v)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=v}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='HUNTER',steps=steps}))end
-- Worth a major cooldown: an elite or boss, any dungeon or raid, or a target that will live 20 s
-- (the forecast last, because it can be unavailable).
local worth=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('elite'),BuiltinConditions.classified('rareelite'),BuiltinConditions.classified('worldboss'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},lives(20)))
-- Casts and channels (Aimed, Steady, Cobra, Powershot, Barrage) and a target that is not
-- attackable end advice.
block('mop.hunter.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},3)
-- Hunter's Mark before the pull when nobody's mark is on the target; Kill Command, Chimera and
-- Explosive Shot apply it in combat.
block('mop.hunter.mark',{
 BuiltinConditions.spell('mark',1130,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1130})),
})
-- Every Hunter: a pet out, revived and mended.
block('mop.hunter.pet',{
 BuiltinConditions.spell('call-pet',883,BuiltinConditions.negate({type='PET'})),
 BuiltinConditions.spell('revive-pet',982,{type='DEAD',unit='pet'}),
 BuiltinConditions.spell('mend-pet',136,BuiltinConditions.all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},BuiltinConditions.negate({type='BUFF',unit='pet',spell=136}))),
})
-- Every Hunter: Aspect of the Iron Hawk (talent 8) or the Hawk when neither is up, except over a
-- travel aspect you chose out of combat.
local hawkless=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(13165)),BuiltinConditions.negate(BuiltinConditions.buff(109260)),BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(5118)),BuiltinConditions.negate(BuiltinConditions.buff(13159)))))
block('mop.hunter.aspect',{
 BuiltinConditions.spell('iron-hawk',109260,hawkless),
 BuiltinConditions.spell('hawk',13165,BuiltinConditions.all(hawkless,BuiltinConditions.negate(BuiltinConditions.known(109260)))),
})
-- Specialized Hunters: interrupt (Silencing Shot overrides Counter Shot for Marksmanship), Fervor
-- when you and the pet are low, optional defensives.
block('mop.hunter.utility',{
 BuiltinConditions.spell('silencing-shot',34490,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('counter-shot',147362,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('fervor',82726,BuiltinConditions.all(BuiltinConditions.combat(),focus('LESSTHAN',50),focus('LESSTHAN',50,'pet'))),
 off('exhilaration',109304,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 off('deterrence',19263,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
})
-- Marksmanship and Survival: major cooldowns together when the fight is worth it.
block('mop.hunter.burst',{
 BuiltinConditions.spell('rapid-fire',3045,BuiltinConditions.all(worth,BuiltinConditions.negate(BuiltinConditions.buff(3045)))),
 BuiltinConditions.spell('stampede',121818,worth),
 BuiltinConditions.spell('blood-fury',20572,worth),
 BuiltinConditions.spell('berserking',26297,worth),
})
-- Talents on their own cooldowns: A Murder of Crows and Lynx Rush on a target that lives or is
-- worth it, Dire Beast whenever ready.
block('mop.hunter.talents',{
 BuiltinConditions.spell('crows',131894,BuiltinConditions.any(worth,lives(30))),
 BuiltinConditions.spell('lynx-rush',120697,BuiltinConditions.any(worth,lives(30))),
 BuiltinConditions.spell('dire-beast',120679),
})
-- Tier-6 talent shots on cooldown.
block('mop.hunter.talent-shots',{
 BuiltinConditions.spell('glaive-toss',117050),
 BuiltinConditions.spell('barrage',120360),
 BuiltinConditions.spell('powershot',109259),
})
-- Serpent Sting on a target that lives 8 s; Cobra Shot (81, Beast Mastery and Survival) refreshes
-- it under 6 s.
local sting={type='DEBUFF',unit='target',spell=118253,owndebuff=true}
block('mop.hunter.serpent',{
 BuiltinConditions.spell('serpent-sting',1978,BuiltinConditions.all(BuiltinConditions.negate(sting),lives(8))),
 BuiltinConditions.spell('cobra-refresh',77767,BuiltinConditions.all(sting,{type='DEBUFF_REMAIN',unit='target',spell=118253,owndebuff=true,operator='LESSTHAN',value=6})),
})
-- Filler: Cobra Shot once learned (it overrides Steady Shot), else Steady Shot; then nothing.
block('mop.hunter.filler',{
 BuiltinConditions.spell('cobra',77767),
 BuiltinConditions.spell('steady',56641,BuiltinConditions.negate(BuiltinConditions.known(77767))),
 BuiltinConditions.stop('wait'),
},2)
