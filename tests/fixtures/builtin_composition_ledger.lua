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
  -- WoW Forever Rogue, Shaman, Warlock and Warrior premades.
  ['forever.rogue.boundaries']={[1]='f237ede1d587c539'},
  ['forever.rogue.stealth-fallback']={[1]='798fc3da0df0873f'},
  ['forever.rogue.reactive']={[1]='9f7fe5095deb2956'},
  ['forever.rogue.expose-armor']={[1]='bf9a7d5187dc5dc7'},
  ['forever.rogue.upkeep']={[1]='d41af43d26d5e51f'},
  ['forever.shaman.manual']={[1]='8122264660ce83b1'},
  ['forever.shaman.upkeep']={[1]='4dcb30b2b9c424d7'},
  ['forever.shaman.imbue']={[1]='bbcbd8f15dac1042'},
  ['forever.shaman.group-totems']={[1]='4b7263f5b8182cea'},
  ['forever.shaman.caster-aoe']={[1]='d37526a54bf26e6b'},
  ['forever.shaman.stormstrike-hybrid']={[1]='76fd946f2b71b272'},
  ['forever.warlock.boundaries']={[1]='a3435b09e5cd562f'},
  ['forever.warlock.upkeep']={[1]='9ba66b913958ee9d'},
  ['forever.warlock.procs']={[1]='26995d1327323097'},
  ['forever.warlock.execute']={[1]='ff4ed8e8235b697c'},
  ['forever.warlock.moving']={[1]='b9a086402bef054f'},
  ['forever.warlock.aoe']={[1]='aee8b3a6646e2c08'},
  ['forever.warlock.wand']={[1]='320af0000818a633'},
  ['forever.warrior.boundaries']={[1]='69ee604e75a8de0b'},
  ['forever.warrior.upkeep']={[1]='0a429c49084b3a07'},
 },
 packs={
  ['rm.tbc.rogue.starter.30-39']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
  ['rm.tbc.rogue.starter.40-49']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
  -- WoW Forever Rogue, Shaman, Warlock and Warrior premades.
  ['rm.forever.rogue.dps']={[1]={['forever.rogue.boundaries']=1,['forever.rogue.expose-armor']=1,['forever.rogue.reactive']=1,['forever.rogue.stealth-fallback']=1,['forever.rogue.upkeep']=1}},
  ['rm.forever.rogue.subtlety.warcrafttavern']={[1]={['forever.rogue.boundaries']=1,['forever.rogue.expose-armor']=1,['forever.rogue.reactive']=1,['forever.rogue.stealth-fallback']=1,['forever.rogue.upkeep']=1}},
  ['rm.forever.rogue.subtlety.wowhead']={[1]={['forever.rogue.boundaries']=1,['forever.rogue.expose-armor']=1,['forever.rogue.stealth-fallback']=1,['forever.rogue.upkeep']=1}},
  ['rm.forever.shaman.restoration']={[1]={['forever.shaman.caster-aoe']=1,['forever.shaman.group-totems']=1,['forever.shaman.manual']=1,['forever.shaman.stormstrike-hybrid']=1,['forever.shaman.upkeep']=1}},
  ['rm.forever.shaman.elemental']={[1]={['forever.shaman.caster-aoe']=1,['forever.shaman.group-totems']=1,['forever.shaman.imbue']=1,['forever.shaman.manual']=1,['forever.shaman.stormstrike-hybrid']=1,['forever.shaman.upkeep']=1}},
  ['rm.forever.shaman.enhancement']={[1]={['forever.shaman.group-totems']=1,['forever.shaman.imbue']=1,['forever.shaman.manual']=1,['forever.shaman.upkeep']=1}},
  ['rm.forever.shaman.enhancement.wowhead']={[1]={['forever.shaman.imbue']=1,['forever.shaman.manual']=1,['forever.shaman.upkeep']=1}},
  ['rm.forever.warlock.dps']={[1]={['forever.warlock.aoe']=1,['forever.warlock.boundaries']=1,['forever.warlock.execute']=1,['forever.warlock.moving']=1,['forever.warlock.procs']=1,['forever.warlock.upkeep']=1,['forever.warlock.wand']=1}},
  ['rm.forever.warlock.dps.icyveins']={[1]={['forever.warlock.aoe']=1,['forever.warlock.boundaries']=1,['forever.warlock.execute']=1,['forever.warlock.moving']=1,['forever.warlock.procs']=1,['forever.warlock.upkeep']=1,['forever.warlock.wand']=1}},
  ['rm.forever.warlock.dps.wowhead']={[1]={['forever.warlock.boundaries']=1,['forever.warlock.execute']=1,['forever.warlock.moving']=1,['forever.warlock.procs']=1,['forever.warlock.upkeep']=1,['forever.warlock.wand']=1}},
  ['rm.forever.warrior.protection']={[1]={['forever.warrior.boundaries']=1,['forever.warrior.upkeep']=1}},
  ['rm.forever.warrior.protection.warcrafttavern']={[1]={['forever.warrior.boundaries']=1,['forever.warrior.upkeep']=1}},
  ['rm.forever.warrior.dps']={[1]={['forever.warrior.boundaries']=1,['forever.warrior.upkeep']=1}},
  ['rm.forever.warrior.dps.warcrafttavern']={[1]={['forever.warrior.boundaries']=1,['forever.warrior.upkeep']=1}},
 },
}
