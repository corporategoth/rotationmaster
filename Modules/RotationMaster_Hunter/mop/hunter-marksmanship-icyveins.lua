-- Mists of Pandaria Classic Marksmanship Hunter, "Arcane dump" family (Icy Veins, Method,
-- wowtbc.gg, Hekili): Aimed Shot is hard-cast only above 80% target health or under Rapid Fire or
-- Bloodlust; spare focus goes to Arcane Shot at 60. Steady Focus refreshed under 4 s. Same switch
-- as rm.mop.hunter.marksmanship, lower priority and disabled: no switch can tell the two apart, so
-- the player chooses.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local moving={type='MOVING'}
local fire=buff(82926)
local focusLow=all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=63},any(negate(buff(53220)),{type='BUFF_REMAIN',unit='player',spell=53220,operator='LESSTHAN',value=4}))
local lust=any(buff(2825),buff(32182),buff(80353),buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.marksmanship.icyveins',revision=1,
 blocks={['mop.hunter.boundaries']=1,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1},
 nameKey='Default.MoP.Hunter.Marksmanship.IcyVeins.Name',descriptionKey='Default.MoP.Hunter.Marksmanship.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER',minLevel=10,maxLevel=90},
 tags={'marksmanship','leveling','single-target','aoe','icy-veins','hekili'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/marksmanship-hunter-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Marksmanship Hunter rotation',reviewedAt='2026-10-23',revision='2026-05-29'},
  {url='https://www.method.gg/mop-classic/marksmanship-hunter-class-guide-mop-classic',title='Method: MoP Classic Marksmanship Hunter guide',reviewedAt='2026-10-23',notes='Aimed Shot during cooldowns and above 80%, Arcane Shot otherwise.'},
  {url='https://wowtbc.gg/mop/class-guides/marksmanship-hunter/',title='wowtbc.gg: MoP Marksmanship Hunter guide',reviewedAt='2026-10-23'},
  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/HunterMarksmanship.simc',title='Hekili MoP Classic Marksmanship priority',reviewedAt='2026-10-23',revision='0750b5dd98',notes='Arcane Shot at 60 focus outside haste.'},
 },
 body={priority=5,disabled=true,switch={type='SPELL_KNOWN',spell=19434},
  cooldowns={
   block('mmiv-pet','mop.hunter.pet','mmiv-'),
   block('mmiv-aspect','mop.hunter.aspect','mmiv-'),
   block('mmiv-utility','mop.hunter.utility','mmiv-'),
   block('mmiv-burst','mop.hunter.burst','mmiv-'),
  },
  rotation={
   block('mmiv-boundaries','mop.hunter.boundaries','mmiv-'),
   {id='mmiv-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    block('mmiv-pull-mark','mop.hunter.mark','mmiv-pull-'),
    spell('mmiv-pull-aimed',19434,negate(moving)),
    stop('mmiv-pull-stop')}},
   spell('mmiv-steady-pair',56641,all({type='SPELL_HISTORY',spell=56641,operator='EQUALS',value=1},focusLow)),
   {id='mmiv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onFalse={},onTrue={
    spell('mmiv-aoe-multi-shot',2643),
    spell('mmiv-aoe-fire',19434,fire),
    spell('mmiv-aoe-kill-shot',53351),
    block('mmiv-aoe-talents','mop.hunter.talents','mmiv-aoe-'),
    block('mmiv-aoe-shots','mop.hunter.talent-shots','mmiv-aoe-'),
    spell('mmiv-aoe-explosive-trap',13813),
    spell('mmiv-aoe-steady',56641),
    stop('mmiv-aoe-wait')}},
   block('mmiv-serpent','mop.hunter.serpent','mmiv-'),
   spell('mmiv-chimera',53209),
   spell('mmiv-fire',19434,fire),
   spell('mmiv-kill-shot',53351),
   block('mmiv-talents','mop.hunter.talents','mmiv-'),
   block('mmiv-shots','mop.hunter.talent-shots','mmiv-'),
   spell('mmiv-steady-start',56641,focusLow),
   spell('mmiv-aimed',19434,all(negate(moving),any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.8},buff(3045),lust))),
   spell('mmiv-arcane',3044,any(focus('GREATERTHANOREQUALS',60),buff(34720))),
   spell('mmiv-steady',56641),
   stop('mmiv-wait'),
  },
 },
}))
