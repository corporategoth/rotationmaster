-- Append-only record of shipped Built In composition revisions; never rewrite a row.
-- blocks: block id -> {[revision]=content digest of the authored block}.
-- packs: composed pack id -> {[pack revision]={[block id]=pinned block revision}}.
-- Changing a block's content needs a new block revision row; changing a pack's pins
-- (including after a block bump) needs a new pack revision row. tests/builtin_composition.lua
-- enforces both, so a block change always reaches clones as a source revision change.
return {
 blocks={
  ['tbc.warrior.boundaries']={[1]='eea4d6001465ebfe'},
  ['tbc.warrior.upkeep']={[1]='127972407c820926'},
  ['tbc.warrior.dps-upkeep']={[1]='7318b1a5c8167b7e'},
  ['tbc.warrior.dps-opening']={[1]='5a998dc2df5a7fc6'},
  ['tbc.warrior.dps-leveling']={[1]='58f709d8b5ab9e71'},
  ['tbc.warrior.prot-core']={[1]='362800323e0abf81'},
  ['tbc.warrior.prot-upkeep']={[1]='12a87bf95b32da69'},
  ['tbc.warrior.sunder']={[1]='42f594925119424b'},
  ['tbc.rogue.opening']={[1]='cce1f30c31693654'},
  ['tbc.rogue.upkeep']={[1]='5144efe25d4c4be0'},
  ['tbc.rogue.builders']={[1]='a3669465c8ec53a6'},
  ['tbc.hunter.opening']={[1]='abd13971901341d6'},
  ['tbc.hunter.leveling']={[1]='0d9d6bab9e7caf90'},
  ['tbc.hunter.upkeep']={[1]='a740b08e7feed8db'},
 },
 packs={
  ['rm.tbc.warrior.dps.wowsims']={[1]={['tbc.warrior.boundaries']=1,['tbc.warrior.upkeep']=1,['tbc.warrior.dps-upkeep']=1,['tbc.warrior.dps-opening']=1,['tbc.warrior.dps-leveling']=1,['tbc.warrior.sunder']=1}},
  ['rm.tbc.warrior.dps.icyveins']={[1]={['tbc.warrior.boundaries']=1,['tbc.warrior.upkeep']=1,['tbc.warrior.dps-upkeep']=1,['tbc.warrior.dps-opening']=1,['tbc.warrior.dps-leveling']=1}},
  ['rm.tbc.warrior.protection.wowhead']={[1]={['tbc.warrior.boundaries']=1,['tbc.warrior.upkeep']=1,['tbc.warrior.prot-upkeep']=1,['tbc.warrior.prot-core']=1,['tbc.warrior.sunder']=1}},
  ['rm.tbc.warrior.protection.icyveins']={[1]={['tbc.warrior.boundaries']=1,['tbc.warrior.upkeep']=1,['tbc.warrior.prot-upkeep']=1,['tbc.warrior.prot-core']=1,['tbc.warrior.sunder']=1}},
  ['rm.tbc.rogue.dps.wowsims']={[1]={['tbc.rogue.opening']=1,['tbc.rogue.upkeep']=1,['tbc.rogue.builders']=1}},
  ['rm.tbc.hunter.ranged.wowsims']={[1]={['tbc.hunter.opening']=1,['tbc.hunter.leveling']=1,['tbc.hunter.upkeep']=1}},
  ['rm.tbc.rogue.dps.wowhead']={[1]={['tbc.rogue.opening']=1,['tbc.rogue.upkeep']=1,['tbc.rogue.builders']=1}},
  ['rm.tbc.hunter.ranged.wowhead']={[1]={['tbc.hunter.opening']=1,['tbc.hunter.leveling']=1,['tbc.hunter.upkeep']=1}},
 },
}
