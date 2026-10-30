-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Mage Frost AoE grinding after Icy Veins (with Warcraft Tavern's and Wowhead's leveling
-- notes), levels 20–60: auto-selected solo once Improved Blizzard is talented. Blizzard is the main
-- spell from two engaged enemies: Frost Nova the pack, Cone of Cold while Nova is spent, Blizzard
-- once nothing is in melee, Arcane Explosion close in; Frostbolt only on a single target. Mana
-- Shield and Ice Barrier go up before the pull. Body pulling, Blink and kiting stay with the player.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local P='mage-grind-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.mage.frost.icyveins',revision=5,
 blocks={['era.mage.boundaries']=3,['era.mage.frostbolt']=1,['era.mage.moving']=2,['era.mage.execute']=2,
  ['era.mage.wand-finish']=2,['era.mage.armor']=1,['era.mage.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='MAGE'},
 tags={'frost','leveling','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/aoe-grinding-frost-mage-leveling-talent-build-from-1-to-60',title='Icy Veins: AoE grinding Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Mage DPS rotation (solo AoE section)',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/mage-leveling-guide/',title='Warcraft Tavern: Classic Mage leveling',reviewedAt='2026-10-23'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/frost/leveling-tips',title='Wowhead: Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2024-11-18'},
 },
 body={
  priority=5,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='NOT',value={type='GROUP'}},{type='TALENT',layout='tree',tree=3,talent=10,operator='GREATERTHANOREQUALS',value=1}}},
  cooldowns={BuiltinConditions.block(P..'armor','era.mage.armor',P),
   BuiltinConditions.spell(P..'pull-mana-shield',1463,BuiltinConditions.all(BuiltinConditions.negate({type='COMBAT',unit='player'}),BuiltinConditions.negate({type='BUFF',unit='player',spell=1463,anyrank=true}),
    {type='MANAPCT',unit='player',operator='GREATERTHAN',value=.6})),
   BuiltinConditions.block(P..'upkeep','era.mage.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.block(P..'pull-filler','era.mage.frostbolt',P..'pull-'),stop(P..'pull-stop')}},
   BuiltinConditions.block(P..'moving','era.mage.moving',P),
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    BuiltinConditions.spell(P..'aoe-nova',122,near(2)),
    BuiltinConditions.spell(P..'aoe-cone',120,BuiltinConditions.all(near(2),{type='SPELL_COOLDOWN',spell=122,operator='GREATERTHAN',value=2})),
    BuiltinConditions.spell(P..'aoe-blizzard',10,BuiltinConditions.negate(near(1))),
    BuiltinConditions.spell(P..'aoe-explosion',1449,near(2)),
    BuiltinConditions.spell(P..'aoe-blizzard-close',10)}},
   BuiltinConditions.spell(P..'nova',122,BuiltinConditions.all(near(1),{type='THREAT',unit='target',threat=3})),
   BuiltinConditions.block(P..'execute','era.mage.execute',P),
   BuiltinConditions.block(P..'filler','era.mage.frostbolt',P),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
