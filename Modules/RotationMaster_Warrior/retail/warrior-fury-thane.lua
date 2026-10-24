-- Retail (Midnight) Fury Warrior, Mountain Thane (SimulationCraft's thane list, Icy Veins): the
-- optimal reference, disabled by default because Enrage, Recklessness, Avatar and Thunder Blast
-- stacks are hidden in Midnight combat (rage is secret on Retail, so there is no 100-rage Rampage).
-- Charge to open. Whirlwind for its buff on two or more engaged enemies; Rampage when Enrage is
-- missing or ending; Bloodbath in Recklessness;
-- Thunder Blast at two stacks; Crushing Blow; Bloodbath; Rampage in Recklessness; Thunder Blast
-- in Avatar; Raging Blow; Thunder Blast; Rampage; Bloodthirst; Execute; Odyn's Fury; Thunder Clap;
-- Whirlwind. Reminders: Recklessness, Avatar, Enraged Regeneration.
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
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.fury.thane',revision=3,
 blocks={['retail.warrior.boundaries']=1,['retail.warrior.upkeep']=1,['retail.warrior.charge']=2},
 nameKey='Default.Retail.Warrior.Fury.Thane.Name',descriptionKey='Default.Retail.Warrior.Fury.Thane.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR',specs={72},minLevel=10,maxLevel=90},
 tags={'fury','melee','reference','mountain-thane','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_fury.simc',title='SimulationCraft: Fury Warrior default list (thane, thane_aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Fury Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=4,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('retail.warrior.upkeep','furyth-'),
   spell('furyth-recklessness',1719,fight),
   spell('furyth-avatar',107574,fight),
   spell('furyth-enraged-regeneration',184364,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','furyth-'),
   block('retail.warrior.charge','furyth-'),
   spell('furyth-whirlwind-buff',190411,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},negate(own(85739)))),
   spell('furyth-rampage-enrage',184367,any(negate(own(184362)),{type='BUFF_REMAIN',unit='player',spell=184362,ownbuff=true,operator='LESSTHAN',value=1.5})),
   spell('furyth-reckless-bloodbath',335096,own(1719)),
   spell('furyth-thunder-blast-stacked',435222,{type='BUFF_STACKS',unit='player',spell=435615,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   spell('furyth-crushing-blow',335097),
   spell('furyth-bloodbath',335096),
   spell('furyth-reckless-rampage',184367,own(1719)),
   spell('furyth-avatar-thunder-blast',435222,own(107574)),
   spell('furyth-raging-blow',85288),
   spell('furyth-thunder-blast',435222),
   spell('furyth-rampage',184367),
   spell('furyth-bloodthirst',23881),
   spell('furyth-execute',5308),
   spell('furyth-odyns-fury',385059),
   spell('furyth-thunder-clap',6343),
   spell('furyth-whirlwind',190411),
  },
 },
}))
