-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage Fire after Wowhead and simulator, levels 10–70 when Fire is the primary talent tree.
-- Same switch as the Icy Veins Fire premade but a lower priority, shipped disabled: enable it to use it.
-- It differs in two places: no Pyroblast opener, and Fire Blast is woven in whenever it is
-- ready while standing still (more damage, more mana), not kept for movement only.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.fire.wowhead',revision=6,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.wand-finish']=2,['tbc.mage.moving-fire-blast']=2,['tbc.mage.fire-aoe']=1,
  ['tbc.mage.improved-scorch']=1,['tbc.mage.armor-molten']=1,['tbc.mage.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'fire','wowhead','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/mage/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Mage DPS rotation',reviewedAt='2026-10-23',revision='2026-05-31'},
  {url='https://www.wowhead.com/tbc/guide/classes/mage/fire/leveling-tips',title='Wowhead: Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-01-04'},


 },
 body={
  priority=10,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={BuiltinConditions.block('mage-firewh-armor','tbc.mage.armor-molten','mage-firewh-'),BuiltinConditions.block('mage-firewh-upkeep','tbc.mage.upkeep','mage-firewh-')},
  rotation={
   BuiltinConditions.block('mage-firewh-boundaries','tbc.mage.boundaries','mage-firewh-'),
   {id='mage-firewh-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('mage-firewh-pull-fireball',133),stop('mage-firewh-pull-stop')}},
   BuiltinConditions.block('mage-firewh-moving','tbc.mage.moving-fire-blast','mage-firewh-'),
   BuiltinConditions.block('mage-firewh-aoe','tbc.mage.fire-aoe','mage-firewh-'),
   BuiltinConditions.block('mage-firewh-scorch','tbc.mage.improved-scorch','mage-firewh-'),
   BuiltinConditions.spell('mage-firewh-weave',2136),
   BuiltinConditions.spell('mage-firewh-fireball',133),
   BuiltinConditions.block('mage-firewh-finish','tbc.mage.wand-finish','mage-firewh-'),
  },
 },
}))
