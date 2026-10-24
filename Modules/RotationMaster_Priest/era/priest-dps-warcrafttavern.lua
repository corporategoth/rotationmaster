-- Classic Era Priest damage after Warcraft Tavern's wand economy, levels 1–60; same switch as
-- rm.era.priest.dps at a lower priority, for players who pick it. Solo: Mind Blast opens, Shadow
-- Word: Pain once per target, Mind Blast again only above 30% target health, and the wand between
-- Mind Blasts instead of Smite or Mind Flay; no automatic shield before pulls (Tavern shields
-- every other mob, which stays with you). In a group: Tavern's Shadow raid order, Pain, Mind
-- Blast, Mind Flay.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='priest-wct-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.dps.warcrafttavern',revision=3,
 blocks={['era.priest.dps-boundaries']=1,['era.priest.shadowform']=1,['era.priest.moving']=1,
  ['era.priest.filler']=1,['era.priest.wand-fallback']=1,['era.priest.upkeep']=1,['era.priest.dps-upkeep']=1},
 nameKey='Default.Era.Priest.Dps.WarcraftTavern.Name',descriptionKey='Default.Era.Priest.Dps.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','leveling','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/priest-leveling-guide/',title='Warcraft Tavern: Classic Priest leveling',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/shadow-priest-pve/',title='Warcraft Tavern: Classic Shadow Priest PvE',reviewedAt='2026-10-23'},
 },
 body={
  priority=5,
  switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),block(P..'dps-upkeep','era.priest.dps-upkeep',P)},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-blast',8092),spell(P..'pull-smite',585),stop(P..'pull-stop')}},
   block(P..'moving','era.priest.moving',P),
   spell(P..'pain',589,negate(own(589))),
   spell(P..'blast',8092,any({type='GROUP'},{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3})),
   {id=P..'solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    stop(P..'solo-wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell(P..'solo-shoot',5019)}},
   block(P..'filler','era.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
