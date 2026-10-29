-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Restoration Druid in a group, levels 10–60, after Warcraft Tavern: heals your current
-- friendly target (RM suggests the spell; you choose the target). Swiftmend first when a HoT is
-- on the target (it no longer consumes the HoT), Wild Growth, Regrowth and Rejuvenation when they
-- are missing, Healing Touch. Health and mana are secret on Forever, so the target you pick is the
-- only signal of who needs healing. On a hostile target: DoTs and Wrath. Solo Restoration levels
-- with the Balance premade. The Icy Veins HoT-first variant is rm.forever.druid.restoration.icyveins.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Balance, 2 Feral Combat, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.restoration',revision=6,
 blocks={['forever.druid.boundaries']=3,['forever.druid.upkeep']=1,['forever.druid.healer-upkeep']=2,['forever.druid.spare-damage']=2,['forever.druid.dots']=2},
 applicability={families={'forever'},actionContext='player',class='DRUID'},
 tags={'restoration','healer','group','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/restoration-druid/',title='Warcraft Tavern: Forever Restoration Druid',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-healer-pve-guide',title='Icy Veins: Forever Restoration Druid PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Spare-time damage list and Tranquility.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Swiftmend keeps the HoT; Wild Growth cooldown; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs and ranks only.'},
 },
 body={priority=30,
  -- From 11 Restoration points (Gift of the Earthmother's tier), so dungeon healers at 20-24 qualify.
  switch=BuiltinConditions.all({type='GROUP'},tree(3,11)),
  cooldowns={
   BuiltinConditions.block('resto-upkeep','forever.druid.upkeep','resto-'),
   BuiltinConditions.block('resto-healer-upkeep','forever.druid.healer-upkeep','resto-'),
   BuiltinConditions.spell('resto-innervate',29166,{type='COMBAT',unit='player'}),
  },
  rotation={
   BuiltinConditions.block('resto-boundaries','forever.druid.boundaries','resto-'),
   {id='resto-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    BuiltinConditions.block('resto-damage','forever.druid.spare-damage','resto-hostile-')}},
   BuiltinConditions.stop('resto-target',BuiltinConditions.negate(BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})))),
   BuiltinConditions.spell('resto-swiftmend',18562,BuiltinConditions.any(hot(774),hot(8936))),
   BuiltinConditions.spell('resto-wild-growth',408120),
   BuiltinConditions.spell('resto-regrowth',8936,BuiltinConditions.negate(hot(8936))),
   BuiltinConditions.spell('resto-rejuvenation',774,BuiltinConditions.negate(hot(774))),
   BuiltinConditions.spell('resto-healing-touch',5185),
   BuiltinConditions.stop('resto-done'),
  },
 },
}))
