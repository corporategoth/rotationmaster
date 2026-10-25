-- Retail (Midnight) Demonology Warlock, Icy Veins and SimulationCraft's default (Diabolist) list:
-- the optimal reference, disabled by default because Demonic Core, imp counts and cooldown
-- timings are hidden in Midnight combat (soul shards stay readable). Before the pull Power
-- Siphon, Demonbolt, Shadow Bolt. Power Siphon at one Demonic Core or none, Grimoire: Imp Lord,
-- Grimoire: Fel Ravager, Summon Doomguard, Call Dreadstalkers, Summon Demonic Tyrant at 5 shards,
-- Implosion on three or more engaged enemies, Ruination, Hand of Gul'dan at 3+ shards, Infernal
-- Bolt below 3, Demonbolt on Demonic Core below 4, Shadow Bolt. Reminder: a Felguard between pulls.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function shards(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local core=own(264173)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.demonology.icyveins',revision=6,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 nameKey='Default.Retail.Warlock.Demonology.IcyVeins.Name',descriptionKey='Default.Retail.Warlock.Demonology.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'demonology','ranged','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/demonology-warlock-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Demonology Warlock rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/warlock_demonology.simc',title='SimulationCraft: Demonology Warlock default list (diabolist)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={266},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('retail.warlock.upkeep','demoiv-'),
   spell('demoiv-summon-felguard',30146,all(negate(combat()),negate({type='PET'}))),
  },
  rotation={
   block('retail.warlock.boundaries','demoiv-'),
   {id='demoiv-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('demoiv-pull-power-siphon',264130),
    spell('demoiv-pull-demonbolt',264178,core),
    spell('demoiv-pull-shadow-bolt',686),
    {id='demoiv-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   spell('demoiv-power-siphon',264130,any(negate(core),{type='BUFF_STACKS',unit='player',spell=264173,ownbuff=true,operator='LESSTHANOREQUALS',value=1})),
   spell('demoiv-imp-lord',1276452),
   spell('demoiv-fel-ravager',1276467),
   spell('demoiv-doomguard',1276672),
   spell('demoiv-dreadstalkers',104316),
   spell('demoiv-tyrant',265187,shards('GREATERTHANOREQUALS',5)),
   spell('demoiv-implosion',196277,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   spell('demoiv-ruination',434635),
   spell('demoiv-hand-of-guldan',105174,shards('GREATERTHANOREQUALS',3)),
   spell('demoiv-infernal-bolt',434506,shards('LESSTHAN',3)),
   spell('demoiv-demonbolt',264178,all(core,shards('LESSTHAN',4))),
   spell('demoiv-shadow-bolt',686),
  },
 },
}))
