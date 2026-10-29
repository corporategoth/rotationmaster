-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Fire Mage after Icy Veins' leveling build (no Improved Scorch), levels 10–60: a
-- player-chosen alternative to rm.forever.mage.fire (same switch, lower priority, off by default).
-- Pyroblast opens; Fire Blast spends Wake of Fire; Scorch as the mob closes (target health is secret
-- on Forever, so its low-target finishers are left out);
-- Frostfire Bolt from 40, else Fireball. No Heating Up or Scorch-stack steps.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Arcane, 2 Fire, 3 Frost; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.fire.icyveins',revision=7,
 blocks={['forever.mage.boundaries']=3,['forever.mage.fire-moving']=2,['forever.mage.fire-aoe']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'fire','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/fire-mage-leveling',title='Icy Veins: Forever Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/fire-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Fire Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=25,disabled=true,switch=tree(2,11),
  cooldowns={BuiltinConditions.block('ivfire-upkeep','forever.mage.upkeep','ivfire-')},
  rotation={
   BuiltinConditions.block('ivfire-boundaries','forever.mage.boundaries','ivfire-'),
   {id='ivfire-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('ivfire-pull-pyroblast',11366),BuiltinConditions.spell('ivfire-pull-fireball',133),BuiltinConditions.stop('ivfire-pull-stop')}},
   BuiltinConditions.block('ivfire-moving','forever.mage.fire-moving','ivfire-'),
   BuiltinConditions.spell('ivfire-fire-blast',2136,{type='BUFF',unit='player',spell=1312934}),
   BuiltinConditions.block('ivfire-aoe','forever.mage.fire-aoe','ivfire-'),
   BuiltinConditions.spell('ivfire-scorch',2948,{type='DISTANCE',unit='target',value=8}),
   BuiltinConditions.spell('ivfire-frostfire',401502),
   BuiltinConditions.spell('ivfire-fireball',133),
   BuiltinConditions.block('ivfire-wand','forever.mage.wand','ivfire-'),
  },
 },
}))
