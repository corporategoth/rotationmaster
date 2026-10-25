-- Retail (Midnight) Protection Warrior, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Shield Block, Thunder Blast and Colossal Might are
-- hidden in Midnight combat. Charge to open. Ravager, Thunder Blast at two stacks, Demolish at
-- five Colossal Might, Shield Charge, Thunder Blast, Shield Slam, Thunder Clap, Execute, Revenge,
-- Devastate. Reminders: Shield Block when its buff is down and you are tanking, Ignore Pain, Avatar,
-- Demoralizing Shout, Champion's Spear, Shield Wall and Last Stand whenever ready in combat (rage
-- and health are secret on Retail).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local tanking={type='THREAT',unit='target',threat=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warrior.protection.icyveins',revision=7,
 blocks={['retail.warrior.boundaries']=2,['retail.warrior.upkeep']=1,['retail.warrior.charge']=3},
 nameKey='Default.Retail.Warrior.Protection.IcyVeins.Name',descriptionKey='Default.Retail.Warrior.Protection.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='WARRIOR'},
 tags={'protection','tank','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/protection-warrior-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Protection Warrior rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warrior_protection.simc',title='SimulationCraft: Protection Warrior default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={73},
  cooldowns={
   block('retail.warrior.upkeep','protiv-'),
   spell('protiv-shield-block',2565,all(fight,tanking,negate(own(132404)))),
   spell('protiv-ignore-pain',190456,fight),
   spell('protiv-avatar',107574,fight),
   spell('protiv-demoralizing-shout',1160,fight),
   spell('protiv-champions-spear',376079,fight),
   spell('protiv-shield-wall',871,combat()),
   spell('protiv-last-stand',12975,combat()),
  },
  rotation={
   block('retail.warrior.boundaries','protiv-'),
   block('retail.warrior.charge','protiv-'),
   spell('protiv-ravager',228920),
   spell('protiv-thunder-blast-stacked',435222,{type='BUFF_STACKS',unit='player',spell=435615,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
   spell('protiv-demolish',436358,{type='BUFF_STACKS',unit='player',spell=440989,ownbuff=true,operator='GREATERTHANOREQUALS',value=5}),
   spell('protiv-shield-charge',385952),
   spell('protiv-thunder-blast',435222),
   spell('protiv-shield-slam',23922),
   spell('protiv-thunder-clap',6343),
   spell('protiv-execute',163201),
   spell('protiv-revenge',6572),
   spell('protiv-devastate',20243),
  },
 },
}))
