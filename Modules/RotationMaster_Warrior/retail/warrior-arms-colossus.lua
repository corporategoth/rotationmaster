-- Retail (Midnight) Arms Warrior, Colossus (SimulationCraft's colossus_st list, Icy Veins): the
-- optimal reference, disabled by default because rage, Rend, Colossus Smash, Colossal Might and
-- Sudden Death are hidden in Midnight combat. Charge to open. Sweeping Strikes on two or more
-- engaged enemies; Mortal Strike to stack Colossal Might; Rend before Colossus Smash; Ravager;
-- Execute at two Sudden Death; Colossus Smash; Champion's Spear; Demolish in Colossus Smash with
-- Colossal Might; Heroic Strike; Mortal Strike; Execute; Overpower; Rend under 5 s; Bladestorm on
-- two or more; Slam. Reminders: Avatar, Die by the Sword.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function rend(v)return any(negate(dot(388539)),{type='DEBUFF_REMAIN',unit='target',spell=388539,owndebuff=true,operator='LESSTHAN',value=v})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local engaged={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.arms.colossus',revision=6,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 nameKey='Default.Retail.Warrior.Arms.Colossus.Name',descriptionKey='Default.Retail.Warrior.Arms.Colossus.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'arms','melee','reference','colossus','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_arms.simc',title='SimulationCraft: Arms Warrior default list (colossus_st)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Arms Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=4,disabled=true,specs={71},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('retail.warrior.upkeep','armsco-'),
   spell('armsco-avatar',107574,fight),
   spell('armsco-die-by-the-sword',118038,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','armsco-'),
   block('retail.warrior.charge','armsco-'),
   spell('armsco-sweeping-strikes',260708,engaged),
   spell('armsco-mortal-strike-might',12294,any(negate(own(440989)),{type='BUFF_STACKS',unit='player',spell=440989,ownbuff=true,operator='LESSTHAN',value=5})),
   spell('armsco-rend-before-smash',772,all(rend(4),{type='SPELL_COOLDOWN',spell=167105,operator='LESSTHAN',value=1.5})),
   spell('armsco-ravager',228920),
   spell('armsco-execute-sudden-death',163201,{type='BUFF_STACKS',unit='player',spell=52437,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   spell('armsco-colossus-smash',167105),
   spell('armsco-champions-spear',376079),
   spell('armsco-demolish',436358,all(dot(208086),own(440989))),
   spell('armsco-heroic-strike',1269383),
   spell('armsco-mortal-strike',12294),
   spell('armsco-execute',163201),
   spell('armsco-overpower',7384),
   spell('armsco-rend',772,rend(5)),
   spell('armsco-bladestorm',227847,engaged),
   spell('armsco-slam',1464),
  },
 },
}))
