-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Priest damage after Wowhead's guides, levels 1–70; same switch as the Icy Veins damage
-- premade with a lower priority, shipped disabled: enable it to use it. It differs where Wowhead
-- differs: Mind Blast opens and goes before DoT refreshes, Vampiric Embrace only when your
-- health drops, and a dying solo target gets spells (Spirit Tap) instead of the wand.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function healthy()return{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}end
local P='priest-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.dps.wowhead',revision=7,
 blocks={['tbc.priest.dps-boundaries']=2,['tbc.priest.shadowform']=1,['tbc.priest.moving']=2,
  ['tbc.priest.dots']=1,['tbc.priest.filler']=2,['tbc.priest.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','wowhead','leveling','raid','single-target'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/priest/shadow/leveling-tips',title='Wowhead: Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/priest/holy/leveling-tips',title='Wowhead: Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/priest/shadow/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Shadow Priest rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
 },
 body={
  priority=5,disabled=true,
  switch={type='SPELL_KNOWN',spell=585},
  cooldowns={BuiltinConditions.block(P..'upkeep','tbc.priest.upkeep',P),
   BuiltinConditions.spell(P..'inner-focus',14751,BuiltinConditions.all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
   BuiltinConditions.spell(P..'scream',8122,BuiltinConditions.all({type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=2},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))},
  rotation={
   BuiltinConditions.block(P..'boundaries','tbc.priest.dps-boundaries',P),
   BuiltinConditions.block(P..'form','tbc.priest.shadowform',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-blast',8092),BuiltinConditions.spell(P..'pull-touch',34914),BuiltinConditions.spell(P..'pull-holy-fire',14914,BuiltinConditions.negate(BuiltinConditions.known(15407))),BuiltinConditions.spell(P..'pull-smite',585),BuiltinConditions.stop(P..'pull-stop')}},
   BuiltinConditions.block(P..'moving','tbc.priest.moving',P),
   {id=P..'dying',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),onFalse={},onTrue={
    BuiltinConditions.spell(P..'dying-blast',8092),BuiltinConditions.spell(P..'dying-death',32379,healthy()),BuiltinConditions.spell(P..'dying-flay',15407),BuiltinConditions.spell(P..'dying-smite',585),BuiltinConditions.stop(P..'dying-stop')}},
   BuiltinConditions.spell(P..'embrace',15286,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7})),
   BuiltinConditions.spell(P..'blast',8092),
   BuiltinConditions.block(P..'dots','tbc.priest.dots',P),
   BuiltinConditions.spell(P..'death',32379,healthy()),
   BuiltinConditions.block(P..'filler','tbc.priest.filler',P),
  },
 },
}))
