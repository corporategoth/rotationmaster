-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Balance Druid after Icy Veins, SimulationCraft and Wowhead (optimal
-- reference): Moonkin Form and two Wraths before the pull; Sunfire and Moonfire kept up; Eclipse
-- entered when neither is active (Lunar on three or more enemies, Solar otherwise); Starfall on
-- Starweaver's Warp, Touch the Cosmos or packs; Starsurge on Starweaver's Weft or Touch the Cosmos;
-- the Moons; Wild Mushroom in an Eclipse; Starsurge whenever it is affordable; Starfire in a Lunar
-- Eclipse or on packs, else Wrath. Astral Power is secret on Retail, so Starsurge spends at its cost
-- instead of before the cap. Disabled: DoTs, Eclipse and procs are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function refresh(id)return any(negate({type='DEBUFF',unit='target',spell=id,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=5.4})end
local eclipse=any(buff(48517),buff(48518))
local aligned=any(buff(194223),buff(102560))
local moonkin=any(buff(24858),buff(102560))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.balance.guide',revision=7,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.BalanceGuide.Name',descriptionKey='Default.Retail.Druid.BalanceGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'balance','ranged','reference','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/balance-druid-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Balance Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/druid_balance.simc',title='SimulationCraft default action list: Balance',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.wowhead.com/guide/classes/druid/balance/rotation-cooldowns-pve-dps',title='Wowhead: Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-04-19',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={102},
  cooldowns={
   block('baguide-utility','retail.druid.utility','baguide-'),
   spell('baguide-solar-beam',78675,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   spell('baguide-celestial-alignment',194223,combat()),
   spell('baguide-incarnation',102560,combat()),
   spell('baguide-fury-of-elune',202770,all(combat(),negate(eclipse))),
   spell('baguide-force-of-nature',205636,all(combat(),negate(eclipse))),
   spell('baguide-convoke',391528,aligned),
  },
  rotation={
   block('baguide-boundaries','retail.druid.boundaries','baguide-'),
   {id='baguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('baguide-pull-moonkin',24858,negate(moonkin)),spell('baguide-pull-wrath',5176),stop('baguide-pull-stop')}},
   spell('baguide-sunfire',93402,refresh(164815)),
   spell('baguide-moonfire',8921,refresh(164812)),
   {id='baguide-eclipse',type='branch',conditions=eclipse,onTrue={},onFalse={
    spell('baguide-lunar-eclipse',1233272,engaged(3)),spell('baguide-solar-eclipse',1233346)}},
   spell('baguide-starfall',191034,any(buff(393942),buff(450360),engaged(3))),
   spell('baguide-starsurge',78674,any(buff(393944),buff(450360))),
   spell('baguide-new-moon',274281),
   spell('baguide-half-moon',274282),
   spell('baguide-full-moon',274283),
   spell('baguide-wild-mushroom',88747,eclipse),
   spell('baguide-starsurge-spend',78674),
   spell('baguide-starfire',194153,any(buff(48518),engaged(3))),
   spell('baguide-wrath',5176),
  },
 },
}))
