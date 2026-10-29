-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Priest damage after Wowhead (Phase 7) and Warcraft Tavern (Phase 4), levels
-- 1–60; same switch as rm.sod.priest.dps at a lower priority, for players who pick it. Differs by
-- holding Mind Blast for three of your Mind Spike stacks (cast normally until Mind Spike is
-- engraved), Mind Flay only on Melting Faces, and Mind Spike as the filler regardless of set.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-sod-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.dps.wowhead',revision=7,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull-shield']=1,['era.priest.wand-finish']=2,
  ['era.priest.wand-fallback']=2,['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1,['sod.priest.upkeep']=2,['sod.priest.pull']=3,['sod.priest.aoe']=1,
  ['sod.priest.moving']=2,['sod.priest.dots']=2,['sod.priest.procs']=1,['sod.priest.filler']=1},
 nameKey="Damage (SoD, Wowhead Mind Spike stacks)",descriptionKey="The Wowhead and Warcraft Tavern way for Season of Discovery, an alternative to the recommended Season of Discovery damage premade, off by default: enable it and disable that one, or raise its priority. Mind Blast waits for three of your Mind Spike stacks on the target (it is cast normally until you engrave Mind Spike), Mind Flay only on Melting Faces, Mind Spike as the filler. Everything else matches the recommended premade.",
 applicability={families={'era'},actionContext='player',class='PRIEST',rulesets={'season:2'}},
 tags={'shadow','damage','raid','single-target','aoe','season-of-discovery','wowhead','warcraft-tavern'},
 sources={
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/priest/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Priest DPS rotation',reviewedAt='2026-10-23',revision='2025-02-01',notes='Phase 7 text.'},
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/shadow-priest-dps/',title='Warcraft Tavern: SoD Shadow Priest',reviewedAt='2026-10-23',notes='Phase 4 text.'},
 },
 body={
  priority=105,disabled=true,
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'dps-upkeep','era.priest.dps-upkeep',P),block(P..'sod-upkeep','sod.priest.upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   block(P..'pull','sod.priest.pull',P),
   block(P..'aoe','sod.priest.aoe',P),
   block(P..'moving','sod.priest.moving',P),
   block(P..'finish','era.priest.wand-finish',P),
   block(P..'dots','sod.priest.dots',P),
   spell(P..'blast',8092,any(negate({type='RUNE_ENGRAVED',spell=431655}),
    {type='DEBUFF_STACKS',unit='target',spell=431655,owndebuff=true,operator='GREATERTHANOREQUALS',value=3})),
   block(P..'procs','sod.priest.procs',P),
   block(P..'filler','sod.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
