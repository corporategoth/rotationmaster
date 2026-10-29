-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Balance Druid after Icy Veins, SimulationCraft and Wowhead (optimal
-- reference): Moonkin Form and two Wraths before the pull; Sunfire and Moonfire kept up; Eclipse
-- entered when neither is active (Lunar on three or more enemies, Solar otherwise); Starfall on
-- Starweaver's Warp, Touch the Cosmos or packs; Starsurge on Starweaver's Weft or Touch the Cosmos;
-- the Moons; Wild Mushroom in an Eclipse; Starsurge whenever it is affordable; Starfire in a Lunar
-- Eclipse or on packs, else Wrath. Astral Power is secret on Retail, so Starsurge spends at its cost
-- instead of before the cap. Disabled: DoTs, Eclipse and procs are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function refresh(id)return BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=id,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=5.4})end
local eclipse=BuiltinConditions.any(buff(48517),buff(48518))
local aligned=BuiltinConditions.any(buff(194223),buff(102560))
local moonkin=BuiltinConditions.any(buff(24858),buff(102560))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.balance.guide',revision=7,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'balance','ranged','reference','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/balance-druid-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Balance Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_balance.simc',title='SimulationCraft default action list: Balance',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.wowhead.com/guide/classes/druid/balance/rotation-cooldowns-pve-dps',title='Wowhead: Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-04-19',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={102},
  cooldowns={
   BuiltinConditions.block('baguide-utility','retail.druid.utility','baguide-'),
   BuiltinConditions.spell('baguide-solar-beam',78675,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   BuiltinConditions.spell('baguide-celestial-alignment',194223,BuiltinConditions.combat()),
   BuiltinConditions.spell('baguide-incarnation',102560,BuiltinConditions.combat()),
   BuiltinConditions.spell('baguide-fury-of-elune',202770,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(eclipse))),
   BuiltinConditions.spell('baguide-force-of-nature',205636,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(eclipse))),
   BuiltinConditions.spell('baguide-convoke',391528,aligned),
  },
  rotation={
   BuiltinConditions.block('baguide-boundaries','retail.druid.boundaries','baguide-'),
   {id='baguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('baguide-pull-moonkin',24858,BuiltinConditions.negate(moonkin)),BuiltinConditions.spell('baguide-pull-wrath',5176),BuiltinConditions.stop('baguide-pull-stop')}},
   BuiltinConditions.spell('baguide-sunfire',93402,refresh(164815)),
   BuiltinConditions.spell('baguide-moonfire',8921,refresh(164812)),
   {id='baguide-eclipse',type='branch',conditions=eclipse,onTrue={},onFalse={
    BuiltinConditions.spell('baguide-lunar-eclipse',1233272,engaged(3)),BuiltinConditions.spell('baguide-solar-eclipse',1233346)}},
   BuiltinConditions.spell('baguide-starfall',191034,BuiltinConditions.any(buff(393942),buff(450360),engaged(3))),
   BuiltinConditions.spell('baguide-starsurge',78674,BuiltinConditions.any(buff(393944),buff(450360))),
   BuiltinConditions.spell('baguide-new-moon',274281),
   BuiltinConditions.spell('baguide-half-moon',274282),
   BuiltinConditions.spell('baguide-full-moon',274283),
   BuiltinConditions.spell('baguide-wild-mushroom',88747,eclipse),
   BuiltinConditions.spell('baguide-starsurge-spend',78674),
   BuiltinConditions.spell('baguide-starfire',194153,BuiltinConditions.any(buff(48518),engaged(3))),
   BuiltinConditions.spell('baguide-wrath',5176),
  },
 },
}))
