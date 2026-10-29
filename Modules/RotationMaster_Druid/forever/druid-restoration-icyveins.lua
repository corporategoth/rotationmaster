-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Restoration Druid after Icy Veins, levels 10–60: a player-chosen alternative to
-- rm.forever.druid.restoration (same switch, lower priority, off by default). HoT-first on your
-- friendly target: Rejuvenation, then Regrowth when missing, Healing Touch only with both HoTs
-- already running, Swiftmend on a HoT target, Wild Growth; Innervate on cooldown. Health is secret
-- on Forever, so the target you pick is the only signal of who needs healing.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Balance, 2 Feral Combat, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.restoration.icyveins',revision=6,
 blocks={['forever.druid.boundaries']=3,['forever.druid.upkeep']=1,['forever.druid.healer-upkeep']=2,['forever.druid.spare-damage']=2,['forever.druid.dots']=2},
 applicability={families={'forever'},actionContext='player',class='DRUID'},
 tags={'restoration','healer','group','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-healer-pve-guide',title='Icy Veins: Forever Restoration Druid PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-leveling',title='Icy Veins: Forever Restoration Druid leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs and ranks only.'},
 },
 body={priority=25,disabled=true,
  -- From 11 Restoration points (Gift of the Earthmother's tier), so dungeon healers at 20-24 qualify.
  switch=BuiltinConditions.all({type='GROUP'},tree(3,11)),
  cooldowns={
   BuiltinConditions.block('rejuv-upkeep','forever.druid.upkeep','rejuv-'),
   BuiltinConditions.block('rejuv-healer-upkeep','forever.druid.healer-upkeep','rejuv-'),
   BuiltinConditions.spell('rejuv-innervate',29166,{type='COMBAT',unit='player'}),
  },
  rotation={
   BuiltinConditions.block('rejuv-boundaries','forever.druid.boundaries','rejuv-'),
   {id='rejuv-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    BuiltinConditions.block('rejuv-damage','forever.druid.spare-damage','rejuv-hostile-')}},
   BuiltinConditions.stop('rejuv-target',BuiltinConditions.negate(BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})))),
   BuiltinConditions.spell('rejuv-rejuvenation',774,BuiltinConditions.negate(hot(774))),
   BuiltinConditions.spell('rejuv-regrowth',8936,BuiltinConditions.negate(hot(8936))),
   BuiltinConditions.spell('rejuv-healing-touch',5185,BuiltinConditions.all(hot(774),hot(8936))),
   BuiltinConditions.spell('rejuv-swiftmend',18562,BuiltinConditions.any(hot(774),hot(8936))),
   BuiltinConditions.spell('rejuv-wild-growth',408120),
   BuiltinConditions.stop('rejuv-done'),
  },
 },
}))
