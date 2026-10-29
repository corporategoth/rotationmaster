-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Protection Paladin after the simulator tank lists (Sha, Horridon, Iron
-- Juggernaut) and wowtbc.gg, levels 10–90: an alternative to rm.mop.paladin.protection, off by
-- default (same switch, lower priority). Shield of the Righteous pools to full Holy Power unless
-- you drop below 40% health; Eternal Flame just before it fades with more than two Bastion of Glory
-- stacks at 3 Holy Power (or free with the tier-16 proc); Sacred Shield kept up; Holy Avenger and
-- Avenging Wrath on cooldown. Generators: Crusader Strike, Judgment, then Avenger's Shield, with
-- Hammer of Wrath low. Boss-timed defensives stay manual.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.protection.simulator',revision=7,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-insight']=2,['mop.paladin.prot-upkeep']=1,['mop.paladin.prot-open']=4,['mop.paladin.prot-aoe']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'protection','tank','single-target','aoe'},
 sources={

  {url='https://wowtbc.gg/mop/class-guides/protection-paladin/',title='wowtbc.gg: MoP Protection Paladin guide',reviewedAt='2026-10-23',notes='Same generator order; Sacred Shield maintained.'},
 },
 body={priority=20,disabled=true,specs={66},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('protsim-upkeep','mop.paladin.prot-upkeep','protsim-'),
   BuiltinConditions.block('protsim-class','mop.paladin.upkeep','protsim-'),
   BuiltinConditions.spell('protsim-eternal-flame',114163,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(114163)),{type='BUFF_REMAIN',unit='player',spell=114163,ownbuff=true,operator='LESSTHAN',value=2}),
    {type='BUFF_STACKS',unit='player',spell=114637,operator='GREATERTHAN',value=2},BuiltinConditions.any(hp('GREATERTHANOREQUALS',3),BuiltinConditions.buff(144569)))),
   BuiltinConditions.spell('protsim-shield-righteous',53600,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(hp('LESSTHAN',-1),BuiltinConditions.buff(90174),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4}))),
   BuiltinConditions.spell('protsim-sacred-shield',20925,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(65148)),{type='BUFF_REMAIN',unit='player',spell=65148,ownbuff=true,operator='LESSTHAN',value=5})),
   BuiltinConditions.spell('protsim-holy-avenger',105809,BuiltinConditions.combat()),
   BuiltinConditions.spell('protsim-avenging-wrath',31884,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('protsim-boundaries','mop.paladin.damage-boundaries','protsim-'),
   BuiltinConditions.block('protsim-open','mop.paladin.prot-open','protsim-'),
   BuiltinConditions.block('protsim-aoe','mop.paladin.prot-aoe','protsim-'),
   BuiltinConditions.spell('protsim-crusader-strike',35395),
   BuiltinConditions.spell('protsim-judgment',20271),
   BuiltinConditions.spell('protsim-avengers-shield',31935),
   BuiltinConditions.spell('protsim-holy-wrath',119072),
   BuiltinConditions.spell('protsim-execution-sentence',114157),
   BuiltinConditions.spell('protsim-lights-hammer',114158),
   BuiltinConditions.spell('protsim-hammer-wrath',24275),
   BuiltinConditions.spell('protsim-consecration',26573),
   BuiltinConditions.spell('protsim-holy-prism',114165),
   BuiltinConditions.spell('protsim-sacred-shield-filler',20925),
  },
 },
}))
