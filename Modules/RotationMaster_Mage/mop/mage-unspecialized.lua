-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Mage before a specialization: levels 1–9, and any Mage who has not
-- chosen one (the spec premades switch on the specialization and outrank this). Frostfire
-- Bolt, Fire Blast to finish or on the move, Ice Lance on the move, Arcane Explosion on packs,
-- Frost Nova when a mob reaches you. RM policy assembled from the spells' training levels; no source
-- writes a level 1–9 list.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.unspecialized',revision=5,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-molten']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'leveling','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-mage-leveling',title='Icy Veins: MoP Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2025-06-17',notes='Spell training levels only; no level 1-9 priority.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/frost/dps-leveling-talent-builds-tips',title='Wowhead: MoP Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-06-29',notes='Frost Nova when mobs get close.'},
 },
 body={priority=0,
  cooldowns={
   BuiltinConditions.block('mage-armor','mop.mage.armor-molten','mage-'),
   BuiltinConditions.block('mage-upkeep','mop.mage.upkeep','mage-'),
   BuiltinConditions.spell('mage-frost-nova',122,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'}),{type='ISSAME',unit='targettarget',otherunit='player'})),
  },
  rotation={
   BuiltinConditions.block('mage-boundaries','mop.mage.boundaries','mage-'),
   {id='mage-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('mage-pull-frostfire',44614),BuiltinConditions.stop('mage-pull-stop')}},
   {id='mage-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('mage-aoe-explosion',1449,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3})}},
   BuiltinConditions.spell('mage-fire-blast',2136,BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.15},{type='MOVING'})),
   BuiltinConditions.spell('mage-ice-lance',30455,{type='MOVING'}),
   BuiltinConditions.spell('mage-frostfire',44614),
  },
 },
}))
