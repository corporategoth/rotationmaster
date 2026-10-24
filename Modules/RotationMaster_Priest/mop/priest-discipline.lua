-- Mists of Pandaria Classic Discipline Priest, levels 10-90: Icy Veins' single-target and Atonement lists joined
-- by your target, with Warcraft Tavern's shield triggers and Hekili's health thresholds. Selected in the Discipline
-- specialization (256). A friendly target is healed: under Spirit Shell Prayer of Healing (three hurt
-- allies) or Greater Heal; Power Word: Shield without Weakened Soul when low, before the pull or every 12 s for
-- Rapture; Flash Heal on Surge of Light; Penance; Flash Heal when very low; Binding Heal; Prayer of Mending;
-- Prayer of Healing; the tier-6 talent; Greater Heal; Renew while moving; Heal. An enemy target runs Atonement:
-- Penance, Solace or Holy Fire, the tier-6 talent on packs, Shadow Word: Pain solo, Smite. Choosing whom to heal,
-- Barrier, Void Shift and Grace stacks on the tank stay with you; Spirit Shell is a reminder you switch on.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function low(n)return health('target','LESSTHAN',n)end
local function hurt(n,below)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function lives(n)return any(health('target','GREATERTHANOREQUALS',.35),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=n})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friendly={type='FRIENDLY',unit='target'}
local group={type='GROUP'}
local unshielded=negate({type='DEBUFF',unit='target',spell=6788})
local tierSix=any(enemies('GREATERTHANOREQUALS',3),hurt(3,.85))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.discipline',revision=4,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2,['mop.priest.healer-cooldowns']=1},
 nameKey='Default.MoP.Priest.Discipline.Name',descriptionKey='Default.MoP.Priest.Discipline.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'discipline','healer','group','leveling','endgame','icy-veins','warcraft-tavern','hekili'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/discipline-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Discipline Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/discipline-priest-leveling',title='Icy Veins: Discipline Priest levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-discipline-priest-rotations-cooldowns/',title='Warcraft Tavern: Discipline Priest rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/discipline-priest/',title='wowtbc.gg: Discipline Priest (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/discipline-priest-class-guide-mop-classic',title='Method: Discipline Priest guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/PriestDiscipline.simc',title='Hekili (MoP fork): Discipline Priest priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=256}}},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.healer-cooldowns','priest-'),
  spell('priest-disc-archangel',81700,all(friendly,{type='BUFF_STACKS',unit='player',spell=81661,ownbuff=true,operator='GREATERTHANOREQUALS',value=5})),
  spell('priest-disc-inner-focus',89485,all(combat(),friendly)),
  spell('priest-disc-pain-suppression',33206,all(combat(),friendly,low(.3))),
  spell('priest-disc-desperate-prayer',19236,health('player','LESSTHAN',.3)),
  {id='priest-disc-spirit-shell',type='spell',action=109964,ranked=false,disabled=true,conditions=all(combat(),group)},
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-disc-'),
 {id='priest-disc-heal',type='branch',conditions=all(friendly,negate({type='DEAD',unit='target'})),onTrue={
  {id='priest-disc-shell',type='branch',conditions=own(109964),onFalse={},onTrue={
   spell('priest-disc-shell-prayer',596,all(group,hurt(3,.95))),
   spell('priest-disc-shell-greater',2060),
   stop('priest-disc-shell-stop'),
  }},
  spell('priest-disc-shield',17,all(any(unshielded,own(123266)),any(low(.5),negate(combat()),negate({type='SPELL_HISTORY_TIME',spell=17,operator='LESSTHAN',value=12})))),
  spell('priest-disc-surge',2061,own(114255)),
  spell('priest-disc-penance',47540,low(.7)),
  spell('priest-disc-flash',2061,low(.35)),
  spell('priest-disc-binding',32546,all(health('player','LESSTHAN',.7),low(.7),negate({type='ISSAME',unit='target',otherunit='player'}))),
  spell('priest-disc-mending',33076,all(combat(),group)),
  spell('priest-disc-prayer',596,all(group,hurt(3,.8))),
  spell('priest-disc-halo',120517,hurt(3,.85)),
  spell('priest-disc-cascade',121135,hurt(3,.85)),
  spell('priest-disc-divine-star',110744,hurt(3,.85)),
  spell('priest-disc-greater',2060,low(.6)),
  spell('priest-disc-renew',139,all({type='MOVING'},low(.9),negate({type='BUFF',unit='target',spell=139,ownbuff=true}))),
  spell('priest-disc-heal-spell',2050,low(.9)),
  stop('priest-disc-heal-stop'),
 },onFalse={
  stop('priest-disc-no-enemy',negate({type='ATTACKABLE',unit='target'})),
  spell('priest-disc-atone-penance',47540),
  spell('priest-disc-solace',129250),
  spell('priest-disc-holy-fire',14914,negate({type='TALENT',layout='grid',value=9})),
  spell('priest-disc-atone-halo',120517,tierSix),
  spell('priest-disc-atone-cascade',121135,tierSix),
  spell('priest-disc-atone-divine-star',110744,tierSix),
  spell('priest-disc-pain',589,all(negate(group),negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}),lives(12))),
  spell('priest-disc-smite',585),
  stop('priest-disc-damage-stop'),
 }},
 }},
}))
