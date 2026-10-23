-- Mists of Pandaria Classic Windwalker Monk after the SimulationCraft 5.4.8 default list that Hekili's
-- MoP fork and MaxDps ship. Same switch as rm.mop.monk.windwalker, lower priority and off by
-- default. Differs from it: Tiger Power refreshed at 3 s, Rising Sun Kick first while its debuff is
-- down, Fists of Fury tied to Tigereye Brew (active or 15 stacks), Tigereye Brew at 20 stacks or 15
-- with Chi, the debuff and Tiger Power up (before Tigereye Brew at 56 Fists of Fury is free to use), and on three or more enemies Spinning Crane Kick with
-- Rising Sun Kick only at full Chi, single-target spenders only above 60 energy.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function stacks(op,v)return{type='BUFF_STACKS',unit='player',spell=1247279,ownbuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local TEB,RSK=1247275,107428
local debuff={type='DEBUFF',unit='target',spell=130320,owndebuff=true}
local capped=negate(chi('GREATERTHANOREQUALS',-1))
local fists=all(negate({type='MOVING'}),energy('LESSTHANOREQUALS',50))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.windwalker.simc',revision=1,
 blocks={['mop.monk.boundaries']=1,['mop.monk.upkeep']=1,['mop.monk.windwalker-upkeep']=1,['mop.monk.windwalker-open']=1,['mop.monk.windwalker-tail']=1},
 nameKey='Default.MoP.Monk.Windwalker.Simc.Name',descriptionKey='Default.MoP.Monk.Windwalker.Simc.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK',minLevel=10,maxLevel=90},
 tags={'windwalker','single-target','aoe','simulationcraft','hekili','maxdps'},
 sources={
  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/MonkWindwalker.simc',title='Hekili MoP fork: Windwalker priority (SimC 5.4.8)',reviewedAt='2026-10-23',revision='0750b5dd98'},
  {url='https://github.com/kaminaris/MaxDps-Monk/blob/d286e7b14011e920aebe2acf2adda9d82a1c270f/Specialization/Mop/Windwalker.lua',title='MaxDps-Monk: MoP Windwalker',reviewedAt='2026-10-23',revision='d286e7b140',notes='Same list; Tigereye Brew at 10 or more.'},
 },
 body={priority=20,disabled=true,switch={type='SPELL_KNOWN',spell=113656},
  cooldowns={
   block('wwsc-upkeep','mop.monk.windwalker-upkeep','wwsc-'),
   block('wwsc-class','mop.monk.upkeep','wwsc-'),
   spell('wwsc-tigereye-brew',TEB,all(combat(),negate(own(TEB)),any(stacks('GREATERTHANOREQUALS',20),
    all(stacks('GREATERTHANOREQUALS',15),chi('GREATERTHANOREQUALS',2),debuff,own(125359))))),
   spell('wwsc-chi-brew',115399,all(combat(),chi('LESSTHANOREQUALS',2))),
  },
  rotation={
   block('wwsc-boundaries','mop.monk.boundaries','wwsc-'),
   block('wwsc-open','mop.monk.windwalker-open','wwsc-'),
   spell('wwsc-tiger-palm',100787,any(negate(own(125359)),remain(125359,'LESSTHANOREQUALS',3))),
   spell('wwsc-rising-sun-debuff',RSK,negate(debuff)),
   {id='wwsc-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('wwsc-aoe-jade-wind',116847),
    spell('wwsc-aoe-zen-sphere',124081,negate(own(124081))),
    spell('wwsc-aoe-chi-wave',115098),
    spell('wwsc-aoe-chi-burst',123986),
    spell('wwsc-aoe-rising-sun',RSK,capped),
    spell('wwsc-aoe-crane-kick',101546,negate({type='TALENT',layout='grid',value=16})),
    {id='wwsc-aoe-pool',type='none',conditions=energy('LESSTHAN',60)}}},
   spell('wwsc-fists-in-brew',113656,all(own(TEB),fists)),
   spell('wwsc-rising-sun-kick',RSK),
   spell('wwsc-fists-of-fury',113656,all(fists,negate(own(115288)),remain(125359,'GREATERTHAN',4),any(own(TEB),stacks('GREATERTHANOREQUALS',15),negate({type='SPELL_KNOWN',spell=TEB})))),
   spell('wwsc-chi-wave',115098),
   spell('wwsc-chi-burst',123986),
   spell('wwsc-zen-sphere',124081,negate(own(124081))),
   spell('wwsc-combo-kick',100784,own(116768)),
   spell('wwsc-combo-palm',100787,remain(118864,'LESSTHANOREQUALS',3)),
   block('wwsc-tail','mop.monk.windwalker-tail','wwsc-'),
  },
 },
}))
