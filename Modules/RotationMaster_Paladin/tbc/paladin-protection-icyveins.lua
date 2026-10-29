-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Protection, Icy Veins: Judgement of the Crusader when nobody has it up, Righteousness
-- (Wisdom on packs), Consecration as the main threat, Judgement, Holy Shield, Avenger's
-- Shield and Hammer of Wrath on cooldown. Same switch as the Wowhead variant, lower priority.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function anySeal()local out={};for i,id in ipairs({21084,20375,31892,348700,31801,348704,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.protection.icyveins',revision=7,
 blocks={['tbc.paladin.tank-upkeep']=2,['tbc.paladin.melee-opening']=2,['tbc.paladin.boundaries']=2},
 nameKey="Protection (Icy Veins)",descriptionKey="Icy Veins' tanking, an alternative to the recommended Wowhead Protection premade, off by default: enable it and disable that one, or raise its priority. Judgement of the Crusader when nobody keeps it up, Righteousness (Wisdom on packs), Consecration as the main threat, Judgement, Holy Shield, then Avenger's Shield and Hammer of Wrath on cooldown. Same reminders as the Wowhead variant without Avenging Wrath.",
 applicability={families={'tbc'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','protection','tank','single-target','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/protection-paladin-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Protection Paladin rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/protection-paladin-leveling-guide',title='Icy Veins: Protection Paladin leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=19,disabled=true,switch=any(own(25780),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={{id='prot-icy-upkeep',type='block',block='tbc.paladin.tank-upkeep',prefix='prot-icy-'}},
  rotation={
   {id='prot-icy-opening',type='block',block='tbc.paladin.melee-opening',prefix='prot-icy-'},
   {id='prot-icy-crusader',type='branch',conditions={type='DEBUFF',unit='target',spell=21183,anyrank=true},onTrue={},onFalse={
    {id='prot-icy-crusader-judgement',type='spell',action=20271,ranked=false,conditions=own(21082)},
    {id='prot-icy-crusader-seal',type='spell',action=21082,ranked=false,conditions=negate(own(21082))},
   }},
   {id='prot-icy-seal',type='branch',conditions=anySeal(),onTrue={},onFalse={
    {id='prot-icy-seal-wisdom',type='spell',action=20166,ranked=false,conditions={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3}},
    {id='prot-icy-seal-righteousness',type='spell',action=21084,ranked=false,conditions={}},
   }},
   {id='prot-icy-consecration',type='spell',action=26573,ranked=false,conditions=negate({type='BEYOND_MELEE',unit='target'})},
   {id='prot-icy-judgement',type='spell',action=20271,ranked=false,conditions={}},
   {id='prot-icy-holy-shield',type='spell',action=20925,ranked=false,conditions=negate(own(20925))},
   {id='prot-icy-avengers-shield',type='spell',action=31935,ranked=false,conditions={}},
   {id='prot-icy-hammer',type='spell',action=24275,ranked=false,conditions={}},
  },
 },
}))
