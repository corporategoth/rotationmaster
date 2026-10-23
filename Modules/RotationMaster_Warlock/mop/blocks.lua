-- Shared Mists of Pandaria Classic Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.warlock.{affliction,affliction.warcrafttavern,demonology,demonology.guide,destruction,
-- unspecialized}. A content change needs a block revision bump, every consumer's pin and revision bumped,
-- and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the
-- consumers'; see premade-research progression/warlock.md. POINT reads the specialization's own
-- resource: Soul Shards (Affliction), Demonic Fury 0-1000 (Demonology), Burning Embers (Destruction).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function corruption()return{type='DEBUFF',unit='target',spell=172,anyrank=true,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function shards(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function soul()return any(own(113860),own(113861),own(113858))end
local function lust()return any(buff(2825),buff(32182),buff(80353),buff(90355))end
-- No pet, out of combat (a summon is a 6 s cast), and not sacrificed to Grimoire of Sacrifice.
local petless=all(negate(combat()),negate({type='PET'}),negate(buff(108503)))
-- Hard casts, and channels other than Malefic Grasp and Drain Soul (wowsims clips those at every GCD, so
-- the next action stays visible; the channel is read by spell), run to the end; no target to attack, no
-- advice.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.boundaries',revision=2,families={'progression'},class='WARLOCK',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',all({type='CHANNELING',unit='player'},negate({type='CHANNELING_SPELL',unit='player',spell=103103}),negate({type='CHANNELING_SPELL',unit='player',spell=1120}))),
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
}}))
-- Reminders every specialization shares: Dark Intent, Curse of the Elements in a group when nobody has it
-- up, Grimoire of Sacrifice (tier 5), the Doomguard (Terrorguard with Grimoire of Supremacy) on an elite or
-- boss in its last minute, in execute or under Bloodlust, the Infernal (Abyssal) on seven engaged
-- enemies instead, defensives when low, and racials inside Dark Soul.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.upkeep',revision=1,families={'progression'},class='WARLOCK',steps={
 spell('dark-intent',109773,negate(buff(109773))),
 spell('curse-of-the-elements',1490,all(combat(),{type='GROUP'},negate({type='DEBUFF',unit='target',spell=1490}))),
 spell('grimoire-of-sacrifice',108503,all(talent(15),{type='PET'},negate(buff(108503)))),
 spell('doomguard',18540,all(combat(),negate(talent(13)),any(classified('worldboss'),classified('elite')),
  any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},lust(),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=63}))),
 spell('terrorguard',112927,all(combat(),talent(13),any(classified('worldboss'),classified('elite')),
  any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},lust(),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=63}))),
 spell('infernal',1122,all(combat(),negate(talent(13)),enemies('GREATERTHANOREQUALS',7))),
 spell('abyssal',112921,all(combat(),talent(13),enemies('GREATERTHANOREQUALS',7))),
 spell('unending-resolve',104773,all(combat(),health('LESSTHAN',.4))),
 spell('dark-regeneration',108359,all(combat(),health('LESSTHAN',.35))),
 spell('berserking',26297,all(combat(),soul())),
 spell('blood-fury',33702,all(combat(),soul())),
}}))
-- Affliction and Destruction pet: the Observer with Grimoire of Supremacy, else the Felhunter; before the
-- Felhunter (29) the Voidwalker solo and the Imp in a group.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.pet-felhunter',revision=1,families={'progression'},class='WARLOCK',steps={
 spell('observer',112869,all(petless,talent(13))),
 spell('felhunter',691,all(petless,negate(talent(13)))),
 spell('early-voidwalker',697,all(petless,negate(known(691)),negate({type='GROUP'}))),
 spell('early-imp',688,all(petless,negate(known(691)),{type='GROUP'})),
}}))
-- Affliction reminders both variants share: Dark Soul: Misery (again at two charges with Archimonde's
-- Darkness), Grimoire: Felhunter, Life Tap at 15% mana when standing still.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-upkeep',revision=1,families={'progression'},class='WARLOCK',steps={
 spell('dark-soul',113860,all(combat(),any(negate(own(113860)),{type='SPELL_CHARGES',spell=113860,operator='GREATERTHANOREQUALS',value=2}))),
 spell('grimoire-felhunter',111897,combat()),
 spell('life-tap',1454,all({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.15},negate({type='MOVING'}))),
}}))
-- Affliction up to the Haunt decision (wowsims order; both variants agree): pre-cast Haunt or Unstable
-- Affliction to pull; moving without Kil'jaeden's Cunning, instants then stop; a fresh elite or long-lived
-- target with none of your DoTs gets Soulburn + Soul Swap; on three or more engaged enemies Soulburn + Seed
-- of Corruption at six, plain Seed before Soulburn: Seed; then Agony, Corruption and Unstable Affliction
-- refreshed late; inside Dark Soul: Misery every DoT is refreshed early in its Pandemic window.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-dots',revision=1,families={'progression'},class='WARLOCK',steps={
 {id='pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
  spell('pull-haunt',48181,negate(dot(48181))),
  spell('pull-unstable-affliction',30108,negate(dot(30108))),
  stop('pull-stop'),
 }},
 {id='moving',type='branch',conditions=all({type='MOVING'},negate(talent(17))),onFalse={},onTrue={
  spell('moving-haunt',48181,all(shards('GREATERTHANOREQUALS',2),any(negate(dot(48181)),remain(48181,'LESSTHAN',4)))),
  spell('moving-agony',980,any(negate(dot(980)),remain(980,'LESSTHAN',1.5))),
  spell('moving-corruption',172,negate(corruption())),
  spell('moving-life-tap',1454,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8}),
  spell('moving-fel-flame',77799),
  stop('moving-stop'),
 }},
 {id='fresh',type='branch',conditions=all(known(86121),negate(dot(980)),negate(corruption()),negate(dot(30108))),onFalse={},onTrue={
  spell('fresh-soulburn',74434,all(negate(own(74434)),shards('GREATERTHANOREQUALS',1),
   any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=10}))),
  spell('fresh-soul-swap',86121,own(74434)),
 }},
 {id='aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  spell('aoe-soulburn',74434,all(enemies('GREATERTHANOREQUALS',6),known(86664),negate(own(74434)),negate(dot(27243)))),
  spell('aoe-soulburn-seed',27243,all(own(74434),negate(dot(27243)))),
  spell('aoe-seed',27243,all(negate(known(86664)),negate(dot(27243)))),
 }},
 spell('agony',980,any(negate(dot(980)),remain(980,'LESSTHAN',2))),
 spell('corruption',172,negate(corruption())),
 spell('unstable-affliction',30108,any(negate(dot(30108)),remain(30108,'LESSTHAN',1.5))),
 {id='misery',type='branch',conditions={type='BUFF_REMAIN',unit='player',spell=113860,ownbuff=true,operator='GREATERTHAN',value=3},onFalse={},onTrue={
  spell('misery-agony',980,remain(980,'LESSTHAN',12)),
  spell('misery-corruption',172,{type='DEBUFF_REMAIN',unit='target',spell=172,anyrank=true,owndebuff=true,operator='LESSTHAN',value=9}),
  spell('misery-unstable-affliction',30108,remain(30108,'LESSTHAN',7)),
 }},
}}))
-- Affliction after Haunt: Drain Soul in execute, Malefic Grasp (Shadow Bolt before 42), Life Tap last.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.affliction-filler',revision=1,families={'progression'},class='WARLOCK',steps={
 spell('drain-soul',1120,{type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.2}),
 spell('malefic-grasp',103103),
 spell('shadow-bolt',686),
 spell('last-life-tap',1454),
}}))
-- Demonology reminders both variants share: the Wrathguard with Grimoire of Supremacy, else the Felguard
-- (before 42 the Voidwalker solo, the Imp in a group); Grimoire: Felguard; Imp Swarm inside Dark Soul or
-- when it is more than 10 s away; Dark Soul: Knowledge (again at two charges); Life Tap at 30% mana
-- outside Metamorphosis; Health Funnel solo when the pet is low.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-upkeep',revision=2,families={'progression'},class='WARLOCK',steps={
 spell('wrathguard',112870,all(petless,talent(13))),
 spell('felguard',30146,all(petless,negate(talent(13)))),
 spell('early-voidwalker',697,all(petless,negate(known(30146)),negate({type='GROUP'}))),
 spell('early-imp',688,all(petless,negate(known(30146)),{type='GROUP'})),
 spell('grimoire-felguard',111898,combat()),
 spell('imp-swarm',104316,all(combat(),any(own(113861),{type='SPELL_COOLDOWN',spell=113861,operator='GREATERTHAN',value=10}))),
 spell('dark-soul',113861,all(combat(),any(negate(own(113861)),{type='SPELL_CHARGES',spell=113861,operator='GREATERTHANOREQUALS',value=2}))),
 spell('life-tap',1454,all({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.3},negate({type='FORM',form=103958}))),
 spell('health-funnel',755,all(negate({type='GROUP'}),{type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.35},health('GREATERTHAN',.5))),
}}))
-- Demonology pull (both variants): pre-cast Soul Fire, or Shadow Bolt before 13, then stop.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-pull',revision=1,families={'progression'},class='WARLOCK',steps={
 {id='pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
  spell('pull-soul-fire',6353),
  spell('pull-shadow-bolt',686),
  stop('pull-stop'),
 }},
}}))
-- Demonology in Metamorphosis (both variants): leave it (recast) when Dark Soul is down and fury is at 300
-- or less; Doom when missing or ending on a target that will outlive it; Touch of Chaos to extend an
-- ending Corruption; Soul Fire on Molten Core or below 25%; Immolation Aura on three, Void Ray on seven
-- engaged enemies; Touch of Chaos; then stop (the caster list does not apply in demon form).
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-demon',revision=1,families={'progression'},class='WARLOCK',steps={
 spell('demon-leave',103958,all(negate(own(113861)),shards('LESSTHANOREQUALS',300))),
 spell('demon-doom',603,any(negate(dot(603)),all(remain(603,'LESSTHAN',30),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=30}))),
 spell('demon-touch-corruption',103964,{type='DEBUFF_REMAIN',unit='target',spell=172,anyrank=true,owndebuff=true,operator='LESSTHAN',value=4}),
 spell('demon-soul-fire',104027,any(own(122355),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25})),
 {id='demon-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  spell('demon-void-ray',115422,enemies('GREATERTHANOREQUALS',7)),
  spell('demon-immolation-aura',104025,negate(own(104025))),
 }},
 spell('demon-touch',103964),
 stop('demon-stop'),
}}))
-- Demonology in caster form, before the variants part ways: moving without Kil'jaeden's Cunning, Corruption
-- then Fel Flame and stop; Corruption; the Shadowflame weave (a one-stack Shadowflame about to drop gets a
-- second Hand of Gul'dan, then Metamorphosis at once so the second stack lands empowered); Hand of Gul'dan
-- at two charges or with the second charge 2.5 s away.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-caster',revision=1,families={'progression'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions=all({type='MOVING'},negate(talent(17))),onFalse={},onTrue={
  spell('moving-corruption',172,negate(corruption())),
  spell('moving-fel-flame',77799),
  stop('moving-stop'),
 }},
 spell('corruption',172,negate(corruption())),
 spell('weave-metamorphosis',103958,all({type='SPELL_HISTORY_TIME',spell=105174,operator='LESSTHAN',value=1.5},
  {type='DEBUFF_STACKS',unit='target',spell=47960,owndebuff=true,operator='EQUALS',value=1},remain(47960,'LESSTHAN',3))),
 spell('weave-hand',105174,all({type='DEBUFF_STACKS',unit='target',spell=47960,owndebuff=true,operator='EQUALS',value=1},remain(47960,'LESSTHAN',3))),
 spell('hand-charges',105174,any({type='SPELL_CHARGES',spell=105174,operator='GREATERTHANOREQUALS',value=2},
  {type='SPELL_REMAIN',spell=105174,operator='LESSTHANOREQUALS',value=2.5})),
}}))
-- Demonology caster filler: Hellfire (Harvest Life when talented) on four engaged enemies, or two with
-- Mannoroth's Fury; Shadow Bolt.
assert(addon:RegisterDefaultBlock({
 id='mop.warlock.demonology-filler',revision=1,families={'progression'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions=any(enemies('GREATERTHANOREQUALS',4),all(enemies('GREATERTHANOREQUALS',2),own(108508))),onFalse={},onTrue={
  spell('aoe-harvest-life',108371),
  spell('aoe-hellfire',1949),
 }},
 spell('shadow-bolt',686),
}}))
