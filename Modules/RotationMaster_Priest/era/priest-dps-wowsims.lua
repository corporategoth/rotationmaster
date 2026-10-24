-- Classic Era Priest damage after wowsims' Shadow APL, levels 1–60; same switch as
-- rm.era.priest.dps at a lower priority, for raid groups with spare debuff slots. Differs from the
-- default by spending Inner Focus on Devouring Plague (Undead) instead of Mind Blast and casting
-- Devouring Plague in raids too; no Vampiric Embrace. Leveling steps match the default.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local combat={type='COMBAT',unit='player'}
local P='priest-sim-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.priest.dps.wowsims',revision=5,
 blocks={['era.priest.dps-boundaries']=2,['era.priest.shadowform']=1,['era.priest.pull']=3,['era.priest.pull-shield']=1,
  ['era.priest.moving']=2,['era.priest.wand-finish']=2,['era.priest.pain']=1,['era.priest.filler']=2,['era.priest.wand-fallback']=2,
  ['era.priest.upkeep']=1},
 nameKey='Default.Era.Priest.Dps.Wowsims.Name',descriptionKey='Default.Era.Priest.Dps.Wowsims.Description',
 applicability={families={'era'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','raid','single-target','wowsims'},
 sources={
  {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/shadow_priest/apls/p1.apl.json',title='wowsims/classic Shadow Priest P1 APL',reviewedAt='2026-10-23',revision='7779ebb'},
 },
 body={
  priority=4,disabled=true,
  switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block(P..'upkeep','era.priest.upkeep',P),
   -- Inner Focus goes on Devouring Plague; without the racial, on Mind Blast as usual.
   spell(P..'inner-focus',14751,all(combat,any(all(known(2944),{type='SPELL_COOLDOWN',spell=2944,operator='LESSTHANOREQUALS',value=1.5},negate(own(2944))),
    all(negate(known(2944)),{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})))),
   spell(P..'scream',8122,all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}))},
  rotation={
   block(P..'boundaries','era.priest.dps-boundaries',P),
   block(P..'form','era.priest.shadowform',P),
   block(P..'pull','era.priest.pull',P),
   block(P..'moving','era.priest.moving',P),
   block(P..'finish','era.priest.wand-finish',P),
   block(P..'pain','era.priest.pain',P),
   -- Devouring Plague right after Inner Focus (or when Inner Focus is not ready or not learned).
   spell(P..'plague',2944,all(negate(own(2944)),any({type='BUFF',unit='player',spell=14751},negate(known(14751)),{type='SPELL_COOLDOWN',spell=14751,operator='GREATERTHAN',value=1.5}))),
   spell(P..'blast',8092,any({type='GROUP'},{type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3})),
   block(P..'filler','era.priest.filler',P),
   block(P..'wand','era.priest.wand-fallback',P),
  },
 },
}))
