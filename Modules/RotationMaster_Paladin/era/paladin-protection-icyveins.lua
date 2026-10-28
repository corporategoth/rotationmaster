-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Protection, Seal of Wisdom style (Icy Veins' raid list with Askalon's Wisdom rotation):
-- keep Seal of Wisdom and Judgement of Wisdom up for mana, Holy Shield, Consecration every cooldown,
-- Judgement otherwise only to pull, and Greater Blessing of Kings as the raid threat filler.
-- Same switch as the recommended Protection premade, lower priority, shipped disabled.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local undead=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
local function sealed()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.protection.icyveins',revision=6,
 blocks={['era.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=3},
 nameKey='Default.Era.Paladin.Protection.IcyVeins.Name',descriptionKey='Default.Era.Paladin.Protection.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'endgame','raid','protection','tank','single-target','aoe','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/protection-paladin-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Protection Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.wowhead.com/classic/guide/lights-bulwark-protection-paladin-tanking',title='Wowhead: Protection Paladin tanking guide (Askalon), Wisdom rotation',reviewedAt='2026-10-23',revision='2024-11-21'}},
 body={priority=19,disabled=true,switch=any(own(25780),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={block('protw-upkeep','era.paladin.tank-upkeep','protw-')},
  rotation={
   block('protw-opening','era.paladin.melee-opening','protw-'),
   {id='protw-seal',type='branch',conditions=sealed(),onTrue={},onFalse={
    spell('protw-seal-wisdom',20166),
    spell('protw-seal-righteousness',20154),
   }},
   {id='protw-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('protw-pull-holy-shield',20925,negate(own(20925))),
    spell('protw-pull-judgement',20271),
    {id='protw-pull-stop',type='stop',conditions={}},
   }},
   spell('protw-holy-shield',20925,negate(own(20925))),
   spell('protw-judgement-wisdom',20271,all(own(20166),negate({type='DEBUFF',unit='target',spell=20186,anyrank=true}))),
   spell('protw-consecration',26573),
   spell('protw-holy-wrath',2812,all(undead,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
   spell('protw-exorcism',879,undead),
   spell('protw-greater-kings',25898,{type='GROUP',raid=true}),
  },
 },
}))
