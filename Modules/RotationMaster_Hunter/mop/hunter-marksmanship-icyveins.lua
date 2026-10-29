-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Marksmanship Hunter, "Arcane dump" family (Icy Veins, Method,
-- wowtbc.gg, Hekili): Aimed Shot is hard-cast only above 80% target health or under Rapid Fire or
-- Bloodlust; spare focus goes to Arcane Shot at 60. Steady Focus refreshed under 4 s. Same switch
-- as rm.mop.hunter.marksmanship, lower priority and disabled: no switch can tell the two apart, so
-- the player chooses.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local moving={type='MOVING'}
local fire=BuiltinConditions.buff(82926)
local focusLow=BuiltinConditions.all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=63},BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.buff(53220)),{type='BUFF_REMAIN',unit='player',spell=53220,operator='LESSTHAN',value=4}))
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.marksmanship.icyveins',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'marksmanship','leveling','single-target','aoe','icy-veins','hekili'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/marksmanship-hunter-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Marksmanship Hunter rotation',reviewedAt='2026-10-23',revision='2026-05-29'},
  {url='https://www.method.gg/mop-classic/marksmanship-hunter-class-guide-mop-classic',title='Method: MoP Classic Marksmanship Hunter guide',reviewedAt='2026-10-23',notes='Aimed Shot during cooldowns and above 80%, Arcane Shot otherwise.'},
  {url='https://wowtbc.gg/mop/class-guides/marksmanship-hunter/',title='wowtbc.gg: MoP Marksmanship Hunter guide',reviewedAt='2026-10-23'},
  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/HunterMarksmanship.simc',title='Hekili MoP Classic Marksmanship priority',reviewedAt='2026-10-23',revision='0750b5dd98',notes='Arcane Shot at 60 focus outside haste.'},
 },
 body={priority=5,disabled=true,specs={254},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('mmiv-pet','mop.hunter.pet','mmiv-'),
   BuiltinConditions.block('mmiv-aspect','mop.hunter.aspect','mmiv-'),
   BuiltinConditions.block('mmiv-utility','mop.hunter.utility','mmiv-'),
   BuiltinConditions.block('mmiv-burst','mop.hunter.burst','mmiv-'),
  },
  rotation={
   BuiltinConditions.block('mmiv-boundaries','mop.hunter.boundaries','mmiv-'),
   {id='mmiv-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.block('mmiv-pull-mark','mop.hunter.mark','mmiv-pull-'),
    BuiltinConditions.spell('mmiv-pull-aimed',19434,BuiltinConditions.negate(moving)),
    BuiltinConditions.stop('mmiv-pull-stop')}},
   BuiltinConditions.spell('mmiv-steady-pair',56641,BuiltinConditions.all({type='SPELL_HISTORY',spell=56641,operator='EQUALS',value=1},focusLow)),
   {id='mmiv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onFalse={},onTrue={
    BuiltinConditions.spell('mmiv-aoe-multi-shot',2643),
    BuiltinConditions.spell('mmiv-aoe-fire',19434,fire),
    BuiltinConditions.spell('mmiv-aoe-kill-shot',53351),
    BuiltinConditions.block('mmiv-aoe-talents','mop.hunter.talents','mmiv-aoe-'),
    BuiltinConditions.block('mmiv-aoe-shots','mop.hunter.talent-shots','mmiv-aoe-'),
    BuiltinConditions.spell('mmiv-aoe-explosive-trap',13813),
    BuiltinConditions.spell('mmiv-aoe-steady',56641),
    BuiltinConditions.stop('mmiv-aoe-wait')}},
   BuiltinConditions.block('mmiv-serpent','mop.hunter.serpent','mmiv-'),
   BuiltinConditions.spell('mmiv-chimera',53209),
   BuiltinConditions.spell('mmiv-fire',19434,fire),
   BuiltinConditions.spell('mmiv-kill-shot',53351),
   BuiltinConditions.block('mmiv-talents','mop.hunter.talents','mmiv-'),
   BuiltinConditions.block('mmiv-shots','mop.hunter.talent-shots','mmiv-'),
   BuiltinConditions.spell('mmiv-steady-start',56641,focusLow),
   BuiltinConditions.spell('mmiv-aimed',19434,BuiltinConditions.all(BuiltinConditions.negate(moving),BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.8},BuiltinConditions.buff(3045),lust))),
   BuiltinConditions.spell('mmiv-arcane',3044,BuiltinConditions.any(focus('GREATERTHANOREQUALS',60),BuiltinConditions.buff(34720))),
   BuiltinConditions.spell('mmiv-steady',56641),
   BuiltinConditions.stop('mmiv-wait'),
  },
 },
}))
