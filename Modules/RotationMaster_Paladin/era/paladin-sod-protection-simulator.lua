-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Protection after simulator' Phase 5 tank list: Judgement whenever a seal is up,
-- the seal renewed below 1.5 s, Holy Shield, Avenger's Shield, Hammer of the Righteous, Exorcism,
-- Shield of Righteousness last. Same switch as the recommended SoD Protection premade, lower priority,
-- shipped disabled.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function remain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1.5}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.protection.simulator',revision=7,
 blocks={['sod.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 nameKey="Protection (SoD, simulator)",descriptionKey="The simulator tank list, an alternative to the recommended Season of Discovery Protection premade, off by default: enable it and disable that one, or raise its priority. Judgement whenever a seal is up, the seal renewed just before it runs out, Holy Shield, Avenger's Shield, Hammer of the Righteous, Exorcism, Shield of Righteousness last. Same reminders as the recommended premade.",
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','protection','tank','single-target','season-of-discovery'},
 sources={},
 body={priority=119,disabled=true,switch=any(own(407627),own(25780),rune(407632),rune(440658),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={block('sprotws-upkeep','sod.paladin.tank-upkeep','sprotws-upkeep-')},
  rotation={
   block('sprotws-opening','era.paladin.melee-opening','sprotws-'),
   spell('sprotws-judgement',20271,any(own(407798),own(20154),own(21084))),
   spell('sprotws-renew-martyrdom',407798,remain(407798)),
   spell('sprotws-renew-righteousness',20154,remain(20154)),
   block('sprotws-seal','sod.paladin.seal','sprotws-'),
   {id='sprotws-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('sprotws-pull-holy-shield',20925,negate(own(20925))),
    spell('sprotws-pull-avengers-shield',407669),
    {id='sprotws-pull-stop',type='stop',conditions={}},
   }},
   spell('sprotws-holy-shield',20925,negate(own(20925))),
   spell('sprotws-avengers-shield',407669),
   spell('sprotws-hammer',407632),
   spell('sprotws-exorcism',415068),
   spell('sprotws-shield',440658),
  },
 },
}))
