-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Protection Paladin, levels 10–90, in the Protection specialization (66).
-- Icy Veins' order with Hekili's thresholds. Shield of the Righteous, Eternal Flame and Word of Glory
-- are off the global cooldown, so they are reminders beside the rotation: Shield of the Righteous
-- whenever it is usable (3 Holy Power), Eternal Flame on yourself when it is running out with three
-- Bastion of Glory stacks and 3 Holy Power. Rotation: Grand Crusader Avenger's Shield, AoE at three
-- enemies, Avenger's Shield, Hammer of Wrath, Crusader Strike, Judgment, tier-six talent,
-- Consecration, Holy Wrath. The pool-to-five variant is rm.mop.paladin.protection.simulator.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local tanking={type='THREAT',unit='target',threat=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.protection',revision=7,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-insight']=2,['mop.paladin.prot-upkeep']=1,['mop.paladin.prot-open']=4,['mop.paladin.prot-aoe']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'protection','tank','leveling','single-target','aoe','icy-veins','hekili'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-paladin-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Protection Paladin rotation',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-paladin-leveling',title='Icy Veins: MoP Classic Protection Paladin leveling',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://github.com/Smufrik/Hekili/blob/main/MistsOfPandaria/Priorities/PaladinProtection.simc',title='Hekili MoP Classic: Protection priority',reviewedAt='2026-10-23',revision='1ebafc17',notes='Shield of the Righteous at 3 Holy Power, Word of Glory under 70%, AoE at 3+.'},
  {url='https://www.method.gg/mop-classic/protection-paladin-class-guide-mop-classic',title='Method: MoP Classic Protection Paladin guide',reviewedAt='2026-10-23',revision='2025-07-23',notes='Righteous Fury; wings and Holy Avenger on cooldown.'},
 },
 body={priority=30,specs={66},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('prot-upkeep','mop.paladin.prot-upkeep','prot-'),
   BuiltinConditions.block('prot-class','mop.paladin.upkeep','prot-'),
   BuiltinConditions.spell('prot-shield-righteous',53600,BuiltinConditions.combat()),
   BuiltinConditions.spell('prot-eternal-flame',114163,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(114163)),{type='BUFF_REMAIN',unit='player',spell=114163,ownbuff=true,operator='LESSTHAN',value=3}),
    {type='BUFF_STACKS',unit='player',spell=114637,operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.any({type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.buff(90174)))),
   BuiltinConditions.spell('prot-word-of-glory',85673,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(114163)),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
   BuiltinConditions.spell('prot-sacred-shield',20925,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(65148)),{type='BUFF_REMAIN',unit='player',spell=65148,ownbuff=true,operator='LESSTHAN',value=5})),
   BuiltinConditions.spell('prot-avenging-wrath',31884,BuiltinConditions.all(BuiltinConditions.combat(),tanking)),
   BuiltinConditions.spell('prot-holy-avenger',105809,BuiltinConditions.all(BuiltinConditions.combat(),tanking)),
  },
  rotation={
   BuiltinConditions.block('prot-boundaries','mop.paladin.damage-boundaries','prot-'),
   BuiltinConditions.block('prot-open','mop.paladin.prot-open','prot-'),
   BuiltinConditions.spell('prot-grand-crusader',31935,BuiltinConditions.buff(85416)),
   BuiltinConditions.block('prot-aoe','mop.paladin.prot-aoe','prot-'),
   BuiltinConditions.spell('prot-avengers-shield',31935),
   BuiltinConditions.spell('prot-hammer-wrath',24275),
   BuiltinConditions.spell('prot-crusader-strike',35395),
   BuiltinConditions.spell('prot-judgment',20271),
   BuiltinConditions.spell('prot-execution-sentence',114157),
   BuiltinConditions.spell('prot-lights-hammer',114158),
   BuiltinConditions.spell('prot-holy-prism',114165),
   BuiltinConditions.spell('prot-consecration',26573),
   BuiltinConditions.spell('prot-holy-wrath',119072),
   BuiltinConditions.spell('prot-sacred-shield-filler',20925),
  },
 },
}))
