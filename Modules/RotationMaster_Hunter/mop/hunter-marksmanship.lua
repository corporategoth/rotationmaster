-- Mists of Pandaria Classic Marksmanship Hunter, levels 10–90, in the Marksmanship
-- specialization (254). Wowhead's Phase 5 order with wowsims' rule for when to hard-cast
-- Aimed Shot: Steady Shots in pairs for Steady Focus (63), Chimera Shot, Serpent Sting, Aimed
-- Shot on Fire!, Kill Shot, talents, Aimed Shot above 80% health, under Rapid Fire or Bloodlust, at
-- 85 focus or while Chimera is away, Arcane Shot only while moving, Steady Shot. Four or more
-- enemies: Chimera, Fire!, Multi-Shot. The Arcane Shot dump variant is
-- rm.mop.hunter.marksmanship.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local moving={type='MOVING'}
local fire=buff(82926)
-- Steady Focus (63) missing or under 5 s; the passive's level stands in for knowing it.
local focusLow=all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=63},any(negate(buff(53220)),{type='BUFF_REMAIN',unit='player',spell=53220,operator='LESSTHAN',value=5}))
local lust=any(buff(2825),buff(32182),buff(80353),buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.marksmanship',revision=2,
 blocks={['mop.hunter.boundaries']=1,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1},
 nameKey='Default.MoP.Hunter.Marksmanship.Name',descriptionKey='Default.MoP.Hunter.Marksmanship.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER',minLevel=10,maxLevel=90},
 tags={'marksmanship','leveling','single-target','aoe','wowhead','wowsims'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/marksmanship/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Marksmanship Hunter rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/hunter/marksmanship/apls/mm.apl.json',title='wowsims/mop Marksmanship APL',reviewedAt='2026-10-23',revision='ec2c6c2552',notes='When to hard-cast Aimed Shot; Arcane Shot only at a cap.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-marksmanship-hunter-dps-rotations-cooldowns/',title='Warcraft Tavern: MoP Marksmanship Hunter rotation',reviewedAt='2026-10-23',notes='Arcane Shot when you cannot stand still.'},
 },
 body={priority=10,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=254}}},
  cooldowns={
   block('mm-pet','mop.hunter.pet','mm-'),
   block('mm-aspect','mop.hunter.aspect','mm-'),
   block('mm-utility','mop.hunter.utility','mm-'),
   block('mm-burst','mop.hunter.burst','mm-'),
  },
  rotation={
   block('mm-boundaries','mop.hunter.boundaries','mm-'),
   {id='mm-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    block('mm-pull-mark','mop.hunter.mark','mm-pull-'),
    spell('mm-pull-aimed',19434,negate(moving)),
    stop('mm-pull-stop')}},
   spell('mm-steady-pair',56641,all({type='SPELL_HISTORY',spell=56641,operator='EQUALS',value=1},focusLow)),
   {id='mm-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onFalse={},onTrue={
    spell('mm-aoe-chimera',53209,enemies('LESSTHAN',10)),
    spell('mm-aoe-fire',19434,fire),
    spell('mm-aoe-multi-shot',2643),
    spell('mm-aoe-kill-shot',53351),
    spell('mm-aoe-explosive-trap',13813),
    block('mm-aoe-shots','mop.hunter.talent-shots','mm-aoe-'),
    spell('mm-aoe-steady',56641),
    stop('mm-aoe-wait')}},
   spell('mm-chimera',53209),
   block('mm-serpent','mop.hunter.serpent','mm-'),
   spell('mm-fire',19434,fire),
   spell('mm-kill-shot',53351),
   block('mm-talents','mop.hunter.talents','mm-'),
   block('mm-shots','mop.hunter.talent-shots','mm-'),
   spell('mm-steady-start',56641,focusLow),
   spell('mm-aimed',19434,all(negate(moving),any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.8},buff(3045),lust,
    focus('GREATERTHANOREQUALS',85),negate(known(53209)),{type='SPELL_COOLDOWN',spell=53209,operator='GREATERTHANOREQUALS',value=3}))),
   spell('mm-arcane-moving',3044,all(moving,any(focus('GREATERTHANOREQUALS',60),buff(34720)))),
   spell('mm-steady',56641),
   stop('mm-wait'),
  },
 },
}))
