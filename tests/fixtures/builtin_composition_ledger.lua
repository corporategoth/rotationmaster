-- Append-only record of shipped Built In composition revisions; never rewrite a row.
-- blocks: block id -> {[revision]=content digest of the authored block}.
-- packs: composed pack id -> {[pack revision]={[block id]=pinned block revision}}.
-- Changing a block's content needs a new block revision row; changing a pack's pins
-- (including after a block bump) needs a new pack revision row. tests/builtin_composition.lua
-- enforces both, so a block change always reaches clones as a source revision change.
return {
 blocks={
  ['tbc.rogue.preserve-manual']={[1]='ffb36f5d46851c34'},
  ['tbc.rogue.melee-priority']={[1]='63c86d4335189586'},
  -- TBC Shaman, Druid and Paladin premades
  ['tbc.shaman.boundaries']={[1]='5ed2e2dd2d8dad16'},
  ['tbc.shaman.interrupt']={[1]='ff766efbac9d70c6'},
  ['tbc.shaman.shield']={[1]='28aeb1c87626b84e'},
  ['tbc.shaman.mainhand-imbue']={[1]='3a184e977ea8b8e2'},
  ['tbc.shaman.bloodlust']={[1]='6620bac3ecf13e1c'},
  ['tbc.shaman.enhancement-upkeep']={[1]='a46e9fbfa6688242'},
  ['tbc.shaman.enhancement-opening']={[1]='ef9f2508aad735e0'},
  ['tbc.shaman.elemental-opening']={[1]='00fd61f068546a2f'},
  ['tbc.shaman.elemental-aoe']={[1]='0ba1706d726b0521'},
  ['tbc.shaman.elemental-totems']={[1]='a7a685e6d2a57686'},
  ['tbc.paladin.boundaries']={[1]='3e92c13beff13b94'},
  ['tbc.paladin.melee-opening']={[1]='7e372129471a51a4'},
  ['tbc.paladin.ret-upkeep']={[1]='d4cb00c3f141e2f3'},
  ['tbc.paladin.tank-upkeep']={[1]='b8133eae06b4be6d'},
  ['tbc.paladin.holy-upkeep']={[1]='bd2d1781c54da357'},
  ['tbc.paladin.holy-hostile']={[1]='741093e892f5ce0b'},
  ['tbc.paladin.holy-emergency']={[1]='1b3a3746b927e7f1'},
  ['tbc.druid.boundaries']={[1]='8256c2869b5cb30f'},
  ['tbc.druid.feral-form-stop']={[1]='8579bb1148ed7c7d'},
  ['tbc.druid.upkeep']={[1]='7e40db1491670caa'},
  ['tbc.druid.cat-builders']={[1]='b5ad60829c2da375'},
  ['tbc.druid.cat-opening']={[1]='5bd57e970926f6b0'},
  ['tbc.druid.bear-core']={[1]='cd262ae6516d9594'},
  ['tbc.druid.feral-cooldowns']={[1]='e7c52cd35f3cf761'},
  ['tbc.druid.feral-humanoid']={[1]='043b7ed64c866c26'},
 },
 packs={
  ['rm.tbc.rogue.starter.30-39']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
  ['rm.tbc.rogue.starter.40-49']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
  -- TBC Shaman, Druid and Paladin premades
  ['rm.tbc.shaman.enhancement.icyveins']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.enhancement-opening']=1,['tbc.shaman.enhancement-upkeep']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1}},
  ['rm.tbc.shaman.enhancement.wowsims']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.enhancement-opening']=1,['tbc.shaman.enhancement-upkeep']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1}},
  ['rm.tbc.shaman.elemental.icyveins']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.elemental-aoe']=1,['tbc.shaman.elemental-opening']=1,['tbc.shaman.elemental-totems']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1}},
  ['rm.tbc.shaman.elemental.wowhead']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.elemental-aoe']=1,['tbc.shaman.elemental-opening']=1,['tbc.shaman.elemental-totems']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1}},
  ['rm.tbc.shaman.elemental.nextaction']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.elemental-opening']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.mainhand-imbue']=1}},
  ['rm.tbc.shaman.restoration']={[1]={['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.interrupt']=1,['tbc.shaman.shield']=1}},
  ['rm.tbc.paladin.retribution.wowhead']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.ret-upkeep']=1}},
  ['rm.tbc.paladin.retribution.icyveins']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.ret-upkeep']=1}},
  ['rm.tbc.paladin.retribution.twist']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.ret-upkeep']=1}},
  ['rm.tbc.paladin.protection.wowhead']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.tank-upkeep']=1}},
  ['rm.tbc.paladin.protection.icyveins']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.tank-upkeep']=1}},
  ['rm.tbc.paladin.holy']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.holy-emergency']=1,['tbc.paladin.holy-hostile']=1,['tbc.paladin.holy-upkeep']=1}},
  ['rm.tbc.paladin.holy.wowhead']={[1]={['tbc.paladin.boundaries']=1,['tbc.paladin.holy-emergency']=1,['tbc.paladin.holy-hostile']=1,['tbc.paladin.holy-upkeep']=1}},
  ['rm.tbc.druid.balance']={[1]={['tbc.druid.boundaries']=1,['tbc.druid.feral-form-stop']=1,['tbc.druid.upkeep']=1}},
  ['rm.tbc.druid.feral.icyveins']={[1]={['tbc.druid.bear-core']=1,['tbc.druid.boundaries']=1,['tbc.druid.cat-builders']=1,['tbc.druid.cat-opening']=1,['tbc.druid.feral-cooldowns']=1,['tbc.druid.feral-humanoid']=1,['tbc.druid.upkeep']=1}},
  ['rm.tbc.druid.feral.wowhead']={[1]={['tbc.druid.bear-core']=1,['tbc.druid.boundaries']=1,['tbc.druid.cat-builders']=1,['tbc.druid.cat-opening']=1,['tbc.druid.feral-cooldowns']=1,['tbc.druid.feral-humanoid']=1,['tbc.druid.upkeep']=1}},
  ['rm.tbc.druid.restoration']={[1]={['tbc.druid.boundaries']=1,['tbc.druid.feral-form-stop']=1,['tbc.druid.upkeep']=1}},
 },
}
