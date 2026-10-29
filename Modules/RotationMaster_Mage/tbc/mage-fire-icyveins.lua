-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage Fire after Icy Veins, levels 10–70 when Fire is the primary talent tree; the default
-- Fire premade. Pyroblast opens a pull once learned, Improved Scorch keeps five Fire
-- Vulnerability stacks, Fireball fills, and Fire Blast is kept for movement.
-- The Wowhead variant (rm.tbc.mage.fire.wowhead) weaves Fire Blast instead.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.fire.icyveins',revision=5,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.wand-finish']=2,['tbc.mage.moving-fire-blast']=2,['tbc.mage.fire-aoe']=1,
  ['tbc.mage.improved-scorch']=1,['tbc.mage.armor-molten']=1,['tbc.mage.upkeep']=1},
 nameKey="Fire (Icy Veins)",descriptionKey="Fire after Icy Veins, chosen when Fire is your main talent tree. Pyroblast opens a pull once learned, Improved Scorch keeps five Fire Vulnerability stacks, Fireball fills, Fire Blast is for moving; Blast Wave, Dragon's Breath and Flamestrike for three or more enemies. Reminders: Molten, Mage or Ice Armor, Combustion below 20% target health, mana gem, Evocation and the shared Mage utilities.",
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'fire','icy-veins','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/fire-mage-leveling-guide',title='Icy Veins: Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/fire-mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Fire Mage rotation',reviewedAt='2026-10-23',revision='2026-01-12'},

 },
 body={
  priority=20,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={block('mage-fire-armor','tbc.mage.armor-molten','mage-fire-'),block('mage-fire-upkeep','tbc.mage.upkeep','mage-fire-')},
  rotation={
   block('mage-fire-boundaries','tbc.mage.boundaries','mage-fire-'),
   {id='mage-fire-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('mage-fire-pull-pyroblast',11366),spell('mage-fire-pull-fireball',133),stop('mage-fire-pull-stop')}},
   block('mage-fire-moving','tbc.mage.moving-fire-blast','mage-fire-'),
   block('mage-fire-aoe','tbc.mage.fire-aoe','mage-fire-'),
   block('mage-fire-scorch','tbc.mage.improved-scorch','mage-fire-'),
   spell('mage-fire-fireball',133),
   block('mage-fire-finish','tbc.mage.wand-finish','mage-fire-'),
  },
 },
}))
