-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Priest damage, levels 1–60; the default Priest premade whenever the healer premade
-- does not apply (solo, Shadow, or no talents yet). Smite and the wand early, Holy Fire opener for
-- builds without Shadowform, Mind Flay and Shadowform as talented; Shadow Word: Pain once per
-- target, Mind Blast on cooldown, the wand on a dying solo target or a low mana pool (Icy Veins
-- leveling and raid, Wowhead, Warcraft Tavern, simulator agree on this core). Vampiric Embrace and
-- Devouring Plague stay out of raids (debuff slots). Thresholds are RM policy.
-- Variants: rm.era.priest.dps.warcrafttavern (wand economy), rm.era.priest.dps.simulator (Undead raid).
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
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.dps',revision=5,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull']=3,['era.priest.pull-shield']=1,
  ['era.priest.moving']=2,['era.priest.wand-finish']=2,['era.priest.pain']=1,['era.priest.filler']=2,['era.priest.wand-fallback']=2,
  ['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1},
 nameKey="Damage",descriptionKey="Damage from level 1 to 60, and the Priest default whenever the healer premade does not apply (solo, Shadow, or no talents yet). Shadowform when learned; before a pull a shield when solo, then Holy Fire (without Shadowform), Mind Blast or Smite. Shadow Word: Pain once per target that will live, Mind Blast on cooldown, Mind Flay as the filler (Smite and Holy Nova before you have it), and the wand on a dying target or when your mana runs low while solo. Vampiric Embrace and Devouring Plague on long fights, never in raids. Reminders: Inner Fire, Fortitude, racial buffs, Inner Focus with Mind Blast, Psychic Scream when two enemies reach you at half health, Fade when your target turns on you, Desperate Prayer. Target choice, multi-dotting and downranking stay with you.",
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','leveling','raid','single-target','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/shadow-priest-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Shadow Priest rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/shadow-priest-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/discipline-priest-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Discipline Priest leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/priest/shadow/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Shadow Priest rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.wowhead.com/classic/guide/classes/priest/hardcore-leveling-tips',title='Wowhead: Hardcore Priest leveling',reviewedAt='2026-10-23',revision='2024-11-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/shadow-priest-pve/',title='Warcraft Tavern: Classic Shadow Priest PvE',reviewedAt='2026-10-23'},

 },
 body={
  priority=10,
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
