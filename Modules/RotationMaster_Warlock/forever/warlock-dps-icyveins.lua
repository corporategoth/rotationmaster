-- WoW Forever Warlock, Icy Veins leveling guides (player-chosen variant, all three trees).
-- Same switch as the recommended Warlock premade, lower priority, off by default. Differs from
-- the default: the wand is the solo filler (Wrack only once known and only in groups),
-- Voidwalker is the default pet, the Affliction and Destruction builds sacrifice their demon and
-- play without one (from 41 and 55), Demonology demotes Immolate to a filler, and Destruction
-- puts Bane of Havoc on the durable enemy of a pack. Health, mana and time to die are secret or
-- unavailable on Forever, so its health-driven Drain Life and Life Tap and its targets-that-live
-- DoT rule are left out. Trees by talent-taught spell: Conflagrate (Destruction), Fel Domination
-- (Demonology), else Affliction. Shared parts: Defaults/blocks/forever-warlock.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function level(n)return{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function havoc()return any(own(1324473),own(1225228))end
local function sacrificed()return any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return all(known(19028),level(40))end
local function summon()return all(negate({type='PET'}),any(negate(combat()),buff(18708)),any(negate(sacrificed()),pact()))end
local function bane()return all(negate(own(980)),negate(own(603)),negate(havoc()))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps.icyveins',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.aoe']=2,['forever.warlock.wand']=2},
 nameKey='Default.Forever.Warlock.DPS.IcyVeins.Name',descriptionKey='Default.Forever.Warlock.DPS.IcyVeins.Description',
 applicability={families={'forever'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/affliction-warlock-leveling',title='Icy Veins: Forever Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/demonology-warlock-leveling',title='Icy Veins: Forever Demonology Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/destruction-warlock-leveling',title='Icy Veins: Forever Destruction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/affliction-warlock-ranged-dps-pve-guide',title='Icy Veins: Forever Affliction Warlock PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'}},
 body={priority=6,disabled=true,
 cooldowns={block('forever.warlock.upkeep','warlock-iv-'),
  spell('warlock-iv-summon-voidwalker',697,summon()),
  spell('warlock-iv-summon-succubus',712,all(negate(known(697)),summon())),
  spell('warlock-iv-summon-imp',688,all(negate(known(697)),negate(known(712)),summon())),
  spell('warlock-iv-petless-sacrifice',18788,all({type='PET'},negate(sacrificed()),negate(known(18708)),any(all(negate(known(1293817)),level(41)),level(55)))),
  spell('warlock-iv-amplify-curse',18288,all(combat(),big(),negate(own(980))))},
 rotation={
 block('forever.warlock.boundaries','warlock-iv-'),
 {id='warlock-iv-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('warlock-iv-pull-bolt',686,known(1293817)),
  spell('warlock-iv-pull-immolate',348,all(negate(known(18708)),negate(own(348)))),
  {id='warlock-iv-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-iv-'),
 block('forever.warlock.moving','warlock-iv-'),
 spell('warlock-iv-havoc',1225228,all(known(1293817),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},big(),negate(havoc()))),
 block('forever.warlock.aoe','warlock-iv-'),
 spell('warlock-iv-elements',440892,all(any({type='GROUP'},big()),negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),
  negate(any(own(704),own(702),own(1714),own(18223))))),
 {id='warlock-iv-destruction',type='branch',conditions=known(1293817),onTrue={
  spell('warlock-iv-destro-immolate',348,negate(own(348))),
  spell('warlock-iv-destro-agony',980,bane()),
  spell('warlock-iv-destro-conflagrate',1293817,all(own(348),any(known(412758),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3}))),
  spell('warlock-iv-destro-shadowburn',17877,known(412758)),
 },onFalse={
  {id='warlock-iv-demonology',type='branch',conditions=known(18708),onTrue={
   spell('warlock-iv-demo-agony',980,bane()),
   spell('warlock-iv-demo-corruption',172,negate(own(172))),
  },onFalse={
   spell('warlock-iv-aff-agony',980,bane()),
   spell('warlock-iv-aff-siphon-life',18265,negate(own(18265))),
   spell('warlock-iv-aff-corruption',172,negate(own(172))),
  }},
 }},
 {id='warlock-iv-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  block('forever.warlock.wand','warlock-iv-solo-'),
 }},
 spell('warlock-iv-incinerate',412758,own(348)),
 spell('warlock-iv-wrack',1316697),
 spell('warlock-iv-demo-immolate',348,all(known(18708),negate(own(348)))),
 spell('warlock-iv-bolt',686),
 }},
}))
