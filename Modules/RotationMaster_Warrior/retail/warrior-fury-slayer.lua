-- Retail (Midnight) Fury Warrior, Slayer (SimulationCraft's slayer and slayer_aoe lists): the
-- optimal reference, disabled by default because Enrage, Recklessness and Sudden Death are hidden
-- in Midnight combat. Charge to open. Whirlwind for its buff on two or more engaged enemies;
-- Rampage when Enrage is ending; in Recklessness Rampage, Bladestorm, Execute on Sudden Death,
-- Odyn's Fury; Crushing Blow; Bloodbath; Execute; Odyn's Fury; Raging Blow; Rampage; Bloodthirst;
-- Whirlwind. Rage is secret on Retail, so Rampage waits only for its cost (no 100-rage gates).
-- Reminders: Recklessness, Avatar, Enraged Regeneration.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.fury.slayer',revision=4,
 blocks={['retail.warrior.boundaries']=1,['retail.warrior.upkeep']=1,['retail.warrior.charge']=2},
 nameKey='Default.Retail.Warrior.Fury.Slayer.Name',descriptionKey='Default.Retail.Warrior.Fury.Slayer.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'fury','melee','reference','slayer','single-target','aoe','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_fury.simc',title='SimulationCraft: Fury Warrior default list (slayer, slayer_aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=72},
  cooldowns={
   block('retail.warrior.upkeep','furysl-'),
   spell('furysl-recklessness',1719,fight),
   spell('furysl-avatar',107574,fight),
   spell('furysl-enraged-regeneration',184364,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','furysl-'),
   block('retail.warrior.charge','furysl-'),
   spell('furysl-whirlwind-buff',190411,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},negate(own(85739)))),
   spell('furysl-rampage-enrage',184367,any(negate(own(184362)),{type='BUFF_REMAIN',unit='player',spell=184362,ownbuff=true,operator='LESSTHAN',value=1.5})),
   {id='furysl-reckless',type='branch',conditions=own(1719),onFalse={},onTrue={
    spell('furysl-reckless-rampage',184367),
    spell('furysl-reckless-bladestorm',446035),
    spell('furysl-reckless-execute',5308,own(280776)),
    spell('furysl-reckless-odyns-fury',385059),
   }},
   spell('furysl-crushing-blow',335097),
   spell('furysl-bloodbath',335096),
   spell('furysl-execute',5308),
   spell('furysl-odyns-fury',385059),
   spell('furysl-raging-blow',85288),
   spell('furysl-rampage',184367),
   spell('furysl-bloodthirst',23881),
   spell('furysl-whirlwind',190411),
  },
 },
}))
