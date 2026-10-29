-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Protection after simulator' Phase 5 tank list: Judgement whenever a seal is up,
-- the seal renewed below 1.5 s, Holy Shield, Avenger's Shield, Hammer of the Righteous, Exorcism,
-- Shield of Righteousness last. Same switch as the recommended SoD Protection premade, lower priority,
-- shipped disabled.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function remain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1.5}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.protection.simulator',revision=7,
 blocks={['sod.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','protection','tank','single-target','season-of-discovery'},
 sources={},
 body={priority=119,disabled=true,switch=BuiltinConditions.any(own(407627),own(25780),rune(407632),rune(440658),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={BuiltinConditions.block('sprotws-upkeep','sod.paladin.tank-upkeep','sprotws-upkeep-')},
  rotation={
   BuiltinConditions.block('sprotws-opening','era.paladin.melee-opening','sprotws-'),
   BuiltinConditions.spell('sprotws-judgement',20271,BuiltinConditions.any(own(407798),own(20154),own(21084))),
   BuiltinConditions.spell('sprotws-renew-martyrdom',407798,remain(407798)),
   BuiltinConditions.spell('sprotws-renew-righteousness',20154,remain(20154)),
   BuiltinConditions.block('sprotws-seal','sod.paladin.seal','sprotws-'),
   {id='sprotws-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('sprotws-pull-holy-shield',20925,BuiltinConditions.negate(own(20925))),
    BuiltinConditions.spell('sprotws-pull-avengers-shield',407669),
    {id='sprotws-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('sprotws-holy-shield',20925,BuiltinConditions.negate(own(20925))),
   BuiltinConditions.spell('sprotws-avengers-shield',407669),
   BuiltinConditions.spell('sprotws-hammer',407632),
   BuiltinConditions.spell('sprotws-exorcism',415068),
   BuiltinConditions.spell('sprotws-shield',440658),
  },
 },
}))
