-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.warlock.{affliction,affliction.warcrafttavern,demonology,demonology.guide,destruction,
-- unspecialized}. A content change needs a block revision bump, every consumer's pin and revision bumped,
-- and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the
-- consumers'; see premade-research progression/warlock.md. POINT reads the specialization's own
-- resource: Soul Shards (Affliction), Demonic Fury 0-1000 (Demonology), Burning Embers (Destruction).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function corruption()return{type='DEBUFF',unit='target',spell=172,anyrank=true,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function shards(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local function soul()return BuiltinConditions.any(BuiltinConditions.ownBuff(113860),BuiltinConditions.ownBuff(113861),BuiltinConditions.ownBuff(113858))end
local function lust()return BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))end
-- No pet, out of combat (a summon is a 6 s cast), and not sacrificed to Grimoire of Sacrifice.
local petless=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(BuiltinConditions.buff(108503)))
-- Hard casts, and channels other than Malefic Grasp and Drain Soul (simulator clips those at every GCD, so
-- the next action stays visible; the channel is read by spell), run to the end; no target to attack, no
-- advice.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.boundaries',revision=4,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate({type='CHANNELING_SPELL',unit='player',spell=103103}),BuiltinConditions.negate({type='CHANNELING_SPELL',unit='player',spell=1120})),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
}}))
-- Reminders every specialization shares: Dark Intent, Curse of the Elements in a group when nobody has it
-- up, Grimoire of Sacrifice (tier 5), the Doomguard (Terrorguard with Grimoire of Supremacy) on an elite or
-- boss in its last minute, in execute or under Bloodlust, the Infernal (Abyssal) on seven engaged
-- enemies instead, defensives when low, and racials inside Dark Soul.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.upkeep',revision=1,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('dark-intent',109773,BuiltinConditions.negate(BuiltinConditions.buff(109773))),
 BuiltinConditions.spell('curse-of-the-elements',1490,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1490}))),
 BuiltinConditions.spell('grimoire-of-sacrifice',108503,BuiltinConditions.all(talent(15),{type='PET'},BuiltinConditions.negate(BuiltinConditions.buff(108503)))),
 BuiltinConditions.spell('doomguard',18540,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(talent(13)),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')),
  BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},lust(),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=63}))),
 BuiltinConditions.spell('terrorguard',112927,BuiltinConditions.all(BuiltinConditions.combat(),talent(13),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')),
  BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},lust(),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=63}))),
 BuiltinConditions.spell('infernal',1122,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(talent(13)),enemies('GREATERTHANOREQUALS',7))),
 BuiltinConditions.spell('abyssal',112921,BuiltinConditions.all(BuiltinConditions.combat(),talent(13),enemies('GREATERTHANOREQUALS',7))),
 BuiltinConditions.spell('unending-resolve',104773,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.4))),
 BuiltinConditions.spell('dark-regeneration',108359,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
 BuiltinConditions.spell('berserking',26297,BuiltinConditions.all(BuiltinConditions.combat(),soul())),
 BuiltinConditions.spell('blood-fury',33702,BuiltinConditions.all(BuiltinConditions.combat(),soul())),
}}))
-- Affliction and Destruction pet: the Observer with Grimoire of Supremacy, else the Felhunter; before the
-- Felhunter (29) the Voidwalker solo and the Imp in a group.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.pet-felhunter',revision=1,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('observer',112869,BuiltinConditions.all(petless,talent(13))),
 BuiltinConditions.spell('felhunter',691,BuiltinConditions.all(petless,BuiltinConditions.negate(talent(13)))),
 BuiltinConditions.spell('early-voidwalker',697,BuiltinConditions.all(petless,BuiltinConditions.negate(BuiltinConditions.known(691)),BuiltinConditions.negate({type='GROUP'}))),
 BuiltinConditions.spell('early-imp',688,BuiltinConditions.all(petless,BuiltinConditions.negate(BuiltinConditions.known(691)),{type='GROUP'})),
}}))
-- Affliction reminders both variants share: Dark Soul: Misery (again at two charges with Archimonde's
-- Darkness), Grimoire: Felhunter, Life Tap at 15% mana when standing still.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-upkeep',revision=1,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('dark-soul',113860,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(113860)),{type='SPELL_CHARGES',spell=113860,operator='GREATERTHANOREQUALS',value=2}))),
 BuiltinConditions.spell('grimoire-felhunter',111897,BuiltinConditions.combat()),
 BuiltinConditions.spell('life-tap',1454,BuiltinConditions.all({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.15},BuiltinConditions.negate({type='MOVING'}))),
}}))
-- Affliction up to the Haunt decision (simulator order; both variants agree): pre-cast Haunt or Unstable
-- Affliction to pull; moving without Kil'jaeden's Cunning, instants then stop; a fresh elite or long-lived
-- target with none of your DoTs gets Soulburn + Soul Swap; on three or more engaged enemies Soulburn + Seed
-- of Corruption at six, plain Seed before Soulburn: Seed; then Agony, Corruption and Unstable Affliction
-- refreshed late; inside Dark Soul: Misery every DoT is refreshed early in its Pandemic window.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-dots',revision=3,families={'progression'},class='WARLOCK',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-haunt',48181,BuiltinConditions.negate(dot(48181))),
  BuiltinConditions.spell('pull-unstable-affliction',30108,BuiltinConditions.negate(dot(30108))),
  BuiltinConditions.stop('pull-stop'),
 }},
 {id='moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(talent(17))),onFalse={},onTrue={
  BuiltinConditions.spell('moving-haunt',48181,BuiltinConditions.all(shards('GREATERTHANOREQUALS',2),BuiltinConditions.any(BuiltinConditions.negate(dot(48181)),remain(48181,'LESSTHAN',4)))),
  BuiltinConditions.spell('moving-agony',980,BuiltinConditions.any(BuiltinConditions.negate(dot(980)),remain(980,'LESSTHAN',1.5))),
  BuiltinConditions.spell('moving-corruption',172,BuiltinConditions.negate(corruption())),
  BuiltinConditions.spell('moving-life-tap',1454,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8}),
  BuiltinConditions.spell('moving-fel-flame',77799),
  BuiltinConditions.stop('moving-stop'),
 }},
 {id='fresh',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.known(86121),BuiltinConditions.negate(dot(980)),BuiltinConditions.negate(corruption()),BuiltinConditions.negate(dot(30108))),onFalse={},onTrue={
  BuiltinConditions.spell('fresh-soulburn',74434,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(74434)),shards('GREATERTHANOREQUALS',1),
   BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=10}))),
  BuiltinConditions.spell('fresh-soul-swap',86121,BuiltinConditions.ownBuff(74434)),
 }},
 {id='aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-soulburn',74434,BuiltinConditions.all(enemies('GREATERTHANOREQUALS',6),BuiltinConditions.known(86664),BuiltinConditions.negate(BuiltinConditions.ownBuff(74434)),BuiltinConditions.negate(dot(27243)))),
  BuiltinConditions.spell('aoe-soulburn-seed',27243,BuiltinConditions.all(BuiltinConditions.ownBuff(74434),BuiltinConditions.negate(dot(27243)))),
  BuiltinConditions.spell('aoe-seed',27243,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(86664)),BuiltinConditions.negate(dot(27243)))),
 }},
 BuiltinConditions.spell('agony',980,BuiltinConditions.any(BuiltinConditions.negate(dot(980)),remain(980,'LESSTHAN',2))),
 BuiltinConditions.spell('corruption',172,BuiltinConditions.negate(corruption())),
 BuiltinConditions.spell('unstable-affliction',30108,BuiltinConditions.any(BuiltinConditions.negate(dot(30108)),remain(30108,'LESSTHAN',1.5))),
 {id='misery',type='branch',conditions={type='BUFF_REMAIN',unit='player',spell=113860,ownbuff=true,operator='GREATERTHAN',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('misery-agony',980,remain(980,'LESSTHAN',12)),
  BuiltinConditions.spell('misery-corruption',172,{type='DEBUFF_REMAIN',unit='target',spell=172,anyrank=true,owndebuff=true,operator='LESSTHAN',value=9}),
  BuiltinConditions.spell('misery-unstable-affliction',30108,remain(30108,'LESSTHAN',7)),
 }},
}}))
-- Affliction after Haunt: Drain Soul in execute, Malefic Grasp (Shadow Bolt before 42), Life Tap last.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-filler',revision=1,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('drain-soul',1120,{type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.2}),
 BuiltinConditions.spell('malefic-grasp',103103),
 BuiltinConditions.spell('shadow-bolt',686),
 BuiltinConditions.spell('last-life-tap',1454),
}}))
-- Demonology reminders both variants share: the Wrathguard with Grimoire of Supremacy, else the Felguard
-- (before 42 the Voidwalker solo, the Imp in a group); Grimoire: Felguard; Imp Swarm inside Dark Soul or
-- when it is more than 10 s away; Dark Soul: Knowledge (again at two charges); Life Tap at 30% mana
-- outside Metamorphosis; Health Funnel solo when the pet is low.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-upkeep',revision=2,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('wrathguard',112870,BuiltinConditions.all(petless,talent(13))),
 BuiltinConditions.spell('felguard',30146,BuiltinConditions.all(petless,BuiltinConditions.negate(talent(13)))),
 BuiltinConditions.spell('early-voidwalker',697,BuiltinConditions.all(petless,BuiltinConditions.negate(BuiltinConditions.known(30146)),BuiltinConditions.negate({type='GROUP'}))),
 BuiltinConditions.spell('early-imp',688,BuiltinConditions.all(petless,BuiltinConditions.negate(BuiltinConditions.known(30146)),{type='GROUP'})),
 BuiltinConditions.spell('grimoire-felguard',111898,BuiltinConditions.combat()),
 BuiltinConditions.spell('imp-swarm',104316,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.ownBuff(113861),{type='SPELL_COOLDOWN',spell=113861,operator='GREATERTHAN',value=10}))),
 BuiltinConditions.spell('dark-soul',113861,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(113861)),{type='SPELL_CHARGES',spell=113861,operator='GREATERTHANOREQUALS',value=2}))),
 BuiltinConditions.spell('life-tap',1454,BuiltinConditions.all({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.3},BuiltinConditions.negate({type='FORM',form=103958}))),
 BuiltinConditions.spell('health-funnel',755,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.35},health('GREATERTHAN',.5))),
}}))
-- Demonology pull (both variants): pre-cast Soul Fire, or Shadow Bolt before 13, then stop.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-pull',revision=3,families={'progression'},class='WARLOCK',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-soul-fire',6353),
  BuiltinConditions.spell('pull-shadow-bolt',686),
  BuiltinConditions.stop('pull-stop'),
 }},
}}))
-- Demonology in Metamorphosis (both variants): leave it (recast) when Dark Soul is down and fury is at 300
-- or less; Doom when missing or ending on a target that will outlive it; Touch of Chaos to extend an
-- ending Corruption; Soul Fire on Molten Core or below 25%; Immolation Aura on three, Void Ray on seven
-- engaged enemies; Touch of Chaos; then stop (the caster list does not apply in demon form).
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-demon',revision=2,families={'progression'},class='WARLOCK',steps={
 BuiltinConditions.spell('demon-leave',103958,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(113861)),shards('LESSTHANOREQUALS',300))),
 BuiltinConditions.spell('demon-doom',603,BuiltinConditions.any(BuiltinConditions.negate(dot(603)),BuiltinConditions.all(remain(603,'LESSTHAN',30),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=30}))),
 BuiltinConditions.spell('demon-touch-corruption',103964,{type='DEBUFF_REMAIN',unit='target',spell=172,anyrank=true,owndebuff=true,operator='LESSTHAN',value=4}),
 BuiltinConditions.spell('demon-soul-fire',104027,BuiltinConditions.any(BuiltinConditions.ownBuff(122355),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25})),
 {id='demon-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  BuiltinConditions.spell('demon-void-ray',115422,enemies('GREATERTHANOREQUALS',7)),
  BuiltinConditions.spell('demon-immolation-aura',104025,BuiltinConditions.negate(BuiltinConditions.ownBuff(104025))),
 }},
 BuiltinConditions.spell('demon-touch',103964),
 BuiltinConditions.stop('demon-stop'),
}}))
-- Demonology in caster form, before the variants part ways: moving without Kil'jaeden's Cunning, Corruption
-- then Fel Flame and stop; Corruption; the Shadowflame weave (a one-stack Shadowflame about to drop gets a
-- second Hand of Gul'dan, then Metamorphosis at once so the second stack lands empowered); Hand of Gul'dan
-- at two charges or with the second charge 2.5 s away.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-caster',revision=2,families={'progression'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(talent(17))),onFalse={},onTrue={
  BuiltinConditions.spell('moving-corruption',172,BuiltinConditions.negate(corruption())),
  BuiltinConditions.spell('moving-fel-flame',77799),
  BuiltinConditions.stop('moving-stop'),
 }},
 BuiltinConditions.spell('corruption',172,BuiltinConditions.negate(corruption())),
 BuiltinConditions.spell('weave-metamorphosis',103958,BuiltinConditions.all({type='SPELL_HISTORY_TIME',spell=105174,operator='LESSTHAN',value=1.5},
  {type='DEBUFF_STACKS',unit='target',spell=47960,owndebuff=true,operator='EQUALS',value=1},remain(47960,'LESSTHAN',3))),
 BuiltinConditions.spell('weave-hand',105174,BuiltinConditions.all({type='DEBUFF_STACKS',unit='target',spell=47960,owndebuff=true,operator='EQUALS',value=1},remain(47960,'LESSTHAN',3))),
 BuiltinConditions.spell('hand-charges',105174,BuiltinConditions.any({type='SPELL_CHARGES',spell=105174,operator='GREATERTHANOREQUALS',value=2},
  {type='SPELL_REMAIN',spell=105174,operator='LESSTHANOREQUALS',value=2.5})),
}}))
-- Demonology caster filler: Hellfire (Harvest Life when talented) on four engaged enemies, or two with
-- Mannoroth's Fury; Shadow Bolt.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-filler',revision=1,families={'progression'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions=BuiltinConditions.any(enemies('GREATERTHANOREQUALS',4),BuiltinConditions.all(enemies('GREATERTHANOREQUALS',2),BuiltinConditions.ownBuff(108508))),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-harvest-life',108371),
  BuiltinConditions.spell('aoe-hellfire',1949),
 }},
 BuiltinConditions.spell('shadow-bolt',686),
}}))
