-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever ranged Hunter, mana-saving (Mobalytics; also the form of Icy Veins' advice that RM
-- can express without reading mana), levels 1–60: a player-chosen alternative to
-- rm.forever.hunter.ranged (same switch, lower priority, off by default). Keeps one Hawk up, Aimed
-- Shot (Multi-Shot on packs), and no Arcane Shot once Summon Hawk is known; its second Hawk on a
-- healthy target is left out, as target health is secret on Forever.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.ranged.mobalytics',revision=6,
 blocks={['forever.hunter.boundaries']=4,['forever.hunter.deadzone']=3,['forever.hunter.pull']=3,['forever.hunter.moving']=2,
  ['forever.hunter.aspects-ranged']=1,['forever.hunter.pet-care']=2,['forever.hunter.burst']=1},
 applicability={families={'forever'},actionContext='player',class='HUNTER'},
 tags={'beast-mastery','marksmanship','ranged','leveling','mana-saving','mobalytics'},
 sources={
  {url='https://mobalytics.gg/wow-forever/classes/hunter-leveling-guide',title='Mobalytics: Forever Hunter leveling 1–30',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://mobalytics.gg/wow-forever/classes/marksmanship-hunter-guide',title='Mobalytics: Forever Marksmanship Hunter',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://www.icy-veins.com/wow-forever/beast-mastery-hunter-leveling',title='Icy Veins: Forever Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-10-17',notes='Arcane Shot only when mana-capped, which RM cannot read in Forever combat.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldown categories only.'},
 },
 body={priority=5,disabled=true,
  cooldowns={
   BuiltinConditions.block('saver-aspects','forever.hunter.aspects-ranged','saver-'),
   BuiltinConditions.spell('saver-trueshot-aura',1299346,BuiltinConditions.negate({type='BUFF',unit='player',spell=1299346,anyrank=true})),
   BuiltinConditions.block('saver-pet-care','forever.hunter.pet-care','saver-'),
   BuiltinConditions.block('saver-burst','forever.hunter.burst','saver-'),
   BuiltinConditions.spell('saver-intimidation',19577,BuiltinConditions.all({type='COMBAT',unit='player'},{type='THREAT',unit='target',threat=3})),
  },
  rotation={
   BuiltinConditions.block('saver-boundaries','forever.hunter.boundaries','saver-'),
   BuiltinConditions.block('saver-deadzone','forever.hunter.deadzone','saver-'),
   BuiltinConditions.block('saver-pull','forever.hunter.pull','saver-'),
   BuiltinConditions.block('saver-moving','forever.hunter.moving','saver-'),
   BuiltinConditions.spell('saver-auto-shot',75,BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})),
   BuiltinConditions.spell('saver-serpent-sting',1978,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
    BuiltinConditions.negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))),
   {id='saver-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    BuiltinConditions.spell('saver-multi-shot',2643)}},
   -- First Hawk: none summoned in the last 18 s (its lifetime).
   BuiltinConditions.spell('saver-first-hawk',1293241,BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=1293241,operator='LESSTHAN',value=18})),
   BuiltinConditions.spell('saver-aimed-shot',19434),
   BuiltinConditions.spell('saver-arcane-shot',3044,BuiltinConditions.negate({type='SPELL_KNOWN',spell=1293241})),
   BuiltinConditions.spell('saver-sniper-shot',1310687,{type='BUFF',unit='player',spell=415407}),
   BuiltinConditions.stop('saver-done'),
  },
 },
}))
