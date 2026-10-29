-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Destruction Warlock, Icy Veins (Hellcaller): a reference, disabled by default
-- because Immolate and charges are hidden in Midnight combat (soul shards stay readable). Rain of
-- Fire on three or more engaged enemies; Wither or Immolate kept up; Summon Infernal;
-- Malevolence; Shadowburn whenever available; Soul Fire below 4 shards; Chaos Bolt before
-- capping (4+ shards); Cataclysm; Infernal Bolt below 4; Channel Demonfire; Conflagrate at two
-- charges, then Conflagrate; Incinerate.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function expiring(id,v)return any(negate(dot(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v})end
local function shards(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.warlock.destruction.icyveins',revision=6,
 blocks={['retail.warlock.boundaries']=3,['retail.warlock.upkeep']=2},
 nameKey="Chaos Bolt before capping reference (Icy Veins)",descriptionKey="Reference only, off by default: Icy Veins' Hellcaller order, which spends shards on Chaos Bolt before they cap and uses Shadowburn and Channel Demonfire on cooldown. Rain of Fire on three or more engaged enemies; Wither or Immolate kept up; Summon Infernal; Malevolence; Shadowburn; Soul Fire below 4 shards; Chaos Bolt at 4 or more; Cataclysm; Infernal Bolt below 4; Channel Demonfire; Conflagrate; Incinerate.",
 applicability={families={'retail'},actionContext='player',class='WARLOCK'},
 tags={'destruction','ranged','reference','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/destruction-warlock-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Destruction Warlock rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=4,disabled=true,specs={267},
  cooldowns={
   block('retail.warlock.upkeep','destroiv-'),
   spell('destroiv-summon-imp',688,all(negate(combat()),negate({type='PET'}),negate({type='BUFF',unit='player',spell=196099,ownbuff=true}))),
  },
  rotation={
   block('retail.warlock.boundaries','destroiv-'),
   spell('destroiv-rain-of-fire',5740,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   spell('destroiv-wither',445468,expiring(445474,5.4)),
   spell('destroiv-immolate',348,all(negate({type='SPELL_KNOWN',spell=445468}),expiring(157736,5.4))),
   spell('destroiv-summon-infernal',1122),
   spell('destroiv-malevolence',442726),
   spell('destroiv-shadowburn',17877),
   spell('destroiv-soul-fire',6353,shards('LESSTHAN',4)),
   spell('destroiv-chaos-bolt',116858,shards('GREATERTHANOREQUALS',4)),
   spell('destroiv-cataclysm',152108),
   spell('destroiv-infernal-bolt',434506,shards('LESSTHAN',4)),
   spell('destroiv-channel-demonfire',196447),
   spell('destroiv-conflagrate-capped',17962,{type='SPELL_CHARGES',spell=17962,operator='GREATERTHANOREQUALS',value=2}),
   spell('destroiv-conflagrate',17962),
   spell('destroiv-incinerate',29722),
  },
 },
}))
