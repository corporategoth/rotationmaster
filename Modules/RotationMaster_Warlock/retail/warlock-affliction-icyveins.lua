-- Retail (Midnight) Affliction Warlock, Icy Veins and SimulationCraft's default (Soul Harvester)
-- list: the optimal reference, disabled by default because DoT timers, Nightfall and Shard
-- Instability are hidden in Midnight combat (soul shards stay readable). Haunt before the pull.
-- Seed of Corruption on three or more engaged enemies without your Corruption; Haunt; Agony and
-- Corruption (Wither) under 3 s; Dark Harvest at two or fewer shards; Unstable Affliction at 5
-- shards; Malefic Grasp, then Shadow Bolt, on two Nightfall; Unstable Affliction on Shard
-- Instability or at 4 shards; Drain Soul; Shadow Bolt. Reminders: Summon Darkglare once Dark
-- Harvest is cooling, Malevolence, a Felhunter between pulls unless sacrificed.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return any(negate(dot(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v})end
local function shards(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.affliction.icyveins',revision=4,
 blocks={['retail.warlock.boundaries']=2,['retail.warlock.upkeep']=2},
 nameKey='Default.Retail.Warlock.Affliction.IcyVeins.Name',descriptionKey='Default.Retail.Warlock.Affliction.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'affliction','ranged','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/affliction-warlock-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Affliction Warlock rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warlock_affliction.simc',title='SimulationCraft: Affliction Warlock default list (SH_st)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=265},
  cooldowns={
   block('retail.warlock.upkeep','affiv-'),
   spell('affiv-summon-felhunter',691,all(negate(combat()),negate({type='PET'}),negate(own(196099)))),
   spell('affiv-darkglare',205180,all(fight,negate({type='SPELL_AVAIL',spell=1257052}))),
   spell('affiv-malevolence',442726,fight),
  },
  rotation={
   block('retail.warlock.boundaries','affiv-'),
   {id='affiv-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('affiv-pull-haunt',48181),
    {id='affiv-pull-stop',type='none',suppress_attack=true,conditions={}},
   }},
   spell('affiv-seed',27243,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},negate(dot(146739)),negate(dot(445474)))),
   spell('affiv-haunt',48181),
   spell('affiv-agony',980,expiring(980,3)),
   spell('affiv-wither',445468,expiring(445474,3)),
   spell('affiv-corruption',172,all(negate({type='SPELL_KNOWN',spell=445468}),expiring(146739,3))),
   spell('affiv-dark-harvest',1257052,shards('LESSTHANOREQUALS',2)),
   spell('affiv-unstable-capped',1259790,shards('GREATERTHANOREQUALS',5)),
   spell('affiv-nightfall-grasp',1261153,{type='BUFF_STACKS',unit='player',spell=264571,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   spell('affiv-nightfall-bolt',686,{type='BUFF_STACKS',unit='player',spell=264571,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   spell('affiv-unstable-instability',1259790,any(own(1260269),shards('GREATERTHANOREQUALS',4))),
   spell('affiv-drain-soul',198590),
   spell('affiv-shadow-bolt',686),
  },
 },
}))
