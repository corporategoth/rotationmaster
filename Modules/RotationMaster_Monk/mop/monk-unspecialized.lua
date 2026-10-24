-- Mists of Pandaria Classic Monk before a specialization (levels 1–9, or a monk who has not picked
-- one): the catch-all, lowest priority, switch always true. Fierce Tiger, Tiger Power from Tiger
-- Palm, Blackout Kick at two Chi, Expel Harm when hurt, Jab. Jab is the opener (no ranged spell yet).
-- RM policy from the 1–9 kit and the Windwalker priority; no guide writes a 1–9 list.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function hurt()return{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.8}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.unspecialized',revision=4,
 blocks={['mop.monk.boundaries']=3,['mop.monk.upkeep']=1},
 nameKey='Default.MoP.Monk.Unspecialized.Name',descriptionKey='Default.MoP.Monk.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'leveling','single-target'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/windwalker-monk-leveling',title='Icy Veins: MoP Classic Windwalker Monk leveling',reviewedAt='2026-10-23',revision='2025-06-17',notes='Early kit (Expel Harm at 7); the 1–9 order is RM policy from the Windwalker priority.'},
  {url='https://www.warcrafttavern.com/mop/guides/monk-leveling-guide/',title='Warcraft Tavern: MoP Monk leveling guide',reviewedAt='2026-10-23'},
 },
 body={priority=0,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   spell('monk-tiger-stance',103985,negate({type='FORM',form=103985})),
   block('monk-class','mop.monk.upkeep','monk-'),
  },
  rotation={
   block('monk-boundaries','mop.monk.boundaries','monk-'),
   spell('monk-tiger-palm',100787,any(negate(own(125359)),{type='BUFF_REMAIN',unit='player',spell=125359,ownbuff=true,operator='LESSTHANOREQUALS',value=2})),
   spell('monk-blackout-kick',100784,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=2}),
   spell('monk-expel-harm',115072,hurt()),
   spell('monk-expel-harm-early',115129,all(hurt(),negate({type='SPELL_KNOWN',spell=115072}))),
   spell('monk-jab',100780),
  },
 },
}))
