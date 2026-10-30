-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Priest damage, levels 1–60 (Phase 8 runes); the default Priest premade on a
-- Season of Discovery realm whenever the healer premade does not apply. Runes count only while
-- engraved. Shadowform; Vampiric Touch pre-cast; Void Plague, Shadow Word: Pain and Vampiric Touch
-- kept up (refreshed under 1.5 s, which Pain and Suffering rarely needs); Mind Blast on cooldown
-- (simulator Phase 8); Mind Flay on Melting Faces and as the filler with the Phase 8 six-piece,
-- otherwise Mind Spike (Icy Veins, Wowhead, Warcraft Tavern); Void Zone and Mind Sear on four or
-- more enemies; Penance, Holy Fire and Smite before Shadowform. Thresholds are RM policy.
-- Variant: rm.sod.priest.dps.wowhead (Mind Blast at three Mind Spike stacks).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local P='priest-sod-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.dps',revision=6,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull-shield']=1,['era.priest.wand-finish']=2,
  ['era.priest.wand-fallback']=2,['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1,['sod.priest.upkeep']=2,['sod.priest.pull']=3,['sod.priest.aoe']=1,
  ['sod.priest.moving']=2,['sod.priest.dots']=2,['sod.priest.procs']=1,['sod.priest.filler']=1},
 applicability={families={'era'},actionContext='player',class='PRIEST',rulesets={'season:2'}},
 tags={'shadow','damage','leveling','raid','single-target','aoe','season-of-discovery','icy-veins'},
 sources={

  {url='https://www.icy-veins.com/wow-classic/shadow-priest-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Shadow Priest rotation',reviewedAt='2026-10-23',revision='2025-04-08',notes='Text describes Phase 4.'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/priest/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Priest DPS rotation',reviewedAt='2026-10-23',revision='2025-02-01',notes='Phase 7 text; AoE and cooldowns only.'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/priest/dps-leveling-tips',title='Wowhead: SoD Priest DPS leveling',reviewedAt='2026-10-23',revision='2025-02-01'},
 },
 body={
  priority=110,
  cooldowns={BuiltinConditions.block(P..'upkeep','era.priest.upkeep',P),BuiltinConditions.block(P..'dps-upkeep','era.priest.dps-upkeep',P),BuiltinConditions.block(P..'sod-upkeep','sod.priest.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.priest.dps-boundaries',P),
   BuiltinConditions.block(P..'form','era.priest.shadowform',P),
   BuiltinConditions.block(P..'pull','sod.priest.pull',P),
   BuiltinConditions.block(P..'aoe','sod.priest.aoe',P),
   BuiltinConditions.block(P..'moving','sod.priest.moving',P),
   BuiltinConditions.block(P..'finish','era.priest.wand-finish',P),
   BuiltinConditions.block(P..'dots','sod.priest.dots',P),
   BuiltinConditions.spell(P..'blast',8092),
   BuiltinConditions.block(P..'procs','sod.priest.procs',P),
   -- The Phase 8 six-piece (Raiments of Revelation) ramps Mind Flay per tick: it replaces Mind Spike.
   BuiltinConditions.spell(P..'set-flay',15407,{type='SET_PIECES',set=1938,operator='GREATERTHANOREQUALS',value=6}),
   BuiltinConditions.block(P..'filler','sod.priest.filler',P),
   BuiltinConditions.block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
