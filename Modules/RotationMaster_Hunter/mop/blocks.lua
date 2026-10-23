-- Shared Mists of Pandaria Classic Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.hunter.beastmastery, .marksmanship, .marksmanship.icyveins, .survival and
-- .unspecialized. A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- MoP removed hunter melee weapons, so every Stop suppresses the implicit Attack.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function focus(op,v,unit)return{type='POWER',unit=unit or'player',operator=op,value=v}end
local function lives(v)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,steps)assert(addon:RegisterDefaultBlock({id=id,revision=1,families={'progression'},class='HUNTER',steps=steps}))end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
-- Worth a major cooldown: an elite or boss, any dungeon or raid, or a target that will live 20 s
-- (the forecast last, because it can be unavailable).
local worth=all(combat(),any(classified('elite'),classified('rareelite'),classified('worldboss'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},lives(20)))
-- Casts and channels (Aimed, Steady, Cobra, Powershot, Barrage) and a target that is not
-- attackable end advice.
block('mop.hunter.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('target',negate({type='ATTACKABLE',unit='target'})),
})
-- Hunter's Mark before the pull when nobody's mark is on the target; Kill Command, Chimera and
-- Explosive Shot apply it in combat.
block('mop.hunter.mark',{
 spell('mark',1130,negate({type='DEBUFF',unit='target',spell=1130})),
})
-- Every Hunter: a pet out, revived and mended.
block('mop.hunter.pet',{
 spell('call-pet',883,negate({type='PET'})),
 spell('revive-pet',982,{type='DEAD',unit='pet'}),
 spell('mend-pet',136,all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},negate({type='BUFF',unit='pet',spell=136}))),
})
-- Every Hunter: Aspect of the Iron Hawk (talent 8) or the Hawk when neither is up, except over a
-- travel aspect you chose out of combat.
local hawkless=all(negate(buff(13165)),negate(buff(109260)),any(combat(),all(negate(buff(5118)),negate(buff(13159)))))
block('mop.hunter.aspect',{
 spell('iron-hawk',109260,hawkless),
 spell('hawk',13165,all(hawkless,negate(known(109260)))),
})
-- Specialized Hunters: interrupt (Silencing Shot overrides Counter Shot for Marksmanship), Fervor
-- when you and the pet are low, optional defensives.
block('mop.hunter.utility',{
 spell('silencing-shot',34490,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('counter-shot',147362,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('fervor',82726,all(combat(),focus('LESSTHAN',50),focus('LESSTHAN',50,'pet'))),
 off('exhilaration',109304,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 off('deterrence',19263,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
})
-- Marksmanship and Survival: major cooldowns together when the fight is worth it.
block('mop.hunter.burst',{
 spell('rapid-fire',3045,all(worth,negate(buff(3045)))),
 spell('stampede',121818,worth),
 spell('blood-fury',20572,worth),
 spell('berserking',26297,worth),
})
-- Talents on their own cooldowns: A Murder of Crows and Lynx Rush on a target that lives or is
-- worth it, Dire Beast whenever ready.
block('mop.hunter.talents',{
 spell('crows',131894,any(worth,lives(30))),
 spell('lynx-rush',120697,any(worth,lives(30))),
 spell('dire-beast',120679),
})
-- Tier-6 talent shots on cooldown.
block('mop.hunter.talent-shots',{
 spell('glaive-toss',117050),
 spell('barrage',120360),
 spell('powershot',109259),
})
-- Serpent Sting on a target that lives 8 s; Cobra Shot (81, Beast Mastery and Survival) refreshes
-- it under 6 s.
local sting={type='DEBUFF',unit='target',spell=118253,owndebuff=true}
block('mop.hunter.serpent',{
 spell('serpent-sting',1978,all(negate(sting),lives(8))),
 spell('cobra-refresh',77767,all(sting,{type='DEBUFF_REMAIN',unit='target',spell=118253,owndebuff=true,operator='LESSTHAN',value=6})),
})
-- Filler: Cobra Shot once learned (it overrides Steady Shot), else Steady Shot; then nothing.
block('mop.hunter.filler',{
 spell('cobra',77767),
 spell('steady',56641,negate(known(77767))),
 stop('wait'),
})
