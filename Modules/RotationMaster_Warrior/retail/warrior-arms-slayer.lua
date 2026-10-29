-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Arms Warrior, Slayer (SimulationCraft's slayer_st list, Icy Veins, Wowhead):
-- the optimal reference, disabled by default because rage, Rend, Colossus Smash, Sudden Death and
-- Opportunist are hidden in Midnight combat. Charge to open. Sweeping Strikes on two or more
-- engaged enemies; Rend before Colossus Smash when it is running out; Ravager just before
-- Colossus Smash; Execute at two Sudden Death; Colossus Smash; Bladestorm in Colossus Smash or
-- Avatar; Heroic Strike; Overpower at two Opportunist; Mortal Strike; Execute; Overpower; Rend
-- under 5 s; Slam. Reminders: Avatar with Colossus Smash ready, Die by the Sword.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function rend(v)return any(negate(dot(388539)),{type='DEBUFF_REMAIN',unit='target',spell=388539,owndebuff=true,operator='LESSTHAN',value=v})end
local function stacks(id,n)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local smashSoon={type='SPELL_COOLDOWN',spell=167105,operator='LESSTHAN',value=1.5}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.arms.slayer',revision=7,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 nameKey="Slayer reference (SimulationCraft)",descriptionKey="Reference only, off by default: the Slayer order from SimulationCraft, Icy Veins and Wowhead reads rage, Rend, Colossus Smash, Sudden Death and Opportunist, which Midnight hides in combat. Charge to open; Sweeping Strikes on two or more engaged enemies; Rend before Colossus Smash when it is running out; Ravager just before Colossus Smash; Execute at two Sudden Death; Colossus Smash; Bladestorm in Colossus Smash or Avatar; Heroic Strike; Overpower at two Opportunist; Mortal Strike; Execute; Overpower; Rend under 5 seconds; Slam. Reminders: Avatar with Colossus Smash ready, Die by the Sword, Battle Shout, Pummel.",
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'arms','melee','reference','slayer','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_arms.simc',title='SimulationCraft: Arms Warrior default list (slayer_st)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Arms Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/warrior/arms/rotation-cooldowns-pve-dps',title='Wowhead: Arms Warrior rotation (Season 2)',reviewedAt='2026-10-23',revision='2026-08-20'},
 },
 body={priority=5,disabled=true,specs={71},
  cooldowns={
   block('retail.warrior.upkeep','armssl-'),
   spell('armssl-avatar',107574,all(fight,{type='SPELL_AVAIL',spell=167105})),
   spell('armssl-die-by-the-sword',118038,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','armssl-'),
   block('retail.warrior.charge','armssl-'),
   spell('armssl-sweeping-strikes',260708,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
   spell('armssl-rend-before-smash',772,all(rend(4),smashSoon)),
   spell('armssl-ravager',228920,smashSoon),
   spell('armssl-execute-sudden-death',163201,stacks(52437,2)),
   spell('armssl-colossus-smash',167105),
   spell('armssl-bladestorm',227847,any(dot(208086),own(107574))),
   spell('armssl-heroic-strike',1269383),
   spell('armssl-overpower-opportunist',7384,stacks(456120,2)),
   spell('armssl-mortal-strike',12294),
   spell('armssl-execute',163201),
   spell('armssl-overpower',7384),
   spell('armssl-rend',772,rend(5)),
   spell('armssl-slam',1464),
  },
 },
}))
