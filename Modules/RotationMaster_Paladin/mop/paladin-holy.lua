-- Mists of Pandaria Classic Holy Paladin, levels 10–90, in the Holy specialization (65). Icy Veins' Eternal
-- Flame and Selfless Healer builds (the talent decides which steps apply) with Warcraft Tavern's
-- triage. A friendly target is healed: spend 3 Holy Power (or Divine Purpose) on Light of Dawn for a
-- hurt group, Eternal Flame or Word of Glory for one; Holy Shock on cooldown; Infusion of Light and
-- Selfless Healer procs; Flash of Light in an emergency; Holy Radiance for the group; Divine Light,
-- then Holy Light. An enemy target gets Holy Shock, Judgment, Crusader Strike and the rest. Beacon of
-- Light and Sacred Shield go on your focus (set the tank as focus); whom to heal is your choice.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function hurt(v,n)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=v,operator='GREATERTHANOREQUALS',value=n or 3}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local focus={type='FRIENDLY',unit='focus'}
local function onFocus(...)local list={};for i,id in ipairs({...})do list[i]={type='BUFF',unit='focus',spell=id,ownbuff=true}end;return{type='OR',value=list}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.holy',revision=3,
 blocks={['mop.paladin.boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-insight']=2},
 nameKey='Default.MoP.Paladin.Holy.Name',descriptionKey='Default.MoP.Paladin.Holy.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'holy','healer','leveling','icy-veins','warcraft-tavern'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-paladin-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Holy Paladin rotation',reviewedAt='2026-10-23',revision='2025-06-10'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-paladin-leveling',title='Icy Veins: MoP Classic Holy Paladin leveling',reviewedAt='2026-10-23',revision='2025-06-10'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-holy-paladin-rotations-cooldowns/',title='Warcraft Tavern: MoP Holy Paladin rotation',reviewedAt='2026-10-23',notes='Triage thresholds and the damage rotation.'},
  {url='https://www.method.gg/mop-classic/holy-paladin-class-guide-mop-classic',title='Method: MoP Classic Holy Paladin guide',reviewedAt='2026-10-23',revision='2025-07-23',notes='Beacon on the tank; cooldowns in heavy damage, not all at once.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=65}}},
  cooldowns={
   block('holy-seal','mop.paladin.seal-insight','holy-'),
   block('holy-upkeep','mop.paladin.upkeep','holy-'),
   spell('holy-beacon',53563,all(focus,negate(onFocus(53563)))),
   spell('holy-sacred-shield',20925,all(focus,negate(onFocus(65148,148039)))),
   spell('holy-divine-plea',54428,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.6})),
   spell('holy-lights-hammer',114158,hurt(.85)),
   spell('holy-avenging-wrath',31884,all({type='GROUP'},hurt(.7))),
   spell('holy-divine-favor',31842,all({type='GROUP'},hurt(.7))),
   spell('holy-guardian',86669,all({type='GROUP'},hurt(.7))),
   spell('holy-holy-avenger',105809,all({type='GROUP'},hurt(.7))),
   spell('holy-lay-on-hands',633,all({type='FRIENDLY',unit='target'},target('LESSTHAN',.15),negate({type='DEBUFF',unit='target',spell=25771}))),
  },
  rotation={
   block('holy-boundaries','mop.paladin.boundaries','holy-'),
   {id='holy-heal',type='branch',conditions={type='FRIENDLY',unit='target'},onTrue={
    {id='holy-spend',type='branch',conditions=any({type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3},buff(90174)),onFalse={},onTrue={
     spell('holy-light-of-dawn',85222,hurt(.9)),
     spell('holy-eternal-flame',114163,negate({type='BUFF',unit='target',spell=114163,ownbuff=true})),
     spell('holy-word-of-glory',85673,target('LESSTHAN',.9))}},
    spell('holy-shock',20473),
    {id='holy-infusion',type='branch',conditions=buff(54149),onFalse={},onTrue={
     spell('holy-infusion-radiance',82327,hurt(.85)),
     spell('holy-infusion-divine-light',82326,target('LESSTHAN',.7))}},
    {id='holy-selfless',type='branch',conditions={type='BUFF_STACKS',unit='player',spell=114250,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
     spell('holy-selfless-radiance',82327,hurt(.85)),
     spell('holy-selfless-flash',19750,target('LESSTHAN',.8))}},
    spell('holy-flash-emergency',19750,target('LESSTHAN',.35)),
    spell('holy-radiance',82327,hurt(.85)),
    spell('holy-divine-light',82326,target('LESSTHAN',.7)),
    spell('holy-holy-light',635,target('LESSTHAN',.9)),
    spell('holy-flash-before-holy-light',19750,all(target('LESSTHAN',.9),negate({type='SPELL_KNOWN',spell=635}))),
    stop('holy-heal-stop')},
   onFalse={
    stop('holy-target',negate({type='ATTACKABLE',unit='target'})),
    spell('holy-damage-shock',20473),
    spell('holy-damage-judgment',20271),
    spell('holy-damage-crusader-strike',35395),
    spell('holy-damage-holy-prism',114165),
    spell('holy-damage-execution-sentence',114157),
    spell('holy-damage-hammer-wrath',24275),
    spell('holy-damage-denounce',2812)}},
  },
 },
}))
