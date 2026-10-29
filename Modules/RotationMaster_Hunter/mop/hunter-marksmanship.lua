-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Marksmanship Hunter, levels 10–90, in the Marksmanship
-- specialization (254). Wowhead's Phase 5 order with simulator' rule for when to hard-cast
-- Aimed Shot: Steady Shots in pairs for Steady Focus (63), Chimera Shot, Serpent Sting, Aimed
-- Shot on Fire!, Kill Shot, talents, Aimed Shot above 80% health, under Rapid Fire or Bloodlust, at
-- 85 focus or while Chimera is away, Arcane Shot only while moving, Steady Shot. Four or more
-- enemies: Chimera, Fire!, Multi-Shot. The Arcane Shot dump variant is
-- rm.mop.hunter.marksmanship.icyveins.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local moving={type='MOVING'}
local fire=BuiltinConditions.buff(82926)
-- Steady Focus (63) missing or under 5 s; the passive's level stands in for knowing it.
local focusLow=BuiltinConditions.all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=63},BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(53220)),{type='BUFF_REMAIN',unit='player',spell=53220,operator='LESSTHAN',value=5}))
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.marksmanship',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'marksmanship','leveling','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/marksmanship/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Marksmanship Hunter rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},

  {url='https://www.warcrafttavern.com/mop/guides/pve-marksmanship-hunter-dps-rotations-cooldowns/',title='Warcraft Tavern: MoP Marksmanship Hunter rotation',reviewedAt='2026-10-23',notes='Arcane Shot when you cannot stand still.'},
 },
 body={priority=10,specs={254},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('mm-pet','mop.hunter.pet','mm-'),
   BuiltinConditions.block('mm-aspect','mop.hunter.aspect','mm-'),
   BuiltinConditions.block('mm-utility','mop.hunter.utility','mm-'),
   BuiltinConditions.block('mm-burst','mop.hunter.burst','mm-'),
  },
  rotation={
   BuiltinConditions.block('mm-boundaries','mop.hunter.boundaries','mm-'),
   {id='mm-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.block('mm-pull-mark','mop.hunter.mark','mm-pull-'),
    BuiltinConditions.spell('mm-pull-aimed',19434,BuiltinConditions.negate(moving)),
    BuiltinConditions.stop('mm-pull-stop')}},
   BuiltinConditions.spell('mm-steady-pair',56641,BuiltinConditions.all({type='SPELL_HISTORY',spell=56641,operator='EQUALS',value=1},focusLow)),
   {id='mm-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onFalse={},onTrue={
    BuiltinConditions.spell('mm-aoe-chimera',53209,enemies('LESSTHAN',10)),
    BuiltinConditions.spell('mm-aoe-fire',19434,fire),
    BuiltinConditions.spell('mm-aoe-multi-shot',2643),
    BuiltinConditions.spell('mm-aoe-kill-shot',53351),
    BuiltinConditions.spell('mm-aoe-explosive-trap',13813),
    BuiltinConditions.block('mm-aoe-shots','mop.hunter.talent-shots','mm-aoe-'),
    BuiltinConditions.spell('mm-aoe-steady',56641),
    BuiltinConditions.stop('mm-aoe-wait')}},
   BuiltinConditions.spell('mm-chimera',53209),
   BuiltinConditions.block('mm-serpent','mop.hunter.serpent','mm-'),
   BuiltinConditions.spell('mm-fire',19434,fire),
   BuiltinConditions.spell('mm-kill-shot',53351),
   BuiltinConditions.block('mm-talents','mop.hunter.talents','mm-'),
   BuiltinConditions.block('mm-shots','mop.hunter.talent-shots','mm-'),
   BuiltinConditions.spell('mm-steady-start',56641,focusLow),
   BuiltinConditions.spell('mm-aimed',19434,BuiltinConditions.all(BuiltinConditions.negate(moving),BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.8},BuiltinConditions.buff(3045),lust,
    focus('GREATERTHANOREQUALS',85),BuiltinConditions.negate(BuiltinConditions.known(53209)),{type='SPELL_COOLDOWN',spell=53209,operator='GREATERTHANOREQUALS',value=3}))),
   BuiltinConditions.spell('mm-arcane-moving',3044,BuiltinConditions.all(moving,BuiltinConditions.any(focus('GREATERTHANOREQUALS',60),BuiltinConditions.buff(34720)))),
   BuiltinConditions.spell('mm-steady',56641),
   BuiltinConditions.stop('mm-wait'),
  },
 },
}))
