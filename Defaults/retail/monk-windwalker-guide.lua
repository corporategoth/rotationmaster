-- Retail (Midnight 12.x) Windwalker Monk after Icy Veins (Conduit of the Celestials; Shado-Pan and
-- SimulationCraft differ trivially), optimal reference. Every step keeps Combo Strikes: never the
-- spell you cast last. Disabled: Heart of the Jade Serpent, Zenith, Blackout Kick!, Dance of Chi-Ji,
-- energy and cooldown times are secret in Midnight combat; only Chi and your own casts stay readable.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
-- Combo Strikes: RM has no rotation-wide "not the previous cast" rule, so each step carries it.
local function strike(id,action,conditions)
 local fresh=negate({type='SPELL_HISTORY',spell=action,operator='EQUALS',value=1})
 return spell(id,action,conditions and all(fresh,conditions)or fresh)
end
local heart=any(buff(443421),buff(443616))
local zenith=buff(1249625)
local bok={type='BUFF_STACKS',unit='player',spell=116768,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.windwalker.guide',revision=1,
 blocks={['retail.monk.boundaries']=1,['retail.monk.utility']=1},
 nameKey='Default.Retail.Monk.WindwalkerGuide.Name',descriptionKey='Default.Retail.Monk.WindwalkerGuide.Description',
 applicability={families={'retail'},actionContext='player',class='MONK',specs={269},minLevel=10,maxLevel=90},
 tags={'windwalker','melee','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/windwalker-monk-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Windwalker Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/monk_windwalker.simc',title='SimulationCraft default action list: Windwalker',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same order with more energy and Heart of the Jade Serpent gates.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('wguide-utility','retail.monk.utility','wguide-'),
   spell('wguide-touch-of-karma',122470,{type='COMBAT',unit='player'}),
  },
  rotation={
   block('wguide-boundaries','retail.monk.boundaries','wguide-'),
   strike('wguide-grace-dragon-punch',152175,any(negate(known(123904)),{type='SPELL_COOLDOWN',spell=123904,operator='GREATERTHAN',value=10})),
   strike('wguide-zenith-stomp',1272696,any(chi('LESSTHAN',2),{type='BUFF_REMAIN',unit='player',spell=1249625,ownbuff=true,operator='LESSTHAN',value=2})),
   strike('wguide-conduit-no-heart',443028,negate(heart)),
   strike('wguide-heart-fists',113656,all(buff(443421),{type='BUFF_REMAIN',unit='player',spell=443421,ownbuff=true,operator='LESSTHAN',value=1})),
   strike('wguide-cap-tiger-palm',100780,all(chi('LESSTHAN',4),negate(bok),{type='POWER',unit='player',operator='LESSTHAN',value=-20},negate(zenith))),
   strike('wguide-conduit',443028),
   strike('wguide-invoke-xuen',123904),
   strike('wguide-fists-of-fury',113656),
   strike('wguide-dragon-punch',152175),
   strike('wguide-windlord',392983),
   strike('wguide-short-blackout-kick',100784,chi('LESSTHAN',3)),
   strike('wguide-rushing-wind-kick',467307),
   strike('wguide-rising-sun-kick',107428),
   strike('wguide-stacked-blackout-kick',100784,any(bok,zenith)),
   strike('wguide-zenith-crane-kick',101546,any(all(zenith,chi('GREATERTHAN',4)),buff(325202))),
   strike('wguide-touch-of-death',322109),
   strike('wguide-short-tiger-palm',100780,chi('LESSTHAN',2)),
   strike('wguide-proc-blackout-kick',100784,buff(116768)),
   strike('wguide-slicing-winds',1217413),
   strike('wguide-tiger-palm',100780,chi('LESSTHAN',4)),
   strike('wguide-blackout-kick',100784),
  },
 },
}))
