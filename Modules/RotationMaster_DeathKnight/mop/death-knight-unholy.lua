-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Unholy Death Knight, levels 55–90, after Icy Veins (rotation and leveling
-- pages). Also the catch-all: every Death Knight knows Death Coil, so this owns an unspecialized
-- knight (diseases, Blood Strike, Death Coil, Death Strike) and anyone Blood or Frost do not claim.
-- Dark Transformation at five Shadow Infusion stacks, Scourge Strike, Death Coil on Sudden Doom or
-- 40 runic power, Festering Strike, Soul Reaper under 35%. The rune-cap variant is
-- rm.mop.deathknight.unholy.simulator.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function remain(id)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=3}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.unholy',revision=5,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.unholy-upkeep']=2,['mop.deathknight.unholy-open']=2,
  ['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/unholy-death-knight-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Unholy Death Knight rotation',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/unholy-death-knight-leveling',title='Icy Veins: MoP Classic Unholy Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23',notes='Death Strike at low health, cooldowns early and often while leveling.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/death-knight/unholy/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Unholy Death Knight rotation',reviewedAt='2026-10-23',revision='2025-08-02',notes='Read from a Wayback snapshot; same order, Outbreak on Strength procs.'},
 },
 body={priority=10,switch=BuiltinConditions.known(47541),
  cooldowns={
   BuiltinConditions.block('unholy-upkeep','mop.deathknight.unholy-upkeep','unholy-'),
   BuiltinConditions.block('unholy-class','mop.deathknight.upkeep','unholy-'),
  },
  rotation={
   BuiltinConditions.block('unholy-boundaries','mop.deathknight.boundaries','unholy-'),
   BuiltinConditions.block('unholy-open','mop.deathknight.unholy-open','unholy-'),
   BuiltinConditions.spell('unholy-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
   BuiltinConditions.spell('unholy-soul-reaper',130736,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   BuiltinConditions.spell('unholy-dark-transformation',63560,{type='BUFF_STACKS',unit='pet',spell=91342,operator='GREATERTHANOREQUALS',value=5}),
   BuiltinConditions.spell('unholy-death-coil-cap',47541,rp('GREATERTHANOREQUALS',90)),
   BuiltinConditions.spell('unholy-death-and-decay',43265,{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=8}),
   BuiltinConditions.spell('unholy-scourge-strike',55090),
   BuiltinConditions.spell('unholy-death-coil',47541,BuiltinConditions.any(BuiltinConditions.buff(81340),rp('GREATERTHANOREQUALS',40))),
   BuiltinConditions.spell('unholy-outbreak-snapshot',77575,BuiltinConditions.buff(53365)),
   BuiltinConditions.spell('unholy-festering-strike',85948),
   BuiltinConditions.spell('unholy-blood-strike',45902,BuiltinConditions.negate(BuiltinConditions.known(85948))),
   BuiltinConditions.spell('unholy-plague-leech',123693,BuiltinConditions.all(BuiltinConditions.any(remain(55095),remain(55078)),{type='SPELL_AVAIL',spell=77575})),
   BuiltinConditions.spell('unholy-horn-filler',57330),
  },
 },
}))
