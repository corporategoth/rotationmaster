-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Hunter before a specialization: levels 1–9, and any Hunter with no
-- specialization chosen (Warcraft Tavern's leveling list). The lowest priority, so the Beast
-- Mastery, Marksmanship and Survival premades take over as soon as a specialization is
-- chosen. Hunter's Mark and Arcane Shot to pull; Serpent Sting, Multi-Shot on three or more,
-- Arcane Shot, Steady Shot, Auto Shot.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local idle=BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.unspecialized',revision=5,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.serpent']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'leveling','single-target'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/hunter-leveling-guide/',title='Warcraft Tavern: MoP Hunter leveling guide',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/beast-mastery-hunter-leveling',title='Icy Veins: MoP Classic Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-05-29',notes='The specialization rotation from level 10.'},
 },
 body={priority=1,
  cooldowns={
   BuiltinConditions.block('hunter-pet','mop.hunter.pet','hunter-'),
   BuiltinConditions.block('hunter-aspect','mop.hunter.aspect','hunter-'),
  },
  rotation={
   BuiltinConditions.block('hunter-boundaries','mop.hunter.boundaries','hunter-'),
   {id='hunter-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.block('hunter-pull-mark','mop.hunter.mark','hunter-pull-'),
    BuiltinConditions.spell('hunter-pull-arcane',3044),
    {id='hunter-pull-auto-shot',type='spell',action=75,ranked=true,conditions=idle},
    BuiltinConditions.stop('hunter-pull-stop')}},
   BuiltinConditions.block('hunter-serpent','mop.hunter.serpent','hunter-'),
   BuiltinConditions.spell('hunter-multi-shot',2643,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   BuiltinConditions.spell('hunter-arcane',3044),
   BuiltinConditions.spell('hunter-steady',56641),
   {id='hunter-auto-shot',type='spell',action=75,ranked=true,conditions=idle},
   BuiltinConditions.stop('hunter-wait'),
  },
 },
}))
