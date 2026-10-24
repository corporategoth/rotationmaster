-- Classic Era Priest damage, levels 1–60; the default Priest premade whenever the healer premade
-- does not apply (solo, Shadow, or no talents yet). Smite and the wand early, Holy Fire opener for
-- builds without Shadowform, Mind Flay and Shadowform as talented; Shadow Word: Pain once per
-- target, Mind Blast on cooldown, the wand on a dying solo target or a low mana pool (Icy Veins
-- leveling and raid, Wowhead, Warcraft Tavern, wowsims agree on this core). Vampiric Embrace and
-- Devouring Plague stay out of raids (debuff slots). Thresholds are RM policy.
-- Variants: rm.era.priest.dps.warcrafttavern (wand economy), rm.era.priest.dps.wowsims (Undead raid).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local raid={type='INSTANCE',value='raid'}
local P='priest-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.dps',revision=3,
 blocks={['era.priest.dps-boundaries']=1,['era.priest.shadowform']=1,['era.priest.pull']=2,['era.priest.pull-shield']=1,
  ['era.priest.moving']=1,['era.priest.wand-finish']=1,['era.priest.pain']=1,['era.priest.filler']=1,['era.priest.wand-fallback']=1,
  ['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1},
 nameKey='Default.Era.Priest.Dps.Name',descriptionKey='Default.Era.Priest.Dps.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','leveling','raid','single-target','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/shadow-priest-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Shadow Priest rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/shadow-priest-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/discipline-priest-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Discipline Priest leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/priest/shadow/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Shadow Priest rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.wowhead.com/classic/guide/classes/priest/hardcore-leveling-tips',title='Wowhead: Hardcore Priest leveling',reviewedAt='2026-10-23',revision='2024-11-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/shadow-priest-pve/',title='Warcraft Tavern: Classic Shadow Priest PvE',reviewedAt='2026-10-23'},
  {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/shadow_priest/apls/p1.apl.json',title='wowsims/classic Shadow Priest P1 APL',reviewedAt='2026-10-23',revision='7779ebb'},
 },
 body={
  priority=10,
  switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'dps-upkeep','era.priest.dps-upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   block(P..'pull','era.priest.pull',P),
   block(P..'moving','era.priest.moving',P),
   block(P..'finish','era.priest.wand-finish',P),
   -- Vampiric Embrace on long fights, or solo when your health is dropping; never in raids.
   spell(P..'embrace',15286,all(negate(raid),negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),any(
    all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7}),
    {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=60}))),
   block(P..'pain','era.priest.pain',P),
   spell(P..'plague',2944,all(negate(own(2944)),negate(raid),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
   spell(P..'blast',8092,any({type='GROUP'},{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3})),
   block(P..'filler','era.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
