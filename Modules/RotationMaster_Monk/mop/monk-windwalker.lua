-- Mists of Pandaria Classic Windwalker Monk, levels 10–90, in the Windwalker specialization
-- (269). wowsims' Phase 5 order, which Wowhead's Phase 5 list mirrors: Touch of
-- Death, Tiger Power, Rising Sun Kick, Chi Wave, Combo Breaker procs, Fists of Fury when the
-- channel will not cap energy, Jab at a two-Chi deficit, Blackout Kick. Cleave and AoE from two
-- engaged enemies. Tigereye Brew is held to 19 stacks (15 with Chi to spend, 10 under Bloodlust).
-- Energy-to-cap tests are POWER thresholds. The SimulationCraft 5.4.8 list is
-- rm.mop.monk.windwalker.simc.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function stacks(op,v)return{type='BUFF_STACKS',unit='player',spell=1247279,ownbuff=true,operator=op,value=v}end
local function rsk(op,v)return{type='DEBUFF_REMAIN',unit='target',spell=130320,owndebuff=true,operator=op,value=v}end
local function enemies(op,v)return{type='THREAT_COUNT',threat=1,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local TEB,RSK=1247275,107428
local lust=any(buff(2825),buff(32182),buff(80353),buff(90355))
local tigerPower=any(negate(own(125359)),remain(125359,'LESSTHANOREQUALS',1))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.windwalker',revision=4,
 blocks={['mop.monk.boundaries']=2,['mop.monk.upkeep']=1,['mop.monk.windwalker-upkeep']=2,['mop.monk.windwalker-open']=2,['mop.monk.windwalker-tail']=1},
 nameKey='Default.MoP.Monk.Windwalker.Name',descriptionKey='Default.MoP.Monk.Windwalker.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'windwalker','leveling','single-target','aoe','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/mop/blob/master/ui/specs/monk/windwalker/apls/default.apl.json',title='wowsims/mop: Windwalker APL (Phase 5)',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/monk/windwalker/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Windwalker Monk rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20',notes='Read from a Wayback snapshot; Tigereye Brew at 19, 15 with Chi or 10 with a burst buff.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/windwalker-monk-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Windwalker Monk rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Fists of Fury gates and Expel Harm instead of Jab when hurt; leveling order.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=269}}},
  cooldowns={
   block('ww-upkeep','mop.monk.windwalker-upkeep','ww-'),
   block('ww-class','mop.monk.upkeep','ww-'),
   spell('ww-tigereye-brew',TEB,all(combat(),negate(own(TEB)),any(stacks('GREATERTHANOREQUALS',19),all(stacks('GREATERTHANOREQUALS',15),chi('GREATERTHANOREQUALS',2)),
    all(stacks('GREATERTHANOREQUALS',10),lust),all(stacks('GREATERTHANOREQUALS',1),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=30})))),
   spell('ww-chi-brew',115399,all(combat(),chi('GREATERTHANOREQUALS',-2),any(own(TEB),{type='SPELL_CHARGES',spell=115399,operator='EQUALS',value=2}))),
  },
  rotation={
   block('ww-boundaries','mop.monk.boundaries','ww-'),
   block('ww-open','mop.monk.windwalker-open','ww-'),
   {id='ww-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    spell('ww-aoe-jade-wind',116847),
    spell('ww-aoe-rising-sun',RSK,any(enemies('LESSTHAN',3),negate({type='DEBUFF',unit='target',spell=130320,owndebuff=true}),rsk('LESSTHANOREQUALS',1.5))),
    spell('ww-aoe-tiger-palm',100787,tigerPower),
    spell('ww-aoe-crane-kick-refreshed',101546,all(enemies('GREATERTHANOREQUALS',4),rsk('GREATERTHANOREQUALS',2.25))),
    spell('ww-aoe-rising-sun-kick',RSK),
    spell('ww-aoe-crane-kick',101546,enemies('GREATERTHANOREQUALS',3))}},
   spell('ww-tiger-palm',100787,tigerPower),
   spell('ww-rising-sun-kick',RSK),
   spell('ww-chi-wave',115098,energy('LESSTHANOREQUALS',85)),
   spell('ww-combo-kick',100784,own(116768)),
   spell('ww-fists-of-fury',113656,all(negate(own(115288)),energy('LESSTHANOREQUALS',50),remain(125359,'GREATERTHANOREQUALS',4),negate({type='MOVING'}),
    any(negate({type='SPELL_KNOWN',spell=RSK}),{type='SPELL_COOLDOWN',spell=RSK,operator='GREATERTHANOREQUALS',value=3}))),
   spell('ww-zen-sphere',124081,all(negate(own(124081)),energy('LESSTHANOREQUALS',75))),
   spell('ww-combo-palm',100787,own(118864)),
   spell('ww-chi-burst',123986,energy('LESSTHANOREQUALS',75)),
   block('ww-tail','mop.monk.windwalker-tail','ww-'),
  },
 },
}))
