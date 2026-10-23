-- Mists of Pandaria Classic Brewmaster Monk, damage-first, after wowsims' "Offensive" APL (Phase 5).
-- Same switch as rm.mop.monk.brewmaster, lower priority and off by default: no routine Purifying
-- Brew or Guard (Purifying Brew only on the tier-15 Purifier proc), Rushing Jade Wind before Keg
-- Smash, Chi spent on Blackout Kick for damage. Only for an overgeared tank or a damage race.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function keg(op,v)return{type='SPELL_COOLDOWN',spell=121253,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local SHUFFLE=115307
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.brewmaster.offensive',revision=1,
 blocks={['mop.monk.boundaries']=1,['mop.monk.upkeep']=1,['mop.monk.brewmaster-upkeep']=1,['mop.monk.brewmaster-pull']=1},
 nameKey='Default.MoP.Monk.Brewmaster.Offensive.Name',descriptionKey='Default.MoP.Monk.Brewmaster.Offensive.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK',minLevel=10,maxLevel=90},
 tags={'brewmaster','tank','single-target','wowsims'},
 sources={
  {url='https://github.com/wowsims/mop/blob/master/ui/specs/monk/brewmaster/apls/offensive.apl.json',title='wowsims/mop: Brewmaster Offensive APL (Phase 5)',reviewedAt='2026-10-23',revision='ec2c6c2552'},
 },
 body={priority=20,disabled=true,switch={type='SPELL_KNOWN',spell=115069},
  cooldowns={
   block('brewo-upkeep','mop.monk.brewmaster-upkeep','brewo-'),
   block('brewo-class','mop.monk.upkeep','brewo-'),
   spell('brewo-purifier',119582,all(combat(),own(138237))),
   spell('brewo-chi-brew',115399,all(combat(),any(chi('EQUALS',0),all(chi('LESSTHANOREQUALS',2),keg('GREATERTHANOREQUALS',2),keg('LESSTHANOREQUALS',7),energy('LESSTHAN',80))))),
  },
  rotation={
   block('brewo-boundaries','mop.monk.boundaries','brewo-'),
   block('brewo-pull','mop.monk.brewmaster-pull','brewo-'),
   spell('brewo-touch-of-death',115080),
   spell('brewo-cap-kick',100784,all(keg('LESSTHANOREQUALS',1.5),chi('LESSTHANOREQUALS',-1))),
   spell('brewo-jade-wind',116847),
   spell('brewo-keg-smash',121253),
   spell('brewo-shuffle-kick',100784,any(negate(own(SHUFFLE)),remain(SHUFFLE,'LESSTHANOREQUALS',1.5),all(keg('LESSTHANOREQUALS',2),chi('LESSTHANOREQUALS',-1)))),
   spell('brewo-tiger-palm',100787,any(negate(own(125359)),remain(125359,'LESSTHANOREQUALS',1.5))),
   spell('brewo-chi-wave',115098),
   spell('brewo-chi-burst',123986),
   spell('brewo-zen-sphere',124081,negate(own(124081))),
   spell('brewo-spend-kick',100784,chi('LESSTHANOREQUALS',-1)),
   spell('brewo-jab',100780,all(energy('GREATERTHANOREQUALS',80),chi('GREATERTHANOREQUALS',-1))),
   spell('brewo-palm-filler',100787),
   spell('brewo-jab-filler',100780,chi('GREATERTHANOREQUALS',-1)),
  },
 },
}))
