-- Shared Mists of Pandaria Classic Death Knight blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.deathknight.blood, .blood.wowsims, .frost, .frost.dualwield, .unholy and
-- .unholy.wowsims. A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Runes are read by current type (RUNE: 1 Blood, 2 Frost, 3 Unholy, 4 Death; ready runes only), so
-- "a Frost or Death rune" is an OR. The engine already checks rune and runic power costs.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,steps)assert(addon:RegisterDefaultBlock({id=id,revision=1,families={'progression'},class='DEATHKNIGHT',steps=steps}))end
local FEVER,PLAGUE=55095,55078
local both=all(disease(FEVER),disease(PLAGUE))
local missing=any(negate(disease(FEVER)),negate(disease(PLAGUE)))
local B,F,U,D=1,2,3,4
local noRunes=all(rune(B,'EQUALS',0),rune(F,'EQUALS',0),rune(U,'EQUALS',0),rune(D,'EQUALS',0))
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
-- Casts and channels (Army of the Dead) and a target that is not attackable end advice.
block('mop.deathknight.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('target',negate({type='ATTACKABLE',unit='target'})),
})
-- Every specialization: Horn of Winter when no attack power shout is up (they do not stack), Mind
-- Freeze on an interruptible cast, Army of the Dead before a group boss pull.
block('mop.deathknight.upkeep',{
 spell('horn',57330,all(negate(buff(57330)),negate(buff(6673)),negate(buff(19506)))),
 spell('mind-freeze',47528,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('army',42650,all(negate(combat()),{type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'})),
})
-- Spread diseases once per pack: Blood Boil with Roiling Blood (talent 1), else Pestilence.
block('mop.deathknight.spread',{
 spell('roiling-blood',48721,all(both,{type='TALENT',layout='grid',value=1})),
 spell('pestilence',50842,all(both,negate({type='SPELL_HISTORY_TIME',spell=50842,operator='LESSTHAN',value=8}))),
})
-- Frost and Unholy survival: Death Strike on a Dark Succor proc or below 35% health.
block('mop.deathknight.survival',{
 spell('death-strike',49998,any(buff(101568),health('LESSTHAN',.35))),
})
-- Both Blood premades: presence, Bone Shield, defensive cooldowns by health.
block('mop.deathknight.blood-upkeep',{
 spell('blood-presence',48263,all(negate(buff(48263)),negate(buff(48266)),negate(buff(48265)))),
 spell('frost-presence',48266,all(negate(buff(48263)),negate(buff(48266)),negate(buff(48265)),negate(known(48263)))),
 spell('bone-shield',49222,any(negate(buff(49222)),{type='BUFF_STACKS',unit='player',spell=49222,operator='LESSTHANOREQUALS',value=1})),
 spell('rune-tap',48982,all(combat(),any(buff(96171),all(health('LESSTHAN',.6),any(rune(B,'GREATERTHANOREQUALS',1),rune(D,'GREATERTHANOREQUALS',1)))))),
 spell('vampiric-blood',55233,all(combat(),health('LESSTHAN',.5))),
 spell('icebound',48792,all(combat(),health('LESSTHAN',.3))),
 spell('dancing-rune-weapon',49028,all(combat(),elite)),
 spell('empower',47568,all(combat(),health('LESSTHAN',.45),rune(F,'EQUALS',0),rune(U,'EQUALS',0),rune(D,'EQUALS',0))),
 spell('death-pact',48743,all(combat(),health('LESSTHAN',.3))),
 off('anti-magic-shell',48707,combat()),
})
-- Both Blood premades open from range with Outbreak, Icy Touch or Death Grip.
block('mop.deathknight.blood-pull',{
 {id='pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  spell('pull-outbreak',77575),spell('pull-icy-touch',45477),spell('pull-grip',49576),stop('pull-stop')}},
})
-- Both Frost premades (dual-wield and two-hand): presence and cooldowns.
block('mop.deathknight.frost-upkeep',{
 spell('frost-presence',48266,all(negate(buff(48263)),negate(buff(48266)),negate(buff(48265)))),
 spell('pillar',51271,combat()),
 spell('raise-dead',46584,combat()),
 spell('empower',47568,all(combat(),noRunes,{type='POWER',unit='player',operator='LESSTHAN',value=70})),
 spell('icebound',48792,all(combat(),health('LESSTHAN',.35))),
 spell('death-pact',48743,all(combat(),health('LESSTHAN',.3))),
})
-- Both Frost premades: pull, survival, Blood Tap, diseases, the AoE arm and Soul Reaper. Icy Veins'
-- order; Howling Blast carries Frost Fever, Plague Strike Blood Plague.
block('mop.deathknight.frost-open',{
 {id='pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  spell('pull-outbreak',77575),spell('pull-howling-blast',49184),spell('pull-grip',49576,negate({type='GROUP'})),stop('pull-stop')}},
 {id='survival',type='block',block='mop.deathknight.survival',prefix='survival-'},
 spell('blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
 spell('unholy-blight',115989,missing),
 spell('outbreak',77575,missing),
 spell('fever',49184,negate(disease(FEVER))),
 spell('plague',45462,negate(disease(PLAGUE))),
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  {id='aoe-spread',type='block',block='mop.deathknight.spread',prefix='aoe-'},
  spell('aoe-death-and-decay',43265,rune(U,'GREATERTHANOREQUALS',1)),
  spell('aoe-howling-blast',49184)}},
 spell('soul-reaper',130735,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
})
-- Frost's shared tail: Plague Leech before diseases fall off (with Outbreak ready to reapply them
-- once it is learned), Frost Strike at 40, Death Strike before Obliterate (58), Horn.
block('mop.deathknight.frost-tail',{
 spell('plague-leech',123693,all(any(remain(FEVER,'LESSTHAN',3),remain(PLAGUE,'LESSTHAN',3)),any(negate(known(77575)),{type='SPELL_AVAIL',spell=77575}))),
 spell('frost-strike-spend',49143,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=40}),
 spell('death-strike',49998,negate(known(49020))),
 spell('horn-filler',57330),
})
-- Both Unholy premades: presence, a permanent ghoul, Gargoyle, Unholy Frenzy and defensives.
local lust=any(buff(2825),buff(32182),buff(80353),buff(90355))
block('mop.deathknight.unholy-upkeep',{
 spell('unholy-presence',48265,all(negate(buff(48263)),negate(buff(48266)),negate(buff(48265)))),
 spell('frost-presence',48266,all(negate(buff(48263)),negate(buff(48266)),negate(buff(48265)),negate(known(48265)))),
 spell('raise-dead',46584,negate({type='PET'})),
 spell('gargoyle',49206,all(combat(),any(lust,all(elite,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})))),
 spell('unholy-frenzy',49016,combat()),
 spell('empower',47568,all(combat(),noRunes,{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=40})),
 spell('icebound',48792,all(combat(),health('LESSTHAN',.35))),
 spell('death-pact',48743,all(combat(),health('LESSTHAN',.3),{type='PET'})),
 off('anti-magic-shell',48707,combat()),
})
-- Both Unholy premades: pull, survival, diseases (Plague Strike applies both from 68 with Ebon
-- Plaguebringer; Icy Touch before), and the AoE arm.
block('mop.deathknight.unholy-open',{
 {id='pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  spell('pull-outbreak',77575),spell('pull-icy-touch',45477),spell('pull-grip',49576,negate({type='GROUP'})),stop('pull-stop')}},
 {id='survival',type='block',block='mop.deathknight.survival',prefix='survival-'},
 spell('unholy-blight',115989,missing),
 spell('outbreak',77575,missing),
 spell('plague',45462,negate(disease(PLAGUE))),
 spell('fever',45477,negate(disease(FEVER))),
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  {id='aoe-spread',type='block',block='mop.deathknight.spread',prefix='aoe-'},
  spell('aoe-death-and-decay',43265),
  spell('aoe-blood-boil',48721,any(rune(B,'GREATERTHANOREQUALS',1),rune(D,'GREATERTHANOREQUALS',1))),
  spell('aoe-icy-touch',45477,rune(F,'GREATERTHANOREQUALS',1))}},
})
