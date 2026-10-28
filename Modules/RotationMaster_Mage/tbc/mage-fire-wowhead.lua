-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage Fire after Wowhead and wowsims, levels 10–70 when Fire is the primary talent tree.
-- Same switch as the Icy Veins Fire premade but a lower priority, shipped disabled: enable it to use it.
-- It differs in two places: no Pyroblast opener, and Fire Blast is woven in whenever it is
-- ready while standing still (more damage, more mana), not kept for movement only.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.fire.wowhead',revision=6,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.wand-finish']=2,['tbc.mage.moving-fire-blast']=2,['tbc.mage.fire-aoe']=1,
  ['tbc.mage.improved-scorch']=1,['tbc.mage.armor-molten']=1,['tbc.mage.upkeep']=1},
 nameKey='Default.TBC.Mage.FireWowhead.Name',descriptionKey='Default.TBC.Mage.FireWowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'fire','wowhead','wowsims','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/mage/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Mage DPS rotation',reviewedAt='2026-10-23',revision='2026-05-31'},
  {url='https://www.wowhead.com/tbc/guide/classes/mage/fire/leveling-tips',title='Wowhead: Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-01-04'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/mage/rotations.go',title='wowsims TBC Mage rotations (Fire Blast weave preset)',reviewedAt='2026-10-23',revision='3301fca'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/ui/core/talents/mage.ts',title='wowsims TBC Mage talent layout (Improved Scorch is Fire talent 10)',reviewedAt='2026-10-23',revision='3301fca',notes='Talent position only.'},
 },
 body={
  priority=10,disabled=true,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={block('mage-firewh-armor','tbc.mage.armor-molten','mage-firewh-'),block('mage-firewh-upkeep','tbc.mage.upkeep','mage-firewh-')},
  rotation={
   block('mage-firewh-boundaries','tbc.mage.boundaries','mage-firewh-'),
   {id='mage-firewh-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('mage-firewh-pull-fireball',133),stop('mage-firewh-pull-stop')}},
   block('mage-firewh-moving','tbc.mage.moving-fire-blast','mage-firewh-'),
   block('mage-firewh-aoe','tbc.mage.fire-aoe','mage-firewh-'),
   block('mage-firewh-scorch','tbc.mage.improved-scorch','mage-firewh-'),
   spell('mage-firewh-weave',2136),
   spell('mage-firewh-fireball',133),
   block('mage-firewh-finish','tbc.mage.wand-finish','mage-firewh-'),
  },
 },
}))
