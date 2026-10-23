-- WoW Forever Warrior melee DPS, Warcraft Tavern's spend-rage list (player-chosen variant).
-- Same switch as the recommended DPS premade, lower priority. Group and raid play that always
-- spends: five Sunder Armors on every target first, Execute above everything below 20%,
-- Overpower, Rend (until Bloodthirst), Mortal Strike, Bloodthirst, Whirlwind, Spearing Strike
-- on cooldown, Slam only with Improved Slam (the override that keeps the swing), Hamstring with
-- spare rage; Heroic Strike or Cleave from 60 rage; Recklessness on cooldown with Death Wish
-- paired to it. No Victory Rush, Demoralizing Shout, Thunder Clap or pack section: the source
-- lists none. Shared parts: Defaults/blocks/forever-warrior.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=all(negate(queued(78)),negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.dps.warcrafttavern',revision=1,
 blocks={['forever.warrior.boundaries']=1,['forever.warrior.upkeep']=1},
 nameKey='Default.Forever.Warrior.DPS.WarcraftTavern.Name',descriptionKey='Default.Forever.Warrior.DPS.WarcraftTavern.Description',
 applicability={families={'forever'},actionContext='player',class='WARRIOR',minLevel=1,maxLevel=60},
 tags={'dps','melee','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/forever/guides/arms-warrior/',title='Warcraft Tavern: Forever Arms Warrior',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/forever/guides/fury-warrior/',title='Warcraft Tavern: Forever Fury Warrior',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/forever/guides/warrior-leveling/',title='Warcraft Tavern: Forever Warrior leveling',reviewedAt='2026-10-23'}},
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('forever.warrior.upkeep','warrior-tavern-'),
  spell('warrior-tavern-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',60))),
  spell('warrior-tavern-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',60))),
  spell('warrior-tavern-recklessness',1719,combat()),
  spell('warrior-tavern-death-wish',12328,all(combat(),any(negate(known(1719)),{type='BUFF',unit='player',spell=1719},
   {type='SPELL_COOLDOWN',spell=1719,operator='GREATERTHAN',value=180})))},
 rotation={
 block('forever.warrior.boundaries','warrior-tavern-'),
 spell('warrior-tavern-sunder',7386,negate({type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5})),
 spell('warrior-tavern-execute',5308,{type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.2}),
 spell('warrior-tavern-overpower',7384),
 spell('warrior-tavern-rend',772,all(negate(known(23881)),negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}))),
 spell('warrior-tavern-mortal-strike',12294),
 spell('warrior-tavern-bloodthirst',23881),
 spell('warrior-tavern-whirlwind',1680),
 spell('warrior-tavern-spearing-strike',1310222),
 spell('warrior-tavern-improved-slam',1310196,negate({type='MOVING'})),
 spell('warrior-tavern-hamstring',1715,rage('GREATERTHANOREQUALS',70)),
 }},
}))
