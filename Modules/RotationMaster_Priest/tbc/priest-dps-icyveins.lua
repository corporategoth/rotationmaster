-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Priest damage, levels 1–70; the default Priest premade whenever the healer premade does
-- not apply (solo, Shadow, or no talents yet). Smite and wand early, Mind Flay once learned,
-- Shadowform, Vampiric Touch and Shadow Word: Death as they arrive; Holy and Discipline
-- questers keep Holy Fire and Smite. DoTs go before Mind Blast (Icy Veins, simulator, MaxDps);
-- a dying solo target is wanded (Icy Veins). Thresholds are RM policy.
-- The Wowhead variant is rm.tbc.priest.dps.wowhead.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function healthy()return{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}end
local P='priest-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.dps.icyveins',revision=6,
 blocks={['tbc.priest.dps-boundaries']=2,['tbc.priest.shadowform']=1,['tbc.priest.moving']=2,
  ['tbc.priest.dots']=1,['tbc.priest.filler']=2,['tbc.priest.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','icy-veins','leveling','raid','single-target'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/shadow-priest-leveling-guide',title='Icy Veins: Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/shadow-priest-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Shadow Priest rotation',reviewedAt='2026-10-23',revision='2026-01-12'},

  {url='https://github.com/kaminaris/MaxDps-Priest/tree/0ecad695ef2548e1aeaab8d7235311d4e211370d/Specialization/TBC',title='MaxDps-Priest TBC modules',reviewedAt='2026-10-23',revision='0ecad69'},
 },
 body={
  priority=10,
  switch={type='SPELL_KNOWN',spell=585},
  cooldowns={BuiltinConditions.block(P..'upkeep','tbc.priest.upkeep',P),
   BuiltinConditions.spell(P..'inner-focus',14751,BuiltinConditions.all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
   BuiltinConditions.spell(P..'scream',8122,BuiltinConditions.all({type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=2},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))},
  rotation={
   BuiltinConditions.block(P..'boundaries','tbc.priest.dps-boundaries',P),
   BuiltinConditions.block(P..'form','tbc.priest.shadowform',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-touch',34914),BuiltinConditions.spell(P..'pull-blast',8092),BuiltinConditions.spell(P..'pull-holy-fire',14914,BuiltinConditions.negate(BuiltinConditions.known(15407))),BuiltinConditions.spell(P..'pull-smite',585),BuiltinConditions.stop(P..'pull-stop')}},
   BuiltinConditions.block(P..'moving','tbc.priest.moving',P),
   {id=P..'dying',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),onFalse={},onTrue={
    {id=P..'dying-wand',type='branch',conditions=BuiltinConditions.known(5019),onFalse={},onTrue={
     BuiltinConditions.stop(P..'dying-wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),BuiltinConditions.spell(P..'dying-shoot',5019)}},
    BuiltinConditions.spell(P..'dying-blast',8092),BuiltinConditions.spell(P..'dying-death',32379,healthy()),BuiltinConditions.spell(P..'dying-flay',15407),BuiltinConditions.spell(P..'dying-smite',585),BuiltinConditions.stop(P..'dying-stop')}},
   -- Vampiric Embrace on long fights, or solo when your health is dropping.
   BuiltinConditions.spell(P..'embrace',15286,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),BuiltinConditions.any(
    BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7}),
    {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=60}))),
   BuiltinConditions.block(P..'dots','tbc.priest.dots',P),
   BuiltinConditions.spell(P..'blast',8092),
   BuiltinConditions.spell(P..'death',32379,healthy()),
   BuiltinConditions.block(P..'filler','tbc.priest.filler',P),
  },
 },
}))
