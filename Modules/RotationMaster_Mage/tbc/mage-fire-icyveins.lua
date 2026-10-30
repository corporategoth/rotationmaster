-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage Fire after Icy Veins, levels 10–70 when Fire is the primary talent tree; the default
-- Fire premade. Pyroblast opens a pull once learned, Improved Scorch keeps five Fire
-- Vulnerability stacks, Fireball fills, and Fire Blast is kept for movement.
-- The Wowhead variant (rm.tbc.mage.fire.wowhead) weaves Fire Blast instead.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.fire.icyveins',revision=5,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.wand-finish']=2,['tbc.mage.moving-fire-blast']=2,['tbc.mage.fire-aoe']=1,
  ['tbc.mage.improved-scorch']=1,['tbc.mage.armor-molten']=1,['tbc.mage.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'fire','icy-veins','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/fire-mage-leveling-guide',title='Icy Veins: Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/fire-mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Fire Mage rotation',reviewedAt='2026-10-23',revision='2026-01-12'},

 },
 body={
  priority=20,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={BuiltinConditions.block('mage-fire-armor','tbc.mage.armor-molten','mage-fire-'),BuiltinConditions.block('mage-fire-upkeep','tbc.mage.upkeep','mage-fire-')},
  rotation={
   BuiltinConditions.block('mage-fire-boundaries','tbc.mage.boundaries','mage-fire-'),
   {id='mage-fire-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('mage-fire-pull-pyroblast',11366),BuiltinConditions.spell('mage-fire-pull-fireball',133),stop('mage-fire-pull-stop')}},
   BuiltinConditions.block('mage-fire-moving','tbc.mage.moving-fire-blast','mage-fire-'),
   BuiltinConditions.block('mage-fire-aoe','tbc.mage.fire-aoe','mage-fire-'),
   BuiltinConditions.block('mage-fire-scorch','tbc.mage.improved-scorch','mage-fire-'),
   BuiltinConditions.spell('mage-fire-fireball',133),
   BuiltinConditions.block('mage-fire-finish','tbc.mage.wand-finish','mage-fire-'),
  },
 },
}))
