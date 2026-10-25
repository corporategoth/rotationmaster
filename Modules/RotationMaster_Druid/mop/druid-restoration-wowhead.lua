-- Mists of Pandaria Classic Restoration Druid for tank healing, after Wowhead's single-target
-- scenario (Method's single-target block agrees): keep the tank targeted. Lifebloom on it, Rejuvenation kept on your
-- target, Regrowth for heavy damage, Nourish for light damage, Healing Touch once Lifebloom and
-- Rejuvenation are already rolling, Swiftmend to keep the target topped. Direct heals replace Wild
-- Growth and Rejuvenation spreading. Shares the Restoration switch at a lower priority and ships
-- disabled.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function hot(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local still=negate({type='MOVING'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.restoration.wowhead',revision=5,
 blocks={['mop.druid.boundaries']=4,['mop.druid.mark']=1,['mop.druid.healer-upkeep']=1,['mop.druid.healer-open']=3},
 nameKey='Default.MoP.Druid.Restoration.Wowhead.Name',descriptionKey='Default.MoP.Druid.Restoration.Wowhead.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'restoration','healer','tank-healing','wowhead'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/restoration/healer-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Restoration Druid healing (single-target scenario)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.method.gg/mop-classic/restoration-druid-class-guide-mop-classic',title='Method: MoP Classic Restoration Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Same single-target block.'},
 },
 body={priority=20,disabled=true,specs={105},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('rtank-mark','mop.druid.mark','rtank-'),
   block('rtank-upkeep','mop.druid.healer-upkeep','rtank-'),
  },
  rotation={
   block('rtank-boundaries','mop.druid.boundaries','rtank-'),
   block('rtank-open','mop.druid.healer-open','rtank-'),
   spell('rtank-lifebloom',33763,all({type='FRIENDLY',unit='target'},any(negate(hot(33763)),
    {type='BUFF_STACKS',unit='target',spell=33763,ownbuff=true,operator='LESSTHAN',value=3},
    {type='BUFF_REMAIN',unit='target',spell=33763,ownbuff=true,operator='LESSTHAN',value=4}))),
   spell('rtank-rejuvenation',774,all({type='COMBAT',unit='player'},negate(hot(774)))),
   spell('rtank-swift-touch',5185,own(132158)),
   spell('rtank-regrowth',8936,hurt(.6)),
   spell('rtank-healing-touch',5185,all(hot(33763),hot(774),hurt(.5),still)),
   spell('rtank-nourish',50464,all(hurt(.9),still)),
   spell('rtank-swiftmend',18562,all(any(hot(774),hot(8936)),hurt(.9))),
   stop('rtank-heal-stop'),
  },
 },
}))
