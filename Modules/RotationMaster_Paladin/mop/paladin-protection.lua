-- Mists of Pandaria Classic Protection Paladin, levels 10–90, in the Protection specialization (66).
-- Icy Veins' order with Hekili's thresholds. Shield of the Righteous, Eternal Flame and Word of Glory
-- are off the global cooldown, so they are reminders beside the rotation: Shield of the Righteous
-- whenever it is usable (3 Holy Power), Eternal Flame on yourself when it is running out with three
-- Bastion of Glory stacks and 3 Holy Power. Rotation: Grand Crusader Avenger's Shield, AoE at three
-- enemies, Avenger's Shield, Hammer of Wrath, Crusader Strike, Judgment, tier-six talent,
-- Consecration, Holy Wrath. The pool-to-five variant is rm.mop.paladin.protection.wowsims.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local tanking={type='THREAT',unit='target',threat=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.protection',revision=4,
 blocks={['mop.paladin.damage-boundaries']=1,['mop.paladin.upkeep']=1,['mop.paladin.seal-insight']=2,['mop.paladin.prot-upkeep']=1,['mop.paladin.prot-open']=3,['mop.paladin.prot-aoe']=1},
 nameKey='Default.MoP.Paladin.Protection.Name',descriptionKey='Default.MoP.Paladin.Protection.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'protection','tank','leveling','single-target','aoe','icy-veins','hekili'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-paladin-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Protection Paladin rotation',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-paladin-leveling',title='Icy Veins: MoP Classic Protection Paladin leveling',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://github.com/Smufrik/Hekili/blob/main/MistsOfPandaria/Priorities/PaladinProtection.simc',title='Hekili MoP Classic: Protection priority',reviewedAt='2026-10-23',revision='1ebafc17',notes='Shield of the Righteous at 3 Holy Power, Word of Glory under 70%, AoE at 3+.'},
  {url='https://www.method.gg/mop-classic/protection-paladin-class-guide-mop-classic',title='Method: MoP Classic Protection Paladin guide',reviewedAt='2026-10-23',revision='2025-07-23',notes='Righteous Fury; wings and Holy Avenger on cooldown.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=66}}},
  cooldowns={
   block('prot-upkeep','mop.paladin.prot-upkeep','prot-'),
   block('prot-class','mop.paladin.upkeep','prot-'),
   spell('prot-shield-righteous',53600,combat()),
   spell('prot-eternal-flame',114163,all(any(negate(own(114163)),{type='BUFF_REMAIN',unit='player',spell=114163,ownbuff=true,operator='LESSTHAN',value=3}),
    {type='BUFF_STACKS',unit='player',spell=114637,operator='GREATERTHANOREQUALS',value=3},any({type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3},buff(90174)))),
   spell('prot-word-of-glory',85673,all(negate(known(114163)),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
   spell('prot-sacred-shield',20925,any(negate(own(65148)),{type='BUFF_REMAIN',unit='player',spell=65148,ownbuff=true,operator='LESSTHAN',value=5})),
   spell('prot-avenging-wrath',31884,all(combat(),tanking)),
   spell('prot-holy-avenger',105809,all(combat(),tanking)),
  },
  rotation={
   block('prot-boundaries','mop.paladin.damage-boundaries','prot-'),
   block('prot-open','mop.paladin.prot-open','prot-'),
   spell('prot-grand-crusader',31935,buff(85416)),
   block('prot-aoe','mop.paladin.prot-aoe','prot-'),
   spell('prot-avengers-shield',31935),
   spell('prot-hammer-wrath',24275),
   spell('prot-crusader-strike',35395),
   spell('prot-judgment',20271),
   spell('prot-execution-sentence',114157),
   spell('prot-lights-hammer',114158),
   spell('prot-holy-prism',114165),
   spell('prot-consecration',26573),
   spell('prot-holy-wrath',119072),
   spell('prot-sacred-shield-filler',20925),
  },
 },
}))
