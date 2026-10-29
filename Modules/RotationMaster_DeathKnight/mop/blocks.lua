-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Death Knight blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.deathknight.blood, .blood.simulator, .frost, .frost.dualwield, .unholy and
-- .unholy.simulator. A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Runes are read by current type (RUNE: 1 Blood, 2 Frost, 3 Unholy, 4 Death; ready runes only), so
-- "a Frost or Death rune" is an OR. The engine already checks rune and runic power costs.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'progression'},class='DEATHKNIGHT',steps=steps}))end
local FEVER,PLAGUE=55095,55078
local both=BuiltinConditions.all(disease(FEVER),disease(PLAGUE))
local missing=BuiltinConditions.any(BuiltinConditions.negate(disease(FEVER)),BuiltinConditions.negate(disease(PLAGUE)))
local B,F,U,D=1,2,3,4
local noRunes=BuiltinConditions.all(rune(B,'EQUALS',0),rune(F,'EQUALS',0),rune(U,'EQUALS',0),rune(D,'EQUALS',0))
-- Presences are stances, read by spell (Blood 48263, Frost 48266, Unholy 48265): none active asks for the
-- specialization's own; one you chose by hand is kept.
local noPresence=BuiltinConditions.all(BuiltinConditions.negate({type='FORM',form=48263}),BuiltinConditions.negate({type='FORM',form=48266}),BuiltinConditions.negate({type='FORM',form=48265}))
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
-- Casts and channels (Army of the Dead) and a target that is not attackable end advice.
block('mop.deathknight.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
},3)
-- Every specialization: Horn of Winter when no attack power shout is up (they do not stack), Mind
-- Freeze on an interruptible cast, Army of the Dead before a group boss pull.
block('mop.deathknight.upkeep',{
 BuiltinConditions.spell('horn',57330,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(57330)),BuiltinConditions.negate(BuiltinConditions.buff(6673)),BuiltinConditions.negate(BuiltinConditions.buff(19506)))),
 BuiltinConditions.spell('mind-freeze',47528,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('army',42650,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'})),
})
-- Spread diseases once per pack: Blood Boil with Roiling Blood (talent 1), else Pestilence.
block('mop.deathknight.spread',{
 BuiltinConditions.spell('roiling-blood',48721,BuiltinConditions.all(both,{type='TALENT',layout='grid',value=1})),
 BuiltinConditions.spell('pestilence',50842,BuiltinConditions.all(both,BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=50842,operator='LESSTHAN',value=8}))),
})
-- Frost and Unholy survival: Death Strike on a Dark Succor proc or below 35% health.
block('mop.deathknight.survival',{
 BuiltinConditions.spell('death-strike',49998,BuiltinConditions.any(BuiltinConditions.buff(101568),health('LESSTHAN',.35))),
})
-- Both Blood premades: presence, Bone Shield, defensive cooldowns by health.
block('mop.deathknight.blood-upkeep',{
 BuiltinConditions.spell('blood-presence',48263,noPresence),
 BuiltinConditions.spell('frost-presence',48266,BuiltinConditions.all(noPresence,BuiltinConditions.negate(BuiltinConditions.known(48263)))),
 BuiltinConditions.spell('bone-shield',49222,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(49222)),{type='BUFF_STACKS',unit='player',spell=49222,operator='LESSTHANOREQUALS',value=1})),
 BuiltinConditions.spell('rune-tap',48982,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.buff(96171),BuiltinConditions.all(health('LESSTHAN',.6),BuiltinConditions.any(rune(B,'GREATERTHANOREQUALS',1),rune(D,'GREATERTHANOREQUALS',1)))))),
 BuiltinConditions.spell('vampiric-blood',55233,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.5))),
 BuiltinConditions.spell('icebound',48792,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.3))),
 BuiltinConditions.spell('dancing-rune-weapon',49028,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
 BuiltinConditions.spell('empower',47568,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.45),rune(F,'EQUALS',0),rune(U,'EQUALS',0),rune(D,'EQUALS',0))),
 BuiltinConditions.spell('death-pact',48743,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.3))),
 off('anti-magic-shell',48707,BuiltinConditions.combat()),
},2)
-- Both Blood premades open from range with Outbreak, Icy Touch or Death Grip.
block('mop.deathknight.blood-pull',{
 {id='pull',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  BuiltinConditions.spell('pull-outbreak',77575),BuiltinConditions.spell('pull-icy-touch',45477),BuiltinConditions.spell('pull-grip',49576),BuiltinConditions.stop('pull-stop')}},
},2)
-- Both Frost premades (dual-wield and two-hand): presence and cooldowns.
block('mop.deathknight.frost-upkeep',{
 BuiltinConditions.spell('frost-presence',48266,noPresence),
 BuiltinConditions.spell('pillar',51271,BuiltinConditions.combat()),
 BuiltinConditions.spell('raise-dead',46584,BuiltinConditions.combat()),
 BuiltinConditions.spell('empower',47568,BuiltinConditions.all(BuiltinConditions.combat(),noRunes,{type='POWER',unit='player',operator='LESSTHAN',value=70})),
 BuiltinConditions.spell('icebound',48792,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
 BuiltinConditions.spell('death-pact',48743,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.3))),
},2)
-- Both Frost premades: pull, survival, Blood Tap, diseases, the AoE arm and Soul Reaper. Icy Veins'
-- order; Howling Blast carries Frost Fever, Plague Strike Blood Plague.
block('mop.deathknight.frost-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  BuiltinConditions.spell('pull-outbreak',77575),BuiltinConditions.spell('pull-howling-blast',49184),BuiltinConditions.spell('pull-grip',49576,BuiltinConditions.negate({type='GROUP'})),BuiltinConditions.stop('pull-stop')}},
 {id='survival',type='block',block='mop.deathknight.survival',prefix='survival-'},
 BuiltinConditions.spell('blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
 BuiltinConditions.spell('unholy-blight',115989,missing),
 BuiltinConditions.spell('outbreak',77575,missing),
 BuiltinConditions.spell('fever',49184,BuiltinConditions.negate(disease(FEVER))),
 BuiltinConditions.spell('plague',45462,BuiltinConditions.negate(disease(PLAGUE))),
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  {id='aoe-spread',type='block',block='mop.deathknight.spread',prefix='aoe-'},
  BuiltinConditions.spell('aoe-death-and-decay',43265,rune(U,'GREATERTHANOREQUALS',1)),
  BuiltinConditions.spell('aoe-howling-blast',49184)}},
 BuiltinConditions.spell('soul-reaper',130735,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
},2)
-- Frost's shared tail: Plague Leech before diseases fall off (with Outbreak ready to reapply them
-- once it is learned), Frost Strike at 40, Death Strike before Obliterate (58), Horn.
block('mop.deathknight.frost-tail',{
 BuiltinConditions.spell('plague-leech',123693,BuiltinConditions.all(BuiltinConditions.any(remain(FEVER,'LESSTHAN',3),remain(PLAGUE,'LESSTHAN',3)),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(77575)),{type='SPELL_AVAIL',spell=77575}))),
 BuiltinConditions.spell('frost-strike-spend',49143,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=40}),
 BuiltinConditions.spell('death-strike',49998,BuiltinConditions.negate(BuiltinConditions.known(49020))),
 BuiltinConditions.spell('horn-filler',57330),
})
-- Both Unholy premades: presence, a permanent ghoul, Gargoyle, Unholy Frenzy and defensives.
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))
block('mop.deathknight.unholy-upkeep',{
 BuiltinConditions.spell('unholy-presence',48265,noPresence),
 BuiltinConditions.spell('frost-presence',48266,BuiltinConditions.all(noPresence,BuiltinConditions.negate(BuiltinConditions.known(48265)))),
 BuiltinConditions.spell('raise-dead',46584,BuiltinConditions.negate({type='PET'})),
 BuiltinConditions.spell('gargoyle',49206,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(lust,BuiltinConditions.all(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})))),
 BuiltinConditions.spell('unholy-frenzy',49016,BuiltinConditions.combat()),
 BuiltinConditions.spell('empower',47568,BuiltinConditions.all(BuiltinConditions.combat(),noRunes,{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=40})),
 BuiltinConditions.spell('icebound',48792,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
 BuiltinConditions.spell('death-pact',48743,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.3),{type='PET'})),
 off('anti-magic-shell',48707,BuiltinConditions.combat()),
},2)
-- Both Unholy premades: pull, survival, diseases (Plague Strike applies both from 68 with Ebon
-- Plaguebringer; Icy Touch before), and the AoE arm.
block('mop.deathknight.unholy-open',{
 {id='pull',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  BuiltinConditions.spell('pull-outbreak',77575),BuiltinConditions.spell('pull-icy-touch',45477),BuiltinConditions.spell('pull-grip',49576,BuiltinConditions.negate({type='GROUP'})),BuiltinConditions.stop('pull-stop')}},
 {id='survival',type='block',block='mop.deathknight.survival',prefix='survival-'},
 BuiltinConditions.spell('unholy-blight',115989,missing),
 BuiltinConditions.spell('outbreak',77575,missing),
 BuiltinConditions.spell('plague',45462,BuiltinConditions.negate(disease(PLAGUE))),
 BuiltinConditions.spell('fever',45477,BuiltinConditions.negate(disease(FEVER))),
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  {id='aoe-spread',type='block',block='mop.deathknight.spread',prefix='aoe-'},
  BuiltinConditions.spell('aoe-death-and-decay',43265),
  BuiltinConditions.spell('aoe-blood-boil',48721,BuiltinConditions.any(rune(B,'GREATERTHANOREQUALS',1),rune(D,'GREATERTHANOREQUALS',1))),
  BuiltinConditions.spell('aoe-icy-touch',45477,rune(F,'GREATERTHANOREQUALS',1))}},
},2)
