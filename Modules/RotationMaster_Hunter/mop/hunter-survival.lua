-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Survival Hunter, levels 10–90, in the Survival
-- specialization (255). Wowhead's Phase 5 order with simulator' pack gates and Black Arrow
-- refresh: Explosive Shot on cooldown and on every Lock and Load, Kill Shot, Black Arrow on a target
-- that lives 8 s, talents, Serpent Sting kept up by Cobra Shot, Arcane Shot as a focus dump that
-- waits for Black Arrow, Cobra or Steady Shot. Two or more enemies: Multi-Shot on Lock and Load with
-- full focus, Explosive Shot up to five targets, Multi-Shot to spend.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local loaded=BuiltinConditions.buff(56453)
local thrill=BuiltinConditions.buff(34720)
local ARROW=3674
local arrow=BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=ARROW,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=ARROW,owndebuff=true,operator='LESSTHAN',value=2}),
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=8})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.survival',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1,['mop.hunter.filler']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'survival','leveling','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/survival/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Survival Hunter rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},

  {url='https://www.icy-veins.com/mists-of-pandaria-classic/survival-hunter-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Survival Hunter rotation',reviewedAt='2026-10-23',revision='2026-05-29',notes='Explosive Shot opener while leveling.'},
 },
 body={priority=10,specs={255},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('sv-pet','mop.hunter.pet','sv-'),
   BuiltinConditions.block('sv-aspect','mop.hunter.aspect','sv-'),
   BuiltinConditions.block('sv-utility','mop.hunter.utility','sv-'),
   BuiltinConditions.block('sv-burst','mop.hunter.burst','sv-'),
  },
  rotation={
   BuiltinConditions.block('sv-boundaries','mop.hunter.boundaries','sv-'),
   {id='sv-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.block('sv-pull-mark','mop.hunter.mark','sv-pull-'),
    BuiltinConditions.spell('sv-pull-black-arrow',ARROW),
    BuiltinConditions.spell('sv-pull-explosive',53301),
    BuiltinConditions.stop('sv-pull-stop')}},
   {id='sv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    BuiltinConditions.spell('sv-aoe-loaded-multi',2643,BuiltinConditions.all(loaded,focus('GREATERTHANOREQUALS',90))),
    BuiltinConditions.spell('sv-aoe-explosive',53301,BuiltinConditions.any(loaded,enemies('LESSTHANOREQUALS',5))),
    BuiltinConditions.spell('sv-aoe-kill-shot',53351),
    BuiltinConditions.spell('sv-aoe-black-arrow',ARROW,arrow),
    BuiltinConditions.spell('sv-aoe-explosive-trap',13813,enemies('GREATERTHANOREQUALS',3)),
    BuiltinConditions.block('sv-aoe-shots','mop.hunter.talent-shots','sv-aoe-'),
    BuiltinConditions.spell('sv-aoe-multi-shot',2643,BuiltinConditions.any(focus('GREATERTHANOREQUALS',60),thrill)),
    BuiltinConditions.block('sv-aoe-filler','mop.hunter.filler','sv-aoe-')}},
   BuiltinConditions.spell('sv-explosive',53301),
   BuiltinConditions.spell('sv-kill-shot',53351),
   BuiltinConditions.spell('sv-black-arrow',ARROW,arrow),
   BuiltinConditions.block('sv-talents','mop.hunter.talents','sv-'),
   BuiltinConditions.block('sv-shots','mop.hunter.talent-shots','sv-'),
   BuiltinConditions.block('sv-serpent','mop.hunter.serpent','sv-'),
   BuiltinConditions.spell('sv-arcane',3044,BuiltinConditions.any(thrill,focus('GREATERTHANOREQUALS',75),BuiltinConditions.all(focus('GREATERTHANOREQUALS',55),
    BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(ARROW)),{type='SPELL_COOLDOWN',spell=ARROW,operator='GREATERTHANOREQUALS',value=4})))),
   BuiltinConditions.block('sv-filler','mop.hunter.filler','sv-'),
  },
 },
}))
