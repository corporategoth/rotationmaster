-- Season of Discovery Priest damage, levels 1–60 (Phase 8 runes); the default Priest premade on a
-- Season of Discovery realm whenever the healer premade does not apply. Runes count only while
-- engraved. Shadowform; Vampiric Touch pre-cast; Void Plague, Shadow Word: Pain and Vampiric Touch
-- kept up (refreshed under 1.5 s, which Pain and Suffering rarely needs); Mind Blast on cooldown
-- (wowsims Phase 8); Mind Flay on Melting Faces and as the filler with the Phase 8 six-piece,
-- otherwise Mind Spike (Icy Veins, Wowhead, Warcraft Tavern); Void Zone and Mind Sear on four or
-- more enemies; Penance, Holy Fire and Smite before Shadowform. Thresholds are RM policy.
-- Variant: rm.sod.priest.dps.wowhead (Mind Blast at three Mind Spike stacks).
local _,addon=...
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-sod-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.priest.dps',revision=6,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull-shield']=1,['era.priest.wand-finish']=2,
  ['era.priest.wand-fallback']=2,['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1,['sod.priest.upkeep']=2,['sod.priest.pull']=3,['sod.priest.aoe']=1,
  ['sod.priest.moving']=2,['sod.priest.dots']=2,['sod.priest.procs']=1,['sod.priest.filler']=1},
 nameKey='Default.SoD.Priest.Dps.Name',descriptionKey='Default.SoD.Priest.Dps.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST',rulesets={'season:2'}},
 tags={'shadow','damage','leveling','raid','single-target','aoe','season-of-discovery','wowsims','icy-veins'},
 sources={
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/shadow_priest/builds/phase_8.build.json',title='wowsims/sod Shadow Priest Phase 8 build',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.icy-veins.com/wow-classic/shadow-priest-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Shadow Priest rotation',reviewedAt='2026-10-23',revision='2025-04-08',notes='Text describes Phase 4.'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/priest/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Priest DPS rotation',reviewedAt='2026-10-23',revision='2025-02-01',notes='Phase 7 text; AoE and cooldowns only.'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/priest/dps-leveling-tips',title='Wowhead: SoD Priest DPS leveling',reviewedAt='2026-10-23',revision='2025-02-01'},
 },
 body={
  priority=110,
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'dps-upkeep','era.priest.dps-upkeep',P),block(P..'sod-upkeep','sod.priest.upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   block(P..'pull','sod.priest.pull',P),
   block(P..'aoe','sod.priest.aoe',P),
   block(P..'moving','sod.priest.moving',P),
   block(P..'finish','era.priest.wand-finish',P),
   block(P..'dots','sod.priest.dots',P),
   spell(P..'blast',8092),
   block(P..'procs','sod.priest.procs',P),
   -- The Phase 8 six-piece (Raiments of Revelation) ramps Mind Flay per tick: it replaces Mind Spike.
   spell(P..'set-flay',15407,{type='SET_PIECES',set=1938,operator='GREATERTHANOREQUALS',value=6}),
   block(P..'filler','sod.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
