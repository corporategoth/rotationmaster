-- Mists of Pandaria Classic Restoration Druid, levels 10–90, in the Restoration specialization (105). Wowhead's
-- Phase 5 group healing (Icy Veins, Method, wowtbc and Warcraft Tavern order the same tools): three
-- Lifeblooms on the focus tank, Wild Mushroom kept down, Swiftmend for emergencies and Harmony (and
-- into Wild Growth with Soul of the Forest), Wild Growth on group damage, Regrowth on Clearcasting,
-- Rejuvenation, then Healing Touch and Nourish on what is left. Heals act on your friendly target (or
-- yourself with none); choosing whom to heal is yours. An attackable target gets Moonfire and Wrath.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function hot(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function group(pct,n)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=pct,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local still=negate({type='MOVING'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.restoration',revision=6,
 blocks={['mop.druid.boundaries']=4,['mop.druid.mark']=1,['mop.druid.healer-upkeep']=1,['mop.druid.healer-open']=3},
 nameKey='Default.MoP.Druid.Restoration.Name',descriptionKey='Default.MoP.Druid.Restoration.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'restoration','healer','leveling','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/restoration/healer-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Restoration Druid healing',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/restoration-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.method.gg/mop-classic/restoration-druid-class-guide-mop-classic',title='Method: MoP Classic Restoration Druid',reviewedAt='2026-10-23',revision='2025-07-22',notes='Harmony from a direct heal.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-restoration-druid-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Restoration Druid',reviewedAt='2026-10-23',notes='Damage in downtime.'},
 },
 body={priority=30,specs={105},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('resto-mark','mop.druid.mark','resto-'),
   block('resto-upkeep','mop.druid.healer-upkeep','resto-'),
  },
  rotation={
   block('resto-boundaries','mop.druid.boundaries','resto-'),
   block('resto-open','mop.druid.healer-open','resto-'),
   spell('resto-swiftmend',18562,all(any(hot(774),hot(8936)),any(hurt(.6),negate(own(100977)),
    all({type='TALENT',layout='grid',value=10},group(.9,3),{type='SPELL_AVAIL',spell=48438})))),
   spell('resto-wild-growth',48438,group(.9,3)),
   spell('resto-swift-touch',5185,own(132158)),
   spell('resto-regrowth',8936,any(all(hurt(.9),any(own(16870),{type='FORM',form=33891})),hurt(.35))),
   spell('resto-tree-lifebloom',33763,all({type='FORM',form=33891},negate(hot(33763)))),
   spell('resto-rejuvenation',774,all(negate(hot(774)),hurt(.95))),
   spell('resto-healing-touch',5185,all(hurt(.5),still)),
   spell('resto-nourish',50464,all(hurt(.85),still)),
   stop('resto-heal-stop'),
  },
 },
}))
