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
 },
 packs={
  ['rm.tbc.rogue.starter.30-39']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
  ['rm.tbc.rogue.starter.40-49']={[1]={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1}},
 },
}
